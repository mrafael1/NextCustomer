class_name ProfileState
extends RefCounted
## The meta progress (full build plan section 4 holds the one field list), saved separately
## from the run by SaveService. record_run takes only a run that ended (won or lost): a run
## restarted before its end records nothing (decided with the user, phase 1). Other fields
## (first-seen flags, settings, the list) change when their own feature does.
##
## The TOY MACHINES (#63, full build plan 7.1) spend coins here: draw_capsule takes the price,
## records the item with its run index (capsule_run_index) and counts the draw. Each draw uses
## its own derived stream of capsule_seed (EventLogService.capsule_stream(capsule_seed,
## capsule_draws)); the seed is made outside core/ and set once with set_capsule_seed, and the
## caller saves the profile right after each draw, so quitting can't reroll a capsule.
##
## Badge pins (#122, full build plan 7.4): a pin is owned when it has no unlock condition or its
## milestone was met (record_run), or when it was bought at random (ProfilePins.buy_random, on
## its own derived stream of capsule_seed, PIN_STREAM). The worn pins (`worn_pins`, at most the
## balance's pin_slots, ProfilePins) are copied into a run when it starts; changing them never
## touches a run.
##
## to_dictionary and from_dictionary give the saved form: JSON types only, with
## FORMAT_VERSION. Pure: no file access here.

## The profile save's format version, written from the first save. Raise it when the saved
## form changes, and read the older versions in from_dictionary. 2 since #63 (capsule_seed and
## capsule_draws); version 1 saves still read, with no seed and 0 draws. 3 since #122
## (unlocked_pins and worn_pins); version 2 saves still read, with no pin unlocked or worn.
const FORMAT_VERSION := 3
## The settings key of the count-up's speed (full build plan 6.2): COUNT_UP_NORMAL or
## COUNT_UP_FAST, read with count_up_speed().
const COUNT_UP_SPEED_KEY := "count_up_speed"
## The settings key of reduced motion (no shakes; full build plan 6.2), read with
## reduced_motion().
const REDUCED_MOTION_KEY := "reduced_motion"
## The count-up speed setting's two values: Normal and Fast.
const COUNT_UP_NORMAL := 1.0
const COUNT_UP_FAST := 1.5
## The stats key of the runs won (#107).
const RUNS_WON := &"runs_won"
## The derived stream name of a random pin purchase (#122), with the purchase's index:
## EventLogService.derived_stream(capsule_seed, PIN_STREAM % pins_bought).
const PIN_STREAM := "pin_%d"

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
## Badge pins unlocked by their milestone or bought (#122), in unlock order. One without a
## condition is owned from the start and never listed here.
var unlocked_pins: Array[StringName] = []
## The pins worn on the badge (#122), at most the balance's pin_slots, in slot order.
var worn_pins: Array[StringName] = []
## Random pins bought with coins (#122): the next purchase's stream index.
var pins_bought: int = 0
## Coupon uses in ended runs, by card id (USE_COUPON_TIMES unlocks: UnlockCheck's
## earlier_uses).
var coupon_uses: Dictionary[StringName, int] = {}
## Long animations already seen once (first-seen flags), by id.
var seen: Array[StringName] = []
## Unlocked achievements by id; their content comes later.
var achievements: Array[StringName] = []
## Lifetime numbers by name; their content comes later, but for RUNS_WON (#107).
var stats: Dictionary[StringName, int] = {}
## The seed of the capsule draws' streams (#63), made outside core/ and set once
## (set_capsule_seed); saved as a decimal string, "" while there is none (has_capsule_seed).
var capsule_seed: int = 0
var has_capsule_seed: bool = false
## Capsule draws made with capsule_seed: the next draw's stream index. Set to the unlocked
## item count when the seed is set, so an older profile's draws never repeat a stream.
var capsule_draws: int = 0
## Player settings by name, JSON values only. Read and change the known ones with their
## accessors (count_up_speed, reduced_motion), which tolerate a missing or wrong-typed value.
var settings: Dictionary = {}


