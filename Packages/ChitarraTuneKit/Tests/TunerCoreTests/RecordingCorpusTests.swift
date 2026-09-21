import Foundation
import Testing
@testable import TunerCore

/// Plays the recordings listed in `Fixtures/Recordings/manifest.json` through the tuning engine.
///
/// The files are read with a small WAV parser rather than an audio framework, so the test runs
/// anywhere the package builds. See `Fixtures/Recordings/README.md` to add recordings.
@Suite("Recorded guitar corpus")
struct RecordingCorpusTests {
    struct Entry: Decodable, CustomTestStringConvertible, Sendable {
        let file: String
        let tuning: String
        let string: Int
        let cents: Double
        let tolerance: Double
        let source: String
        /// A4 the string was tuned against, if not 440 Hz.
        let referenceA: Double?
        var testDescription: String { "\(file) — \(source)" }
    }

    static let directory: URL = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent()
        .appendingPathComponent("Fixtures/Recordings")

    static func entries() throws -> [Entry] {
        let data = try Data(contentsOf: directory.appendingPathComponent("manifest.json"))
        return try JSONDecoder().decode([Entry].self, from: data)
    }

    /// The corpus is empty, and an empty corpus is not a passing one.
    ///
    /// Every accuracy figure in this repository presently comes from `StringModel`, a generator this
    /// project wrote — and whose inharmonicity law, `f_k = k·f0·√(1 + B·k²)`, is the very law
    /// ``PitchDetector/refine(_:lowPassed:)`` exists to correct. The refinement is therefore checked
    /// against a signal that assumes the same physics as the correction: self-consistent, and not yet
    /// evidence about a real string. `docs/ACCURACY.md` says so in prose and
    /// `docs/RELEASE_READINESS.md` calls it blocker B1; this says it on every run instead.
    ///
    /// It is a known issue, not an expectation: the suite reports it, the gate stays honest, and the
    /// day a recording is added this test fails and whoever added it deletes the wrapper.
    @Test("The corpus holds at least one real recording")
    func corpusIsNotEmpty() throws {
        let entries = try Self.entries()
        withKnownIssue("no guitar has been recorded yet — Scripts/add-recording.sh, Fixtures/Recordings/README.md") {
            #expect(!entries.isEmpty, "the accuracy numbers rest on a synthetic string model alone")
        }
    }

    @Test("The manifest is valid and every listed file exists")
    func manifest() throws {
        for entry in try Self.entries() {
            #expect(FileManager.default.fileExists(atPath: Self.directory.appendingPathComponent(entry.file).path), "\(entry.file) is missing")
            let tuning = try #require(TuningID(rawValue: entry.tuning), "unknown tuning \(entry.tuning)")
            #expect((1...Tuning.tuning(for: tuning).stringCount).contains(entry.string))
            #expect(entry.tolerance > 0 && entry.tolerance <= 5)
            #expect(PitchMath.referenceARange.contains(entry.referenceA ?? PitchMath.standardReferenceA))
        }
    }

