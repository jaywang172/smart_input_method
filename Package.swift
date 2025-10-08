// swift-tools-version: 5.9
import PackageDescription

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
    targets: [
        .target(
            name: "SmartIMECore",
            path: "Sources/SmartIMECore"
        ),
        .executableTarget(
            name: "SmartIMEDemo",
            dependencies: ["SmartIMECore"],
            path: "Sources/SmartIMEDemo"
        ),
        .testTarget(
            name: "SmartIMECoreTests",
            dependencies: ["SmartIMECore"],
            path: "Tests"
        ),
    ]
)