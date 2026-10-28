extends GdUnitTestSuite
## The family looks as data (#105, data/families/): every family a card names has a style, the
## main-family order covers the ticket families once, every colour is the art's, the text reads
## on every face (WCAG 4.5:1), and the colours are the mock-up readability v3's set A (chosen by the
## user on 2026-10-25 over the colour-blind set B).

const LiveCardCount := preload("res://tests/data/live_card_count.gd")
const CARDS_DIR := "res://data/cards"
const FAMILIES_DIR := "res://data/families"
const PALETTE_FILE := "res://art/src/palette.txt"
const MIN_CONTRAST := 4.5
const GLYPH_SIZE := Vector2i(9, 9)
## The ticket families, and the coupon mark (glyph and words only).
const TICKET_FAMILIES := [
	"Breakfast", "Bakery", "Produce", "Dairy", "Frozen", "Snack", "Household", "Clearance", "Food"
]
const COUPON := "Coupon"
## The mock-up's colours (readability_v3 FC, set A): face, light, shade, paper text.
const COLOURS: Dictionary[String, Array] = {
	"Breakfast": ["e2b33c", "f1d27a", "b38425", false],
	"Bakery": ["d2a874", "ddcba5", "a87a4e", false],
	"Produce": ["5fae5a", "a5d17e", "3d7a45", false],
	"Dairy": ["4f9a94", "86c2b6", "3a7672", false],
	"Frozen": ["c3e0d4", "fbf7ee", "86c2b6", false],
	"Snack": ["7a5232", "a87a4e", "4a3022", true],
	"Household": ["5e574d", "8a8172", "4a3f38", true],
	"Clearance": ["a83a3c", "d9534f", "6e2630", true],
	"Food": ["ec8a6e", "f5bfa0", "d9534f", false],
}


func test_the_palette_holds_every_family_once() -> void:
	var palette: FamilyPalette = FamilyPalette.shared()
	var ids: Array[String] = []
	for family: FamilyStyle in palette.families:
		assert_bool(ids.has(family.id)).override_failure_message(family.id).is_false()
		ids.append(family.id)
		assert_str(family.display_name).override_failure_message(family.id).is_not_empty()
		assert_object(family.glyph).override_failure_message(family.id).is_not_null()
	var expected: Array = TICKET_FAMILIES + [COUPON]
	ids.sort()
	expected.sort()
	assert_array(ids).is_equal(expected)
	assert_bool(palette.style(COUPON).has_ticket_colours()).is_false()
	assert_array(Array(palette.style(COUPON).words)).is_equal(["coupon", "coupons"])


func test_the_main_order_covers_the_ticket_families_once() -> void:
	var order: Array = Array(FamilyPalette.shared().main_family_order)
	var sorted: Array = order.duplicate()
	sorted.sort()
	var expected: Array = TICKET_FAMILIES.duplicate()
	expected.sort()
	assert_array(sorted).is_equal(expected)
	# An aisle family beats Breakfast, which beats Clearance, which beats Food.
	assert_int(order.find("Breakfast")).is_greater(order.find("Dairy"))
	assert_int(order.find("Clearance")).is_greater(order.find("Breakfast"))
	assert_int(order.find("Food")).is_equal(order.size() - 1)
	assert_array(Array(FamilyPalette.shared().quiet_families)).is_equal(["Food"])


func test_every_family_a_card_names_has_a_style() -> void:
	var palette: FamilyPalette = FamilyPalette.shared()
	var files: PackedStringArray = DirAccess.get_files_at(CARDS_DIR)
	var cards: int = 0
	for file: String in files:
		if not file.ends_with(".tres"):
			continue
		cards += 1
		var card: CardDefinition = load("%s/%s" % [CARDS_DIR, file])
		var where: String = String(card.id)
		for tag: String in card.tags:
			(
				assert_object(palette.style(tag))
				. override_failure_message(where + " " + tag)
				. is_not_null()
			)
		assert_int(card.ticket_families.size()).override_failure_message(where).is_less_equal(
			CardFamilies.MAX_FAMILIES
		)
		var families: PackedStringArray = palette.ticket_families(card)
		assert_int(families.size()).override_failure_message(where).is_less_equal(
			CardFamilies.MAX_FAMILIES
		)
		for id: String in Array(families) + Array(card.ticket_families):
			var style: FamilyStyle = palette.style(id)
			assert_object(style).override_failure_message(where + " " + id).is_not_null()
			if style != null:
				assert_bool(style.has_ticket_colours()).override_failure_message(where).is_true()
		for id: String in palette.shelf_families(card.tags):
			(
				assert_object(palette.style(id))
				. override_failure_message(where + " " + id)
				. is_not_null()
			)
	assert_int(cards).is_equal(LiveCardCount.CARDS)


