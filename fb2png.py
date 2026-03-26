import sys
from PIL import Image

def convert_fb16_to_png(fb_path, output_path, width, height):
    with open(fb_path, "rb") as f:
        # Xvfb with 16bpp often uses RGB 565
        # The file size should be width * height * 2
        data = f.read(width * height * 2)

    img = Image.new("RGB", (width, height))
    pixels = img.load()

    for y in range(height):
        for x in range(width):
            offset = (y * width + x) * 2
            # Little endian RGB565
            low = data[offset]
            high = data[offset+1]
            val = (high << 8) | low

            r = (val >> 11) & 0x1F
            g = (val >> 5) & 0x3F
            b = val & 0x1F

            # Scale to 8-bit
            pixels[x, y] = (int(r * 255 / 31), int(g * 255 / 63), int(b * 255 / 31))

    img.save(output_path)

if __name__ == "__main__":
    if len(sys.argv) < 3:
        print("Usage: fb2png.py <fb_file> <output.png> [width] [height]")
        sys.exit(1)

    fb_file = sys.argv[1]
    out_file = sys.argv[2]
    width = int(sys.argv[3]) if len(sys.argv) > 3 else 800
    height = int(sys.argv[4]) if len(sys.argv) > 4 else 600

    convert_fb16_to_png(fb_file, out_file, width, height)
