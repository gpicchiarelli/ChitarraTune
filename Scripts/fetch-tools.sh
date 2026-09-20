#!/usr/bin/env bash
# Fetches the linters the gate runs, at the exact versions CI uses, into the project cache. Each
# download is refused unless its SHA-256 matches the value recorded here, the way every GitHub
# action in this repository is pinned to a commit: a linter runs over the whole tree with your
# permissions, so it is supply chain like anything else (ADR 0010, ADR 0019 rule 4).
#
#   Scripts/fetch-tools.sh           fetch whatever is missing
#   Scripts/fetch-tools.sh --force   fetch again even when it is already there
#   Scripts/fetch-tools.sh --check   verify what is present, download nothing
#
# The tools land beside the build cache, where Scripts/clean-caches.sh leaves them alone unless it
# is asked for --all. Apple silicon only: no Mac that can run this app is Intel.
#
# When a version changes here, change it in .github/workflows/ci.yml too — the checksums in the two
# files are for the same releases, macOS here and Linux there.
set -euo pipefail
source "$(dirname "$0")/lib/help.sh"

CACHE="${CACHE:-$HOME/Library/Caches/ChitarraTune}"
FORCE=false
CHECK=false
while [ "$#" -gt 0 ]; do
    case "$1" in
    --force) FORCE=true; shift ;;
    --check) CHECK=true; shift ;;
    *) echo "error: unknown argument '$1' (try --help)" >&2; exit 1 ;;
    esac
done

if [ "$(uname -m)" != "arm64" ]; then
    echo "error: this fetches Apple silicon builds, and $(uname -m) is not one" >&2
    exit 1
fi

ok() { printf '  \033[32m✓\033[0m %s\n' "$1"; }
info() { printf '  %s\n' "$1"; }

# fetch <name> <version> <url> <sha256> <relative path of the binary inside the unpacked archive>
fetch() {
    local name="$1" version="$2" url="$3" sha="$4" binary="$5"
    # Two statements, not one: within a single `local` the earlier name is not bound yet.
    local dir="$CACHE/$name-$version"
    local archive="$dir/${url##*/}"

    if [ -x "$dir/$binary" ] && ! $FORCE; then
        ok "$name $version"
        return 0
    fi
    if $CHECK; then
        echo "  missing: $name $version ($dir/$binary)" >&2
        return 1
    fi

    mkdir -p "$dir"
    info "downloading $name $version"
    curl -fsSL -o "$archive" "$url"
    if ! echo "$sha  $archive" | shasum -a 256 --check --status; then
        rm -f "$archive"
        rmdir "$dir" 2>/dev/null || true   # leave no empty shell behind when nothing was installed
        echo "error: $name $version does not match its recorded checksum; nothing was installed" >&2
        return 1
    fi
    case "$archive" in
    *.zip) unzip -qo "$archive" -d "$dir" ;;
    *.tar.gz) tar xzf "$archive" -C "$dir" ;;
    *.tar.xz) tar xJf "$archive" -C "$dir" ;;
    *) echo "error: $archive is not an archive this script unpacks" >&2; return 1 ;;
    esac
    [ -x "$dir/$binary" ] || { echo "error: $name unpacked without $binary" >&2; return 1; }
    ok "$name $version"
}

MISSING=0
fetch swiftlint 0.65.1 \
    "https://github.com/realm/SwiftLint/releases/download/0.65.1/portable_swiftlint.zip" \
    c1e429b0599cf1b516f369a2d9ec04eaf0e436f3c12b637df8851fa52ff694d0 \
    swiftlint || MISSING=$((MISSING + 1))
fetch shellcheck 0.11.0 \
    "https://github.com/koalaman/shellcheck/releases/download/v0.11.0/shellcheck-v0.11.0.darwin.aarch64.tar.gz" \
    339b930feb1ea764467013cc1f72d09cd6b869ebf1013296ba9055ab2ffbd26f \
    shellcheck-v0.11.0/shellcheck || MISSING=$((MISSING + 1))
fetch actionlint 1.7.12 \
    "https://github.com/rhysd/actionlint/releases/download/v1.7.12/actionlint_1.7.12_darwin_arm64.tar.gz" \
    aba9ced2dee8d27fecca3dc7feb1a7f9a52caefa1eb46f3271ea66b6e0e6953f \
    actionlint || MISSING=$((MISSING + 1))

if [ "$MISSING" -gt 0 ]; then
    exit 1
fi

# SwiftLint is the one Scripts/verify.sh expects on PATH; the other two it finds in the cache itself.
printf '\n  add SwiftLint to your PATH:\n    export PATH="%s/swiftlint-0.65.1:$PATH"\n' "$CACHE"
