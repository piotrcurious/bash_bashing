#!/bin/bash

# Configuration
SERIAL_PORT=${1:-/tmp/ttyS0}

echo "Bash generator started. Writing to $SERIAL_PORT..."

while true; do
    values=""
    for i in {1..20}; do
        # Simple random data for bash
        val=$(( RANDOM % 100 ))
        values+="$val,"
    done
    values=${values%,}
    echo "$values" > "$SERIAL_PORT"
    sleep 2
done
