#!/bin/bash

# Configuration
FB_FILE=${1:-/tmp/xvfb_fb/Xvfb_screen0}
WIDTH=800
HEIGHT=600
BPP=2 # 16-bit
STRIDE=$((WIDTH * BPP))

# Draw a red rectangle (800x600) using dd from /dev/zero and tr to fill with a specific color.
# Red in RGB565 is 0xF800 (high: 0xF8, low: 0x00)
# Use dd and tr to fill the screen with red
# tr is tricky with non-ascii. Better use python for complex drawing.
python3 -c "import os; data = (b'\x00\xF8') * (800 * 600); f = open('$FB_FILE', 'r+b'); f.write(data); f.close()"
