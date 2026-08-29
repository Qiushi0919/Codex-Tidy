// swift-tools-version: 5.10

import PackageDescription

let package = Package(
    name: "CodexFileManager",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .library(name: "CodexFileCore", targets: ["CodexFileCore"]),
        .executable(name: "CodexFileManager", targets: ["CodexFileManager"]),
        .executable(name: "codexfm", targets: ["CodexFMCLI"])
    ],
    targets: [
        .target(name: "CodexFileCore"),
        .executableTarget(
            name: "CodexFileManager",
            dependencies: ["CodexFileCore"]
        ),
        .executableTarget(
            name: "CodexFMCLI",
            dependencies: ["CodexFileCore"]
        ),
        .testTarget(
            name: "CodexFileCoreTests",
            dependencies: ["CodexFileCore"]
        )
    ]
)
