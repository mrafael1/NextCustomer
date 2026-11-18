extends GdUnitTestSuite
## The tutorial's script and text data (data/tutorial: the guided run with its free planning's
## retry and answer lines and reactive hints, the one-time tips and the quick tutorials R, P and
## SA; tutorial plan WP-3, reworked after play test 1, 2026-11-15, and cut by more than half
## after the play tests of 2026-11-16 and 2026-11-18, v1.40: "a lot of information, maybe even too
## much"). Every id, anchor, event, action and chip resolves; the filled lines equal the approved
## ones, so a card or balance change that breaks the answer's total fails here; every line passes
## the line checker (one short sentence, no word before it is taught, no avoided word); and the
## count of lines stays within the cut's budget.

## The approved lines, filled (chips marked **).
const APPROVED: Dictionary[String, String] = {
	"G3": "Open both **BOOSTERS**.",
	"G5": "Pick one **STARTER PACK**.",
	"G7": "Drag items into the row to reach the **QUOTA**: 30€.",
	"G8": "The order matters: hold the pointer on an item to read its rule.",
	"G10": "",
	"RETRY": "24€ is under the quota: try another order.",
	"ANSWER": "This order pays 36€: drag each item onto its ghost.",
	"combo": "This item's rule is working.",
	"wasted": "This item's rule does nothing here: try another spot.",
	"G15": "Bad items? Press **REDRAW**, then click a basket.",
	"T2": "A **COUPON** has no price: it changes the items around it.",
	"T6": "Today has a **DAY EVENT**: green helps, red makes the shift harder.",
	"T7": "**PAYDAY**: reach the quota today for better prizes.",
	"T9": "A **MISS**: no prize this time, and this week forgives only 2.",
	"T11": "Your perk sits here and lasts the whole run.",
	"T14": "Next time, put Eggs somewhere before your best Food item.",
	"T14 fallback": "Next time, try a new order before you press checkout.",
	"T15": "**COINS** buy toy capsules, from the title screen.",
	"R1": "**RESTOCK**: send back a booster you opened for a new one.",
	"P1": "You earned a **BADGE PIN**: wear it to change a rule for this run.",
	"SA1": "You can now swap one of your regulars: click the basket.",
	"swap_drag": "Drag a card onto a regular to swap them.",
}
## The guided run's steps, in order (they keep the ids of the 14-step script they were cut from;
## G15, the closing step, took the REDRAW tip's place), and the one-time tips'.
const GUIDED: Array[String] = ["G1", "G3", "G5", "G7", "G8", "G10", "G15"]
const TIPS: Array[String] = ["T2", "T6", "T7", "T9", "T11", "T14", "T15"]
## The cut's budget (v1.40; before it: 14 guided lines with the retry and answer lines, 18 hints,
## 16 tips, 3 callouts and 7 quick hints, 60 lines): the lines a new player can meet, at most.
const MAX_LINES := 24
## G1 follows the title's plate (the user's decision): START RUN on a fresh profile, NEW RUN with
## a saved run.
const G1_LINE := "Click %s."
const PLATES: Array[String] = ["START RUN", "NEW RUN"]
## The words tutorial_glossary.json says to avoid (its avoid_synonyms; BOOSTER is a word of its
## own on page 1, so "booster" is not avoided), and the phrases that hold an avoided word but are
## words of their own (the mock-up's EXEMPT).
const AVOID: Array[String] = [
	"day",
	"product",
	"hand",
	"belt",
	"base",
	"effect",
	"scan",
	"target",
	"spend",
	"beat",
	"next to",
	"side by side",
	"neighbours",
	"adjacency",
	"just before",
	"before it",
	"after it",
	"1st",
	"filled slot",
	"tag",
	"label",
	"category",
	"a banana pair",
	"frozen pair",
	"in a row",
	"fizzled",
	"written off",
	"binned",
	"upgrade",
	"step",
	"rare+",
	"deck",
	"run info",
	"malus",
	"boon",
	"inspection for good days",
	"manager's review",
	"final review",
	"slip",
	"short",
	"bonus ticket",
	"bonus draw",
	"again",
	"overtime",
	"upgrades",
	"register upgrades",
	"crate",
	"staples",
	"re-roll",
	"reroll",
]
const EXEMPT: Array[String] = [
	"DAY EVENT", "GOOD DAY", "RIGHT BEFORE", "RIGHT AFTER", "NEW ITEMS", "training WEEK"
]
const MAX_WORDS := 16
const MAX_SENTENCE := 16
## The boxes that were there before the tutorial (they keep their own words).
const OLD_BOXES: Array[String] = ["FAMILY", "ROW", "SLOT", "QUOTA", "PREMIUM", "COUPON"]
const BALANCE := "res://data/balance/balance.tres"

