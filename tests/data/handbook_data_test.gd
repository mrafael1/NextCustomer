extends GdUnitTestSuite
## The staff handbook's data (v1.06, data/handbook): every word the cards print has an entry
## (every keyword chip a card's sticker draws, every family a card carries, every coupon offered),
## every entry is well formed (a known tab, a unique id, real cards and day events, every markup
## token naming something real), a keyword's rule names its keyword, and every example
## row's total is the real Scoring's (pinned in example_total, so a rule change shows up here).
## The guide feedback of 2026-11-11: the TIERS and SHIFT tabs are gone and nothing links to their
## pages; the families and the coupon intro have no example.

const CARDS_FOLDER := "res://data/cards"
## The tabs, in order.
const TABS: Array[StringName] = [&"keywords", &"families", &"coupons", &"place"]
## The pages the TIERS and SHIFT tabs held, and PLACES' BESIDE (round 4: "it is just pair re
## explained").
const REMOVED: Array[StringName] = [
	&"golden",
	&"big",
	&"spot_check",
	&"redraw",
	&"target",
	&"charge",
	&"gained",
	&"day_events",
	&"pl_beside",
]
## PLACES' pages, in order.
const PLACES: Array[StringName] = [
	&"pl_right_after", &"pl_next", &"pl_earlier", &"pl_lone", &"pl_slots"
]


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


func test_every_coupon_has_an_entry() -> void:
	var book: HandbookBook = _book()
	for card: CardDefinition in _cards():
		if card.is_coupon() and not card.is_connector:
			var found: HandbookEntry = book.entry_for_card(String(card.id))
			assert_object(found).override_failure_message(String(card.id)).is_not_null()


## The TIERS and SHIFT tabs and their pages are gone, and PLACES' BESIDE, and no tooltip leads
## there: a tier's chip, the GAINED or BESIDE word or a line that opens with an old page's title
## finds no entry.
func test_the_removed_pages_are_unreachable() -> void:
	var book: HandbookBook = _book()
	assert_array(book.group_ids).is_equal(TABS)
	assert_array(Array(book.group_titles)).is_equal(["KEYWORDS", "FAMILIES", "COUPONS", "PLACES"])
	for removed: StringName in REMOVED:
		assert_object(book.entry(removed)).override_failure_message(removed).is_null()
	for card: CardDefinition in _cards():
		if card.tier != CardDefinition.Tier.PLAIN:
			var tier: String = PriceSticker.tier_text(card)
			assert_object(book.entry_for_keyword(tier)).override_failure_message(tier).is_null()
	assert_object(book.entry_for_keyword("GAINED")).is_null()
	assert_object(book.entry_for_keyword("BESIDE")).is_null()
	var places: Array[StringName] = []
	for entry: HandbookEntry in book.entries_in(&"place"):
		places.append(entry.id)
	assert_array(places).is_equal(PLACES)
	for line: String in [
		"Beside Milk: +3",
		"Spot check · slot 3 pays 0€",
		"Today's target is 65€",
		"Redraw · 2 left",
		"Charge unused",
		"Day events",
	]:
		assert_object(book.entry_titled(line)).override_failure_message(line).is_null()


## Every markup token in every entry names something real (HandbookMarkup), no brace is left
## over on the page (a token never closed shows raw), and the rules use the markup.
func test_every_markup_token_resolves() -> void:
	var used: int = 0
	for entry: HandbookEntry in _book().entries:
		var what: String = String(entry.id)
		var unknown: PackedStringArray = HandbookMarkup.unknown_tokens(entry.rule)
		assert_array(Array(unknown)).override_failure_message(what).is_empty()
		for shown: String in [HandbookMarkup.plain(entry.rule), entry.title]:
			(
				assert_bool(shown.contains("{") or shown.contains("}"))
				. override_failure_message(what)
				. is_false()
			)
		for run: HandbookMarkup.Run in HandbookMarkup.runs(entry.rule):
			if run.kind != HandbookMarkup.Kind.TEXT:
				used += 1
	assert_int(used).is_greater(0)


