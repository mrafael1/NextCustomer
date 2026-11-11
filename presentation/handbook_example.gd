class_name HandbookExample
extends RefCounted
## A handbook entry's worked example (v1.06, HandbookEntry.example_row): its cards scored by the
## game's own Scoring, under its day events and redraws left, so its numbers are always the rules'.
## The equation reads like the mock-up's: "Banana, Banana, Banana = 2 + 4 + 6 = 12€", each part
## painted (equation_parts) for the page to colour: an item's name as an item, a coupon's as a
## coupon (the guide feedback of 2026-11-11, round 3), each payout that differs from its card's
## printed price marked.

## How the page paints an equation part: plain ink, a marked amount, an item's or a coupon's name.
enum Paint { PLAIN, MARKED, ITEM, COUPON }

const EQUALS := " = "
const PLUS := " + "
const COMMA := ", "

## The cards, in row order (a missing id is left out).
var cards: Array[CardDefinition] = []
## The day events it is scored under (a missing id is left out).
var events: Array[InspectionDefinition] = []
## The Price gun's relabels: row slot (from 0) to the family it gains.
var relabels: Dictionary[int, String] = {}
## The example's quota (0: none).
var quota: int = 0
var result: ScoreResult


## The example of `entry` (an empty one when it has none), its cards found by `lookup` (the game's
## data/cards by default).
static func of(entry: HandbookEntry, lookup: ContentLookup = null) -> HandbookExample:
	var example: HandbookExample = HandbookExample.new()
	if entry == null or not entry.has_example():
		return example
	var content: ContentLookup = lookup if lookup != null else ContentLookup.new(null)
	var row: Array[CardInstance] = []
	for card_id: String in entry.example_row:
		var card: CardDefinition = content.card(card_id)
		if card == null:
			continue
		example.cards.append(card)
		row.append(CardInstance.new(card, row.size() + 1))
	for event_id: String in entry.example_events:
		var event: InspectionDefinition = content.inspection(event_id)
		if event != null:
			example.events.append(event)
	var credits: ScoreCredits = ScoreCredits.new()
	credits.redraws_left = entry.example_redraws_left
	for relabel: String in entry.example_relabels:
		var parts: PackedStringArray = relabel.split(":")
		var slot: int = parts[0].to_int() - 1 if parts.size() == 2 else -1
		if slot >= 0 and slot < row.size():
			example.relabels[slot] = parts[1]
			credits.relabels[row[slot].instance_id] = parts[1]
	example.quota = entry.example_quota
	var none: Array[UpgradeDefinition] = []
	example.result = Scoring.score(row, none, example.events, credits)
	return example


## Whether there is a scored row.
func is_scored() -> bool:
	return result != null and not cards.is_empty()


func total() -> int:
	return result.total if result != null else 0


## Each slot's payout, in row order.
func payouts() -> PackedInt32Array:
	return result.payouts if result != null else PackedInt32Array()


## The equation's parts in order, each [text, Paint]: each card's name (ITEM or COUPON) with the
## commas between them, then each payout (MARKED when it differs from its card's printed price),
## then the total (MARKED). Joined, they read "Bread, Eggs, Milk = 5 + 1 + 12 = 18€".
func equation_parts() -> Array[Array]:
	var parts: Array[Array] = []
	if not is_scored():
		return parts
	for slot: int in range(cards.size()):
		if slot > 0:
			parts.append([COMMA, Paint.PLAIN])
		var card: CardDefinition = cards[slot]
		parts.append([card.display_name, Paint.COUPON if card.is_coupon() else Paint.ITEM])
	parts.append([EQUALS, Paint.PLAIN])
	var pays: PackedInt32Array = payouts()
	for slot: int in range(pays.size()):
		if slot > 0:
			parts.append([PLUS, Paint.PLAIN])
		var marked: bool = pays[slot] != cards[slot].base
		parts.append([str(pays[slot]), Paint.MARKED if marked else Paint.PLAIN])
	parts.append([EQUALS, Paint.PLAIN])
	parts.append([MonitorText.euros(total()), Paint.MARKED])
	return parts


## The equation as plain text.
func equation() -> String:
	var text: String = ""
	for part: Array in equation_parts():
		text += str(part[0])
	return text
