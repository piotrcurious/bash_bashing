#!/usr/bin/env python3
import sys
import os
import time

def main():
    if len(sys.argv) < 3:
        print("Usage: plotter.py <serial_port> <fb_file> [width] [height]")
        sys.exit(1)

    port_path = sys.argv[1]
    fb_path = sys.argv[2]
    width = int(sys.argv[3]) if len(sys.argv) > 3 else 800
    height = int(sys.argv[4]) if len(sys.argv) > 4 else 600

    # Constants
    BPP = 2
    COLOR_WHITE = 0xFFFF
    COLOR_BLACK = 0x0000
    COLOR_GRID = 0x4208 # Dark grey
    COLOR_LINE = 0x07E0 # Green

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
        # Fill graph area with black
        black_line = (COLOR_BLACK.to_bytes(2, 'little')) * graph_w
        for y in range(graph_y, graph_y + graph_h):
            f.seek((y * width + graph_x) * BPP)
            f.write(black_line)

        # Draw border
        draw_line(f, graph_x, graph_y, graph_x + graph_w, graph_y, COLOR_GRID)
        draw_line(f, graph_x + graph_w, graph_y, graph_x + graph_w, graph_y + graph_h, COLOR_GRID)
        draw_line(f, graph_x + graph_w, graph_y + graph_h, graph_x, graph_y + graph_h, COLOR_GRID)
        draw_line(f, graph_x, graph_y + graph_h, graph_x, graph_y, COLOR_GRID)

    with open(fb_path, "r+b") as fb, open(port_path, "r") as port:
        # Initial clear
        fb.write((COLOR_BLACK.to_bytes(2, 'little')) * (width * height))
        clear_graph(fb)
        fb.flush()

        prev_points = None

        while True:
            line = port.readline()
            if not line:
                time.sleep(0.01)
                continue

            try:
                values = [float(v) for v in line.strip().split(',')]
            except ValueError:
                continue

            # For simplicity, we'll redraw the graph each time a full set of points comes in
            # or shift it. Let's try shifting for better "plotter" feel.
            # But the request was for CSV serial plotter.

            # If CSV contains multiple values, we can plot them as a series.
            # If it's a stream of single values, we shift.

            # Let's assume we get one line of multiple values representing the whole visible graph
            clear_graph(fb)

            num_vals = len(values)
            if num_vals < 2:
                continue

            for i in range(num_vals - 1):
                x1 = graph_x + int(i * graph_w / (num_vals - 1))
                x2 = graph_x + int((i+1) * graph_w / (num_vals - 1))

                v1 = values[i]
                v2 = values[i+1]

                # Scale values
                y1 = graph_y + graph_h - int((v1 - min_val) * graph_h / (max_val - min_val))
                y2 = graph_y + graph_h - int((v2 - min_val) * graph_h / (max_val - min_val))

                # Clip
                y1 = max(graph_y, min(graph_y + graph_h, y1))
                y2 = max(graph_y, min(graph_y + graph_h, y2))

                draw_line(fb, x1, y1, x2, y2, COLOR_LINE)

            fb.flush()

if __name__ == "__main__":
    main()
