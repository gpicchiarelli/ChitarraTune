#!/usr/bin/env bash
# Wraps ChitarraTune.app in the disk image Apple's packaging guide asks for: a UDIF read-only,
# zip-compressed (UDZO) image holding the app, a symlink to /Applications and a volume icon, no
# Finder or AppleScript step (ADR 0014). Never run as an Xcode build phase: the sandbox
# (ENABLE_USER_SCRIPT_SANDBOXING) would block the mount and the writes outside declared outputs.
#
#   Scripts/make-dmg.sh                              ad hoc, from the app Scripts/release-check.sh
#                                                     just built; every check that needs no certificate
#   Scripts/make-dmg.sh --app path/to/ChitarraTune.app --version 2.1.0 --output ChitarraTune-2.1.0.dmg
#                                                     wrap a specific app
#   Scripts/make-dmg.sh --identity "Developer ID Application: …" [--keychain PATH] \
#     [--notarize PROFILE | --notarize-key path/to/AuthKey.p8]
#                                                     also sign the image, and notarize + staple it
#   Scripts/make-dmg.sh --verify path/to.dmg [--signed] [--stapled]
#                                                     check an image someone else built
#
# A notarytool profile is created once with:
#   xcrun notarytool store-credentials PROFILE --apple-id you@example.com --team-id TEAMID
# --notarize-key needs ASC_API_KEY_ID and ASC_API_ISSUER_ID in the environment (what the release
# workflow uses, so it never stores a notarytool profile).
set -euo pipefail
source "$(dirname "$0")/lib/help.sh"

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

# The image's own code-signing identifier: prefixed by the app's bundle identifier, and equal to no
# bundle identifier in the product (Apple requires both; a name shared with the app would be wrong).
IDENTIFIER="com.chitarratune.app.dmg"

APP="" VERSION="" OUTPUT="" IDENTITY="" KEYCHAIN="" PROFILE="" KEY="" VERIFY="" SIGNED=false STAPLED=false
while [ $# -gt 0 ]; do
  case "$1" in
    --app) APP="${2:?}"; shift 2 ;;
    --version) VERSION="${2:?}"; shift 2 ;;
    --output) OUTPUT="${2:?}"; shift 2 ;;
    --identity) IDENTITY="${2:?}"; SIGNED=true; shift 2 ;;
    --keychain) KEYCHAIN="${2:?}"; shift 2 ;;
    --notarize) PROFILE="${2:?}"; shift 2 ;;
    --notarize-key) KEY="${2:?}"; shift 2 ;;
    --verify) VERIFY="${2:?}"; shift 2 ;;
    --signed) SIGNED=true; shift ;;
    --stapled) STAPLED=true; shift ;;
    *) sed -n '2,20p' "$0" | sed 's/^# \{0,1\}//'; exit 64 ;;
  esac
done
[ -n "$VERIFY" ] && [ -n "$APP" ] && { echo "error: --app and --verify are exclusive"; exit 64; }
[ -n "$PROFILE" ] && [ -n "$KEY" ] && { echo "error: --notarize and --notarize-key are exclusive"; exit 64; }
if [ -n "$PROFILE" ] || [ -n "$KEY" ]; then
  [ -n "$IDENTITY" ] || { echo "error: notarizing needs --identity (a Developer ID certificate)"; exit 64; }
  STAPLED=true
fi
if [ -n "$KEY" ]; then
  [ -n "${ASC_API_KEY_ID:-}" ] && [ -n "${ASC_API_ISSUER_ID:-}" ] \
    || { echo "error: --notarize-key needs ASC_API_KEY_ID and ASC_API_ISSUER_ID in the environment"; exit 64; }
fi

FAILURES=0
pass() { printf '  \033[32m✓\033[0m %s\n' "$1"; }
fail() { printf '  \033[31m✗ %s\033[0m\n' "$1"; FAILURES=$((FAILURES + 1)); }
note() { printf '  \033[33m•\033[0m %s\n' "$1"; }
check() { local label="$1"; shift; if "$@" >/dev/null 2>&1; then pass "$label"; else fail "$label"; fi; }
step() { printf '\n\033[1m▸ %s\033[0m\n' "$1"; }

# Outside the repository: folders synced by iCloud (~/Documents) gain extended attributes that break
# codesign, and a mount point has no business inside a working tree. Override with SCRATCH.
WORK="${SCRATCH:-$HOME/Library/Caches/ChitarraTune}/dmg"
STAGE="$WORK/stage"
MOUNT="$WORK/volume"

