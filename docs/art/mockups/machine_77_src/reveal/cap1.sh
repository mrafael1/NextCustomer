#!/bin/sh
# usage: sh cap1.sh <name-suffix> "<query>" [height]: captures machine_77_reveals.html to machine_77_reveals_<suffix>.png
# (a unique Chrome profile per capture under the session scratchpad, up to 3 tries; the profile is removed afterwards)
M=/c/dev/projects/NextCustomer/docs/art/mockups
SP=/c/Users/marqu/AppData/Local/Temp/claude/C--dev-projects-NextCustomer/7500dc83-5e8d-48d1-8c46-c3bf1ad780bf/scratchpad/p77
for try in 1 2 3; do
  d="$SP/reveal_$1_${try}_$$"; mkdir -p "$d"
  TMPDIR="$d" sh "$M/count_up_86_v5_src/cap.sh" "$M/machine_77_reveals.html" "$M/machine_77_reveals_$1.png" "$2" "${3:-720}" && { rm -rf "$d"; exit 0; }
  rm -rf "$d"
done
exit 1
