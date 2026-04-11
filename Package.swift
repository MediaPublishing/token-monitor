// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "TokenMonitor",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .library(
            name: "TokenMonitorCore",
            targets: ["TokenMonitorCore"]
        ),
        .executable(
            name: "TokenMonitorApp",
            targets: ["TokenMonitorApp"]
        )
    ],
    dependencies: [
        .package(url: "https://github.com/sparkle-project/Sparkle.git", from: "2.9.1"),
        .package(url: "https://github.com/swiftlang/swift-testing.git", exact: "6.2.3")
    ],
    targets: [
        .target(
            name: "TokenMonitorCore",
            path: "Sources/TokenMonitorCore"
        ),
        .executableTarget(
            name: "TokenMonitorApp",
            dependencies: [
                "TokenMonitorCore",
                .product(name: "Sparkle", package: "Sparkle")
            ],
            path: "Sources/TokenMonitorApp",
            resources: [
                .copy("Resources")
            ]
        ),
        .testTarget(
            name: "TokenMonitorCoreTests",
            dependencies: [
                "TokenMonitorCore",
                .product(name: "Testing", package: "swift-testing")
            ],
            path: "Tests/TokenMonitorCoreTests",
            resources: [
                .copy("Fixtures")
            ]
        )
    ]
)
