#!/bin/zsh
# Outset integration test payload: on-demand-privileged
# Expected: runs as root each time outset --on-demand-privileged is triggered,
# then the script is removed by the cleanup run mode.
MARKER="/private/tmp/outset-test-results/on-demand-privileged.ran"
mkdir -p "$(dirname "$MARKER")"
echo "on-demand-privileged ran at $(date) as $(id -un) (uid=$(id -u))" >> "$MARKER"
