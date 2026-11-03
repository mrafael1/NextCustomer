#!/bin/sh
# usage: shot.sh <canvas id> <it> [extra query]
out="C:/dev/projects/NextCustomer/docs/art/mockups/card_rarity_B_build/$1_it$2$3.png"
q=$(echo "$3" | sed 's/^_/\&/')
timeout 60 "/c/Program Files/Google/Chrome/Application/chrome.exe" --headless=new --disable-gpu --allow-file-access-from-files --hide-scrollbars --window-size=1920,1080 --virtual-time-budget=6000 --screenshot="$out" "file:///C:/dev/projects/NextCustomer/docs/art/mockups/card_rarity_B.html?only=$1&it=$2$q" 2>/dev/null
echo "$out"
