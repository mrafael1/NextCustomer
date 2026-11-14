extends GdUnitTestSuite
## The hover tips' words (the hover tips revamp, design B): TipMarkup's runs and auto markup,
## TipSpec's split of a plain tip into title and rule, its boxes (keywords and boxed words, at most
## MAX_SUBS, never the one it is about unless it is not working), and the approved wording (QUOTA,
## SHIFT: never TARGET, SPEND or BEAT).


func test_markup_reads_as_its_runs() -> void:
	var runs: Array[Dictionary] = TipMarkup.runs("Pays {x2} and {+5€}, [PAIR] <Dairy> ~row|ROW~")
	var kinds: Array = runs.map(func(run: Dictionary) -> int: return run["run"])
	(
		assert_array(kinds)
		. contains_exactly(
			[
				TipMarkup.Run.TEXT,
				TipMarkup.Run.PILL,
				TipMarkup.Run.TEXT,
				TipMarkup.Run.MONEY,
				TipMarkup.Run.TEXT,
				TipMarkup.Run.KEYWORD,
				TipMarkup.Run.TEXT,
				TipMarkup.Run.FAMILY,
				TipMarkup.Run.TEXT,
				TipMarkup.Run.TERM,
			]
		)
	)
	assert_str(TipMarkup.plain("Pays {x2} and {+5€}, [PAIR] <Dairy> ~row|ROW~")).is_equal(
		"Pays ×2 and +5€, PAIR Dairy row"
	)
	assert_int(TipMarkup.runs("{0€}")[0]["run"]).is_equal(TipMarkup.Run.ZERO)
	assert_int(TipMarkup.runs("[BATCH!]")[0]["run"]).is_equal(TipMarkup.Run.KEYWORD_BAD)
	assert_array(Array(TipMarkup.subs_of("[PAIR] then ~row|ROW~ and [PAIR] again"))).is_equal(
		["PAIR", "ROW"]
	)


## auto() marks money, counts, keywords, a family's capitalised name and the first boxed word;
## marked-up text stays as it is.
func test_auto_marks_up_plain_words() -> void:
	assert_str(TipMarkup.auto("Bakery items +2€, quota +10%")).is_equal(
		"<Bakery> items {+2€}, ~quota|QUOTA~ {+10%}"
	)
	assert_str(TipMarkup.auto("the row and the row")).is_equal("the ~row|ROW~ and the row")
	assert_str(TipMarkup.auto("Already {x2}")).is_equal("Already {x2}")
	assert_str(TipMarkup.auto("")).is_empty()


## A plain tip splits into its title and its rule (as sentences); a long first part is the rule.
func test_a_plain_tip_splits_into_title_and_rule() -> void:
	var tip: TipSpec = TipSpec.from_text("PRICE GUN · Click the gun · then an item")
	assert_str(tip.title).is_equal("PRICE GUN")
	assert_str(tip.body).is_equal("Click the gun. Then an item.")
	var lines: TipSpec = TipSpec.from_text("Silver medal\nScore 130€ in one shift.\nReady.")
	assert_str(lines.title).is_equal("Silver medal")
	assert_str(lines.body).is_equal("Score 130€ in one shift. Ready.")
	var long: TipSpec = TipSpec.from_text("A first part far too long to be a title · and more")
	assert_str(long.title).is_empty()
	assert_str(TipSpec.from_text("Menu").title).is_equal("Menu")


## Its boxes: the keywords and boxed words it names, at most MAX_SUBS, without the one it is
## about, unless the tip says that one is not working.
func test_a_tip_shows_its_boxes() -> void:
	var tip: TipSpec = TipSpec.make(TipSpec.Kind.PERK, "Coupon engine", "The first ~coupon|COUPON~")
	tip.cond = "In the ~row|ROW~, by the [PAIR] and ~quota|QUOTA~"
	assert_array(Array(tip.shown_subs())).is_equal(["COUPON", "ROW"])
	var about: TipSpec = TipSpec.make(TipSpec.Kind.KEYWORD, "PAIR", "[PAIR] pays [BATCH]")
	assert_array(Array(about.shown_subs())).is_equal(["BATCH"])
	var broken: TipSpec = TipSpec.make(TipSpec.Kind.BROKEN, "BATCH NOT WORKING", "[BATCH!] waits")
	assert_array(Array(broken.shown_subs())).is_equal(["BATCH"])
	broken.subs = PackedStringArray(["QUOTA"])
	assert_array(Array(broken.shown_subs())).is_equal(["QUOTA"])


## The approved words: the medals', the boxed words' and the chutes' tips say QUOTA and SHIFT,
## never TARGET, SPEND or BEAT.
func test_sentence_case_capitalises_only_the_first_letter() -> void:
	assert_str(TipMarkup.sentence_case("SPOT CHECK")).is_equal("Spot check")
	assert_str(TipMarkup.sentence_case("WRITTEN OFF")).is_equal("Written off")
	assert_str(TipMarkup.sentence_case("")).is_equal("")


func test_the_tips_use_the_approved_words() -> void:
	var texts: Array[String] = [
		OvertimeWords.medal_tip(null, false, OvertimeWords.STATE_AVAILABLE, 130),
		OvertimeWords.medal_tip(null, true, OvertimeWords.STATE_USED, 195),
		OvertimeWords.STATE_PENDING,
		OvertimeWords.STATE_LAST,
	]
	for key: String in TipWords.WORDS:
		texts.append(str(TipWords.WORDS[key][1]))
	texts.append_array(ChuteKey.TIPS)
	for text: String in texts:
		for banned: String in ["target", "spend", "spent", "beat"]:
			assert_bool(text.to_lower().contains(banned)).override_failure_message(text).is_false()
	assert_str(texts[0]).contains("130€").contains("quota").contains("shift")
