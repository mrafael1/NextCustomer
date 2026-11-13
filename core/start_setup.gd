class_name StartSetup
extends RefCounted
## Saved opening-time choices (start screen, full build plan 7.2; v1.32 "boosters": page 1 YOUR
## STORE deals sealed aisle boosters). StartSetupRules supplies the pure operations; the caller
## supplies the named random streams and saves after each commitment. Serialization stays
## independent of the live run.
##
## `stage` only moves forward: SELECT (set up, nothing dealt yet: a new run is dealt at once, so
## no save waits here in practice), DEALT (the boosters and the pack offer are dealt, the boosters
## sealed until opened), BUILD (page 2 was opened once). `stock_aisles` are the run's aisles, in
## data order: the dealt_aisle_count aisles of its boosters, the only aisles the run stocks (v1.32
## feedback, 2026-11-13). `boosters` are the dealt boosters in board order: one per stocked aisle,
## plus, from pair_choice_min_completed completed aisles, one more of an aisle not stocked (PICK 2
## OF 3, start_booster_choice_count in all). A booster counts (active_boosters) while its aisle is
## stocked and it is not SOLD OUT: while the pick is pending (picking) the seeded pair stands for
## the stock; once picked, the other one is SOLD OUT and the picked pair is the run's stock.
## `swap_offers` holds the swap window's booster of each stocked aisle (aisle id → up to
## regular_offer_max plain products of that aisle, those the copy limit lets in first; v1.32 swap
## window, 2026-11-13), kept the first time the window shows them so reopening it (or a resume)
## never rerolls them; `swap_opened` the aisles whose swap booster is open. `packs_redrawn`: NEW
## PACKS was used. `pins_confirmed`: the BADGE PINS step was confirmed (the packs wait for it
## while the profile owns a pin). `originals` are the recipe's own regulars, `completed_count` the
## completed aisles when the run started. A saved form without
## `boosters` is an older one (the first build's, or v1.07's three baskets, is_old_format): a run
## waiting for its pick restarts its setup instead of converting it (RunSave).

enum Stage { SELECT, DEALT, BUILD }

const STAGE_NAMES: Array[String] = ["select", "dealt", "build"]

var stage: Stage = Stage.SELECT
var stock_aisles: Array[StringName] = []
var completed_count: int = 0
var originals: Array[CardDefinition] = []
var boosters: Array[StartBooster] = []
var swap_offers: Dictionary[String, Array] = {}
var swap_opened: Array[StringName] = []
var packs_redrawn: bool = false
var picked: StringName = &""
var pins_confirmed: bool = false


## Whether PICK 2 OF 3 is pending: a booster of an aisle not stocked today, none SOLD OUT yet.
func picking() -> bool:
	var extra: bool = false
	for booster: StartBooster in boosters:
		if booster.sold_out:
			return false
		extra = extra or not stock_aisles.has(booster.aisle)
	return extra


## Whether booster `index` counts: its aisle is one of today's and it is not SOLD OUT.
func is_active(index: int) -> bool:
	if index < 0 or index >= boosters.size():
		return false
	return not boosters[index].sold_out and stock_aisles.has(boosters[index].aisle)


## The boosters whose cards count (is_active), in board order.
func active_boosters() -> Array[StartBooster]:
	var found: Array[StartBooster] = []
	for index: int in boosters.size():
		if is_active(index):
			found.append(boosters[index])
	return found


## Whether every active booster is opened (swaps wait for it: a sealed card must never count).
func all_open() -> bool:
	for booster: StartBooster in active_boosters():
		if not booster.opened:
			return false
	return true


## The active boosters' cards, in board order (the offer's shared products from DEALT on).
func shared() -> Array[CardDefinition]:
	var cards: Array[CardDefinition] = []
	for booster: StartBooster in active_boosters():
		cards.append_array(booster.cards)
	return cards


## The index of the booster the run's RESTOCK dealt again (-1: none).
func restock_booster() -> int:
	for index: int in boosters.size():
		if boosters[index].restocked:
			return index
	return -1


## The saved swap booster of aisle `aisle_id` (empty when not shown yet).
func swap_offer(aisle_id: StringName) -> Array[CardDefinition]:
	var offer: Array[CardDefinition] = []
	offer.assign(swap_offers.get(String(aisle_id), []))
	return offer


## Whether the swap window has shown aisle `aisle_id`'s booster (its offer is saved).
func has_swap_offer(aisle_id: StringName) -> bool:
	return swap_offers.has(String(aisle_id))


