#!/bin/zsh
# Outset integration test payload: boot-once
# Expected: runs exactly once at boot; subsequent boots should not re-run it.
MARKER="/private/tmp/outset-test-results/boot-once.ran"
mkdir -p "$(dirname "$MARKER")"
echo "boot-once ran at $(date)" >> "$MARKER"
