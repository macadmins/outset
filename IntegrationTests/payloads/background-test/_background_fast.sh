#!/bin/zsh
# Background script — prefixed with _ so outset runs it concurrently.
# Completes quickly, before the foreground scripts finish.
# Demonstrates that background tasks finishing early don't block anything.
echo "background-fast: start"
sleep 1
echo "background-fast: done (after 1s)"
