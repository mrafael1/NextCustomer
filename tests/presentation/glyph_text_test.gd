extends GdUnitTestSuite
## Sticker text with glyphs (GlyphText, #105): a family's name becomes its glyph, glued to the
## word before it (and to a count before that), and every live card's summary splits cleanly.

const CARDS_DIR := "res://data/cards"


func test_a_family_name_becomes_its_glyph() -> void:
	var runs: Array[Dictionary] = GlyphText.runs("+1 per earlier Breakfast", _palette())
	assert_array(runs).is_equal(
		[GlyphText.text_run("+1 per earlier "), GlyphText.glyph_run("Breakfast")]
	)


func test_the_coupon_word_is_the_coupon_mark() -> void:
	var families: PackedStringArray = GlyphText.families("+2 per earlier coupon", _palette())
	assert_array(Array(families)).is_equal(["Coupon"])
	var runs: Array[Dictionary] = GlyphText.runs("+2 per earlier coupon", _palette())
	assert_dict(runs.back()).is_equal(GlyphText.glyph_run("Coupon", "coupon"))
	assert_array(Array(GlyphText.families("+1 per earlier coupons", _palette()))).is_equal(
		["Coupon"]
	)


func test_plain_words_stay_text() -> void:
	var text: String = "×3 later with prior's tag"
	assert_array(GlyphText.runs(text, _palette())).is_equal([GlyphText.text_run(text)])
	# Matching is whole-word and case-sensitive, as cards write tags.
	assert_array(Array(GlyphText.families("+3 beside Foods breakfast", _palette()))).is_empty()


func test_a_glyph_is_glued_to_the_word_before_and_a_count() -> void:
	var pieces: Array[Array] = GlyphText.pieces("×2 next 2 Food", _palette())
	assert_int(pieces.size()).is_equal(2)
	assert_array(pieces[0]).is_equal([GlyphText.text_run("×2")])
	assert_array(pieces[1]).is_equal([GlyphText.text_run("next 2 "), GlyphText.glyph_run("Food")])
	var single: Array[Array] = GlyphText.pieces("+2 next Breakfast", _palette())
	assert_array(single[1]).is_equal(
		[GlyphText.text_run("next "), GlyphText.glyph_run("Breakfast")]
	)
	# "+2" is not a count to glue: only plain digits are.
	var signed: Array[Array] = GlyphText.pieces("+2 Food", _palette())
	assert_array(signed[0]).is_equal([GlyphText.text_run("+2 "), GlyphText.glyph_run("Food")])


func test_a_leading_glyph_and_punctuation() -> void:
	var pieces: Array[Array] = GlyphText.pieces("Dairy, then Snack.", _palette())
	assert_array(pieces[0]).is_equal([GlyphText.glyph_run("Dairy"), GlyphText.text_run(",")])
	assert_array(pieces[1]).is_equal(
		[GlyphText.text_run("then "), GlyphText.glyph_run("Snack"), GlyphText.text_run(".")]
	)
	(
		assert_array(GlyphText.runs("Dairy, then Snack.", _palette()))
		. is_equal(
			[
				GlyphText.glyph_run("Dairy"),
				GlyphText.text_run(", then "),
				GlyphText.glyph_run("Snack"),
				GlyphText.text_run("."),
			]
		)
	)


func test_every_live_summary_splits_cleanly() -> void:
	var palette: FamilyPalette = _palette()
	var checked: int = 0
	for file: String in DirAccess.get_files_at(CARDS_DIR):
		if not file.ends_with(".tres"):
			continue
		var card: CardDefinition = load("%s/%s" % [CARDS_DIR, file])
		var summary: String = card.sticker_summary()
		if summary.is_empty():
			continue
		checked += 1
		var rebuilt: String = ""
		for run: Dictionary in GlyphText.runs(summary, palette):
			rebuilt += str(run["text"])
			assert_bool(str(run["text"]).contains("{")).override_failure_message(summary).is_false()
		# Glyphs replace exactly the words they name: nothing is lost or added.
		assert_str(rebuilt).override_failure_message(String(card.id)).is_equal(summary)
	assert_int(checked).is_greater(100)


func test_live_summaries_draw_the_expected_glyphs() -> void:
	var expected: Dictionary[String, Array] = {
		"milk": ["Breakfast"],
		"scissors": ["Coupon"],
		"multipack": [],
		"eggs_golden": ["Food"],
		"breakfast_sticker": ["Breakfast"],
	}
	for id: String in expected:
		var card: CardDefinition = FamilyPalette.data_card(id)
		var families: PackedStringArray = GlyphText.families(card.sticker_summary(), _palette())
		assert_array(Array(families)).override_failure_message(id).is_equal(expected[id])
	var golden_eggs: String = FamilyPalette.data_card("eggs_golden").sticker_summary()
	var last: Array = GlyphText.pieces(golden_eggs, _palette()).back()
	assert_str(str((last[0] as Dictionary)["text"])).is_equal("next 2 ")


func _palette() -> FamilyPalette:
	return FamilyPalette.shared()
