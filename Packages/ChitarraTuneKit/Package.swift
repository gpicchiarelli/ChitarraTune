// swift-tools-version: 6.2
import PackageDescription

/// Language features shared by every target. Swift 6 language mode already enables
/// strict concurrency; the flags below opt into the remaining forward-looking checks.
let sharedSettings: [SwiftSetting] = [
    .enableUpcomingFeature("ExistentialAny"),
    .enableUpcomingFeature("MemberImportVisibility"),
    .enableUpcomingFeature("NonisolatedNonsendingByDefault"),
]

let package = Package(
    name: "ChitarraTuneKit",
    platforms: [
        .macOS("26.0"),
        .iOS("26.0"),
    ],
    products: [
        .library(name: "TunerCore", targets: ["TunerCore"]),
        .library(name: "TunerAudio", targets: ["TunerAudio"]),
        .library(name: "TunerFeature", targets: ["TunerFeature"]),
    ],
    targets: [
        // Pure domain + DSP. Foundation and Accelerate only; no UI, no audio I/O.
        .target(
            name: "TunerCore",
            swiftSettings: sharedSettings
        ),
        // Microphone capture, permission and input-device discovery (AVFoundation / Core Audio).
        .target(
            name: "TunerAudio",
            dependencies: ["TunerCore"],
            swiftSettings: sharedSettings
        ),
        // Observable presentation model that wires capture → DSP → UI state.
        .target(
            name: "TunerFeature",
            dependencies: ["TunerCore", "TunerAudio"],
            swiftSettings: sharedSettings
        ),
        .testTarget(
            name: "TunerCoreTests",
            dependencies: ["TunerCore"],
            // Recordings are read from the source tree by path (see RecordingCorpusTests).
            exclude: ["Fixtures"],
            swiftSettings: sharedSettings
        ),
        // Turns the promises made by the README, SECURITY.md, the build settings and the workflows
        // into tests that read the repository itself (privacy, entitlements, pinned actions, docs).
        .testTarget(
            name: "RepositoryPolicyTests",
            dependencies: ["TunerCore"],
            swiftSettings: sharedSettings
        ),
        .testTarget(
            name: "TunerFeatureTests",
            dependencies: ["TunerFeature", "TunerAudio", "TunerCore"],
            swiftSettings: sharedSettings
        ),
    ],
    swiftLanguageModes: [.v6]
)
