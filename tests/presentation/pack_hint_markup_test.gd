extends GdUnitTestSuite
## A starter pack's hint as HandbookMarkup (PackHintMarkup, the cart and run info polish,
## 2026-11-12): every pack's hint keeps its words, names only known terms, and marks its
## keywords, its cards (a plural item, a coupon whose name holds digits) and the families.

const PACKS := "res://data/starter_packs"


func test_every_pack_hint_keeps_its_words_and_names_known_terms() -> void:
	var packs: int = 0
	for path: String in DirAccess.get_files_at(PACKS):
		if not path.ends_with(".tres"):
			continue
		packs += 1
		var pack: StarterPackDefinition = load(PACKS.path_join(path))
		var markup: String = RunInfoHero.hint_markup(pack)
		assert_str(HandbookMarkup.plain(markup)).override_failure_message(path).is_equal(
			pack.hint_text
		)
		(
			assert_array(HandbookMarkup.unknown_tokens(markup))
			. override_failure_message(path)
			. is_empty()
		)
		assert_str(markup).override_failure_message(path).contains(HandbookMarkup.OPEN)
	assert_int(packs).is_greater(0)


func test_terms_are_marked_whole_and_longest_first() -> void:
	var cards: Array[CardDefinition] = [
		load("res://data/cards/banana.tres"),
		load("res://data/cards/two_for_one.tres"),
		load("res://data/cards/tea_bags_big.tres"),
	]
	var palette: FamilyPalette = FamilyPalette.shared()
	var families: Array[FamilyStyle] = palette.families
	(
		assert_str(
			PackHintMarkup.of(
				"4 Bananas in a row: 2 for 1 before Tea bags, MORNING Food. Bananarama.",
				cards,
				families
			)
		)
		. is_equal(
			(
				"4 {items:banana} in a row: {coupon:two_for_one} before {item:tea_bags},"
				+ " {kw:MORNING} {fam:Food}. Bananarama."
			)
		)
	)
