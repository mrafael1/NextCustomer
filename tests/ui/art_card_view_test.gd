extends GdUnitTestSuite
## The pixel-art card (full build plan section 6.1): every card in data/cards fits ArtCardView's
## fixed size with the real fonts, including any tag a coupon can grant it while scoring,
## and the fonts have every character the game prints. This is the test that sets
## ArtCardView.SIZE.y: a failure lists each card's spare pixels (negative when it overflows).
## It also checks the value badge's brass payout plaque (#55, D2a) and the plain CardView's badge.

const CARDS := "res://data/cards"
const BALANCE := "res://data/balance/balance.tres"


func test_every_card_fits_the_art_card() -> void:
	var definitions: Array[CardDefinition] = _cards()
	assert_int(definitions.size()).is_greater(0)
	# A product gains at most one tag while scoring: the only tag grant is a relabeller's, on
	# the product in its next slot (Breakfast sticker, Clearance tag). So each card is laid out
	# with each grantable tag in turn, and with none, and its worst fit counts.
	var tag_sets: Array[PackedStringArray] = [PackedStringArray()]
	for tag: String in _grantable_tags(definitions):
		tag_sets.append(PackedStringArray([tag]))
	var spare: Dictionary[String, float] = {}
	var overflow: Array[String] = []
	# Every product is laid out with a band (an aisle's), its tallest look.
	var any_aisle: AisleDefinition = (load(BALANCE) as BalanceDefinition).aisles[0]
	for definition: CardDefinition in definitions:
		for granted: PackedStringArray in tag_sets:
			var view: ArtCardView = await _laid_out(definition, granted, any_aisle)
			var height: float = view._column.get_combined_minimum_size().y
			var available: float = ArtCardView.SIZE.y - 2.0 * view.padding().y
			var card_name: String = definition.display_name
			spare[card_name] = minf(spare.get(card_name, available - height), available - height)
			var body: Rect2 = view.body.get_global_rect()
			var rule: Rect2 = view._rule_label.get_global_rect()
			var rule_label: Label = view._rule_label
			var clipped: bool = rule_label.get_visible_line_count() < rule_label.get_line_count()
			if height > available or clipped or not body.encloses(rule):
				if not overflow.has(card_name):
					overflow.append(card_name)
	(
		assert_array(overflow)
		. override_failure_message(
			"Cards overflow (card %d tall). Spare pixels per card: %s" % [ArtCardView.SIZE.y, spare]
		)
		. is_empty()
	)


## A product's price sticker sits inside the sprite's box, clear of the sprite's middle (where
## an item stands), and every card's content stays inside its body.
func test_the_price_sticker_and_content_fit() -> void:
	for definition: CardDefinition in _cards():
		var view: ArtCardView = await _laid_out(definition, PackedStringArray())
		var body: Rect2 = view.body.get_global_rect()
		var column: Rect2 = view._column.get_global_rect()
		if definition.is_product():
			var art: Rect2 = view._art.get_global_rect()
			var sticker: Rect2 = view._sticker.get_global_rect()
			(
				assert_bool(art.encloses(sticker))
				. override_failure_message("%s: %s" % [definition.display_name, sticker])
				. is_true()
			)
			var sprite_middle: float = art.get_center().x - ArtCardView.ART_SPRITE_SIZE / 2.0
			assert_float(sticker.end.x).is_less_equal(sprite_middle)
		(
			assert_bool(body.encloses(column))
			. override_failure_message(
				"%s: %s outside %s" % [definition.display_name, column, body]
			)
			. is_true()
		)


func test_the_fonts_have_every_printed_character() -> void:
	var fonts: Array[Font] = [
		ArtStyle.DISPLAY_FONT, ArtStyle.BODY_FONT, ArtStyle.number_font(), ArtStyle.MONO_FONT
	]
	for font: Font in fonts:
		for character: String in ArtStyle.REQUIRED_GLYPHS:
			(
				assert_bool(font.has_char(character.unicode_at(0)))
				. override_failure_message("%s lacks %s" % [font.resource_path, character])
				. is_true()
			)


