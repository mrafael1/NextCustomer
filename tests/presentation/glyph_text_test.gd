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


## The BATCH keyword (#128) is a keyword run glued to the plain word after it, never a glyph; a
## keyword with punctuation keeps it as text in its piece.
func test_the_batch_keyword_is_a_chip_glued_to_the_next_word() -> void:
	var pieces: Array[Array] = GlyphText.pieces("BATCH 1st: +2 to the rest", _palette())
	assert_array(pieces[0]).is_equal(
		[GlyphText.keyword_run(CardText.BATCH_WORD), GlyphText.text_run(" 1st:")]
	)
	assert_int(pieces.size()).is_equal(5)
	assert_array(Array(GlyphText.keywords("BATCH 1st: +2", _palette()))).is_equal(["BATCH"])
	assert_array(Array(GlyphText.families("BATCH 1st: +2", _palette()))).is_empty()
	var later: Array[Array] = GlyphText.pieces("+3 each, next BATCH of 3+", _palette())
	assert_array(later[3]).is_equal(
		[GlyphText.keyword_run(CardText.BATCH_WORD), GlyphText.text_run(" of")]
	)
	var punctuated: Array[Array] = GlyphText.pieces("next BATCH.", _palette())
	assert_array(punctuated[1]).is_equal(
		[GlyphText.keyword_run(CardText.BATCH_WORD), GlyphText.text_run(".")]
	)
	assert_bool(GlyphText.is_text(GlyphText.keyword_run("BATCH"))).is_false()
	assert_bool(GlyphText.is_glyph(GlyphText.keyword_run("BATCH"))).is_false()
	# Only the keyword itself, in capitals: "batch" stays a word.
	assert_array(Array(GlyphText.keywords("2 per batch", _palette()))).is_empty()
	assert_str(GlyphText.keyword_tip("BATCH")).is_equal(
		(
			"Put Bakery items side by side to make a BATCH: the bigger it is, the more each "
			+ "item earns. Some cards care about their spot in it: Croissant first, Stale "
			+ "doughnut last."
		)
	)


## The CHAIN keyword (#128 Produce links) is a chip like BATCH, glued to the word after it, with
## its own tooltip.
func test_the_chain_keyword_is_a_chip() -> void:
	var pieces: Array[Array] = GlyphText.pieces("CHAIN middle: ×2 prev", _palette())
	assert_array(pieces[0]).is_equal(
		[GlyphText.keyword_run(CardText.CHAIN_WORD), GlyphText.text_run(" middle:")]
	)
	assert_array(Array(GlyphText.keywords("+1 each, next CHAIN", _palette()))).is_equal(["CHAIN"])
	assert_str(GlyphText.keyword_tip("CHAIN")).is_equal(
		(
			"Put Bananas side by side to make a CHAIN. Each Banana adds the price of "
			+ "the one before it, so longer chains pay more."
		)
	)
	assert_str(GlyphText.keyword_tip("NOPE")).is_empty()


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


## A batch role's word (#128 batch polish: FIRST, LAST) is a role run in the Bakery colour, glued
## to the plain word after it; GlyphLabel draws it in the family's darkened shade on light paper.
func test_a_role_word_is_a_bakery_run_drawn_in_its_colour() -> void:
	var line: String = "FIRST in BATCH: +2 to the rest"
	var pieces: Array[Array] = GlyphText.pieces(line, _palette())
	assert_array(pieces[0]).is_equal(
		[GlyphText.role_run(CardText.FIRST_WORD), GlyphText.text_run(" in")]
	)
	assert_str(GlyphText.role_family(pieces[0][0] as Dictionary)).is_equal("Bakery")
	assert_array(Array(GlyphText.roles("×2 the LAST in BATCH", _palette()))).is_equal(["LAST"])
	# Only the capital words: "the last" stays text.
	assert_array(Array(GlyphText.roles("×2 the last", _palette()))).is_empty()
	var label: GlyphLabel = auto_free(
		GlyphLabel.new(line, ThemeDB.fallback_font, 14, Palette.INK, 16.0, 200.0)
	)
	var drawn: Array[Dictionary] = label.role_runs()
	assert_int(drawn.size()).is_equal(1)
	assert_str(str(drawn[0]["text"])).is_equal("FIRST")
	var bakery: FamilyStyle = _palette().style("Bakery")
	assert_that(drawn[0]["color"]).is_equal(bakery.shade.darkened(GlyphLabel.ROLE_DARKEN))
	assert_that(drawn[0]["color"]).is_not_equal(label.color())


## A bonus amount ("+4€", "+2" after a keyword) is drawn in the monitor's bonus green (v1.43); a
## lone "+" and a count stay the text's ink.
func test_a_bonus_amount_is_drawn_in_the_monitors_green() -> void:
	var label: GlyphLabel = auto_free(
		GlyphLabel.new(
			"+4€ if beside Soup, BATCH +2 to + 3 more",
			ThemeDB.fallback_font,
			14,
			Palette.INK,
			16.0,
			400.0
		)
	)
	var drawn: Array[Dictionary] = label.role_runs(true)
	(
		assert_array(drawn.map(func(run: Dictionary) -> String: return str(run["text"])))
		. is_equal(["+4€", "+2"])
	)
	for run: Dictionary in drawn:
		assert_that(run["color"]).is_equal(MonitorStepRow.BONUS_COLOR)


## A factor ("×2", "×5") is drawn in the monitor's ink for its strength step (v1.43).
func test_a_factor_is_drawn_in_the_monitors_ink_for_its_step() -> void:
	var label: GlyphLabel = auto_free(
		GlyphLabel.new(
			"×1.5 next Snack, ×2 the LAST, ×3 more, ×5 all.",
			ThemeDB.fallback_font,
			14,
			Palette.INK,
			16.0,
			400.0
		)
	)
	var drawn: Array[Dictionary] = label.role_runs(true)
	assert_int(drawn.size()).is_equal(4)
	var steps: Array[int] = []
	for run: Dictionary in drawn:
		var step: int = MonitorStepRow.factor_step(str(run["text"]))
		steps.append(step)
		assert_that(run["color"]).is_equal(MonitorStepRow.factor_ink(step))
	assert_array(steps).is_equal([0, 1, 2, 3])
	assert_str(str(drawn[3]["text"])).is_equal("×5")


## Wasted text stays fully grey, its amounts too (v1.43).
func test_a_wasted_texts_amounts_stay_grey() -> void:
	var label: GlyphLabel = auto_free(
		GlyphLabel.new("+3€ and ×2 the LAST", ThemeDB.fallback_font, 14, Palette.INK, 16.0, 400.0)
	)
	label.set_wasted("NO BATCH")
	var drawn: Array[Dictionary] = label.role_runs(true)
	assert_int(drawn.size()).is_equal(2)
	for run: Dictionary in drawn:
		assert_that(run["color"]).is_equal(GlyphLabel.WASTED_INK)
	label.set_wasted("")
	assert_that(label.role_runs(true)[0]["color"]).is_equal(MonitorStepRow.BONUS_COLOR)


func _palette() -> FamilyPalette:
	return FamilyPalette.shared()
