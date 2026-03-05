#!/bin/zsh
# =============================================================================
# Outset Integration Test — Run
#
# Invokes outset in each run mode that can be exercised from the command line.
# Must be run as root.
#
# Run modes exercised here:
#   --boot                  Daemon mode; processes boot-once and boot-every.
#   --login                 Agent mode; processes login-once, login-every,
#                           and kicks off the privileged trigger.
#   --login-privileged      Daemon mode; processes login-privileged-once/every.
#   --on-demand             Agent mode; processes on-demand scripts.
#   --on-demand-privileged  Daemon mode; processes on-demand-privileged scripts.
#   --cleanup               Daemon mode; removes processed on-demand scripts.
#
# Run modes NOT exercised here (require an interactive session):
#   --login-window          Only loads in the LoginWindow launchd session;
#                           cannot be run from a standard shell.
#
# Usage:
#   sudo ./run_tests.zsh [--second-pass]
#
# Options:
#   --second-pass   Re-run boot and login modes a second time so that the
#                   verify script can confirm once-type payloads did NOT
#                   execute again.
# =============================================================================

set -euo pipefail

# ── Privilege check ────────────────────────────────────────────────────────────
if [[ $(id -u) -ne 0 ]]; then
    print "ERROR: run_tests.zsh must be run as root (sudo)." >&2
    exit 1
fi

# ── Paths ──────────────────────────────────────────────────────────────────────
OUTSET_BIN="/usr/local/outset/Outset.app/Contents/MacOS/Outset"
OUTSET_DIR="/usr/local/outset"
RESULTS_DIR="/private/tmp/outset-test-results"
SCRIPT_DIR="${0:A:h}/payloads"

# Parse flags
SECOND_PASS=false
for arg in "$@"; do
    [[ "$arg" == "--second-pass" ]] && SECOND_PASS=true
done

# ── Sanity checks ─────────────────────────────────────────────────────────────
if [[ ! -x "$OUTSET_BIN" ]]; then
    print "ERROR: Outset binary not found at $OUTSET_BIN" >&2
    exit 1
fi

if [[ ! -d "$RESULTS_DIR" ]]; then
    print "ERROR: Results directory missing — run setup.zsh first." >&2
    exit 1
fi

# Detect console user so login modes receive the right username context
CONSOLE_USER=$(stat -f "%Su" /dev/console 2>/dev/null || echo "")

# ── Helper ────────────────────────────────────────────────────────────────────
# Re-deploy a payload that may have been removed by --cleanup so it is
# available for a second-pass test.
redeploy_on_demand() {
    local name="$1"
    local destdir="$2"
    local src="$SCRIPT_DIR/$name"
    local dest="$destdir/$name"
    if [[ ! -f "$dest" && -f "$src" ]]; then
        cp "$src" "$dest"
        chmod 755 "$dest"
        chown root:wheel "$dest"
        print "    Re-deployed $name for second pass"
    fi
}

run_mode() {
    local label="$1"; shift
    local pass_label="${SECOND_PASS:+  [second pass]}"
    print "\n── $label$pass_label ────────────────────────────────────────────"
    "$OUTSET_BIN" "$@" 2>&1 | sed 's/^/    /'
    print "  Done."
}

# ── First pass (or second pass for every-type modes) ─────────────────────────
if [[ "$SECOND_PASS" == false ]]; then

    # Boot modes ---------------------------------------------------------------
    run_mode "--boot" --boot

    # Login modes — these need a console user to be present -----------------
    if [[ -z "$CONSOLE_USER" || "$CONSOLE_USER" == "root" ]]; then
        print "\nWARNING: No console user detected; login mode tests may be skipped"
        print "         by outset's ignored-user logic or user-context guards."
    fi

    # --login runs as the LaunchAgent would (invoked by root here for testing)
    run_mode "--login" --login

    # --login-privileged runs as a LaunchDaemon (root)
    run_mode "--login-privileged" --login-privileged

    # On-demand modes (scripts are removed by --cleanup afterwards) ----------
    run_mode "--on-demand" --on-demand

    # Re-deploy on-demand-privileged payload after on-demand may have cleaned it
    redeploy_on_demand "on-demand-privileged.sh" "$OUTSET_DIR/on-demand-privileged"
    run_mode "--on-demand-privileged" --on-demand-privileged

    # Cleanup (removes processed on-demand scripts from their directories) ---
    run_mode "--cleanup" --cleanup

    print "\n── First pass complete ──────────────────────────────────────────────────"
    print "  To test once-type suppression, run:  sudo ./run_tests.zsh --second-pass"
    print "  Then run  ./verify.zsh  to check all results."

else
    # ── Second pass: confirm once-type payloads do NOT run again ─────────────
    # Restore on-demand payloads so they appear to be fresh requests.
    redeploy_on_demand "on-demand.sh"              "$OUTSET_DIR/on-demand"
    redeploy_on_demand "on-demand-privileged.sh"   "$OUTSET_DIR/on-demand-privileged"

    # Record marker before second pass so verify can count lines after it
    date > "$RESULTS_DIR/second-pass.timestamp"

    run_mode "--boot (second pass)"            --boot
    run_mode "--login (second pass)"           --login
    run_mode "--login-privileged (second pass)" --login-privileged

    # On-demand should still run every time — not once-type
    run_mode "--on-demand (second pass)"           --on-demand
    run_mode "--on-demand-privileged (second pass)" --on-demand-privileged
    run_mode "--cleanup (second pass)"             --cleanup

    print "\n── Second pass complete ─────────────────────────────────────────────────"
    print "  Run  ./verify.zsh  to check all results."
fi
