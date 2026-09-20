#!/usr/bin/env bash
# Builds the Mac app exactly as a release does and checks it the way notarization and App Review
# would, so that release day holds no surprise (ADR 0013).
#
#   Scripts/release-check.sh                         Release build, ad-hoc signed, every check
#   Scripts/release-check.sh --identity "Developer ID Application: …" [--notarize PROFILE]
#                                                    signed with your certificate; with a notarytool
#                                                    keychain profile it is also notarized and stapled
#   Scripts/release-check.sh --verify path/to/ChitarraTune.app [--signed]
#                                                    checks an app someone else built (the release
#                                                    workflow does this with its own build)
#
# A notarytool profile is created once with:
#   xcrun notarytool store-credentials PROFILE --apple-id you@example.com --team-id TEAMID
set -euo pipefail
source "$(dirname "$0")/lib/help.sh"

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"
IDENTITY="" PROFILE="" VERIFY="" SIGNED=false
while [ $# -gt 0 ]; do
  case "$1" in
    --identity) IDENTITY="${2:?}"; SIGNED=true; shift 2 ;;
    --notarize) PROFILE="${2:?}"; shift 2 ;;
    --verify) VERIFY="${2:?}"; shift 2 ;;
    --signed) SIGNED=true; shift ;;
    *) sed -n '2,15p' "$0" | sed 's/^# \{0,1\}//'; exit 64 ;;
  esac
done
[ -n "$PROFILE" ] && [ -z "$IDENTITY" ] && { echo "error: --notarize needs --identity (a Developer ID certificate)"; exit 64; }

FAILURES=0
pass() { printf '  \033[32m✓\033[0m %s\n' "$1"; }
fail() { printf '  \033[31m✗ %s\033[0m\n' "$1"; FAILURES=$((FAILURES + 1)); }
check() { local label="$1"; shift; if "$@" >/dev/null 2>&1; then pass "$label"; else fail "$label"; fi; }
step() { printf '\n\033[1m▸ %s\033[0m\n' "$1"; }

# MARK: Build

if [ -z "$VERIFY" ]; then
  # Outside the repository: iCloud-synced folders add extended attributes that break codesign.
  BUILD="${SCRATCH:-$HOME/Library/Caches/ChitarraTune}/release-check"
  rm -rf "$BUILD"
  step "Release build (every architecture, pointer authentication, as the release workflow)"
  SIGNING=(CODE_SIGN_STYLE=Manual CODE_SIGN_IDENTITY=- DEVELOPMENT_TEAM= PROVISIONING_PROFILE_SPECIFIER=)
  if $SIGNED; then
    SIGNING=(CODE_SIGN_STYLE=Manual "CODE_SIGN_IDENTITY=$IDENTITY" "OTHER_CODE_SIGN_FLAGS=--timestamp" PROVISIONING_PROFILE_SPECIFIER=)
  fi
  xcodebuild -project ChitarraTune.xcodeproj -scheme ChitarraTune -configuration Release \
    -destination 'generic/platform=macOS' -derivedDataPath "$BUILD" \
    ENABLE_POINTER_AUTHENTICATION=YES ENABLE_HARDENED_RUNTIME=YES \
    GCC_TREAT_WARNINGS_AS_ERRORS=YES \
    GIT_COMMIT="$(git rev-parse --short HEAD)" "${SIGNING[@]}" build > "$BUILD.log" 2>&1 \
    || { tail -n 30 "$BUILD.log"; echo "error: the Release build failed (log: $BUILD.log)"; exit 1; }
  pass "built ($BUILD.log)"
  VERIFY="$BUILD/Build/Products/Release/ChitarraTune.app"
fi

APP="$VERIFY"
EXT="$APP/Contents/PlugIns/ChitarraTuneControls.appex"
[ -d "$APP" ] || { echo "error: no app at $APP"; exit 1; }
PLIST="$APP/Contents/Info.plist"
EXT_PLIST="$EXT/Contents/Info.plist"
value() { /usr/libexec/PlistBuddy -c "Print :$2" "$1" 2>/dev/null; }

# MARK: Bundle

