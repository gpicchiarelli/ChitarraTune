// swift-tools-version: 6.2
import PackageDescription

/// Language features shared by every target. Swift 6 language mode already enables
/// strict concurrency; the flags below opt into the remaining forward-looking checks.
///
/// Everything is an error except a deprecation. A yearly SDK deprecates APIs that still work, and a
/// build that refuses to compile because Apple has published a successor — sometimes before that
/// successor has a Swift spelling anyone would want to write — turns their release schedule into an
/// outage. A deprecation is a message, so it stays a warning: visible on every build, migrated when
/// there is somewhere to migrate to, and never a reason for the gate to go red on a morning nobody
/// touched the code. Nothing in this package is deprecated today; the rule is for next September.
let sharedSettings: [SwiftSetting] = [
    .enableUpcomingFeature("ExistentialAny"),
    .enableUpcomingFeature("MemberImportVisibility"),
    .enableUpcomingFeature("NonisolatedNonsendingByDefault"),
    .treatWarning("DeprecatedDeclaration", as: .warning),
]

let package = Package(
    name: "ChitarraTuneKit",
    platforms: [
        .macOS("27.0"),
        .iOS("27.0"),
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
            exclude: ["Hardware/README.md"],
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
