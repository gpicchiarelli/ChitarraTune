#!/usr/bin/env bash
# Puts Apple's official "Download on the App Store" and "Download on the Mac App Store" badges in the
# README (English header and Italian section), linked to the app's product page.
#
# Apple's marketing guidelines allow the badges only for an app that is available on the App Store,
# only as the artwork Apple provides (served from Apple's marketing tools, never redrawn), in the
# language of the page, and only as a link to the app's product page. So the README ships without
# them, and this script adds them once the app is live, from the Apple ID that App Store Connect
# shows under App Information (the digits in https://apps.apple.com/app/id<ID>).
#
#   Scripts/app-store-badges.sh 1234567890   # add or update the badges (checks the product page is live)
#   Scripts/app-store-badges.sh --remove     # take them out again
#
# --skip-availability-check exists for the policy tests only. README=<path> edits another copy.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
README="${README:-$ROOT/README.md}"
TOOLBOX="https://toolbox.marketingtools.apple.com/api/v2/badges"

usage() { echo "usage: Scripts/app-store-badges.sh <App Store ID> [--skip-availability-check] | --remove" >&2; exit 64; }

ID=""
CHECK=1
REMOVE=0
for argument in "$@"; do
    case "$argument" in
        --remove) REMOVE=1 ;;
        --skip-availability-check) CHECK=0 ;;
        -*) usage ;;
        *) [[ -z "$ID" ]] || usage; ID="$argument" ;;
    esac
done
if [[ $REMOVE == 1 ]]; then [[ -z "$ID" ]] || usage; else [[ -n "$ID" ]] || usage; fi
if [[ -n "$ID" && ! "$ID" =~ ^[0-9]{6,12}$ ]]; then
    echo "error: '$ID' is not an App Store ID (the digits after 'id' in the product page URL)" >&2
    exit 1
fi
for language in en it; do
    count=$(grep -c "<!-- app-store-badges:$language:start -->" "$README" || true)
    [[ "$count" == 1 ]] || { echo "error: $README needs exactly one app-store-badges:$language block, found $count" >&2; exit 1; }
done

if [[ -n "$ID" && $CHECK == 1 ]]; then
    for storefront in "" "it/"; do
        page="https://apps.apple.com/${storefront}app/id$ID"
        status=$(curl -s -o /dev/null -w '%{http_code}' -L "$page" || true)
        if [[ "$status" != 200 ]]; then
            echo "error: $page answers $status. Apple allows the badges only once the app is available." >&2
            exit 1
        fi
    done
fi

# The block's content: two badges, or only a note for whoever edits the README.
block() {
    local locale="$1" page="$2" app_store="$3" mac_app_store="$4"
    if [[ -z "$ID" ]]; then
        echo "<!-- Official App Store badges: Scripts/app-store-badges.sh <App Store ID> adds them once the app is live. -->"
        return
    fi
    cat <<EOF
<p>
  <a href="$page"><img alt="$app_store" src="$TOOLBOX/download-on-the-app-store/black/$locale" height="40"></a>
  &nbsp;&nbsp;
  <a href="$page"><img alt="$mac_app_store" src="$TOOLBOX/download-on-the-mac-app-store/black/$locale" height="40"></a>
</p>
EOF
}

replace() {
    local language="$1" content="$2"
    CONTENT="$content" LANGUAGE="$language" perl -0pi -e \
        's/(<!-- app-store-badges:$ENV{LANGUAGE}:start -->\n).*?(<!-- app-store-badges:$ENV{LANGUAGE}:end -->)/$1$ENV{CONTENT}\n$2/s' \
        "$README"
}

replace en "$(block en-us "https://apps.apple.com/app/id$ID" "Download on the App Store" "Download on the Mac App Store")"
replace it "$(block it-it "https://apps.apple.com/it/app/id$ID" "Scarica su App Store" "Scarica su Mac App Store")"

if [[ -n "$ID" ]]; then echo "Badges linked to App Store ID $ID."; else echo "Badges removed."; fi
