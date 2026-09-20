import AVFoundation
import Testing
@testable import TunerAudio

@Suite("ChannelSelector")
struct ChannelSelectorTests {
    @Test("The first buffer picks the loudest channel")
    func firstPickIsLoudest() {
        #expect(ChannelSelector.choose(rms: [0.001, 0.2], current: nil) == 1)
        #expect(ChannelSelector.choose(rms: [0.2, 0.001], current: nil) == 0)
    }

    @Test("A guitar in input 2 is heard even though channel 0 is silent")
    func instrumentInputIsFound() {
        var current: Int?
        for levels: [Float] in [[0, 0], [0, 0.05], [0.0001, 0.12]] {
            current = ChannelSelector.choose(rms: levels, current: current)
        }
        #expect(current == 1)
    }

    @Test("Comparable levels never make the choice flip-flop")
    func hysteresis() {
        #expect(ChannelSelector.choose(rms: [0.12, 0.10], current: 1) == 1)
        #expect(ChannelSelector.choose(rms: [0.10, 0.19], current: 0) == 0)
    }

    @Test("A clearly louder channel takes over")
    func clearlyLouderWins() {
        #expect(ChannelSelector.choose(rms: [0.30, 0.10], current: 1) == 0)
    }

    @Test("Silence keeps the current channel")
    func silenceKeepsChoice() {
        #expect(ChannelSelector.choose(rms: [0, 0], current: 1) == 1)
        #expect(ChannelSelector.choose(rms: [1e-7, 0], current: 1) == 1)
    }

    @Test("Degenerate input is safe")
    func degenerate() {
        #expect(ChannelSelector.choose(rms: [], current: nil) == 0)
        #expect(ChannelSelector.choose(rms: [0.1], current: 5) == 0)
    }

    @Test("Real stereo buffer: signal on the second channel is selected")
    func realBuffer() throws {
        let format = try #require(AVAudioFormat(commonFormat: .pcmFormatFloat32, sampleRate: 44_100, channels: 2, interleaved: false))
        let buffer = try #require(AVAudioPCMBuffer(pcmFormat: format, frameCapacity: 1_024))
        buffer.frameLength = 1_024
        let data = try #require(buffer.floatChannelData)
        for frame in 0..<1_024 {
            data[0][frame] = 0
            data[1][frame] = Float(0.3 * sin(2 * Double.pi * 110 * Double(frame) / 44_100))
        }
        #expect(ChannelSelector().channel(in: buffer) == 1)
    }

    @Test("Mono buffers need no selection")
    func mono() throws {
        let format = try #require(AVAudioFormat(standardFormatWithSampleRate: 44_100, channels: 1))
        let buffer = try #require(AVAudioPCMBuffer(pcmFormat: format, frameCapacity: 256))
        buffer.frameLength = 256
        #expect(ChannelSelector().channel(in: buffer) == 0)
    }
}
