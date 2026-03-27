#!/bin/bash

# Configuration
SERIAL_PORT=${1:-/tmp/ttyS0}

echo "Bash verification generator starting (speed up). Writing to $SERIAL_PORT..."

# Generate a pattern to verify scaling and scrolling
val1=0
while true; do
    echo "$val1,50,20" > "$SERIAL_PORT"
    val1=$(( (val1 + 10) % 110 )) # 0, 10, ..., 100, 0
    # Faster generation (0.5s) to trigger scrolling quickly
    sleep 0.5
done
