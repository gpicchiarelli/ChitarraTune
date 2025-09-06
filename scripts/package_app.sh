#!/usr/bin/env bash
set -euo pipefail

# Build and package ChitarraTune.app as a zip with version and checksum.
# Usage: scripts/package_app.sh [version]
# If version is omitted, uses the latest git tag (e.g., v1.2.3). The leading 'v' is stripped for CFBundleShortVersionString.

ROOT_DIR=$(cd "$(dirname "$0")/.." && pwd)
cd "$ROOT_DIR"

VERSION_REF="${1:-}"
if [[ -z "$VERSION_REF" ]]; then
  VERSION_REF="${GITHUB_REF_NAME:-}"
fi
if [[ -z "$VERSION_REF" ]]; then
  VERSION_REF="$(git describe --tags --abbrev=0 2>/dev/null || true)"
fi
if [[ -z "$VERSION_REF" ]]; then
  echo "ERROR: version not provided and no git tag found" >&2
  exit 1
fi

SHORT_VER="${VERSION_REF#v}"
COMMIT_SHORT="$(git rev-parse --short HEAD)"

echo "Building ChitarraTune.app (version: $SHORT_VER, commit: $COMMIT_SHORT)"

# Generate BuildInfo.swift from git (used by About panel)
OUT="Apps/Shared/Generated/VersionInfo.swift"
mkdir -p "$(dirname "$OUT")"
DESC="$(git describe --tags --dirty --always 2>/dev/null || git rev-parse --short HEAD 2>/dev/null || echo)"
DATE="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
cat > "$OUT" <<EOF
import Foundation
public enum BuildInfo {
    public static let gitTag: String = "${VERSION_REF}"
    public static let gitCommit: String = "${COMMIT_SHORT}"
    public static let gitDescribe: String = "${DESC}"
    public static let buildDate: String = "${DATE}"
}
EOF

# Resolve, test, and build
xcodebuild -resolvePackageDependencies -project ChitarraTune.xcodeproj
swift test --parallel --configuration release
xcodebuild -project ChitarraTune.xcodeproj -scheme "ChitarraTune" -configuration Release -derivedDataPath build -destination 'platform=macOS' CODE_SIGNING_ALLOWED=NO build

APP="build/Build/Products/Release/ChitarraTune.app"
test -d "$APP" || { echo "Build failed: .app not found" >&2; exit 1; }

# Stamp Info.plist inside the built app
PLIST="$APP/Contents/Info.plist"
/usr/libexec/PlistBuddy -c "Set :CFBundleShortVersionString $SHORT_VER" "$PLIST" || /usr/libexec/PlistBuddy -c "Add :CFBundleShortVersionString string $SHORT_VER" "$PLIST"
/usr/libexec/PlistBuddy -c "Set :CFBundleVersion $COMMIT_SHORT" "$PLIST" || /usr/libexec/PlistBuddy -c "Add :CFBundleVersion string $COMMIT_SHORT" "$PLIST"

# Try to sign locally for convenience (non-notarized)
if security find-identity -p codesigning -v >/dev/null 2>&1; then
  DEV_ID=$(security find-identity -p codesigning -v | awk -F '"' '/Apple Development/ {print $2; exit}')
  if [[ -n "$DEV_ID" ]]; then
    echo "Signing with Apple Development: $DEV_ID"
    codesign --force --deep --timestamp --options runtime \
             --entitlements Apps/macOS/ChitarraTune.entitlements \
             -s "$DEV_ID" "$APP" || true
  else
    echo "No Apple Development identity found; using ad-hoc signing"
    codesign --force --deep -s - "$APP" || true
  fi
  codesign --verify --deep --strict --verbose=2 "$APP" || true
fi

# Zip and checksum
ZIP_NAME="ChitarraTune-${SHORT_VER}-macOS.zip"
ditto -c -k --sequesterRsrc --keepParent "$APP" "$ZIP_NAME"
shasum -a 256 "$ZIP_NAME" > "$ZIP_NAME.sha256"

echo "Packaged: $ZIP_NAME"
echo "Checksum: $(cat "$ZIP_NAME.sha256")"
