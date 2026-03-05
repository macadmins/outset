#!/bin/zsh
# Outset integration test payload: login-every
# Expected: runs on every login invocation.
MARKER="/private/tmp/outset-test-results/login-every.ran"
mkdir -p "$(dirname "$MARKER")"
echo "login-every ran at $(date) as $(id -un)" >> "$MARKER"
