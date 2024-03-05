#!/bin/zsh

# Indicate if all the Outset daemons are enabled or not.

outsetStatusRaw=$(/usr/local/outset/outset --service-status)
enabledDaemons=$(echo $outsetStatusRaw | grep -c 'Enabled$')

healthyStatus="Not Healthy"

if [ $enabledDaemons -eq 6 ]; then
	healthyStatus="Healthy"
fi

echo "<result>$healthyStatus</result>"