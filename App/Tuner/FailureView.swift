import SwiftUI
import TunerAudio
import TunerFeature

/// Full-screen explanation when the microphone can't be used, with the one action that helps.
///
/// Built by hand rather than with `ContentUnavailableView`, so that every line grows with Dynamic
/// Type and scrolls instead of being clipped at the largest sizes.
struct FailureView: View {
    let failure: CaptureFailure
    let model: TunerModel

    @ScaledMetric(relativeTo: .largeTitle) private var symbolSize: CGFloat = 48
    @State private var visibleHeight: CGFloat = 0

    var body: some View {
        ScrollView {
            content.frame(minHeight: visibleHeight)
        }
        .scrollBounceBehavior(.basedOnSize)
        .onScrollGeometryChange(for: CGFloat.self) { geometry in
            geometry.containerSize.height - geometry.contentInsets.top - geometry.contentInsets.bottom
        } action: { _, height in
            visibleHeight = max(0, height)
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("failureView")
    }

    private var content: some View {
        Group {
            VStack(spacing: 14) {
                Image(systemName: failure.symbol)
                    .font(.system(size: symbolSize, weight: .semibold))
                    .foregroundStyle(Color.tuneSecondaryLabel)
                    .accessibilityHidden(true)

                Text(failure.title)
                    .font(.title2.weight(.bold))
                    .multilineTextAlignment(.center)
                    .accessibilityAddTraits(.isHeader)

                Text(failure.message)
                    .multilineTextAlignment(.center)

                VStack(spacing: 10) {
                    if failure.needsSystemSettings {
                        Button(action: PlatformSettings.openMicrophonePrivacy) {
                            Text(.failureOpenSettings).frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.prominentCapsule)
                    }
                    if failure != .microphoneRestricted {
                        Button {
                            Task { await model.start() }
                        } label: {
                            Text(.failureRetry).frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.secondaryCapsule)
                    }
                }
                .frame(maxWidth: 320)
                .padding(.top, 8)
            }
            .frame(maxWidth: 480)
            .padding(.horizontal, 24)
            .padding(.vertical, 32)
            .frame(maxWidth: .infinity)
        }
    }
}
