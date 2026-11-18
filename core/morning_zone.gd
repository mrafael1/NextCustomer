class_name MorningZone
extends Resource
## The MORNING ZONE (the rule of 2026-11-18, in place of #128's opening run): the row's first
## `slots` slots. A product with the reading card's tag (Breakfast) standing in one of them is a
## MORNING item; nothing else counts (no run, no first-slot condition). One balance value
## (data/balance/morning_zone.tres) every MORNING card's rule points at, and the belt's print
## reads. 0 slots: no zone.

@export var slots: int = 0
