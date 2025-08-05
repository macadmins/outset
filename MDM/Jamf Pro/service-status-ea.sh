#!/bin/zsh

currentUser=$( echo "show State:/Users/ConsoleUser" | scutil | awk '/Name :/ { print $3 }' )
ROOT_PATH="/usr/local/outset"
BUNDLE="Outset.app"
AGENTS="Contents/Library/LaunchAgents"
DAEMONS="Contents/Library/LaunchDaemons"

# Get a count of what we expect from the agents and daemons listed in the app bundle
EXPECTED_AGENTS=$(ls ${ROOT_PATH}/${BUNDLE}/${AGENTS} | wc -l)
EXPECTED_DAEMONS=$(ls ${ROOT_PATH}/${BUNDLE}/${DAEMONS} | wc -l)

# Indicate if all the Outset daemons are enabled or not.
outsetStatusRaw=$(${ROOT_PATH}/outset --service-status)
enabledDaemons=$(echo $outsetStatusRaw | grep -c 'Enabled$')

# We expect all services to be present and loaded
expectedServices=$(( EXPECTED_AGENTS + EXPECTED_DAEMONS ))

# If there is no user logged in, none of the agents will be active, only the daemons.
if [ -z "${currentUser}" -o "${currentUser}" = "loginwindow" ]; then
  expectedServices=${EXPECTED_DAEMONS}
fi

healthyStatus="Not Healthy"

if [ ${enabledDaemons} -eq ${expectedServices} ]; then
	healthyStatus="Healthy"
fi

echo "<result>$healthyStatus</result>"