    /// `(try? entries()) ?? []` degrades to no cases rather than throwing, because an `arguments:`
    /// expression cannot throw. A manifest that will not parse would therefore be silence here — so it
    /// is not read here alone: ``manifest()`` and ``corpusIsNotEmpty()`` both call `entries()` with
    /// `try`, and either of them fails the suite before this one can quietly run zero times.
    @Test("Each recording reads as its string, within its tolerance", arguments: (try? entries()) ?? [])
    func recording(entry: Entry) throws {
        let audio = try WAV(contentsOf: Self.directory.appendingPathComponent(entry.file))
        let tuning = Tuning.tuning(for: try #require(TuningID(rawValue: entry.tuning)))
        var engine = TuningEngine(configuration: .init(tuning: tuning, referenceA: entry.referenceA ?? PitchMath.standardReferenceA))
        var readings: [TunerReading] = []
        for chunk in audio.samples.chunked(1_024) {
            if let reading = engine.process(chunk, sampleRate: audio.sampleRate)?.reading, !reading.isHeld {
                readings.append(reading)
            }
        }
        // Skip the attack: the first 300 ms of readings.
        let settled = Array(readings.dropFirst(Int(0.3 / EngineParameters.standard.hopDuration)))
        try #require(settled.count >= 10, "too few readings")
        #expect(settled.allSatisfy { $0.stringIndex == entry.string - 1 }, "wrong string")
        let errors = settled.map { abs($0.cents - entry.cents) }.sorted()
        let typical = errors[errors.count / 2]
        #expect(typical <= entry.tolerance, "typical error \(typical) ¢")
    }

    @Test("The WAV reader decodes 16-bit and float files")
    func wavReader() throws {
        let samples: [Float] = [0, 0.5, -0.5, 1]
        let float = try WAV(data: WAV.encode(samples, sampleRate: 48_000, float: true))
        #expect(float.sampleRate == 48_000)
        #expect(float.samples == samples)
        let integer = try WAV(data: WAV.encode(samples, sampleRate: 44_100, float: false))
        #expect(integer.sampleRate == 44_100)
        for (decoded, original) in zip(integer.samples, samples) { #expect(abs(decoded - original) < 1e-4) }
        #expect(throws: WAV.Failure.self) { try WAV(data: Data("not a wav".utf8)) }
    }
}

/// Minimal RIFF/WAVE reader: mono or multichannel (first channel kept), PCM 16-bit or float 32-bit.
struct WAV {
    enum Failure: Error { case notWAV, unsupported, truncated }

    let sampleRate: Double
    let samples: [Float]

    init(contentsOf url: URL) throws { try self.init(data: Data(contentsOf: url)) }

    init(data: Data) throws {
        let bytes = [UInt8](data)
        func u32(_ offset: Int) -> UInt32 {
            UInt32(bytes[offset]) | UInt32(bytes[offset + 1]) << 8 | UInt32(bytes[offset + 2]) << 16 | UInt32(bytes[offset + 3]) << 24
        }
        func u16(_ offset: Int) -> UInt16 { UInt16(bytes[offset]) | UInt16(bytes[offset + 1]) << 8 }
        func tag(_ offset: Int) -> String { String(bytes: bytes[offset..<offset + 4], encoding: .ascii) ?? "" }

        guard bytes.count >= 12, tag(0) == "RIFF", tag(8) == "WAVE" else { throw Failure.notWAV }
        var offset = 12
        struct Format { let code: UInt16, channels: Int, rate: Double, bits: Int }
        var format: Format?
        var payload: ArraySlice<UInt8>?
        while offset + 8 <= bytes.count {
            let size = Int(u32(offset + 4))
            let body = offset + 8
            guard body + size <= bytes.count else { throw Failure.truncated }
            switch tag(offset) {
            case "fmt ":
                format = Format(code: u16(body), channels: Int(u16(body + 2)), rate: Double(u32(body + 4)), bits: Int(u16(body + 14)))
            case "data":
                payload = bytes[body..<body + size]
            default: break
            }
            offset = body + size + (size & 1)
        }
        guard let format, let payload, format.channels > 0 else { throw Failure.notWAV }
        let stride = format.channels * format.bits / 8
        let data = Array(payload)
        var samples: [Float] = []
        samples.reserveCapacity(data.count / max(1, stride))
        var index = 0
        switch (format.code, format.bits) {
        case (1, 16):
            while index + stride <= data.count {
                let raw = Int16(bitPattern: UInt16(data[index]) | UInt16(data[index + 1]) << 8)
                samples.append(Float(raw) / 32_768)
                index += stride
            }
        case (3, 32):
            while index + stride <= data.count {
                let raw = UInt32(data[index]) | UInt32(data[index + 1]) << 8 | UInt32(data[index + 2]) << 16 | UInt32(data[index + 3]) << 24
                samples.append(Float(bitPattern: raw))
                index += stride
            }
        default:
            throw Failure.unsupported
        }
        sampleRate = format.rate
        self.samples = samples
    }

    /// Encodes mono samples as a WAV file (used by the reader's own test).
    static func encode(_ samples: [Float], sampleRate: Int, float: Bool) -> Data {
        var data = Data()
        func append32(_ value: UInt32) { withUnsafeBytes(of: value.littleEndian) { data.append(contentsOf: $0) } }
        func append16(_ value: UInt16) { withUnsafeBytes(of: value.littleEndian) { data.append(contentsOf: $0) } }
        let bits = float ? 32 : 16
        let payload = samples.count * bits / 8
        data.append(contentsOf: Array("RIFF".utf8)); append32(UInt32(36 + payload)); data.append(contentsOf: Array("WAVE".utf8))
        data.append(contentsOf: Array("fmt ".utf8)); append32(16)
        append16(float ? 3 : 1); append16(1); append32(UInt32(sampleRate)); append32(UInt32(sampleRate * bits / 8))
        append16(UInt16(bits / 8)); append16(UInt16(bits))
        data.append(contentsOf: Array("data".utf8)); append32(UInt32(payload))
        for sample in samples {
            if float { append32(sample.bitPattern) } else { append16(UInt16(bitPattern: Int16(max(-1, min(1, sample)) * 32_767))) }
        }
        return data
    }
}
