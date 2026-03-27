#!/bin/bash

# Configuration
SERIAL_PORT=${1:-/tmp/ttyS1}
FB_FILE=${2:-/tmp/xvfb_fb/Xvfb_screen0}
WIDTH=800
HEIGHT=600
BPP=2 # 16-bit RGB565

# Graph area
GRAPH_X=50
GRAPH_Y=80 # Room for legends
GRAPH_W=700
GRAPH_H=470

# RGB565 Colors (Little Endian)
# Red: 0xF800, Green: 0x07E0, Blue: 0x001F, Yellow: 0xFFE0, Cyan: 0x07FF, Magenta: 0xF81F
COLORS=("\x00\xF8" "\xE0\x07" "\x1F\x00" "\xE0\xFF" "\xFF\x07" "\x1F\xF8")
COLOR_NAMES=("Red" "Green" "Blue" "Yellow" "Cyan" "Magenta")
COLOR_GRID="\x08\x42" # Dark Grey
COLOR_BLACK="\x00\x00"

GRID_LINE=$(printf "$COLOR_GRID"%.0s {1..700})
WORK_FB="/tmp/fb_work"
TEMPLATE_FB="/tmp/fb_template"

echo "Initializing v3 plotter (pre-calculating template)..."

# Initial screen clear
dd if=/dev/zero of="$FB_FILE" bs=$((WIDTH * HEIGHT * BPP)) count=1 conv=notrunc 2>/dev/null

# Pre-calculate a background template (grid)
dd if=/dev/zero of="$TEMPLATE_FB" bs=$((WIDTH * HEIGHT * BPP)) count=1 2>/dev/null
# Horizontal border
for ((y=GRAPH_Y; y<GRAPH_Y+GRAPH_H; y++)); do
    offset=$(( (y * WIDTH + GRAPH_X) * BPP ))
    if [ $y -eq $GRAPH_Y ] || [ $y -eq $((GRAPH_Y+GRAPH_H-1)) ]; then
        printf "$GRID_LINE" | dd of="$TEMPLATE_FB" bs=1 seek=$offset count=$((GRAPH_W * BPP)) conv=notrunc 2>/dev/null
    else
        printf "$COLOR_GRID" | dd of="$TEMPLATE_FB" bs=1 seek=$offset count=2 conv=notrunc 2>/dev/null
        printf "$COLOR_GRID" | dd of="$TEMPLATE_FB" bs=1 seek=$((offset + (GRAPH_W-1)*BPP)) count=2 conv=notrunc 2>/dev/null
    fi
done

echo "Starting v3 live loop with auto-scaling and legends..."

history=()
max_history=30 # Reduced for speed due to Bresenham's

exec 3< "$SERIAL_PORT"

while read -r line <&3; do
    [[ -z "$line" ]] && continue

    # Update history
    history+=("$line")
    [[ ${#history[@]} -gt $max_history ]] && history=("${history[@]:1}")

    # Auto-scaling: find min/max in current history
    curr_min=999999
    curr_max=-999999
    for entry in "${history[@]}"; do
        IFS=',' read -ra ADDR <<< "$entry"
        for val_raw in "${ADDR[@]}"; do
            val=${val_raw%.*}
            [[ $val -lt $curr_min ]] && curr_min=$val
            [[ $val -gt $curr_max ]] && curr_max=$val
        done
    done

    # Padding
    min_all=$(( curr_min - 5 ))
    max_all=$(( curr_max + 5 ))
    range=$(( max_all - min_all ))
    [[ $range -eq 0 ]] && range=1

    # Atomic update via work buffer
    cat "$TEMPLATE_FB" > "$WORK_FB"

    # Draw legends (boxes)
    IFS=',' read -ra CHANNELS <<< "${history[0]}"
    num_channels=${#CHANNELS[@]}
    for ((ch=0; ch<num_channels; ch++)); do
        [[ $ch -ge ${#COLORS[@]} ]] && break
        color=${COLORS[$ch]}
        legend_x=$(( 50 + ch * 120 ))
        legend_y=20
        # Draw 20x20 box
        for ((ly=legend_y; ly<legend_y+20; ly++)); do
            l_offset=$(( (ly * WIDTH + legend_x) * BPP ))
            # Print color 20 times to fill row
            printf "$color"%.0s {1..20} | dd of="$WORK_FB" bs=1 seek=$l_offset count=40 conv=notrunc 2>/dev/null
        done
    done

    num_points=${#history[@]}
    [[ $num_points -lt 2 ]] && continue

    # Plot channels
    for ((ch=0; ch<num_channels; ch++)); do
        [[ $ch -ge ${#COLORS[@]} ]] && break
        color=${COLORS[$ch]}

        IFS=',' read -ra ADDR <<< "${history[0]}"
        val=${ADDR[$ch]%.*}
        prev_x=$GRAPH_X
        # Scale Y
        prev_y=$(( GRAPH_Y + GRAPH_H - ( (val - min_all) * GRAPH_H / range ) ))
        [[ $prev_y -lt $GRAPH_Y ]] && prev_y=$GRAPH_Y
        [[ $prev_y -ge $((GRAPH_Y+GRAPH_H)) ]] && prev_y=$((GRAPH_Y+GRAPH_H-1))

        for ((i=1; i<num_points; i++)); do
            IFS=',' read -ra ADDR <<< "${history[$i]}"
            val=${ADDR[$ch]%.*}

            x=$(( GRAPH_X + i * GRAPH_W / (max_history - 1) ))
            y=$(( GRAPH_Y + GRAPH_H - ( (val - min_all) * GRAPH_H / range ) ))
            [[ $y -lt $GRAPH_Y ]] && y=$GRAPH_Y
            [[ $y -ge $((GRAPH_Y+GRAPH_H)) ]] && y=$((GRAPH_Y+GRAPH_H-1))

            # Pure Bash Bresenham's line drawing
            dx=$(( x - prev_x ))
            dy=$(( y - prev_y ))
            sx=$(( dx > 0 ? 1 : -1 ))
            sy=$(( dy > 0 ? 1 : -1 ))
            dx=${dx#-}
            dy=${dy#-}
            err=$(( dx - dy ))

            cx=$prev_x
            cy=$prev_y

            while true; do
                offset=$(( (cy * WIDTH + cx) * BPP ))
                printf "$color" | dd of="$WORK_FB" bs=1 seek=$offset count=2 conv=notrunc 2>/dev/null
                [[ $cx -eq $x ]] && [[ $cy -eq $y ]] && break
                e2=$(( 2 * err ))
                if [[ $e2 -gt -$dy ]]; then
                    err=$(( err - dy ))
                    cx=$(( cx + sx ))
                fi
                if [[ $e2 -lt $dx ]]; then
                    err=$(( err + dx ))
                    cy=$(( cy + sy ))
                fi
            done

            prev_x=$x
            prev_y=$y
        done
    done

    # Atomic update
    cat "$WORK_FB" > "$FB_FILE"
done
