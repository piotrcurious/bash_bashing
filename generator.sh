#!/bin/bash

# Configuration
SERIAL_PORT=${1:-/tmp/ttyS0}

echo "Bash generator (dynamic range version) started. Writing to $SERIAL_PORT..."

# Use awk for calculation of dynamic range signals
phase=0
while true; do
    # Generate 3 channels with varying amplitude over time
    val=$(awk -v p="$phase" 'BEGIN {
        # Amplitude factor cycles over time (dynamic range)
        amp = 20 + 20 * sin(p * 0.1);

        x1 = p;
        v1 = 50 + amp * (sin(x1) + 0.5 * sin(2.5 * x1));

        x2 = p * 1.5;
        v2 = 50 + (amp * 0.8) * (sin(x2) + 0.3 * sin(5.1 * x2));

        x3 = p * 0.7;
        v3 = 30 + (amp * 0.5) * (sin(x3) + 0.2 * sin(10.1 * x3));

        printf "%.0f,%.0f,%.0f", v1, v2, v3
    }')
    echo "$val" > "$SERIAL_PORT"
    phase=$(awk -v p="$phase" 'BEGIN { print p + 0.5 }')
    sleep 5
done
