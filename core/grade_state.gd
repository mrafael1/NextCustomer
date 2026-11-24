class_name GradeState
extends RefCounted
## A graded run's twist state (#182, v1.49; GradeRules plays the rules): the products shrunk by
## Shrinkflation, the cards that expire and when, the products taken this week (the BEST BEFORE
## candidates), the Picky regular's family per shift, and the news the current shift opens with.
## Saved with the run (RunSave v21, `grade_state`, only when not empty; v23 adds the promo cuts).
## Pure data.

## Shrinkflation: product id (a plain card's) to the euros it lost.
var shrinks: Dictionary[StringName, int] = {}
## Expiry dates: instance id to the last 1-based shift the card plays (it leaves as the next one
## starts). Coupons get one as they are taken, BEST BEFORE products at their week's end.
var expiry: Dictionary[int, int] = {}
## The products taken from the machine this week: instance id to the 1-based shift after whose
## checkout it was taken. The week's end picks its BEST BEFORE ones among them, then empties it.
var week_added: Dictionary[int, int] = {}
## The Picky regular: 1-based shift to the family out of favour.
var picky: Dictionary[int, String] = {}
## The Picky regular's cut per 1-based shift, in percent (v1.49 play test: drawn with the family).
var promo_cuts: Dictionary[int, int] = {}
## What changed as `news_shift` (1-based) opened: one short line each ("Shrinkflation: Bread
## -1€", "Expired: 2 for 1"), for its opening notice and the run log.
var news: PackedStringArray = PackedStringArray()
var news_shift: int = 0
## What `news_shift` just changed, for the shift screen's stamps (GradeMoves, v1.49 play test):
## the products shrunk, the cards dated (instance ids) and the cards that expired. Never saved, so
## a resumed save never plays them again; the screen empties them once played (clear_fresh).
var fresh_shrunk: Array[StringName] = []
var fresh_dated: Array[int] = []
var fresh_expired: Array[CardDefinition] = []
## Whether `news_shift` just opened on a run with the Picky regular: its promo tags stamp on.
var fresh_promo: bool = false
## The run's copies of the twists' events (GradeRules), rebuilt when the state changes; the
## Picky regular's keyed by family and cut ("Dairy|25").
var shrink_event: InspectionDefinition
var picky_events: Dictionary[String, InspectionDefinition] = {}


func is_empty() -> bool:
	return (
		shrinks.is_empty()
		and expiry.is_empty()
		and week_added.is_empty()
		and picky.is_empty()
		and promo_cuts.is_empty()
		and news.is_empty()
	)


## Whether a shift start left changes to show (see fresh_shrunk).
func has_fresh() -> bool:
	return (
		fresh_promo
		or not (fresh_shrunk.is_empty() and fresh_dated.is_empty() and fresh_expired.is_empty())
	)


## Forgets the changes to show (played, or a new shift starts).
func clear_fresh() -> void:
	fresh_shrunk = []
	fresh_dated = []
	fresh_expired = []
	fresh_promo = false


## The saved form: JSON types only (keys as text).
func to_dictionary() -> Dictionary:
	var shrunk: Dictionary = {}
	for id: StringName in shrinks:
		shrunk[String(id)] = shrinks[id]
	var families: Dictionary = {}
	for shift: int in picky:
		families[str(shift)] = picky[shift]
	return {
		"shrinks": shrunk,
		"expiry": _text_keys(expiry),
		"week_added": _text_keys(week_added),
		"picky": families,
		"promo_cuts": _text_keys(promo_cuts),
		"news": Array(news),
		"news_shift": news_shift,
	}


## The state `data` holds (to_dictionary's form, as parsed from JSON), or null when it is
## malformed. A missing field reads empty. With `fixed_cut` (a save from before v23's random cuts,
## RunSave) every Picky regular day it names reads at that cut.
static func from_data(data: Variant, fixed_cut: int = -1) -> GradeState:
	if not data is Dictionary:
		return null
	var saved: Dictionary = data
	var state: GradeState = GradeState.new()
	var shrunk: Variant = saved.get("shrinks", {})
	var expires: Variant = saved.get("expiry", {})
	var families: Variant = saved.get("picky", {})
	if not shrunk is Dictionary or not expires is Dictionary or not families is Dictionary:
		return null
	for key: Variant in shrunk as Dictionary:
		var euros: Variant = (shrunk as Dictionary)[key]
		if not key is String or not SaveReader.is_whole(euros) or int(euros) < 0:
			return null
		state.shrinks[StringName(key as String)] = int(euros)
	if not _read_wholes(expires as Dictionary, state.expiry):
		return null
	for key: Variant in families as Dictionary:
		var family: Variant = (families as Dictionary)[key]
		if not key is String or not (key as String).is_valid_int() or not family is String:
			return null
		state.picky[(key as String).to_int()] = family as String
	var cuts: Variant = saved.get("promo_cuts", {})
	if not cuts is Dictionary or not _read_wholes(cuts as Dictionary, state.promo_cuts):
		return null
	for shift: int in state.promo_cuts:
		if state.promo_cuts[shift] < 0 or state.promo_cuts[shift] > 100:
			return null
	if fixed_cut >= 0:
		for shift: int in state.picky:
			state.promo_cuts[shift] = fixed_cut
	var added: Variant = saved.get("week_added", {})
	var lines: Variant = saved.get("news", [])
	var shift: Variant = saved.get("news_shift", 0)
	if not added is Dictionary or not lines is Array or not SaveReader.is_whole(shift):
		return null
	if not _read_wholes(added as Dictionary, state.week_added):
		return null
	for line: Variant in lines as Array:
		if not line is String:
			return null
		state.news.append(line as String)
	state.news_shift = int(shift)
	return state


## Drops the run's event copies (the shrinks or a family changed).
func clear_events() -> void:
	shrink_event = null
	picky_events = {}


## `numbers` with its keys as text (JSON's keys).
static func _text_keys(numbers: Dictionary[int, int]) -> Dictionary:
	var keyed: Dictionary = {}
	for key: int in numbers:
		keyed[str(key)] = numbers[key]
	return keyed


## Reads `data`'s whole numbers keyed by whole numbers as text into `into`; false when malformed.
static func _read_wholes(data: Dictionary, into: Dictionary[int, int]) -> bool:
	for key: Variant in data:
		var value: Variant = data[key]
		if (
			not key is String
			or not (key as String).is_valid_int()
			or not SaveReader.is_whole(value)
		):
			return false
		into[(key as String).to_int()] = int(value)
	return true
