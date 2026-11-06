extends GdUnitTestSuite
## The staff handbook's data (v1.06, data/handbook): every word the cards print has an entry
## (every keyword chip a card's sticker draws, every family a card carries, every coupon offered,
## both tiers), every entry is well formed (a known tab, a unique id, real cards and day events),
## a keyword's rule is its tooltip's meaning, and every example row's total is the real Scoring's
## (pinned in example_total, so a rule change shows up here).

const CARDS_FOLDER := "res://data/cards"


func _book() -> HandbookBook:
	return load(HandbookBook.PATH) as HandbookBook


static func _cards() -> Array[CardDefinition]:
	var found: Array[CardDefinition] = []
	for file_name: String in DirAccess.get_files_at(CARDS_FOLDER):
		if file_name.ends_with(".tres"):
			found.append(load(CARDS_FOLDER.path_join(file_name)) as CardDefinition)
	return found


func test_every_keyword_a_card_prints_has_an_entry() -> void:
	var book: HandbookBook = _book()
	var palette: FamilyPalette = FamilyPalette.shared()
	var seen: Dictionary[String, bool] = {}
	for card: CardDefinition in _cards():
		for word: String in GlyphText.keywords(CardText.sticker_summary(card), palette):
			seen[word] = true
	assert_array(seen.keys()).is_not_empty()
	for word: String in seen:
		assert_object(book.entry_for_keyword(word)).override_failure_message(word).is_not_null()
	for word: String in GlyphText.KEYWORD_TIPS:
		assert_object(book.entry_for_keyword(word)).override_failure_message(word).is_not_null()


func test_every_family_a_card_carries_has_an_entry() -> void:
	var book: HandbookBook = _book()
	var seen: Dictionary[String, bool] = {}
	for card: CardDefinition in _cards():
		for tag: String in card.tags:
			seen[tag] = true
	for style: FamilyStyle in FamilyPalette.shared().families:
		seen[style.id] = true
	for family: String in seen:
		assert_object(book.entry_for_family(family)).override_failure_message(family).is_not_null()


func test_every_coupon_and_tier_has_an_entry() -> void:
	var book: HandbookBook = _book()
	for card: CardDefinition in _cards():
		if card.is_coupon() and not card.is_connector:
			var found: HandbookEntry = book.entry_for_card(String(card.id))
			assert_object(found).override_failure_message(String(card.id)).is_not_null()
		if card.tier != CardDefinition.Tier.PLAIN:
			var tier: String = PriceSticker.tier_text(card)
			assert_object(book.entry_for_keyword(tier)).override_failure_message(tier).is_not_null()


func test_every_entry_is_well_formed() -> void:
	var book: HandbookBook = _book()
	assert_int(book.entries.size()).is_greater_equal(37)
	assert_int(book.group_titles.size()).is_equal(book.group_ids.size())
	assert_object(book.entry(book.first_entry)).is_not_null()
	var ids: Dictionary[StringName, bool] = {}
	var lookup: ContentLookup = ContentLookup.new(null)
	for entry: HandbookEntry in book.entries:
		var what: String = String(entry.id)
		assert_bool(ids.has(entry.id)).override_failure_message(what).is_false()
		ids[entry.id] = true
		assert_bool(book.group_ids.has(entry.group)).override_failure_message(what).is_true()
		assert_str(entry.title).override_failure_message(what).is_not_empty()
		assert_str(entry.rule).override_failure_message(what).is_not_empty()
		assert_int(entry.mark).override_failure_message(what).is_not_equal(HandbookEntry.Mark.NONE)
		if entry.mark == HandbookEntry.Mark.ICON:
			assert_object(entry.icon).override_failure_message(what).is_not_null()
		for card_id: String in Array(entry.example_row) + Array(entry.cards):
			assert_object(lookup.card(card_id)).override_failure_message(card_id).is_not_null()
		for event_id: String in entry.example_events:
			var event: InspectionDefinition = lookup.inspection(event_id)
			assert_object(event).override_failure_message(event_id).is_not_null()
	for group_id: StringName in book.group_ids:
		assert_array(book.entries_in(group_id)).override_failure_message(group_id).is_not_empty()


## A keyword's rule is its tooltip's meaning (GlyphText.keyword_tip after "WORD · "), so the
## handbook and the tickets never disagree.
func test_a_keywords_rule_is_its_tooltip() -> void:
	var book: HandbookBook = _book()
	for word: String in GlyphText.KEYWORD_TIPS:
		var tip: String = GlyphText.keyword_tip(word)
		assert_str(book.entry_for_keyword(word).rule).is_equal(tip.trim_prefix(word + " · "))


## Each example row scores, with the real Scoring, to its pinned total; the equation adds up.
func test_every_example_scores_its_pinned_total() -> void:
	for entry: HandbookEntry in _book().entries:
		if not entry.has_example():
			continue
		var example: HandbookExample = HandbookExample.of(entry)
		var what: String = String(entry.id)
		assert_bool(example.is_scored()).override_failure_message(what).is_true()
		assert_int(example.cards.size()).override_failure_message(what).is_equal(
			entry.example_row.size()
		)
		assert_int(example.total()).override_failure_message(what).is_equal(entry.example_total)
		var sum: int = 0
		for payout: int in example.payouts():
			sum += payout
		assert_int(sum).override_failure_message(what).is_equal(entry.example_total)
		assert_str(example.equation()).override_failure_message(what).ends_with(
			MonitorText.euros(entry.example_total)
		)


func test_the_mock_ups_worked_examples() -> void:
	var book: HandbookBook = _book()
	assert_str(HandbookExample.of(book.entry(&"chain")).equation()).is_equal(
		"Banana, Banana, Banana, Banana = 2 + 4 + 6 + 8 = 20€"
	)
	assert_str(HandbookExample.of(book.entry(&"morning")).equation()).is_equal(
		"Tea bags, Bread, Milk, Potatoes, Coffee = 1 + 5 + 24 + 3 + 5 = 38€"
	)
	assert_str(HandbookExample.of(book.entry(&"spot_check")).equation()).is_equal(
		"Bread, Eggs, Milk = 5 + 1 + 0 = 6€"
	)
	assert_bool(HandbookExample.of(book.entry(&"target")).is_scored()).is_false()
