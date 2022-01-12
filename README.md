# TimelapsePiCam
A Web Cam cron job that takes a picture every few minutes and then at night compiles them into a timelapse video.  It takes a picture via raspistill every few minutes and stores them into a cache directory. at the end of the night, it compiles (via ffmpeg) the images into a video. imagemagick is used to place a timestamp at the bottom of the images. End of night, the cache dir is cleaned. 

## libraries

This uses ffmpeg, imagemagik, raspistill, and bash

## OS

This is running on my RaspberryPi 4. uname -a is:

`Linux carbonpi 5.10.63-v7l+ #1496 SMP Wed Dec 1 15:58:56 GMT 2021 armv7l GNU/Linux`



