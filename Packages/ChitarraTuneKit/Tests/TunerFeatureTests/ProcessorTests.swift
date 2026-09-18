import Foundation
import Synchronization
import Testing
import TunerAudio
import TunerCore
@testable import TunerFeature

@Suite("TunerProcessor")
struct ProcessorTests {
    private func chunks(_ samples: [Float]) -> [AudioChunk] {
        stride(from: 0, to: samples.count, by: 1_024).map {
            AudioChunk(samples: Array(samples[$0..<min($0 + 1_024, samples.count)]), sampleRate: 44_100, sampleTime: Int64($0))
        }
    }

    @Test("Analyses the capture stream off the main actor and ends with it")
    func analysesAndEnds() async throws {
        let processor = TunerProcessor(configuration: TunerConfiguration(), parameters: .standard)
        let (input, feed) = AsyncThrowingStream<AudioChunk, any Error>.makeStream()
        let frames = processor.frames(from: input)
        for chunk in chunks(pluckSamples(midi: 45, duration: 1)) { feed.yield(chunk) }
        feed.finish()
        var last: TunerFrame?
        for try await frame in frames { last = frame }
        #expect(last?.reading?.note.midi == 45)
    }

    @Test("A capture failure is passed through")
    func passesFailureThrough() async {
        let processor = TunerProcessor(configuration: TunerConfiguration(), parameters: .standard)
        let (input, feed) = AsyncThrowingStream<AudioChunk, any Error>.makeStream()
        let frames = processor.frames(from: input)
        feed.finish(throwing: CaptureFailure.interrupted)
        await #expect(throws: CaptureFailure.interrupted) { for try await _ in frames {} }
    }

    @Test("Configuration and power-profile updates take effect")
    func updates() async {
        let processor = TunerProcessor(configuration: TunerConfiguration(), parameters: .standard)
        await processor.update(configuration: TunerConfiguration(target: .string(1)), parameters: .standard)
        var efficient = EngineParameters.standard
        efficient.hopDuration = 0.045
        await processor.update(configuration: TunerConfiguration(target: .string(1)), parameters: efficient)
        var reading: TunerReading?
        for chunk in chunks(pluckSamples(midi: 45, duration: 1)) {
            if let frame = await processor.process(chunk) { reading = frame.reading ?? reading }
        }
        #expect(reading?.stringIndex == 1)
    }

    @Test("A slow consumer loses frames, not audio")
    func slowConsumer() async throws {
        let processor = TunerProcessor(configuration: TunerConfiguration(), parameters: .standard)
        let (input, feed) = AsyncThrowingStream<AudioChunk, any Error>.makeStream()
        let frames = processor.frames(from: input)
        for chunk in chunks(pluckSamples(midi: 45, duration: 2)) { feed.yield(chunk) }
        feed.finish()
        // The consumer starts late and reads slowly; however many frames it misses, it only ever
        // sees complete analyses, and the last one is still the note that was played.
        try await Task.sleep(for: .milliseconds(200))
        var received: [TunerFrame] = []
        for try await frame in frames {
            received.append(frame)
            try await Task.sleep(for: .milliseconds(20))
        }
        #expect(!received.isEmpty)
        #expect(received.last?.reading?.note.midi == 45)
    }
}

@Suite("SystemNotifications")
struct SystemNotificationsTests {
    private let name = Notification.Name("test.chitarratune.\(UUID().uuidString)")

    @Test("Emits for a registered notification posted right after creation")
    func emits() async {
        var changes = SystemNotifications.changes([name]).makeAsyncIterator()
        NotificationCenter.default.post(name: name, object: nil)
        #expect(await changes.next() != nil)
    }

    @Test("The filter decides from userInfo")
    func filters() async {
        var changes = SystemNotifications.changes([name]) { $0?["keep"] as? Bool == true }.makeAsyncIterator()
        NotificationCenter.default.post(name: name, object: nil, userInfo: ["keep": false])
        NotificationCenter.default.post(name: name, object: nil, userInfo: ["keep": true])
        #expect(await changes.next() != nil)
    }

    @Test("Ending the stream removes the observers")
    func unregisters() async {
        let center = NotificationCenter()
        let received = Mutex(0)
        let task = Task {
            for await _ in SystemNotifications.changes([name], center: center) { received.withLock { $0 += 1 } }
        }
        try? await Task.sleep(for: .milliseconds(20))
        task.cancel()
        await task.value
        center.post(name: name, object: nil)
        #expect(received.withLock { $0 } == 0)
    }
}
