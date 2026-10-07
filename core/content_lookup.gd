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
## Tests point `root` at a folder of their own, or add in-memory resources with add().

const DATA_ROOT := "res://data"
const CARDS_FOLDER := "cards"
const UPGRADES_FOLDER := "upgrades"
const INSPECTIONS_FOLDER := "inspections"
const DECKS_FOLDER := "decks"

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


## Tests only: makes a card, upgrade, inspection or deck made in code resolvable by its id.
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
		return null
	var resource: Resource = load(path)
	if resource == null or _folder_of(resource) != folder:
		return null
	var own_id: Variant = resource.get("id")
	return resource if own_id is StringName and own_id == StringName(id) else null


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
