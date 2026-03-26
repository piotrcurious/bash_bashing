#!/bin/bash

# Configuration
SERIAL_PORT=${1:-/tmp/ttyS0}

echo "Bash generator (compound sine) started. Writing to $SERIAL_PORT..."

# Using a more robust sine wave generation in bash (using bc)
phase=0
while true; do
    values=""
    for ((i=0; i<50; i++)); do
        # Use awk for math since bash doesn't have sin()
        # Compound: sin(x) + 0.5*sin(2.5x) + 0.2*sin(5.1x)
        val=$(awk -v p="$phase" -v i="$i" 'BEGIN {
            x = p + i * 0.2;
            v = 50 + 25 * (sin(x) + 0.5 * sin(2.5 * x) + 0.2 * sin(5.1 * x));
            printf "%.0f", v
        }')
        values+="$val,"
    done
    values=${values%,}
    echo "$values" > "$SERIAL_PORT"
    phase=$(awk -v p="$phase" 'BEGIN { print p + 0.5 }')
    sleep 1
done
