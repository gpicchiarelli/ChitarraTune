// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "ChitarraTune",
    defaultLocalization: "it",
    platforms: [
        .iOS(.v15),
        .macOS(.v12),
        .tvOS(.v15)
    ],
    products: [
        .library(name: "ChitarraTuneCore", targets: ["ChitarraTuneCore"]) 
    ],
    targets: [
        .target(
            name: "ChitarraTuneCore",
            path: "Sources/ChitarraTuneCore"
        )
    ]
)

