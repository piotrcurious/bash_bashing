#!/usr/bin/env python3
import sys
import time
import math
import random

def main():
    if len(sys.argv) < 2:
        print("Usage: generator.py <serial_port>")
        sys.exit(1)

    port_path = sys.argv[1]

    # We want to send a line of CSV values periodically.
    # To simulate a plotter, let's say we send 100 values at a time.

    num_points = 100
    phase = 0.0

    with open(port_path, "w", buffering=1) as f:
        while True:
            values = []
            for i in range(num_points):
                # Sine wave with some noise
                val = 50 + 30 * math.sin(phase + i * 0.1) + random.uniform(-2, 2)
                values.append(f"{val:.2f}")

            f.write(",".join(values) + "\n")
            f.flush()

            phase += 0.5
            time.sleep(1.0) # Send a new graph every second

if __name__ == "__main__":
    main()
