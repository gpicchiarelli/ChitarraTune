#!/usr/bin/env bash
# Runs the ChitarraTuneKit tests with coverage and fails if any module drops below its threshold.
#
# Every module must be fully covered (Scripts/coverage-thresholds.json). The only code outside the
# measurement is the hardware boundary, Sources/TunerAudio/Hardware/: it drives the real microphone and
# Core Audio devices, so what it executes depends on the machine. See the README in that folder.
#
# The tests are compiled optimised (ADR 0018). They are numeric: the same suite takes three and a
# half minutes at -Onone and twenty-five seconds at -O, and the coverage it measures is line for line
# the same.
#
# The build tree is kept between runs: it is the one long-lived tree in the project, and the next
# run reuses it (ADR 0017 rule 2). `Scripts/clean-caches.sh` is what empties it.
#
# Usage: Scripts/coverage-gate.sh [extra `swift test` arguments]
#        SCRATCH=/some/dir Scripts/coverage-gate.sh    (build somewhere other than the cache)
#        CONFIGURATION=debug Scripts/coverage-gate.sh  (for a debugger, or to compare)
set -euo pipefail
source "$(dirname "$0")/lib/help.sh"

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
PACKAGE="$ROOT/Packages/ChitarraTuneKit"
THRESHOLDS="$ROOT/Scripts/coverage-thresholds.json"
# Never inside the working tree: iCloud stamps anything under ~/Documents with extended
# attributes that break code signing, and a second copy of the build belongs to nobody (ADR 0017).
BUILD="${SCRATCH:-$HOME/Library/Caches/ChitarraTune/kit-build}"

# Identical flags to the build step in Scripts/verify.sh and the `kit` job of ci.yml: SwiftPM plans a
# build per set of flags, so a single character of difference means compiling the package twice.
CONFIGURATION="${CONFIGURATION:-release}"
swift test --package-path "$PACKAGE" --scratch-path "$BUILD" \
  -c "$CONFIGURATION" -Xswiftc -enable-testing -Xswiftc -warnings-as-errors \
  --enable-code-coverage "$@"

# The newest, not the first: the build tree outlives the run (ADR 0017 rule 2), so a profile from
# an earlier one can still be sitting beside the one `swift test` has just written.
PROFDATA="$(find "$BUILD" -name default.profdata -exec stat -f '%m %N' {} + | sort -rn | head -n 1 | cut -d' ' -f2-)"
[ -n "$PROFDATA" ] || { echo "error: no coverage data was produced" >&2; exit 1; }

# Every test bundle links the modules it tests, so merge them all as objects.
OBJECTS=()
while IFS= read -r bundle; do
  name="$(basename "$bundle" .xctest)"
  [ -f "$bundle/Contents/MacOS/$name" ] && OBJECTS+=("$bundle/Contents/MacOS/$name")
done < <(find "$BUILD" -maxdepth 6 -name '*Tests.xctest' -type d)
[ "${#OBJECTS[@]}" -gt 0 ] || { echo "error: no test bundles found" >&2; exit 1; }

IGNORE='/Tests/|/\.build/|DerivedSources|/Sources/TunerAudio/Hardware/'

ARGS=("${OBJECTS[0]}")
for object in "${OBJECTS[@]:1}"; do ARGS+=(-object "$object"); done

xcrun llvm-cov export -format=text -instr-profile="$PROFDATA" "${ARGS[@]}" \
  -ignore-filename-regex="$IGNORE" > "$BUILD/coverage.json"

python3 - "$BUILD/coverage.json" "$THRESHOLDS" <<'PY'
import json, sys, collections, os

data = json.load(open(sys.argv[1]))["data"][0]["files"]
thresholds = json.load(open(sys.argv[2]))
lines = collections.defaultdict(lambda: [0, 0])
for entry in data:
    name = entry["filename"]
    if "/Sources/" not in name:
        continue
    module = name.split("/Sources/")[1].split("/")[0]
    summary = entry["summary"]["lines"]
    lines[module][0] += summary["covered"]
    lines[module][1] += summary["count"]

report = ["| Module | Coverage | Required | |", "| --- | ---: | ---: | :---: |"]
failed = []
for module in sorted(set(lines) | set(thresholds)):
    covered, total = lines.get(module, (0, 0))
    percent = 100 * covered / total if total else 0.0
    required = thresholds.get(module)
    ok = required is None or percent >= required
    report.append(f"| {module} | {percent:.1f}% ({covered}/{total}) | {required if required is not None else '–'}% | {'✅' if ok else '❌'} |")
    if not ok:
        failed.append(f"{module}: {percent:.1f}% < {required}%")
    if required is None:
        failed.append(f"{module}: has no threshold in Scripts/coverage-thresholds.json")

print("\n".join(report))
summary_path = os.environ.get("GITHUB_STEP_SUMMARY")
if summary_path:
    with open(summary_path, "a") as handle:
        handle.write("### Coverage\n" + "\n".join(report) + "\n")
print("\nExcluded (hardware boundary): Sources/TunerAudio/Hardware/")
if failed:
    # Lines that hold a region never executed, from the same export the percentages come from
    # (segments: line, column, count, has count, region entry, gap region).
    print("\nUncovered lines:", file=sys.stderr)
    for entry in data:
        name = entry["filename"]
        if "/Sources/" not in name or entry["summary"]["lines"]["covered"] == entry["summary"]["lines"]["count"]:
            continue
        source = open(name).read().splitlines()
        for number in sorted({s[0] for s in entry["segments"] if s[3] and s[2] == 0 and not s[5]}):
            print(f"  {name.split('/Sources/')[1]}:{number}  {source[number - 1].strip()[:100]}", file=sys.stderr)
    print("\nCoverage gate FAILED:\n  " + "\n  ".join(failed), file=sys.stderr)
    sys.exit(1)
print("\nCoverage gate passed.")
PY