step "Bundle"
check "the Controls extension is embedded" test -d "$EXT"
[ "$(value "$PLIST" CFBundleIdentifier)" = "com.chitarratune.app" ] && pass "bundle identifier com.chitarratune.app" || fail "bundle identifier is $(value "$PLIST" CFBundleIdentifier)"
[ "$(value "$EXT_PLIST" CFBundleIdentifier)" = "com.chitarratune.app.controls" ] && pass "extension identifier is prefixed by the app's" || fail "extension identifier is $(value "$EXT_PLIST" CFBundleIdentifier)"
VERSION="$(value "$PLIST" CFBundleShortVersionString)"
[[ "$VERSION" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] && pass "marketing version $VERSION" || fail "marketing version '$VERSION' is not X.Y.Z"
[ "$VERSION" = "$(value "$EXT_PLIST" CFBundleShortVersionString)" ] && [ "$(value "$PLIST" CFBundleVersion)" = "$(value "$EXT_PLIST" CFBundleVersion)" ] \
  && pass "app and extension carry the same version and build" || fail "app and extension versions differ"
[[ "$(value "$PLIST" CFBundleVersion)" =~ ^[0-9]+(\.[0-9]+){0,2}$ ]] && pass "build number $(value "$PLIST" CFBundleVersion)" || fail "build number is not numeric"
# The minimum is read from the one file that states it, never repeated here: a release must not be
# able to pass this check while the build settings say something else.
MINIMUM="$(sed -n 's/^MACOSX_DEPLOYMENT_TARGET = //p' "$ROOT/Config/Base.xcconfig" | tr -d ' ')"
[ -n "$MINIMUM" ] || fail "Config/Base.xcconfig does not state MACOSX_DEPLOYMENT_TARGET"
[ "$(value "$PLIST" LSMinimumSystemVersion)" = "$MINIMUM" ] && pass "minimum macOS $MINIMUM" || fail "LSMinimumSystemVersion is $(value "$PLIST" LSMinimumSystemVersion), build settings say $MINIMUM"
[ "$(value "$PLIST" LSApplicationCategoryType)" = "public.app-category.music" ] && pass "App Store category: music" || fail "category is $(value "$PLIST" LSApplicationCategoryType)"
[ "$(value "$PLIST" ITSAppUsesNonExemptEncryption)" = "false" ] && pass "export compliance: no non-exempt encryption" || fail "ITSAppUsesNonExemptEncryption is not false"
[ -n "$(value "$PLIST" NSMicrophoneUsageDescription)" ] && pass "microphone purpose string" || fail "NSMicrophoneUsageDescription is missing"
[ -n "$(value "$PLIST" NSHumanReadableCopyright)" ] && pass "copyright" || fail "NSHumanReadableCopyright is missing"
[ "$(value "$PLIST" ChitarraGitCommit)" != "dev" ] && pass "records its commit ($(value "$PLIST" ChitarraGitCommit))" || fail "ChitarraGitCommit was not set"
check "privacy manifest in the bundle" test -f "$APP/Contents/Resources/PrivacyInfo.xcprivacy"
check "app icon compiled" test -f "$APP/Contents/Resources/Assets.car"
for language in en it; do
  check "localised: $language" test -d "$APP/Contents/Resources/$language.lproj"
done
MICROPHONE_IT="$(plutil -extract NSMicrophoneUsageDescription raw "$APP/Contents/Resources/it.lproj/InfoPlist.strings" 2>/dev/null || true)"
[ -n "$MICROPHONE_IT" ] && pass "microphone purpose string in Italian" || fail "no Italian microphone purpose string"

# MARK: User guide

step "User guide (Help Book, ADR 0015)"
HELP="$APP/Contents/Resources/ChitarraTune.help"
check "the Help Book is in the app" test -f "$HELP/Contents/Info.plist"
[ "$(value "$PLIST" CFBundleHelpBookName)" = "$(value "$HELP/Contents/Info.plist" CFBundleIdentifier)" ] \
  && pass "the app names the book it ships ($(value "$PLIST" CFBundleHelpBookName))" || fail "CFBundleHelpBookName does not match the Help Book"
for language in en it; do
  check "$language: pages and search index" test -f "$HELP/Contents/Resources/$language.lproj/index.html" -a -s "$HELP/Contents/Resources/$language.lproj/ChitarraTune.cshelpindex"
done
grep -rqE '(src|href)="https?:' "$HELP" && fail "the Help Book loads something from the network" || pass "the Help Book is entirely offline"

# MARK: Binaries

step "Binaries"
for binary in "$APP/Contents/MacOS/ChitarraTune" "$EXT/Contents/MacOS/ChitarraTuneControls"; do
  name="$(basename "$binary")"
  archs="$(lipo -archs "$binary")"
  # Apple silicon only: at a macOS 27 deployment target Xcode's standard architectures are arm64 and
  # arm64e, and no Intel Mac reaches that system version, so an x86_64 slice would be weight nobody can
  # run. It is not merely absent — it must stay absent, or the app carries a slice it cannot be used on.
  for arch in arm64e arm64; do
    grep -qw "$arch" <<< "$archs" && pass "$name: $arch" || fail "$name lacks $arch ($archs)"
  done
  grep -qw x86_64 <<< "$archs" && fail "$name carries an x86_64 slice no macOS 27 Mac can run" \
    || pass "$name: no Intel slice"
  outside="$(otool -L "$binary" | tail -n +2 | awk '{print $1}' | grep -Ev '^(/System/Library/|/usr/lib/)' || true)"
  [ -z "$outside" ] && pass "$name links only system libraries" || fail "$name links $outside"
done
if [ -n "$(find "$(dirname "$APP")" -maxdepth 1 -name 'ChitarraTune.app.dSYM' -print -quit)" ]; then
  pass "debug symbols (dSYM) produced"
else
  fail "no ChitarraTune.app.dSYM next to the app"
fi

# MARK: Signature and entitlements

step "Signature and entitlements"
check "signature verifies (deep, strict)" codesign --verify --deep --strict "$APP"
entitlements() { codesign -d --entitlements - --xml "$1" 2>/dev/null | plutil -convert json -o - - 2>/dev/null || echo "{}"; }
if ! $SIGNED; then
  # Xcode never applies the Hardened Runtime to an ad-hoc signature, so check the setting that makes
  # it apply to a real one, for both targets.
  for target in ChitarraTune ChitarraTuneControls; do
    xcodebuild -project ChitarraTune.xcodeproj -target "$target" -configuration Release -sdk macosx -showBuildSettings 2>/dev/null \
      | grep -Eq '^ *ENABLE_HARDENED_RUNTIME = YES$' \
      && pass "$target: Hardened Runtime enabled (applied when signed with a certificate)" \
      || fail "$target: ENABLE_HARDENED_RUNTIME is not YES"
  done
fi
for bundle in "$APP" "$EXT"; do
  name="$(basename "$bundle")"
  if $SIGNED; then
    codesign -dv "$bundle" 2>&1 | grep -Eq 'flags=.*runtime' && pass "$name: Hardened Runtime" || fail "$name: Hardened Runtime is off"
  fi
  granted="$(entitlements "$bundle" | python3 -c 'import json,sys; d=json.load(sys.stdin); print("\n".join(f"{k}={json.dumps(v)}" for k,v in sorted(d.items())))')"
  # Exactly what ADR 0003 allows; the team-issued identifiers appear only in team-signed builds.
  expected="com.apple.security.app-sandbox=true
com.apple.security.hardened-process=true
com.apple.security.hardened-process.dyld-ro=true
com.apple.security.hardened-process.enhanced-security-version-string=\"2\"
com.apple.security.hardened-process.hardened-heap=true
com.apple.security.hardened-process.platform-restrictions-string=\"2\""
  [ "$name" = "ChitarraTune.app" ] && expected="$(printf '%s\ncom.apple.security.device.audio-input=true' "$expected" | sort)"
  actual="$(grep -Ev '^com\.apple\.(application-identifier|developer\.team-identifier)=' <<< "$granted" | sort)"
  if [ "$actual" = "$(sort <<< "$expected")" ]; then
    pass "$name: entitlements are exactly the allowed set"
  else
    fail "$name: entitlements differ from ADR 0003"
    diff <(sort <<< "$expected") <(echo "$actual") | sed 's/^/      /' || true
  fi
  grep -q "get-task-allow" <<< "$granted" && fail "$name: get-task-allow (a debugging entitlement) is present" || pass "$name: no get-task-allow"
done
if $SIGNED; then
  AUTHORITY="$(codesign -dv --verbose=2 "$APP" 2>&1 | sed -n 's/^Authority=//p' | head -n 1)"
  [[ "$AUTHORITY" == "Developer ID Application:"* || "$AUTHORITY" == "Apple Distribution:"* ]] \
    && pass "signed by $AUTHORITY" || fail "signed by '$AUTHORITY', not a distribution certificate"
  codesign -dv --verbose=2 "$APP" 2>&1 | grep -q '^Timestamp=' && pass "secure timestamp" || fail "no secure timestamp (notarization rejects it)"
fi

# MARK: Notarization

if [ -n "$PROFILE" ]; then
  step "Notarization"
  ZIP="$(mktemp -d)/ChitarraTune.zip"
  ditto -c -k --keepParent "$APP" "$ZIP"
  RESULT="$(xcrun notarytool submit "$ZIP" --keychain-profile "$PROFILE" --wait --timeout 30m --output-format json)"
  echo "$RESULT"
  grep -Eq '"status" *: *"Accepted"' <<< "$RESULT" && pass "accepted by the notary service" || fail "notarization not accepted"
  check "ticket stapled" xcrun stapler staple "$APP"
  check "stapled ticket validates" xcrun stapler validate "$APP"
  check "Gatekeeper accepts it" spctl --assess --type execute "$APP"
  rm -rf "$(dirname "$ZIP")"
fi

echo
if [ "$FAILURES" -gt 0 ]; then
  printf '\033[1;31m✗ %d check(s) failed\033[0m\n' "$FAILURES"
  exit 1
fi
printf '\033[1;32m✓ release-ready%s\033[0m\n' "$([ -n "$PROFILE" ] && echo ", notarized" || echo "")"
