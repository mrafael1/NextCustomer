extends GdUnitTestSuite
## The tutorial's script and text data (data/tutorial: the guided run G1-G14 with its free
## planning's retry and answer lines and reactive hints, the one-time tips T1-T16 and the quick
## tutorials R, P and SA; tutorial plan WP-3, reworked after play test 1, 2026-11-15). Every id,
## anchor, event, action and chip resolves; the filled lines equal the approved ones (the mock-up
## docs/art/mockups/tutorial.html, with the user's decisions: Pantry, not Produce; G1 follows the
## title's plate), so a card or balance change that breaks the answer's total fails here; and
## every line passes the mock-up's line checker, ported below.

## The approved lines, filled (the mock-up's GUIDED, TIPS and QUICK texts, chips marked **).
const APPROVED: Dictionary[String, String] = {
	"G2": "These are **YOUR REGULARS**. They start in your **CART** on every run.",
	"G3": "Open both **BOOSTERS**. Their 3 **CARDS** each go in your **CART**.",
	"G4": "Your store is stocked. Click NEXT.",
	"G5":
	"Pick one **STARTER PACK**. Its **CARDS** join your **CART**. Point at a pack to read it.",
	"G6": "Your **CART** is ready. Click OPEN STORE to start your first **SHIFT**.",
	"G7":
	(
		"Put **ITEMS** from your **BASKETS** in the **ROW**. Reach the **QUOTA**, 30€, to pass "
		+ "the **SHIFT**."
	),
	"G8":
	(
		"Each **CARD** has a **PRICE** and a **RULE**, and the order matters. Hold the pointer "
		+ "still on one to read it on the monitor."
	),
	"G9": "Your turn! Build your **ROW**, then press **CHECKOUT**. Tips pop up as you go.",
	"G10": "",
	"RETRY":
	(
		"24€ of 30€: not quite! Move some **ITEMS**, or **REDRAW** a **BASKET**, then press "
		+ "**CHECKOUT** once more."
	),
	"ANSWER":
	(
		"Here is a **ROW** that pays 36€. Drag each **ITEM** onto its ghost, then press "
		+ "**CHECKOUT**."
	),
	"eggs_placed":
	"Eggs can boost other items! The **NEXT** Food **ITEM**, anywhere **LATER**, pays ×2.",
	"quota":
	(
		"Your **ROW** reaches the **QUOTA**! Press **CHECKOUT**, or push on: 2× the **QUOTA** "
		+ "earns a **SILVER** medal."
	),
	"silver":
	(
		"2× the **QUOTA**: **SILVER** brings an **EXTRA DRAW** at the machine. 3× makes it "
		+ "**GOLD**: **PREMIUM** prizes."
	),
	"redrawn": "New **CARDS** from your **PILE**! Each **BASKET** you swap costs 1 **REDRAW**.",
	"row_full": "7 slots, 8 **CARDS**: one always stays in its **BASKET**.",
	"G11":
	(
		"**QUOTA** met! Pick a key, then PUSH. **NEW ITEMS** brings new **CARDS**. **IMPROVE** "
		+ "makes one better, or gives a **LOYALTY PERK**."
	),
	"G12":
	"Keep 1 prize, or **SKIP** them all. **RARE** and **LEGENDARY** prizes are harder to find.",
	"G13":
	(
		"A **WEEK** is 4 **SHIFTS**, and **PAYDAY** is the last. In training **WEEK** you may "
		+ "**MISS** the **QUOTA** 2 times."
	),
	"G14": "That's the basics! Look up any word in the **HANDBOOK**, in the menu.",
	"T1":
	(
		"Bad **CARDS**? Press **REDRAW**, then click a **BASKET**. Its **CARDS** swap for new "
		+ "ones from your **PILE**. Each **BASKET** costs 1 **REDRAW**."
	),
	"T2":
	(
		"A **COUPON** has no **PRICE**. It changes the **ITEMS** around it. Two **ITEMS** with a "
		+ "**COUPON** between them are not **BESIDE** each other."
	),
	"T3":
	(
		"The small icons in a ticket's corner are its **FAMILIES**, like Breakfast or Dairy. A "
		+ "chip in a **RULE** names a **FAMILY** or a keyword."
	),
	"T4":
	(
		"**MORNING**: start your **ROW** with Breakfast **ITEMS**. Coffee pays +1€ for each one. "
		+ "Here, Eggs and Bread make 2."
	),
	"T5":
	(
		"**BATCH**: Bakery **ITEMS** **BESIDE** each other. Some care where they sit in it: "
		+ "Croissant first."
	),
	"T6":
	(
		"Each **SHIFT** may have a **DAY EVENT**. Green is a **GOOD DAY**. Red is an "
		+ "**INSPECTION**: a harder **RULE** for this **SHIFT**."
	),
	"T7":
	(
		"**PAYDAY**: the last **SHIFT** of the **WEEK**, with 2 **INSPECTIONS**. Meet the "
		+ "**QUOTA** for 2 **PREMIUM** draws: every prize **RARE** or better."
	),
	"T8": "**PREMIUM**: every prize here is **RARE** or better.",
	"T9":
	(
		"**MISS** 1 of 2: no prizes this time. Training **WEEK** lets it go. From **WEEK** 2, one "
		+ "**MISS** ends the run."
	),
	"T10":
	(
		"Pay 2× the **QUOTA** in one **SHIFT** for **SILVER**: an **EXTRA DRAW**. 3× for "
		+ "**GOLD**: your draw turns **PREMIUM**. One of each per **WEEK**."
	),
	"T11":
	"Your **LOYALTY** card. Each **LOYALTY PERK** stays for the whole run, and some level up.",
	"T12": "**IMPROVE** made it **BIG**: it pays more. A later **IMPROVE** can make it **GOLDEN**.",
	"T13": "Training **WEEK** is over. From now on, one **MISS** ends the run.",
	"T14":
	(
		"Next time: put Eggs **EARLIER** than your best Food **ITEM**, with no other Food "
		+ "**ITEM** between them."
	),
	"T15":
	(
		"Pass 8 **SHIFTS** or more to earn **COINS**. Use them to buy toy capsules at the exit. "
		+ "**BADGE PINS** change your next run."
	),
	"T16":
	(
		"Look up rules and words here. On a tip, point at a chip word to see what it means. "
		+ "MORE › opens its page here."
	),
	"R1":
	(
		"NEW: **RESTOCK**. Not happy with a **BOOSTER** you opened? Send it back for a new one, "
		+ "once per run start."
	),
	"R2": "Click RETURN THIS ONE on the **BOOSTER** to send back. CANCEL keeps all your **CARDS**.",
	"R3":
	(
		"Its 3 **CARDS** go in the RETURNS tote and leave your **CART**. A new sealed "
		+ "**BOOSTER** takes its place."
	),
	"R4":
	(
		"Open it: 3 new **CARDS**, with a new chance at a **RARE** one. **RESTOCK** is used up "
		+ "until your next run."
	),
	"P1": "NEW: **BADGE PINS**. You earned one! A pin you wear changes a rule for this whole run.",
	"P2": "Read a pin's rule, then click WEAR. You have 1 slot: wearing another pin swaps it.",
	"P3": "Confirm with the red key, and your **STARTER PACKS** deal. Wearing no pin is fine too.",
	"P4":
	"Your pin is on the board for this run. Click the board or press P to change it before you pick.",
	"SA1":
	(
		"NEW: each completed aisle lets you swap 1 of **YOUR REGULARS**. Click the basket to "
		+ "swap."
	),
	"SA2": "Each aisle gives a **BOOSTER** of plain **CARDS**. Open both.",
	"SA3": "Drag a **CARD** onto a regular to swap them. Drag it back to undo.",
	"SA4": "Swaps last this run only. Next run, **YOUR REGULARS** are back. Click DONE.",
}
## G1 follows the title's plate (the user's decision): START RUN on a fresh profile, NEW RUN with
## a saved run.
const G1_LINE := (
	"Welcome to the till! Click %s. Your first **SHIFT** shows you how to play, one move at "
	+ "a time."
)
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
const MAX_WORDS := 30
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