func test_the_colours_are_set_a() -> void:
	var palette: FamilyPalette = FamilyPalette.shared()
	for id: String in COLOURS:
		_assert_values(palette.style(id), COLOURS[id])


func test_every_colour_is_the_arts_and_the_text_reads() -> void:
	var allowed: Dictionary[String, bool] = {}
	for colour: Color in _art_palette():
		allowed[colour.to_html(false)] = true
	assert_int(allowed.size()).is_greater(30)
	var styles: Array[FamilyStyle] = _styles(FAMILIES_DIR)
	var checked: int = 0
	for style: FamilyStyle in styles:
		if not style.has_ticket_colours():
			continue
		checked += 1
		for colour: Color in [style.face, style.light, style.shade]:
			(
				assert_bool(allowed.has(colour.to_html(false)))
				. override_failure_message("%s %s" % [style.id, colour.to_html(false)])
				. is_true()
			)
		var text: Color = Palette.PAPER if style.paper_text else Palette.INK
		var ratio: float = _contrast(text, style.face)
		(
			assert_float(ratio)
			. override_failure_message("%s: %.2f" % [style.id, ratio])
			. is_greater_equal(MIN_CONTRAST)
		)
	assert_int(checked).is_equal(TICKET_FAMILIES.size())


func test_the_text_colour_is_paper_only_on_dark_faces() -> void:
	var palette: FamilyPalette = FamilyPalette.shared()
	assert_that(palette.text_color(PackedStringArray(["Household"]))).is_equal(Palette.PAPER)
	assert_that(palette.text_color(PackedStringArray(["Breakfast"]))).is_equal(Palette.INK)
	assert_that(palette.text_color(PackedStringArray(["Snack", "Clearance"]))).is_equal(
		Palette.PAPER
	)
	assert_that(palette.text_color(PackedStringArray(["Snack", "Dairy"]))).is_equal(Palette.INK)
	assert_that(palette.text_color(PackedStringArray())).is_equal(Palette.INK)


func test_every_glyph_is_9x9() -> void:
	for style: FamilyStyle in FamilyPalette.shared().families:
		var size: Vector2i = Vector2i(style.glyph.get_size())
		assert_that(size).override_failure_message(style.id).is_equal(GLYPH_SIZE)


func _assert_values(style: FamilyStyle, values: Array) -> void:
	assert_object(style).is_not_null()
	if style == null:
		return
	assert_str(style.face.to_html(false)).override_failure_message(style.id).is_equal(values[0])
	assert_str(style.light.to_html(false)).override_failure_message(style.id).is_equal(values[1])
	assert_str(style.shade.to_html(false)).override_failure_message(style.id).is_equal(values[2])
	assert_bool(style.paper_text).override_failure_message(style.id).is_equal(values[3])


static func _styles(folder: String) -> Array[FamilyStyle]:
	var found: Array[FamilyStyle] = []
	for file: String in DirAccess.get_files_at(folder):
		if file.ends_with(".tres") and file != "family_palette.tres":
			found.append(load(folder.path_join(file)) as FamilyStyle)
	return found


## WCAG 2 contrast ratio of two colours.
static func _contrast(a: Color, b: Color) -> float:
	var la: float = _luminance(a)
	var lb: float = _luminance(b)
	return (maxf(la, lb) + 0.05) / (minf(la, lb) + 0.05)


static func _luminance(colour: Color) -> float:
	var linear: Color = colour.srgb_to_linear()
	return 0.2126 * linear.r + 0.7152 * linear.g + 0.0722 * linear.b


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
