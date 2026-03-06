#!/bin/zsh
# Background script — prefixed with _ so outset runs it concurrently.
# Deliberately slow with periodic output to demonstrate log interleaving
# with the foreground scripts that run at the same time.
echo "background-slow: start"
sleep 1
echo "background-slow: tick 1 (after 1s)"
sleep 2
echo "background-slow: tick 2 (after 3s)"
sleep 2
echo "background-slow: tick 3 (after 5s)"
sleep 2
echo "background-slow: done (after 7s)"
