import AppIntents
import os
import SwiftUI
import TunerAudio
import TunerFeature

@main
struct ChitarraTuneApp: App {
    #if os(macOS)
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    #endif
    @State private var hub: TunerHub

    init() {
        let hub = LaunchOptions.isDemo ? TunerHub.demo(permission: LaunchOptions.demoPermission) : TunerHub.live()
        _hub = State(initialValue: hub)
        // Siri, Shortcuts and the Action Button reach the running tuner through this dependency.
        AppDependencyManager.shared.add(dependency: hub)
        #if os(macOS)
        AppDelegate.hub = hub
        #endif
        MetricsReporter.shared.start()
        TunerLog.app.info("launched \(BuildInfo.version, privacy: .public) (\(BuildInfo.build, privacy: .public)) demo=\(LaunchOptions.isDemo)")
    }

    var body: some Scene {
        #if os(macOS)
        // One window per tuner; the first uses the primary model, ⌘N opens more (own input and tuning).
        WindowGroup(Text(.appName), id: "tuner", for: UUID.self) { $id in
            TunerWindow(hub: hub, id: id)
        } defaultValue: {
            hub.primaryID
        }
        .defaultSize(width: 460, height: 800)
        .windowResizability(.contentMinSize)
        .commands { TunerCommands(hub: hub) }

        Settings {
            NavigationStack { SettingsView(settings: hub.settings) }
        }

        Window(Text(.aboutTitle), id: "about") {
            AboutView()
        }
        .windowResizability(.contentSize)
        .windowStyle(.hiddenTitleBar)

        Window(Text(.licenseTitle), id: "license") {
            LicenseView()
        }
        .windowResizability(.contentSize)
        #else
        WindowGroup {
            TunerWindow(hub: hub, id: hub.primaryID)
        }
        .commands { TunerCommands(hub: hub) }
        #endif
    }
}
