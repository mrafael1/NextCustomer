class_name RedrawNotice
extends RefCounted
## What the monitor's redraw panel says (plan section 3.8; mock-up redraw_basket_v1.html, approved
## by the user on 2026-10-22), built by the shift screen from RunState's counts: redraw mode armed
## (armed), a basket hovered (hovered) and the redraw playing (redrawing). Display only: plain
## data and wording, no rule; RedrawPanel lays it out. With a Recycle pin (#122,
## RunPins.recycles) the old items go back in the pile rather than being set aside, and the
## wording says so (`recycle`). With a Stock list pin (#132, PinPlay.peek; the user's call of
## 2026-11-02) a hovered basket also shows the items its redraw would bring (`coming`).

const RECYCLE_LINE := "Back in the pile, to draw again: %s."
const RECYCLE_FOOT := "The old items go back in the pile (Recycle)."
## The Redraw key's captions (caps, as the register's other keys: the PR #138 left UI): REDRAW,
## PICK A BASKET while redraw mode is armed, NONE TO DRAW with an empty draw pile.
const REDRAW_CAPTION := "REDRAW"
const PICK_CAPTION := "PICK A BASKET"
const EMPTY_CAPTION := "NONE TO DRAW"

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


## Redraw mode's panel for `run`, with basket `hovered_basket` hovered (-1: none, or one that
## can't be redrawn: armed).
static func of_run(run: RunState, hovered_basket: int) -> RedrawNotice:
	var redraws_left: int = run.redraws_allowed - run.redraws_used
	var recycle: bool = RunPins.recycles(run)
	if hovered_basket < 0 or not run.can_redraw_basket(hovered_basket):
		return armed(redraws_left, recycle)
	var items: Array[CardDefinition] = []
	var places: Array[CardInstance] = run.hand_places()
	for place: int in run.basket_places(hovered_basket):
		items.append(places[place].definition)
	var notice: RedrawNotice = hovered(
		hovered_basket, redraws_left, items, run.deck.draw_pile().size(), recycle
	)
	var next: Array[CardDefinition] = definitions(PinPlay.peek(run))
	notice.coming = next.slice(0, mini(notice.drawn, next.size()))
	return notice


## Redraw mode armed, no basket hovered.
static func armed(redraws_left: int, recycle: bool = false) -> RedrawNotice:
	var notice: RedrawNotice = RedrawNotice.new()
	notice.title = "REDRAW"
	notice.left = redraws_left
	notice.key = "PICK A BASKET"
	var fate: String = "go back in the pile" if recycle else "are set aside"
	notice.line = (
		"Its items %s and new ones are drawn into it." % fate
		+ " Each basket costs [b]1 redraw[/b]."
	)
	notice.foot = "Empty baskets can't be redrawn · Cancel to back out"
	return notice


## Basket `basket` (0-based) hovered: its hand items `items` (left first) with `pile` cards left
## to draw, so the first min(items, pile) go and the rest stay.
static func hovered(
	basket: int, redraws_left: int, items: Array[CardDefinition], pile: int, recycle: bool = false
) -> RedrawNotice:
	var notice: RedrawNotice = RedrawNotice.new()
	notice.title = "REDRAW BASKET %d" % (basket + 1)
	notice.left = redraws_left
	var count: int = mini(items.size(), pile)
	notice.going = items.slice(0, count)
	notice.drawn = count
	notice.cost = true
	notice.line = "Set aside for this shift: %s." % names(notice.going)
	if recycle:
		notice.line = RECYCLE_LINE % names(notice.going)
	if count < items.size():
		var stays: CardDefinition = items[count]
		var word: String = "item" if pile == 1 else "items"
		notice.foot = "Only %d %s left to draw: %s stays." % [pile, word, stays.display_name]
		notice.foot_warning = true
	elif not recycle:
		notice.foot = "They go back in the Cart next shift."
	else:
		notice.foot = RECYCLE_FOOT
	return notice


## `run`'s redraw playing: `going` out, `coming` in.
static func redrawing(
	run: RunState, going_items: Array[CardDefinition], coming_items: Array[CardDefinition]
) -> RedrawNotice:
	var notice: RedrawNotice = RedrawNotice.new()
	notice.title = "REDRAWING"
	notice.left = run.redraws_allowed - run.redraws_used
	notice.going = going_items.duplicate()
	notice.coming = coming_items.duplicate()
	notice.foot = "The old items are set aside for this shift."
	if RunPins.recycles(run):
		notice.foot = RECYCLE_FOOT
	return notice


## The cards' definitions, in order.
static func definitions(cards: Array[CardInstance]) -> Array[CardDefinition]:
	var found: Array[CardDefinition] = []
	for card: CardInstance in cards:
		found.append(card.definition)
	return found


## "[b]A[/b]", "[b]A[/b] and [b]B[/b]" (BBCode).
static func names(items: Array[CardDefinition]) -> String:
	var parts: PackedStringArray = PackedStringArray()
	for item: CardDefinition in items:
		parts.append("[b]%s[/b]" % item.display_name)
	return " and ".join(parts)


## The colour of a redraw count `redraws_left` (the Redraw key's counter, the redraw panel's
## heading): green for 2 or more, orange for 1 (the PR #138 review: orange, not the brown of
## mustard darkest), red for none, each dark enough to read on the paper of the key's counter
## window and the panel.
static func count_color(redraws_left: int) -> Color:
	if redraws_left >= 2:
		return Palette.GREEN_DARK
	if redraws_left == 1:
		return Palette.ORANGE_DARK
	return Palette.TOMATO_DARK


## Captions the shift screen's Redraw `redraw_key`: redraw mode `is_armed`, the redraws
## `redraws_left` and whether any item is left `to_draw`. The count stands in the key's counter
## window in count_color (the PR #138 left UI: its own part, left of the key's face; the 0 struck
## through on an unlit pane, RegisterKey.NoteLook.ALERT), the face reads REDRAW (PICK A BASKET
## while armed, NONE TO DRAW with an empty draw pile). Screen readers hear "(N left)".
static func caption_key(
	redraw_key: RegisterKey, is_armed: bool, redraws_left: int, to_draw: bool
) -> void:
	var count: String = "%d" % redraws_left
	var color: Color = count_color(redraws_left)
	var look: RegisterKey.NoteLook = RegisterKey.NoteLook.COUNT
	var caption: String = REDRAW_CAPTION
	var spoken: String = "Redraw a basket (%d left)" % redraws_left
	if is_armed:
		caption = PICK_CAPTION
		spoken = "Pick a basket (%d left)" % redraws_left
	elif redraws_left <= 0:
		look = RegisterKey.NoteLook.ALERT
		spoken = "Redraw (0 left)"
	elif not to_draw:
		caption = EMPTY_CAPTION
		spoken = "Redraw: no items left to draw (%d left)" % redraws_left
	redraw_key.show_caption(caption, count, spoken, color, look)
