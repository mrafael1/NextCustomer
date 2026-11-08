extends GdUnitTestSuite
## A ticket's family row and its written families (2026-11-05, split out of price_sticker_test for
## gdlint's method count): a third icon (two printed families and a gained one) widens the label
## and narrows the window beside it, the price kept inside it and the ticket's height kept; family
## chips are 8 art px tall with their name centred. Layout: price_sticker_test's checks.

const Sticker := preload("res://tests/ui/price_sticker_test.gd")
const CARDS := "res://data/cards"


## Two printed families and a gained one (Milk): the label widens to three icons on its one row
## and the window narrows beside it, its right edge and height kept, its price still inside it (a
## two-digit price steps down to the 4x7 digits); the ticket keeps its height, the gold ring too.
func test_a_third_icon_widens_the_label_and_keeps_the_price() -> void:
	var definition: CardDefinition = _card("milk_golden")
	var milk: PriceSticker = auto_free(PriceSticker.new(definition))
	add_child(milk)
	assert_int(milk.glyphs().size()).is_equal(2)
	milk.show_gained("Household")
	await get_tree().process_frame
	assert_bool(milk.is_wide()).is_true()
	assert_vector(milk.size).is_equal(PriceSticker.SIZE)
	var gained: FamilyGlyph = milk.gained()
	assert_vector(gained.position).is_equal(
		PriceSticker.ICON_FIRST + Vector2(PriceSticker.ICON_STEP * 2.0, 0.0)
	)
	var window: Rect2 = Rect2(milk.window().position, milk.window().size)
	var wide: Rect2i = TicketFace.WINDOW_WIDE
	assert_object(window).is_equal(Rect2(wide.position * 2, wide.size * 2))
	var full: Rect2 = Rect2(PriceSticker.WINDOW_AT, PriceWindow.SIZE)
	assert_float(window.end.x).is_equal(full.end.x)
	assert_float(window.size.y).is_equal(full.size.y)
	assert_bool(gained.rim_rect().intersects(window)).is_false()
	for amount: int in [4, 21, 99]:
		milk.set_pay(PlanningModel.Pay.BOOSTED, amount)
		var digits: Rect2 = milk.window().digits_rect()
		(
			assert_bool(Rect2(Vector2.ZERO, window.size).encloses(digits))
			. override_failure_message("%d€ at %s" % [amount, digits])
			. is_true()
		)
	milk.clear_pay()
	var grow: float = 2.0 * PriceSticker.GOLD_RING_ART * ArtStyle.ART_SCALE
	assert_float(milk.gold_ring().size.y).is_equal(PriceSticker.SIZE.y + grow)
	_assert_gained_frame(gained)
	_assert_layout(milk, definition)
	milk.show_gained("")
	await get_tree().process_frame
	assert_bool(milk.is_wide()).is_false()
	assert_vector(milk.window().size).is_equal(PriceWindow.SIZE)
	_assert_layout(milk, definition)


## Family chips (2026-11-05): 8 art px tall, one more than v5's, at the rule's own type size, the
## name's capitals centred down the chip; the chip centred on its text line, inside the plate.
func test_family_chips_have_room_round_their_name() -> void:
	assert_float(FamilyWord.HEIGHT).is_equal(16.0)
	var families: Dictionary[String, bool] = {}
	for file_name: String in DirAccess.get_files_at(CARDS):
		if not file_name.ends_with(".tres"):
			continue
		var definition: CardDefinition = load(CARDS.path_join(file_name)) as CardDefinition
		if definition == null:
			continue
		var sticker: PriceSticker = auto_free(PriceSticker.new(definition))
		for word: FamilyWord in sticker.summary().words():
			families[word.family] = true
			var cap: float = -ReceiptRows.ink_span(word._font, word._font_size).x
			var above: float = word.baseline() - cap
			var below: float = FamilyWord.HEIGHT - word.baseline()
			# Lettering centred: as much room over the capitals as under the baseline, within a
			# px, and at least an art px of it.
			assert_float(absf(above - below)).override_failure_message(file_name).is_less_equal(1.0)
			assert_float(above).is_greater_equal(ArtStyle.ART_SCALE)
			assert_float(fmod(word.position.y, ArtStyle.ART_SCALE)).is_equal(0.0)
		if not sticker.summary().words().is_empty():
			_assert_layout(sticker, definition)
	for family: String in ["Food", "Breakfast", "Household"]:
		assert_bool(families.has(family)).override_failure_message(family).is_true()


## A gained glyph's amber frame: one art px round its 9x9 art, behind it.
func _assert_gained_frame(gained: FamilyGlyph) -> void:
	var frame: Control = gained.get_node(PriceSticker.GAINED_FRAME_NAME) as Control
	assert_object(frame).is_not_null()
	assert_bool(frame.show_behind_parent).is_true()
	assert_object(Rect2(frame.position, frame.size)).is_equal(
		Rect2(Vector2.ZERO, gained.size).grow(ArtStyle.ART_SCALE)
	)
	assert_object(PriceSticker.gained_frame_ink()).is_equal(Palette.MUSTARD_DARK)


func _assert_layout(sticker: PriceSticker, definition: CardDefinition) -> void:
	var problems: PackedStringArray = Sticker._layout_problems(
		sticker, definition, FamilyPalette.shared()
	)
	assert_array(problems).override_failure_message("\n".join(problems)).is_empty()


static func _card(card_id: String) -> CardDefinition:
	return load("%s/%s.tres" % [CARDS, card_id]) as CardDefinition
