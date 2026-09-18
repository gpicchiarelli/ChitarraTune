import SwiftUI
import TunerAudio
import TunerCore
import TunerFeature

/// One tuner: note readout, gauge, string chips and the listen button. Adapts to iPhone portrait
/// and landscape, iPad (any window size, Split View, Stage Manager) and resizable Mac windows.
struct TunerScreen: View {
    @Bindable var model: TunerModel

    @Environment(\.verticalSizeClass) private var verticalSizeClass
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.locale) private var locale
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    #if os(iOS)
    @State private var isShowingSettings = false
    #endif

    private var settings: TunerSettings { model.settings }
    private var notation: NoteNotation { settings.resolvedNotation(for: locale) }
    private var state: TuneState { TuneState(model.reading) }
    private var isLandscapePhone: Bool { verticalSizeClass == .compact }

    /// Note shown in the readout: the detected one, or the pinned string while waiting.
    private var displayedNote: Note? {
        if let reading = model.reading { return reading.note }
        if case .string(let index) = model.target { return model.tuning.strings[safe: index] }
        return nil
    }

    private var hint: LocalizedStringResource {
        if !model.isListening { return .tunerHintStopped }
        if case .string(let index) = model.target, let note = model.tuning.strings[safe: index] {
            return .tunerHintPinned(NoteParts(note, notation: notation).spoken)
        }
        return .tunerHintIdle
    }

    var body: some View {
        ZStack {
            TunerBackground(state: state)

            if let failure = model.failure {
                FailureView(failure: failure, model: model)
            } else {
                tuner
            }
        }
        .navigationTitle(Text(.appName))
        #if os(macOS)
        .navigationSubtitle(Text(model.tuning.id.title))
        #else
        .toolbarTitleDisplayMode(.inline)
        #endif
        .toolbar { toolbar }
        .focusedSceneValue(\.tuner, model)
        .task { await model.monitorEnvironment() }
        .task { await autostartIfRequested() }
        .onChange(of: model.isListening) { _, listening in PlatformSettings.setKeepScreenAwake(listening) }
        .onChange(of: scenePhase) { _, phase in
            #if os(iOS)
            // iOS may not record in the background: release the microphone once the app is really in the
            // background. `.inactive` is only a transient state (the microphone permission prompt, Control
            // Center, an incoming call banner); stopping there would cancel a start the user just asked for.
            if phase == .background { Task { await model.stop() } }
            #endif
        }
        .onChange(of: model.reading?.isInTune == true) { old, new in
            if new, !old { announceInTune() }
        }
        .onDisappear {
            PlatformSettings.setKeepScreenAwake(false)
            Task { await model.stop() }
        }
        .sensoryFeedback(.success, trigger: model.reading?.isInTune == true) { old, new in
            new && !old && settings.isHapticsEnabled
        }
        .sensoryFeedback(.selection, trigger: model.target) { _, _ in settings.isHapticsEnabled }
        .sensoryFeedback(.impact(weight: .light), trigger: model.isBusy) { _, _ in settings.isHapticsEnabled }
        #if os(iOS)
        .sheet(isPresented: $isShowingSettings) {
            NavigationStack {
                SettingsView(settings: settings)
                    .toolbar {
                        ToolbarItem(placement: .confirmationAction) {
                            Button(.settingsDone) { isShowingSettings = false }
                        }
                    }
            }
            .presentationDetents([.medium, .large])
        }
        #endif
    }

    // MARK: Layout

    @ViewBuilder
    private var tuner: some View {
        if isLandscapePhone {
            HStack(alignment: .center, spacing: 24) {
                display
                    .frame(maxWidth: .infinity)
                VStack(spacing: 16) {
                    controls
                    ListenButton(model: model)
                }
                .frame(maxWidth: 420)
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 8)
        } else {
            ScrollView {
                VStack(spacing: 20) {
                    display
                    controls
                }
                .frame(maxWidth: 640)
                .padding(.horizontal, 20)
                .padding(.top, 8)
                .padding(.bottom, 16)
                .frame(maxWidth: .infinity)
            }
            .scrollBounceBehavior(.basedOnSize)
            .safeAreaInset(edge: .bottom) {
                ListenButton(model: model)
                    .frame(maxWidth: 640)
                    .padding(.horizontal, 20)
                    .padding(.bottom, 8)
                    .padding(.top, 8)
                    .frame(maxWidth: .infinity)
            }
        }
    }

    /// Readout + gauge + level.
    private var display: some View {
        VStack(spacing: 14) {
            NoteReadout(note: displayedNote, notation: notation, reading: model.reading, state: state, hint: hint)
                .dynamicTypeSize(...DynamicTypeSize.accessibility2)

            gauge

            if model.didStopForInactivity {
                Label(.tunerNoticeInactivity, systemImage: "battery.100percent.bolt")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            LevelMeter(level: model.inputLevel, isActive: model.isListening)
        }
    }

    @ViewBuilder
    private var gauge: some View {
        Group {
            switch settings.gaugeStyle {
            case .dial: TunerDial(cents: model.reading?.cents, state: state)
            case .bar: TunerBar(cents: model.reading?.cents, state: state)
            }
        }
        .frame(maxWidth: 520)
        .overlay(alignment: .bottom) {
            HStack {
                Text(.gaugeFlatEnd)
                Spacer()
                Text(.gaugeSharpEnd)
            }
            .font(.title2.weight(.semibold))
            .foregroundStyle(.secondary)
            .padding(.horizontal, 4)
            .accessibilityHidden(true)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(.gaugeLabel))
        .accessibilityValue(Text(gaugeAccessibilityValue))
        .accessibilityAddTraits(.updatesFrequently)
    }

    private var controls: some View {
        VStack(spacing: 12) {
            HStack(spacing: 10) {
                TuningPicker(model: model, notation: notation)
                AutoChip(model: model)
            }
            StringSelector(model: model, notation: notation, state: state)
        }
    }

    private var gaugeAccessibilityValue: String {
        guard let reading = model.reading else { return String(localized: .a11YNoSignal) }
        let cents = abs(reading.displayedCents)
        if reading.isInTune { return String(localized: .tunerStatusInTune) }
        return reading.cents < 0 ? String(localized: .a11YCentsFlat(cents)) : String(localized: .a11YCentsSharp(cents))
    }

    // MARK: Toolbar

    @ToolbarContentBuilder
    private var toolbar: some ToolbarContent {
        #if os(iOS)
        ToolbarItem(placement: .topBarLeading) { InputMenu(model: model) }
        ToolbarItem(placement: .topBarTrailing) {
            Button(.settingsTitle, systemImage: "gearshape") { isShowingSettings = true }
                .accessibilityIdentifier("settingsButton")
        }
        #else
        ToolbarItem(placement: .primaryAction) { InputMenu(model: model) }
        #endif
    }

    // MARK: Actions

    private func announceInTune() {
        guard let note = model.reading?.note else { return }
        var announcement = AttributedString(String(localized: .a11YInTune(NoteParts(note, notation: notation).spoken)))
        announcement.accessibilitySpeechAnnouncementPriority = .high
        AccessibilityNotification.Announcement(announcement).post()
    }

    /// Demo / UI-test hook: `-autostart` begins listening without a tap.
    private func autostartIfRequested() async {
        if LaunchOptions.autostart, !model.isBusy { await model.start() }
    }
}

extension Array {
    fileprivate subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}

/// Thin input-level bar. Purely visual (hidden from accessibility); shows the mic is hearing you.
private struct LevelMeter: View {
    let level: Double
    let isActive: Bool

    var body: some View {
        Capsule()
            .fill(.quaternary)
            .frame(height: 4)
            .overlay(alignment: .leading) {
                GeometryReader { proxy in
                    Capsule()
                        .fill(Color.accentColor.opacity(0.8))
                        .frame(width: proxy.size.width * level)
                        .animation(.linear(duration: 0.08), value: level)
                }
            }
            .frame(maxWidth: 220)
            .opacity(isActive ? 1 : 0.35)
            .accessibilityHidden(true)
    }
}
