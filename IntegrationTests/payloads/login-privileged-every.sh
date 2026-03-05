#!/bin/zsh
# Outset integration test payload: login-privileged-every
# Expected: runs as root on every login.
MARKER="/private/tmp/outset-test-results/login-privileged-every.ran"
mkdir -p "$(dirname "$MARKER")"
echo "login-privileged-every ran at $(date) as $(id -un) (uid=$(id -u))" >> "$MARKER"
