#!/usr/bin/env bash
# Prints what each test cost, slowest first, from a result bundle a test run produced.
#
#   Scripts/test-timings.sh <bundle.xcresult>              the twenty slowest
#   Scripts/test-timings.sh <bundle.xcresult> --top 50     more of them
#   Scripts/test-timings.sh <bundle.xcresult> --all        every test
#
# On CI it also appends the table to the run summary, so the cost of the slowest job in the gate is
# visible on the run itself instead of being reconstructed by hand afterwards (ADR 0020).
#
# Durations in a result bundle are human strings in the runner's locale — "0,003s" here and "15 s"
# or "1m 30s" elsewhere — so they are parsed, not read as numbers.
set -euo pipefail
source "$(dirname "$0")/lib/help.sh"

BUNDLE=""
TOP=20
while [ "$#" -gt 0 ]; do
    case "$1" in
    --top) TOP="${2:?usage: --top N}"; shift 2 ;;
    --all) TOP=0; shift ;;
    -*) echo "error: unknown argument '$1' (try --help)" >&2; exit 1 ;;
    *) BUNDLE="$1"; shift ;;
    esac
done
[ -n "$BUNDLE" ] || { echo "error: give me a result bundle (try --help)" >&2; exit 1; }
[ -d "$BUNDLE" ] || { echo "error: '$BUNDLE' is not a result bundle" >&2; exit 1; }
[[ "$TOP" =~ ^[0-9]+$ ]] || { echo "error: --top takes a whole number" >&2; exit 1; }

xcrun xcresulttool get test-results tests --path "$BUNDLE" --format json \
    | TOP="$TOP" python3 -c '
import json, os, re, sys

def seconds(text):
    """"0,003s", "15 s", "1m 30s", "2h 1m 3s" → float. None when there is no duration."""
    if not text:
        return None
    total, found = 0.0, False
    for value, unit in re.findall(r"([0-9]+(?:[.,][0-9]+)?)\s*([hms])", text):
        total += float(value.replace(",", ".")) * {"h": 3600, "m": 60, "s": 1}[unit]
        found = True
    return total if found else None

tests = []
def walk(node, suite):
    name = node.get("name") or ""
    if node.get("nodeType") == "Test Case":
        cost = seconds(node.get("duration"))
        if cost is not None:
            tests.append((cost, suite, name, node.get("result") or ""))
    else:
        suite = name if node.get("nodeType") in ("Test Suite", "Unit test bundle", "UI test bundle") else suite
    for child in node.get("children", []):
        walk(child, suite)

for root in json.load(sys.stdin).get("testNodes", []):
    walk(root, "")

if not tests:
    print("No test durations in this bundle.")
    sys.exit(0)

tests.sort(reverse=True)
top = int(os.environ["TOP"])
shown = tests if top == 0 else tests[:top]
total = sum(cost for cost, _, _, _ in tests)

lines = [f"{len(tests)} tests, {total:.0f}s in total, slowest first:", "",
         "| Seconds | Share | Suite | Test | |", "| ---: | ---: | --- | --- | :---: |"]
for cost, suite, name, result in shown:
    share = 100 * cost / total if total else 0
    mark = "✅" if result == "Passed" else ("⏭️" if result == "Skipped" else "❌")
    lines.append(f"| {cost:.1f} | {share:.1f}% | {suite} | {name} | {mark} |")
if len(shown) < len(tests):
    rest = sum(cost for cost, _, _, _ in tests[len(shown):])
    lines.append(f"| {rest:.1f} | {100 * rest / total:.1f}% | | *the other {len(tests) - len(shown)}* | |")

report = "\n".join(lines)
print(report)
summary = os.environ.get("GITHUB_STEP_SUMMARY")
if summary:
    with open(summary, "a") as handle:
        handle.write("### Test timings\n" + report + "\n")
'
