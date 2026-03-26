#!/bin/bash

# Configuration
FB_FILE=${1:-/tmp/xvfb_fb/Xvfb_screen0}

# System call numbers for x86_64
SYS_OPEN=2
SYS_IOCTL=16
SYS_CLOSE=3

# Flags
O_RDWR=2
FBIOGET_VSCREENINFO=0x4600

# Use python to perform the ioctl and print info, because strace is too indirect
# but the user asked for syscall based.
# Let's try to use perl for a true syscall demo as suggested in bash_strace.md

perl -e '
    require "syscall.ph";
    $fb_file = shift;
    sysopen(FB, $fb_file, 2) or die "Cannot open $fb_file: $!";
    $vscreeninfo_t = "L" x 40; # Approximate size of fb_var_screeninfo
    $data = "\0" x 160;
    $res = syscall(SYS_ioctl(), fileno(FB), 0x4600, $data);
    if ($res == 0) {
        @info = unpack("L10", $data);
        printf("Resolution: %dx%d, %dbpp\n", $info[0], $info[1], $info[6]);
    } else {
        print "ioctl failed: $!\n";
    }
    close(FB);
' "$FB_FILE"