ATTACHED=false
detach() {
  hdiutil detach "$MOUNT" -quiet 2>/dev/null \
    || { sleep 2; hdiutil detach "$MOUNT" -force -quiet 2>/dev/null || true; }
  ATTACHED=false
}
cleanup() { if $ATTACHED; then detach; fi; :; }
trap cleanup EXIT INT TERM

# attach <image> [writable]
attach() {
  local image="$1" mode="${2:-readonly}"
  local flags=(-nobrowse -noverify -noautoopen -mountpoint "$MOUNT")
  [ "$mode" = writable ] || flags+=(-readonly)
  # Three attempts; the counter is never read, so it has no name.
  for _ in 1 2 3; do
    limited 120 hdiutil attach "$image" "${flags[@]}" >/dev/null 2>&1 \
      && { ATTACHED=true; return 0; }
    sleep 3
  done
  return 1
}

# Runs a command with a deadline, because a disk-image tool that hangs used to cost the whole job.
# macOS has no timeout(1). A killed command fails loudly with 124 instead of waiting for the CI
# timeout and leaving an orphaned process behind.
limited() {
  local seconds="$1"; shift
  "$@" & local pid=$! waited=0
  while kill -0 "$pid" 2>/dev/null; do
    if [ "$waited" -ge "$seconds" ]; then
      kill -9 "$pid" 2>/dev/null || true
      wait "$pid" 2>/dev/null || true
      echo "error: $1 did not finish within ${seconds}s" >&2
      return 124
    fi
    sleep 1
    waited=$((waited + 1))
  done
  wait "$pid"
}

# MARK: Volume icon (best effort: a missing icon or a missing tool must never fail the build)

volume_icon() {
  local destination="$1" source="App/Resources/Assets.xcassets/IconPreview.imageset/icon.png"
  local set="$WORK/VolumeIcon.iconset" size
  [ -f "$source" ] || { note "no icon source: the volume keeps the generic disk icon"; return 0; }
  rm -rf "$set"; mkdir -p "$set"
  for size in 16 32 128 256 512; do
    sips -z "$size" "$size" "$source" --out "$set/icon_${size}x${size}.png" >/dev/null 2>&1 \
      || { note "sips could not render the volume icon"; return 0; }
    sips -z "$((size * 2))" "$((size * 2))" "$source" --out "$set/icon_${size}x${size}@2x.png" >/dev/null 2>&1 \
      || { note "sips could not render the volume icon"; return 0; }
  done
  iconutil -c icns "$set" -o "$destination" >/dev/null 2>&1 || { note "iconutil could not build the .icns"; return 0; }
  # Finder shows .VolumeIcon.icns only when the folder carries the custom-icon Finder flag (bit
  # 0x0400 of com.apple.FinderInfo, bytes 9-10). SetFile ships with Xcode; xattr is the fallback.
  local folder; folder="$(dirname "$destination")"
  if command -v SetFile >/dev/null 2>&1; then
    SetFile -a C "$folder" 2>/dev/null || note "the custom-icon flag could not be set"
  else
    # com.apple.FinderInfo is 32 bytes (64 hex digits): bytes 0-7 are frRect (unused here), bytes
    # 8-9 are frFlags, bytes 10-31 are reserved. kHasCustomIcon is flag bit 0x0400.
    local finderFlags="0000000000000000" reserved
    finderFlags+="0400"
    reserved="$(printf '0%.0s' $(seq 1 44))"
    xattr -wx com.apple.FinderInfo "$finderFlags$reserved" "$folder" 2>/dev/null \
      || note "the custom-icon flag could not be set"
  fi
  :
}

# MARK: Build

