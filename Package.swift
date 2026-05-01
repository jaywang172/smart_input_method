// swift-tools-version: 5.9
import PackageDescription

var targets: [Target] = [
    .target(
        name: "SmartIMECore",
        path: "Sources/SmartIMECore"
    ),
    .executableTarget(
        name: "SmartIMEDemo",
        dependencies: ["SmartIMECore"],
        path: "Sources/SmartIMEDemo"
    ),
    .executableTarget(
        name: "SmartIMECoreTests",
        dependencies: ["SmartIMECore"],
        path: "Tests",
        sources: ["UnitTests.swift"]
    ),
]

#if os(macOS)
targets.append(
    .executableTarget(
        name: "SmartIMEApp",
        dependencies: ["SmartIMECore"],
        path: "Sources/SmartIMEApp",
        exclude: ["Info.plist"],
        linkerSettings: [
            .linkedFramework("InputMethodKit")
        ]
    )
)
#endif

let package = Package(
    name: "SmartIMECore",
    platforms: [
        .macOS(.v10_15),
        .iOS(.v13)
    ],
    products: [
        .library(
            name: "SmartIMECore",
            targets: ["SmartIMECore"]
        ),
        .executable(
            name: "SmartIMEDemo",
            targets: ["SmartIMEDemo"]
        ),
    ],
    targets: targets
)
