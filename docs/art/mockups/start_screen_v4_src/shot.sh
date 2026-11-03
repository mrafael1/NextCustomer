#!/bin/sh
# shot.sh <out.png> <query>  : renders start_screen_v4.html at 1920x1080 into start_screen_v4_build/
cd /c/dev/projects/NextCustomer/docs/art/mockups
timeout 60 "/c/Program Files/Google/Chrome/Application/chrome.exe" --headless=new --disable-gpu --allow-file-access-from-files --hide-scrollbars --window-size=1920,1080 --virtual-time-budget=6000 --screenshot="C:/dev/projects/NextCustomer/docs/art/mockups/start_screen_v4_build/$1" "file:///C:/dev/projects/NextCustomer/docs/art/mockups/start_screen_v4.html?solo=1&page=2&$2" 2>/dev/null >/dev/null
