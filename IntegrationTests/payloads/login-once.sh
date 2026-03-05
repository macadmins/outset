#!/bin/zsh
# Outset integration test payload: login-once
# Expected: runs exactly once per user; second login should not re-run it.
MARKER="/private/tmp/outset-test-results/login-once.ran"
mkdir -p "$(dirname "$MARKER")"
echo "login-once ran at $(date) as $(id -un)" >> "$MARKER"
