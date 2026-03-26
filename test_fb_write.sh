#!/bin/bash

# Configuration
FB_FILE=${1:-/tmp/xvfb_fb/Xvfb_screen0}
WIDTH=800
HEIGHT=600
BPP=2 # 16-bit
STRIDE=$((WIDTH * BPP))

# Function to draw a pixel
# Usage: set_pixel x y r g b
# RGB565 format: RRRRRGGG GGGBBBBB
set_pixel() {
    local x=$1
    local y=$2
    local r=$3
    local g=$4
    local b=$5

    # Scale 0-255 to 5 or 6 bits
    r=$(( (r * 31) / 255 ))
    g=$(( (g * 63) / 255 ))
    b=$(( (b * 31) / 255 ))

    local val=$(( (r << 11) | (g << 5) | b ))
    local low=$(( val & 0xFF ))
    local high=$(( (val >> 8) & 0xFF ))

    local offset=$(( (y * WIDTH + x) * BPP ))

    # Use dd to write the 2 bytes
    printf "$(printf '\\x%02x\\x%02x' $low $high)" | dd of="$FB_FILE" bs=1 seek=$offset count=2 conv=notrunc 2>/dev/null
}

# Example usage
# Clear screen to a dark blue
# This is slow with dd, better use a larger block or dd from /dev/zero
# dd if=/dev/zero of="$FB_FILE" bs=$((WIDTH * HEIGHT * BPP)) count=1 conv=notrunc 2>/dev/null

# Draw a red square
for y in {100..200}; do
    for x in {100..200}; do
        set_pixel $x $y 255 0 0
    done
done
