#!/bin/zsh
# =============================================================================
# Outset Integration Test — Setup
#
# Deploys test payload scripts into the real outset directories and clears
# any previous test result markers.  Must be run as root.
#
# Usage:
#   sudo ./setup.zsh [--clean-run-once]
#
# Options:
#   --clean-run-once   Remove all existing run-once tracking records so that
#                      once-type payloads will execute fresh.
#
# After running setup, invoke each run mode manually (see run_tests.zsh) or
# wait for launchd to trigger the appropriate mode.  Then run verify.zsh to
# check results.
# =============================================================================

set -euo pipefail

# ── Privilege check ────────────────────────────────────────────────────────────
if [[ $(id -u) -ne 0 ]]; then
    print "ERROR: setup.zsh must be run as root (sudo)." >&2
    exit 1
fi

# ── Paths ──────────────────────────────────────────────────────────────────────
OUTSET_BIN="/usr/local/outset/Outset.app/Contents/MacOS/Outset"
OUTSET_DIR="/usr/local/outset"
RESULTS_DIR="/private/tmp/outset-test-results"
SCRIPT_DIR="${0:A:h}/payloads"   # directory containing this script / payloads

# Parse flags
CLEAN_RUN_ONCE=false
for arg in "$@"; do
    [[ "$arg" == "--clean-run-once" ]] && CLEAN_RUN_ONCE=true
done

# ── Sanity checks ─────────────────────────────────────────────────────────────
if [[ ! -x "$OUTSET_BIN" ]]; then
    print "ERROR: Outset binary not found at $OUTSET_BIN" >&2
    print "       Install Outset before running integration tests." >&2
    exit 1
fi

if [[ ! -d "$SCRIPT_DIR" ]]; then
    print "ERROR: Payload directory not found: $SCRIPT_DIR" >&2
    exit 1
fi

# ── Helper ────────────────────────────────────────────────────────────────────
deploy() {
    local src="$1"
    local destdir="$2"
    local name="${src:t}"           # basename
    local dest="$destdir/$name"

    if [[ ! -d "$destdir" ]]; then
        print "WARNING: Directory $destdir does not exist — skipping $name" >&2
        return
    fi

    cp "$src" "$dest"
    chmod 755 "$dest"
    chown root:wheel "$dest"
    print "  Deployed: $dest"
}

# ── Clear previous results ────────────────────────────────────────────────────
print "\n── Clearing previous test results ──────────────────────────────────────"
rm -rf "$RESULTS_DIR"
mkdir -p "$RESULTS_DIR"
chmod 1777 "$RESULTS_DIR"   # world-writable so user-context scripts can write
print "  Results directory: $RESULTS_DIR"

# ── Optionally wipe run-once tracking ─────────────────────────────────────────
if [[ "$CLEAN_RUN_ONCE" == true ]]; then
    print "\n── Clearing run-once tracking records ───────────────────────────────────"
    # System-level plist (written by root)
    defaults delete io.macadmins.Outset run_once 2>/dev/null && \
        print "  Cleared system run_once key" || true
    # Per-user key for the current console user
    CONSOLE_USER=$(stat -f "%Su" /dev/console 2>/dev/null || echo "")
    if [[ -n "$CONSOLE_USER" && "$CONSOLE_USER" != "root" ]]; then
        defaults delete io.macadmins.Outset "run_once-${CONSOLE_USER}" 2>/dev/null && \
            print "  Cleared run_once-${CONSOLE_USER} key" || true
        # User-domain UserDefaults (login-once stored here when not root)
        sudo -u "$CONSOLE_USER" defaults delete io.macadmins.Outset run_once 2>/dev/null && \
            print "  Cleared user-domain run_once for ${CONSOLE_USER}" || true
    fi
fi

# ── Deploy payloads ───────────────────────────────────────────────────────────
print "\n── Deploying test payloads ──────────────────────────────────────────────"

deploy "$SCRIPT_DIR/boot-once.sh"              "$OUTSET_DIR/boot-once"
deploy "$SCRIPT_DIR/boot-every.sh"             "$OUTSET_DIR/boot-every"
deploy "$SCRIPT_DIR/login-once.sh"             "$OUTSET_DIR/login-once"
deploy "$SCRIPT_DIR/login-every.sh"            "$OUTSET_DIR/login-every"
deploy "$SCRIPT_DIR/login-privileged-once.sh"  "$OUTSET_DIR/login-privileged-once"
deploy "$SCRIPT_DIR/login-privileged-every.sh" "$OUTSET_DIR/login-privileged-every"
deploy "$SCRIPT_DIR/on-demand.sh"              "$OUTSET_DIR/on-demand"
deploy "$SCRIPT_DIR/on-demand-privileged.sh"   "$OUTSET_DIR/on-demand-privileged"

print "\n── Setup complete ───────────────────────────────────────────────────────"
print "  Run  sudo ./run_tests.zsh  to exercise each mode and collect results."
print "  Then run  ./verify.zsh     to check pass/fail."