func test_the_guided_run_is_g1_to_g14_in_order() -> void:
	var script: TutorialScript = TutorialScript.guided()
	assert_int(script.steps.size()).is_equal(14)
	for k: int in script.steps.size():
		assert_str(String(script.steps[k].id)).is_equal("G%d" % (k + 1))
		assert_int(script.index_of(script.steps[k].id)).is_equal(k)
	assert_object(script.step(&"G10")).is_same(script.steps[9])
	assert_object(script.step(&"G99")).is_null()
	# G10 is shift 1's free planning: no line, every planning move but REDRAW and its baskets.
	assert_int(script.free_index()).is_equal(9)
	for k: int in script.steps.size():
		assert_bool(script.steps[k].is_free()).override_failure_message(str(k)).is_equal(k == 9)
	assert_str(String(script.retry.id)).is_equal("RETRY")
	assert_str(String(script.answer_step.id)).is_equal("ANSWER")
	var ids: Array[StringName] = []
	for hint: PlanHint in script.hints:
		assert_bool(ids.has(hint.id)).override_failure_message(String(hint.id)).is_false()
		ids.append(hint.id)
		assert_str(hint.title).override_failure_message(String(hint.id)).is_not_empty()
		var about_card: bool = hint.when in [PlanHint.When.PLACED, PlanHint.When.FIRED]
		about_card = about_card or hint.when == PlanHint.When.WASTED
		assert_bool(hint.card.is_empty()).override_failure_message(String(hint.id)).is_equal(
			not about_card
		)
		if about_card:
			(
				assert_bool(script.hand.has(hint.card))
				. override_failure_message(String(hint.id))
				. is_true()
			)


