# Recorded guitar corpus

Real recordings that `RecordingCorpusTests` plays through the tuning engine. The synthetic
`StringModel` covers inharmonicity, weak fundamentals, pick noise, hum and room noise, but only a
real instrument in a real room proves the tuner. Every recording added here becomes a regression
test.

## Adding a recording

ChitarraTune itself never records audio: use a separate recorder (Voice Memos, a DAW). Then

```bash
Scripts/add-recording.sh low-e.m4a --tuning standard --string 1 --cents 0 --source "Acoustic steel-string, iPhone 16 built-in microphone, quiet room"
```

By hand:

1. Tune the string with a reference you trust (a strobe tuner, or a tone generator and beats), then
   record one pluck of 2–4 seconds. Any microphone is fine; note which one.
2. Save it as a mono **WAV**, 16-bit integer or 32-bit float, 44.1 or 48 kHz. On a Mac:

   ```bash
   afconvert -f WAVE -d LEI16@48000 -c 1 input.m4a e2-iphone-mic.wav
   ```

3. Add an entry to `manifest.json`:

   ```json
   {
     "file": "e2-iphone-mic.wav",
     "tuning": "standard",
     "string": 1,
     "cents": 0,
     "tolerance": 3,
     "source": "Acoustic steel-string, iPhone 16 built-in microphone, quiet room"
   }
   ```

   `string` counts from 1 (low to high), `cents` is how far the string was from its target when
   recorded, according to the trusted reference, `tolerance` the largest accepted error of the
   typical settled reading, in cents. Add `"referenceA": 442` if the string was tuned against an A4
   other than 440 Hz.

Keep files short (a few hundred kilobytes); the repository ships them. Only add recordings you
have the right to publish under the project's license.
