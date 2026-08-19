// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "Chlorophyll",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(name: "ChlorophyllApp", targets: ["ChlorophyllApp"]),
        .library(name: "ChlorophyllCore", targets: ["ChlorophyllCore"]),
        .library(name: "ChlorophyllEditor", targets: ["ChlorophyllEditor"])
    ],
    targets: [
        .target(
            name: "ChlorophyllCore",
            swiftSettings: [.swiftLanguageMode(.v5)]
        ),
        .target(
            name: "ChlorophyllEditor",
            dependencies: ["ChlorophyllCore"],
            swiftSettings: [.swiftLanguageMode(.v5)]
        ),
        .executableTarget(
            name: "ChlorophyllApp",
            dependencies: ["ChlorophyllCore", "ChlorophyllEditor"],
            swiftSettings: [.swiftLanguageMode(.v5)]
        ),
        .testTarget(
            name: "ChlorophyllCoreTests",
            dependencies: ["ChlorophyllCore"],
            swiftSettings: [.swiftLanguageMode(.v5)]
        )
    ]
)
