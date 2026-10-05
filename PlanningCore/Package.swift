// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "PlanningCore",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .library(
            name: "PlanningCore",
            targets: ["PlanningCore"]
        )
    ],
    targets: [
        .target(name: "PlanningCore"),
        .testTarget(
            name: "PlanningCoreTests",
            dependencies: ["PlanningCore"]
        )
    ]
)