## The value badge is the brass payout plaque (#55, D2a): it reads "pays €N" in the number font,
## its face's top sits PLAQUE_Y above the card, centred over it, and the text fits the face
## inside the card's width (a four-digit payout too) without the Label growing past
## BADGE_HEIGHT. Only the face carries the sharp-pixel material, never the text.
func test_the_payout_plaque_reads_pays_and_fits() -> void:
	var view: ArtCardView = await _laid_out(load("%s/milk.tres" % CARDS), PackedStringArray())
	for value: int in [0, 7, 42, 9999]:
		view.show_badge(value, false)
		await get_tree().process_frame
		var badge: Label = view.badge
		assert_str(badge.text).is_equal("pays €%d" % value)
		assert_bool(badge.visible).is_true()
		assert_float(badge.size.y).is_equal(ArtCardView.BADGE_HEIGHT)
		assert_float(badge.get_minimum_size().y).is_less_equal(ArtCardView.BADGE_HEIGHT)
		var card: Rect2 = view.get_global_rect()
		var face: Rect2 = view.plaque().get_global_rect()
		assert_float(face.position.y - card.position.y).is_equal(ArtCardView.PLAQUE_Y)
		assert_float(face.size.y).is_equal(ArtCardView.PLAQUE_HEIGHT)
		assert_float(face.end.y).is_less_equal(card.position.y)
		assert_float(face.get_center().x).is_equal_approx(card.get_center().x, 0.5)
		assert_float(face.position.x).is_greater_equal(card.position.x)
		assert_float(face.end.x).is_less_equal(card.end.x)
		var text_width: float = badge.get_minimum_size().x
		assert_float(text_width).is_less_equal(face.size.x - 2.0 * ArtCardView.PLAQUE_PADDING)
	assert_object(view.badge.get_theme_font("font")).is_same(ArtStyle.number_font())
	assert_int(view.badge.get_theme_font_size("font_size")).is_equal(ArtCardView.PLAQUE_FONT_SIZE)
	assert_object(view.badge.material).is_null()
	assert_bool(view.badge.has_meta(ArtStyle.PIXEL_ART_META)).is_false()
	assert_object(view.plaque().material).is_same(ArtStyle.pixel_material())
	assert_bool(view.plaque().show_behind_parent).is_true()
	assert_int(view.plaque().mouse_filter).is_equal(Control.MOUSE_FILTER_IGNORE)


## The muted face shows at €0 and on a denied value; any other value shows the brass face, and
## show_badge brings it back after a denied one. The rest y is the plaque's, not CardView's.
func test_the_plaque_mutes_at_zero_and_when_denied() -> void:
	var view: ArtCardView = await _laid_out(load("%s/milk.tres" % CARDS), PackedStringArray())
	view.show_badge(5, false)
	assert_bool(view.is_badge_muted()).is_false()
	view.show_badge(0, true)
	assert_bool(view.is_badge_muted()).is_true()
	view.show_badge(3, true)
	assert_bool(view.is_badge_muted()).is_false()
	view.show_fizzle_badge(4)
	assert_bool(view.is_badge_muted()).is_true()
	assert_str(view.badge.text).is_equal("pays €4")
	view.show_badge(4, true)
	assert_bool(view.is_badge_muted()).is_false()
	var rest: float = (
		ArtCardView.PLAQUE_Y - (ArtCardView.BADGE_HEIGHT - ArtCardView.PLAQUE_HEIGHT) / 2.0
	)
	assert_float(view.badge_rest_y()).is_equal(rest)
	view.badge.position.y = 0.0
	view.reset_motion()
	assert_float(view.badge.position.y).is_equal(rest)


## A plain CardView keeps its number badge: BADGE_Y above the card, tomato when denied.
func test_the_plain_card_keeps_its_badge() -> void:
	var view: CardView = auto_free(CardView.new(CardInstance.new(load("%s/milk.tres" % CARDS), 1)))
	add_child(view)
	assert_float(view.badge_rest_y()).is_equal(CardView.BADGE_Y)
	view.show_fizzle_badge(0)
	assert_str(view.badge.text).is_equal("0")
	assert_object(view.badge.get_theme_color("font_color")).is_equal(Palette.TOMATO)
	view.show_badge(2, true)
	assert_object(view.badge.get_theme_color("font_color")).is_equal(Palette.MUSTARD)


## Milk carries its sprite; a card without art shows the art-pending box.
func test_art_ref_loads_the_sprite() -> void:
	var milk: CardDefinition = load("%s/milk.tres" % CARDS)
	assert_str(milk.art_ref).is_equal("res://art/items/milk.png")
	assert_object(ArtStyle.item_texture(milk)).is_not_same(ArtStyle.ART_PENDING)
	assert_object(ArtStyle.item_texture(load("%s/bread.tres" % CARDS))).is_same(
		ArtStyle.ART_PENDING
	)


