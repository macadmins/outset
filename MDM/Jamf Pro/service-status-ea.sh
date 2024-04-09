#!/bin/zsh

# Indicate if all the Outset daemons are enabled or not.

outsetStatusRaw=$(/usr/local/outset/outset --service-status)
enabledDaemons=$(echo $outsetStatusRaw | grep -c 'Enabled$')

# If there is no user logged in, none of the 3 agents will be active, only the daemons.

expectedServices=6

currentUser=$( echo "show State:/Users/ConsoleUser" | scutil | awk '/Name :/ { print $3 }' )

if [ -z "$currentUser" -o "$currentUser" = "loginwindow" ]; then
  expectedServices=3
fi

healthyStatus="Not Healthy"

if [ $enabledDaemons -eq $expectedServices ]; then
	healthyStatus="Healthy"
fi

echo "<result>$healthyStatus</result>"