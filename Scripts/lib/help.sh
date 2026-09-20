#!/usr/bin/env bash
# Sourced by every script in Scripts/, right after `set -euo pipefail`: `--help` (or `-h`) prints
# that script's header — the comment block under its shebang — and exits 0, before the script looks
# at its arguments or touches anything. Sourced and not called, so `$0` is still the script the user
# ran and the header printed is its own. These scripts are not installed on the PATH, so `--help` is
# their manual page (ADR 0009); `ScriptPolicyTests` checks that every one of them answers it.

case "${1:-}" in
-h | --help)
    while IFS= read -r line; do
        if [[ $line == '#!'* ]]; then continue; fi
        if [[ $line != '#'* ]]; then break; fi
        line=${line#\#}
        printf '%s\n' "${line# }"
    done <"$0"
    exit 0
    ;;
esac
