import SwiftUI

@main
struct ChitarraTuneApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .commands {
            CommandGroup(after: .help) {
                if let url = URL(string: "https://chitarratune.github.io") {
                    Link("ChitarraTune Help", destination: url)
                }
                if let lic = URL(string: "https://chitarratune.github.io/license.html") {
                    Link("License (BSD-3)", destination: lic)
                }
            }
        }
    }
}
