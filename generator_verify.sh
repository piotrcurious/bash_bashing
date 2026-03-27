#!/bin/bash

# Configuration
SERIAL_PORT=${1:-/tmp/ttyS0}

echo "Bash verification generator starting. Writing to $SERIAL_PORT..."

# Generate a clear pattern to verify scaling and scrolling
# Channel 1: Ramp 0 -> 100
# Channel 2: Constant 50
# Channel 3: Constant 20
val1=0
while true; do
    echo "$val1,50,20" > "$SERIAL_PORT"
    val1=$(( (val1 + 10) % 110 )) # 0, 10, ..., 100, 0
    sleep 3
done
