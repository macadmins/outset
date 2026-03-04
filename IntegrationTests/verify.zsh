#!/bin/zsh
# =============================================================================
# Outset Integration Test — Verify
#
# Reads the marker files written by each test payload and the outset log to
# determine whether each run mode behaved correctly.
#
# Can be run as any user (reads /private/tmp/outset-test-results and the
# outset log at /usr/local/outset/logs/outset.log).
#
# Exit codes:
#   0 — all checks passed
#   1 — one or more checks failed
# =============================================================================

RESULTS_DIR="/private/tmp/outset-test-results"
LOG_FILE="/usr/local/outset/logs/outset.log"

# ── Colour helpers ─────────────────────────────────────────────────────────────
# Use tput if a terminal is attached; fall back to plain text otherwise.
if [[ -t 1 ]]; then
    RED=$(tput setaf 1)
    GRN=$(tput setaf 2)
    YLW=$(tput setaf 3)
    RST=$(tput sgr0)
    BLD=$(tput bold)
else
    RED="" GRN="" YLW="" RST="" BLD=""
fi

PASS=0
FAIL=0
WARN=0

pass()  { print "  ${GRN}PASS${RST}  $*"; (( PASS++ )) }
fail()  { print "  ${RED}FAIL${RST}  $*"; (( FAIL++ )) }
warn()  { print "  ${YLW}WARN${RST}  $*"; (( WARN++ )) }
header(){ print "\n${BLD}── $* ────────────────────────────────────────────────${RST}" }

# ── Helpers ───────────────────────────────────────────────────────────────────

# marker_count <file>
# Returns the number of lines in a marker file (0 if it does not exist).
marker_count() {
    local f="$RESULTS_DIR/$1"
    [[ -f "$f" ]] && wc -l < "$f" | tr -d ' ' || echo 0
}

# marker_count_after <file> <timestamp-file>
# Returns the number of lines appended to a marker file after the timestamp
# recorded in <timestamp-file>.  Used for second-pass checks.
marker_count_after() {
    local marker="$RESULTS_DIR/$1"
    local ts_file="$RESULTS_DIR/$2"
    if [[ ! -f "$marker" ]]; then echo 0; return; fi
    if [[ ! -f "$ts_file" ]]; then
        # No timestamp file: return total count (treated as first pass only)
        wc -l < "$marker" | tr -d ' '
        return
    fi
    # Count lines whose leading timestamp is after the second-pass marker date.
    # Marker files record lines like: "boot-once ran at Thu 1 Jan 00:00:00 UTC 2026"
    # The timestamp file contains a date string from `date`.
    # We compare file modification times: lines written after the ts file was
    # created are in the second pass.  Since we can't directly correlate line
    # timestamps across formats, we use line count delta instead: capture total
    # count minus count that existed at setup time.
    #
    # Simpler approach: record first-pass count in a sidecar file (see run_tests.zsh).
    # We store it here lazily: if a <marker>.firstpass sidecar exists, use it.
    local sidecar="$RESULTS_DIR/$1.firstpass"
    if [[ -f "$sidecar" ]]; then
        local first; first=$(cat "$sidecar")
        local total; total=$(wc -l < "$marker" | tr -d ' ')
        echo $(( total - first ))
    else
        # Fall back: count lines after second-pass.timestamp modification time
        # by looking for lines written after the ts file.  This is approximate.
        wc -l < "$marker" | tr -d ' '
    fi
}

# log_contains <pattern>
# Returns 0 (true) if the outset log contains the pattern since the last setup.
log_contains() {
    [[ -f "$LOG_FILE" ]] && grep -q "$1" "$LOG_FILE"
}

# ── Pre-flight ────────────────────────────────────────────────────────────────
header "Pre-flight checks"

if [[ ! -d "$RESULTS_DIR" ]]; then
    fail "Results directory $RESULTS_DIR not found — run setup.zsh and run_tests.zsh first."
    print "\n${RED}Cannot continue — no results to verify.${RST}"
    exit 1
fi
pass "Results directory exists: $RESULTS_DIR"

if [[ -f "$LOG_FILE" ]]; then
    pass "Outset log exists: $LOG_FILE"
else
    warn "Outset log not found at $LOG_FILE (log checks will be skipped)"
fi

HAS_SECOND_PASS=false
[[ -f "$RESULTS_DIR/second-pass.timestamp" ]] && HAS_SECOND_PASS=true
if $HAS_SECOND_PASS; then
    pass "Second-pass timestamp found — will verify once-type suppression"
else
    warn "No second-pass timestamp — run 'sudo ./run_tests.zsh --second-pass' for full coverage"
fi