## Whether the deck can be chosen: no unlock condition, or unlocked.
func has_deck(deck: DeckDefinition) -> bool:
	return deck.unlock_condition == null or unlocked_decks.has(deck.id)


## Whether the card variant is available: no unlock condition, or unlocked.
func has_variant(variant: CardDefinition) -> bool:
	return variant.unlock_condition == null or unlocked_variants.has(variant.id)


## Whether the badge pin is owned: no unlock condition, or unlocked (#122).
func has_pin(pin: PinDefinition) -> bool:
	return pin.unlock_condition == null or unlocked_pins.has(pin.id)


## The count-up speed setting: COUNT_UP_FAST when set so, else COUNT_UP_NORMAL (also for a
## missing, wrong-typed or unknown value, such as an old save's).
func count_up_speed() -> float:
	var value: Variant = settings.get(COUNT_UP_SPEED_KEY)
	if value is float and value == COUNT_UP_FAST:
		return COUNT_UP_FAST
	return COUNT_UP_NORMAL


## Sets the count-up speed setting. A speed other than COUNT_UP_FAST is stored as
## COUNT_UP_NORMAL.
func set_count_up_speed(speed: float) -> void:
	settings[COUNT_UP_SPEED_KEY] = COUNT_UP_FAST if speed == COUNT_UP_FAST else COUNT_UP_NORMAL


## The reduced motion setting: off unless set to true (a missing or wrong-typed value, such as
## an old save's, is off).
func reduced_motion() -> bool:
	var value: Variant = settings.get(REDUCED_MOTION_KEY)
	return value is bool and value


func set_reduced_motion(on: bool) -> void:
	settings[REDUCED_MOTION_KEY] = on


## Records a run that ended (won or lost; anything else is ignored and returns nothing):
## checks every locked deck's, variant's and badge pin's condition with the coupon uses and wins
## from before this run, then adds the run's coins (CoinPayout) and coupon uses and counts the
## run. Returns the ids unlocked now, decks first, then variants and pins, each in catalogue
## order.
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
	var wins: int = int(stats.get(RUNS_WON, 0))
	for pin: PinDefinition in catalogue.pins:
		if not has_pin(pin) and UnlockCheck.is_met(pin.unlock_condition, run, coupon_uses, wins):
			unlocked_pins.append(pin.id)
			unlocked_now.append(pin.id)
	coins += CoinPayout.for_run(run).total()
	var uses: Dictionary[StringName, int] = UnlockCheck.coupon_uses(run.history)
	for id: StringName in uses:
		coupon_uses[id] = coupon_uses.get(id, 0) + uses[id]
	if run.phase == RunState.Phase.WON:
		stats[RUNS_WON] = int(stats.get(RUNS_WON, 0)) + 1
	run_count += 1
	return unlocked_now


## Whether a run of this profile was ever won (#107: until then, the starter pack offer raises its
## good first pick).
func has_won() -> bool:
	return int(stats.get(RUNS_WON, 0)) > 0


## Sets the capsule seed if the profile has none yet, and the draw count to the unlocked item
## count. Returns false (and changes nothing) when a seed is already set: it is never replaced.
func set_capsule_seed(seed_value: int) -> bool:
	if has_capsule_seed:
		return false
	capsule_seed = seed_value
	has_capsule_seed = true
	capsule_draws = unlocked_items.size()
	return true


## The run index a capsule drawn now comes out at (RunStock's `unlocked`, full build plan 7.1):
## the run that just ended (run_count - 1) on the results or on the title with no saved run, or
## the saved run's own index (run_count) on the title while a run is saved (#63 default (a): the
## item rides the runs after the saved one). -1 before any run has ended (debug coins only).
func capsule_run_index(has_saved_run: bool) -> int:
	return run_count if has_saved_run else run_count - 1


## Whether a capsule can be drawn from the aisle's machine: enough coins and items left.
func can_draw(aisle: AisleDefinition, price: int) -> bool:
	return coins >= price and not CapsuleDraw.is_empty(aisle, unlocked_items)


