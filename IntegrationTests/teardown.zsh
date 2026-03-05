#!/bin/zsh
# =============================================================================
# Outset Integration Test — Teardown
#
# Removes the test payload scripts from all outset directories and clears the
# results directory.  Must be run as root.
#
# Pass --keep-results to preserve the results directory for later inspection.
#
# Usage:
#   sudo ./teardown.zsh [--keep-results]
# =============================================================================

set -euo pipefail

if [[ $(id -u) -ne 0 ]]; then
    print "ERROR: teardown.zsh must be run as root (sudo)." >&2
    exit 1
fi

OUTSET_DIR="/usr/local/outset"
RESULTS_DIR="/private/tmp/outset-test-results"

KEEP_RESULTS=false
for arg in "$@"; do
    [[ "$arg" == "--keep-results" ]] && KEEP_RESULTS=true
done

print "\n── Removing test payloads ───────────────────────────────────────────────"

remove_payload() {
    local file="$OUTSET_DIR/$1"
    if [[ -f "$file" ]]; then
        rm "$file"
        print "  Removed: $file"
    fi
}

remove_payload "boot-once/boot-once.sh"
remove_payload "boot-every/boot-every.sh"
remove_payload "login-once/login-once.sh"
remove_payload "login-every/login-every.sh"
remove_payload "login-privileged-once/login-privileged-once.sh"
remove_payload "login-privileged-every/login-privileged-every.sh"
remove_payload "on-demand/on-demand.sh"
remove_payload "on-demand-privileged/on-demand-privileged.sh"

if [[ "$KEEP_RESULTS" == false ]]; then
    print "\n── Removing results directory ───────────────────────────────────────────"
    rm -rf "$RESULTS_DIR"
    print "  Removed: $RESULTS_DIR"
else
    print "\n  Results directory preserved: $RESULTS_DIR"
fi

print "\n── Teardown complete ────────────────────────────────────────────────────"