var _folder: String = ""


func before_test() -> void:
	# Nothing here saves or logs, but the event log and saves still point at a temporary folder.
	_folder = "user://test_tutorial_data_%d" % Time.get_ticks_usec()
	_event_log().use_folder(_folder)
	ProjectSettings.set_setting(SaveService.FOLDER_SETTING, _folder)


func after_test() -> void:
	ProjectSettings.set_setting(SaveService.FOLDER_SETTING, null)
	if DirAccess.dir_exists_absolute(_folder):
		for file_name: String in DirAccess.get_files_at(_folder):
			DirAccess.remove_absolute(_folder.path_join(file_name))
		DirAccess.remove_absolute(_folder)


func test_the_guided_run_is_its_seven_steps_in_order() -> void:
	var script: TutorialScript = TutorialScript.guided()
	var ids: Array[String] = []
	for k: int in script.steps.size():
		ids.append(String(script.steps[k].id))
		assert_int(script.index_of(script.steps[k].id)).is_equal(k)
	assert_array(ids).is_equal(GUIDED)
	assert_object(script.step(&"G10")).is_same(script.steps[5])
	assert_object(script.step(&"G99")).is_null()
	# G10 is shift 1's free planning: no line, every planning move.
	assert_int(script.free_index()).is_equal(5)
	for k: int in script.steps.size():
		assert_bool(script.steps[k].is_free()).override_failure_message(str(k)).is_equal(k == 5)
	assert_str(String(script.retry.id)).is_equal("RETRY")
	assert_str(String(script.answer_step.id)).is_equal("ANSWER")
	# The closing step shows on shift 2's planning and never forces a move.
	var closing: TutorialStep = script.steps[-1]
	assert_int(closing.screen).is_equal(TutorialStep.Screen.WEEK_CARD)
	assert_int(closing.gate).is_equal(TutorialStep.Gate.OPEN)
	assert_bool(closing.button_advances()).is_true()
	# Two reactive hints, about any card: the first rule that works, and a WASTED one.
	var whens: Array[int] = []
	for hint: PlanHint in script.hints:
		whens.append(hint.when)
		assert_str(hint.title).override_failure_message(String(hint.id)).is_not_empty()
		assert_bool(hint.card.is_empty()).override_failure_message(String(hint.id)).is_true()
	assert_array(whens).is_equal([PlanHint.When.FIRED, PlanHint.When.WASTED])


## The cut holds: every line a new player can meet, counted (a line added later has to make its
## case here), and none of them a rule's explanation of MORNING or the medals.
func test_the_lines_stay_within_the_cut() -> void:
	var count: int = 0
	for line: Array in _lines():
		var text: String = str(line[1])
		if text.is_empty():
			continue
		count += 1
		for word: String in ["MORNING", "SILVER", "GOLD", "medal"]:
			(
				assert_bool(text.contains(word))
				. override_failure_message("%s: %s" % [line[0], word])
				. is_false()
			)
	assert_int(count).is_less_equal(MAX_LINES)
	assert_int(count).is_equal(APPROVED.size())  # G1, the title line, for G10, which has none.
	assert_int(TipScheduler.PER_PLANNING).is_equal(1)


