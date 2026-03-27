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

# RGB565 Colors (Little Endian)
# Red: 0xF800 -> \x00\xF8
# Green: 0x07E0 -> \xE0\x07
# Blue: 0x001F -> \x1F\x00
COLORS=("\x00\xF8" "\xE0\x07" "\x1F\x00" "\xE0\xFF" "\xFF\x07" "\x1F\xF8")
COLOR_GRID="\x08\x42" # Dark Grey
COLOR_BLACK="\x00\x00"

GRID_LINE=$(printf "$COLOR_GRID"%.0s {1..700})
WORK_FB="/tmp/fb_work"
TEMPLATE_FB="/tmp/fb_template"

echo "Initializing pure bash plotter (pre-calculating template)..."

# Initial full screen clear
dd if=/dev/zero of="$FB_FILE" bs=$((WIDTH * HEIGHT * BPP)) count=1 conv=notrunc 2>/dev/null

# Pre-calculate a background template (grid)
dd if=/dev/zero of="$TEMPLATE_FB" bs=$((WIDTH * HEIGHT * BPP)) count=1 2>/dev/null
for ((y=GRAPH_Y; y<GRAPH_Y+GRAPH_H; y++)); do
    offset=$(( (y * WIDTH + GRAPH_X) * BPP ))
    if [ $y -eq $GRAPH_Y ] || [ $y -eq $((GRAPH_Y+GRAPH_H-1)) ]; then
        printf "$GRID_LINE" | dd of="$TEMPLATE_FB" bs=1 seek=$offset count=$((GRAPH_W * BPP)) conv=notrunc 2>/dev/null
    else
        printf "$COLOR_GRID" | dd of="$TEMPLATE_FB" bs=1 seek=$offset count=2 conv=notrunc 2>/dev/null
        printf "$COLOR_GRID" | dd of="$TEMPLATE_FB" bs=1 seek=$((offset + (GRAPH_W-1)*BPP)) count=2 conv=notrunc 2>/dev/null
    fi
done

echo "Pure bash compound plotter starting. Reading from $SERIAL_PORT..."

history=()
max_history=40 # Reduced for speed

exec 3< "$SERIAL_PORT"

while read -r line <&3; do
    [[ -z "$line" ]] && continue

    # Update history
    history+=("$line")
    [[ ${#history[@]} -gt $max_history ]] && history=("${history[@]:1}")

    # Use the work buffer to avoid flickering/incomplete frames
    cat "$TEMPLATE_FB" > "$WORK_FB"

    num_points=${#history[@]}
    [[ $num_points -lt 2 ]] && continue

    # Plot channels
    for ((ch=0; ch<3; ch++)); do
        color=${COLORS[$ch]}

        # Get first point
        IFS=',' read -ra ADDR <<< "${history[0]}"
        val=${ADDR[$ch]%.*}
        prev_x=$GRAPH_X
        prev_y=$(( GRAPH_Y + GRAPH_H - (val * GRAPH_H / 100) ))

        for ((i=1; i<num_points; i++)); do
            IFS=',' read -ra ADDR <<< "${history[$i]}"
            val=${ADDR[$ch]%.*}

            x=$(( GRAPH_X + i * GRAPH_W / (max_history - 1) ))
            y=$(( GRAPH_Y + GRAPH_H - (val * GRAPH_H / 100) ))

            # Simple line drawing: just start and end points and midpoint for speed
            # Pure bash can't do full Bresenham at this scale efficiently.

            # Draw points
            offsets=()
            offsets+=($(( (prev_y * WIDTH + prev_x) * BPP )))
            offsets+=($(( (y * WIDTH + x) * BPP )))
            # Midpoint
            mid_x=$(( (prev_x + x) / 2 ))
            mid_y=$(( (prev_y + y) / 2 ))
            offsets+=($(( (mid_y * WIDTH + mid_x) * BPP )))

            for offset in "${offsets[@]}"; do
                printf "$color" | dd of="$WORK_FB" bs=1 seek=$offset count=2 conv=notrunc 2>/dev/null
            done

            prev_x=$x
            prev_y=$y
        done
    done

    # Atomic update
    cat "$WORK_FB" > "$FB_FILE"
done
