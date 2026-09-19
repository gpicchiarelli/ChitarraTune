#!/usr/bin/env bash
# The same checks the CI gate runs, for your machine. Run it before you push.
#
#   Scripts/verify.sh          lint + warning-free package build + tests + coverage gate
#   Scripts/verify.sh --app    ... and also build the app for macOS
#   Scripts/verify.sh --release ... and build and check the Mac app as a release, and wrap it in a
#                                    disk image (Scripts/release-check.sh, Scripts/make-dmg.sh)
#
# Install it as a pre-push hook once:   git config core.hooksPath .githooks
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"
APP=false
RELEASE=false
[ "${1:-}" = "--app" ] && APP=true
[ "${1:-}" = "--release" ] && RELEASE=true

# Build outside the repository: folders synced by iCloud (~/Documents) gain extended attributes that
# make codesign fail. Override with SCRATCH=/some/dir.
export SCRATCH="${SCRATCH:-$HOME/Library/Caches/ChitarraTune/kit-build}"
mkdir -p "$SCRATCH"

step() { printf '\n\033[1m▸ %s\033[0m\n' "$1"; }

step "SwiftLint (strict)"
if command -v swiftlint >/dev/null 2>&1; then
  PINNED="$(grep -oE 'swiftlint:[0-9.]+' .github/workflows/swiftlint.yml | head -n 1 | cut -d: -f2)"
  if [ -n "$PINNED" ] && [ "$(swiftlint --version)" != "$PINNED" ]; then
    echo "warning: CI lints with SwiftLint $PINNED, you have $(swiftlint --version); results may differ."
  fi
  swiftlint lint --strict --quiet
else
  echo "swiftlint is not installed (brew install swiftlint); CI will run it."
fi

step "Package builds without warnings"
swift build --package-path Packages/ChitarraTuneKit --scratch-path "$SCRATCH" -Xswiftc -warnings-as-errors

step "Tests and coverage gate"
Scripts/coverage-gate.sh

if $APP; then
  step "App builds for macOS"
  xcodebuild -project ChitarraTune.xcodeproj -scheme ChitarraTune -destination 'platform=macOS' \
    CODE_SIGNING_ALLOWED=NO build -quiet
fi

if $RELEASE; then
  step "Mac app as a release (notarization and App Review checks)"
  Scripts/release-check.sh
  step "Disk image (Apple's layout, ad hoc)"
  Scripts/make-dmg.sh
fi

printf '\n\033[1;32m✓ all checks passed\033[0m\n'
