#!/bin/sh
# usage: sh cap.sh <name> <page.html> <out.png> [query] [height]: one capture via the house cap.sh, unique TMPDIR, 3 tries
SP=/c/Users/marqu/AppData/Local/Temp/claude/C--dev-projects-NextCustomer/7500dc83-5e8d-48d1-8c46-c3bf1ad780bf/scratchpad/p77
M=/c/dev/projects/NextCustomer/docs/art/mockups
for i in 1 2 3; do
  d="$SP/${1}_${i}_$$"; mkdir -p "$d"
  TMPDIR="$d" sh "$M/count_up_86_v5_src/cap.sh" "$2" "$3" "$4" "$5" && exit 0
done
exit 1
