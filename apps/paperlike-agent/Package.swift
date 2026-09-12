// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "PaperlikeAgent",
    platforms: [.macOS(.v13)],
    products: [.executable(name: "PaperlikeAgent", targets: ["PaperlikeAgent"])],
    targets: [
        .target(name: "PaperlikeCore"),
        .executableTarget(name: "PaperlikeAgent", dependencies: ["PaperlikeCore"]),
        .testTarget(name: "PaperlikeCoreTests", dependencies: ["PaperlikeCore"])
    ]
)
