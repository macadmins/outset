#!/bin/zsh
# Foreground script B — runs after A finishes, sequentially.
echo "foreground-b: start"
sleep 2
echo "foreground-b: done (after 2s)"
