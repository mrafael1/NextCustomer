class_name SaveReader
extends RefCounted
## Reads a save's fields (full build plan section 4) as parsed from JSON, where every number is
## a float: a whole number is read as an int. A field that is missing or of the wrong type, or
## an id that doesn't resolve through the ContentLookup, clears `ok` and reads as a neutral
## value, so a caller reads every field, then checks `ok` once. Nothing is ever printed.
##
## 64-bit numbers (a seed, an RNG state) are saved as decimal strings and read with int64:
## JSON numbers are doubles and lose precision above 2^53.

## The largest whole number a JSON number (a double) holds exactly: 2^53.
const MAX_EXACT := 9007199254740992
## The digits of the largest and smallest 64-bit ints (without the minus sign).
const INT64_MAX_DIGITS := "9223372036854775807"
const INT64_MIN_DIGITS := "9223372036854775808"

## False once any field couldn't be read.
var ok: bool = true
var _data: Dictionary
var _lookup: ContentLookup


func _init(data: Dictionary, lookup: ContentLookup) -> void:
	_data = data
	_lookup = lookup


## A whole number that JSON holds exactly: an int, or a float with no fraction.
static func is_whole(value: Variant) -> bool:
	if value is int:
		return true
	return (
		value is float and is_finite(value) and value == floorf(value) and absf(value) <= MAX_EXACT
	)


## A decimal 64-bit int: an optional minus sign and up to 19 digits, within the int range.
static func is_int64_text(number: String) -> bool:
	var digits: String = number.trim_prefix("-")
	if digits.is_empty() or digits.length() > INT64_MAX_DIGITS.length():
		return false
	for character: String in digits:
		if character < "0" or character > "9":
			return false
	if digits.length() < INT64_MAX_DIGITS.length():
		return true
	# Same length: comparing the digits as text compares the numbers.
	return digits <= (INT64_MIN_DIGITS if number.begins_with("-") else INT64_MAX_DIGITS)


## A whole number of at least `minimum`.
func whole(key: String, minimum: int = 0) -> int:
	var value: Variant = _data.get(key)
	if not is_whole(value) or int(value) < minimum:
		ok = false
		return 0
	return int(value)


## A 64-bit int saved as a decimal string.
func int64(key: String) -> int:
	var value: Variant = _data.get(key)
	if not value is String or not is_int64_text(value):
		ok = false
		return 0
	return (value as String).to_int()


func flag(key: String) -> bool:
	var value: Variant = _data.get(key)
	if not value is bool:
		ok = false
		return false
	return value


func text(key: String) -> String:
	var value: Variant = _data.get(key)
	if not value is String:
		ok = false
		return ""
	return value


## A list of whole numbers, each at least `minimum`.
func wholes(key: String, minimum: int = 0) -> Array[int]:
	var found: Array[int] = []
	for value: Variant in _array(key):
		if is_whole(value) and int(value) >= minimum:
			found.append(int(value))
		else:
			ok = false
	return found


## Card copies saved as [instance id, card id] pairs; instance ids start at 1.
func instances(key: String) -> Array[CardInstance]:
	var found: Array[CardInstance] = []
	for pair: Variant in _array(key):
		if not pair is Array or (pair as Array).size() != 2:
			ok = false
			continue
		var instance_id: Variant = pair[0]
		var card_id: Variant = pair[1]
		var definition: CardDefinition = null
		if card_id is String:
			definition = _lookup.card(card_id)
		if not is_whole(instance_id) or int(instance_id) < 1 or definition == null:
			ok = false
			continue
		found.append(CardInstance.new(definition, int(instance_id)))
	return found


## Card ids, each resolved.
func cards(key: String) -> Array[CardDefinition]:
	var found: Array[CardDefinition] = []
	found.assign(_resolve_all(key, _lookup.card))
	return found


## One card id, or "" for none.
func card(key: String) -> CardDefinition:
	return _resolve_optional(key, _lookup.card) as CardDefinition


func upgrades(key: String) -> Array[UpgradeDefinition]:
	var found: Array[UpgradeDefinition] = []
	found.assign(_resolve_all(key, _lookup.upgrade))
	return found


## One upgrade id, or "" for none.
func upgrade(key: String) -> UpgradeDefinition:
	return _resolve_optional(key, _lookup.upgrade) as UpgradeDefinition


func inspections(key: String) -> Array[InspectionDefinition]:
	var found: Array[InspectionDefinition] = []
	found.assign(_resolve_all(key, _lookup.inspection))
	return found


## One inspection id, or "" for none.
func inspection(key: String) -> InspectionDefinition:
	return _resolve_optional(key, _lookup.inspection) as InspectionDefinition


## A starting deck's id (required).
func deck(key: String) -> DeckDefinition:
	var found: DeckDefinition = _resolve_optional(key, _lookup.deck) as DeckDefinition
	if found == null:
		ok = false
	return found


## Aisle ids, each one of the balance's aisles.
func aisles(key: String) -> Array[StringName]:
	var found: Array[StringName] = []
	for id: String in _strings(key):
		if _lookup.aisle(id) == null:
			ok = false
		else:
			found.append(StringName(id))
	return found


## A list of JSON objects (e.g. the history's records).
func dictionaries(key: String) -> Array[Dictionary]:
	var found: Array[Dictionary] = []
	for value: Variant in _array(key):
		if value is Dictionary:
			found.append(value)
		else:
			ok = false
	return found


func _array(key: String) -> Array:
	var value: Variant = _data.get(key)
	if not value is Array:
		ok = false
		return []
	return value


func _strings(key: String) -> Array[String]:
	var found: Array[String] = []
	for value: Variant in _array(key):
		if value is String:
			found.append(value)
		else:
			ok = false
	return found


## Every id in the list, resolved with `resolve` (an id -> Resource lookup method).
func _resolve_all(key: String, resolve: Callable) -> Array:
	var found: Array = []
	for id: String in _strings(key):
		var resource: Resource = resolve.call(id)
		if resource == null:
			ok = false
		else:
			found.append(resource)
	return found


## The resource named by the field's id, or null for "" (none).
func _resolve_optional(key: String, resolve: Callable) -> Resource:
	var id: String = text(key)
	if id.is_empty():
		return null
	var resource: Resource = resolve.call(id)
	if resource == null:
		ok = false
	return resource
