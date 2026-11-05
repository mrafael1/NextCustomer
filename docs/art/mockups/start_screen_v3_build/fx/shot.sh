# usage: shot.sh <out-name> <query>
B=/c/dev/projects/NextCustomer/docs/art/mockups
timeout 60 "/c/Program Files/Google/Chrome/Application/chrome.exe" --headless=new --disable-gpu --allow-file-access-from-files --hide-scrollbars --window-size=1920,1080 --virtual-time-budget=6000 --screenshot="C:/dev/projects/NextCustomer/docs/art/mockups/start_screen_v3_build/$1.png" "file:///C:/dev/projects/NextCustomer/docs/art/mockups/start_screen_v3.html?$2" 2>/dev/null >/dev/null
timeout 60 "/c/Program Files/Google/Chrome/Application/chrome.exe" --headless=new --disable-gpu --allow-file-access-from-files --virtual-time-budget=6000 --dump-dom "file:///C:/dev/projects/NextCustomer/docs/art/mockups/start_screen_v3.html?$2" 2>/dev/null | grep -o 'data-check="[a-zA-Z]*"\|SELF-CHECK:[^<]*' | head -3
