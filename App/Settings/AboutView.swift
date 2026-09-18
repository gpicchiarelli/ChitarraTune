import SwiftUI
import TunerAudio

/// Build metadata read from the bundle (no generated source files, no build scripts).
enum BuildInfo {
    static let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "—"
    static let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "—"
    static let commit = Bundle.main.object(forInfoDictionaryKey: "ChitarraGitCommit") as? String ?? "dev"

    /// Plain-text summary for bug reports.
    static var summary: String {
        "ChitarraTune \(version) (\(build), \(commit))\n\(ProcessInfo.processInfo.operatingSystemVersionString)"
    }
}

struct AboutView: View {
    static let repositoryURL = URL(string: "https://github.com/gpicchiarelli/ChitarraTune")!

    var body: some View {
        VStack(spacing: 14) {
            AppIconImage()
                .frame(width: 96, height: 96)
                .clipShape(.rect(cornerRadius: 22, style: .continuous))
                .shadow(color: .black.opacity(0.15), radius: 8, y: 3)
                .accessibilityHidden(true)

            Text(.appName)
                .font(.title.weight(.bold))
            Text(.aboutTagline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            VStack(spacing: 2) {
                Text(.aboutVersion(BuildInfo.version))
                Text(.aboutBuild(BuildInfo.build, BuildInfo.commit))
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }
            .textSelection(.enabled)

            GlassEffectContainer(spacing: 10) {
                HStack {
                    Link(destination: Self.repositoryURL) { Label(.aboutSource, systemImage: "chevron.left.forwardslash.chevron.right") }
                        .buttonStyle(.glass)
                    CopyInfoButton()
                }
            }
            .padding(.top, 6)
        }
        .padding(28)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .navigationTitle(Text(.aboutTitle))
        #if os(macOS)
        .frame(width: 360, height: 380)
        #endif
    }
}

/// Copies version info plus the app's recent (privacy-safe) log lines for bug reports.
private struct CopyInfoButton: View {
    @State private var didCopy = false

    var body: some View {
        Button {
            Task {
                let report = await Diagnostics.report()
                #if os(macOS)
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(report, forType: .string)
                #else
                UIPasteboard.general.string = report
                #endif
                didCopy = true
            }
        } label: {
            Label(.aboutCopyDiagnostics, systemImage: didCopy ? "checkmark" : "doc.on.doc")
        }
        .buttonStyle(.glass)
        .sensoryFeedback(.success, trigger: didCopy)
    }
}

/// The app icon as an image, on both platforms.
struct AppIconImage: View {
    var body: some View {
        #if os(macOS)
        Image(nsImage: NSApplication.shared.applicationIconImage)
            .resizable()
            .scaledToFit()
        #else
        Image(.iconPreview)
            .resizable()
            .scaledToFit()
        #endif
    }
}

struct LicenseView: View {
    var body: some View {
        ScrollView {
            Text(Self.text)
                .font(.callout.monospaced())
                .textSelection(.enabled)
                .padding(20)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .navigationTitle(Text(.licenseTitle))
        #if os(macOS)
        .frame(width: 560, height: 480)
        #endif
    }

    private static var text: String {
        if let url = Bundle.main.url(forResource: "LICENSE", withExtension: nil),
           let text = try? String(contentsOf: url, encoding: .utf8) {
            return text
        }
        return String(localized: .licenseMissing)
    }
}

#if os(macOS)
import AppKit
#else
import UIKit
#endif
