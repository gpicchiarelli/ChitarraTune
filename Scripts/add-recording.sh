#!/usr/bin/env bash
# Adds a real guitar recording to the corpus that RecordingCorpusTests plays through the engine.
#
#   Scripts/add-recording.sh <audio file> --cents <reference reading> --source "<guitar, mic, room>"
#                            [--tuning <id>] [--string <1–6, low to high>] [--a4 <Hz>] [--tolerance <cents>]
#
# --cents is the ground truth: how far a trusted reference (strobe tuner, tone generator and beats)
# said the string was from its target when it was recorded, e.g. 0 or -12.5. It is never taken from
# ChitarraTune itself: the corpus exists to check ChitarraTune against something else.
#
# Record with a separate recorder (Voice Memos, a DAW): ChitarraTune itself never records audio.
# A file named like standard-string2-A2-a440-48k-20260919-153012.wav gives tuning, string and A4;
# any other needs --tuning and --string. Anything but a mono WAV is converted to a mono 16-bit WAV.
set -euo pipefail
source "$(dirname "$0")/lib/help.sh"

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
CORPUS="$ROOT/Packages/ChitarraTuneKit/Tests/TunerCoreTests/Fixtures/Recordings"
TUNINGS="standard halfDown fullDown dropD dropC dadgad openD openG openE openA"

usage() { sed -n '2,13p' "$0" | sed 's/^# \{0,1\}//'; exit 64; }
fail() { echo "error: $*" >&2; exit 65; }

[ $# -ge 1 ] || usage
INPUT="$1"; shift
[ -f "$INPUT" ] || fail "no such file: $INPUT"
CENTS="" SOURCE="" TUNING="" STRING="" A4="" TOLERANCE="3"
while [ $# -gt 0 ]; do
  case "$1" in
    --cents) CENTS="${2:-}"; shift 2 ;;
    --source) SOURCE="${2:-}"; shift 2 ;;
    --tuning) TUNING="${2:-}"; shift 2 ;;
    --string) STRING="${2:-}"; shift 2 ;;
    --a4) A4="${2:-}"; shift 2 ;;
    --tolerance) TOLERANCE="${2:-}"; shift 2 ;;
    *) usage ;;
  esac
done

NAME="$(basename "$INPUT")"
if [[ "$NAME" =~ ^([A-Za-z]+)-string([1-6])-[A-Za-z0-9]+-a([0-9]+)-[0-9]+k-[0-9]{8}-[0-9]{6}\.wav$ ]]; then
  TUNING="${TUNING:-${BASH_REMATCH[1]}}"
  STRING="${STRING:-${BASH_REMATCH[2]}}"
  A4="${A4:-${BASH_REMATCH[3]}}"
fi

[ -n "$CENTS" ] || fail "--cents is required: the reading of a trusted reference tuner"
[ -n "$SOURCE" ] || fail "--source is required: guitar, microphone and room"
[[ "$CENTS" =~ ^[-+]?[0-9]+(\.[0-9]+)?$ ]] || fail "--cents must be a number"
[[ "$TOLERANCE" =~ ^[0-9]+(\.[0-9]+)?$ ]] || fail "--tolerance must be a number"
[[ " $TUNINGS " == *" $TUNING "* ]] || fail "--tuning must be one of: $TUNINGS"
[[ "$STRING" =~ ^[1-6]$ ]] || fail "--string must be 1–6 (1 = lowest)"
A4="${A4:-440}"
[[ "$A4" =~ ^[0-9]+(\.[0-9]+)?$ ]] || fail "--a4 must be a number"

STEM="${NAME%.*}"
DEST="$CORPUS/$STEM.wav"
[ -e "$DEST" ] && fail "$DEST already exists"
if [[ "$NAME" == *.wav ]] && afinfo "$INPUT" | grep -q "1 ch"; then
  cp "$INPUT" "$DEST"
else
  afconvert -f WAVE -d LEI16 -c 1 "$INPUT" "$DEST"
fi

python3 - "$CORPUS/manifest.json" "$STEM.wav" "$TUNING" "$STRING" "$CENTS" "$TOLERANCE" "$SOURCE" "$A4" <<'PY'
import json, sys
path, file, tuning, string, cents, tolerance, source, a4 = sys.argv[1:]
with open(path) as f:
    entries = json.load(f)
entry = {"file": file, "tuning": tuning, "string": int(string), "cents": float(cents),
         "tolerance": float(tolerance), "source": source}
if float(a4) != 440:
    entry["referenceA"] = float(a4)
entries.append(entry)
with open(path, "w") as f:
    json.dump(entries, f, indent=2, ensure_ascii=False)
    f.write("\n")
print(json.dumps(entry, ensure_ascii=False))
PY

echo "Added $DEST ($(du -h "$DEST" | cut -f1 | tr -d ' ')). Running the corpus tests:"
swift test --package-path "$ROOT/Packages/ChitarraTuneKit" \
  --scratch-path "${SCRATCH:-$HOME/Library/Caches/ChitarraTune/kit-build}" --filter RecordingCorpusTests

# The recording and its manifest entry are the artifact; the build tree the tests needed is not.
[ "${KEEP_BUILD:-0}" = "1" ] || rm -rf "${SCRATCH:-$HOME/Library/Caches/ChitarraTune/kit-build}"
