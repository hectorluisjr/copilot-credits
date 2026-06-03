// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "CopilotCreditsMenuBar",
    platforms: [
        .macOS(.v13)
    ],
    targets: [
        .executableTarget(
            name: "CopilotCreditsMenuBar",
            path: "Sources/CopilotCreditsMenuBar"
        ),
        .testTarget(
            name: "CopilotCreditsMenuBarTests",
            dependencies: ["CopilotCreditsMenuBar"],
            path: "Tests/CopilotCreditsMenuBarTests"
        ),
    ]
)