func test_tips_and_quick_tutorials_have_their_ids() -> void:
	var tips: TipList = TipList.shared()
	assert_int(tips.tips.size()).is_equal(16)
	for k: int in tips.tips.size():
		assert_str(String(tips.tips[k].id)).is_equal("T%d" % (k + 1))
		assert_bool(TipDefinition.TRIGGERS.has(tips.tips[k].trigger)).is_true()
		assert_int(tips.tips[k].priority).is_between(1, 6)
	assert_object(tips.tip(&"T6")).is_same(tips.tips[5])
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
	assert_array(steps).is_equal(
		["SA1", "SA2", "SA3", "SA4", "R1", "R2", "R3", "R4", "P1", "P2", "P3", "P4"]
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
	assert_bool(TipList.shared().tip(&"T1").more_in_toys()).is_false()
	assert_str(String(TipList.shared().tip(&"T16").more_page)).is_empty()


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
		TutorialText.MORNING_NAMES,
		TutorialText.MORNING_MAKE,
		TutorialText.MORNING_COUNT,
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
	assert_str(values["hand"]).is_equal(str(balance.hand_size))
	assert_str(values["slots"]).is_equal(str(balance.slot_count))
	# The answer row meets the shift 1 quota.
	assert_int(int(values["answer_total"])).is_greater_equal(balance.quotas[0])
	# T4's "Coffee pays +1€ for each one" is Coffee's own rule.
	var coffee: CardDefinition = load("res://data/cards/coffee.tres")
	assert_str(values["coffee_per"]).is_equal(str((coffee.rules[0] as MorningCountRule).bonus_each))


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
	assert_array(Array(_check(long + ".", 9, taught))).has_size(1)


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
	# G7-G9 read first: no move but picking a placed card back up.
	var g9: TutorialStep = script.step(&"G9")
	assert_bool(g9.allows(TutorialActions.PICK_CARD, _card(&"eggs", false))).is_false()
	assert_bool(g9.allows(TutorialActions.CHECKOUT)).is_false()
	assert_bool(g9.allows(TutorialActions.PICK_CARD, _card(&"eggs", true))).is_true()
	var g3: TutorialStep = script.step(&"G3")
	assert_bool(g3.allows(TutorialActions.HIT, {TutorialActions.ARG_ID: &"booster1"})).is_true()
	assert_bool(g3.allows(TutorialActions.HIT, {TutorialActions.ARG_ID: &"crate"})).is_false()
	assert_bool(g3.allows(TutorialActions.HIT, {TutorialActions.ARG_ID: &"restock"})).is_false()
	var g11: TutorialStep = script.step(&"G11")
	assert_bool(g11.allows(TutorialActions.CHUTE, {TutorialEvents.ARG_CHUTE: &"upgrade"})).is_true()


func test_a_quick_step_refuses_only_its_refused_ids() -> void:
	var restock: QuickTutorial = load(QuickTutorial.PATHS[1])
	var armed: TutorialStep = restock.step(&"R2")
	assert_bool(armed.allows(TutorialActions.HIT, {TutorialActions.ARG_ID: &"tab2"})).is_false()
	assert_bool(armed.allows(TutorialActions.HIT, {TutorialActions.ARG_ID: &"primary"})).is_true()
	assert_bool(armed.allows(TutorialActions.HIT, {TutorialActions.ARG_ID: &"rcards0"})).is_true()
	assert_str(String(armed.back_out_on)).is_equal(String(TutorialEvents.RESTOCK_CANCELLED))
	(
		assert_bool(
			restock.step(&"R1").allows(TutorialActions.HIT, {TutorialActions.ARG_ID: &"tab2"})
		)
		. is_true()
	)


func test_markup_marks_keywords_and_words() -> void:
	var marked: String = TutorialText.markup("A **PAIR** of **CARDS**, **RIGHT BEFORE** it.")
	assert_str(marked).is_equal("A [PAIR] of ~CARDS|CARD~, ~RIGHT BEFORE|RIGHT BEFORE~ it.")
	assert_str(TipMarkup.plain(marked)).is_equal("A PAIR of CARDS, RIGHT BEFORE it.")
	assert_array(Array(TipMarkup.subs_of(marked))).is_equal(["PAIR", "CARD", "RIGHT BEFORE"])
	assert_str(TutorialText.plain("**ROW** pays")).is_equal("ROW pays")
	assert_array(Array(TutorialText.chips("**A** b **C D**"))).is_equal(["A", "C D"])


func test_live_fills_read_aloud() -> void:
	assert_str(TutorialText.listed(PackedStringArray(["Eggs"]))).is_equal("Eggs")
	assert_str(TutorialText.listed(PackedStringArray(["Eggs", "Bread"]))).is_equal("Eggs and Bread")
	assert_str(TutorialText.listed(PackedStringArray(["Eggs", "Bread", "Milk"]))).is_equal(
		"Eggs, Bread and Milk"
	)
	var one: Dictionary[String, String] = TutorialText.morning_values(PackedStringArray(["Eggs"]))
	assert_str(one[TutorialText.MORNING_MAKE]).is_equal("makes")
	assert_str(one[TutorialText.MORNING_COUNT]).is_equal("1")
	var t4: String = TipList.shared().tip(&"T4").text
	var values: Dictionary = _values()
	values.merge(one, true)
	assert_str(TutorialText.fill(t4, values)).ends_with("Here, Eggs makes 1.")


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
	return found


func _steps() -> Array[TutorialStep]:
	var found: Array[TutorialStep] = []
	found.append_array(TutorialScript.guided().steps)
	for each: QuickTutorial in QuickTutorial.all():
		found.append_array(each.steps)
	return found


## The data's values plus the approved lines' live ones (START RUN, T4's Eggs and Bread, T14's
## Eggs and Food).
func _values() -> Dictionary:
	var values: Dictionary = {}
	values.merge(TutorialText.values(TutorialScript.guided(), _balance()))
	values.merge(TutorialText.morning_values(PackedStringArray(["Eggs", "Bread"])))
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
