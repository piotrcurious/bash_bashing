#!/bin/bash

# Configuration
SERIAL_PORT=${1:-/tmp/ttyS0}

echo "Bash generator (pure bash version) started. Writing to $SERIAL_PORT..."

# Use awk for calculation as it's cleaner for compound sine waves
phase=0
while true; do
    values=""
    for ((i=0; i<20; i++)); do
        val=$(awk -v p="$phase" -v i="$i" 'BEGIN {
            x = p + i * 0.4;
            v = 50 + 25 * (sin(x) + 0.5 * sin(2.5 * x));
            printf "%.0f", v
        }')
        values+="$val,"
    done
    values=${values%,}
    echo "$values" > "$SERIAL_PORT"
    phase=$(awk -v p="$phase" 'BEGIN { print p + 0.5 }')
    sleep 5
done
