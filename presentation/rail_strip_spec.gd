class_name RailStripSpec
extends RefCounted
## One rail strip along the belt lip (#71, mock-up h1, H1_BUILD_SPEC.md section 5): who gives
## what to whom. One per giver slot, covering every item its card gives a bonus, a stamp, a copy
## or a fizzle (an Egg reset) to. Pure data: every number comes from the score's steps.

## The giver's slot (the plug and the name plate sit at its ticket).
var giver_slot: int = -1
## The giver's display name in uppercase, for the name plate.
var name: String = ""
## The target slots, ascending; descending for a backward strip (nearest the giver first).
var targets: PackedInt32Array = PackedInt32Array()
## One per target: the link tokens to that target joined by a space ("+2 ×2").
var tokens: PackedStringArray = PackedStringArray()
## One per target: the summed EffectLink.gain of the links to it, or -1 when a denial cancelled
## them (no gain badge then).
var gains: PackedInt32Array = PackedInt32Array()
## The lane: 0 (the lip), 1 (the top face's front edge) or -1 (overflow: drawn only on hover).
var lane: int = 0
## Every target comes before the giver (the cap is at the leftmost target and the chevrons
## point left).
var backward: bool = false


## The span's first slot (the giver or a target).
func lo() -> int:
	var low: int = giver_slot
	for target: int in targets:
		low = mini(low, target)
	return low


## The span's last slot.
func hi() -> int:
	var high: int = giver_slot
	for target: int in targets:
		high = maxi(high, target)
	return high


## Whether this strip's span shares a slot with `other`'s (they can't share a lane).
func conflicts(other: RailStripSpec) -> bool:
	return lo() <= other.hi() and other.lo() <= hi()
