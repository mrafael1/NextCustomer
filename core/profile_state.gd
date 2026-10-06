class_name ProfileState
extends RefCounted
## The meta progress (full build plan section 4 holds the one field list), saved separately
## from the run by SaveService. record_run takes only a run that ended (won or lost): a run
## restarted before its end records nothing (decided with the user, phase 1). Other fields
## (first-seen flags, settings, the list) change when their own feature does.
##
## to_dictionary and from_dictionary give the saved form: JSON types only, with
## FORMAT_VERSION. Pure: no file access here.

## The profile save's format version, written from the first save. Raise it when the saved
## form changes, and read the older versions in from_dictionary.
const FORMAT_VERSION := 1

## Coins from final receipts (full build plan 7.1); 1 coin = 1 capsule.
var coins: int = 0
## Runs that ended (won or lost). The run being built has this run index (RunStock).
var run_count: int = 0
## Unlocked capsule items: id -> the run index at whose exit it came out, in draw order
## (RunStock's `unlocked`).
var unlocked_items: Dictionary[StringName, int] = {}
## The last shopping list (aisle ids), the next list's default (full build plan 7.2).
var last_list: Array[StringName] = []
## Decks and card variants unlocked by their condition (plan 7.3). One without a condition is
## available from the start and never listed here.
var unlocked_decks: Array[StringName] = []
var unlocked_variants: Array[StringName] = []
## Coupon uses in ended runs, by card id (USE_COUPON_TIMES unlocks: UnlockCheck's
## earlier_uses).
var coupon_uses: Dictionary[StringName, int] = {}
## Long animations already seen once (first-seen flags), by id.
var seen: Array[StringName] = []
## Unlocked achievements by id; their content comes later.
var achievements: Array[StringName] = []
## Lifetime numbers by name; their content comes later.
var stats: Dictionary[StringName, int] = {}
## Player settings by name, JSON values only; their content comes later.
var settings: Dictionary = {}


## Whether the deck can be chosen: no unlock condition, or unlocked.
func has_deck(deck: DeckDefinition) -> bool:
	return deck.unlock_condition == null or unlocked_decks.has(deck.id)


## Whether the card variant is available: no unlock condition, or unlocked.
func has_variant(variant: CardDefinition) -> bool:
	return variant.unlock_condition == null or unlocked_variants.has(variant.id)


## Records a run that ended (won or lost; anything else is ignored and returns nothing):
## checks every locked deck's and variant's condition with the coupon uses from before this
## run, then adds this run's coupon uses and counts the run. Returns the ids unlocked now,
## decks first, each in catalogue order.
func record_run(run: RunState, catalogue: CatalogueDefinition) -> Array[StringName]:
	var unlocked_now: Array[StringName] = []
	if run.phase != RunState.Phase.WON and run.phase != RunState.Phase.LOST:
		return unlocked_now
	for deck: DeckDefinition in catalogue.decks:
		if not has_deck(deck) and UnlockCheck.is_met(deck.unlock_condition, run, coupon_uses):
			unlocked_decks.append(deck.id)
			unlocked_now.append(deck.id)
	for variant: CardDefinition in catalogue.variants:
		if (
			not has_variant(variant)
			and UnlockCheck.is_met(variant.unlock_condition, run, coupon_uses)
		):
			unlocked_variants.append(variant.id)
			unlocked_now.append(variant.id)
	var uses: Dictionary[StringName, int] = UnlockCheck.coupon_uses(run.history)
	for id: StringName in uses:
		coupon_uses[id] = coupon_uses.get(id, 0) + uses[id]
	run_count += 1
	return unlocked_now


## The saved form. Unlocked items are [id, run index] pairs, so their draw order survives any
## JSON writer that sorts keys.
func to_dictionary() -> Dictionary:
	var items: Array = []
	for id: StringName in unlocked_items:
		items.append([String(id), unlocked_items[id]])
	return {
		"format_version": FORMAT_VERSION,
		"coins": coins,
		"run_count": run_count,
		"unlocked_items": items,
		"last_list": _strings(last_list),
		"unlocked_decks": _strings(unlocked_decks),
		"unlocked_variants": _strings(unlocked_variants),
		"coupon_uses": _string_keys(coupon_uses),
		"seen": _strings(seen),
		"achievements": _strings(achievements),
		"stats": _string_keys(stats),
		"settings": settings.duplicate(true),
	}


## Reads the saved form (as parsed from JSON: numbers may be floats). Returns null when it
## isn't a profile this version can read: a missing or newer format version, or a field of
## the wrong type. Unknown fields are ignored; missing fields keep their defaults.
static func from_dictionary(data: Dictionary) -> ProfileState:
	var version: Variant = data.get("format_version")
	if not _is_whole(version) or int(version) < 1 or int(version) > FORMAT_VERSION:
		return null
	var profile: ProfileState = ProfileState.new()
	var ok: bool = true
	ok = ok and _read_int(data, "coins", profile, "coins")
	ok = ok and _read_int(data, "run_count", profile, "run_count")
	ok = ok and _read_items(data.get("unlocked_items", []), profile.unlocked_items)
	ok = ok and _read_names(data.get("last_list", []), profile.last_list)
	ok = ok and _read_names(data.get("unlocked_decks", []), profile.unlocked_decks)
	ok = ok and _read_names(data.get("unlocked_variants", []), profile.unlocked_variants)
	ok = ok and _read_counts(data.get("coupon_uses", {}), profile.coupon_uses)
	ok = ok and _read_names(data.get("seen", []), profile.seen)
	ok = ok and _read_names(data.get("achievements", []), profile.achievements)
	ok = ok and _read_counts(data.get("stats", {}), profile.stats)
	var settings_value: Variant = data.get("settings", {})
	if not settings_value is Dictionary:
		return null
	profile.settings = (settings_value as Dictionary).duplicate(true)
	return profile if ok else null


static func _read_int(data: Dictionary, key: String, profile: ProfileState, field: String) -> bool:
	var value: Variant = data.get(key, 0)
	if not _is_whole(value) or int(value) < 0:
		return false
	profile.set(field, int(value))
	return true


static func _read_items(value: Variant, into: Dictionary[StringName, int]) -> bool:
	if not value is Array:
		return false
	for pair: Variant in value:
		if not pair is Array or (pair as Array).size() != 2:
			return false
		var id: Variant = pair[0]
		var run_index: Variant = pair[1]
		if not id is String or not _is_whole(run_index) or int(run_index) < 0:
			return false
		into[StringName(id)] = int(run_index)
	return true


static func _read_names(value: Variant, into: Array[StringName]) -> bool:
	if not value is Array:
		return false
	for id: Variant in value:
		if not id is String:
			return false
		into.append(StringName(id))
	return true


static func _read_counts(value: Variant, into: Dictionary[StringName, int]) -> bool:
	if not value is Dictionary:
		return false
	for key: Variant in value:
		var count: Variant = value[key]
		if not key is String or not _is_whole(count) or int(count) < 0:
			return false
		into[StringName(key)] = int(count)
	return true


## JSON parses every number as a float: whole numbers are accepted as ints.
static func _is_whole(value: Variant) -> bool:
	if value is int:
		return true
	return value is float and is_finite(value) and value == floorf(value)


static func _strings(ids: Array[StringName]) -> Array:
	var found: Array = []
	for id: StringName in ids:
		found.append(String(id))
	return found


static func _string_keys(counts: Dictionary[StringName, int]) -> Dictionary:
	var found: Dictionary = {}
	for id: StringName in counts:
		found[String(id)] = counts[id]
	return found
