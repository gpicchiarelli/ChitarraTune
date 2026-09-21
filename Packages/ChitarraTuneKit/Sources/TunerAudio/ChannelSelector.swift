import Accelerate
import AVFoundation
import Synchronization

/// Chooses which channel of a multichannel input the tuner listens to.
///
/// Audio interfaces expose their inputs as channels of a single stream, and a guitar is usually in
/// the instrument input (often input 2), not in channel 0. Reading a fixed channel would hear silence.
/// The selector follows the loudest channel and only switches when another one is clearly louder, so a
/// note is never spliced together from two different signals.
///
/// One instance belongs to one capture session. `channel(in:)` is called from the audio tap, and
/// everything here is written for that thread: see `docs/adr/0022-the-audio-thread-s-contract.md`.
final class ChannelSelector: Sendable {
    /// A challenger must be this many times louder (RMS) than the current channel to take over (~6 dB).
    static let switchRatio: Float = 2
    /// Below this RMS a channel counts as silent; silence never triggers a switch.
    static let silenceFloor: Float = 1e-5

    /// No channel has been chosen yet.
    static let noChannel = -1
    /// The channel being followed. An atomic, not a lock: this is read and written on the audio
    /// thread, and a lock there can be held by a thread the scheduler has just preempted, which is
    /// how a render cycle is missed (ADR 0022 rule 2). One writer, one word, relaxed is enough.
    private let current = Atomic<Int>(ChannelSelector.noChannel)

    /// The channel of `buffer` to analyse. Mono buffers are returned without any work.
    func channel(in buffer: AVAudioPCMBuffer) -> Int {
        let count = Int(buffer.format.channelCount)
        guard count > 1, let data = buffer.floatChannelData, buffer.frameLength > 0 else { return 0 }
        let frames = vDSP_Length(buffer.frameLength)
        let previous = current.load(ordering: .relaxed)
        // Stack memory for a handful of floats. `[Float](repeating:count:)` here was a malloc on
        // every callback, on the one thread that must never wait for an allocator (ADR 0022 rule 1).
        let chosen = withUnsafeTemporaryAllocation(of: Float.self, capacity: count) { levels in
            for index in 0..<count { vDSP_rmsqv(data[index], 1, &levels[index], frames) }
            return Self.choose(rms: levels, current: previous == Self.noChannel ? nil : previous)
        }
        current.store(chosen, ordering: .relaxed)
        return chosen
    }

    /// Copies the active channel of `buffer` into a chunk; `nil` for an empty or non-float buffer.
    ///
    /// The one allocation the tap makes, and the one it cannot avoid: the samples leave this thread
    /// as a value, and `[Float]` is what carries them. It is a few kilobytes every 23 ms, and a pool
    /// would move the copy rather than remove it (ADR 0022 rule 3).
    func chunk(from buffer: AVAudioPCMBuffer, sampleRate: Double, sampleTime: Int64? = nil) -> AudioChunk? {
        guard let channels = buffer.floatChannelData, buffer.frameLength > 0 else { return nil }
        let channel = channels[channel(in: buffer)]
        return AudioChunk(
            samples: Array(UnsafeBufferPointer(start: channel, count: Int(buffer.frameLength))),
            sampleRate: sampleRate,
            sampleTime: sampleTime
        )
    }

    /// Pure selection rule, separated so it can be tested without audio hardware. Generic over the
    /// storage so the caller may hand it stack memory instead of an array.
    static func choose<Levels>(rms: Levels, current: Int?) -> Int
    where Levels: RandomAccessCollection, Levels.Element == Float, Levels.Index == Int {
        guard let loudest = rms.indices.max(by: { rms[$0] < rms[$1] }) else { return 0 }
        guard let current, rms.indices.contains(current) else { return loudest }
        if rms[loudest] > silenceFloor, rms[loudest] > rms[current] * switchRatio { return loudest }
        return current
    }
}
