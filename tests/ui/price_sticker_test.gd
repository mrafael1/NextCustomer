extends GdUnitTestSuite
## The price sticker (#75): every card in data/cards shows its summary from core
## (CardDefinition.sticker_summary) in at most 2 lines inside SUMMARY_RECT, measured with the
## real font (bold Atkinson 13), and its base or COUPON, and an aisle product its glyph, all inside
## the sticker. The style frame v2 cards read as approved (spec section 4.1). Planning (#71,
## mock-up h1): set_pay strikes a product's base (never a coupon's COUPON) with an ink line across
## its text, moves the aisle glyph after the base and hides it next to a pay tag, shrinks the base
## when the tag needs the room, and puts it all back; set_got swaps a product's face.

const CARDS := "res://data/cards"
const BALANCE := "res://data/balance/balance.tres"
## A number that isn't an ordinal ("2nd" stays): the data's numbers, which balance passes may
## change.
const NUMBER := "\\d+(?!st|nd|rd|th)"
## The approved readings of style frame v2's cards (spec section 4.1), every number from the data
## as N.
const READINGS: Dictionary[String, String] = {
	"eggs": "×N next Food",
	"tea_bags": "×N next Breakfast",
	"banana": "+N after Banana",
	"batteries": "+N in last slot",
	"two_for_one": "Same both sides: 2nd ×N",
	"crisps": "+N beside Bread",
	"coffee": "+N next Breakfast",
	"milk": "+N per earlier Breakfast",
	"cheese": "+N after Bread",
	"strawberries": "+N beside Produce",
	"croissant": "+N beside Bakery",
	"multipack": "×N later with prior's tag",
}


func test_every_summary_fits_two_lines() -> void:
	var cards: Array[CardDefinition] = _cards()
	assert_int(cards.size()).is_equal(59)
	var balance: BalanceDefinition = load(BALANCE) as BalanceDefinition
	var stickers: Array[PriceSticker] = []
	for definition: CardDefinition in cards:
		var sticker: PriceSticker = auto_free(
			PriceSticker.new(definition, balance.aisle_of(definition))
		)
		add_child(sticker)
		stickers.append(sticker)
	await get_tree().process_frame
	await get_tree().process_frame
	var too_long: Array[String] = []
	for index: int in range(cards.size()):
		var definition: CardDefinition = cards[index]
		var sticker: PriceSticker = stickers[index]
		var summary: Label = sticker.summary_label()
		var message: String = '%s: "%s"' % [definition.id, summary.text]
		assert_str(summary.text).override_failure_message(message).is_equal(
			definition.sticker_summary()
		)
		var clipped: bool = summary.get_visible_line_count() < summary.get_line_count()
		if summary.get_line_count() > PriceSticker.MAX_SUMMARY_LINES or clipped:
			too_long.append(message)
		var rect: Rect2 = _local(sticker, summary)
		assert_bool(rect == PriceSticker.SUMMARY_RECT).override_failure_message(message).is_true()
		var face: Rect2 = Rect2(Vector2.ZERO, PriceSticker.SIZE)
		assert_bool(face.encloses(rect)).override_failure_message(message).is_true()
		# The summary's lines at the real font's height end inside the sticker's face.
		assert_float(summary.get_minimum_size().y).override_failure_message(message).is_less_equal(
			PriceSticker.SUMMARY_RECT.size.y
		)
		assert_bool(sticker.size == PriceSticker.SIZE).override_failure_message(message).is_true()
		_assert_head(sticker, definition, balance.aisle_of(definition))
	assert_array(too_long).override_failure_message("Over 2 lines: %s" % [too_long]).is_empty()


func test_the_v2_cards_read_as_approved() -> void:
	var number: RegEx = RegEx.create_from_string(NUMBER)
	for card_id: String in READINGS:
		var definition: CardDefinition = load("%s/%s.tres" % [CARDS, card_id]) as CardDefinition
		var sticker: PriceSticker = auto_free(PriceSticker.new(definition, null))
		var text: String = sticker.summary_label().text
		assert_str(number.sub(text, "N", true)).override_failure_message(card_id).is_equal(
			READINGS[card_id]
		)


