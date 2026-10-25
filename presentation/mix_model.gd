class_name MixModel
extends RefCounted
## The mix highlight's looks (#105 piece 3, mock-up readability v3 section 4, option A): which
## items light up and which grey while the player looks for what to mix.
##
## A family glyph's hover (for_family) lights every item in that family and greys the rest. An
## item's hover or hold (for_card) lights the items it works with (CardAffinity, both ways: its
## rule's targets and the items that boost it): a penalty pair shows PENALTY, a belt pair that
## pays in the current order (EffectGraph.related_slots) NOW, another match LIT, and a match that
## comes only from a broad family ("×2 next Food") FAINT, greyed under a faint outline, unless the
## pair pays now. The item itself is SELF and every other item greys. With nothing to light, the
## result is empty: no highlight at all.
##
## Presentation only: it reads the cards' rules and the score's graph, never scores.

## SELF the hovered or held item; LIT, NOW and PENALTY lit; FAINT and GREY greyed.
enum Look { NONE, SELF, LIT, NOW, PENALTY, FAINT, GREY }


## One item on screen: its card, the tags it has there (a belt item's scored tags, a granted
## Breakfast included; the printed ones elsewhere) and its belt slot (-1 off the belt).
class Entry:
	extends RefCounted

	var card: CardInstance
	var tags: PackedStringArray
	var slot: int = -1

	func _init(item_card: CardInstance, item_tags: PackedStringArray, belt_slot: int = -1) -> void:
		card = item_card
		tags = item_tags
		slot = belt_slot


## The looks of `entries` (in order) while `family`'s glyph is hovered: LIT in the family, else
## GREY; empty when no entry is in it.
static func for_family(entries: Array[Entry], family: String) -> Array[Look]:
	var looks: Array[Look] = []
	var any: bool = false
	for entry: Entry in entries:
		var lit: bool = CardAffinity.in_family(entry.tags, family)
		any = any or lit
		looks.append(Look.LIT if lit else Look.GREY)
	if not any:
		looks.clear()
	return looks


## The looks of `entries` (in order) while `focus` is hovered or held: SELF for its own card, then
## PENALTY, NOW (a belt pair `graph` says pays now; none without a graph, e.g. in a drag), LIT,
## FAINT (a broad match only: `broad`'s families), else GREY; empty when nothing is lit or faint.
static func for_card(
	entries: Array[Entry], focus: Entry, graph: EffectGraph, broad: PackedStringArray
) -> Array[Look]:
	var looks: Array[Look] = []
	var now: PackedInt32Array = PackedInt32Array()
	if graph != null and focus.slot >= 0:
		now = graph.related_slots(focus.slot)
	var any: bool = false
	for entry: Entry in entries:
		var look: Look = Look.SELF
		if entry.card != focus.card:
			look = _look(entry, focus, now, broad)
			any = any or look != Look.GREY
		looks.append(look)
	if not any:
		looks.clear()
	return looks


## Whether `look` greys its item (GREY, and FAINT under its outline).
static func greys(look: Look) -> bool:
	return look == Look.GREY or look == Look.FAINT


static func _look(
	entry: Entry, focus: Entry, now: PackedInt32Array, broad: PackedStringArray
) -> Look:
	var hit: CardAffinity.Match = CardAffinity.between(
		focus.card.definition, focus.tags, entry.card.definition, entry.tags, broad
	)
	if hit == CardAffinity.Match.PENALTY:
		return Look.PENALTY
	if entry.slot >= 0 and now.has(entry.slot):
		return Look.NOW
	if hit == CardAffinity.Match.YES:
		return Look.LIT
	return Look.FAINT if hit == CardAffinity.Match.WEAK else Look.GREY
