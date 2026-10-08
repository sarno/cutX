// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "CutX",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(
            name: "CutX",
            targets: ["CutX"]
        ),
        .library(
            name: "CutXCore",
            targets: ["CutXCore"]
        )
    ],
    dependencies: [],
    targets: [
        .target(
            name: "CutXCore",
            dependencies: [],
            path: "Sources/CutXCore"
        ),
        .executableTarget(
            name: "CutX",
            dependencies: ["CutXCore"],
            path: "Sources/CutX"
        ),
        .executableTarget(
            name: "CutXTestRunner",
            dependencies: ["CutXCore"],
            path: "Sources/CutXTestRunner"
        )
    ]
)
