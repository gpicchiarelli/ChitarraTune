import os

/// Central logging (Unified Logging) and tracing (signposts) for the whole app.
///
/// Conventions:
/// - One subsystem, one category per concern, so Console.app / `log stream` can filter precisely:
///   `log stream --predicate 'subsystem == "com.chitarratune.app"'`.
/// - Levels: `debug` for developer detail, `info` for lifecycle, `notice` for state the user caused,
///   `error` for recoverable failures, `fault` only for broken invariants.
/// - Privacy: audio content is never logged. Dynamic strings default to private; only enum names and
///   numeric codes are marked `.public`. Device names and UIDs stay `.private`.
public enum TunerLog {
    public static let subsystem = "com.chitarratune.app"

    /// Microphone capture, audio session and route changes.
    public static let capture = Logger(subsystem: subsystem, category: "capture")
    /// Session state machine of the tuner (start, stop, recovery, idle timeout).
    public static let tuner = Logger(subsystem: subsystem, category: "tuner")
    /// App Intents, Siri and Shortcuts.
    public static let intents = Logger(subsystem: subsystem, category: "intents")
    /// App lifecycle, windows and diagnostics.
    public static let app = Logger(subsystem: subsystem, category: "app")

    /// Signposts appear in Instruments ▸ Points of Interest (analysis duration, start-up latency).
    public static let signposter = OSSignposter(subsystem: subsystem, category: .pointsOfInterest)
}