# ── Save first-pass counts before second-pass check ───────────────────────────
# These sidecar files are created by run_tests.zsh --second-pass preamble.
# If they don't exist we create them now from current counts (first-pass only run).
save_first_pass_count() {
    local name="$1"
    local sidecar="$RESULTS_DIR/$name.firstpass"
    if [[ ! -f "$sidecar" && -f "$RESULTS_DIR/$name" ]]; then
        wc -l < "$RESULTS_DIR/$name" | tr -d ' ' > "$sidecar"
    fi
}

# ── Boot modes ───────────────────────────────────────────────────────────────
header "boot-once"
count=$(marker_count "boot-once.ran")
if (( count >= 1 )); then
    pass "boot-once.sh executed (marker present, $count line(s))"
    if $HAS_SECOND_PASS; then
        sidecar="$RESULTS_DIR/boot-once.ran.firstpass"
        if [[ -f "$sidecar" ]]; then
            first=$(cat "$sidecar")
            total=$(marker_count "boot-once.ran")
            second=$(( total - first ))
            if (( second == 0 )); then
                pass "boot-once.sh did NOT run on second pass (correct once-type behaviour)"
            else
                fail "boot-once.sh ran $second time(s) on second pass — should be suppressed"
            fi
        else
            warn "No first-pass sidecar for boot-once; cannot verify suppression precisely"
        fi
    fi
else
    fail "boot-once.sh did not execute — marker file missing or empty"
fi

header "boot-every"
count=$(marker_count "boot-every.ran")
if (( count >= 1 )); then
    pass "boot-every.sh executed (marker present, $count line(s))"
    if $HAS_SECOND_PASS; then
        sidecar="$RESULTS_DIR/boot-every.ran.firstpass"
        if [[ -f "$sidecar" ]]; then
            first=$(cat "$sidecar")
            total=$(marker_count "boot-every.ran")
            second=$(( total - first ))
            if (( second >= 1 )); then
                pass "boot-every.sh ran on second pass ($second time(s)) — correct every-type behaviour"
            else
                fail "boot-every.sh did not run on second pass — should run every time"
            fi
        else
            warn "No first-pass sidecar for boot-every; cannot verify re-run precisely"
        fi
    fi
else
    fail "boot-every.sh did not execute — marker file missing or empty"
fi

# ── Login modes ──────────────────────────────────────────────────────────────
header "login-once"
count=$(marker_count "login-once.ran")
if (( count >= 1 )); then
    pass "login-once.sh executed (marker present, $count line(s))"
    if $HAS_SECOND_PASS; then
        sidecar="$RESULTS_DIR/login-once.ran.firstpass"
        if [[ -f "$sidecar" ]]; then
            first=$(cat "$sidecar")
            total=$(marker_count "login-once.ran")
            second=$(( total - first ))
            if (( second == 0 )); then
                pass "login-once.sh did NOT run on second pass (correct once-type behaviour)"
            else
                fail "login-once.sh ran $second time(s) on second pass — should be suppressed"
            fi
        else
            warn "No first-pass sidecar for login-once; cannot verify suppression precisely"
        fi
    fi
else
    warn "login-once.sh did not execute — may be expected if no console user was present"
    print "       (login mode is skipped when there is no console user)"
fi

header "login-every"
count=$(marker_count "login-every.ran")
if (( count >= 1 )); then
    pass "login-every.sh executed (marker present, $count line(s))"
    if $HAS_SECOND_PASS; then
        sidecar="$RESULTS_DIR/login-every.ran.firstpass"
        if [[ -f "$sidecar" ]]; then
            first=$(cat "$sidecar")
            total=$(marker_count "login-every.ran")
            second=$(( total - first ))
            if (( second >= 1 )); then
                pass "login-every.sh ran on second pass ($second time(s)) — correct every-type behaviour"
            else
                fail "login-every.sh did not run on second pass — should run every time"
            fi
        else
            warn "No first-pass sidecar for login-every; cannot verify re-run precisely"
        fi
    fi
else
    warn "login-every.sh did not execute — may be expected if no console user was present"
fi

# ── Login privileged modes ────────────────────────────────────────────────────
header "login-privileged-once"
count=$(marker_count "login-privileged-once.ran")
if (( count >= 1 )); then
    if grep -q "uid=0" "$RESULTS_DIR/login-privileged-once.ran" 2>/dev/null; then
        pass "login-privileged-once.sh executed as root (uid=0, $count line(s))"
    else
        fail "login-privileged-once.sh executed but NOT as root — check uid in marker"
        pass "login-privileged-once.sh executed ($count line(s))"
    fi
    if $HAS_SECOND_PASS; then
        sidecar="$RESULTS_DIR/login-privileged-once.ran.firstpass"
        if [[ -f "$sidecar" ]]; then
            first=$(cat "$sidecar")
            total=$(marker_count "login-privileged-once.ran")
            second=$(( total - first ))
            if (( second == 0 )); then
                pass "login-privileged-once.sh did NOT run on second pass (correct once-type behaviour)"
            else
                fail "login-privileged-once.sh ran $second time(s) on second pass — should be suppressed"
            fi
        else
            warn "No first-pass sidecar for login-privileged-once"
        fi
    fi
