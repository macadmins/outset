#!/bin/zsh

# Shows the current service status (Enabled, Not Registered, Requires Approval or Not Found).

outsetStatus=$(/usr/local/outset/outset --service-status)
echo "<result>$outsetStatus</result>"