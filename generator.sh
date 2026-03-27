#!/bin/bash

# Configuration
SERIAL_PORT=${1:-/tmp/ttyS0}

echo "Bash generator (multi-channel compound version) started. Writing to $SERIAL_PORT..."

# Use awk for calculation as it's cleaner for multi-channel compound sine waves
phase=0
while true; do
    # Generate 3 channels
    val=$(awk -v p="$phase" 'BEGIN {
        x1 = p;
        v1 = 50 + 25 * (sin(x1) + 0.5 * sin(2.5 * x1));

        x2 = p * 1.5;
        v2 = 50 + 20 * (sin(x2) + 0.3 * sin(5.1 * x2));

        x3 = p * 0.7;
        v3 = 30 + 15 * (sin(x3) + 0.2 * sin(10.1 * x3));

        printf "%.0f,%.0f,%.0f", v1, v2, v3
    }')
    echo "$val" > "$SERIAL_PORT"
    phase=$(awk -v p="$phase" 'BEGIN { print p + 0.5 }')
    sleep 2
done
