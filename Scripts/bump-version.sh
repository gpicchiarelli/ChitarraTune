#!/usr/bin/env bash
# Prepares a release: sets MARKETING_VERSION, the README badge, and turns the changelog's
# "Unreleased" section into the new version's section (with today's date) above a fresh, empty one.
# Review the diff, commit, then tag:  git tag vX.Y.Z && git push origin vX.Y.Z
#
#   Scripts/bump-version.sh 2.0.1
set -euo pipefail

VERSION="${1:?usage: Scripts/bump-version.sh X.Y.Z}"
[[ "$VERSION" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] || { echo "error: '$VERSION' is not X.Y.Z" >&2; exit 1; }
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

grep -q '^## \[Unreleased\]' CHANGELOG.md || { echo "error: CHANGELOG.md has no Unreleased section" >&2; exit 1; }
if grep -q "^## \[$VERSION\]" CHANGELOG.md; then echo "error: CHANGELOG.md already has $VERSION" >&2; exit 1; fi

sed -i '' -E "s/^MARKETING_VERSION = .*/MARKETING_VERSION = $VERSION/" Config/Base.xcconfig
sed -i '' -E "s/version-[0-9]+\.[0-9]+\.[0-9]+-/version-$VERSION-/; s/alt=\"Version [0-9]+\.[0-9]+\.[0-9]+\"/alt=\"Version $VERSION\"/" README.md
sed -i '' -E "s/^## \[Unreleased\]$/## [Unreleased]\\
\\
## [$VERSION] - $(date +%Y-%m-%d)/" CHANGELOG.md

echo "Version $VERSION prepared. Also update AppStore/metadata/*/release_notes.txt, then review:"
git --no-pager diff --stat