if [ -z "$VERIFY" ]; then
  [ -n "$APP" ] || APP="${SCRATCH:-$HOME/Library/Caches/ChitarraTune}/release-check/Build/Products/Release/ChitarraTune.app"
  [ -d "$APP" ] || { echo "error: no app at $APP (run Scripts/release-check.sh first, or pass --app)"; exit 1; }
  [ -n "$VERSION" ] || VERSION="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$APP/Contents/Info.plist" 2>/dev/null || true)"
  [ -n "$VERSION" ] || { echo "error: could not read the app's version; pass --version"; exit 1; }
  VOLUME="ChitarraTune $VERSION"
  [ "${#VOLUME}" -le 27 ] || { echo "error: '$VOLUME' is longer than the 27-character HFS volume-name limit"; exit 1; }
  [ -n "$OUTPUT" ] || OUTPUT="$WORK/ChitarraTune-$VERSION.dmg"
  DMG="$OUTPUT"

  rm -rf "$WORK"
  mkdir -p "$STAGE" "$MOUNT"

  step "Staging"
  # ditto, never cp: cp -R resolves the Applications symlink (copying the whole folder into the
  # image) and drops the app's own stapled notarization ticket; ditto preserves both.
  ditto "$APP" "$STAGE/ChitarraTune.app"
  ln -s /Applications "$STAGE/Applications"
  volume_icon "$STAGE/.VolumeIcon.icns"
  pass "staged the app, an Applications symlink and the volume icon"

  step "Disk image"
  mkdir -p "$(dirname "$DMG")"
  rm -f "$DMG"
  # Not `hdiutil create -srcfolder`: it copies the folder through a private mount that never returns
  # on a CI runner or on a developer's Mac — half an hour of silence, the job's timeout, an orphaned
  # hdiutil. Nor `hdiutil makehybrid`, which is fast but writes Finder information into the bundle and
  # breaks its signature ("resource fork, Finder information, or similar detritus not allowed"), which
  # notarization would reject. So: a blank read-write image, `ditto` into it — keeping the symlink, the
  # extended attributes and the signature — then compressed read-only. Two seconds, and every step is
  # one this script already relies on elsewhere.
  #
  # `hdiutil create -size` and `hdiutil convert` warn that `diskutil image create` replaces them. It is
  # not used here on purpose: its own help says "Attach / Mount operations will take place during the
  # creation process", which is the mechanism that hangs. Attaching explicitly, as below, is what works.
  READ_WRITE="$WORK/read-write.dmg"
  KILOBYTES=$(( $(du -sk "$STAGE" | cut -f1) * 3 / 2 + 10240 ))
  limited 120 hdiutil create -size "${KILOBYTES}k" -fs HFS+ -volname "$VOLUME" \
    -layout SPUD -ov "$READ_WRITE" >/dev/null
  attach "$READ_WRITE" writable || { echo "error: could not mount the image being built"; exit 1; }
  ditto "$STAGE/" "$MOUNT/"
  detach
  limited 300 hdiutil convert "$READ_WRITE" -format UDZO -imagekey zlib-level=9 -o "$DMG" >/dev/null
  rm -f "$READ_WRITE"
  pass "created $DMG"

  step "Signature"
  SIGN=(codesign --force --sign "${IDENTITY:--}" --identifier "$IDENTIFIER")
  [ -n "$KEYCHAIN" ] && SIGN+=(--keychain "$KEYCHAIN")
  if $SIGNED; then SIGN+=(--timestamp); else SIGN+=(--timestamp=none); fi
  "${SIGN[@]}" "$DMG"
  pass "signed under $IDENTIFIER"

  if [ -n "$PROFILE" ] || [ -n "$KEY" ]; then
    step "Notarization"
    NOTARY=(xcrun notarytool submit "$DMG" --wait --timeout 30m --output-format json)
    if [ -n "$PROFILE" ]; then NOTARY+=(--keychain-profile "$PROFILE")
    else NOTARY+=(--key "$KEY" --key-id "$ASC_API_KEY_ID" --issuer "$ASC_API_ISSUER_ID"); fi
    RESULT="$("${NOTARY[@]}")"
    echo "$RESULT"
    grep -Eq '"status" *: *"Accepted"' <<< "$RESULT" && pass "accepted by the notary service" || fail "notarization not accepted"
    # Stapling rewrites the file: the checksum, the attestation and the upload must come after this.
    check "ticket stapled" xcrun stapler staple "$DMG"
  fi
  VERIFY="$DMG"
fi

# MARK: Verify

DMG="$VERIFY"
[ -f "$DMG" ] || { echo "error: no disk image at $DMG"; exit 1; }

step "Format"
# hdiutil's prose is localized (an Italian machine prints "Sola lettura", "Compresso"): read the plist.
FORMAT="$(hdiutil imageinfo -plist "$DMG" 2>/dev/null | plutil -extract Format raw -o - - 2>/dev/null || echo '?')"
[ "$FORMAT" = "UDZO" ] && pass "UDIF read-only, zip-compressed (UDZO)" || fail "format is '$FORMAT'; Apple requires UDZO"

