// swift-tools-version: 6.0
import Foundation
import PackageDescription

let isMASBuild = ProcessInfo.processInfo.environment["TOKEN_MONITOR_MAS_BUILD"] == "1"

var packageDependencies: [Package.Dependency] = [
    .package(url: "https://github.com/swiftlang/swift-testing.git", exact: "6.2.3")
]

if !isMASBuild {
    packageDependencies.append(.package(url: "https://github.com/sparkle-project/Sparkle.git", from: "2.9.1"))
}

var appDependencies: [Target.Dependency] = [
    "TokenMonitorCore"
]

if !isMASBuild {
    appDependencies.append(.product(name: "Sparkle", package: "Sparkle"))
}

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
    dependencies: packageDependencies,
    targets: [
        .target(
            name: "TokenMonitorCore",
            path: "Sources/TokenMonitorCore"
        ),
        .executableTarget(
            name: "TokenMonitorApp",
            dependencies: appDependencies,
            path: "Sources/TokenMonitorApp",
            resources: [
                .copy("Resources")
            ],
            swiftSettings: isMASBuild ? [.define("MAS_BUILD")] : []
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
