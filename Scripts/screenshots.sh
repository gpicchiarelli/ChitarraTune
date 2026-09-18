#!/usr/bin/env bash
# App Store screenshots for iPhone 6.9", iPad 13" and Mac, in English and Italian, from the demo
# mode (synthetic guitar). Output: AppStore/screenshots/<language>/<device>/NN-name.png
#
#   Scripts/screenshots.sh                 every device and language
#   DEVICES="iPhone" LANGUAGES="it" Scripts/screenshots.sh
#
# Builds outside the repository (iCloud extended attributes under ~/Documents break code signing).
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
WORK="${SCREENSHOT_WORK:-$HOME/Library/Caches/ChitarraTune/screenshots}"
OUT="$ROOT/AppStore/screenshots"
DEVICES="${DEVICES:-iPhone iPad Mac}"
LANGUAGES="${LANGUAGES:-en it}"
IPHONE="${IPHONE_SIMULATOR:-iPhone 17 Pro Max}"   # 6.9" display, 1320 × 2868
IPAD="${IPAD_SIMULATOR:-iPad Pro 13-inch (M5)}"    # 13" display, 2064 × 2752
mkdir -p "$WORK"

prepare_simulator() {
  local name="$1" udid
  udid="$(xcrun simctl list devices available -j | python3 -c "
import json, sys
for runtime, devices in json.load(sys.stdin)['devices'].items():
    for d in devices:
        if d['name'] == sys.argv[1]: print(d['udid']); sys.exit()
" "$name")"
  [ -n "$udid" ] || { echo "error: no simulator named '$name'" >&2; exit 1; }
  xcrun simctl boot "$udid" 2>/dev/null || true
  xcrun simctl bootstatus "$udid" -b > /dev/null
  # Apple's marketing status bar: 9:41, full battery and signal.
  xcrun simctl status_bar "$udid" override --time "9:41" --batteryState charged --batteryLevel 100 \
    --wifiMode active --wifiBars 3 --cellularMode active --cellularBars 4 --operatorName ""
  xcrun simctl ui "$udid" appearance light
  echo "$udid"
}

run() {
  local device="$1" language="$2" destination signing=() bundle="$WORK/$1-$2.xcresult"
  case "$device" in
    iPhone) destination="platform=iOS Simulator,id=$(prepare_simulator "$IPHONE")"; signing=(CODE_SIGNING_ALLOWED=NO) ;;
    iPad)   destination="platform=iOS Simulator,id=$(prepare_simulator "$IPAD")"; signing=(CODE_SIGNING_ALLOWED=NO) ;;
    Mac)    destination="platform=macOS"; signing=(CODE_SIGN_IDENTITY=- CODE_SIGN_STYLE=Manual DEVELOPMENT_TEAM=) ;;
  esac
  rm -rf "$bundle"
  echo "▸ $device · $language"
  TEST_RUNNER_SCREENSHOTS=1 TEST_RUNNER_SCREENSHOT_LANGUAGE="$language" xcodebuild test \
    -project "$ROOT/ChitarraTune.xcodeproj" -scheme ChitarraTune -destination "$destination" \
    -derivedDataPath "$WORK/DerivedData-$device" -resultBundlePath "$bundle" \
    -only-testing:ChitarraTuneUITests/AppStoreScreenshots "${signing[@]}" -quiet

  local exported="$WORK/attachments-$device-$language" target="$OUT/$language/$device"
  rm -rf "$exported" "$target"
  mkdir -p "$exported" "$target"
  xcrun xcresulttool export attachments --path "$bundle" --output-path "$exported" > /dev/null
  python3 - "$exported" "$target" <<'PY'
import json, os, shutil, sys
exported, target = sys.argv[1], sys.argv[2]
for test in json.load(open(os.path.join(exported, "manifest.json"))):
    for attachment in test.get("attachments", []):
        name = attachment.get("suggestedHumanReadableName", "")
        stem = name.split("_0_")[0]
        if stem[:2].isdigit():
            shutil.copy(os.path.join(exported, attachment["exportedFileName"]), os.path.join(target, stem + ".png"))
PY
  if [ "$device" = "Mac" ]; then
    for image in "$target"/*.png; do swift "$ROOT/Scripts/compose-mac-screenshot.swift" "$image" "$image"; done
  fi
  ls "$target"
}

for device in $DEVICES; do
  for language in $LANGUAGES; do run "$device" "$language"; done
done
echo "Screenshots in $OUT"
