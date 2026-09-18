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
/// One instance belongs to one capture session. `channel(in:)` is called from the audio tap.
final class ChannelSelector: Sendable {
    /// A challenger must be this many times louder (RMS) than the current channel to take over (~6 dB).
    static let switchRatio: Float = 2
    /// Below this RMS a channel counts as silent; silence never triggers a switch.
    static let silenceFloor: Float = 1e-5

    private let current = Mutex<Int?>(nil)

    /// The channel of `buffer` to analyse. Mono buffers are returned without any work.
    func channel(in buffer: AVAudioPCMBuffer) -> Int {
        let count = Int(buffer.format.channelCount)
        guard count > 1, let data = buffer.floatChannelData, buffer.frameLength > 0 else { return 0 }
        let frames = vDSP_Length(buffer.frameLength)
        var levels = [Float](repeating: 0, count: count)
        for index in 0..<count {
            vDSP_rmsqv(data[index], 1, &levels[index], frames)
        }
        return current.withLock { state in
            let chosen = Self.choose(rms: levels, current: state)
            state = chosen
            return chosen
        }
    }

    /// Copies the active channel of `buffer` into a chunk; `nil` for an empty or non-float buffer.
    func chunk(from buffer: AVAudioPCMBuffer, sampleRate: Double) -> AudioChunk? {
        guard let channels = buffer.floatChannelData, buffer.frameLength > 0 else { return nil }
        let channel = channels[channel(in: buffer)]
        return AudioChunk(samples: Array(UnsafeBufferPointer(start: channel, count: Int(buffer.frameLength))), sampleRate: sampleRate)
    }

    /// Pure selection rule, separated so it can be tested without audio hardware.
    static func choose(rms: [Float], current: Int?) -> Int {
        guard let loudest = rms.indices.max(by: { rms[$0] < rms[$1] }) else { return 0 }
        guard let current, rms.indices.contains(current) else { return loudest }
        if rms[loudest] > silenceFloor, rms[loudest] > rms[current] * switchRatio { return loudest }
        return current
    }
}
