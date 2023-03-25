#!/bin/sh

#  preinstall.sh
#  Outset
#
#  Created by Bart Reardon on 25/3/2023.
#  

## Process legacy launchd items if upgrading from outset 3.0.3 or earlier

LD_ROOT="/Library/LaunchDaemons"
LA_ROOT="/Library/LaunchAgents"
OUTSET_ROOT="/usr/local/outset"
OUTSET_BACKUP="${OUTSET_ROOT}/backup"

USER_ID=$(id -u $(stat -f %Su /dev/console))

## LaunchDaemons
DAEMONS=(
  "${LD_ROOT}/com.github.outset.boot.plist"
  "${LD_ROOT}/com.github.outset.cleanup.plist"
  "${LD_ROOT}/com.github.outset.login-privileged.plist"
)

## LaunchAgents
AGENTS=(
  "${LA_ROOT}/com.github.outset.login.plist"
  "${LA_ROOT}/com.github.outset.on-demand.plist"
)

# Unload if present
for daemon in ${DAEMONS}; do
    if [ -e "${daemon}" ]; then
        /bin/launchctl bootout system "${daemon}"
        sudo rm -fv "${daemon}"
    fi
done

for agent in ${AGENTS}; do
    if [ -e "${agent}" ]; then
        if [ ${USER_ID} -ne 0 ]; then
            launchctl bootout gui/${USER_ID} "${agent}"
        fi
        sudo rm -fv "${agent}"
    fi
done

# backup existing preference files
mkdir -p "${OUTSET_BACKUP}"

if [ -e "${OUTSET_ROOT}/share" ]; then
    cp "${OUTSET_ROOT}/share/*" "${OUTSET_BACKUP}/"
fi

for user in $(ls /Users); do
    if [ -e "/Users/${user}/Library/Preferences/com.github.outset.once.plist" ]; then
        mkdir -p "${OUTSET_ROOT}/backup/${user}"
        cp "/Users/${user}/Library/Preferences/com.github.outset.once.plist" "${OUTSET_BACKUP}/${user}/"
    fi
done
