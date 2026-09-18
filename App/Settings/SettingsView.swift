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
            about
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
                    .foregroundStyle(.secondary)
            } label: {
                Text(.settingsReferencePitch)
            }
            Slider(value: $settings.referenceA, in: PitchMath.referenceARange, step: 1) {
                Text(.settingsReferencePitch)
            } minimumValueLabel: {
                Text(verbatim: "415")
            } maximumValueLabel: {
                Text(verbatim: "466")
            }
            .accessibilityValue(Text(.settingsReferencePitchValue(Int(settings.referenceA))))
            Button(.settingsReset) { settings.referenceA = PitchMath.standardReferenceA }
                .disabled(settings.referenceA == PitchMath.standardReferenceA)
        } header: {
            Text(.settingsCalibration)
        } footer: {
            Text(.settingsReferencePitchFooter)
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
        }
    }

    private var feedback: some View {
        Section {
            Toggle(isOn: $settings.isHapticsEnabled) { Text(.settingsHaptics) }
        } header: {
            Text(.settingsFeedback)
        } footer: {
            Text(.settingsHapticsFooter)
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
        } footer: {
            Text(.settingsAutoStopFooter)
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
        }
    }

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
        }
    }
}
