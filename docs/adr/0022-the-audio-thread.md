# ADR 0022: The audio thread

Status: Accepted (2026-09-21)

## Context

`EngineAudioCapture` installs a tap on `AVAudioEngine`'s input node. The block it installs runs on a thread the system schedules at real-time priority, with a deadline: a render cycle at 48 kHz and 1 024 frames is 21 ms, and work that does not finish inside it is a dropout the user hears as a click and the engine reads as a discontinuity.

The rest of this repository claims maximum conformance to Apple's canonical patterns, and this was the one place where the conformance was nominal. The tap block called `ChannelSelector.chunk(from:)`, which did three things a real-time thread is not supposed to do: it allocated a `[Float]` for the per-channel levels on every callback, it took a `Mutex` to read and write the channel being followed, and it allocated a second array for the samples. A malloc can take a lock inside the allocator; a `Mutex` can be held by a thread the scheduler has just preempted, and waiting for it is unbounded priority inversion. Neither had been observed to glitch — which is the usual state of this class of bug right up until it is observed on somebody else's machine, under load, once.

Nothing in the repository said what was allowed there, so nothing noticed when something new was added.

## Decision

1. The tap block and everything it calls MUST NOT allocate heap memory, except where rule 3 allows it. Scratch space is stack memory (`withUnsafeTemporaryAllocation`) or is allocated once, before the stream starts.
2. The tap block and everything it calls MUST NOT take a lock. State shared with other threads is atomic (`Synchronization.Atomic`), and the memory ordering is stated where it is used.
3. Exactly one allocation is permitted, and it is the one that carries the samples off this thread: `AudioChunk.samples`. A few kilobytes every 23 ms, and a buffer pool would move that copy rather than remove it — with a pool's own lifetime problem in exchange. `AsyncThrowingStream.Continuation.yield` takes the stream's internal lock and is accepted for the same reason: it is bounded, it never waits for the consumer (`.bufferingNewest(8)` drops instead), and the alternative is a lock-free ring buffer that this project would then have to prove.
4. The tap block MUST NOT log, format a string, or touch Foundation's date, locale or number machinery. Diagnostics about the stream are counted by the engine and reported from `TunerProcessor` (`StreamStatistics`), off this thread.
5. A change to any of this MUST say in its commit message which rule it touches and why the exception is bounded. Rules 1, 2 and 4 are checkable and are checked; rule 3 is a single named exception, and a second one is a decision, not a refactor.

## Consequences

- `ChannelSelector` keeps the channel it follows in an `Atomic<Int>` with relaxed ordering — one writer, one word — instead of a `Mutex<Int?>`, and measures the per-channel RMS into stack memory. `ChannelSelector.choose(rms:current:)` is generic over its storage so a caller may hand it either.
- The per-callback allocation count goes from two to one, and the lock count from two to one, and the one that remains is the one that carries the audio away.
- A future version that wants the last allocation gone changes `AudioChunk` and the capture-to-processor boundary together, which is a redesign with its own record, not a tweak inside the tap.
- The rule is the kind a reviewer forgets and a test does not, which is why rules 1, 2 and 4 are written as forbidden spellings rather than as good intentions.

## Enforcement

- `Packages/ChitarraTuneKit/Sources/TunerAudio/ChannelSelector.swift` holds the selector: stack scratch, one atomic, no lock.
- `Packages/ChitarraTuneKit/Tests/RepositoryPolicyTests/ArchitecturePolicyTests.swift` reads the tap block of `Packages/ChitarraTuneKit/Sources/TunerAudio/EngineAudioCapture.swift` and everything it calls, and refuses an allocation, a lock, a logger or a formatter in either.
- `Packages/ChitarraTuneKit/Tests/TunerFeatureTests/ChannelSelectorTests.swift` covers the selection rule itself, on both storages.
