// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "Flemo",
    platforms: [
        .macOS(.v14)
    ],
    dependencies: [
        .package(url: "https://github.com/sparkle-project/Sparkle", from: "2.9.4")
    ],
    targets: [
        .executableTarget(
            name: "Flemo",
            dependencies: [
                .product(name: "Sparkle", package: "Sparkle")
            ],
            path: "Sources/Flemo",
            resources: [
                .process("Resources")
            ]
        )
    ]
)
