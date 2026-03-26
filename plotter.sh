#!/bin/bash

# Configuration
SERIAL_PORT=${1:-/tmp/ttyS1}
FB_FILE=${2:-/tmp/xvfb_fb/Xvfb_screen0}
WIDTH=800
HEIGHT=600
BPP=2 # 16-bit RGB565

# Graph area
GRAPH_X=50
GRAPH_Y=50
GRAPH_W=700
GRAPH_H=500

COLOR_LINE="\x00\xF8" # Red in RGB565 (Little Endian: 00 F8)
COLOR_GRID="\x08\x42" # Dark Grey
COLOR_BLACK="\x00\x00"

# Function to draw a pixel
draw_pixel() {
    local x=$1
    local y=$2
    local color_bytes=$3 # e.g. "\x00\xF8"
    local offset=$(( (y * WIDTH + x) * BPP ))
    printf "$color_bytes" | dd of="$FB_FILE" bs=1 seek=$offset count=2 conv=notrunc 2>/dev/null
}

# Function to draw a horizontal line efficiently
draw_hline() {
    local x=$1
    local y=$2
    local w=$3
    local color_bytes=$4
    local offset=$(( (y * WIDTH + x) * BPP ))

    # Create a string of color bytes
    local line=""
    for ((i=0; i<w; i++)); do
        line+="$color_bytes"
    done
    printf "$line" | dd of="$FB_FILE" bs=1 seek=$offset count=$((w * BPP)) conv=notrunc 2>/dev/null
}

clear_graph() {
    # Clear graph area
    for ((y=GRAPH_Y; y<GRAPH_Y+GRAPH_H; y++)); do
        draw_hline $GRAPH_X $y $GRAPH_W "$COLOR_BLACK"
    done

    # Draw border
    draw_hline $GRAPH_X $GRAPH_Y $GRAPH_W "$COLOR_GRID"
    draw_hline $GRAPH_X $((GRAPH_Y+GRAPH_H-1)) $GRAPH_W "$COLOR_GRID"
    # Vertical lines (slow with draw_pixel, but let's keep it simple)
    for ((y=GRAPH_Y; y<GRAPH_Y+GRAPH_H; y++)); do
        draw_pixel $GRAPH_X $y "$COLOR_GRID"
        draw_pixel $((GRAPH_X+GRAPH_W-1)) $y "$COLOR_GRID"
    done
}

# Clear screen initially
dd if=/dev/zero of="$FB_FILE" bs=$((WIDTH * HEIGHT * BPP)) count=1 conv=notrunc 2>/dev/null

echo "Bash plotter started. Reading from $SERIAL_PORT..."

clear_graph

exec 3< "$SERIAL_PORT"

while read -r line <&3; do
    [[ -z "$line" ]] && continue

    clear_graph

    IFS=',' read -ra ADDR <<< "$line"
    num_vals=${#ADDR[@]}
    [[ $num_vals -lt 2 ]] && continue

    prev_x=$GRAPH_X
    # Scale first value
    val=${ADDR[0]%.*} # Integer part
    prev_y=$(( GRAPH_Y + GRAPH_H - (val * GRAPH_H / 100) ))

    for ((i=1; i<num_vals; i++)); do
        x=$(( GRAPH_X + i * GRAPH_W / (num_vals - 1) ))
        val=${ADDR[i]%.*}
        y=$(( GRAPH_Y + GRAPH_H - (val * GRAPH_H / 100) ))

        # Draw a simple line using Bresenham's (roughly)
        # To speed up bash, we only draw a few points between prev and current
        dx=$(( x - prev_x ))
        dy=$(( y - prev_y ))
        abs_dy=${dy#-}

        steps=$dx
        if [ $abs_dy -gt $dx ]; then steps=$abs_dy; fi
        if [ $steps -eq 0 ]; then steps=1; fi

        for ((s=0; s<=steps; s++)); do
            curr_x=$(( prev_x + s * dx / steps ))
            curr_y=$(( prev_y + s * dy / steps ))
            draw_pixel $curr_x $curr_y "$COLOR_LINE"
        done

        prev_x=$x
        prev_y=$y
    done
done
