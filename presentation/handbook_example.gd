class_name HandbookExample
extends RefCounted
## A handbook entry's worked example (v1.06, HandbookEntry.example_row): its cards scored by the
## game's own Scoring, under its day events and redraws left, so its numbers are always the rules'.
## The equation reads like the mock-up's: "Banana, Banana, Banana = 2 + 4 + 6 = 12€", each payout
## that differs from its card's printed price marked (equation_parts) for the page to colour.

const EQUALS := " = "
const PLUS := " + "
const COMMA := ", "

## The cards, in row order (a missing id is left out).
var cards: Array[CardDefinition] = []
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
	var events: Array[InspectionDefinition] = []
	for event_id: String in entry.example_events:
		var event: InspectionDefinition = content.inspection(event_id)
		if event != null:
			events.append(event)
	var credits: ScoreCredits = ScoreCredits.new()
	credits.redraws_left = entry.example_redraws_left
	var none: Array[UpgradeDefinition] = []
	example.result = Scoring.score(row, none, events, credits)
	return example


## Whether there is a scored row.
func is_scored() -> bool:
	return result != null and not cards.is_empty()


func total() -> int:
	return result.total if result != null else 0


## Each slot's payout, in row order.
func payouts() -> PackedInt32Array:
	return result.payouts if result != null else PackedInt32Array()


## The equation's parts in order, each [text, marked]: the names, then each payout (marked when it
## differs from its card's printed price), then the total (marked). Joined, they read
## "Bread, Eggs, Milk = 5 + 1 + 12 = 18€".
func equation_parts() -> Array[Array]:
	var parts: Array[Array] = []
	if not is_scored():
		return parts
	var names: PackedStringArray = PackedStringArray()
	for card: CardDefinition in cards:
		names.append(card.display_name)
	parts.append([COMMA.join(names) + EQUALS, false])
	var pays: PackedInt32Array = payouts()
	for slot: int in range(pays.size()):
		if slot > 0:
			parts.append([PLUS, false])
		parts.append([str(pays[slot]), pays[slot] != cards[slot].base])
	parts.append([EQUALS, false])
	parts.append([MonitorText.euros(total()), true])
	return parts


## The equation as plain text.
func equation() -> String:
	var text: String = ""
	for part: Array in equation_parts():
		text += str(part[0])
	return text
