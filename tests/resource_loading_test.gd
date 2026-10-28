extends GdUnitTestSuite
## Loads every scene and resource in the game folders and the golden fixture. tools/test.sh
## fails on any Godot error printed while loading, so a broken link inside a .tres or .tscn
## fails here. A new folder of scenes or resources must be added to FOLDERS, and a resource
## outside them to FILES.

## Subfolders are loaded too, so "res://data" covers data/cards, data/decks, data/balance,
## data/upgrades, data/inspections, data/aisles, data/catalogue and data/families (#105);
## test_every_data_folder_is_loaded checks that.
const FOLDERS := [
	"res://data",
	"res://ui",
	"res://presentation",
	"res://debug",
	"res://telemetry",
	"res://tests/fixtures",
]
## Resources outside FOLDERS: the audio bus layout at the project root (#62).
const FILES := ["res://default_bus_layout.tres"]


func test_every_scene_and_resource_loads() -> void:
	var files: Array[String] = []
	for folder: String in FOLDERS:
		_collect(folder, files)
	for path: String in FILES:
		files.append(path)
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
		elif path.contains("/item_upgrades/"):
			assert_object(resource).override_failure_message(path).is_instanceof(
				ItemUpgradeDefinition
			)
		elif path.ends_with("/families/family_palette.tres"):
			assert_object(resource).override_failure_message(path).is_instanceof(FamilyPalette)
		elif path.contains("/families/"):
			assert_object(resource).override_failure_message(path).is_instanceof(FamilyStyle)
		elif path.contains("/aisles/"):
			assert_object(resource).override_failure_message(path).is_instanceof(AisleDefinition)
		elif path.ends_with("/balance/count_up.tres"):
			assert_object(resource).override_failure_message(path).is_instanceof(CountUpTuning)
		elif path.ends_with("/balance/count_total.tres"):
			assert_object(resource).override_failure_message(path).is_instanceof(CountTotalTuning)
		elif path.ends_with("/balance/scan.tres"):
			assert_object(resource).override_failure_message(path).is_instanceof(ScanTuning)
		elif path.ends_with("/balance/machine_tempo.tres"):
			assert_object(resource).override_failure_message(path).is_instanceof(MachineTuning)
		elif path.ends_with("/balance/machine.tres"):
			assert_object(resource).override_failure_message(path).is_instanceof(MachineDefinition)
		elif path.ends_with("/balance/planning.tres"):
			assert_object(resource).override_failure_message(path).is_instanceof(PlanningTuning)
		elif path.ends_with("/balance/redraw.tres"):
			assert_object(resource).override_failure_message(path).is_instanceof(RedrawTuning)
		elif path.ends_with("/balance/cart_reveal.tres"):
			assert_object(resource).override_failure_message(path).is_instanceof(CartRevealTuning)
		elif path.contains("/balance/"):
			assert_object(resource).override_failure_message(path).is_instanceof(BalanceDefinition)
		elif path.ends_with("_bus_layout.tres"):
			assert_object(resource).override_failure_message(path).is_instanceof(AudioBusLayout)


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
		"cards",
		"decks",
		"balance",
		"upgrades",
		"inspections",
		"aisles",
		"catalogue",
		"builds",
		"item_upgrades",
		"families",
	]:
		var prefix: String = "res://data/%s/" % folder
		var found: bool = files.any(func(path: String) -> bool: return path.begins_with(prefix))
		assert_bool(found).override_failure_message(prefix).is_true()
