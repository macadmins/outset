#!/bin/zsh
# Outset integration test payload: login-privileged-once
# Expected: runs exactly once as root, triggered from the login LaunchAgent.
MARKER="/private/tmp/outset-test-results/login-privileged-once.ran"
mkdir -p "$(dirname "$MARKER")"
echo "login-privileged-once ran at $(date) as $(id -un) (uid=$(id -u))" >> "$MARKER"
