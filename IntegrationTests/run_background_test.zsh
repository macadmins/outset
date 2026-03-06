#!/bin/zsh
# =============================================================================
# Outset Background Processing Test
#
# Deploys four scripts into login-every, invokes outset --login, then tails
# the outset log so you can watch interleaved background/foreground output.
#
# Expected timeline (approximate):
#
#   t=0s   outset --login starts
#          background-slow dispatched  → [BG:pid=N] background-slow: start
#          background-fast dispatched  → [BG:pid=M] background-fast: start
#          foreground-a starts         → foreground-a: start
#   t=1s   [BG:pid=N] background-slow: tick 1
#          [BG:pid=M] background-fast: done
#   t=2s   foreground-a: step 1
#   t=3s   [BG:pid=N] background-slow: tick 2
#   t=4s   foreground-a: done  →  foreground-b starts  → foreground-b: start
#   t=5s   [BG:pid=N] background-slow: tick 3
#   t=6s   foreground-b: done
#   t=7s   [BG:pid=N] background-slow: done
#          group.wait() returns, outset exits
#
# The key thing to observe: background-slow log lines appear between
# foreground lines, confirming true concurrent execution.
#
# Usage:
#   sudo ./run_background_test.zsh [--teardown]
#
# Options:
#   --teardown   Remove deployed scripts after the test (default: leave them
#                so you can re-run outset manually and inspect logs again).
# =============================================================================

set -euo pipefail

if [[ $(id -u) -ne 0 ]]; then
    print "ERROR: must be run as root (sudo)." >&2
    exit 1
fi

OUTSET_BIN="${1:-/usr/local/outset/Outset.app/Contents/MacOS/Outset}"
OUTSET_LOGIN_EVERY="/usr/local/outset/login-every"
LOG_FILE="/usr/local/outset/logs/outset.log"
PAYLOAD_DIR="${0:A:h}/payloads/background-test"

TEARDOWN=false
for arg in "$@"; do
    [[ "$arg" == "--teardown" ]] && TEARDOWN=true
done

if [[ ! -x "$OUTSET_BIN" ]]; then
    print "ERROR: Outset not found at $OUTSET_BIN" >&2
    exit 1
fi

if [[ ! -d "$PAYLOAD_DIR" ]]; then
    print "ERROR: Payload directory not found: $PAYLOAD_DIR" >&2
    exit 1
fi

# ── Deploy ────────────────────────────────────────────────────────────────────
print "\n── Deploying background test scripts → $OUTSET_LOGIN_EVERY"
for script in "$PAYLOAD_DIR"/*.sh; do
    name="${script:t}"
    dest="$OUTSET_LOGIN_EVERY/$name"
    cp "$script" "$dest"
    chmod 755 "$dest"
    chown root:wheel "$dest"
    print "  Deployed: $dest"
done

# ── Note current log end so we only tail new output ───────────────────────────
LOG_START=0
if [[ -f "$LOG_FILE" ]]; then
    LOG_START=$(wc -l < "$LOG_FILE" | tr -d ' ')
fi

# ── Run ───────────────────────────────────────────────────────────────────────
print "\n── Running: outset --login"
print "   Watch for interleaved [BG:pid=N] lines among foreground output.\n"

"$OUTSET_BIN" --login

# ── Show relevant log output ──────────────────────────────────────────────────
print "\n── Outset log output from this run:"
if [[ -f "$LOG_FILE" ]]; then
    tail -n +"$((LOG_START + 1))" "$LOG_FILE" \
        | grep -E "foreground|background|BG:" \
        | sed 's/^/  /'
else
    print "  (log file not found at $LOG_FILE)"
fi

# ── Teardown ──────────────────────────────────────────────────────────────────
if [[ "$TEARDOWN" == true ]]; then
    print "\n── Removing test scripts"
    for script in "$PAYLOAD_DIR"/*.sh; do
        name="${script:t}"
        dest="$OUTSET_LOGIN_EVERY/$name"
        [[ -f "$dest" ]] && rm "$dest" && print "  Removed: $dest"
    done
fi

print "\n── Done. Full log: $LOG_FILE"
