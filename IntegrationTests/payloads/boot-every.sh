#!/bin/zsh
# Outset integration test payload: boot-every
# Expected: runs on every boot invocation.
MARKER="/private/tmp/outset-test-results/boot-every.ran"
mkdir -p "$(dirname "$MARKER")"
echo "boot-every ran at $(date)" >> "$MARKER"
