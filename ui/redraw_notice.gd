class_name RedrawNotice
extends RefCounted
## What the monitor's redraw panel says (plan section 3.8; mock-up redraw_basket_v1.html, approved
## by the user on 2026-10-22), built by the shift screen from RunState's counts: redraw mode armed
## (armed), a basket hovered (hovered) and the redraw playing (redrawing). Display only: plain
## data and wording, no rule; RedrawPanel lays it out.

## The panel's heading ("REDRAW", "REDRAW BASKET 2", "REDRAWING") and the redraws left beside it.
var title: String = ""
var left: int = 0
## A small spaced line under the heading ("PICK A BASKET"), or "".
var key: String = ""
## The items going (left first) and, while redrawing, the ones coming; `drawn` new items named
## after the going ones when nothing is coming yet ("2 new items drawn"), with the cost chip.
var going: Array[CardDefinition] = []
var coming: Array[CardDefinition] = []
var drawn: int = 0
var cost: bool = false
## The body line (BBCode: [b] for names), and the foot line under the dashed rule; a warning foot
## (a short draw pile) is tomato dark.
var line: String = ""
var foot: String = ""
var foot_warning: bool = false


## Redraw mode armed, no basket hovered.
static func armed(redraws_left: int) -> RedrawNotice:
	var notice: RedrawNotice = RedrawNotice.new()
	notice.title = "REDRAW"
	notice.left = redraws_left
	notice.key = "PICK A BASKET"
	notice.line = (
		"Its items are set aside and new ones are drawn into it."
		+ " Each basket costs [b]1 redraw[/b]."
	)
	notice.foot = "Empty baskets can't be redrawn · Cancel to back out"
	return notice


## Basket `basket` (0-based) hovered: its hand items `items` (left first) with `pile` cards left
## to draw, so the first min(items, pile) go and the rest stay.
static func hovered(
	basket: int, redraws_left: int, items: Array[CardDefinition], pile: int
) -> RedrawNotice:
	var notice: RedrawNotice = RedrawNotice.new()
	notice.title = "REDRAW BASKET %d" % (basket + 1)
	notice.left = redraws_left
	var count: int = mini(items.size(), pile)
	notice.going = items.slice(0, count)
	notice.drawn = count
	notice.cost = true
	notice.line = "Set aside for this shift: %s." % names(notice.going)
	if count < items.size():
		var stays: CardDefinition = items[count]
		var word: String = "item" if pile == 1 else "items"
		notice.foot = "Only %d %s left to draw: %s stays." % [pile, word, stays.display_name]
		notice.foot_warning = true
	else:
		notice.foot = "They go back in the Cart next shift."
	return notice


## The redraw playing: `going` out, `coming` in.
static func redrawing(
	redraws_left: int, going_items: Array[CardDefinition], coming_items: Array[CardDefinition]
) -> RedrawNotice:
	var notice: RedrawNotice = RedrawNotice.new()
	notice.title = "REDRAWING"
	notice.left = redraws_left
	notice.going = going_items.duplicate()
	notice.coming = coming_items.duplicate()
	notice.foot = "The old items are set aside for this shift."
	return notice


## "[b]A[/b]", "[b]A[/b] and [b]B[/b]" (BBCode).
static func names(items: Array[CardDefinition]) -> String:
	var parts: PackedStringArray = PackedStringArray()
	for item: CardDefinition in items:
		parts.append("[b]%s[/b]" % item.display_name)
	return " and ".join(parts)
