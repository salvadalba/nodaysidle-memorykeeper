// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "MemoryKeeper",
    platforms: [.macOS(.v15)],
    products: [
        .executable(name: "MemoryKeeper", targets: ["MemoryKeeper"])
    ],
    targets: [
        .executableTarget(
            name: "MemoryKeeper",
            path: "MemoryKeeper",
            swiftSettings: [
                .enableExperimentalFeature("StrictConcurrency")
            ]
        ),
        .testTarget(
            name: "MemoryKeeperTests",
            dependencies: ["MemoryKeeper"],
            path: "Tests"
        )
    ]
)