## Draws one capsule from the aisle's machine (CapsuleDraw) with `rng`, the caller's stream for
## this draw (capsule_draws' stream): spends `price` coins, records the item at `run_index`
## (appended, so draw order is kept) and counts the draw. Null, with nothing changed, when
## can_draw is false.
func draw_capsule(
	aisle: AisleDefinition, price: int, run_index: int, rng: RandomNumberGenerator
) -> CardDefinition:
	if not can_draw(aisle, price):
		return null
	var card: CardDefinition = CapsuleDraw.draw(aisle, unlocked_items, rng)
	coins -= price
	unlocked_items[card.id] = run_index
	capsule_draws += 1
	return card


## Takes back a draw whose save failed: the item locked again, and the coins and the draw count
## as they were before it (`previous_draws`).
func undo_capsule(card: CardDefinition, price: int, previous_draws: int) -> void:
	if unlocked_items.erase(card.id):
		coins += price
	capsule_draws = previous_draws


## The unlocked items that are capsule items of the balance's aisles (the FIGURINES count).
func owned_capsules(balance: BalanceDefinition) -> int:
	var owned: int = 0
	for aisle: AisleDefinition in balance.aisles:
		for card: CardDefinition in aisle.capsule_cards:
			if unlocked_items.has(card.id):
				owned += 1
	return owned


## Debug only: unlocks every capsule item still locked at `run_index`, in data order, counting
## a draw for each (so later draws' streams stay new).
func unlock_all_capsules(balance: BalanceDefinition, run_index: int) -> void:
	for aisle: AisleDefinition in balance.aisles:
		for card: CardDefinition in aisle.capsule_cards:
			if not unlocked_items.has(card.id):
				unlocked_items[card.id] = run_index
				capsule_draws += 1


## Debug only: locks every item again and clears the list. The seed is kept and the draw count
## restarts at 0, so the same draws come out again.
func reset_collection() -> void:
	unlocked_items.clear()
	capsule_draws = 0
	last_list.clear()


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
		"capsule_seed": str(capsule_seed) if has_capsule_seed else "",
		"capsule_draws": capsule_draws,
		"unlocked_pins": _strings(unlocked_pins),
		"worn_pins": _strings(worn_pins),
		"pins_bought": pins_bought,
	}


## Reads the saved form (as parsed from JSON: numbers may be floats). Returns null when it
## isn't a profile this version can read: a missing or newer format version, or a field of
## the wrong type (a capsule seed that isn't "" or a decimal of 0 or more). Version 1 reads
## with no capsule seed and 0 draws, version 2 with no pins. Unknown fields are ignored;
## missing fields keep their defaults.
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
	ok = ok and _read_int(data, "capsule_draws", profile, "capsule_draws")
	ok = ok and _read_seed(data.get("capsule_seed", ""), profile)
	ok = ok and _read_names(data.get("unlocked_pins", []), profile.unlocked_pins)
	ok = ok and _read_names(data.get("worn_pins", []), profile.worn_pins)
	ok = ok and _read_int(data, "pins_bought", profile, "pins_bought")
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


## The capsule seed's saved form: "" (none yet) or a decimal of 0 or more.
static func _read_seed(value: Variant, profile: ProfileState) -> bool:
	if not value is String:
		return false
	var text: String = value
	if text.is_empty():
		return true
	if not text.is_valid_int() or text.to_int() < 0:
		return false
	profile.capsule_seed = text.to_int()
	profile.has_capsule_seed = true
	return true


## A run index of -1 is a capsule drawn before any run ended (capsule_run_index).
static func _read_items(value: Variant, into: Dictionary[StringName, int]) -> bool:
	if not value is Array:
		return false
	for pair: Variant in value:
		if not pair is Array or (pair as Array).size() != 2:
			return false
		var id: Variant = pair[0]
		var run_index: Variant = pair[1]
		if not id is String or not _is_whole(run_index) or int(run_index) < -1:
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
