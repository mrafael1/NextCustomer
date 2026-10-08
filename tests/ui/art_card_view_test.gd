extends GdUnitTestSuite
## The pixel-art card (full build plan section 6.1): every card in data/cards fits ArtCardView's
## fixed size with the real fonts, including every tag a coupon can grant it while scoring,
## and the fonts have every character the game prints. This is the test that sets
## ArtCardView.SIZE.y: a failure lists each card's spare pixels (negative when it overflows).

const CARDS := "res://data/cards"


func test_every_card_fits_the_art_card() -> void:
	var definitions: Array[CardDefinition] = _cards()
	assert_int(definitions.size()).is_greater(0)
	var granted: PackedStringArray = _grantable_tags(definitions)
	var spare: Dictionary[String, float] = {}
	var overflow: Array[String] = []
	for definition: CardDefinition in definitions:
		var view: ArtCardView = await _laid_out(definition, granted)
		var height: float = view._column.get_combined_minimum_size().y
		var available: float = ArtCardView.SIZE.y - 2.0 * view.padding().y
		spare[definition.display_name] = available - height
		var body: Rect2 = view.body.get_global_rect()
		var rule: Rect2 = view._rule_label.get_global_rect()
		var rule_label: Label = view._rule_label
		var clipped: bool = rule_label.get_visible_line_count() < rule_label.get_line_count()
		if height > available or clipped or not body.encloses(rule):
			overflow.append(definition.display_name)
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
			var sprite_middle: float = art.get_center().x + ArtCardView.ART_SPRITE_SIZE / 2.0
			assert_float(sticker.position.x).is_greater_equal(sprite_middle)
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


func _laid_out(definition: CardDefinition, extra_tags: PackedStringArray) -> ArtCardView:
	var view: ArtCardView = auto_free(ArtCardView.new(CardInstance.new(definition, 1)))
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


## Every tag a coupon can grant (Breakfast sticker's Breakfast): a product shows it beside the
## tags it prints, so the worst case is a product that gains them all.
static func _grantable_tags(definitions: Array[CardDefinition]) -> PackedStringArray:
	var tags: PackedStringArray = PackedStringArray()
	for definition: CardDefinition in definitions:
		for rule: Rule in definition.rules:
			var grant: GrantTagToNextSlotRule = rule as GrantTagToNextSlotRule
			if grant != null and grant.tag != "" and not tags.has(grant.tag):
				tags.append(grant.tag)
	return tags
