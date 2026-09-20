#!/usr/bin/env bash
# Prints the CHANGELOG.md section of one version (without its heading), for the GitHub release and
# as a starting point for the App Store "What's New" text. Fails if the version has no section.
#
#   Scripts/release-notes.sh 2.0.0
set -euo pipefail
source "$(dirname "$0")/lib/help.sh"

VERSION="${1:?usage: Scripts/release-notes.sh X.Y.Z}"
ROOT="$(cd "$(dirname "$0")/.." && pwd)"

awk -v version="$VERSION" '
  /^## \[/ {
    if (found) exit
    if (index($0, "## [" version "]") == 1) { found = 1; next }
  }
  found { print }
  END { if (!found) exit 1 }
' "$ROOT/CHANGELOG.md" | sed -e '/./,$!d'