## A card with no rule (Bread) shows only its price: an empty summary.
func test_a_card_with_no_rule_shows_only_its_price() -> void:
	var bread: CardDefinition = load("%s/bread.tres" % CARDS) as CardDefinition
	assert_bool(bread.rules.is_empty()).is_true()
	var sticker: PriceSticker = auto_free(PriceSticker.new(bread, null))
	assert_str(sticker.summary_label().text).is_empty()
	assert_str(sticker.base_label().text).is_equal("€%d" % bread.base)


## Struck, a product's base turns ink light under an ink line from STRIKE_OUT left of its text to
## STRIKE_OUT right of it, across its middle; with a tag the glyph moves to just after the base,
## and hides when it would touch the tag; a tag starting before the base's full-size end shrinks
## the base; set_pay(false, no tag) puts the plain ticket back.
func test_a_struck_base_moves_the_glyph_clear_of_the_tag() -> void:
	var balance: BalanceDefinition = load(BALANCE) as BalanceDefinition
	var aisle: AisleDefinition = balance.aisles[0]
	var product: CardDefinition = aisle.base_cards[0]
	var sticker: PriceSticker = auto_free(PriceSticker.new(product, aisle))
	add_child(sticker)
	await get_tree().process_frame
	assert_object(sticker.glyph()).is_not_null()
	var full_end: float = sticker.base_text_end(PriceSticker.BASE_SIZE)
	# A tag clear of the base, far right: struck, glyph moved after the base and kept.
	var far: Rect2 = Rect2(full_end + 30, -6, 60, 32)
	sticker.set_pay(true, far)
	assert_bool(sticker.is_struck()).is_true()
	var text: Rect2 = sticker.base_text_rect()
	var line: ColorRect = sticker.get_node(PriceSticker.STRIKE_NAME) as ColorRect
	assert_bool(line.visible).is_true()
	assert_object(line.color).is_equal(Palette.INK)
	assert_float(line.position.x).is_equal(text.position.x - PriceSticker.STRIKE_OUT)
	assert_float(line.size.x).is_equal(text.size.x + 2.0 * PriceSticker.STRIKE_OUT)
	assert_float(line.size.y).is_equal(PriceSticker.STRIKE_WIDTH)
	assert_float(absf(line.get_rect().get_center().y - text.get_center().y)).is_less_equal(1.0)
	assert_object(sticker.base_label().get_theme_color("font_color")).is_equal(Palette.INK_LIGHT)
	assert_float(sticker.glyph().position.x).is_equal_approx(
		text.end.x + PriceSticker.GLYPH_GAP, 1.0
	)
	assert_bool(sticker.glyph().visible).is_true()
	# A tag right after the base: the glyph would touch it, so it hides.
	var near: Rect2 = Rect2(full_end + PriceSticker.GLYPH_GAP, -6, 60, 32)
	sticker.set_pay(true, near)
	assert_bool(sticker.glyph().visible).is_false()
	assert_int(sticker.base_label().get_theme_font_size("font_size")).is_equal(
		PriceSticker.BASE_SIZE
	)
	# A tag over the full-size base's end: the base shrinks.
	sticker.set_pay(true, Rect2(full_end - 4, -6, 60, 32))
	assert_int(sticker.base_label().get_theme_font_size("font_size")).is_equal(
		PriceSticker.BASE_STRUCK_SIZE
	)
	assert_float(sticker.base_text_rect().end.x).is_less(full_end)
	sticker.set_pay(false, Rect2())
	assert_bool(sticker.is_struck()).is_false()
	assert_bool(line.visible).is_false()
	assert_vector(sticker.glyph().position).is_equal(PriceSticker.GLYPH_RECT.position)
	assert_bool(sticker.glyph().visible).is_true()
	assert_int(sticker.base_label().get_theme_font_size("font_size")).is_equal(
		PriceSticker.BASE_SIZE
	)
	assert_object(sticker.base_label().get_theme_color("font_color")).is_equal(Palette.INK)


