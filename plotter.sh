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

# Pre-calculate strings for batch drawing
GRID_LINE=$(printf "$COLOR_GRID"%.0s {1..700})
BLACK_LINE=$(printf "$COLOR_BLACK"%.0s {1..700})

echo "Initializing pure bash plotter (pre-calculating template)..."

# Initial full screen clear
dd if=/dev/zero of="$FB_FILE" bs=$((WIDTH * HEIGHT * BPP)) count=1 conv=notrunc 2>/dev/null

# Pre-calculate a background template (grid) for faster clearing
# This is a pure bash task that speeds up the live loop.
dd if=/dev/zero of=/tmp/fb_template bs=$((WIDTH * HEIGHT * BPP)) count=1 2>/dev/null
for ((y=GRAPH_Y; y<GRAPH_Y+GRAPH_H; y++)); do
    offset=$(( (y * WIDTH + GRAPH_X) * BPP ))
    if [ $y -eq $GRAPH_Y ] || [ $y -eq $((GRAPH_Y+GRAPH_H-1)) ]; then
        printf "$GRID_LINE" | dd of=/tmp/fb_template bs=1 seek=$offset count=$((GRAPH_W * BPP)) conv=notrunc 2>/dev/null
    else
        printf "$COLOR_GRID" | dd of=/tmp/fb_template bs=1 seek=$offset count=2 conv=notrunc 2>/dev/null
        printf "$COLOR_GRID" | dd of=/tmp/fb_template bs=1 seek=$((offset + (GRAPH_W-1)*BPP)) count=2 conv=notrunc 2>/dev/null
    fi
done

echo "Starting pure bash live loop..."

# Read from serial port
exec 3< "$SERIAL_PORT"

while read -r line <&3; do
    [[ -z "$line" ]] && continue

    # Fast clear by copying the template
    cat /tmp/fb_template > "$FB_FILE"

    IFS=',' read -ra ADDR <<< "$line"
    num_vals=${#ADDR[@]}
    [[ $num_vals -lt 2 ]] && continue

    # Calculate points and draw
    val=${ADDR[0]%.*}
    prev_x=$GRAPH_X
    prev_y=$(( GRAPH_Y + GRAPH_H - (val * GRAPH_H / 100) ))

    # Pure bash line drawing (grouping steps as much as possible)
    # Since dd is the only way to seek, we limit its calls.
    for ((i=1; i<num_vals; i++)); do
        x=$(( GRAPH_X + i * GRAPH_W / (num_vals - 1) ))
        val=${ADDR[i]%.*}
        y=$(( GRAPH_Y + GRAPH_H - (val * GRAPH_H / 100) ))

        dx=$(( x - prev_x ))
        dy=$(( y - prev_y ))
        abs_dy=${dy#-}

        steps=$dx
        if [ $abs_dy -gt $dx ]; then steps=$abs_dy; fi

        # Performance optimization for pure bash: skip points
        # Only draw enough to looks somewhat like a line
        step_inc=1
        if [ $steps -gt 20 ]; then step_inc=$(( steps / 5 )); fi

        for ((s=0; s<=steps; s+=step_inc)); do
            curr_x=$(( prev_x + s * dx / steps ))
            curr_y=$(( prev_y + s * dy / steps ))
            offset=$(( (curr_y * WIDTH + curr_x) * BPP ))
            # Only dd can seek, so we have to call it here.
            printf "$COLOR_LINE" | dd of="$FB_FILE" bs=1 seek=$offset count=2 conv=notrunc 2>/dev/null
        done

        prev_x=$x
        prev_y=$y
    done
done