## Every art_ref in data/cards names a texture that exists.
func test_every_art_ref_exists() -> void:
	for definition: CardDefinition in _cards():
		if definition.art_ref != "":
			(
				assert_bool(ResourceLoader.exists(definition.art_ref))
				. override_failure_message(definition.art_ref)
				. is_true()
			)


## The aisle mark (#55, decision 3): a product from an aisle wears its aisle's sign colour as
## the band and its glyph in the sprite box's free corner, clear of the price sticker and the
## sprite's middle; staples and coupons wear neither, even if handed an aisle.
func test_the_aisle_mark_shows_only_on_aisle_products() -> void:
	var balance: BalanceDefinition = load(BALANCE)
	var checked: int = 0
	for definition: CardDefinition in _cards():
		var aisle: AisleDefinition = balance.aisle_of(definition)
		var view: ArtCardView = await _laid_out(definition, PackedStringArray(), aisle)
		var card_name: String = definition.display_name
		if aisle == null:
			assert_bool(view.has_band()).override_failure_message(card_name).is_false()
			assert_object(view.glyph()).override_failure_message(card_name).is_null()
			continue
		checked += 1
		assert_bool(view.has_band()).override_failure_message(card_name).is_true()
		assert_object(view.band_color()).is_equal(aisle.sign_color)
		var glyph: TextureRect = view.glyph()
		assert_object(glyph).override_failure_message(card_name).is_not_null()
		assert_object(glyph.texture).is_same(load(ArtCardView.glyph_path(aisle)))
		assert_str(glyph.tooltip_text).contains(aisle.display_name)
		var mark: Rect2 = glyph.get_global_rect()
		var art: Rect2 = view._art.get_global_rect()
		assert_vector(mark.size).is_equal(glyph.texture.get_size() * ArtCardView.GLYPH_SCALE)
		assert_bool(art.encloses(mark)).override_failure_message(card_name).is_true()
		assert_bool(mark.intersects(view._sticker.get_global_rect())).is_false()
		var sprite_middle: float = art.get_center().x + ArtCardView.ART_SPRITE_SIZE / 2.0
		assert_float(mark.position.x).is_greater_equal(sprite_middle)
	assert_int(checked).is_greater(0)
	# A staple (no aisle) and a coupon handed an aisle show no mark.
	var staple: ArtCardView = await _laid_out(load("%s/bread.tres" % CARDS), PackedStringArray())
	assert_bool(staple.has_band()).is_false()
	assert_object(staple.glyph()).is_null()
	var coupon: ArtCardView = await _laid_out(
		load("%s/repeat.tres" % CARDS), PackedStringArray(), balance.aisles[0]
	)
	assert_object(coupon.aisle).is_null()
	assert_bool(coupon.has_band()).is_false()
	assert_object(coupon.glyph()).is_null()


func _laid_out(
	definition: CardDefinition, extra_tags: PackedStringArray, aisle: AisleDefinition = null
) -> ArtCardView:
	var view: ArtCardView = auto_free(ArtCardView.new(CardInstance.new(definition, 1), aisle))
	add_child(view)
	if definition.is_product():
		for tag: String in extra_tags:
			view.add_tag(tag)
	await get_tree().process_frame
	await get_tree().process_frame
	return view


func _cards() -> Array[CardDefinition]:
	var result: Array[CardDefinition] = []
	for file: String in DirAccess.get_files_at(CARDS):
		if file.ends_with(".tres"):
			result.append(load("%s/%s" % [CARDS, file]) as CardDefinition)
	return result


## Every tag a coupon can grant (Breakfast sticker's Breakfast, Clearance tag's Clearance). A
## product gains at most one of them while scoring, so the fit test lays out each one in turn.
static func _grantable_tags(definitions: Array[CardDefinition]) -> PackedStringArray:
	var tags: PackedStringArray = PackedStringArray()
	for definition: CardDefinition in definitions:
		for rule: Rule in definition.rules:
			var grant: GrantTagToNextSlotRule = rule as GrantTagToNextSlotRule
			if grant != null and grant.tag != "" and not tags.has(grant.tag):
				tags.append(grant.tag)
	return tags
