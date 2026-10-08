extends GdUnitTestSuite
## Loads every scene and resource in the game folders and the golden fixture. tools/test.sh
## fails on any Godot error printed while loading, so a broken link inside a .tres or .tscn
## fails here. A new folder of scenes or resources must be added to FOLDERS.

## Subfolders are loaded too, so "res://data" covers data/cards, data/decks, data/balance,
## data/upgrades, data/inspections, data/aisles and data/catalogue;
## test_every_data_folder_is_loaded checks that.
const FOLDERS := [
	"res://data",
	"res://ui",
	"res://presentation",
	"res://debug",
	"res://telemetry",
	"res://tests/fixtures",
]


func test_every_scene_and_resource_loads() -> void:
	var files: Array[String] = []
	for folder: String in FOLDERS:
		_collect(folder, files)
	assert_int(files.size()).is_greater(0)
	for path: String in files:
		var resource: Resource = load(path)
		assert_object(resource).override_failure_message(path).is_not_null()
		if path.ends_with(".tscn"):
			assert_object(resource).override_failure_message(path).is_instanceof(PackedScene)
		elif path.contains("/cards/") or path.begins_with("res://tests/fixtures/cards_"):
			assert_object(resource).override_failure_message(path).is_instanceof(CardDefinition)
		elif path.contains("/decks/"):
			assert_object(resource).override_failure_message(path).is_instanceof(DeckDefinition)
		elif path.contains("/upgrades/"):
			assert_object(resource).override_failure_message(path).is_instanceof(UpgradeDefinition)
		elif path.contains("/builds/"):
			assert_object(resource).override_failure_message(path).is_instanceof(BuildDefinition)
		elif path.contains("/inspections/"):
			assert_object(resource).override_failure_message(path).is_instanceof(
				InspectionDefinition
			)
		elif path.contains("/catalogue/"):
			assert_object(resource).override_failure_message(path).is_instanceof(
				CatalogueDefinition
			)
		elif path.contains("/aisles/"):
			assert_object(resource).override_failure_message(path).is_instanceof(AisleDefinition)
		elif path.contains("/balance/"):
			assert_object(resource).override_failure_message(path).is_instanceof(BalanceDefinition)


static func _collect(folder: String, files: Array[String]) -> void:
	if not DirAccess.dir_exists_absolute(folder):
		return
	for file: String in DirAccess.get_files_at(folder):
		if file.ends_with(".tres") or file.ends_with(".tscn"):
			files.append("%s/%s" % [folder, file])
	for sub: String in DirAccess.get_directories_at(folder):
		_collect("%s/%s" % [folder, sub], files)


func test_every_data_folder_is_loaded() -> void:
	var files: Array[String] = []
	_collect("res://data", files)
	for folder: String in [
		"cards", "decks", "balance", "upgrades", "inspections", "aisles", "catalogue", "builds"
	]:
		var prefix: String = "res://data/%s/" % folder
		var found: bool = files.any(func(path: String) -> bool: return path.begins_with(prefix))
		assert_bool(found).override_failure_message(prefix).is_true()
