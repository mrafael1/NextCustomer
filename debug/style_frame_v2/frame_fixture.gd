class_name StyleFrameFixture
extends RefCounted
## Style frame v2's data (#75, spec section 7): the screen capture's fixture (seed, shift 5 of 8
## under Short belt, the upgrades, the hand and the row), state 2's rearranged row, and the
## cards, upgrades, inspection, limits and balance from data/. Nothing here scores: the scene
## calls Scoring.score on these cards.

const CAPTURE := preload("res://debug/screen_capture/screen_capture.gd")
const BALANCE := preload("res://data/balance/balance.tres")
const TUNING := preload("res://data/balance/count_up.tres")
const STICKERS := preload("res://debug/style_frame_v2/sticker_texts.tres")
const CARD_PATH := "res://data/cards/%s.tres"
const UPGRADE_PATH := "res://data/upgrades/%s.tres"
const INSPECTION_PATH := "res://data/inspections/%s.tres"
## State 2: state 1's cards rearranged into a full row (a reachable planning move), frozen at the
## first step of COUNT_UP_SLOT (round 2, delta section 9: Batteries' +15, so the receipt reaches
## the counter and a chip still to come shows dimmed).
const COUNT_UP_ROW_IDS: Array[String] = [
	"coffee", "croissant", "strawberries", "banana", "multipack", "batteries"
]
const COUNT_UP_HAND_IDS: Array[String] = [
	"eggs", "tea_bags", "two_for_one", "crisps", "milk", "cheese"
]
const COUNT_UP_SLOT := 5
## Mocked: the deck's size in the Deck button.
const DECK_COUNT := 13


## The run's upgrades in pick order (the capture fixture's).
static func upgrades() -> Array[UpgradeDefinition]:
	var found: Array[UpgradeDefinition] = []
	for upgrade_id: String in CAPTURE.UPGRADE_IDS:
		found.append(load(UPGRADE_PATH % upgrade_id) as UpgradeDefinition)
	return found


## The shift's inspections (the capture fixture's Short belt).
static func inspections() -> Array[InspectionDefinition]:
	return [load(INSPECTION_PATH % CAPTURE.INSPECTION) as InspectionDefinition]


## The shift's limits, as the game computes them.
static func limits() -> ShiftLimits:
	return ShiftLimits.for_shift(BALANCE, upgrades(), CAPTURE.SHIFT - 1, inspections())


static func card(card_id: String) -> CardDefinition:
	return load(CARD_PATH % card_id) as CardDefinition


## The 12 cards of the fixture (the hand, then the row), each once.
static func card_ids() -> Array[String]:
	var ids: Array[String] = []
	ids.append_array(CAPTURE.HAND_IDS)
	ids.append_array(CAPTURE.ROW_IDS)
	return ids


static func names(cards: Array[CardInstance]) -> PackedStringArray:
	var found: PackedStringArray = PackedStringArray()
	for instance: CardInstance in cards:
		found.append(instance.definition.display_name)
	return found


static func upgrade_names() -> PackedStringArray:
	return LoyaltyCard.names(upgrades())


static func inspection_names() -> PackedStringArray:
	return InspectionTag.names(inspections())


## The capacity line for `row`, worded as the shift screen's.
static func capacity_text(row: Array[CardInstance]) -> String:
	var shift: ShiftLimits = limits()
	return (
		"Products %d/%d%s  ·  Coupon slot%s %d/%d%s"
		% [
			RowCapacity.product_count(row),
			shift.slot_count,
			_closed_text(shift.closed_slots, shift.slot_count),
			"s" if shift.coupon_slot_count > 1 else "",
			RowCapacity.coupon_slots_used(shift, row),
			shift.coupon_slot_count,
			_closed_text(shift.closed_coupon_slots, shift.coupon_slot_count),
		]
	)


## The pile's height in pixels: the earlier shifts' paper plus `printed` lines (count_up.tres).
static func pile_height(printed: int) -> float:
	var start: float = minf(
		TUNING.pile_start_px_per_shift * (CAPTURE.SHIFT - 1), TUNING.pile_start_max_px
	)
	return start + TUNING.pile_px_per_line * printed


static func _closed_text(closed: int, left: int) -> String:
	if closed <= 0:
		return ""
	return "  (closed)" if left == 0 else "  (inspection −%d)" % closed
