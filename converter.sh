#!/bin/bash

if (( "$#" < 4 )); then
  echo "USAGE: $0 -i <input filename> -o <output filename> [-p quality|time][-d]"
  echo "-i: determines name of the input file."
  echo "-o: determines name of the output file."
  echo "-p: determines priority(quality/time). By default this value specified as middle between these two."
  echo "  quality: video processing might be slower, but quality will be better."
  echo "  time: video processing might be faster, but quality will be worse."
  echo "-d: to see debug info."
  exit
fi

DEBUG=0

while [ -n "$1" ]; do
  case "$1" in
    -p) PRIORITY="$2"
	echo "Found the -p option, with parameter value $PRIORITY";;
    -i) INPUT="$2"
        echo "Found the -i option, with parameter value $INPUT"
        shift ;;
    -o) OUTPUT="$2"
        echo "Found the -o option, with parameter value $OUTPUT"
	shift ;;
    -d) DEBUG=1 ;;
    *) echo "$1 is not an option";;
  esac
  shift
done

# Aspect ratio
a=16
b=9

# Max width/height. If resolution will be greater than these vars, resolution will be scaled.
MAX_WIDTH=1920
MAX_HEIGHT=1080

# Color of side bars. If aspect ratio isn't a:b, bars will be added to video for getting a:b aspect ratio.
# Defaul: "black", You can change it to "red" to view that videos really change resolution.
color="black"

#duration=$(ffprobe -v error -select_streams v:0 -show_entries stream=duration -of compact=p=0:nk=1 $INPUT)
width=$(ffprobe -v error -select_streams v:0 -show_entries stream=width -of default=nk=1:nw=1 $INPUT)
height=$(ffprobe -v error -select_streams v:0 -show_entries stream=height -of default=nk=1:nw=1 $INPUT)
video_bitrate=$(ffprobe -v error -select_streams v:0 -show_entries stream=bit_rate -of default=nk=1:nw=1 $INPUT)
audio_bitrate=$(ffprobe -v error -select_streams a:0 -show_entries stream=bit_rate -of default=nk=1:nw=1 $INPUT)

asp_ratio=$(bc <<< "scale=5;$width/$height")
ENDRATIO=$(bc <<< "scale=5;$a/$b")

echo "Ratio: ${asp_ratio}"
echo "${a}/${b}: ${ENDRATIO}"

params=""
nw=$width
nh=$height

# Converting to a:b aspect ratio. Default: a=16, b=9
if [ $(bc <<< "$asp_ratio < $ENDRATIO") -eq 1 ]; then

  nw=$(/usr/bin/printf "%.0f" $(bc <<< "scale=5;$ENDRATIO*$height"))

  if (( nw % 2 == 1 )); then
    ((nw+=1))
  fi

  temp=$(($nw-$width))

  if ((nw > MAX_WIDTH)) || ((nh > MAX_HEIGHT)); then
    temp=$((temp*MAX_WIDTH/nw))
    nw=$(($MAX_WIDTH-$temp))
    nh=$MAX_HEIGHT
    width=$nw
    if [ $DEBUG -eq 1 ]; then
      echo "SCALING A VERTICAL VIDEO!!!!!!!!!!!!!!!!!!!!!!!! temp: ${temp}"
    fi
  fi
  params="-filter_complex [0:v]scale=$width:$nh,pad=w=$temp+iw:x=$(($temp/2)):color=$color"

elif [ $(bc <<< "$asp_ratio > $ENDRATIO") -eq 1 ]; then

  nh=$(/usr/bin/printf "%.0f" $(bc <<< "scale=5;(1/$ENDRATIO)*$width"))

  if (( nh % 2 == 1 )); then
    ((nh+=1))
  fi

  temp=$(($nh-$height))

  if ((nw > MAX_WIDTH)) || ((nh > MAX_HEIGHT)); then
    temp=$((temp*MAX_WIDTH/nw))
    nw=$MAX_WIDTH
    nh=$(($MAX_HEIGHT-$temp))
    height=$nh
    if [ $DEBUG -eq 1 ]; then
      echo "SCALING A GORIZONTAL VIDEO!!!!!!!!!!!!!!!!!!!!!!!! temp: ${temp}"
    fi
  fi
  params="-filter_complex [0:v]scale=$nw:$height,pad=h=$temp+ih:y=$(($temp/2)):color=$color"

fi

if ((nw > MAX_WIDTH)) || ((nh > MAX_HEIGHT)); then
  nw=$MAX_WIDTH
  nh=$MAX_HEIGHT
  params="-vf scale=$nw:$nh"
  if [ $DEBUG -eq 1 ]; then
    echo "~~~~~~~~~~~~~~~~~~~~~~ASPECT RATIO ALREADY ${a}:${b}~~~~~~~~~~~~~~~~~~~~~~"
  fi
fi

if [[ $PRIORITY == "quality" ]]; then
  preset="veryfast"
elif [[ $PRIORITY == "time" ]]; then
  preset="ultrafast"
else
  preset="superfast"
fi

# The ffmpeg function that converts a videos.
ffmpeg -i $INPUT -preset $preset -tune zerolatency $params -vcodec libx264 $OUTPUT -async 1 -vsync 1
echo "--------------------------"

if [ $DEBUG -eq 1 ]; then
  ffmpeg -i $INPUT -hide_banner
  echo "--------------------------"
  ffmpeg -i $OUTPUT -hide_banner
  echo "--------------------------"
fi

echo "Source info:"
echo ""
echo "Filename: ${INPUT}"
echo "Width: ${width}"
echo "Height: ${height}"
echo "Video bitrate: $((video_bitrate/1024)) kbits/s"
echo "Audio bitrate: $((audio_bitrate/1024)) kbits/s"


echo "--------------------------"

new_width=$(ffprobe -v error -select_streams v:0 -show_entries stream=width -of default=nk=1:nw=1 $OUTPUT)
new_height=$(ffprobe -v error -select_streams v:0 -show_entries stream=height -of default=nk=1:nw=1 $OUTPUT)
new_video_bitrate=$(ffprobe -v error -select_streams v:0 -show_entries stream=bit_rate -of default=nk=1:nw=1 $OUTPUT)
new_audio_bitrate=$(ffprobe -v error -select_streams a:0 -show_entries stream=bit_rate -of default=nk=1:nw=1 $OUTPUT)

echo "Output info:"
echo ""
echo "Filename: ${OUTPUT}"
echo "Width: ${new_width}"
echo "Height: ${new_height}"
echo "Video bitrate: $((new_video_bitrate/1024)) kbits/s"
echo "Audio bitrate: $((new_audio_bitrate/1024)) kbits/s"
echo "Preset: ${preset}"