func stage_name() -> String:
	return STAGE_NAMES[stage]


func to_dictionary() -> Dictionary:
	var saved_boosters: Array[Dictionary] = []
	for booster: StartBooster in boosters:
		saved_boosters.append(booster.to_dictionary())
	var offers: Dictionary = {}
	for key: String in swap_offers:
		offers[key] = _ids(swap_offer(StringName(key)))
	var opened: Array[String] = []
	for id: StringName in swap_opened:
		opened.append(String(id))
	return {
		"stage": stage_name(),
		"stock_aisles": Array(stock_aisles),
		"completed_count": completed_count,
		"originals": _ids(originals),
		"boosters": saved_boosters,
		"swap_offers": offers,
		"swap_opened": opened,
		"packs_redrawn": packs_redrawn,
		"picked": String(picked),
		"pins_confirmed": pins_confirmed,
	}


## A copy holding the same choices (a caller's snapshot for rolling a failed save back).
func copy() -> StartSetup:
	var other: StartSetup = StartSetup.new()
	other.stage = stage
	other.stock_aisles = stock_aisles.duplicate()
	other.completed_count = completed_count
	other.originals = originals.duplicate()
	for booster: StartBooster in boosters:
		other.boosters.append(booster.copy())
	for key: String in swap_offers:
		other.swap_offers[key] = swap_offer(StringName(key))
	other.swap_opened = swap_opened.duplicate()
	other.packs_redrawn = packs_redrawn
	other.picked = picked
	other.pins_confirmed = pins_confirmed
	return other


## Whether `data` is a setup saved in an older form (the first build's, or v1.07's three
## baskets): one without boosters.
static func is_old_format(data: Dictionary) -> bool:
	return not data.has("boosters")


## The setup `data` holds, or null when it is damaged or in an older form (is_old_format).
static func from_dictionary(data: Dictionary, lookup: ContentLookup) -> StartSetup:
	if is_old_format(data):
		return null
	var reader: SaveReader = SaveReader.new(data, lookup)
	var setup: StartSetup = StartSetup.new()
	var stage_index: int = STAGE_NAMES.find(reader.text("stage"))
	setup.stage = maxi(stage_index, 0) as Stage
	setup.stock_aisles = reader.aisles("stock_aisles")
	setup.completed_count = reader.whole("completed_count")
	setup.originals = reader.cards("originals")
	setup.packs_redrawn = reader.flag("packs_redrawn")
	setup.picked = StringName(reader.text("picked"))
	setup.pins_confirmed = reader.flag("pins_confirmed")
	for saved: Dictionary in reader.dictionaries("boosters"):
		var booster_reader: SaveReader = SaveReader.new(saved, lookup)
		var booster: StartBooster = StartBooster.new(
			StringName(booster_reader.text("aisle")),
			booster_reader.cards("cards"),
			booster_reader.whole("hits")
		)
		booster.opened = booster_reader.flag("opened")
		booster.sold_out = booster_reader.flag("sold_out")
		booster.restocked = booster_reader.flag("restocked")
		reader.ok = reader.ok and booster_reader.ok
		setup.boosters.append(booster)
	var offers: Variant = data.get("swap_offers")
	if not offers is Dictionary:
		return null
	var offers_reader: SaveReader = SaveReader.new(offers as Dictionary, lookup)
	for key: Variant in (offers as Dictionary).keys():
		if not key is String:
			return null
		setup.swap_offers[key as String] = offers_reader.cards(key as String)
	setup.swap_opened = reader.aisles("swap_opened")
	if not reader.ok or not offers_reader.ok or stage_index == -1:
		return null
	return setup if setup._is_valid(lookup.balance) else null


func _is_valid(balance: BalanceDefinition) -> bool:
	var size: int = mini(balance.dealt_aisle_count, balance.aisles.size())
	var valid: bool = stock_aisles.size() == size and _distinct(stock_aisles)
	valid = valid and completed_count <= balance.aisles.size() and _offers_valid(balance)
	if stage == Stage.SELECT:
		return (
			valid
			and boosters.is_empty()
			and not packs_redrawn
			and picked == &""
			and not pins_confirmed
			and swap_offers.is_empty()
		)
	return valid and _boosters_valid(balance)


