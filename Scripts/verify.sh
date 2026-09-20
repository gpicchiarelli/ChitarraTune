#!/usr/bin/env bash
# The same checks the CI gate runs, for your machine. Run it before you push.
#
#   Scripts/verify.sh          lint + warning-free package build + tests + coverage gate
#   Scripts/verify.sh --app    ... and also build the app for macOS
#   Scripts/verify.sh --release ... and build and check the Mac app as a release, and wrap it in a
#                                    disk image (Scripts/release-check.sh, Scripts/make-dmg.sh)
#
# Install it as a pre-push hook once:   git config core.hooksPath .githooks
#
# The package build is kept between runs so the next one is incremental (ADR 0017 rule 2); the
# heavier one-shot trees are not. What the cache holds is printed at the end, with the one command
# that empties it.
set -euo pipefail
source "$(dirname "$0")/lib/help.sh"

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"
APP=false
RELEASE=false
[ "${1:-}" = "--app" ] && APP=true
[ "${1:-}" = "--release" ] && RELEASE=true

# Build outside the repository: folders synced by iCloud (~/Documents) gain extended attributes that
# make codesign fail (ADR 0017 rule 1). Override the root with CACHE=/some/dir, or the package
# build alone with SCRATCH=/some/dir.
CACHE="${CACHE:-$HOME/Library/Caches/ChitarraTune}"
KIT_BUILD="${SCRATCH:-$CACHE/kit-build}"
mkdir -p "$KIT_BUILD"

step() { printf '\n\033[1m▸ %s\033[0m\n' "$1"; }

step "SwiftLint (strict)"
if command -v swiftlint >/dev/null 2>&1; then
  PINNED="$(grep -oE 'swiftlint:[0-9.]+' .github/workflows/swiftlint.yml | head -n 1 | cut -d: -f2)"
  if [ -n "$PINNED" ] && [ "$(swiftlint --version)" != "$PINNED" ]; then
    echo "warning: CI lints with SwiftLint $PINNED, you have $(swiftlint --version); results may differ."
  fi
  swiftlint lint --strict --quiet
else
  echo "swiftlint is not here (Scripts/fetch-tools.sh); CI will run it."
fi

# The same flags the coverage gate uses, so both share one build tree (ADR 0018). SwiftPM plans a
# build per set of flags: differ by one and the package is compiled twice for no reason.
step "Shell and workflows"
# The pinned copies first, so what passes here passes in CI: same versions, same findings.
# Scripts/clean-caches.sh leaves pinned tools alone. Neither tool is required to be installed —
# CI runs both on every push — but without them the hook is weaker than the gate it stands for.
SHELLCHECK="$CACHE/shellcheck-0.11.0/shellcheck-v0.11.0/shellcheck"
ACTIONLINT="$CACHE/actionlint-1.7.12/actionlint"
[ -x "$SHELLCHECK" ] || SHELLCHECK="$(command -v shellcheck 2>/dev/null || true)"
[ -x "$ACTIONLINT" ] || ACTIONLINT="$(command -v actionlint 2>/dev/null || true)"
if [ -n "$ACTIONLINT" ] && [ -x "$ACTIONLINT" ]; then
  # actionlint shells out to shellcheck for every `run:` block, so it wants it on PATH.
  [ -x "$SHELLCHECK" ] && PATH="$(dirname "$SHELLCHECK"):$PATH"
  "$ACTIONLINT"
else
  echo "actionlint is not here (Scripts/fetch-tools.sh); CI will run it."
fi
if [ -n "$SHELLCHECK" ] && [ -x "$SHELLCHECK" ]; then
  "$SHELLCHECK" -x --severity=warning Scripts/*.sh Scripts/lib/*.sh .githooks/pre-push
else
  echo "shellcheck is not here (Scripts/fetch-tools.sh); CI will run it."
fi

step "Package builds without warnings"
swift build --package-path Packages/ChitarraTuneKit --scratch-path "$KIT_BUILD" --build-tests \
  -c release -Xswiftc -enable-testing -Xswiftc -warnings-as-errors

step "Tests and coverage gate"
SCRATCH="$KIT_BUILD" Scripts/coverage-gate.sh

if $APP; then
  step "App builds for macOS"
  xcodebuild -project ChitarraTune.xcodeproj -scheme ChitarraTune -destination 'platform=macOS' \
    -derivedDataPath "$CACHE/dd-verify-app" CODE_SIGNING_ALLOWED=NO build -quiet
  rm -rf "$CACHE/dd-verify-app"
fi

if $RELEASE; then
  step "Mac app as a release (notarization and App Review checks)"
  # The disk image is built from this app, so the derived data has to outlive the check…
  SCRATCH="$CACHE" KEEP_BUILD=1 Scripts/release-check.sh
  step "Disk image (Apple's layout, ad hoc)"
  SCRATCH="$CACHE" Scripts/make-dmg.sh
  # …and not a moment longer: a gigabyte that nothing reads again (ADR 0017 rule 3).
  rm -rf "$CACHE/release-check"
fi

# What the cache is holding, and the one command that empties it (ADR 0017 rule 4). The package
# build above stays: it is what makes the next run incremental. Everything else was one-shot and
# is already gone.
if [ -d "$CACHE" ]; then
  KILOBYTES="$(du -sk "$CACHE" 2>/dev/null | cut -f1)"
  printf '\n  cache: %s in %s\n' "$(du -sh "$CACHE" 2>/dev/null | cut -f1)" "$CACHE"
  if [ -n "$KILOBYTES" ] && [ "$KILOBYTES" -gt 5242880 ]; then
    printf '  \033[33mover 5 GB — Scripts/clean-caches.sh (--now for today'"'"'s builds too)\033[0m\n'
  fi
fi

printf '\n\033[1;32m✓ all checks passed\033[0m\n'
