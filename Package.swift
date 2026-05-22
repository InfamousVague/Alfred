// swift-tools-version: 5.9
import PackageDescription

// Alfred — three SPM products:
//
//   • `AlfredPane` (.dynamic) — the actual disk-cruft cleaner. Loaded
//     at runtime by the MattsSoftware launcher via SuiteKit.
//   • `Alfred` (.executable) — thin standalone shim that hosts the
//     pane in its own NSStatusItem + NSPopover.
//   • `AlfredShared` (.library, .static) — App Group id, `SharedStats`
//     Group-Container model, `ScanIntent` / `CleanAllSafeIntent` and
//     the `IntentBus` glue. Consumed by `AlfredPane`, `Alfred`, AND
//     the Xcode widget target at `Widget/AlfredWidgets.xcodeproj` —
//     the widget extension can't live in SPM (SR-14944: SPM has no
//     `productType = com.apple.product-type.app-extension`, so the
//     binary fatal-errors in ExtensionFoundation at launch). The
//     Xcode subproject consumes `AlfredShared` via local package
//     dependency so the widget shares one source of truth for the
//     models + intent definitions.
let package = Package(
    name: "Alfred",
    platforms: [.macOS(.v14)],
    products: [
        .executable(name: "Alfred", targets: ["Alfred"]),
        .library(name: "AlfredPane", type: .dynamic,
                 targets: ["AlfredPane"]),
        .library(name: "AlfredShared", targets: ["AlfredShared"])
    ],
    dependencies: [ .package(path: "../suitekit-swift") ],
    targets: [
        .target(
            name: "AlfredShared",
            path: "Sources/AlfredShared"
        ),
        .target(
            name: "AlfredPane",
            dependencies: [
                "AlfredShared",
                .product(name: "SuiteKit", package: "suitekit-swift")
            ],
            path: "Sources/AlfredPane",
            resources: [.process("Resources")]
        ),
        .executableTarget(
            name: "Alfred",
            dependencies: [
                "AlfredPane",
                "AlfredShared",
                .product(name: "SuiteKit", package: "suitekit-swift")
            ],
            path: "Sources/Alfred"
        )
    ]
)
