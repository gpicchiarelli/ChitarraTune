import SwiftUI

/// Shown once, before the system microphone prompt: says why the tuner needs the microphone and
/// what happens to the sound, so the system alert never arrives out of the blue.
struct MicrophonePrimer: View {
    let onContinue: () -> Void
    let onCancel: () -> Void

    @ScaledMetric(relativeTo: .largeTitle) private var symbolSize: CGFloat = 56

    var body: some View {
        ScrollView {
            VStack(spacing: 18) {
                Image(systemName: "mic.fill")
                    .font(.system(size: symbolSize, weight: .semibold))
                    .foregroundStyle(Color.accentColor)
                    .padding(.top, 8)
                    .accessibilityHidden(true)

                Text(.primerTitle)
                    .font(.title2.weight(.bold))
                    .multilineTextAlignment(.center)
                    .accessibilityAddTraits(.isHeader)

                Text(.primerBody)
                    .multilineTextAlignment(.center)

                Label {
                    Text(.primerPrivacy)
                } icon: {
                    Image(systemName: "lock.shield.fill").foregroundStyle(Color.accentColor)
                }
                .font(.callout)
                .foregroundStyle(Color.tuneSecondaryLabel)
            }
            .frame(maxWidth: 440)
            .padding(.horizontal, 24)
            .padding(.vertical, 20)
            .frame(maxWidth: .infinity)
        }
        .scrollBounceBehavior(.basedOnSize)
        .safeAreaInset(edge: .bottom) {
            VStack(spacing: 8) {
                Button(action: onContinue) {
                    Text(.primerContinue).frame(maxWidth: .infinity)
                }
                .buttonStyle(.prominentCapsule)
                .keyboardShortcut(.defaultAction)
                .accessibilityIdentifier("primerContinue")

                Button(action: onCancel) {
                    Text(.primerNotNow).frame(maxWidth: .infinity)
                }
                .buttonStyle(.secondaryCapsule)
                .keyboardShortcut(.cancelAction)
                .accessibilityIdentifier("primerNotNow")
            }
            .frame(maxWidth: 440)
            .padding(.horizontal, 24)
            .padding(.bottom, 16)
            .frame(maxWidth: .infinity)
        }
        #if os(macOS)
        .frame(width: 420, height: 420)
        #endif
        // `.contain` keeps the buttons' own identifiers; on a plain container the identifier would
        // be copied onto every child.
        .accessibilityElement(children: .contain)
        .accessibilityLabel(Text(.primerTitle))
        .accessibilityIdentifier("microphonePrimer")
    }
}

#Preview {
    MicrophonePrimer(onContinue: {}, onCancel: {})
}
