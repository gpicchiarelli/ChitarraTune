import SwiftUI
import TunerCore
import TunerFeature

/// Preferences shared by every tuner window. A Settings scene on macOS, a sheet on iPhone/iPad.
struct SettingsView: View {
    @Bindable var settings: TunerSettings

    var body: some View {
        Form {
            calibration
            display
            feedback
            battery
            privacy
            #if os(iOS)
            about
            #endif
        }
        .formStyle(.grouped)
        .navigationTitle(Text(.settingsTitle))
        #if os(macOS)
        .frame(width: 480)
        .scrollContentBackground(.visible)
        #endif
    }

    // MARK: Sections

    private var calibration: some View {
        Section {
            LabeledContent {
                Text(.settingsReferencePitchValue(Int(settings.referenceA)))
                    .monospacedDigit()
                    .foregroundStyle(Color.tuneSecondaryLabel)
            } label: {
                Text(.settingsReferencePitch)
            }
            Slider(value: $settings.referenceA, in: PitchMath.referenceARange, step: 1) {
                Text(.settingsReferencePitch)
            } minimumValueLabel: {
                Text(PitchMath.referenceARange.lowerBound, format: .number)
            } maximumValueLabel: {
                Text(PitchMath.referenceARange.upperBound, format: .number)
            }
            .accessibilityValue(Text(.settingsReferencePitchValue(Int(settings.referenceA))))
            // Offered only when there is something to reset (a disabled button would be unreadable).
            if settings.referenceA != PitchMath.standardReferenceA {
                Button(.settingsReset) { settings.referenceA = PitchMath.standardReferenceA }
            }
        } header: {
            Text(.settingsCalibration)
                .foregroundStyle(Color.tuneSecondaryLabel)
        } footer: {
            Text(.settingsReferencePitchFooter)
                .foregroundStyle(Color.tuneSecondaryLabel)
        }
    }

    private var display: some View {
        Section {
            Picker(selection: $settings.notation) {
                Text(.notationAutomatic).tag(TunerSettings.NotationPreference.automatic)
                Text(.notationEnglish).tag(TunerSettings.NotationPreference.english)
                Text(.notationSolfege).tag(TunerSettings.NotationPreference.solfege)
            } label: {
                Text(.settingsNotation)
            }
            Picker(selection: $settings.gaugeStyle) {
                Text(.gaugeDial).tag(TunerSettings.GaugeStyle.dial)
                Text(.gaugeBar).tag(TunerSettings.GaugeStyle.bar)
            } label: {
                Text(.settingsGauge)
            }
            .pickerStyle(.segmented)
        } header: {
            Text(.settingsDisplay)
                .foregroundStyle(Color.tuneSecondaryLabel)
        }
    }

    private var feedback: some View {
        Section {
            Toggle(isOn: $settings.isHapticsEnabled) { Text(.settingsHaptics) }
        } header: {
            Text(.settingsFeedback)
                .foregroundStyle(Color.tuneSecondaryLabel)
        } footer: {
            Text(.settingsHapticsFooter)
                .foregroundStyle(Color.tuneSecondaryLabel)
        }
    }

    private var battery: some View {
        Section {
            Picker(selection: $settings.idleTimeout) {
                Text(.autostopNever).tag(TunerSettings.IdleTimeout.never)
                Text(.autostop1).tag(TunerSettings.IdleTimeout.oneMinute)
                Text(.autostop3).tag(TunerSettings.IdleTimeout.threeMinutes)
                Text(.autostop5).tag(TunerSettings.IdleTimeout.fiveMinutes)
            } label: {
                Text(.settingsAutoStop)
            }
        } header: {
            Text(.settingsBattery)
                .foregroundStyle(Color.tuneSecondaryLabel)
        } footer: {
            Text(.settingsAutoStopFooter)
                .foregroundStyle(Color.tuneSecondaryLabel)
        }
    }

    private var privacy: some View {
        Section {
            Label {
                Text(.settingsPrivacyBody)
            } icon: {
                Image(systemName: "lock.shield.fill").foregroundStyle(Color.accentColor)
            }
        } header: {
            Text(.settingsPrivacy)
                .foregroundStyle(Color.tuneSecondaryLabel)
        }
    }

    #if os(iOS)
    private var about: some View {
        Section {
            NavigationLink {
                AboutView()
            } label: {
                Text(.aboutTitle)
            }
            NavigationLink {
                LicenseView()
            } label: {
                Text(.aboutLicense)
            }
        } header: {
            Text(.settingsAbout)
                .foregroundStyle(Color.tuneSecondaryLabel)
        }
    }
    #endif
}
