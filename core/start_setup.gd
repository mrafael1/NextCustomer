class_name StartSetup
extends RefCounted
## Saved opening-time choices (start screen, full build plan 7.2, reworked 2026-11-05).
## StartSetupRules supplies the pure operations; the caller supplies the named random streams and
## saves after each commitment. Serialization stays independent of the live run.
##
## `stage` only moves forward: SELECT (today's aisles are being set, nothing dealt), REVEALED
## (LOCK IN & DEAL dealt the baskets and drew the pack offer; the aisles are locked for the run),
## BUILD (page 2 was opened once). `stock_aisles` are today's aisles: the STARTER CART (green)
## aisles first, in data order, then the RUN ONLY (orange) one. `baskets` are the three baskets in
## order: the Staples shelf's, then each green aisle's; their cards are empty in SELECT.
## `restock_basket` is the basket the once-a-run RESTOCK redrew (-1: none). `regular_offers` holds
## each regular slot's offer from one aisle ("<slot>:<aisle id>" → cards, data order), kept the
## first time it is shown so reopening never rerolls it. `packs_redrawn`: NEW PACKS was used.
## `originals` are the recipe's own regulars, `completed_count` the completed aisles when the run
## started. A saved form without `stage` is the first build's (is_old_format): a run waiting for
## its pick restarts its setup instead of converting it (RunSave).

enum Stage { SELECT, REVEALED, BUILD }

## The Staples basket's source.
const STAPLES := &"staples"
const STAGE_NAMES: Array[String] = ["select", "revealed", "build"]

var stage: Stage = Stage.SELECT
var stock_aisles: Array[StringName] = []
var completed_count: int = 0
var originals: Array[CardDefinition] = []
var baskets: Array[StartBasket] = []
var restock_basket: int = -1
var regular_offers: Dictionary[String, Array] = {}
var packs_redrawn: bool = false
var picked: StringName = &""


## The STARTER CART (green) aisles, data order.
func green_ids(balance: BalanceDefinition) -> Array[StringName]:
	return stock_aisles.slice(0, balance.dealt_aisle_count)


## The RUN ONLY (orange) aisles.
func run_only_ids(balance: BalanceDefinition) -> Array[StringName]:
	return stock_aisles.slice(balance.dealt_aisle_count)


## The baskets' sources, in basket order.
func basket_sources() -> Array[StringName]:
	var sources: Array[StringName] = []
	for basket: StartBasket in baskets:
		sources.append(basket.source)
	return sources


## The baskets' cards, in basket order (the offer's shared products from REVEALED on).
func shared() -> Array[CardDefinition]:
	var cards: Array[CardDefinition] = []
	for basket: StartBasket in baskets:
		cards.append_array(basket.cards)
	return cards


## The key of regular `slot`'s offer from aisle `aisle_id` in regular_offers.
static func offer_key(slot: int, aisle_id: StringName) -> String:
	return "%d:%s" % [slot, aisle_id]


## Slot `slot`'s saved offer from `aisle_id` (empty when not shown yet).
func regular_offer(slot: int, aisle_id: StringName) -> Array[CardDefinition]:
	return regular_offer_from(offer_key(slot, aisle_id))


func stage_name() -> String:
	return STAGE_NAMES[stage]


func to_dictionary() -> Dictionary:
	var saved_baskets: Array[Dictionary] = []
	for basket: StartBasket in baskets:
		saved_baskets.append(basket.to_dictionary())
	var offers: Dictionary = {}
	for key: String in regular_offers:
		offers[key] = _ids(regular_offer_from(key))
	return {
		"stage": stage_name(),
		"stock_aisles": Array(stock_aisles),
		"completed_count": completed_count,
		"originals": _ids(originals),
		"baskets": saved_baskets,
		"restock_basket": restock_basket,
		"regular_offers": offers,
		"packs_redrawn": packs_redrawn,
		"picked": String(picked),
	}


## The saved offer under regular_offers key `key` (empty when missing).
func regular_offer_from(key: String) -> Array[CardDefinition]:
	var offer: Array[CardDefinition] = []
	offer.assign(regular_offers.get(key, []))
	return offer


## A copy holding the same choices (a caller's snapshot for rolling a failed save back).
func copy() -> StartSetup:
	var other: StartSetup = StartSetup.new()
	other.stage = stage
	other.stock_aisles = stock_aisles.duplicate()
	other.completed_count = completed_count
	other.originals = originals.duplicate()
	for basket: StartBasket in baskets:
		other.baskets.append(basket.copy())
	other.restock_basket = restock_basket
	for key: String in regular_offers:
		other.regular_offers[key] = regular_offer_from(key)
	other.packs_redrawn = packs_redrawn
	other.picked = picked
	return other


