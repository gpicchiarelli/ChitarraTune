import Foundation
import Synchronization

/// Turns system notifications into an `AsyncStream<Void>`.
///
/// The observers are registered while the stream is created, so a notification posted right after
/// is never lost, and they are removed when the consumer stops iterating. The observer tokens live
/// in a `Mutex`, so nothing needs `nonisolated(unsafe)`.
public enum SystemNotifications {
    /// - Parameter filter: decides from the notification's `userInfo` whether to emit.
    public static func changes(
        _ names: [Notification.Name],
        center: NotificationCenter = .default,
        where filter: @escaping @Sendable ([AnyHashable: Any]?) -> Bool = { _ in true }
    ) -> AsyncStream<Void> {
        AsyncStream(bufferingPolicy: .bufferingNewest(1)) { continuation in
            let observers = Mutex(names.map { name in
                center.addObserver(forName: name, object: nil, queue: nil) { note in
                    if filter(note.userInfo) { continuation.yield() }
                }
            })
            continuation.onTermination = { _ in
                observers.withLock { tokens in
                    for token in tokens { center.removeObserver(token) }
                    tokens.removeAll()
                }
            }
        }
    }
}
