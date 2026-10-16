class_name ScanTuning
extends Resource
## The hover scanner's tuning (#80, step 1): how long the pointer stays on an item before its
## quiet hover turns into the animated scan. It lives in data/balance/scan.tres so it can be
## tuned by feel without code changes; ScanController reads it and never hard-codes it. The
## default is neutral (0), like CountUpTuning's, so a script edit can never silently change the
## tuned value in the file.

## Milliseconds the pointer stays on the same item before the full scan plays (the popup, the
## lift, the tomato brackets and scan line, and the beep). A shorter stay shows nothing. In ms,
## like CountUpTuning's times and ScanController's clock.
@export var hold_ms: int = 0
