#!/bin/bash

# Configuration
SERIAL_PORT=${1:-/tmp/ttyS0}

echo "Bash verification generator starting (speed up v2). Writing to $SERIAL_PORT..."

# Generate a clear pattern to verify scaling and scrolling
# Channel 1: Ramp 0 -> 100
val1=0
while true; do
    echo "$val1,50,20" > "$SERIAL_PORT"
    val1=$(( (val1 + 10) % 110 ))
    # Fast generation (0.2s)
    sleep 0.2
done
