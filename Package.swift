// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "Alfred",
    platforms: [.macOS(.v14)],
    targets: [
        .executableTarget(
            name: "Alfred",
            path: "Sources/Alfred",
            resources: [
                .process("Resources")
            ]
        )
    ]
)
