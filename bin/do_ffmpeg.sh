#!/bin/sh

echo "Starting avconv..."
avconv -s $VIDEO_STREAM_WIDTHx$VIDEO_STREAM_HEIGHT -r 9 -f video4linux2 -i /dev/video0 -f mpeg1video -r 24 http://0.0.0.0:$STREAM_PORT
