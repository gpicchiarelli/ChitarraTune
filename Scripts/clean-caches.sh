#!/usr/bin/env bash
# Frees the build caches this project leaves in ~/Library/Caches/ChitarraTune: the package build,
# the release check, the disk image, the screenshots, and any derived data an ad-hoc `xcodebuild`
# left behind. Nothing here is source, and everything is rebuilt on demand; what it costs to delete
# is time, not work.
#
# Left alone: anything touched more recently than the age limit (something may still be using it),
# and the pinned tools the checks download, such as the SwiftLint binary CI matches.
#
#   Scripts/clean-caches.sh                 what has not been touched for a day
#   Scripts/clean-caches.sh --days 7        a gentler limit
#   Scripts/clean-caches.sh --now           today's build output too, tools kept
#   Scripts/clean-caches.sh --all           everything, tools included
#   Scripts/clean-caches.sh --dry-run       say what would go, delete nothing
#
# The rules it enforces are ADR 0017; verify.sh says when the cache has grown enough to want it.
set -euo pipefail
source "$(dirname "$0")/lib/help.sh"

CACHE="${CACHE:-$HOME/Library/Caches/ChitarraTune}"
DAYS=1
ALL=false
NOW=false
DRY=false
while [ "$#" -gt 0 ]; do
    case "$1" in
    --days) DAYS="${2:?usage: --days N}"; shift 2 ;;
    --all) ALL=true; shift ;;
    --now) NOW=true; shift ;;
    --dry-run | -n) DRY=true; shift ;;
    *) echo "error: unknown argument '$1' (try --help)" >&2; exit 1 ;;
    esac
done
[[ "$DAYS" =~ ^[0-9]+$ ]] || { echo "error: --days takes a whole number of days" >&2; exit 1; }

# Refuse to run against anything that is not this project's cache, whatever CACHE says.
case "$CACHE" in
*/ChitarraTune) ;;
*) echo "error: CACHE must end in /ChitarraTune, not '$CACHE'" >&2; exit 1 ;;
esac
[ -d "$CACHE" ] || { echo "Nothing to clean: $CACHE does not exist."; exit 0; }

# A build in flight would lose its intermediates half-way through and fail with something that looks
# like a compiler bug. Wait for it instead.
if ! $DRY && pgrep -xq xcodebuild 2>/dev/null || ! $DRY && pgrep -xq swift-frontend 2>/dev/null; then
    echo "error: a build is running (xcodebuild or swift-frontend); let it finish" >&2
    exit 1
fi

kept=0
freed=0
removed=0
for entry in "$CACHE"/*; do
    [ -e "$entry" ] || continue
    name="$(basename "$entry")"
    size="$(du -sk "$entry" | cut -f1)"

    # A git worktree lives here too (the one the release scripts push from). Deleting its files
    # would leave the repository with a worktree it still believes in: `git worktree remove` is the
    # only way to take one out, so this script never touches one, not even with --all.
    if [ -e "$entry/.git" ]; then
        printf '  keep   %6s  %s (a git worktree, not a cache)\n' "$(du -sh "$entry" | cut -f1)" "$name"
        kept=$((kept + size))
        continue
    fi

    if ! $ALL; then
        # The pinned tools are downloads, not build output: deleting them costs bandwidth, and CI
        # pins their versions on purpose.
        case "$name" in
        swiftlint-* | *.zip | *.pkg)
            kept=$((kept + size))
            continue
            ;;
        esac
        # -mtime +N is "older than N full days", which is exactly the question being asked.
        if ! $NOW && [ -z "$(find "$entry" -maxdepth 0 -mtime +"$DAYS" -print 2>/dev/null)" ]; then
            printf '  keep   %6s  %s (touched recently)\n' "$(du -sh "$entry" | cut -f1)" "$name"
            kept=$((kept + size))
            continue
        fi
    fi

    printf '  %s %6s  %s\n' "$($DRY && echo "would" || echo "free ")" "$(du -sh "$entry" | cut -f1)" "$name"
    $DRY || rm -rf "$entry"
    freed=$((freed + size))
    removed=$((removed + 1))
done

printf '\n%s %d MB in %d item(s); %d MB kept.\n' \
    "$($DRY && echo "Would free" || echo "Freed")" "$((freed / 1024))" "$removed" "$((kept / 1024))"