step "Contents"
attach "$DMG" || { echo "error: could not mount $DMG"; exit 1; }
ENTRIES="$(ls "$MOUNT" | sort | tr '\n' ' ')"
[ "$ENTRIES" = "Applications ChitarraTune.app " ] \
  && pass "the volume holds the app and Applications, and nothing else" \
  || fail "the volume holds: $ENTRIES"
[ "$(readlink "$MOUNT/Applications" 2>/dev/null)" = "/Applications" ] \
  && pass "Applications is a symlink to /Applications" \
  || fail "Applications is not a symlink to /Applications (ditto preserves it, cp does not)"
check "no .DS_Store (no Finder ever touched this volume)" test ! -e "$MOUNT/.DS_Store"
if [ -f "$MOUNT/.VolumeIcon.icns" ]; then pass "volume icon present"; else note "no volume icon"; fi
# A glob, not `ls` piped into `grep`: this is the check that the shipped image carries nothing it
# should not, so it must hold for a filename of any shape.
HIDDEN=""
for entry in "$MOUNT"/.*; do
  [ -e "$entry" ] || continue
  case "$(basename "$entry")" in
  . | .. | .VolumeIcon.icns | .fseventsd | .Trashes) continue ;;
  *) HIDDEN="$HIDDEN$(basename "$entry") " ;;
  esac
done
[ -z "$HIDDEN" ] && pass "no unexpected hidden items" || fail "unexpected hidden items: $HIDDEN"

step "The app inside"
INNER="$MOUNT/ChitarraTune.app"
check "the app's signature verifies (deep, strict)" codesign --verify --deep --strict "$INNER"
INNER_VERSION="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$INNER/Contents/Info.plist" 2>/dev/null || true)"
case "${VERSION:-$INNER_VERSION}" in
  "$INNER_VERSION"|"$INNER_VERSION"-*) pass "the app inside is version $INNER_VERSION" ;;
  *) fail "the image says ${VERSION:-?}, the app inside says $INNER_VERSION" ;;
esac
if $STAPLED; then
  # The ticket travels inside the bundle too, so the app keeps working once dragged out, offline.
  check "the app carries its own stapled ticket" xcrun stapler validate "$INNER"
  check "Gatekeeper accepts the app" spctl --assess --type execute "$INNER"
fi
BUNDLES="$(find "$INNER" -name Info.plist -path '*/Contents/Info.plist' \
  -exec /usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' {} \; 2>/dev/null | sort -u)"
detach

step "Signature of the image"
check "the image's signature verifies" codesign --verify --strict "$DMG"
ACTUAL="$(codesign -dv --verbose=2 "$DMG" 2>&1 | sed -n 's/^Identifier=//p')"
[ "$ACTUAL" = "$IDENTIFIER" ] && pass "signing identifier $ACTUAL" || fail "signing identifier is '$ACTUAL', expected $IDENTIFIER"
case "$ACTUAL" in
  com.chitarratune.app.*) pass "prefixed by the app's bundle identifier" ;;
  *) fail "'$ACTUAL' is not prefixed by com.chitarratune.app" ;;
esac
if grep -qx "$ACTUAL" <<< "$BUNDLES"; then
  fail "'$ACTUAL' is also a bundle identifier in the product; it must be unique"
else
  pass "the identifier is no bundle identifier in the product ($(tr '\n' ' ' <<< "$BUNDLES"))"
fi
if $SIGNED; then
  AUTHORITY="$(codesign -dv --verbose=2 "$DMG" 2>&1 | sed -n 's/^Authority=//p' | head -n 1)"
  [[ "$AUTHORITY" == "Developer ID Application:"* ]] \
    && pass "signed by $AUTHORITY" || fail "signed by '$AUTHORITY', not a Developer ID Application certificate"
  codesign -dv --verbose=2 "$DMG" 2>&1 | grep -q '^Timestamp=' \
    && pass "secure timestamp" || fail "no secure timestamp (notarization rejects it)"
fi
if $STAPLED; then
  check "the image carries a stapled ticket (Gatekeeper is satisfied offline)" xcrun stapler validate "$DMG"
  note "Gatekeeper: $(spctl --status 2>&1)"
  check "Gatekeeper opens it" spctl --assess --type open --context context:primary-signature "$DMG"
fi

echo
if [ "$FAILURES" -gt 0 ]; then
  printf '\033[1;31m✗ %d check(s) failed\033[0m\n' "$FAILURES"
  exit 1
fi
printf '\033[1;32m✓ %s is ready%s\033[0m\n' "$(basename "$DMG")" "$($STAPLED && echo ", notarized and stapled")"
