// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "EmojiGFast",
    platforms: [
        .macOS(.v14)
    ],
    targets: [
        .executableTarget(
            name: "EmojiGFast",
            resources: [
                .process("Resources")
            ]
        )
    ]
)
