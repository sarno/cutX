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
        )
    ],
    dependencies: [],
    targets: [
        .executableTarget(
            name: "CutX",
            dependencies: [],
            path: "Sources/CutX"
        ),
        .testTarget(
            name: "CutXTests",
            dependencies: ["CutX"],
            path: "Tests/CutXTests"
        )
    ]
)