## A token shows its data's name; an unknown one shows plainly and is listed.
func test_markup_names_come_from_data() -> void:
	assert_str(HandbookMarkup.plain("{items:banana} and {item:cheese}")).is_equal(
		"Bananas and Cheese"
	)
	assert_str(HandbookMarkup.plain("{coupon:two_for_one}, {fam:Breakfast}, {kw:CHAIN}")).is_equal(
		"2 for 1, Breakfast, CHAIN"
	)
	var text: String = "{kw:NOPE} {item:two_for_one} {coupon:banana} {nothing} {x:y} ok"
	assert_str(HandbookMarkup.plain(text)).is_equal("NOPE two_for_one banana nothing x:y ok")
	assert_array(Array(HandbookMarkup.unknown_tokens(text))).is_equal(
		["{kw:NOPE}", "{item:two_for_one}", "{coupon:banana}", "{nothing}", "{x:y}"]
	)


## A family's page and the coupon intro only describe: no example, so no clip and no equation.
func test_families_and_the_coupon_intro_have_no_example() -> void:
	var book: HandbookBook = _book()
	var plain: Array[HandbookEntry] = book.entries_in(&"families")
	plain.append(book.entry(&"coupon"))
	assert_int(plain.size()).is_equal(10)
	for entry: HandbookEntry in plain:
		assert_bool(entry.has_example()).override_failure_message(String(entry.id)).is_false()
		assert_bool(HandbookExample.of(entry).is_scored()).is_false()


func test_every_entry_is_well_formed() -> void:
	var book: HandbookBook = _book()
	assert_int(book.entries.size()).is_greater_equal(28)
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
		for card_id: String in entry.example_row:
			assert_object(lookup.card(card_id)).override_failure_message(card_id).is_not_null()
		for event_id: String in entry.example_events:
			var event: InspectionDefinition = lookup.inspection(event_id)
			assert_object(event).override_failure_message(event_id).is_not_null()
		# A Price gun relabel names a slot of the row (from 1) and a family the game draws.
		for relabel: String in entry.example_relabels:
			var parts: PackedStringArray = relabel.split(":")
			assert_int(parts.size()).override_failure_message(relabel).is_equal(2)
			var slot: int = parts[0].to_int()
			assert_bool(slot >= 1 and slot <= entry.example_row.size()).is_true()
			var style: FamilyStyle = FamilyPalette.shared().style(parts[1])
			assert_object(style).override_failure_message(relabel).is_not_null()
		assert_int(entry.example_quota).override_failure_message(what).is_greater_equal(0)
		if entry.example_quota > 0:
			assert_bool(entry.has_example()).override_failure_message(what).is_true()
	for group_id: StringName in book.group_ids:
		assert_array(book.entries_in(group_id)).override_failure_message(group_id).is_not_empty()


## A keyword's page explains its keyword in its own short words, naming it coloured ({kw:WORD}),
## and its chip's tooltip says exactly those words (the guide feedback of 2026-11-11, round 3:
## "change to match"): the tooltip is the plain text of the rule's first paragraph (a page may
## teach the belt's look after it, BATCH's caps).
func test_a_keywords_rule_is_its_tooltip() -> void:
	var book: HandbookBook = _book()
	for word: String in GlyphText.KEYWORD_TIPS:
		var entry: HandbookEntry = book.entry_for_keyword(word)
		assert_object(entry).override_failure_message(word).is_not_null()
		if entry == null:
			continue
		var rule: String = entry.tip_rule()
		assert_str(rule).override_failure_message(word).contains("{kw:%s}" % word)
		assert_str(GlyphText.keyword_tip(word)).override_failure_message(word).is_equal(
			HandbookMarkup.plain(rule)
		)


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


