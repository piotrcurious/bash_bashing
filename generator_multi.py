#!/usr/bin/env python3
import sys
import time
import math
import random

def main():
    if len(sys.argv) < 2:
        print("Usage: generator_multi.py <serial_port>")
        sys.exit(1)

    port_path = sys.argv[1]
    phase = 0.0

    with open(port_path, "w", buffering=1) as f:
        while True:
            # Generate 3 channels of data
            v1 = 50 + 40 * math.sin(phase) + random.uniform(-1, 1)
            v2 = 50 + 30 * math.cos(phase * 0.7) + random.uniform(-1, 1)
            v3 = 30 + 10 * math.sin(phase * 2.1) + random.uniform(-1, 1)

            f.write(f"{v1:.2f},{v2:.2f},{v3:.2f}\n")
            f.flush()

            phase += 0.1
            time.sleep(0.1) # Send at 10Hz

if __name__ == "__main__":
    main()