else
    warn "login-privileged-once.sh did not execute — may be expected if no console user was present"
fi

header "login-privileged-every"
count=$(marker_count "login-privileged-every.ran")
if (( count >= 1 )); then
    if grep -q "uid=0" "$RESULTS_DIR/login-privileged-every.ran" 2>/dev/null; then
        pass "login-privileged-every.sh executed as root (uid=0, $count line(s))"
    else
        fail "login-privileged-every.sh executed but NOT as root"
    fi
    if $HAS_SECOND_PASS; then
        sidecar="$RESULTS_DIR/login-privileged-every.ran.firstpass"
        if [[ -f "$sidecar" ]]; then
            first=$(cat "$sidecar")
            total=$(marker_count "login-privileged-every.ran")
            second=$(( total - first ))
            if (( second >= 1 )); then
                pass "login-privileged-every.sh ran on second pass ($second time(s)) — correct every-type behaviour"
            else
                fail "login-privileged-every.sh did not run on second pass"
            fi
        else
            warn "No first-pass sidecar for login-privileged-every"
        fi
    fi
else
    warn "login-privileged-every.sh did not execute — may be expected if no console user was present"
fi

# ── On-demand modes ───────────────────────────────────────────────────────────
header "on-demand"
count=$(marker_count "on-demand.ran")
if (( count >= 1 )); then
    pass "on-demand.sh executed ($count line(s))"
    # on-demand scripts should be cleaned up afterwards
    if [[ ! -f "/usr/local/outset/on-demand/on-demand.sh" ]]; then
        pass "on-demand.sh was removed from on-demand directory after execution (cleanup ran)"
    else
        warn "on-demand.sh still present in on-demand directory — did cleanup run?"
    fi
else
    fail "on-demand.sh did not execute — marker file missing or empty"
fi

header "on-demand-privileged"
count=$(marker_count "on-demand-privileged.ran")
if (( count >= 1 )); then
    if grep -q "uid=0" "$RESULTS_DIR/on-demand-privileged.ran" 2>/dev/null; then
        pass "on-demand-privileged.sh executed as root (uid=0, $count line(s))"
    else
        fail "on-demand-privileged.sh executed but NOT as root"
    fi
    if [[ ! -f "/usr/local/outset/on-demand-privileged/on-demand-privileged.sh" ]]; then
        pass "on-demand-privileged.sh was removed after execution (cleanup ran)"
    else
        warn "on-demand-privileged.sh still present — did cleanup run?"
    fi
else
    fail "on-demand-privileged.sh did not execute — marker file missing or empty"
fi

# ── Log checks ────────────────────────────────────────────────────────────────
header "Outset log spot-checks"

if [[ -f "$LOG_FILE" ]]; then
    # These strings appear in the outset log when each mode starts
    declare -A log_checks=(
        ["Boot mode started"]="boot"
        ["Login mode started"]="login"
        ["Login Privileged mode started"]="login-privileged"
        ["On Demand mode started"]="on-demand"
    )
    for msg in "${(@k)log_checks}"; do
        if log_contains "$msg"; then
            pass "Log contains: \"$msg\""
        else
            warn "Log does not contain: \"$msg\" (mode may use different wording — check manually)"
        fi
    done
    if log_contains "ERROR"; then
        fail "Outset log contains ERROR entries — review $LOG_FILE"
        print "       Matching lines:"
        grep "ERROR" "$LOG_FILE" | tail -10 | sed 's/^/         /'
    else
        pass "No ERROR entries in outset log"
    fi
else
    warn "Log file not found — skipping log checks"
fi

# ── Login-window note ─────────────────────────────────────────────────────────
header "login-window (manual verification required)"
print "  SKIP  login-window mode cannot be triggered from a shell — it only"
print "        runs in the LoginWindow launchd session before a user logs in."
print "        To test manually: place a script in /usr/local/outset/login-window/,"
print "        restart the Mac, and check the outset log after reaching the login"
print "        window (before authenticating)."

# ── Summary ───────────────────────────────────────────────────────────────────
print "\n${BLD}── Summary ─────────────────────────────────────────────────────────────${RST}"
TOTAL=$(( PASS + FAIL + WARN ))
print "  Total checks : $TOTAL"
print "  ${GRN}Passed${RST}       : $PASS"
print "  ${RED}Failed${RST}       : $FAIL"
print "  ${YLW}Warnings${RST}     : $WARN"
print ""
print "  Results dir  : $RESULTS_DIR"
print "  Outset log   : $LOG_FILE"
print ""

if (( FAIL > 0 )); then
    print "${RED}${BLD}RESULT: FAILED ($FAIL check(s) failed)${RST}"
    exit 1
else
    print "${GRN}${BLD}RESULT: PASSED${RST}"
    exit 0
fi
