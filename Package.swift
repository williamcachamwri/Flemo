// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "Flemo",
    platforms: [
        .macOS(.v14)
    ],
    targets: [
        .executableTarget(
            name: "Flemo",
            path: "Sources/EmojiGFast",
            resources: [
                .process("Resources")
            ]
        )
    ]
)