func test_tips_and_quick_tutorials_have_their_ids() -> void:
	var tips: TipList = TipList.shared()
	var tip_ids: Array[String] = []
	var triggers: Array[StringName] = []
	for k: int in tips.tips.size():
		tip_ids.append(String(tips.tips[k].id))
		assert_bool(TipDefinition.TRIGGERS.has(tips.tips[k].trigger)).is_true()
		assert_bool(triggers.has(tips.tips[k].trigger)).is_false()  # One tip per trigger.
		triggers.append(tips.tips[k].trigger)
		assert_int(tips.tips[k].priority).is_between(1, 6)
	assert_array(tip_ids).is_equal(TIPS)
	assert_array(triggers).contains_exactly_in_any_order(TipDefinition.TRIGGERS)
	assert_object(tips.tip(&"T6")).is_same(tips.tips[1])
	assert_str(String(tips.for_trigger(TipDefinition.DAY_EVENT)[0].id)).is_equal("T6")
	var quick: Array[QuickTutorial] = QuickTutorial.all()
	var ids: Array[StringName] = []
	for each: QuickTutorial in quick:
		ids.append(each.id)
		assert_bool(QuickTutorial.TRIGGERS.has(each.trigger)).is_true()
	# SWAP, then RESTOCK (both page 1), then BADGE PINS (page 2).
	assert_array(ids).is_equal(TutorialFlags.QUICK_IDS)
	var steps: Array[String] = []
	for each: QuickTutorial in quick:
		for step: TutorialStep in each.steps:
			steps.append(String(step.id))
	# One callout each (play test 1, 2026-11-15), and one hint in all: SWAP's drag (v1.40).
	assert_array(steps).is_equal(["SA1", "R1", "P1"])
	(
		assert_array(quick.map(func(each: QuickTutorial) -> int: return each.hints.size()))
		. is_equal([1, 0, 0])
	)
	for each: QuickTutorial in quick:
		for hint: QuickHint in each.hints:
			(
				assert_bool(TutorialEvents.ARGS.has(hint.event))
				. override_failure_message(hint.id)
				. is_true()
			)
			var anchor: StringName = hint.anchor_for({})
			(
				assert_bool(TutorialAnchors.is_known(anchor))
				. override_failure_message(hint.id)
				. is_true()
			)
	var every: Array[String] = []
	for line: Array in _lines():
		assert_bool(every.has(str(line[0]))).override_failure_message(str(line[0])).is_false()
		every.append(str(line[0]))


func test_every_ring_and_lock_is_an_anchor() -> void:
	for step: TutorialStep in _steps():
		for anchor: StringName in step.rings + step.locks + step.keep_clear:
			(
				assert_bool(TutorialAnchors.is_known(anchor))
				. override_failure_message("%s: %s" % [step.id, anchor])
				. is_true()
			)
		assert_int(step.act).override_failure_message(step.id).is_between(-1, step.rings.size() - 1)
		if not step.rings.is_empty():
			assert_int(step.point).is_between(0, step.rings.size() - 1)
		# A step whose move is the ring's shows "CLICK THE RING" and moves on by an event.
		if step.footer == TutorialStep.Footer.RING:
			assert_int(step.act).override_failure_message(step.id).is_not_equal(-1)
	for tip: TipDefinition in TipList.shared().tips:
		for anchor: StringName in tip.rings:
			assert_bool(TutorialAnchors.is_known(anchor)).override_failure_message(tip.id).is_true()


func test_events_and_actions_are_the_contracts() -> void:
	for step: TutorialStep in _steps():
		for event: StringName in [step.advance_on, step.back_out_on]:
			if not event.is_empty():
				(
					assert_bool(TutorialEvents.is_event(event))
					. override_failure_message("%s: %s" % [step.id, event])
					. is_true()
				)
		for action: StringName in step.allow:
			(
				assert_bool(TutorialActions.is_action(action))
				. override_failure_message("%s: %s" % [step.id, action])
				. is_true()
			)
		for hit: StringName in step.allow_ids + step.refuse_ids:
			assert_bool(TutorialAnchors.is_known(hit)).override_failure_message(step.id).is_true()
		assert_int(step.advance_count).is_greater(0)
		assert_bool(step.button_advances() or not step.advance_on.is_empty()).is_true()
	# The guided run's start and planning steps only allow their move; the machine's and the
	# quick tutorials' never force one.
	for step: TutorialStep in TutorialScript.guided().steps:
		var forced: bool = (
			step.screen
			in [
				TutorialStep.Screen.START_STOCK,
				TutorialStep.Screen.START_BUILD,
				TutorialStep.Screen.PLANNING,
			]
		)
		assert_bool(step.gate == TutorialStep.Gate.ONLY).override_failure_message(step.id).is_equal(
			forced
		)
	for each: QuickTutorial in QuickTutorial.all():
		for step: TutorialStep in each.steps:
			assert_int(step.gate).is_equal(TutorialStep.Gate.OPEN)