## A coupon's COUPON is never struck; set_got swaps a product's face to ticket_got and back,
## and leaves a coupon's slip.
func test_a_coupon_is_never_struck_and_got_swaps_a_products_face() -> void:
	var coupon: CardDefinition = load("%s/multipack.tres" % CARDS) as CardDefinition
	var slip: PriceSticker = auto_free(PriceSticker.new(coupon, null))
	add_child(slip)
	slip.set_pay(true, Rect2(60, -4, 52, 26))
	assert_bool(slip.is_struck()).is_false()
	assert_bool((slip.get_node(PriceSticker.STRIKE_NAME) as CanvasItem).visible).is_false()
	slip.set_got(true)
	assert_bool(slip.is_got()).is_false()
	var bread: CardDefinition = load("%s/bread.tres" % CARDS) as CardDefinition
	var sticker: PriceSticker = auto_free(PriceSticker.new(bread, null))
	add_child(sticker)
	var face: Panel = sticker.get_child(0) as Panel
	sticker.set_got(true)
	assert_bool(sticker.is_got()).is_true()
	var got: StyleBoxTexture = face.get_theme_stylebox("panel") as StyleBoxTexture
	assert_object(got.texture).is_same(PriceSticker.GOT_FRAME)
	assert_float(got.texture_margin_top).is_equal(
		float(PriceSticker.FRAME_TOP_MARGIN * ArtStyle.ART_SCALE)
	)
	sticker.set_got(false)
	var plain: StyleBoxTexture = face.get_theme_stylebox("panel") as StyleBoxTexture
	assert_object(plain.texture).is_same(PriceSticker.FRAME)
	# The text rects: the base's from BASE_RECT's left, centred on it; no summary for Bread.
	var base: Rect2 = sticker.base_text_rect()
	assert_float(base.position.x).is_equal(PriceSticker.BASE_RECT.position.x)
	assert_float(base.size.x).is_greater(0.0)
	assert_float(base.get_center().y).is_equal_approx(PriceSticker.BASE_RECT.get_center().y, 0.5)
	assert_bool(sticker.summary_text_rect().has_area()).is_false()


## The base (or COUPON) and the glyph sit at their rects, apart, inside the sticker; only a
## product of an aisle has a glyph.
func _assert_head(
	sticker: PriceSticker, definition: CardDefinition, aisle: AisleDefinition
) -> void:
	var message: String = String(definition.id)
	var face: Rect2 = Rect2(Vector2.ZERO, PriceSticker.SIZE)
	# The base's label grows to the number font's height, centred on BASE_RECT's row.
	var base: Rect2 = _local(sticker, sticker.base_label())
	(
		assert_bool(base.position == PriceSticker.BASE_RECT.position)
		. override_failure_message("%s: %s" % [message, base])
		. is_true()
	)
	assert_float(base.size.x).is_equal(PriceSticker.BASE_RECT.size.x)
	assert_bool(face.encloses(base)).override_failure_message(message).is_true()
	var expected: String = (
		PriceSticker.COUPON_TITLE if definition.is_coupon() else "€%d" % definition.base
	)
	assert_str(sticker.base_label().text).override_failure_message(message).is_equal(expected)
	var glyph: TextureRect = sticker.glyph()
	assert_bool(glyph != null).override_failure_message(message).is_equal(aisle != null)
	if glyph == null:
		return
	assert_bool(definition.is_product()).override_failure_message(message).is_true()
	var rect: Rect2 = _local(sticker, glyph)
	assert_bool(rect == PriceSticker.GLYPH_RECT).override_failure_message(message).is_true()
	assert_bool(face.encloses(rect)).override_failure_message(message).is_true()
	assert_bool(rect.intersects(base)).override_failure_message(message).is_false()
	assert_object(glyph.texture).is_same(load(ArtStyle.glyph_path(aisle)))


## `control`'s rect in `sticker`'s own coordinates, from the global transforms.
static func _local(sticker: PriceSticker, control: Control) -> Rect2:
	return sticker.get_global_transform().affine_inverse() * control.get_global_rect()


static func _cards() -> Array[CardDefinition]:
	var cards: Array[CardDefinition] = []
	for file: String in DirAccess.get_files_at(CARDS):
		if file.ends_with(".tres"):
			cards.append(load("%s/%s" % [CARDS, file]) as CardDefinition)
	return cards