## The boosters: one per stocked aisle, plus the PICK 2 OF 3 extras from
## pair_choice_min_completed (aisles not stocked today); each booster valid (_booster_valid) and
## flagged consistently (_flags_valid); the active ones the stocked aisles.
func _boosters_valid(balance: BalanceDefinition) -> bool:
	var green: Array[StringName] = stock_aisles
	var most: int = green.size()
	var choice: bool = balance.pair_choice_min_completed > 0
	if choice and completed_count >= balance.pair_choice_min_completed:
		most = maxi(most, balance.start_booster_choice_count)
	if boosters.size() < green.size() or boosters.size() > most:
		return false
	var aisles: Array[StringName] = []
	for booster: StartBooster in boosters:
		if aisles.has(booster.aisle):
			return false
		aisles.append(booster.aisle)
		if not _booster_valid(balance, booster):
			return false
	if not _flags_valid(balance, green.size()):
		return false
	var active: Array[StringName] = []
	for booster: StartBooster in active_boosters():
		active.append(booster.aisle)
	return StartSetupRules.ordered_pair(balance, active) == green


## The boosters' flags: after the pick every extra SOLD OUT (never opened or restocked), while
## picking none opened or restocked, NEW PACKS unused and page 2 not opened; at most
## restocks_per_run restocked, and only from restock_min_completed.
func _flags_valid(balance: BalanceDefinition, green_count: int) -> bool:
	var sold: int = 0
	var restocks: int = 0
	var touched: bool = false
	for booster: StartBooster in boosters:
		if booster.sold_out and (booster.opened or booster.restocked):
			return false
		sold += 1 if booster.sold_out else 0
		restocks += 1 if booster.restocked else 0
		touched = touched or booster.opened or booster.restocked
	var valid: bool = sold == 0 or sold == boosters.size() - green_count
	valid = valid and restocks <= maxi(balance.restocks_per_run, 0)
	valid = valid and (restocks == 0 or completed_count >= balance.restock_min_completed)
	if picking():
		valid = valid and not touched and not packs_redrawn and stage != Stage.BUILD
	return valid


## A booster: at most start_booster_size cards of its aisle, distinct products, at most
## start_booster_hit_slots hit places (the last), a BIG card only in a hit place, never GOLDEN.
static func _booster_valid(balance: BalanceDefinition, booster: StartBooster) -> bool:
	if booster.cards.size() > balance.start_booster_size:
		return false
	if booster.hits > maxi(balance.start_booster_hit_slots, 0):
		return false
	if booster.hits > booster.cards.size():
		return false
	var products: Array[CardDefinition] = []
	for index: int in booster.cards.size():
		var card: CardDefinition = booster.cards[index]
		if not card.is_product() or card.tier == CardDefinition.Tier.GOLDEN:
			return false
		if card.tier == CardDefinition.Tier.BIG and not booster.is_hit(index):
			return false
		var aisle: AisleDefinition = balance.aisle_of(card)
		if aisle == null or aisle.id != booster.aisle or products.has(card.product_card()):
			return false
		products.append(card.product_card())
	return true


## The swap boosters: one per stocked aisle at most, each at most regular_offer_max distinct
## plain-tier products of its aisle; only a shown booster (its offer saved) can be open.
func _offers_valid(balance: BalanceDefinition) -> bool:
	for key: String in swap_offers:
		var aisle: AisleDefinition = null
		for candidate: AisleDefinition in balance.aisles:
			if String(candidate.id) == key:
				aisle = candidate
		if not stock_aisles.has(StringName(key)) or aisle == null:
			return false
		if not _offer_valid(swap_offer(StringName(key)), aisle, balance.regular_offer_max):
			return false
	for id: StringName in swap_opened:
		if swap_opened.count(id) != 1 or not swap_offers.has(String(id)):
			return false
	return true


## Whether `offer` holds at most `most` distinct plain-tier products of `aisle`.
static func _offer_valid(offer: Array[CardDefinition], aisle: AisleDefinition, most: int) -> bool:
	if offer.size() > most:
		return false
	for card: CardDefinition in offer:
		var plain: bool = card.is_product() and card.variant_of == null
		plain = plain and card.tier == CardDefinition.Tier.PLAIN
		if offer.count(card) != 1 or not plain:
			return false
		if not aisle.base_cards.has(card) and not aisle.capsule_cards.has(card):
			return false
	return true


static func _distinct(ids: Array[StringName]) -> bool:
	for id: StringName in ids:
		if ids.count(id) != 1:
			return false
	return true


static func _ids(cards: Array[CardDefinition]) -> Array[String]:
	var ids: Array[String] = []
	for card: CardDefinition in cards:
		ids.append(String(card.id))
	return ids
