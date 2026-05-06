// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "SomeLens",
    platforms: [
        .iOS(.v17),
        .macOS(.v14)
    ],
    products: [
        .library(
            name: "SomeLens",
            targets: ["SomeLens"]
        )
    ],
    targets: [
        .target(
            name: "SomeLens",
            resources: [
                .process("LensShader.metal")
            ]
        )
    ]
)
