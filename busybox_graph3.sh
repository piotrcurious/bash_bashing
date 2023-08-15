#!/bin/busybox sh

# Define some variables
SERIAL_PORT=/dev/ttyS0 # Change this to your serial port device
FRAMEBUFFER=/dev/fb0 # Change this to your framebuffer device
SCREEN_WIDTH=800 # Change this to your screen width in pixels
SCREEN_HEIGHT=600 # Change this to your screen height in pixels
SCREEN_BPP=16 # Change this to your screen bits per pixel
SCREEN_SIZE=$((SCREEN_WIDTH * SCREEN_HEIGHT * SCREEN_BPP / 8)) # Calculate the screen size in bytes
GRAPH_HEIGHT=400 # Change this to the height of the graph in pixels
GRAPH_WIDTH=$((SCREEN_WIDTH - 20)) # Calculate the width of the graph in pixels
GRAPH_X=10 # The x coordinate of the graph origin
GRAPH_Y=$((SCREEN_HEIGHT - GRAPH_HEIGHT - 10)) # The y coordinate of the graph origin
MAX_VALUE=100 # The maximum value of the sensor data
MIN_VALUE=0 # The minimum value of the sensor data
COLOR=0xF800 # The color of the graph line in RGB565 format

# Define some functions
# A function to draw a pixel on the framebuffer
# Usage: draw_pixel x y color
draw_pixel() {
  local x=$1
  local y=$2
  local color=$3
  local offset=$((y * SCREEN_WIDTH + x)) # Calculate the offset of the pixel in the framebuffer
  busybox dd if=/dev/zero bs=1 count=2 2>/dev/null | busybox awk -v c=$color 'BEGIN {printf "%c%c", and(rshift(c, 8), 255), and(c, 255)}' | busybox dd of=$FRAMEBUFFER bs=1 seek=$((offset * 2)) count=2 conv=notrunc 2>/dev/null # Write the color bytes to the framebuffer at the offset position
}

# A function to draw a line on the framebuffer using Bresenham's algorithm
# Usage: draw_line x1 y1 x2 y2 color
draw_line() {
  local x1=$1
  local y1=$2
  local x2=$3
  local y2=$4
  local color=$5
  local dx=$((x2 - x1))
  local dy=$((y2 - y1))
  local sx=$((dx > 0 ? 1 : -1))
  local sy=$((dy > 0 ? 1 : -1))
  dx=${dx#-} # Absolute value of dx
  dy=${dy#-} # Absolute value of dy
  local err=$((dx - dy))
  local e2
  while true; do
    draw_pixel $x1 $y1 $color # Draw a pixel at (x1, y1)
    [ $x1 -eq $x2 ] && [ $y1 -eq $y2 ] && break # If we reached the end point, break the loop
    e2=$((err * 2))
    if [ $e2 -gt -$dy ]; then # If e2 > -dy, increment x and decrement error 
      err=$(($err - $dy))
      x1=$(($x1 + $sx))
    fi
    if [ $e2 -lt $dx ]; then # If e2 < dx, increment y and increment error 
      err=$(($err + $dx))
      y1=$(($y1 + $sy))
    fi  
  done  
}

# A function to draw a rectangle on the framebuffer
# Usage: draw_rect x y w h color
draw_rect() {
  local x=$1
  local y=$2
  local w=$3
  local h=$4
  local color=$5
  draw_line $x $y $(($x + $w)) $y $color # Draw the top line of the rectangle 
  draw_line $(($x + $w)) $y $(($x + $w)) $(($y + $h)) $color # Draw the right line of the rectangle 
  draw_line $(($x + $w)) $(($y + $h)) $x $(($y + $h)) $color # Draw the bottom line of the rectangle 
  draw_line $x $(($y + $h)) $x $y $color # Draw the left line of the rectangle 
}

# A function to draw a graph on the framebuffer
# Usage: draw_graph data
draw_graph() {
  local data=$1 # The data is a comma-separated list of values
  local oldIFS=$IFS # Save the old IFS
  IFS=, # Set the IFS to comma
  local values=($data) # Split the data into an array of values
  IFS=$oldIFS # Restore the old IFS
  local n=${#values[@]} # Get the number of values
  local x=$GRAPH_X # The initial x coordinate of the graph line
  local y # The y coordinate of the graph line
  local prev_x=$x # The previous x coordinate of the graph line
  local prev_y=$((GRAPH_Y + GRAPH_HEIGHT / 2)) # The previous y coordinate of the graph line
  local value # The current value
  local scale=$((GRAPH_HEIGHT / (MAX_VALUE - MIN_VALUE))) # The scale factor to map the value to the graph height
  for value in ${values[@]}; do # Loop through the values
    y=$((GRAPH_Y + GRAPH_HEIGHT - (value - MIN_VALUE) * scale)) # Calculate the y coordinate based on the value and the scale factor
    draw_line $prev_x $prev_y $x $y $COLOR # Draw a line from the previous point to the current point
    prev_x=$x # Update the previous x coordinate
    prev_y=$y # Update the previous y coordinate
    x=$(($x + GRAPH_WIDTH / n)) # Increment the x coordinate by the width divided by the number of values
  done  
}

# A function to clear the framebuffer with black color
# Usage: clear_screen
clear_screen() {
  busybox dd if=/dev/zero bs=$SCREEN_SIZE count=1 2>/dev/null | busybox dd of=$FRAMEBUFFER bs=$SCREEN_SIZE count=1 conv=notrunc 2>/dev/null # Write zeros to the framebuffer with the screen size
}

# A function to shift the framebuffer to the left by one pixel
# Usage: shift_screen
shift_screen() {
  busybox dd if=$FRAMEBUFFER bs=1 skip=2 count=$((SCREEN_SIZE - 2)) 2>/dev/null | busybox dd of=$FRAMEBUFFER bs=1 seek=0 count=$((SCREEN_SIZE - 2)) conv=notrunc 2>/dev/null # Copy the framebuffer content from offset 2 to offset 0 with the size minus 2 bytes 
}

# A function to read a line from the serial port
# Usage: read_line
read_line() {
  busybox awk 'BEGIN {RS="\r\n"; ORS=""; getline; print}' < $SERIAL_PORT # Use awk to read a line from the serial port and print it without newline 
}

# Main program

# Clear the screen
clear_screen

# Draw a rectangle around the graph area
draw_rect $GRAPH_X $GRAPH_Y $GRAPH_WIDTH $GRAPH_HEIGHT 0xFFFF

# Loop forever
while true; do
  # Shift the screen to the left by one pixel
  shift_screen

  # Read a line from the serial port
  DATA=$(read_line)

  # Draw a graph with the data
  draw_graph $DATA

done
