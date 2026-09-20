import SwiftUI

/// The primary action: white text on a solid capsule.
///
/// The fill is opaque on purpose. White on a translucent tinted glass depends on whatever is behind
/// it and can drop well below 4.5:1; on the solid ``Color/tuneAccentFill`` or ``Color/tuneRedFill``
/// it stays above 5.8:1 in every appearance.
struct ProminentCapsuleButtonStyle: ButtonStyle {
    var fill: Color = .tuneAccentFill

    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .multilineTextAlignment(.center)
            .fixedSize(horizontal: false, vertical: true)
            .foregroundStyle(.white)
            .padding(.horizontal, 20)
            .padding(.vertical, 14)
            .frame(minHeight: 52)
            .background(Capsule().fill(fill))
            .contentShape(.capsule)
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .opacity(isEnabled ? (configuration.isPressed ? 0.85 : 1) : 0.5)
            .animation(.snappy(duration: 0.15), value: configuration.isPressed)
    }
}

/// A secondary action: accent-coloured text on a pale accent capsule (≥ 7:1 in every appearance).
struct SecondaryCapsuleButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .multilineTextAlignment(.center)
            .fixedSize(horizontal: false, vertical: true)
            .foregroundStyle(Color.tuneAccentText)
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .frame(minHeight: 48)
            // Opaque, so the contrast does not depend on what is behind the button.
            .background(Capsule().fill(Color.tuneAccentTint))
            .overlay(Capsule().fill(Color.tuneAccentFill.opacity(configuration.isPressed ? 0.12 : 0)))
            .contentShape(.capsule)
            .opacity(isEnabled ? 1 : 0.5)
    }
}

extension ButtonStyle where Self == ProminentCapsuleButtonStyle {
    static var prominentCapsule: ProminentCapsuleButtonStyle { .init() }
    static func prominentCapsule(fill: Color) -> ProminentCapsuleButtonStyle { .init(fill: fill) }
}

extension ButtonStyle where Self == SecondaryCapsuleButtonStyle {
    static var secondaryCapsule: SecondaryCapsuleButtonStyle { .init() }
}
