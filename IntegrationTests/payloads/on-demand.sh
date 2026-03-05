#!/bin/zsh
# Outset integration test payload: on-demand
# Expected: runs each time outset --on-demand is triggered, then the script
# is removed from the on-demand directory by the cleanup run mode.
MARKER="/private/tmp/outset-test-results/on-demand.ran"
mkdir -p "$(dirname "$MARKER")"
echo "on-demand ran at $(date) as $(id -un)" >> "$MARKER"
