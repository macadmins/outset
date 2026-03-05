#!/bin/zsh
# Foreground script A — runs first, sequentially.
# Should complete before foreground B starts.
echo "foreground-a: start"
sleep 2
echo "foreground-a: step 1 (after 2s)"
sleep 2
echo "foreground-a: done (after 4s)"
