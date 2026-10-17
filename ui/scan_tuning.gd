class_name ScanTuning
extends Resource
## The hover scanner's tuning (#80, step 1): how long the pointer stays on an item before its
## quiet hover turns into the animated scan, and how long the monitor's store channel shows each
## slide while nothing is scanned (MonitorChannel, the user's play test of 2026-10-17). It lives
## in data/balance/scan.tres so it can be tuned by feel without code changes; ScanController and
## MonitorChannel read it and never hard-code it. The defaults are neutral (0), like
## CountUpTuning's, so a script edit can never silently change the tuned values in the file.

## Milliseconds the pointer stays on the same item before the full scan plays (the popup, the
## lift, the tomato brackets and scan line, and the beep). A shorter stay shows nothing. In ms,
## like CountUpTuning's times and ScanController's clock.
@export var hold_ms: int = 0

## Milliseconds the monitor's store channel shows each slide in planning before it moves on to
## the next (MonitorChannel). In ms, like hold_ms.
@export var channel_slide_ms: int = 0
