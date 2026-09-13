import Foundation
import Darwin

// Local IPC only: private directory, same-user peers, bounded messages and
// deadlines. The CLI never opens a second connection to the hardware.
public final class LocalSocket {
    public static let directory = FileManager.default.homeDirectoryForCurrentUser
        .appendingPathComponent("Library/Application Support/PaperlikeAgent").path
    public static let path = directory + "/control.sock"
    private var lockFD: Int32 = -1
    private var socketFD: Int32 = -1
    private var source: DispatchSourceRead?
    private let slots = DispatchSemaphore(value: 4)

    public init() {}

    public func serve(handler: @escaping ([String]) -> [String: Any]) throws {
        try FileManager.default.createDirectory(atPath: Self.directory, withIntermediateDirectories: true,
                                              attributes: [.posixPermissions: 0o700])
        var info = stat()
        guard lstat(Self.directory, &info) == 0, info.st_uid == getuid(),
              (info.st_mode & S_IFMT) == S_IFDIR, chmod(Self.directory, 0o700) == 0 else {
            throw PaperlikeError("The control directory must belong to this user.")
        }
        lockFD = Darwin.open(Self.directory + "/agent.lock", O_RDWR | O_CREAT | O_NOFOLLOW | O_CLOEXEC, 0o600)
        guard lockFD >= 0, flock(lockFD, LOCK_EX | LOCK_NB) == 0 else {
            throw PaperlikeError("PaperlikeAgent is already running.")
        }
        // The lock owns the socket namespace, so only a stale socket is removed.
        unlink(Self.path)
        socketFD = socket(AF_UNIX, SOCK_STREAM, 0)
        guard socketFD >= 0 else { throw PaperlikeError("Cannot create the socket.") }
        setNonBlocking(socketFD)
        var address = try Self.address()
        let bound = withUnsafePointer(to: &address) {
            $0.withMemoryRebound(to: sockaddr.self, capacity: 1) { Darwin.bind(socketFD, $0, socklen_t(MemoryLayout<sockaddr_un>.size)) }
        }
        guard bound == 0, chmod(Self.path, 0o600) == 0, listen(socketFD, 4) == 0 else {
            throw PaperlikeError("Cannot open the local socket.")
        }
        let source = DispatchSource.makeReadSource(fileDescriptor: socketFD, queue: .global(qos: .utility))
        source.setEventHandler { [weak self] in
            guard let self else { return }
            let client = accept(self.socketFD, nil, nil)
            guard client >= 0 else { return }
            guard self.slots.wait(timeout: .now()) == .success else { Darwin.close(client); return }
            DispatchQueue.global(qos: .utility).async {
                defer { Darwin.close(client); self.slots.signal() }
                var uid: uid_t = 0, gid: gid_t = 0
                guard getpeereid(client, &uid, &gid) == 0, uid == getuid() else { return }
                setNonBlocking(client)
                do {
                    let input = try Self.readLine(client, limit: 1024, timeout: 1.5)
                    guard let args = try JSONSerialization.jsonObject(with: input) as? [String] else { return }
                    let response = handler(args)
                    var data = try JSONSerialization.data(withJSONObject: response, options: [.sortedKeys])
                    data.append(10)
                    try writeAll(fd: client, data: data, timeout: 1)
                } catch {
                    let reply = ["ok": false, "error": String(describing: error)] as [String: Any]
                    if var data = try? JSONSerialization.data(withJSONObject: reply) {
                        data.append(10); try? writeAll(fd: client, data: data, timeout: 0.5)
                    }
                }
            }
        }
        self.source = source
        source.resume()
    }

    public static func request(_ args: [String]) throws -> [String: Any] {
        let fd = socket(AF_UNIX, SOCK_STREAM, 0)
        guard fd >= 0 else { throw PaperlikeError("Cannot create the socket.") }
        defer { Darwin.close(fd) }
        setNonBlocking(fd)
        var address = try address()
        let result = withUnsafePointer(to: &address) {
            $0.withMemoryRebound(to: sockaddr.self, capacity: 1) { Darwin.connect(fd, $0, socklen_t(MemoryLayout<sockaddr_un>.size)) }
        }
        guard result == 0 else { throw PaperlikeError("Agent unavailable. Run make paperlike in mac-setup.") }
        var uid: uid_t = 0, gid: gid_t = 0
        guard getpeereid(fd, &uid, &gid) == 0, uid == getuid() else { throw PaperlikeError("Unexpected owner of the agent socket.") }
        var data = try JSONSerialization.data(withJSONObject: args)
        data.append(10)
        try writeAll(fd: fd, data: data, timeout: 1)
        let response = try readLine(fd, limit: 65536, timeout: 6)
        guard let object = try JSONSerialization.jsonObject(with: response) as? [String: Any] else {
            throw PaperlikeError("Invalid reply from the agent.")
        }
        return object
    }

    private static func address() throws -> sockaddr_un {
        var address = sockaddr_un()
        address.sun_family = sa_family_t(AF_UNIX)
        address.sun_len = UInt8(MemoryLayout<sockaddr_un>.size)
        let bytes = Array(path.utf8) + [0]
        guard bytes.count <= MemoryLayout.size(ofValue: address.sun_path) else {
            throw PaperlikeError("User path too long for a macOS socket.")
        }
        withUnsafeMutableBytes(of: &address.sun_path) { $0.copyBytes(from: bytes) }
        return address
    }

    private static func readLine(_ fd: Int32, limit: Int, timeout: TimeInterval) throws -> Data {
        let end = ProcessInfo.processInfo.systemUptime + timeout
        var data = Data()
        while data.count <= limit {
            let remaining = end - ProcessInfo.processInfo.systemUptime
            guard remaining > 0 else { throw PaperlikeError("The agent did not reply in time.") }
            var p = pollfd(fd: fd, events: Int16(POLLIN), revents: 0)
            let ready = poll(&p, 1, Int32(max(1, remaining * 1000)))
            if ready < 0 && errno == EINTR { continue }
            guard ready > 0 else { throw PaperlikeError("Communication timed out.") }
            var bytes = [UInt8](repeating: 0, count: 2048)
            let count = Darwin.read(fd, &bytes, bytes.count)
            if count < 0 && [EAGAIN, EINTR].contains(errno) { continue }
            guard count > 0 else { throw PaperlikeError("Local connection interrupted.") }
            data.append(contentsOf: bytes.prefix(count))
            if let newline = data.firstIndex(of: 10), newline <= limit { return data.prefix(upTo: newline) }
        }
        throw PaperlikeError("Local message too long.")
    }
}

private func setNonBlocking(_ fd: Int32) {
    _ = fcntl(fd, F_SETFL, fcntl(fd, F_GETFL) | O_NONBLOCK)
    _ = fcntl(fd, F_SETFD, FD_CLOEXEC)
    var one: Int32 = 1
    setsockopt(fd, SOL_SOCKET, SO_NOSIGPIPE, &one, socklen_t(MemoryLayout.size(ofValue: one)))
}
