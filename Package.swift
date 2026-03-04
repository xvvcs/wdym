// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "DictationPromptRefactor",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .library(
            name: "PromptRefactorCore",
            targets: ["PromptRefactorCore"]
        )
    ],
    targets: [
        .target(
            name: "PromptRefactorCore"
        ),
        .testTarget(
            name: "PromptRefactorCoreTests",
            dependencies: ["PromptRefactorCore"]
        )
    ]
)
