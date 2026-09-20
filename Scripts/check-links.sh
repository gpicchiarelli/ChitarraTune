#!/usr/bin/env bash
# Checks that every external link in the Markdown files still resolves. Relative links are already
# checked offline by DocumentationSpecTests; these need the network, so they run here and in the
# weekly Links workflow, never in the test suite.
#
# A link is reported when the host cannot be reached or answers 404 or 410. Anything else (403, 405,
# a redirect, a rate limit) counts as alive: Apple and GitHub answer some of those to a robot.
#
#   Scripts/check-links.sh            every tracked Markdown file
#   Scripts/check-links.sh README.md  only these files
set -euo pipefail
source "$(dirname "$0")/lib/help.sh"

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

# bash 3.2 (the one macOS ships) has no mapfile, so the lists are built by hand.
FILES=()
if [ "$#" -gt 0 ]; then
    FILES=("$@")
else
    while IFS= read -r file; do FILES+=("$file"); done < <(git ls-files '*.md')
fi

# Links written by a release script for a version that does not exist yet, and the placeholder the
# privacy policy uses to show where earlier wordings live.
SKIP='vX\.Y\.Z|compare/v|releases/tag/v|<App Store ID>|example\.com'

URLS=()
while IFS= read -r url; do URLS+=("$url"); done < <(
    grep -ohE 'https?://[^ )"<>]+' "${FILES[@]}" |
        sed -E 's/[.,;:]+$//' |
        grep -vE "$SKIP" |
        sort -u
)
echo "${#URLS[@]} distinct external links in ${#FILES[@]} files"

failed=0
for url in "${URLS[@]}"; do
    code="$(curl -sS -o /dev/null -w '%{http_code}' -L --connect-timeout 10 --max-time 30 --retry 2 \
        -A 'ChitarraTune link check (+https://github.com/gpicchiarelli/ChitarraTune)' \
        -I "$url" || echo 000)"
    # Some hosts refuse HEAD but answer GET; ask again before believing the worst.
    if [ "$code" = "000" ] || [ "$code" = "404" ] || [ "$code" = "405" ]; then
        code="$(curl -sS -o /dev/null -w '%{http_code}' -L --connect-timeout 10 --max-time 30 --retry 2 \
            -A 'ChitarraTune link check (+https://github.com/gpicchiarelli/ChitarraTune)' \
            -r 0-0 "$url" || echo 000)"
    fi
    case "$code" in
    000 | 404 | 410)
        echo "  BROKEN $code  $url" >&2
        grep -lF "$url" "${FILES[@]}" | sed 's/^/          in /' >&2
        failed=$((failed + 1))
        ;;
    esac
done

if [ "$failed" -gt 0 ]; then
    echo "$failed link(s) need attention" >&2
    exit 1
fi
echo "Every external link answers."
