#!/usr/bin/env bash
# Runs the ChitarraTuneKit tests with coverage and fails if any module drops below its threshold.
#
# Thresholds live in Scripts/coverage-thresholds.json and only ever go UP: when coverage improves,
# raise the number in the same pull request. Hardware-facing code (TunerAudio) has a low floor
# because it needs a real microphone; everything else is held to a high one.
#
# Usage: Scripts/coverage-gate.sh [extra `swift test` arguments]
#        SCRATCH=/some/dir Scripts/coverage-gate.sh    (build somewhere other than .build)
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
PACKAGE="$ROOT/Packages/ChitarraTuneKit"
THRESHOLDS="$ROOT/Scripts/coverage-thresholds.json"
BUILD="${SCRATCH:-$PACKAGE/.build}"

swift test --package-path "$PACKAGE" --scratch-path "$BUILD" --enable-code-coverage "$@"

PROFDATA="$(find "$BUILD" -name default.profdata -print -quit)"
[ -n "$PROFDATA" ] || { echo "error: no coverage data was produced" >&2; exit 1; }

# Every test bundle links the modules it tests, so merge them all as objects.
OBJECTS=()
while IFS= read -r bundle; do
  name="$(basename "$bundle" .xctest)"
  [ -f "$bundle/Contents/MacOS/$name" ] && OBJECTS+=("$bundle/Contents/MacOS/$name")
done < <(find "$BUILD" -maxdepth 6 -name '*Tests.xctest' -type d)
[ "${#OBJECTS[@]}" -gt 0 ] || { echo "error: no test bundles found" >&2; exit 1; }

ARGS=("${OBJECTS[0]}")
for object in "${OBJECTS[@]:1}"; do ARGS+=(-object "$object"); done

xcrun llvm-cov export -format=text -instr-profile="$PROFDATA" "${ARGS[@]}" \
  -ignore-filename-regex='/Tests/|/\.build/' > "$BUILD/coverage.json"

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
if failed:
    print("\nCoverage gate FAILED:\n  " + "\n  ".join(failed), file=sys.stderr)
    sys.exit(1)
print("\nCoverage gate passed.")
PY