func test_every_chip_and_taught_word_has_a_box() -> void:
	for line: Array in _lines():
		for form: String in TutorialText.chips(str(line[1])):
			var key: String = TutorialText.chip_key(form)
			assert_str(key).override_failure_message("%s: %s" % [line[0], form]).is_not_empty()
			assert_bool(TipWords.has(key)).override_failure_message(key).is_true()
		for key: String in TipMarkup.subs_of(TutorialText.markup(str(line[1]))):
			assert_bool(TipWords.has(key)).override_failure_message(key).is_true()
	for taught: Array in _taught_lists():
		for key: String in taught[1]:
			(
				assert_bool(TipWords.has(key))
				. override_failure_message("%s: %s" % [taught[0], key])
				. is_true()
			)
	for key: String in TutorialText.CHIP_KEYS.values():
		assert_bool(TipWords.has(key)).override_failure_message(key).is_true()


func test_every_more_page_resolves() -> void:
	var book: HandbookBook = HandbookBook.shared()
	var pages: Array[StringName] = []
	for tip: TipDefinition in TipList.shared().tips:
		pages.append(tip.more_page)
	for each: QuickTutorial in QuickTutorial.all():
		pages.append(each.more_page)
	for page: StringName in pages:
		if page.is_empty() or String(page).begins_with(TipDefinition.TOYS_PREFIX):
			continue
		assert_bool(book.entry(page) != null).override_failure_message(page).is_true()
	assert_bool(TipList.shared().tip(&"T15").more_in_toys()).is_true()
	assert_bool(TipList.shared().tip(&"T2").more_in_toys()).is_false()
	assert_str(String(TipList.shared().tip(&"T11").more_page)).is_empty()


func test_the_filled_lines_are_the_approved_lines() -> void:
	var filled: Dictionary[String, String] = {}
	for line: Array in _lines():
		filled[str(line[0])] = TutorialText.fill(str(line[1]), _values())
	for id: String in APPROVED:
		assert_str(filled.get(id, "")).override_failure_message(id).is_equal(APPROVED[id])
	for plate: String in PLATES:
		var values: Dictionary = _values()
		values[TutorialText.PRIMARY] = plate
		var g1: String = TutorialScript.guided().step(&"G1").text
		assert_str(TutorialText.fill(g1, values)).is_equal(G1_LINE % plate)
	# Pantry, not Produce (the user's decision): no line names the Produce booster's cards.
	for id: String in filled:
		assert_bool(filled[id].contains("Produce")).is_false()
		assert_bool(filled[id].contains("Potatoes")).is_false()


func test_every_placeholder_is_filled_from_data_or_live() -> void:
	var values: Dictionary = _values()
	for line: Array in _lines():
		var text: String = TutorialText.fill(str(line[1]), values)
		assert_bool(text.contains("{")).override_failure_message(text).is_false()
		assert_bool(text.contains("}")).override_failure_message(text).is_false()
	var from_data: Dictionary[String, String] = TutorialText.values(
		TutorialScript.guided(), _balance()
	)
	for live: String in [
		TutorialText.PRIMARY,
		TutorialText.WASTED_CARD,
		TutorialText.WASTED_FAMILY,
		TutorialText.MISSED,
	]:
		assert_bool(from_data.has(live)).override_failure_message(live).is_false()
	assert_array(TutorialText.placeholders("a {x} b {y} {x}")).is_equal(
		PackedStringArray(["x", "y"])
	)
	assert_str(TutorialText.fill("{x}, {z}", {"x": "1"})).is_equal("1, {z}")


func test_the_figures_are_the_rules_and_the_balance() -> void:
	var balance: BalanceDefinition = _balance()
	var values: Dictionary[String, String] = TutorialText.values(TutorialScript.guided(), balance)
	assert_str(values["quota"]).is_equal(str(balance.quotas[0]))
	assert_str(values["misses"]).is_equal(str(balance.write_up_limit))
	# The answer row meets the shift 1 quota.
	assert_int(int(values["answer_total"])).is_greater_equal(balance.quotas[0])


func test_every_line_passes_the_line_checker() -> void:
	var taught_at: Dictionary[String, int] = {}
	var order: Array[Array] = _taught_lists()
	for k: int in order.size():
		for key: String in order[k][1]:
			if not taught_at.has(key):
				taught_at[key] = k
	var values: Dictionary = _values()
	for line: Array in _lines():
		var at: int = int(line[2])
		var issues: PackedStringArray = _check(
			TutorialText.fill(str(line[1]), values), at, taught_at
		)
		(
			assert_array(Array(issues))
			. override_failure_message("%s: %s" % [line[0], ", ".join(issues)])
			. is_empty()
		)


