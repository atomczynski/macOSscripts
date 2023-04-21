#!/bin/bash

## Script to test and document device charge,
## as well as deplete battery "quickly".

#################
### VARIABLES ###
#################

TICKER=300 #Number of seconds between each watch.
LOG="/Users/Shared/chargeWatcher.log"
CORE_COUNT=$(sysctl -n hw.ncpu)

#################
### FUNCTIONS ###
#################

## Sends updates to process running script and log.
logLogger () {
    echo -e "$1"
    echo -e "$1" >> "$LOG"
}

## Save to variable whether device is connected to AC Power or Battery Power.
powerQuery () {
    POWER=$(pmset -g batt | head -n 1 | cut -d \' -f2)
}

## Gives screen caffeine and prompts beginning.
startUp () {
    SECONDS=0
    logLogger "\nPIDs:Beginning $PROCESS process at $(date +%Y-%m-%d\ %H:%M:%S)..."
    caffeinate -d & FLEET_PIDS="$!"
}

## Sends updates on charge.
chargeUpdate () {
    PERCENT=$(pmset -g ps | awk '/InternalBattery/{gsub(";","");print $3}')
    logLogger "$(date +%Y-%m-%d\ %H:%M:%S) | process: $PROCESS $SUBTYPE | charge: $PERCENT"
}

## Spawns (yes) processes equal to number (device core count).
fleetSpawner () {
    COUNT=0
    until [ "$COUNT" -eq "$2" ]; do
        COUNT=$((COUNT+1))
        "$1" > /dev/null &
        FLEET_PIDS="$FLEET_PIDS $!"
    done
}

## Runs cleanUp function and exits if interrupt signal is received.
haltProcess () {
    cleanUp "\nReceived interrupt signal."
    exit 0
}

## Sends duration to log and kills background processes.
cleanUp () {
    DURATION=$SECONDS
    logLogger "$1 Duration: $((DURATION / 3600)) hours, $(((DURATION / 60) % 60)) minutes and $((DURATION % 60)) seconds. Terminating processes and exiting..."
    for pid in $FLEET_PIDS; do kill "$pid"; wait "$pid" 2>/dev/null; done
}

## Initial prompt to select process.
processDialog () {
    PROCESS=$(osascript 2>&1 <<END
        beep
        button returned of (display dialog ¬
            "Choose to either log the battery with Charge or Deplete.\n\n\
Charge - Log battery level every $TICKER seconds.\n\
Deplete - Log battery level every $TICKER seconds while purposely being depleted.\n\n\
Screen will be caffeinated in either process." ¬
            buttons {"Cancel","Deplete", "Charge"} ¬
            default button {"Charge"} ¬
            with title "chargeWatcher" ¬
            with icon POSIX file "/System/Library/CoreServices/CoreTypes.bundle/Contents/Resources/MagnifyingGlassIcon.icns")
END
)
}

## Verify power source aligns with process and prompts user if not matching.
chargerCheck () {
    powerQuery
    if [ "$PROCESS" == "Deplete" ] && [ "$POWER" == "AC Power" ]; then
        until [ "$POWER" == "Battery Power" ]; do
            powerQuery
            CHE_RES=$(osascript 2>&1 <<END
                beep
                button returned of (display dialog ¬
                    "Charger is plugged in. Disconnect charger and click OK to begin deplete watch.\n\n\
To override this to watch the charge while actively depleting battery, click Override." ¬
                    buttons {"Cancel","Override","OK"} ¬
                    default button {"OK"} ¬
                    with title "chargeWatcher" ¬
                    with icon POSIX file "/System/Library/CoreServices/CoreTypes.bundle/Contents/Resources/MagnifyingGlassIcon.icns")
END
)
            echo "$CHE_RES" | grep -q "User canceled." && exit 0
            [ "$CHE_RES" == "Override" ] && SUBTYPE="(w/ AC Power)" && break
        done
    elif [ "$PROCESS" == "Charge" ] && [ "$POWER" == "Battery Power" ]; then
        until [ "$POWER" == "AC Power" ] || [ "$CHE_RES" == "Override" ]; do
            powerQuery
            CHE_RES=$(osascript 2>&1 <<END
                beep
                button returned of (display dialog ¬
                    "Charger is not plugged in. Connect charger and click OK to begin charge watch.\n\n\
To override this to watch the charge deplete normally, click Override." ¬
                    buttons {"Cancel","Override","OK"} ¬
                    default button {"OK"} ¬
                    with title "chargeWatcher" ¬
                    with icon POSIX file "/System/Library/CoreServices/CoreTypes.bundle/Contents/Resources/MagnifyingGlassIcon.icns")
END
)
            echo "$CHE_RES" | grep -q "User canceled." && exit 0
            [ "$CHE_RES" == "Override" ] && SUBTYPE="(w/o AC Power)" && break
        done
    fi
}

## Dialog shown when running a process adds it to processes to be killed when finished.
runningDialog () {
    osascript 2>&1 <<END > /dev/null &
        beep
        display dialog ¬
            "Now running $PROCESS. Outputting updates to both stdout and log:\n$LOG\n
Clicking OK will close this dialog, but not interrupt the process. Processes will be terminated on an interrupt signal. \
To interrupt the script running in Terminal, press Control-C in terminal.\n
In case of termination failures, see beginning of process log for PIDs of all background processes." ¬
            buttons {"OK"} ¬
            default button {"OK"} ¬
            with title "chargeWatcher" ¬
            with icon POSIX file "/System/Library/CoreServices/CoreTypes.bundle/Contents/Resources/MagnifyingGlassIcon.icns"
END
    FLEET_PIDS="$FLEET_PIDS $!"
}

############
### BODY ###
############

trap haltProcess INT
processDialog
chargerCheck
if [ "$PROCESS" == "Charge" ]; then
    startUp
    runningDialog
    logLogger "PIDS: $FLEET_PIDS"
    until [ "$PERCENT" == "100%" ]; do
        chargeUpdate
        sleep "$TICKER"
    done
    cleanUp "$PROCESS process finished."
elif [ "$PROCESS" == "Deplete" ]; then
    startUp
    fleetSpawner yes "$CORE_COUNT"
    runningDialog
    logLogger "PIDS: $FLEET_PIDS"
    until [ "$PERCENT" == "1%" ] || [ "$PERCENT" == "2%" ] || [ "$PERCENT" == "3%" ]; do
        chargeUpdate
        sleep "$TICKER"
    done
    cleanUp "$PROCESS process finished."
elif echo "$PROCESS" | grep -q "User canceled"; then
    echo "User cancelled."
fi