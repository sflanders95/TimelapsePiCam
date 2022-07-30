#!/bin/bash
# #!/bin/bash -x

# REM USES PACKAGE Enfuse
# REM USES PACKAGE ImageMagick

#unused so far DEBUG=1
BATCH=orig
# WAITTIME=300
#CAPTURE_DIR=~/webcam/raspi/capture

# Perform Enfuse grabs (true|(anything but true is false))
DO_ENFUSE=false

CAPTURE_DIR=/mnt/webcam/cache/v01
CACHE2_DIR=/mnt/webcam/cache/v02/
MOVIE_DIR=/mnt/webcam/http/
#MOVIE_DIR=~/public_html/webcam/
DATE=$(date +"%Y%m%d_%H%M%S")
LOGFILE=/mnt/webcam/log/WebCamCron.log
CPUTEMPLOG=/mnt/webcam/http/CpuTempLog.txt
LOCKFILE=/mnt/webcam/log/.lock
LOCKFILE_LOG=/mnt/webcam/log/testPiCamIsUp.log
REBOOTFILE=/mnt/webcam/log/.reboot
RASPIERRCOUNT=0;

function LogTemp() {
  sleep 1
  TEMPC=$(/usr/bin/vcgencmd measure_temp|tr -d 'temp='|tr -d "'C")
  TEMPF=$(echo "scale=1;((9/5) * $TEMPC) + 32" |bc)
  echo -e "`date`\t${TEMPC}\t${TEMPF}" >> $CPUTEMPLOG
  # LogTempToDB
  LogTempToUntyping
}

