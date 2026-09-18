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
    @State private var sheet: Sheet?
    @State private var visibleHeight: CGFloat = 0

    private enum Sheet: Identifiable {
        /// Why the tuner needs the microphone, before the system prompt.
        case microphone
        #if os(iOS)
        case settings
        #endif

        var id: Self { self }
    }

    private var settings: TunerSettings { model.settings }
    private var notation: NoteNotation { settings.resolvedNotation(for: locale) }
    private var isLandscapePhone: Bool { verticalSizeClass == .compact }

    /// Note shown in the readout: the detected one, or the pinned string while waiting.
    private var displayedNote: Note? {
        if let note = model.detectedNote { return note }
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
            TunerBackground(state: model.tuneState)

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
        .onChange(of: model.isInTune) { old, new in
            if new, !old { announceInTune() }
        }
        .onDisappear {
            PlatformSettings.setKeepScreenAwake(false)
            Task { await model.stop() }
        }
        .sensoryFeedback(.success, trigger: model.isInTune) { old, new in
            new && !old && settings.isHapticsEnabled
        }
        .sensoryFeedback(.selection, trigger: model.target) { _, _ in settings.isHapticsEnabled }
        .sensoryFeedback(.impact(weight: .light), trigger: model.isBusy) { _, _ in settings.isHapticsEnabled }
        // One sheet modifier per view: SwiftUI presents only one of several stacked `.sheet`s.
        .sheet(item: $sheet) { sheet in
            switch sheet {
            case .microphone:
                MicrophonePrimer(
                    onContinue: {
                        self.sheet = nil
                        Task { await model.start() }
                    },
                    onCancel: { self.sheet = nil }
                )
            #if os(iOS)
            case .settings:
                NavigationStack {
                    SettingsView(settings: settings)
                        .toolbar {
                            ToolbarItem(placement: .topBarTrailing) {
                                Button(.settingsDone) { self.sheet = nil }
                                    .fontWeight(.semibold)
                            }
                        }
                }
            #endif
            }
        }
    }

    // MARK: Layout

    /// Centred when it fits; scrolls when it does not (large Dynamic Type, small windows, a phone
    /// on its side). One scroll view whose content is at least as tall as the screen, so the same
    /// views are always on screen whatever the text size.
    private var tuner: some View {
        ScrollView {
            Group {
                if isLandscapePhone {
                    HStack(alignment: .center, spacing: 24) {
                        display
                            .frame(maxWidth: .infinity)
                        VStack(spacing: 16) {
                            controls
                            ListenButton(model: model, start: start)
                        }
                        .frame(maxWidth: 420)
                    }
                    .padding(.horizontal, 24)
                    .padding(.vertical, 8)
                } else if dynamicTypeSize.isAccessibilitySize {
                    // At accessibility sizes the button is too tall to pin over the content.
                    VStack(spacing: 20) {
                        portraitContent
                        ListenButton(model: model, start: start)
                            .frame(maxWidth: 640)
                            .padding(.horizontal, 20)
                            .padding(.bottom, 16)
                    }
                } else {
                    portraitContent
                }
            }
            .frame(minHeight: visibleHeight)
        }
        .scrollBounceBehavior(.basedOnSize)
        // The height actually visible between the bars and the pinned button: content at least
        // this tall is centred, and only scrolls when it is taller.
        .onScrollGeometryChange(for: CGFloat.self) { geometry in
            geometry.containerSize.height - geometry.contentInsets.top - geometry.contentInsets.bottom
        } action: { _, height in
            visibleHeight = max(0, height)
        }
        .safeAreaInset(edge: .bottom) {
            if !isLandscapePhone, !dynamicTypeSize.isAccessibilitySize {
                ListenButton(model: model, start: start)
                    .frame(maxWidth: 640)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 8)
                    .frame(maxWidth: .infinity)
            }
        }
    }

    private var portraitContent: some View {
        VStack(spacing: 20) {
            Spacer(minLength: 0)
            display
            Spacer(minLength: 0)
            controls
        }
        .frame(maxWidth: 640)
        .padding(.horizontal, 20)
        .padding(.top, 8)
        .padding(.bottom, 16)
        .frame(maxWidth: .infinity)
    }

    /// Readout + gauge + level.
    private var display: some View {
        VStack(spacing: 14) {
            NoteReadout(model: model, note: displayedNote, notation: notation, hint: hint)

            GaugeView(model: model)

            if model.didStopForInactivity {
                Label(.tunerNoticeInactivity, systemImage: "battery.100percent.bolt")
                    .font(.footnote)
                    .foregroundStyle(Color.tuneSecondaryLabel)
                    .multilineTextAlignment(.center)
            }
            LevelMeter(model: model)
        }
    }

    private var controls: some View {
        VStack(spacing: 12) {
            let layout = dynamicTypeSize.isAccessibilitySize
                ? AnyLayout(VStackLayout(spacing: 10))
                : AnyLayout(HStackLayout(spacing: 10))
            layout {
                TuningPicker(model: model, notation: notation)
                AutoChip(model: model)
            }
            StringSelector(model: model, notation: notation)
        }
    }

    // MARK: Toolbar

    @ToolbarContentBuilder
    private var toolbar: some ToolbarContent {
        #if os(iOS)
        ToolbarItem(placement: .topBarLeading) { InputMenu(model: model) }
        ToolbarItem(placement: .topBarTrailing) {
            Button(.settingsTitle, systemImage: "gearshape") { sheet = .settings }
                .accessibilityIdentifier("settingsButton")
        }
        #else
        ToolbarItem(placement: .primaryAction) { InputMenu(model: model) }
        #endif
    }

    // MARK: Actions

    /// Explains the microphone before the first system prompt; afterwards starts straight away.
    private func start() {
        if model.needsMicrophonePermission {
            sheet = .microphone
        } else {
            Task { await model.start() }
        }
    }

    private func announceInTune() {
        guard let note = model.detectedNote else { return }
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
