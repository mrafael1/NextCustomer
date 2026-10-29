class_name ContentLookup
extends RefCounted
## Resolves the ids a save holds (full build plan section 4) to the content they name: cards,
## upgrades, inspections and starting decks by file (<root>/<folder>/<id>.tres), aisles from
## the balance. An id resolves only to a resource of the right type whose own id equals it (a
## data test checks that every file's id equals its file name), so a renamed or removed file
## makes a save unreadable instead of loading the wrong thing. Nothing here prints an error:
## a file is checked with ResourceLoader.exists before it is loaded, and an id that isn't a
## plain name (empty, or a path such as "../balance/balance") is never looked up.
##
## A retired id (content removed from data/ by a rule change, RETIRED_UPGRADES and
## RETIRED_INSPECTIONS) resolves to an inert stand-in with that id and name and no effect, so a
## save or a log made before the change still reads; RunSave drops retired registers from the
## run (is_retired).
##
## Tests point `root` at a folder of their own, or add in-memory resources with add().

const DATA_ROOT := "res://data"
const CARDS_FOLDER := "cards"
const UPGRADES_FOLDER := "upgrades"
const INSPECTIONS_FOLDER := "inspections"
const DECKS_FOLDER := "decks"
## Upgrades removed from data/, by id: their names (plan v0.46, #106: every slot is general).
const RETIRED_UPGRADES: Dictionary[StringName, String] = {
	&"extra_coupon_slot": "Extra coupon slot",
}
## Inspections (day events) removed from data/, by id: their names (plan v0.46, #106; Big
## trolleys, a boon, v0.70: its 9-item hand overlapped).
const RETIRED_INSPECTIONS: Dictionary[StringName, String] = {
	&"coupon_slot_closed": "Coupon slot closed",
	&"big_trolleys": "Big trolleys",
}
## The retired day events that were boons: their stand-ins keep the BOON tone.
const RETIRED_BOONS: Array[StringName] = [&"big_trolleys"]
## The effect text of a retired stand-in.
const RETIRED_TEXT := "Retired: no effect"

## The balance the run is played with: aisle ids resolve to its aisles, and a restored run uses
## it.
var balance: BalanceDefinition
var root: String = DATA_ROOT
## Resources added with add(), by "<folder>/<id>".
var _added: Dictionary[String, Resource] = {}


func _init(content_balance: BalanceDefinition, data_root: String = DATA_ROOT) -> void:
	balance = content_balance
	root = data_root


func card(id: String) -> CardDefinition:
	return _resolve(CARDS_FOLDER, id) as CardDefinition


func upgrade(id: String) -> UpgradeDefinition:
	return _resolve(UPGRADES_FOLDER, id) as UpgradeDefinition


func inspection(id: String) -> InspectionDefinition:
	return _resolve(INSPECTIONS_FOLDER, id) as InspectionDefinition


func deck(id: String) -> DeckDefinition:
	return _resolve(DECKS_FOLDER, id) as DeckDefinition


## One of the balance's aisles, or null.
func aisle(id: String) -> AisleDefinition:
	for found: AisleDefinition in balance.aisles:
		if found.id == StringName(id):
			return found
	return null


## Makes a card, upgrade, inspection or deck made in code resolvable by its id (tests, and the
## retired stand-ins).
func add(resource: Resource) -> void:
	var folder: String = _folder_of(resource)
	if not folder.is_empty():
		_added["%s/%s" % [folder, resource.get("id")]] = resource


## The resource named by `id` in `folder` (one of the kinds), or null: the id must be a plain
## name, the file must exist and hold a resource of that kind whose id equals the file name.
func _resolve(folder: String, id: String) -> Resource:
	if not id.is_valid_identifier():
		return null
	var key: String = "%s/%s" % [folder, id]
	if _added.has(key):
		return _added[key]
	var path: String = "%s/%s.tres" % [root.path_join(folder), id]
	if not ResourceLoader.exists(path):
		return _retired(folder, StringName(id))
	var resource: Resource = load(path)
	if resource == null or _folder_of(resource) != folder:
		return null
	var own_id: Variant = resource.get("id")
	return resource if own_id is StringName and own_id == StringName(id) else null


## Whether `resource` is a retired upgrade's or inspection's inert stand-in.
static func is_retired(resource: Resource) -> bool:
	if resource is UpgradeDefinition:
		return RETIRED_UPGRADES.has((resource as UpgradeDefinition).id)
	if resource is InspectionDefinition:
		return RETIRED_INSPECTIONS.has((resource as InspectionDefinition).id)
	return false


## The inert stand-in for a retired id in `folder`, made once per lookup, or null when the id
## isn't retired.
func _retired(folder: String, id: StringName) -> Resource:
	var stand_in: Resource = null
	if folder == UPGRADES_FOLDER and RETIRED_UPGRADES.has(id):
		var upgrade_stand_in: UpgradeDefinition = UpgradeDefinition.new()
		upgrade_stand_in.id = id
		upgrade_stand_in.display_name = RETIRED_UPGRADES[id]
		upgrade_stand_in.type = UpgradeDefinition.Type.ECONOMY
		upgrade_stand_in.effect_text = RETIRED_TEXT
		stand_in = upgrade_stand_in
	elif folder == INSPECTIONS_FOLDER and RETIRED_INSPECTIONS.has(id):
		var inspection_stand_in: InspectionDefinition = InspectionDefinition.new()
		inspection_stand_in.id = id
		inspection_stand_in.display_name = RETIRED_INSPECTIONS[id]
		inspection_stand_in.notice_text = RETIRED_TEXT
		inspection_stand_in.chip_text = "no effect"
		if RETIRED_BOONS.has(id):
			inspection_stand_in.tone = InspectionDefinition.Tone.BOON
		stand_in = inspection_stand_in
	if stand_in != null:
		add(stand_in)
	return stand_in


## The folder for a resource's kind, or "" when it isn't one of the kinds.
static func _folder_of(resource: Resource) -> String:
	if resource is CardDefinition:
		return CARDS_FOLDER
	if resource is UpgradeDefinition:
		return UPGRADES_FOLDER
	if resource is InspectionDefinition:
		return INSPECTIONS_FOLDER
	if resource is DeckDefinition:
		return DECKS_FOLDER
	return ""
