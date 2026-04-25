#!/usr/bin/env bash

TMP_DIR="/tmp/qs_media"
mkdir -p "$TMP_DIR"
JSON_OUT="/tmp/qs_media.json"
PLACEHOLDER="$TMP_DIR/placeholder.png"

if [ ! -f "$PLACEHOLDER" ]; then
    convert -size 500x500 xc:"#181825" "$PLACEHOLDER"
fi

# Отримуємо метадані + статус
RAW=$(playerctl -p playerctld metadata --format '{{xesam:title}}|{{xesam:artist}}|{{mpris:artUrl}}|{{status}}|{{mpris:length}}|{{position}}' 2>/dev/null)
# Отримуємо гучність системи (0-100)
VOL=$(wpctl get-volume @DEFAULT_AUDIO_SINK@ 2>/dev/null | awk '/Volume:/{v=$2; printf "%d", int(v*100+0.5)}')

if [ -n "$RAW" ]; then
    IFS="|" read -r TITLE ARTIST ART_URL STATUS LEN_MICRO POS_MICRO <<< "$RAW"

    trackHash=$(echo "${TITLE}${ARTIST}" | md5sum | cut -d" " -f1)
    finalArt="$TMP_DIR/${trackHash}_art.jpg"
    colorFile="$TMP_DIR/${trackHash}_color.txt"

    displayArt="$PLACEHOLDER"
    textColor="#d4ed8a"

    if [ -f "$finalArt" ] && [ -s "$finalArt" ]; then
        displayArt="$finalArt"
        [ -f "$colorFile" ] && textColor=$(cat "$colorFile")
    else
        if [ -n "$ART_URL" ]; then
            if [[ "$ART_URL" == http* ]]; then
                curl -s -L --max-time 5 -o "$finalArt" "$ART_URL"
            else
                cp "${ART_URL#file://}" "$finalArt" 2>/dev/null
            fi
            if [ -f "$finalArt" ]; then
                color=$(convert "$finalArt" -resize 1x1! -format "%[hex:u]" info: | cut -c1-6)
                echo "#$color" > "$colorFile"
            fi
        fi
    fi

    [ -z "$LEN_MICRO" ] || [ "$LEN_MICRO" -eq 0 ] && LEN_MICRO=1
    percent=$(( POS_MICRO * 100 / LEN_MICRO ))

    jq -n -c \
        --arg title "$TITLE" --arg artist "$ARTIST" --arg status "$STATUS" \
        --arg art "$displayArt" --arg percent "$percent" --arg txt "$textColor" \
        --arg vol "${VOL:-0}" \
        '{title: $title, artist: $artist, status: $status, artUrl: $art, percent: $percent, textColor: $txt, volume: $vol, deviceIcon: "󰋋", deviceName: "JBL Live 770NC"}' > "$JSON_OUT"
else
    echo "{\"title\":\"Not Playing\",\"artist\":\"\",\"status\":\"Stopped\",\"percent\":0,\"artUrl\":\"\",\"textColor\":\"#cdd6f4\",\"volume\":\"${VOL:-0}\",\"deviceIcon\":\"󰓃\",\"deviceName\":\"Speaker\"}" > "$JSON_OUT"
fi
