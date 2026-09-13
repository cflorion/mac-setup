import Carbon
import PaperlikeCore

// Registers the configured shortcuts through RegisterEventHotKey: the agent
// never observes keystrokes and never needs Accessibility permission. Each
// binding's outcome is reported, because a shortcut already taken by another
// application fails silently otherwise.
final class HotKeyCenter {
    private struct Registered { let binding: HotKeyBinding; var ref: EventHotKeyRef? }

    private static let signature: OSType = 0x50415052   // 'PAPR'
    private var registered: [UInt32: Registered] = [:]
    private var handler: EventHandlerRef?
    private let agent: Agent
    private let hud: HUD?
    // Main thread only. One exchange runs at a time; presses that arrive
    // meanwhile wait here, where consecutive relative moves merge.
    private var pending: [(keys: String, action: Action)] = []
    private var running = false

    init(agent: Agent, hud: HUD?, bindings: [HotKeyBinding]) {
        self.agent = agent
        self.hud = hud
        var event = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        let installed = InstallEventHandler(GetApplicationEventTarget(), { _, event, context in
            guard let context, let event else { return OSStatus(eventNotHandledErr) }
            var id = EventHotKeyID()
            let read = GetEventParameter(event, EventParamName(kEventParamDirectObject), EventParamType(typeEventHotKeyID),
                                         nil, MemoryLayout<EventHotKeyID>.size, nil, &id)
            guard read == noErr, id.signature == HotKeyCenter.signature else { return OSStatus(eventNotHandledErr) }
            let center = Unmanaged<HotKeyCenter>.fromOpaque(context).takeUnretainedValue()
            guard let entry = center.registered[id.id] else { return OSStatus(eventNotHandledErr) }
            center.press(entry.binding)
            return noErr
        }, 1, &event, Unmanaged.passUnretained(self).toOpaque(), &handler)

        var results: [(HotKeyBinding, OSStatus)] = []
        for (index, binding) in bindings.enumerated() {
            let id = UInt32(index + 1)
            guard installed == noErr else { results.append((binding, installed)); continue }
            var ref: EventHotKeyRef?
            let status = RegisterEventHotKey(binding.keyCode, binding.modifiers,
                                             EventHotKeyID(signature: HotKeyCenter.signature, id: id),
                                             GetApplicationEventTarget(), 0, &ref)
            if status == noErr { registered[id] = Registered(binding: binding, ref: ref) }
            results.append((binding, status))
        }
        agent.recordShortcutRegistrations(results)
    }

    deinit {
        for entry in registered.values { if let ref = entry.ref { UnregisterEventHotKey(ref) } }
        if let handler { RemoveEventHandler(handler) }
    }

    private func press(_ binding: HotKeyBinding) {
        if let last = pending.last, let merged = last.action.merged(with: binding.parsed) {
            pending.removeLast()
            if !merged.isNoOp { pending.append((binding.keys, merged)) }
        } else {
            pending.append((binding.keys, binding.parsed))
        }
        runNext()
    }

    private func runNext() {
        guard !running, !pending.isEmpty else { return }
        let (keys, action) = pending.removeFirst()
        running = true
        // The serial exchange runs off the main run loop, which stays free for
        // the next press and for drawing the HUD.
        DispatchQueue.global(qos: .userInitiated).async { [self] in
            let reply = agent.perform(action)
            agent.recordShortcutResult(keys, reply)
            DispatchQueue.main.async { [self] in
                running = false
                hud?.show(reply)
                runNext()
            }
        }
    }
}