## Whether `data` is a setup saved in the first build's form (before the 2026-11-05 rework).
static func is_old_format(data: Dictionary) -> bool:
	return not data.has("stage")


## The setup `data` holds, or null when it is damaged or in the old format (is_old_format).
static func from_dictionary(data: Dictionary, lookup: ContentLookup) -> StartSetup:
	if is_old_format(data):
		return null
	var balance: BalanceDefinition = lookup.balance
	var reader: SaveReader = SaveReader.new(data, lookup)
	var setup: StartSetup = StartSetup.new()
	var stage_index: int = STAGE_NAMES.find(reader.text("stage"))
	setup.stage = stage_index as Stage
	setup.stock_aisles = reader.aisles("stock_aisles")
	setup.completed_count = reader.whole("completed_count")
	setup.originals = reader.cards("originals")
	setup.restock_basket = reader.whole("restock_basket", -1)
	setup.packs_redrawn = reader.flag("packs_redrawn")
	setup.picked = StringName(reader.text("picked"))
	for saved: Dictionary in reader.dictionaries("baskets"):
		var basket_reader: SaveReader = SaveReader.new(saved, lookup)
		var basket: StartBasket = StartBasket.new(
			StringName(basket_reader.text("source")), basket_reader.cards("cards")
		)
		reader.ok = reader.ok and basket_reader.ok
		setup.baskets.append(basket)
	var offers: Variant = data.get("regular_offers")
	if not offers is Dictionary:
		return null
	var offers_reader: SaveReader = SaveReader.new(offers as Dictionary, lookup)
	for key: Variant in (offers as Dictionary).keys():
		if not key is String:
			return null
		setup.regular_offers[key as String] = offers_reader.cards(key as String)
	if not reader.ok or not offers_reader.ok or stage_index == -1:
		return null
	return setup if setup._is_valid(balance) else null


func _is_valid(balance: BalanceDefinition) -> bool:
	var size: int = mini(balance.stock_aisle_count, balance.aisles.size())
	var valid: bool = stock_aisles.size() == size and _distinct(stock_aisles)
	valid = valid and completed_count <= balance.aisles.size()
	valid = valid and restock_basket >= -1 and restock_basket < baskets.size()
	valid = valid and (restock_basket < 0 or completed_count >= balance.restock_min_completed)
	return valid and _baskets_valid(balance) and _offers_valid(balance)


## The baskets: the Staples basket, then one per green aisle in order, each holding at most
## start_basket_size cards of its source; all empty in SELECT, with nothing spent or picked.
func _baskets_valid(balance: BalanceDefinition) -> bool:
	var green: Array[StringName] = green_ids(balance)
	if baskets.size() != 1 + green.size() or baskets[0].source != STAPLES:
		return false
	for index: int in green.size():
		if baskets[index + 1].source != green[index]:
			return false
	if stage == Stage.SELECT:
		if restock_basket != -1 or packs_redrawn or picked != &"" or not shared().is_empty():
			return false
	for basket: StartBasket in baskets:
		if basket.cards.size() > balance.start_basket_size:
			return false
		for card: CardDefinition in basket.cards:
			if not _from_source(balance, basket.source, card) or basket.cards.count(card) != 1:
				return false
	return true


func _offers_valid(balance: BalanceDefinition) -> bool:
	for key: String in regular_offers:
		var parts: PackedStringArray = key.split(":")
		if parts.size() != 2 or not parts[0].is_valid_int():
			return false
		var slot: int = parts[0].to_int()
		if slot < 0 or slot >= originals.size():
			return false
		var aisle: AisleDefinition = null
		for candidate: AisleDefinition in balance.aisles:
			if String(candidate.id) == parts[1]:
				aisle = candidate
		var offer: Array[CardDefinition] = regular_offer_from(key)
		if aisle == null or offer.size() > balance.regular_offer_max:
			return false
		for card: CardDefinition in offer:
			if offer.count(card) != 1:
				return false
			if not aisle.base_cards.has(card) and not aisle.capsule_cards.has(card):
				return false
	return true


## Whether `card` belongs to basket source `source` (the staples shelf or that aisle).
static func _from_source(
	balance: BalanceDefinition, source: StringName, card: CardDefinition
) -> bool:
	if source == STAPLES:
		return balance.staples.has(card)
	var aisle: AisleDefinition = balance.aisle_of(card)
	return aisle != null and aisle.id == source


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
