#!/usr/bin/env python3
import sys
import os
import time

def main():
    if len(sys.argv) < 3:
        print("Usage: plotter_multi.py <serial_port> <fb_file> [width] [height]")
        sys.exit(1)

    port_path = sys.argv[1]
    fb_path = sys.argv[2]
    width = int(sys.argv[3]) if len(sys.argv) > 3 else 800
    height = int(sys.argv[4]) if len(sys.argv) > 4 else 600

    # Constants
    BPP = 2
    COLOR_BLACK = 0x0000
    COLOR_GRID = 0x4208
    # Multiple colors for multiple channels
    COLORS = [0x07E0, 0xF800, 0x001F, 0xFFE0, 0x07FF, 0xF81F] # Green, Red, Blue, Yellow, Cyan, Magenta

    graph_x = 50
    graph_y = 50
    graph_w = width - 100
    graph_h = height - 100

    max_val = 100.0
    min_val = 0.0

    def set_pixel(f, x, y, color):
        if 0 <= x < width and 0 <= y < height:
            offset = (y * width + x) * BPP
            f.seek(offset)
            f.write(color.to_bytes(2, byteorder='little'))

    def draw_line(f, x1, y1, x2, y2, color):
        dx = abs(x2 - x1)
        dy = abs(y2 - y1)
        sx = 1 if x1 < x2 else -1
        sy = 1 if y1 < y2 else -1
        err = dx - dy
        while True:
            set_pixel(f, x1, y1, color)
            if x1 == x2 and y1 == y2:
                break
            e2 = 2 * err
            if e2 > -dy:
                err -= dy
                x1 += sx
            if e2 < dx:
                err += dx
                y1 += sy

    def clear_graph(f):
        black_line = (COLOR_BLACK.to_bytes(2, 'little')) * graph_w
        for y in range(graph_y, graph_y + graph_h):
            f.seek((y * width + graph_x) * BPP)
            f.write(black_line)

        draw_line(f, graph_x, graph_y, graph_x + graph_w, graph_y, COLOR_GRID)
        draw_line(f, graph_x + graph_w, graph_y, graph_x + graph_w, graph_y + graph_h, COLOR_GRID)
        draw_line(f, graph_x + graph_w, graph_y + graph_h, graph_x, graph_y + graph_h, COLOR_GRID)
        draw_line(f, graph_x, graph_y + graph_h, graph_x, graph_y, COLOR_GRID)

    # We'll keep a history of points for scrolling effect
    history = []
    max_history = 100

    with open(fb_path, "r+b") as fb, open(port_path, "r") as port:
        fb.write((COLOR_BLACK.to_bytes(2, 'little')) * (width * height))

        while True:
            line = port.readline()
            if not line:
                time.sleep(0.01)
                continue

            try:
                # Expecting CSV: val1,val2,val3... (one set of values per point in time)
                current_values = [float(v) for v in line.strip().split(',')]
            except ValueError:
                continue

            history.append(current_values)
            if len(history) > max_history:
                history.pop(0)

            clear_graph(fb)

            num_channels = len(current_values)
            num_points = len(history)

            if num_points < 2:
                continue

            for ch in range(num_channels):
                color = COLORS[ch % len(COLORS)]
                for i in range(num_points - 1):
                    x1 = graph_x + int(i * graph_w / (max_history - 1))
                    x2 = graph_x + int((i+1) * graph_w / (max_history - 1))

                    v1 = history[i][ch]
                    v2 = history[i+1][ch]

                    y1 = graph_y + graph_h - int((v1 - min_val) * graph_h / (max_val - min_val))
                    y2 = graph_y + graph_h - int((v2 - min_val) * graph_h / (max_val - min_val))

                    y1 = max(graph_y, min(graph_y + graph_h, y1))
                    y2 = max(graph_y, min(graph_y + graph_h, y2))

                    draw_line(fb, x1, y1, x2, y2, color)

            fb.flush()

if __name__ == "__main__":
    main()
