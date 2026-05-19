// swift-tools-version: 5.9
import PackageDescription

// Alfred: `AlfredPane` (disk-cruft cleaner as a dynamic library via
// SuiteKit, loadable by the launcher; bundles its PNG glyphs) +
// `Alfred` (thin @main standalone shim, behaviour unchanged).
let package = Package(
    name: "Alfred",
    platforms: [.macOS(.v14)],
    products: [
        .executable(name: "Alfred", targets: ["Alfred"]),
        .library(name: "AlfredPane", type: .dynamic, targets: ["AlfredPane"])
    ],
    dependencies: [ .package(path: "../suitekit-swift") ],
    targets: [
        .target(
            name: "AlfredPane",
            dependencies: [.product(name: "SuiteKit", package: "suitekit-swift")],
            path: "Sources/AlfredPane",
            resources: [.process("Resources")]
        ),
        .executableTarget(
            name: "Alfred",
            dependencies: ["AlfredPane", .product(name: "SuiteKit", package: "suitekit-swift")],
            path: "Sources/Alfred"
        )
    ]
)
