extends GdUnitTestSuite
## The screens' colours are the art's (full build plan section 6.1, #55): every Color constant
## of Palette and of the boutique classes the shift screen builds is one of art/src/palette.txt's
## 67 colours. Out of scope (listed for #56/#75, not changed in #55): EffectMarker's
## SPENT_BACKGROUND (c9c1ae) and the shade's black, which belong to #60's count-up look.

const PALETTE_FILE := "res://art/src/palette.txt"
const PALETTE_SIZE := 67
## Palette and ArtStyle, then the boutique classes #55 adds to the real shift screen
## (StoreBackdrop, BeltPanel, RegisterCabinet, LedDisplay, PaperPile), the scan pieces #75
## moves out of style frame v2 (PriceSticker, ScanPopup, ScanOverlay, EffectChip) and the items
## and their cells (ItemView, PayoutPlaque, RowStrip), which take their colours from Palette:
## style frame v2's palette check, kept for the screen that replaced it (#75, step 9). A class is
## checked once its script exists, so each step of the adoption is covered as it lands.
const SCRIPTS: Array[String] = [
	"res://ui/palette.gd",
	"res://presentation/art_style.gd",
	"res://ui/store_backdrop.gd",
	"res://ui/belt_panel.gd",
	"res://ui/register_cabinet.gd",
	"res://ui/led_display.gd",
	"res://presentation/paper_pile.gd",
	"res://ui/price_sticker.gd",
	"res://ui/scan_popup.gd",
	"res://ui/scan_overlay.gd",
	"res://ui/effect_chip.gd",
	"res://ui/item_view.gd",
	"res://ui/payout_plaque.gd",
	"res://ui/row_strip.gd",
]
## The scan pieces and the items name no colour of their own: every colour they draw is a
## Palette constant.
const PALETTE_ONLY: Array[String] = [
	"res://ui/price_sticker.gd",
	"res://ui/scan_popup.gd",
	"res://ui/scan_overlay.gd",
	"res://ui/effect_chip.gd",
	"res://ui/item_view.gd",
	"res://ui/payout_plaque.gd",
]

var _folder: String = ""


func before_test() -> void:
	_folder = "user://test_palette_colours_%d" % Time.get_ticks_usec()
	_event_log().use_folder(_folder)
	ProjectSettings.set_setting(SaveService.FOLDER_SETTING, _folder)


func after_test() -> void:
	ProjectSettings.set_setting(SaveService.FOLDER_SETTING, null)
	_remove_folder(_folder)


func test_the_art_palette_has_its_colours() -> void:
	assert_int(_art_palette().size()).is_equal(PALETTE_SIZE)


func test_every_declared_colour_is_the_arts() -> void:
	var allowed: Dictionary[String, bool] = {}
	for colour: Color in _art_palette():
		allowed[colour.to_html(false)] = true
	var checked: int = 0
	for path: String in SCRIPTS:
		if not ResourceLoader.exists(path):
			continue
		var script: Script = load(path) as Script
		var constants: Dictionary = script.get_script_constant_map()
		for constant: String in constants:
			var value: Variant = constants[constant]
			if value is Color:
				checked += 1
				var html: String = (value as Color).to_html(false)
				(
					assert_bool(allowed.has(html))
					. override_failure_message(
						"%s.%s = %s is not in %s" % [path.get_file(), constant, html, PALETTE_FILE]
					)
					. is_true()
				)
	# Palette alone declares more than 20 colours.
	assert_int(checked).is_greater(20)


## The scan pieces and the items draw only Palette's colours: no Color constant, html colour or
## Color.NAMED colour in their code.
func test_the_scan_pieces_use_the_palette() -> void:
	var literal: RegEx = RegEx.create_from_string('Color\\("|Color\\.[A-Z]')
	for path: String in PALETTE_ONLY:
		var script: Script = load(path) as Script
		for constant: Variant in script.get_script_constant_map().values():
			assert_bool(constant is Color).override_failure_message(path).is_false()
		var found: RegExMatch = literal.search(script.source_code)
		(
			assert_object(found)
			. override_failure_message("%s: %s" % [path, found.get_string() if found else ""])
			. is_null()
		)
		assert_str(script.source_code).contains("Palette.")


## Palette's boutique constants are the art palette's named shades.
func test_the_boutique_ramps() -> void:
	var expected: Dictionary[Color, String] = {
		Palette.INK_LIGHT: "4a3f38",
		Palette.GREY_DARK: "5e574d",
		Palette.GREY: "8a8172",
		Palette.GREY_LIGHT: "c7beab",
		Palette.CREAM_SHADE: "ddcba5",
		Palette.TOMATO_DARK: "a83a3c",
		Palette.MUSTARD_LIGHT: "f1d27a",
		Palette.MUSTARD_PALE: "faecbc",
		Palette.BRASS_DARKEST: "4a3010",
		Palette.BRASS_DARK: "8a5d1a",
		Palette.BRASS: "c8932b",
		Palette.GOLD: "ffcf3f",
		Palette.VELVET_DARKEST: "2a0e14",
		Palette.VELVET_DARK: "561327",
		Palette.VELVET: "8a1f33",
		Palette.VELVET_SHEEN: "b23a55",
	}
	for colour: Color in expected:
		assert_str(colour.to_html(false)).is_equal(expected[colour])


static func _art_palette() -> Array[Color]:
	var colours: Array[Color] = []
	var file: FileAccess = FileAccess.open(PALETTE_FILE, FileAccess.READ)
	if file == null:
		return colours
	while not file.eof_reached():
		var line: String = file.get_line().strip_edges()
		if line.is_empty() or line.begins_with(";"):
			continue
		var parts: PackedStringArray = line.split(" ", false)
		if parts.size() >= 2 and parts[1].is_valid_html_color():
			colours.append(Color(parts[1]))
	return colours


static func _remove_folder(folder: String) -> void:
	if not DirAccess.dir_exists_absolute(folder):
		return
	for sub: String in DirAccess.get_directories_at(folder):
		_remove_folder(folder.path_join(sub))
	for file_name: String in DirAccess.get_files_at(folder):
		DirAccess.remove_absolute(folder.path_join(file_name))
	DirAccess.remove_absolute(folder)


static func _event_log() -> EventLogService:
	return (Engine.get_main_loop() as SceneTree).root.get_node("/root/EventLog")