function LogTempToDB() {
  DB_USER=**********************
  # DB_USER=**********************
  DB_PASSWD=**********************
  DB_NAME=**********************
  TABLE=cpu_temp
  # DB_SERVER=Untyping.org
  DB_SERVER=ferrumpi.local
  
  TEMPC=$(/usr/bin/vcgencmd measure_temp|tr -d 'temp='|tr -d "'C")
  TEMPF=$(echo "scale=2;((9/5) * $TEMPC) + 32" |bc)
  
mysql -h $DB_SERVER --user=$DB_USER --password=$DB_PASSWD $DB_NAME << EOF
INSERT INTO $TABLE (\`server\`, \`tempC\`, \`tempF\`) VALUES ("carbonpi", "$TEMPC", "$TEMPF");
EOF

}

function LogTempToUntyping() {
  HOST=dallas166.arvixeshared.com
  USER=untyping_dbuser
  PW=G1ngerAle
  DB=untyping_general
  TABLE=cpu_temp
  TEMPC=$(/usr/bin/vcgencmd measure_temp|tr -d 'temp='|tr -d "'C")
  if [ "$?" -eq "0" ]
  then
    TEMPF=$(echo "scale=2;((9/5) * $TEMPC) + 32" |bc)

mysql -h $HOST --user=$USER --password=$PW -P 3306 $DB << EOF
INSERT INTO $TABLE (\`server\`, \`tempC\`, \`tempF\`) VALUES ("carbonpi", "$TEMPC", "$TEMPF");
EOF
fi
}

function PutLock()
{
    # Don't allow sudo to reboot.
    touch $LOCKFILE
    echo "`date`	Lockfile On" >> $LOCKFILE_LOG
}

function RemoveLock()
{
    # Allow sudo to reboot.
    rm -f $LOCKFILE
    echo "`date`	Lockfile Off" >> $LOCKFILE_LOG
}

function log() {
  echo "$(date +"%Y%m%d_%H%M%S") $*" >> $LOGFILE
}

function RSync() {
  pushd $MOVIE_DIR
  echo -n rsync $(date +"%m/%d/%y %H:%M:%S") :\  >> $LOGFILE
  rsync -avze ssh --include '*.mp4' --exclude '*' . untyping@untyping.org:public_html/lm/ >> $LOGFILE
  popd
  LogTemp
}

function RSyncImg() {
  pushd $MOVIE_DIR
  echo -n rsync $(date +"%m/%d/%y %H:%M:%S") :\  >> $LOGFILE
  rsync -avze ssh --include 'index.php' --include 'CpuTempLog*' --include 'LakeTempLog*' --include 'm*.jpg' --include 'latest*' --exclude '*' . untyping@untyping.org:public_html/lm/ >> $LOGFILE
  # rsync -avze ssh --include 'mergedlatest.jpg' --exclude '*' . untyping@untyping.org:public_html/lm/
  popd
}

function RaspiErrors() {
   RASPIERRCOUNT=$((RASPIERRCOUNT+1))
    if [ "$RASPIERRCOUNT" -gt "3" ] 
    then
        # signal su cron time to reboot.
        touch $REBOOTFILE
        echo "`date`	Error, setting reboot flag"
    fi
}

# RaspiErrors

function makeDups() {
NUM=$1
log "Making $1 duplicates for $(ls -1 *.jpg|wc -l) files"
ls -1 *.jpg|sort|while read f
do
  # echo $f
  COUNT=0
  while [ "$COUNT" -le "$NUM" ]
  do
    # echo $f ${f//sm/${COUNT}sm}
    cp   $f ${f//sm/${COUNT}sm}
    ((COUNT++))
  done
done
}

function DoEnfuseCapture() {
  # EVALUES='-24 0 -18 -9 6 -6 3'
  EVALUES='0 -9 6 -6 3'
  for EV in $EVALUES
  do
    FNAME=${CACHE2_DIR}${DATE}_ev${EV}.jpg
    log "${FNAME}\t${EV}" 
    if [ "$EV" -eq "0" ]
    then
      # zero is not a valid "-ev" value.
      timeout 60s raspistill -n -o "$FNAME" 2>&1
      if [ "$?" -ne "0" ]
      then
          log "${FNAME}\t${EV}\tReturnCode:\t$?"
          RaspiErrors
      fi
    else
      timeout 60s raspistill -n -ev "$EV" -o "$FNAME" 2>&1
      if [ "$?" -ne "0" ]
      then
          log "${FNAME}\t${EV}\tReturnCode:\t$?"
          RaspiErrors
      fi
    fi
    chmod 644 $FNAME
    cp --force $FNAME ${MOVIE_DIR}m${EV}.jpg

    # sleep for 1/3 of a second.
    /usr/bin/perl -e "select(undef,undef,undef,0.3);"
  done

  BRIGHT=$(identify -verbose ${CACHE2_DIR}${DATE}_ev6.jpg|grep ight|awk '{print $2}'|sed 's/\/100//g')
  FNAME=${CACHE2_DIR}${DATE}_enfuse.jpg
  enfuse -o ${FNAME} $(ls -1 ${CACHE2_DIR}${DATE}_ev*.jpg) 2>&1 >/dev/null
  

  #if [ "$BRIGHT" -lt "8" ]
  #then
    #raspistill -n -ISO 800 -ss 3000000 -br 80 -co 100 -o "${CACHE2_DIR}${DATE}_ev99.jpg" 2>&1
    #enfuse -o ${FNAME} "${CACHE2_DIR}${DATE}_ev99.jpg" "${CACHE2_DIR}${DATE}_ev6.jpg" 2>&1 >/dev/null
  #else
  #  enfuse -o ${FNAME} $(ls -1 ${CACHE2_DIR}${DATE}_ev*.jpg) 2>&1 >/dev/null
  #  if [ "$?" -eq "0" ] ; then log Enfused ; else log "Error Enfusing  $FNAME" ;  fi;
  #fi
  cp --force $FNAME ${MOVIE_DIR}mergedlatest.jpg
  chmod 644 ${MOVIE_DIR}mergedlatest.jpg
  chmod 644 $FNAME
  
  # Next resize for movie making
  convert $FNAME -resize 720x486^ -gravity center -extent 720x468 ${FNAME//enfuse/sm}

  AddDateTimeToImage ${FNAME//enfuse/sm}
  AddDateTimeToImage ${MOVIE_DIR}mergedlatest.jpg 1

  #rm ${CACHE2_DIR}${DATE}_ev3.jpg
  #rm ${CACHE2_DIR}${DATE}_ev6.jpg
  #rm ${CACHE2_DIR}${DATE}_ev-18.jpg
  #rm ${CACHE2_DIR}${DATE}_ev-6.jpg
  rm ${CACHE2_DIR}${DATE}_e*.jpg
  #rm ${CACHE2_DIR}${DATE}_enfuse.jpg
}

### https://www.raspberrypi.com/documentation/accessories/camera.html
# Main capture block.
function captureImage() {
  IMG=${CAPTURE_DIR}/${DATE}${BATCH}.jpg

  # Lowlight fix, DEC=high crashes sometimes in low light.
  H=$(date +"%H")
  RISEHOUR=6
  SETHOUR=20
  DRC=high
  #if [ $H -lt $RISEHOUR ] || [ $H -gt $SETHOUR ]; then DRC=medium; fi 

  # /usr/bin/raspistill -ex auto -n -o ${IMG}
  #nice timeout 60s nice /usr/bin/raspistill -ex night -drc high -n -o ${IMG}
  nice timeout 60s nice /usr/bin/libcamera-jpeg -n -o ${IMG}
  sleep 5

  if [ "$?" -eq "0" ]
  then 
    cp --force $IMG ${MOVIE_DIR}latest.jpg
    convert $IMG -resize 1^x630 ${MOVIE_DIR}latest_seo.jpg
    chmod 644 ${MOVIE_DIR}latest.jpg
    chmod 644 ${MOVIE_DIR}latest_seo.jpg
    convert $IMG -resize 720x486^ -gravity center -extent 720x468 ${IMG//$BATCH/sm}
    if [ "$?" -eq "0" ] ; then rm $IMG ; else log "Error converting/resizing $IMG" ;  fi;
    AddDateTimeToImage ${IMG//$BATCH/sm}
    AddDateTimeToImage ${MOVIE_DIR}latest.jpg 1
  else
    RaspiErrors
    log "Error: CaptureImage() creating image from raspistill" 
  fi
  if [ $"$DO_ENFUSE" = "true" ]
  then
    DoEnfuseCapture
  fi
}


# Usage: AddDateTimeToImage "FileName"
# If larger size font, add a second parameter of 1
# e.g.: AddDateTimeToImage ${MOVIE_DIR}latest.jpg 1
# todo: change second param to desired fontsize
function AddDateTimeToImage()
{
  IFILE=$1
  PARAM2=$2
  if [ -f $IFILE ]
  then
    FONTSIZE=16
    if [ "$PARAM2" = "1" ]
    then
      FONTSIZE=46
    fi
    TXT=`date`
    TMPF=$IFILE.$$
    rm -f $TMPF
    convert -font helvetica -fill darkgray -pointsize $FONTSIZE -gravity southEast -draw "text 11,21 '$TXT'" $IFILE $TMPF
    convert -font helvetica -fill white -pointsize $FONTSIZE -gravity southEast -draw "text 10,20 '$TXT'" $TMPF $IFILE
    rm -f $TMPF
  fi
}


function makeMovie() {
  LogTemp
  PutLock
  rm -f ${CAPTURE_DIR}/*orig.jpg
  DATE=$(date +"%Y%m%d")
  makeMovieSub $CAPTURE_DIR ${MOVIE_DIR}/${DATE}_timelapse.mp4 $DATE
  if [ $"$DO_ENFUSE" = "true" ]
  then
    makeMovieSub $CACHE2_DIR ${MOVIE_DIR}/${DATE}_timelapse_v2.mp4 $DATE
  fi
  RemoveLock
  LogTemp
}

# $1 is the source image dir
# $2 is the output movie filename
# $3 is the input file prefix (%Y%m%d)
function makeMovieSub() {
  #pushd $CAPTURE_DIR
  #pushd $CACHE2_DIR
  pushd $1
  pwd
  MOVIE=$2
  PREFIX=$3

  makeDups 1

  DATE=$(date +"%Y%m%d")
  #MOVIE=${MOVIE_DIR}/${DATE}_timelapse.mp4
  #MOVIE=${MOVIE_DIR}/${DATE}_timelapse_v2.mp4
  # old # ffmpeg -y -f image2 -pattern_type glob -i ${DATE}_\*sm.jpg -r 12 -vcodec libx264 -profile:h -preset:slow $MOVIE
  #ffmpeg -y -f image2 -pattern_type glob -i ${DATE}_\*sm.jpg -r 12 -vcodec libx264 $MOVIE
  ffmpeg -y -f image2 -pattern_type glob -i ${PREFIX}_\*sm.jpg -r 12 -vcodec libx264 $MOVIE
  if [ "$?" -eq "0" ]
  then 
    log "$MOVIE was sucessfully Created"
    log "$(file $MOVIE)"
    log "$(ls -l $MOVIE)"
    rm ${PREFIX}_*sm.jpg
  else
    log "Error Creating $MOVIE"
  fi
  popd -n
}

function InstallCron() {
  CRON="/bin/bash $(pwd)/${0}"
  # uninstall
  crontab -l | grep -v $0 | crontab
  # install
  # */3 4-20 Summer, */2 5-19 Aug
  # crontab -l | { cat; echo "*/3 4-22 * * * $CRON capture"; }   | crontab -
  crontab -l | { cat; echo "*/3 5-21 * * *   $CRON capture"; }   | crontab -
  crontab -l | { cat; echo "5 22 * * *       $CRON makemovie"; } | crontab -
  crontab -l | { cat; echo "*/17 * * * *     $CRON rsync"; }     | crontab -
  crontab -l | { cat; echo "*/17 * * * *     $CRON rsyncimg"; }  | crontab -
  crontab -l | { cat; echo "*/15 22-23 * * * $CRON taketemp"; }  | crontab -
  crontab -l | { cat; echo "*/15 0-2 * * *   $CRON taketemp"; }  | crontab -
  crontab -l 
}


function Usage() {
  echo "Usage:"
  echo "  ./$0 capture  - to take a picture"
  echo "  ./$0 makemovie  - to compile all pictures into mp4"
  echo "  ./$0 rsync  - upload files to untyping.org/lm"
  echo "  ./$0 taketemp - record CPU temperature"
  echo "  ./$0 install  - to (re)install the cron job"
  echo
  echo "Current Settings:"
  echo "  BATCH=${BATCH}  - filename suffix (before .jpg)"
  echo "  CAPTURE_DIR=${CAPTURE_DIR}  - temp storage for jpg files"
  echo "  MOVIE_DIR=${MOVIE_DIR}  - destination for mp4 file"
  echo "  DATE=$(date +"%Y%m%d_%H%M%S") - jpg filename prefix"
  echo "  LOGFILE=${LOGFILE} - The output from this file"
}


# MAIN

if   [ "$1" == "capture" ]   ; then captureImage
elif [ "$1" == "makemovie" ] ; then makeMovie
elif [ "$1" == "install" ]   ; then InstallCron
elif [ "$1" == "rsync" ]   ; then RSync
elif [ "$1" == "rsyncimg" ]   ; then RSyncImg
elif [ "$1" == "taketemp" ]   ; then LogTemp
else
   Usage 
fi


# 
# Commands:
# 
# raspistill -o image.jpg
# raspivid -o video.h264 -t 10000
# 
# 
# ffmpeg -f image2 -pattern_type glob -framerate 12 -i 'foo-*.jpeg' -s WxH foo.avi
# 
# ffmpeg
#   -y         Overwrite destination
#   -f image2  at beginning, imput type (redundant?)
#   -pattern_type glob -i 'capture/20190619_*.jpg'
#   -r 24
#   -vcodec libx264
#   -profile high
#   -preset slow
# 
# 
# ffmpeg -y -f image2 -pattern_type glob -i 'capture/20190619_*.jpg' -r 24 -vcodec libx264 -profile high -preset slow timelapse.mp4
# 
# convert 20190619_200912first.jpg -resize 720x486^ -gravity center -extent 720x468 20190619_200912a.jpg
# 
# ls -1 *.jpg|sort|while read f ; do echo convert $f -resize 720x486^ -gravity center -extent 720x486 ${f//first/a} >> go