## The slip's paints (guide round 3): each card's name ITEM or COUPON, a payout MARKED only when it
## differs from its card's printed price, the total MARKED. MORNING: Milk's 24 and Coffee's 5 are
## changed (printed 4 and 2); Tea bags' 1, Bread's 5 and Potatoes' 3 are not.
func test_the_equation_parts_paint_names_and_changed_payouts() -> void:
	var example: HandbookExample = HandbookExample.of(_book().entry(&"morning"))
	var parts: Array[Array] = example.equation_parts()
	var shown: Array = []
	for part: Array in parts:
		if part[0] not in [HandbookExample.COMMA, HandbookExample.PLUS, HandbookExample.EQUALS]:
			shown.append(part)
	var item: HandbookExample.Paint = HandbookExample.Paint.ITEM
	var plain: HandbookExample.Paint = HandbookExample.Paint.PLAIN
	var marked: HandbookExample.Paint = HandbookExample.Paint.MARKED
	(
		assert_array(shown)
		. is_equal(
			[
				["Tea bags", item],
				["Bread", item],
				["Milk", item],
				["Potatoes", item],
				["Coffee", item],
				["1", plain],
				["5", plain],
				["24", marked],
				["3", plain],
				["5", marked],
				["38€", marked],
			]
		)
	)
	var two_for_one: HandbookExample = HandbookExample.of(_book().entry(&"two_for_one"))
	var coupons: int = 0
	for slot: int in range(two_for_one.cards.size()):
		if two_for_one.cards[slot].is_coupon():
			coupons += 1
			(
				assert_bool(
					(
						[two_for_one.cards[slot].display_name, HandbookExample.Paint.COUPON]
						in (two_for_one.equation_parts())
					)
				)
				. is_true()
			)
	assert_int(coupons).is_greater(0)


func test_the_mock_ups_worked_examples() -> void:
	var book: HandbookBook = _book()
	assert_str(HandbookExample.of(book.entry(&"chain")).equation()).is_equal(
		"Banana, Banana, Banana, Banana = 2 + 4 + 6 + 8 = 20€"
	)
	assert_str(HandbookExample.of(book.entry(&"morning")).equation()).is_equal(
		"Tea bags, Bread, Milk, Potatoes, Coffee = 1 + 5 + 24 + 3 + 5 = 38€"
	)


## BATCH's page teaches the bookends (2026-11-12, "guide need update"): the FIRST and LAST caps,
## the cap each job card lights (Croissant FIRST; Stale doughnut and Iced bun LAST, the icing
## drip; Baguette the foot band), the gold caps under a lit BATCH chip, a WASTED cap and a
## Shelf swap's split frame capping only the batch's real ends; its tooltip stays the first
## paragraph. The Bakery page names the caps too.
func test_the_batch_page_teaches_the_bookends() -> void:
	var book: HandbookBook = _book()
	var batch: HandbookEntry = book.entry_for_keyword(CardText.BATCH_WORD)
	var paragraphs: PackedStringArray = batch.rule.split(HandbookEntry.PARAGRAPH)
	assert_int(paragraphs.size()).is_equal(3)
	assert_str(batch.tip_rule()).is_equal(paragraphs[0])
	var caps: String = paragraphs[1]
	for words: String in [
		"FIRST on its left end",
		"LAST on its right end",
		"Hover a card",
		"{item:croissant} lights FIRST",
		"{item:stale_doughnut} and {item:iced_bun} light LAST",
		"icing drips",
		"{item:baguette} fills the frame's foot",
	]:
		assert_str(caps).override_failure_message(words).contains(words)
	var looks: String = paragraphs[2]
	for words: String in [
		"{kw:BATCH} chip turns both caps gold",
		"{kw:WASTED} card turns its cap red when you hover it",
		"{coupon:shelf_swap}",
		"only the batch's real first and last items get a cap",
	]:
		assert_str(looks).override_failure_message(words).contains(words)
	var tip: String = GlyphText.keyword_tip(CardText.BATCH_WORD)
	assert_bool(tip.contains("cap")).is_false()
	assert_str(book.entry_for_family("Bakery").rule).contains("a FIRST cap and a LAST cap")
