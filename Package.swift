// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "ChitarraTune",
    defaultLocalization: "it",
    platforms: [
        .macOS(.v12)
    ],
    products: [
        .library(name: "ChitarraTuneCore", targets: ["ChitarraTuneCore"]) 
    ],
    targets: [
        .target(
            name: "ChitarraTuneCore",
            path: "Sources/ChitarraTuneCore"
        ),
        .testTarget(
            name: "ChitarraTuneCoreTests",
            dependencies: ["ChitarraTuneCore"],
            path: "Tests/ChitarraTuneCoreTests"
        )
    ]
)
