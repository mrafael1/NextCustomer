extends GdUnitTestSuite
## The screens' colours are the art's (full build plan section 6.1, #55): every Color constant
## of Palette and of the boutique classes the shift screen builds is one of art/src/palette.txt's
## 67 colours. Out of scope (listed for #56/#75, not changed in #55): the shade's black
## (ScreenShade's colour since #80), which belongs to #60's count-up look.

const PALETTE_FILE := "res://art/src/palette.txt"
const PALETTE_SIZE := 67
## Palette and ArtStyle, then the boutique classes #55 adds to the real shift screen
## (StoreBackdrop, BeltPanel with step 6's BeltFootprint and ContactShadow, RegisterCabinet,
## LedDisplay), the scan pieces #75 moves out of style frame v2 (PriceSticker,
## ScanPopup, ScanOverlay), the items, their marks and their cells (ItemView, EffectMark,
## PayoutPlaque, RowStrip), which take their colours from Palette, and the hung monitor's pieces
## #80 adds (MonitorView, LedBeat, ScanFooter) and the back of the store (StoreShelves, step 11):
## style frame v2's palette check, kept for the screen that replaced it (#75, step 9), and the
## planning effects' pieces (#71, mock-up h1: PlanningLayer, RailStrip, EffectSticker, GiverBadge,
## PayTag, DenyStamp), the count-up's receipt chip (#86 v6, ReceiptFly) and its paper bag
## (PaperBag, which declares no colour: its art is drawn from the palette), the belt ride and the
## giver sparks (BeltRide, GiverSparks), and the monitor's count view (ScannerBay, MetStamp,
## Sunburst, OverTab) with the burst outside it (TankBurst), and the RECEIPT REWARDS machine's
## parts (#77, build spec 4.2: ui/machine/, and the receipt's stamps, ReceiptStamps), listed ahead
## of their builds. A class is checked once its script exists, so each step of the adoption is
## covered as it lands.
const SCRIPTS: Array[String] = [
	"res://ui/palette.gd",
	"res://presentation/art_style.gd",
	"res://ui/store_backdrop.gd",
	"res://ui/belt_panel.gd",
	"res://ui/belt_footprint.gd",
	"res://ui/contact_shadow.gd",
	"res://ui/register_cabinet.gd",
	"res://ui/led_display.gd",
	"res://ui/price_sticker.gd",
	"res://ui/scan_popup.gd",
	"res://ui/scan_overlay.gd",
	"res://ui/effect_mark.gd",
	"res://ui/item_view.gd",
	"res://ui/payout_plaque.gd",
	"res://ui/row_strip.gd",
	"res://ui/monitor_view.gd",
	"res://ui/led_beat.gd",
	"res://ui/scan_footer.gd",
	"res://ui/store_shelves.gd",
	"res://ui/planning_layer.gd",
	"res://ui/rail_strip.gd",
	"res://ui/effect_sticker.gd",
	"res://ui/giver_badge.gd",
	"res://ui/pay_tag.gd",
	"res://ui/deny_stamp.gd",
	"res://presentation/receipt_fly.gd",
	"res://ui/paper_bag.gd",
	"res://ui/belt_ride.gd",
	"res://ui/giver_sparks.gd",
	"res://ui/scanner_bay.gd",
	"res://ui/met_stamp.gd",
	"res://ui/sunburst.gd",
	"res://ui/over_tab.gd",
	"res://ui/tank_burst.gd",
	"res://ui/bay_bed.gd",
	"res://ui/bay_tag.gd",
	"res://ui/bay_queue.gd",
	"res://ui/tally_chips.gd",
	"res://ui/machine/reward_machine_view.gd",
	"res://ui/machine/machine_head.gd",
	"res://ui/machine/slot_plate.gd",
	"res://ui/machine/machine_display.gd",
	"res://ui/machine/chute_key.gd",
	"res://ui/machine/punch_meter.gd",
	"res://ui/machine/stockroom_window.gd",
	"res://ui/machine/order_slip.gd",
	"res://ui/machine/order_plate.gd",
	"res://ui/machine/machine_belt.gd",
	"res://ui/machine/box_lane.gd",
	"res://ui/machine/restock_hood.gd",
	"res://ui/machine/prize_ticket.gd",
	"res://ui/machine/rarity_tab.gd",
	"res://ui/machine/odds_card.gd",
	"res://ui/machine/cart_drawer.gd",
	"res://ui/machine/machine_flyer.gd",
	"res://ui/machine/receipt_feed.gd",
	"res://presentation/receipt_stamps.gd",
]
## The scan pieces (the scan's step lines in ScanFooter, #80, too), the items and the planning
## effects' pieces (#71), the receipt chip and the giver sparks (#86 v6) name no colour of their
## own: every colour they draw is a Palette constant.
const PALETTE_ONLY: Array[String] = [
	"res://ui/price_sticker.gd",
	"res://ui/scan_popup.gd",
	"res://ui/scan_overlay.gd",
	"res://ui/effect_mark.gd",
	"res://ui/item_view.gd",
	"res://ui/payout_plaque.gd",
	"res://ui/scan_footer.gd",
	"res://ui/planning_layer.gd",
	"res://ui/rail_strip.gd",
	"res://ui/effect_sticker.gd",
	"res://ui/giver_badge.gd",
	"res://ui/pay_tag.gd",
	"res://ui/deny_stamp.gd",
	"res://presentation/receipt_fly.gd",
	"res://ui/giver_sparks.gd",
]
## The machine's parts (test_the_machine_parts_use_the_palette) and the colour literals they may
## not write.
const MACHINE_FOLDER := "res://ui/machine"
const RECEIPT_STAMPS := "res://presentation/receipt_stamps.gd"
const MACHINE_LITERAL := 'Color8?\\(\\s*["0-9.]|Color\\.(from_[a-z]+|html)\\(|Color\\.[A-Z]'

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


## The RECEIPT REWARDS machine's parts (#77, build spec 4.2: every ui/machine/ script, and the
## receipt's stamps once ReceiptStamps exists) take every colour from Palette: no Color constant,
## and no colour written in their code (an html or number Color(), Color8(), Color.from_*(),
## Color.html() or a Color.NAMED colour). Placeholder parts with no colour yet pass.
func test_the_machine_parts_use_the_palette() -> void:
	var literal: RegEx = RegEx.create_from_string(MACHINE_LITERAL)
	var paths: Array[String] = []
	for file_name: String in DirAccess.get_files_at(MACHINE_FOLDER):
		if file_name.get_extension() == "gd":
			paths.append(MACHINE_FOLDER.path_join(file_name))
	if ResourceLoader.exists(RECEIPT_STAMPS):
		paths.append(RECEIPT_STAMPS)
	assert_bool(paths.has(MACHINE_FOLDER.path_join("reward_machine_view.gd"))).is_true()
	for path: String in paths:
		var script: Script = load(path) as Script
		for constant: String in script.get_script_constant_map():
			var value: Variant = script.get_script_constant_map()[constant]
			(
				assert_bool(value is Color)
				. override_failure_message("%s declares the colour %s" % [path, constant])
				. is_false()
			)
		var found: RegExMatch = literal.search(script.source_code)
		(
			assert_object(found)
			. override_failure_message("%s: %s" % [path, found.get_string() if found else ""])
			. is_null()
		)


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
		Palette.MUSTARD_DARK: "b38425",
		Palette.MUSTARD_DARKEST: "7a5a1c",
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
