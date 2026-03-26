#!/bin/bash

# Configuration
SERIAL_PORT=${1:-/tmp/ttyS1}
FB_FILE=${2:-/tmp/xvfb_fb/Xvfb_screen0}

echo "Bash plotter (optimized with perl) started. Reading from $SERIAL_PORT..."

# Use perl for the inner loop to handle binary framebuffer writes efficiently
# while remaining a script-based solution.
perl -e '
    use strict;
    my $fb_file = shift;
    my $width = 800;
    my $height = 600;
    my $graph_x = 50;
    my $graph_y = 50;
    my $graph_w = 700;
    my $graph_h = 500;
    my $bpp = 2;

    my $color_line = pack("S", 0xF800); # Red in RGB565
    my $color_grid = pack("S", 0x4208); # Dark Grey
    my $color_black = pack("S", 0x0000);

    open(my $fb, "+<", $fb_file) or die "Cannot open $fb_file: $!";
    binmode($fb);

    while (my $line = <STDIN>) {
        chomp $line;
        next if $line eq "";
        my @values = split(",", $line);
        next if @values < 2;

        # Clear graph area
        my $black_line = $color_black x $graph_w;
        for (my $y = $graph_y; $y < $graph_y + $graph_h; $y++) {
            seek($fb, ($y * $width + $graph_x) * $bpp, 0);
            print $fb $black_line;
        }

        # Draw grid
        my $grid_line = $color_grid x $graph_w;
        seek($fb, ($graph_y * $width + $graph_x) * $bpp, 0);
        print $fb $grid_line;
        seek($fb, (($graph_y + $graph_h - 1) * $width + $graph_x) * $bpp, 0);
        print $fb $grid_line;
        for (my $y = $graph_y; $y < $graph_y + $graph_h; $y++) {
            seek($fb, ($y * $width + $graph_x) * $bpp, 0);
            print $fb $color_grid;
            seek($fb, ($y * $width + $graph_x + $graph_w - 1) * $bpp, 0);
            print $fb $color_grid;
        }

        # Draw plot
        my $prev_x = $graph_x;
        my $v0 = $values[0];
        my $prev_y = $graph_y + $graph_h - int($v0 * $graph_h / 100);

        for (my $i = 1; $i < @values; $i++) {
            my $x = $graph_x + int($i * $graph_w / (@values - 1));
            my $v = $values[$i];
            my $y = $graph_y + $graph_h - int($v * $graph_h / 100);

            # Simple line drawing (Bresenham)
            my $dx = abs($x - $prev_x);
            my $dy = abs($y - $prev_y);
            my $sx = $prev_x < $x ? 1 : -1;
            my $sy = $prev_y < $y ? 1 : -1;
            my $err = $dx - $dy;

            my ($cx, $cy) = ($prev_x, $prev_y);
            while (1) {
                seek($fb, ($cy * $width + $cx) * $bpp, 0);
                print $fb $color_line;
                last if ($cx == $x && $cy == $y);
                my $e2 = 2 * $err;
                if ($e2 > -$dy) { $err -= $dy; $cx += $sx; }
                if ($e2 < $dx) { $err += $dx; $cy += $sy; }
            }
            ($prev_x, $prev_y) = ($x, $y);
        }
        # Flush to ensure frame is drawn
        $fb->flush();
    }
' "$FB_FILE" < "$SERIAL_PORT"
