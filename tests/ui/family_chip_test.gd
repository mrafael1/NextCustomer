extends GdUnitTestSuite
## The scanner bay's family chip (#105 piece 2, FamilyChip): what every card's chip says (a family,
## a card, the item itself, both halves of a split ticket, or COUPON), in its ticket's first
## family's colour, with the family's glyph for a one-family ticket and the colour's tooltip; a
## word on paper (show_text) takes the colour, the glyph and the tooltip off.

const CARDS := "res://data/cards"


## Every card's chip text by its ticket: COUPON for none, "A + B" (upper case) for a split ticket,
## the subject for a card's or the item's own colour, else the family's name; the live cards have
## every kind but the split (a coupon, a family, a card or the item).
func test_every_cards_chip_says_what_its_ticket_works_with() -> void:
	var palette: FamilyPalette = FamilyPalette.shared()
	var kinds: Dictionary[String, int] = {}
	for definition: CardDefinition in _cards():
		var ids: PackedStringArray = palette.ticket_families(definition)
		var text: String = FamilyChip.item_text(definition)
		var message: String = "%s: '%s'" % [definition.id, text]
		assert_str(text).override_failure_message(message).is_equal(text.to_upper())
		assert_str(text).override_failure_message(message).is_not_empty()
		var kind: String = "family"
		if ids.is_empty():
			kind = "coupon"
			assert_str(text).override_failure_message(message).is_equal(FamilyChip.COUPON_TEXT)
		elif ids.size() > 1:
			kind = "split"
			var split: String = (
				FamilyChip.SPLIT_TEXT % [palette.display_name(ids[0]), palette.display_name(ids[1])]
			)
			assert_str(text).override_failure_message(message).is_equal(split.to_upper())
		else:
			var why: CardFamilies.Why = palette.colour_reason(definition)
			if why.reason == CardFamilies.Reason.CARD or why.reason == CardFamilies.Reason.SAME:
				kind = "subject"
				assert_str(text).override_failure_message(message).is_equal(why.subject.to_upper())
			else:
				var family: String = palette.display_name(ids[0]).to_upper()
				assert_str(text).override_failure_message(message).is_equal(family)
		kinds[kind] = kinds.get(kind, 0) + 1
	prints("#105 chip kinds:", kinds)
	for kind: String in ["coupon", "family", "subject"]:
		assert_int(kinds.get(kind, 0)).override_failure_message(kind).is_greater(0)


## A card's chip: its text, the first family's face and light (paper for a coupon), the glyph only
## for a one-family ticket, the colour's tooltip; show_text puts a word on paper with no glyph or
## tooltip.
func test_the_chip_takes_its_tickets_colour_and_a_word_takes_it_off() -> void:
	var palette: FamilyPalette = FamilyPalette.shared()
	var chip: FamilyChip = auto_free(FamilyChip.new())
	get_tree().root.add_child(chip)
	for definition: CardDefinition in _cards():
		chip.show_item(definition)
		var message: String = String(definition.id)
		var ids: PackedStringArray = palette.ticket_families(definition)
		assert_str(chip.chip_text()).is_equal(FamilyChip.item_text(definition))
		assert_str(chip.tip_text).override_failure_message(message).is_not_empty()
		var face: Color = Palette.PAPER
		if not ids.is_empty() and palette.style(ids[0]).has_ticket_colours():
			face = palette.style(ids[0]).face
		assert_that(chip.face_color()).override_failure_message(message).is_equal(face)
		var glyph: bool = ids.size() == 1 and palette.style(ids[0]).glyph != null
		assert_bool(chip.glyph_sprite().visible).override_failure_message(message).is_equal(glyph)
		if glyph:
			assert_object(chip.glyph_sprite().texture).is_same(palette.style(ids[0]).glyph)
	chip.show_text(ScannerBay.END_NAME)
	assert_str(chip.chip_text()).is_equal(ScannerBay.END_NAME)
	assert_that(chip.face_color()).is_equal(Palette.PAPER)
	assert_bool(chip.glyph_sprite().visible).is_false()
	assert_str(chip.tip_text).is_empty()
	assert_vector(chip.size).is_equal(FamilyChip.SIZE)


static func _cards() -> Array[CardDefinition]:
	var cards: Array[CardDefinition] = []
	for file_name: String in DirAccess.get_files_at(CARDS):
		if file_name.ends_with(".tres"):
			cards.append(load(CARDS.path_join(file_name)) as CardDefinition)
	return cards