## The checker catches what it is for: a long line, a long sentence, a word used before it is
## taught and an avoided word.
func test_the_line_checker_flags_what_the_page_flags() -> void:
	var taught: Dictionary[String, int] = {"QUOTA": 5}
	assert_array(Array(_check("Reach the **QUOTA** today.", 9, taught))).is_empty()
	assert_array(Array(_check("Reach the **QUOTA**.", 2, taught))).has_size(1)
	assert_array(Array(_check("Your hand is here.", 9, taught))).has_size(1)
	assert_array(Array(_check("Each GOOD DAY is fine.", 9, taught))).is_empty()
	var long: String = " ".join(
		PackedStringArray(range(17).map(func(_n: int) -> String: return "go"))
	)
	# Over the line's words and over a sentence's (the same limit since v1.40: one sentence).
	assert_array(Array(_check(long + ".", 9, taught))).has_size(2)


func test_the_hand_and_rows_fit_the_guided_shift() -> void:
	var script: TutorialScript = TutorialScript.guided()
	var balance: BalanceDefinition = _balance()
	assert_int(script.hand.size()).is_equal(balance.hand_size)
	for card_id: StringName in script.hand:
		assert_bool(ResourceLoader.exists("res://data/cards/%s.tres" % card_id)).is_true()
	for step: TutorialStep in script.steps:
		for card_id: StringName in step.allow_cards:
			assert_bool(script.hand.has(card_id)).override_failure_message(step.id).is_true()
		# A hand place it rings holds a card it lets the player move.
		for anchor: StringName in step.rings:
			var place: int = TutorialAnchors.index_of(anchor, TutorialAnchors.HAND)
			if place >= 0 and not step.allow_cards.is_empty():
				(
					assert_bool(step.allow_cards.has(script.hand[place]))
					. override_failure_message("%s: %s" % [step.id, anchor])
					. is_true()
				)
	# The answer fills the row from the hand and leaves one card in its basket.
	assert_int(script.answer.size()).is_equal(balance.slot_count)
	for card_id: StringName in script.answer:
		assert_int(script.answer.count(card_id)).is_less_equal(script.hand.count(card_id))
	assert_bool(script.answer.has(script.hand[6])).is_false()
	assert_int(script.place_of(&"banana", 1)).is_equal(1)
	assert_int(script.place_of(&"potatoes")).is_equal(-1)


func test_the_gate_allows_only_the_steps_move() -> void:
	var script: TutorialScript = TutorialScript.guided()
	# G10, the free planning (and its retry and answer lines): any card anywhere, REDRAW and its
	# baskets, CHECKOUT, the cart and the calendar.
	for step: TutorialStep in [script.step(&"G10"), script.retry, script.answer_step]:
		assert_bool(step.allows(TutorialActions.PICK_CARD, _card(&"tea_bags", false))).is_true()
		assert_bool(step.allows(TutorialActions.PLACE_CARD, _placed(&"eggs", 5))).is_true()
		assert_bool(step.allows(TutorialActions.CHECKOUT)).is_true()
		assert_bool(step.allows(TutorialActions.OPEN_DECK)).is_true()
		assert_bool(step.allows(TutorialActions.REDRAW)).is_true()
		assert_bool(step.allows(TutorialActions.BASKET, {TutorialEvents.ARG_BASKET: 1})).is_true()
	# G7 and G8 read first: no move but picking a placed card back up.
	var g8: TutorialStep = script.step(&"G8")
	assert_bool(g8.allows(TutorialActions.PICK_CARD, _card(&"eggs", false))).is_false()
	assert_bool(g8.allows(TutorialActions.CHECKOUT)).is_false()
	assert_bool(g8.allows(TutorialActions.PICK_CARD, _card(&"eggs", true))).is_true()
	var g3: TutorialStep = script.step(&"G3")
	assert_bool(g3.allows(TutorialActions.HIT, {TutorialActions.ARG_ID: &"booster1"})).is_true()
	assert_bool(g3.allows(TutorialActions.HIT, {TutorialActions.ARG_ID: &"crate"})).is_false()
	assert_bool(g3.allows(TutorialActions.HIT, {TutorialActions.ARG_ID: &"restock"})).is_false()
	# The steps before a board key say nothing of it, so they let it through: NEXT and tab 2 once
	# the boosters are open (G5 waits on page 2), OPEN STORE once a pack is picked (G7 waits).
	var g5: TutorialStep = script.step(&"G5")
	assert_bool(g5.allows(TutorialActions.HIT, {TutorialActions.ARG_ID: &"primary"})).is_true()
	assert_bool(g5.allows(TutorialActions.HIT, {TutorialActions.ARG_ID: &"newpacks"})).is_false()
	var g7: TutorialStep = script.step(&"G7")
	assert_bool(g7.allows(TutorialActions.HIT, {TutorialActions.ARG_ID: &"primary"})).is_true()
	assert_bool(g7.allows(TutorialActions.CHECKOUT)).is_false()
	# The closing step (shift 2) and the machine before it: nothing is refused.
	var g15: TutorialStep = script.step(&"G15")
	assert_bool(g15.allows(TutorialActions.CHUTE, {TutorialEvents.ARG_CHUTE: &"upgrade"})).is_true()
	assert_bool(g15.allows(TutorialActions.REDRAW)).is_true()


