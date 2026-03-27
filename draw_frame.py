import sys
import os

def main():
    if len(sys.argv) < 3:
        sys.exit(1)

    fb_path = sys.argv[1]
    csv_line = sys.argv[2]

    width = 800
    height = 600
    graph_x = 50
    graph_y = 50
    graph_w = 700
    graph_h = 500
    bpp = 2

    color_line = b'\x00\xF8'
    color_grid = b'\x08\x42'
    color_black = b'\x00\x00'

    try:
        values = [float(v) for v in csv_line.strip().split(',')]
    except ValueError:
        sys.exit(0)

    with open(fb_path, "r+b") as f:
        # Clear graph area (using seek for each line for speed)
        black_line = color_black * graph_w
        for y in range(graph_y, graph_y + graph_h):
            f.seek((y * width + graph_x) * bpp)
            f.write(black_line)

        # Draw grid
        grid_line = color_grid * graph_w
        f.seek((graph_y * width + graph_x) * bpp)
        f.write(grid_line)
        f.seek(((graph_y + graph_h - 1) * width + graph_x) * bpp)
        f.write(grid_line)

        for y in range(graph_y, graph_y + graph_h):
            f.seek((y * width + graph_x) * bpp)
            f.write(color_grid)
            f.seek((y * width + graph_x + graph_w - 1) * bpp)
            f.write(color_grid)

        # Draw points and connecting lines
        num_vals = len(values)
        if num_vals < 2:
            return

        prev_x = graph_x
        val = values[0]
        prev_y = graph_y + graph_h - int(val * graph_h / 100)

        for i in range(1, num_vals):
            x = graph_x + int(i * graph_w / (num_vals - 1))
            val = values[i]
            y = graph_y + graph_h - int(val * graph_h / 100)

            # Draw line between (prev_x, prev_y) and (x, y)
            dx = abs(x - prev_x)
            dy = abs(y - prev_y)
            sx = 1 if prev_x < x else -1
            sy = 1 if prev_y < y else -1
            err = dx - dy

            curr_x, curr_y = prev_x, prev_y
            while True:
                if 0 <= curr_x < width and 0 <= curr_y < height:
                    f.seek((curr_y * width + curr_x) * bpp)
                    f.write(color_line)
                if curr_x == x and curr_y == y:
                    break
                e2 = 2 * err
                if e2 > -dy:
                    err -= dy
                    curr_x += sx
                if e2 < dx:
                    err += dx
                    curr_y += sy

            prev_x, prev_y = x, y

if __name__ == "__main__":
    main()
