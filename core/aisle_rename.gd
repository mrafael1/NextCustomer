class_name AisleRename
extends RefCounted
## The aisle ids that changed (v1.40: the Cold cases aisle became the Dairy aisle, and Frozen
## peas moved to Fruit & veg as a capsule item): a save from before reads with its old ids
## renamed (RunSave before version 18, ProfileState before version 8). Pure: plain data only.

## Old aisle id -> the id it has now.
const RENAMED: Dictionary[String, String] = {"cold_cases": "dairy"}
## The products that left an aisle's base cards for another aisle's capsule machine: an older
## profile owned them from the start, so it reads with them unlocked.
const MOVED_TO_CAPSULES: Array[StringName] = [&"frozen_peas"]


## `id` under its name of today.
static func id_now(id: String) -> String:
	return RENAMED.get(id, id)


## A deep copy of `value` (JSON types) with every string that is an old aisle id, as a value or
## as a dictionary key, renamed. No card, pack, deck, pin or upgrade id is an old aisle id, so
## only aisle ids change.
static func renamed(value: Variant) -> Variant:
	if value is String:
		return id_now(value as String)
	if value is Array:
		var items: Array = []
		for item: Variant in value as Array:
			items.append(renamed(item))
		return items
	if value is Dictionary:
		var entries: Dictionary = {}
		var source: Dictionary = value
		for key: Variant in source:
			var new_key: Variant = id_now(key as String) if key is String else key
			entries[new_key] = renamed(source[key])
		return entries
	return value