func test_a_quick_hint_fires_on_its_event() -> void:
	var swap: QuickTutorial = load(QuickTutorial.PATHS[0])
	var drag: QuickHint = swap.hints[0]
	assert_bool(drag.fires_on(TutorialEvents.SWAP_BOOSTER_OPENED, {})).is_true()
	assert_bool(drag.fires_on(TutorialEvents.SWAP_OPENED, {})).is_false()
	assert_str(String(drag.anchor_for({}))).is_equal("swap_regular0")
	var made: QuickHint = QuickHint.new()
	made.anchor = "booster{index}"
	assert_str(String(made.anchor_for({TutorialEvents.ARG_INDEX: 1}))).is_equal("booster1")
	made.anchor = "swap_regular{slot}"
	assert_str(String(made.anchor_for({TutorialEvents.ARG_SLOT: 2}))).is_equal("swap_regular2")


func test_markup_marks_keywords_and_words() -> void:
	var marked: String = TutorialText.markup("A **PAIR** of **CARDS**, **RIGHT BEFORE** it.")
	assert_str(marked).is_equal("A [PAIR] of ~CARDS|CARD~, ~RIGHT BEFORE|RIGHT BEFORE~ it.")
	assert_str(TipMarkup.plain(marked)).is_equal("A PAIR of CARDS, RIGHT BEFORE it.")
	assert_array(Array(TipMarkup.subs_of(marked))).is_equal(["PAIR", "CARD", "RIGHT BEFORE"])
	assert_str(TutorialText.plain("**ROW** pays")).is_equal("ROW pays")
	assert_array(Array(TutorialText.chips("**A** b **C D**"))).is_equal(["A", "C D"])


func test_the_new_boxes_avoid_the_retired_words() -> void:
	for key: String in TutorialText.CHIP_KEYS.values():
		if OLD_BOXES.has(key) or not TipWords.WORDS.has(key):
			continue
		var words: String = str(TipWords.WORDS[key][1])
		(
			assert_array(Array(_avoided(words)))
			. override_failure_message("%s: %s" % [key, words])
			. is_empty()
		)


## The mock-up's checkLine: at most MAX_WORDS words, at most MAX_SENTENCE per sentence, no chip
## before the step that teaches it (`at` is the line's place in teaching order) and no avoided
## word.
func _check(text: String, at: int, taught_at: Dictionary[String, int]) -> PackedStringArray:
	var issues: PackedStringArray = PackedStringArray()
	var plain: String = TutorialText.plain(text)
	var alnum: RegEx = RegEx.create_from_string("[A-Za-z0-9€]")
	var words: int = 0
	for word: String in plain.split(" ", false):
		if alnum.search(word) != null:
			words += 1
	if words > MAX_WORDS:
		issues.append("over %d words" % MAX_WORDS)
	var longest: int = 0
	var sentence_end: RegEx = RegEx.create_from_string("(?<=[.!?:])\\s+")
	for sentence: String in sentence_end.sub(plain, "\n", true).split("\n", false):
		if RegEx.create_from_string("[A-Za-z0-9]").search(sentence) != null:
			longest = maxi(longest, sentence.split(" ", false).size())
	if longest > MAX_SENTENCE:
		issues.append("a sentence over %d words" % MAX_SENTENCE)
	for form: String in TutorialText.chips(text):
		if TutorialText.UNCHECKED.has(form):
			continue
		var key: String = TutorialText.chip_key(form)
		if not taught_at.has(key) or taught_at[key] > at:
			issues.append("%s used before it is taught" % form)
	issues.append_array(_avoided(plain))
	return issues


