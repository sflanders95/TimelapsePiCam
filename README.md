# TimelapsePiCam
A Web Cam cron job that takes a picture every few minutes and then at night compiles them into a timelapse video.  It takes a picture via raspistill every few minutes and stores them into a cache directory. at the end of the night, it compiles (via ffmpeg) the images into a video. imagemagick is used to place a timestamp at the bottom of the images. End of night, the cache dir is cleaned. 

## libraries

This uses ffmpeg, imagemagik, raspistill, and bash