static func _avoided(plain: String) -> PackedStringArray:
	var low: String = " %s " % plain.to_lower()
	for exempt: String in EXEMPT:
		low = low.replace(exempt.to_lower(), " ")
	var found: PackedStringArray = PackedStringArray()
	for avoid: String in AVOID:
		var pattern: String = "(^|[^a-z])%s([^a-z]|$)" % _escaped(avoid)
		if RegEx.create_from_string(pattern).search(low) != null:
			found.append('avoid "%s"' % avoid)
	return found


static func _escaped(words: String) -> String:
	var escaped: String = ""
	for character: String in words:
		escaped += ("\\" + character) if ".*+?^${}()|[]\\".contains(character) else character
	return escaped


## Every line: [id, text, its place in teaching order], the guided run's first, then the tips',
## then the quick tutorials' (the mock-up's taughtMap order). T14's fallback line too.
func _lines() -> Array[Array]:
	var found: Array[Array] = []
	var at: int = 0
	var script: TutorialScript = TutorialScript.guided()
	for step: TutorialStep in script.steps:
		found.append([String(step.id), step.text, at])
		at += 1
		if step.is_free():
			for extra: TutorialStep in [script.retry, script.answer_step]:
				found.append([String(extra.id), extra.text, at])
				at += 1
			for hint: PlanHint in script.hints:
				found.append([String(hint.id), hint.text, at])
				at += 1
	for tip: TipDefinition in TipList.shared().tips:
		found.append([String(tip.id), tip.text, at])
		if not tip.fallback_text.is_empty():
			found.append(["%s fallback" % tip.id, tip.fallback_text, at])
		at += 1
	for each: QuickTutorial in QuickTutorial.all():
		for step: TutorialStep in each.steps:
			found.append([String(step.id), step.text, at])
			at += 1
		for hint: QuickHint in each.hints:
			found.append([String(hint.id), hint.text, at])
			at += 1
	return found


## Each line's taught words, in the same order: [id, teaches].
func _taught_lists() -> Array[Array]:
	var found: Array[Array] = []
	var script: TutorialScript = TutorialScript.guided()
	for step: TutorialStep in script.steps:
		found.append([step.id, step.teaches])
		if step.is_free():
			for extra: TutorialStep in [script.retry, script.answer_step]:
				found.append([extra.id, extra.teaches])
			for hint: PlanHint in script.hints:
				found.append([hint.id, hint.teaches])
	for tip: TipDefinition in TipList.shared().tips:
		found.append([tip.id, tip.teaches])
	for each: QuickTutorial in QuickTutorial.all():
		for step: TutorialStep in each.steps:
			found.append([step.id, step.teaches])
		for hint: QuickHint in each.hints:
			found.append([hint.id, hint.teaches])
	return found


func _steps() -> Array[TutorialStep]:
	var found: Array[TutorialStep] = []
	found.append_array(TutorialScript.guided().steps)
	for each: QuickTutorial in QuickTutorial.all():
		found.append_array(each.steps)
	return found


## The data's values plus the approved lines' live ones (START RUN, T14's Eggs and Food).
func _values() -> Dictionary:
	var values: Dictionary = {}
	values.merge(TutorialText.values(TutorialScript.guided(), _balance()))
	values[TutorialText.PRIMARY] = PLATES[0]
	values[TutorialText.WASTED_CARD] = "Eggs"
	values[TutorialText.WASTED_FAMILY] = "Food"
	values[TutorialText.MISSED] = "24"
	return values


func _balance() -> BalanceDefinition:
	return load(BALANCE) as BalanceDefinition


func _card(card_id: StringName, from_row: bool) -> Dictionary:
	return {
		TutorialEvents.ARG_CARD: card_id,
		TutorialEvents.ARG_INSTANCE: 1,
		TutorialEvents.ARG_FROM_ROW: from_row,
	}


func _placed(card_id: StringName, slot: int) -> Dictionary:
	return {
		TutorialEvents.ARG_CARD: card_id,
		TutorialEvents.ARG_INSTANCE: 1,
		TutorialEvents.ARG_SLOT: slot,
	}


static func _event_log() -> EventLogService:
	return (Engine.get_main_loop() as SceneTree).root.get_node("/root/EventLog")
