extends GdUnitTestSuite
## The receipt's silver and gold paper and its anchored count on the real shift screen and alone
## (2026-11-05: ReceiptGold, ReceiptGoldFlow; since left column v2, the user's pick of 2026-11-09,
## mock-up docs/art/mockups/left_column_v2.html, the paper carries the week medal the checkout wins:
## the gauge hides at CHECKOUT). A count earning the overtime ticket's medal (twice the target)
## turns the paper SILVER, the PREMIUM medal (three times) GOLD, wiping over the silver; each wipe
## runs from the paper's top down in whole art px, then one stepped shine band crosses it; under
## reduced motion the metal is at once, with no shine. No stamp. A payday wears the paycheck design
## (ReceiptPayday: its brass PAYDAY ribbon, foot band and € watermark) from its opening (a
## resume's too) through its verdict, passed or missed, never a metal of its own; the next ordinary
## shift opens plain. The count pays planning's rows in place, every row keeping its place on the
## paper, and its dessert prints nothing under its foot (the 2026-11-09 play test: no tear, no
## INSPECTION PASSED, nothing on a slip beside it); the machine feeds that very paper, its whole
## length. On the metals the ink stays dark and the warnings legible. Layout asserts on-screen
## geometry (memory: UI tests check layout).

const Rush := preload("res://tests/ui/count_up_rush.gd")
const ReceiptFed := preload("res://tests/ui/receipt_fed_lines.gd")
const SCREEN := "res://ui/shift_screen.tscn"
const MILK := "res://data/cards/milk.tres"
## The payday's review drawn from Spot check alone (slot 3 pays 0), so its pass is the same every
## run (the drawn review can raise the quota or zero a paid slot).
const SPOT_CHECK := "res://data/inspections/spot_check.tres"
## The live schedule's first payday (MachineDefinition.is_payday_shift) and an ordinary shift.
const PAYDAY_SHIFT := 4
const ORDINARY_SHIFT := 5
## The gold paper's face: the announce slip's gold.
const PAPER_GOLD := GoldPaperArt.FACE
const MAX_FRAMES := 3000
## A metal's whole beat: its wipe, then its shine.
const BEAT := ReceiptGold.WIPE_SECONDS + ReceiptGold.SHINE_SECONDS + 0.1

var _folder: String = ""


func before_test() -> void:
	_folder = "user://test_receipt_gold_%d" % Time.get_ticks_usec()
	_event_log().use_folder(_folder)
	ProjectSettings.set_setting(SaveService.FOLDER_SETTING, _folder)


func after_test() -> void:
	ProjectSettings.set_setting(SaveService.FOLDER_SETTING, null)
	if DirAccess.dir_exists_absolute(_folder):
		for file_name: String in DirAccess.get_files_at(_folder):
			DirAccess.remove_absolute(_folder.path_join(file_name))
		DirAccess.remove_absolute(_folder)


## The gold paper alone: gold at once when `instant` (no shine, no sparkles); on it the light inks
## step darker (tomato, the waiting grey, green, teal) and the dashed rules turn amber; back on
## cream every ink is its own again. Every ink on the gold reads: the ink dark (7:1 and more), the
## stepped ones 3:1 and more. The paper is never tinted flat: its gold is drawn (GoldPaperArt).
func test_the_gold_paper_keeps_its_inks_legible() -> void:
	var receipt: ReceiptView = auto_free(ReceiptView.new())
	add_child(receipt)
	var notice: Label = receipt.add_notice("NEXT: SPOT CHECK").get_child(0) as Label
	var waiting: Label = (
		receipt.add_line("5 ·····", "", ReceiptView.LineStyle.WAITING).get_child(0) as Label
	)
	var projected: Control = receipt.add_line("PROJECTED", "9€", ReceiptView.LineStyle.PROJECTED)
	var rule: HSeparator = receipt._lines.get_child(projected.get_index() - 1) as HSeparator
	assert_object(_ink(notice)).is_equal(Palette.TOMATO)
	receipt.gold.show_gold(true, true)
	assert_float(receipt.gold.amount()).is_equal(1.0)
	assert_object(receipt.gold.face_colour()).is_equal(PAPER_GOLD)
	assert_object(receipt.self_modulate).is_equal(Color.WHITE)
	assert_bool(receipt.gold.is_gold()).is_true()
	assert_bool(receipt.gold.shines()).is_false()
	await _frames(1)
	assert_object(_ink(notice)).is_equal(Palette.TOMATO_DARK)
	assert_object(_ink(waiting)).is_equal(Palette.GREY_DARK)
	assert_bool(rule.get_meta(ReceiptGold.RULE_META, false)).is_true()
	# A line printed on the gold steps darker too.
	var late: Label = receipt.add_notice("NEXT: SHORT BELT").get_child(0) as Label
	await _frames(1)
	assert_object(_ink(late)).is_equal(Palette.TOMATO_DARK)
	assert_float(_contrast(Palette.INK, PAPER_GOLD)).is_greater_equal(7.0)
	for ink: Color in ReceiptGold.INKS.values():
		(
			assert_float(_contrast(ink, PAPER_GOLD))
			. override_failure_message(ink.to_html())
			. is_greater_equal(3.0)
		)
	receipt.gold.show_gold(false, true)
	assert_float(receipt.gold.amount()).is_equal(0.0)
	await _frames(1)
	assert_object(_ink(notice)).is_equal(Palette.TOMATO)
	assert_object(_ink(waiting)).is_equal(Palette.MUTED_INK)
	assert_bool(rule.get_meta(ReceiptGold.RULE_META, true)).is_false()


## The wipe (left column v2): a metal wipes on from the paper's top down, its front on whole art px
## at every step, the paper never moving; once down its stepped shine band crosses once, then
## stops. Gold wipes over silver (the face gold once down; gold implies silver's beat first in a
## count, ReceiptGoldFlow). Under reduced motion: at once, no shine.
func test_a_metal_wipes_down_then_shines_once() -> void:
	var receipt: ReceiptView = auto_free(ReceiptView.new())
	add_child(receipt)
	receipt.size = Vector2(ShiftStage.RECEIPT_WIDTH, 301.0)
	await _frames(1)
	var cell: float = ArtStyle.ART_SCALE
	for k: float in [0.0, 0.13, 0.5, 0.77, 1.0]:
		var front: float = receipt.gold.wipe_y(k)
		assert_float(fposmod(front, cell)).override_failure_message(str(k)).is_equal(0.0)
		assert_float(front).is_between(0.0, receipt.size.y + cell)
	var rect: Rect2 = receipt.get_global_rect()
	receipt.gold.show_silver(true)
	assert_float(receipt.gold.silver_amount()).is_less(1.0)
	assert_object(receipt.gold.face_colour()).is_equal(Palette.PAPER)
	await get_tree().create_timer(ReceiptGold.WIPE_SECONDS + 0.05).timeout
	assert_float(receipt.gold.silver_amount()).is_equal(1.0)
	assert_object(receipt.gold.face_colour()).is_equal(GoldPaperArt.SILVER[0])
	assert_bool(receipt.gold.is_shining()).is_true()
	await get_tree().create_timer(ReceiptGold.SHINE_SECONDS).timeout
	assert_bool(receipt.gold.is_shining()).is_false()
	receipt.gold.show_gold(true)
	assert_float(receipt.gold.amount()).is_less(1.0)
	await get_tree().create_timer(BEAT).timeout
	assert_float(receipt.gold.amount()).is_equal(1.0)
	assert_object(receipt.gold.face_colour()).is_equal(PAPER_GOLD)
	assert_object(receipt.get_global_rect()).is_equal(rect)
	# Reduced motion: at once, still.
	receipt.gold.show_gold(false, true)
	receipt.gold.show_silver(false, true)
	receipt.gold.show_gold(true, true)
	assert_float(receipt.gold.amount()).is_equal(1.0)
	assert_bool(receipt.gold.shines()).is_false()
	assert_bool(receipt.gold.is_shining()).is_false()


## The gold is the PAYDAY / PREMIUM NEXT announce slip's: its gold face, its glint every
## SHINE_PERIOD (sweeping across, then gone till the next).
func test_the_gold_paper_is_the_announce_slips() -> void:
	assert_object(GoldPaperArt.FACE).is_equal(Palette.GOLD)
	assert_float(GoldPaperArt.SHINE_PERIOD).is_equal(PremiumAnnounce.SHINE_PERIOD)
	assert_float(GoldPaperArt.shine_at(0.0)).is_less(0.0)
	var mid: float = GoldPaperArt.SHINE_DELAY + GoldPaperArt.SHINE_LENGTH / 2.0
	assert_float(GoldPaperArt.shine_at(mid)).is_between(0.0, 1.0)
	assert_float(GoldPaperArt.shine_at(mid + GoldPaperArt.SHINE_PERIOD)).is_equal_approx(
		GoldPaperArt.shine_at(mid), 0.001
	)
	var gone: float = GoldPaperArt.SHINE_DELAY + GoldPaperArt.SHINE_LENGTH + 0.1
	assert_float(GoldPaperArt.shine_at(gone)).is_greater(1.0)


## A payday shift opens with the paycheck design (PAYDAY NEXT's check): the PAYDAY ribbon over the
## header, inside the paper, the paper cream (no metal); an ordinary shift opens plain; a resumed
## payday planning wears the design too. The design never hides the target's number.
func test_a_payday_shift_opens_as_a_paycheck() -> void:
	var screen: ShiftScreen = await _screen()
	screen._debug.skip_to_shift(PAYDAY_SHIFT)
	await _frames(2)
	var receipt: ReceiptView = screen._receipt
	assert_bool(ReceiptGoldFlow.payday(screen.run)).is_true()
	assert_bool(receipt.payday_ribbon.visible).is_true()
	assert_bool(receipt.gold.is_gold()).is_false()
	assert_bool(receipt.gold.is_silver()).is_false()
	var ribbon: Rect2 = receipt.payday_ribbon.get_global_rect()
	var paper: Rect2 = receipt.get_global_rect()
	assert_bool(paper.encloses(ribbon)).override_failure_message(str(ribbon)).is_true()
	assert_float(ribbon.size.y).is_equal(ReceiptPayday.height())
	var target: Rect2 = receipt.target.get_global_rect()
	assert_float(ribbon.end.y).is_less_equal(target.position.y + 0.5)
	screen._debug.skip_to_shift(ORDINARY_SHIFT)
	await _frames(1)
	assert_bool(ReceiptGoldFlow.payday(screen.run)).is_false()
	assert_bool(receipt.payday_ribbon.visible).is_false()
	screen._debug.skip_to_shift(PAYDAY_SHIFT)
	await _frames(1)
	var resumed: ShiftScreen = await _screen()
	assert_int(resumed.run.shift_index).is_equal(PAYDAY_SHIFT - 1)
	assert_int(resumed.run.phase).is_equal(RunState.Phase.PLANNING)
	assert_bool(resumed._receipt.payday_ribbon.visible).is_true()


## A passed payday keeps its paycheck design through the count and the verdict (the TOTAL green
## dark), its dessert covering no paid row at any frame, then the next ordinary shift opens plain.
func test_a_passed_payday_stays_a_paycheck_through_its_verdict() -> void:
	var screen: ShiftScreen = await _screen()
	_low_quotas(screen, 5)
	screen._debug.skip_to_shift(PAYDAY_SHIFT)
	await _frames(2)
	_place_milks(screen, 2)
	await _frames(2)
	var rows: Array[Rect2] = _row_rects(screen)
	var paper: Rect2 = ReceiptFed.planned_rect(screen)
	assert_bool(_header_shown(screen)).is_true()
	var seen: Dictionary = await _checkout_watching(screen, rows)
	assert_bool(seen["plain_frames"] as bool).is_false()
	assert_bool(screen.run.history[-1].passed).is_true()
	await _frames(1)
	_assert_anchored(screen, seen, rows, paper)
	_assert_dessert_clear(screen, seen, paper)
	var target: ReceiptTarget = screen._receipt.target
	var total: int = screen.run.last_result.total
	assert_str(target.hero.text).is_equal(ReceiptTarget.AMOUNT_TEXT % total)
	assert_object(_ink(target.over)).is_equal(Palette.GREEN_DARK)
	screen._machine.debug_skip()
	await _frames(2)
	assert_int(screen.run.shift_index).is_equal(ORDINARY_SHIFT - 1)
	assert_bool(screen._receipt.payday_ribbon.visible).is_false()


## A missed payday keeps its paycheck design through the verdict (the TOTAL and SHORT tomato
## dark), then the next ordinary shift (its slip moves the run on) opens plain.
func test_a_missed_payday_stays_a_paycheck_through_its_verdict() -> void:
	var screen: ShiftScreen = await _screen()
	screen._debug.skip_to_shift(PAYDAY_SHIFT)
	await _frames(2)
	_place_milks(screen, 1)
	assert_int(screen.run.preview().total).is_less(screen.run.quota())
	await _frames(2)
	var rows: Array[Rect2] = _row_rects(screen)
	var paper: Rect2 = ReceiptFed.planned_rect(screen)
	var seen: Dictionary = await _checkout_watching(screen, rows)
	assert_bool(seen["plain_frames"] as bool).is_false()
	assert_bool(screen.run.history[-1].passed).is_false()
	var inks: Array = seen["verdict_inks"]
	assert_array(inks).contains([Palette.TOMATO_DARK])
	await _frames(1)
	_assert_anchored(screen, seen, rows, paper)
	assert_bool(screen._receipt.payday_ribbon.visible).is_true()
	assert_bool(screen._receipt.gold.is_gold()).is_false()
	assert_int(screen.run.phase).is_equal(RunState.Phase.SCORED)
	for _frame: int in range(MAX_FRAMES):
		if screen.run.phase != RunState.Phase.SCORED:
			break
		await get_tree().process_frame
	assert_int(screen.run.phase).is_equal(RunState.Phase.PLANNING)
	assert_int(screen.run.shift_index).is_equal(ORDINARY_SHIFT - 1)
	assert_bool(ReceiptGoldFlow.payday(screen.run)).is_false()
	assert_bool(screen._receipt.payday_ribbon.visible).is_false()


## An ordinary shift reaching the PREMIUM laps (×3) only with its last item: the paper is cream
## at the click, turns silver and gold (gold over silver) in CHECKOUT's medal prelude, before the
## count starts (MedalPrelude, the 2026-11-09 play test), and stays gold through the count; the
## paper never moves and every row keeps its place, paid in place. A resumed screen shows the
## gold at once.
func test_overtime_on_the_last_item_turns_the_receipt_gold_before_the_count() -> void:
	var screen: ShiftScreen = await _screen()
	var laps: int = ReceiptGoldFlow.premium_laps(screen.run)
	assert_int(laps).is_equal(screen.run.balance.machine.overtime_premium_laps)
	assert_int(laps).is_greater(0)
	await _last_item_reaches(screen, laps)
	assert_bool(screen._receipt.gold.is_gold()).is_false()
	var rows: Array[Rect2] = _row_rects(screen)
	var paper: Rect2 = ReceiptFed.planned_rect(screen)
	var last: int = screen.run.row.size() - 1
	var seen: Dictionary = await _checkout_watching(screen, rows, last)
	assert_bool(seen["moved"] as bool).override_failure_message(str(seen["moved_at"])).is_false()
	assert_bool(seen["gold_before_count"] as bool).is_true()
	assert_bool(seen["early_gold"] as bool).is_true()
	assert_bool(seen["cream_while_counting"] as bool).is_false()
	assert_bool(seen["silver_seen"] as bool).is_true()
	_assert_fed_paper(screen, paper)
	assert_bool(screen._receipt.gold.is_gold()).is_true()
	await get_tree().create_timer(ReceiptGold.WIPE_SECONDS + 0.05).timeout
	assert_object(screen._receipt.gold.face_colour()).is_equal(PAPER_GOLD)
	# The rows printed at checkout: each item's amount is its payout, in ink.
	var printed: Array[Control] = screen._receipt.printed_rows()
	assert_int(printed.size()).is_equal(screen.run.row.size())
	for slot: int in range(screen.run.row.size()):
		var amount: Label = printed[slot].get_child(1) as Label
		assert_str(amount.text).is_equal(ReceiptView.money(screen.run.last_result.payouts[slot]))
		assert_object(_ink(amount)).is_equal(Palette.INK)
	assert_str(screen._receipt.target.total_caption.text).is_equal(ReceiptTarget.TOTAL_TEXT)
	var resumed: ShiftScreen = await _screen()
	assert_int(resumed.run.phase).is_equal(RunState.Phase.MACHINE_CHOOSE)
	assert_bool(resumed._receipt.gold.is_gold()).is_true()
	assert_float(resumed._receipt.gold.amount()).is_equal(1.0)
	assert_str(resumed._receipt.target.total_caption.text).is_equal(ReceiptTarget.TOTAL_TEXT)
	assert_int(resumed._receipt.printed_rows().size()).is_equal(screen.run.row.size())


## A payday reaching the PREMIUM laps with its last item: the paycheck design all along; the GOLD
## medal stays in its socket (a payday's visit is PREMIUM already, 2026-11-06), so the paper never
## turns gold, but the SILVER is spent: the paper turns silver under the design (the metal is the
## medal won, the user's play test of 2026-11-09).
func test_a_payday_reaching_overtime_turns_silver_under_its_design() -> void:
	var screen: ShiftScreen = await _screen()
	screen._debug.skip_to_shift(PAYDAY_SHIFT)
	await _frames(2)
	var laps: int = ReceiptGoldFlow.premium_laps(screen.run)
	await _last_item_reaches(screen, laps)
	assert_bool(ReceiptGoldFlow.payday(screen.run)).is_true()
	assert_bool(screen._receipt.gold.is_gold()).is_false()
	var rows: Array[Rect2] = _row_rects(screen)
	var paper: Rect2 = ReceiptFed.planned_rect(screen)
	var seen: Dictionary = await _checkout_watching(screen, rows)
	assert_bool(seen["plain_frames"] as bool).is_false()
	assert_bool(seen["gold_while_counting"] as bool).is_false()
	assert_bool(seen["silver_seen"] as bool).is_true()
	assert_bool(screen._receipt.gold.is_gold()).is_false()
	assert_bool(screen._receipt.gold.is_silver()).is_true()
	assert_bool(screen._receipt.payday_ribbon.visible).is_true()
	var spent: Array[int] = [WeekMedals.State.USED, WeekMedals.State.AVAILABLE]
	assert_array(screen._stage.medal_case.states()).is_equal(spent)
	_assert_anchored(screen, seen, rows, paper)


## Under reduced motion the overtime's metal switches at once: the first gold frame of the count is
## already all gold, with no shine and no sparkles.
func test_overtime_gold_is_instant_under_reduced_motion() -> void:
	var screen: ShiftScreen = await _screen()
	screen.profile.settings[ProfileState.REDUCED_MOTION_KEY] = true
	await _last_item_reaches(screen, ReceiptGoldFlow.premium_laps(screen.run))
	var seen: Dictionary = await _checkout_watching(screen)
	assert_float(seen["first_gold_tint"] as float).is_equal(1.0)
	assert_bool(screen._receipt.gold.shines()).is_false()
	assert_bool(screen._receipt.gold.is_shining()).is_false()


## A shift reaching the overtime ticket's laps (×2) only with its last item turns its receipt
## SILVER as that item is counted (not gold), its lighter inks stepped darker as on gold; no stub
## prints at its foot; the week badge's SILVER medal is spent (its socket empty), the GOLD still
## there (2026-11-06). A resumed screen shows the silver and the empty socket at once.
func test_the_tickets_laps_turn_the_receipt_silver() -> void:
	var screen: ShiftScreen = await _screen()
	var laps: int = ReceiptGoldFlow.ticket_laps(screen.run)
	assert_int(laps).is_equal(screen.run.balance.machine.overtime_ticket_laps)
	assert_int(laps).is_between(1, ReceiptGoldFlow.premium_laps(screen.run) - 1)
	await _last_item_reaches(screen, laps)
	var receipt: ReceiptView = screen._receipt
	assert_bool(receipt.gold.is_silver()).is_false()
	await Rush.checkout(screen)
	await get_tree().create_timer(BEAT).timeout
	assert_bool(receipt.gold.is_silver()).is_true()
	assert_bool(receipt.gold.is_gold()).is_false()
	assert_float(receipt.gold.silver_amount()).is_equal(1.0)
	assert_object(receipt.gold.face_colour()).is_equal(GoldPaperArt.SILVER[0])
	assert_float(_contrast(Palette.INK, GoldPaperArt.SILVER[0])).is_greater_equal(7.0)
	for ink: Color in ReceiptGold.INKS.values():
		(
			assert_float(_contrast(ink, GoldPaperArt.SILVER[0]))
			. override_failure_message(ink.to_html())
			. is_greater_equal(3.0)
		)
	assert_object(receipt.find_child("BonusStub", true, false)).is_null()
	var spent: Array[int] = [WeekMedals.State.USED, WeekMedals.State.AVAILABLE]
	assert_array(screen._stage.medal_case.states()).is_equal(spent)
	var resumed: ShiftScreen = await _screen()
	assert_bool(resumed._receipt.gold.is_silver()).is_true()
	assert_array(resumed._stage.medal_case.states()).is_equal(spent)


## A full belt on a passed payday with its review (the inspection): through the count and the
## dessert nothing on the paper is ever covered; the dessert prints nothing under its foot (no
## INSPECTION PASSED, no tear) and nothing beside it; no BONUS stub and no banner.
## The machine then feeds that very paper, its whole length, every row where it stood.
func test_a_full_belt_keeps_every_row_in_sight() -> void:
	var screen: ShiftScreen = await _screen()
	_low_quotas(screen, 5)
	screen._debug.skip_to_shift(PAYDAY_SHIFT)
	await _frames(2)
	_fill_belt(screen)
	await _frames(2)
	assert_bool(RowCapacity.fits(screen.run.limits, screen.run.row)).is_false()
	var rows: Array[Rect2] = _row_rects(screen)
	var paper: Rect2 = ReceiptFed.planned_rect(screen)
	var seen: Dictionary = await _checkout_watching(screen, rows)
	assert_bool(screen.run.history[-1].passed).is_true()
	assert_object(screen.run.history[-1].inspection).is_not_null()
	_assert_anchored(screen, seen, rows, paper)
	_assert_dessert_clear(screen, seen, paper)
	assert_bool(screen._receipt.payday_ribbon.visible).is_true()
	(
		assert_bool(seen["banner_seen"] as bool)
		. override_failure_message(str(seen.get("banner_at", "")))
		. is_false()
	)
	await _assert_fed_as_is(screen, rows)


## Low quotas on a copy of the balance (the loaded one is shared), its reviews Spot check alone.
func _low_quotas(screen: ShiftScreen, quota: int) -> void:
	var balance: BalanceDefinition = screen.run.balance.duplicate()
	var pool: Array[InspectionDefinition] = [load(SPOT_CHECK)]
	balance.inspection_pool = pool
	var quotas: PackedInt32Array = PackedInt32Array()
	quotas.resize(balance.quotas.size())
	quotas.fill(quota)
	balance.quotas = quotas
	screen.run.balance = balance
	screen.run.week = null  # Drawn again (from this pool) on the skip to the payday.


func _place_milks(screen: ShiftScreen, count: int) -> void:
	for _card: int in range(count):
		screen.run.place(screen.run.debug_add_to_hand(load(MILK)), screen.run.row.size())
	screen._refresh()


## Milks on every slot of the belt.
func _fill_belt(screen: ShiftScreen) -> void:
	while RowCapacity.fits(screen.run.limits, screen.run.row):
		var card: CardInstance = screen.run.debug_add_to_hand(load(MILK))
		if not screen.run.place(card, screen.run.row.size()):
			break
	screen._refresh()


## Places Milks and sets the quota so the row makes `laps` laps only with its last Milk.
func _last_item_reaches(screen: ShiftScreen, laps: int) -> void:
	_place_milks(screen, 3)
	var short_of: int = screen.run.preview().total
	_place_milks(screen, 1)
	var total: int = screen.run.preview().total
	var quota: int = floori(total / float(laps))
	assert_int(laps * quota).is_greater(short_of)
	screen.run.limits.quota = quota
	screen._refresh()
	await _frames(2)
	assert_int(screen.run.quota()).is_equal(quota)
	assert_int(OvertimeTickets.laps(total, quota)).is_greater_equal(laps)
	assert_int(OvertimeTickets.laps(short_of, quota)).is_less(laps)


## Checks out (rushed) and watches every frame until the checkout ends: whether the paper ever
## lost a payday's design (`plain_frames`), a printed row moved (`moved`), gold showed before item
## `last` was counted (`early_gold`), at all (`gold_while_counting`), as the count started (after
## the medal prelude: `gold_before_count`) and the count then lost it (`cream_while_counting`),
## silver showed (`silver_seen`), the tint of the first gold frame, and the TOTAL's inks once the
## verdict showed.
func _checkout_watching(screen: ShiftScreen, rows: Array[Rect2] = [], last: int = -1) -> Dictionary:
	var payday: bool = screen._receipt.payday_ribbon.visible
	var seen: Dictionary = {
		"plain_frames": false,
		"silver_seen": false,
		"moved": false,
		"moved_at": "",
		"early_gold": false,
		"gold_while_counting": false,
		"gold_before_count": false,
		"cream_while_counting": false,
		"first_gold_tint": -1.0,
		"covered": false,
		"covered_at": "",
		"verdict_gold": false,
		"verdict_inks": [],
		"header_lost": false,
		"banner_seen": false,
	}
	var printed: Array[Rect2] = rows.duplicate()
	var count_up: CountUp = screen._count_up
	var receipt: ReceiptView = screen._receipt
	var at_count: Callable = func(_views: Array[CardView]) -> void:
		seen["gold_before_count"] = receipt.gold.is_gold()
	count_up.count_started.connect(at_count, CONNECT_ONE_SHOT)
	(func() -> void: Rush.rush(count_up)).call_deferred()
	screen._on_checkout_pressed()
	for frame: int in range(MAX_FRAMES):
		await get_tree().process_frame
		var gold: bool = receipt.gold.is_gold()
		var plain: bool = payday and not receipt.payday_ribbon.visible
		seen["plain_frames"] = (seen["plain_frames"] as bool) or plain
		if receipt.gold.is_silver():
			seen["silver_seen"] = true
		# Whether item `last`'s row has printed (the count reached it).
		var reached: bool = receipt._print != null and receipt._print.row_of(last) != null
		if gold and (seen["first_gold_tint"] as float) < 0.0:
			seen["first_gold_tint"] = receipt.gold.amount()
		# The medals land in the prelude, before the count (MedalPrelude, 2026-11-09).
		if gold:
			seen["gold_while_counting"] = true
			if count_up._playing and last >= 0 and not reached:
				seen["early_gold"] = true
		elif count_up._playing and (seen["gold_before_count"] as bool):
			seen["cream_while_counting"] = true
		var beside: Array[String] = ReceiptFed.beside(screen, receipt.get_global_rect())
		if not beside.is_empty() and not (seen["banner_seen"] as bool):
			seen["banner_seen"] = true
			seen["banner_at"] = "frame %d: %s" % [frame, beside]
		var cover: String = _covered_row(screen)
		if not cover.is_empty() and not (seen["covered"] as bool):
			seen["covered"] = true
			seen["covered_at"] = "frame %d: %s" % [frame, cover]
		# Through the count and the dessert, to the checkout's end: a printed row stays put (main
		# scene v2: the rows print as the count reaches them) and the header shows.
		var now: Array[Rect2] = _row_rects(screen)
		for index: int in range(mini(printed.size(), now.size())):
			if now[index] != printed[index] and not (seen["moved"] as bool):
				seen["moved"] = true
				seen["moved_at"] = "frame %d: %s after %s" % [frame, now, printed]
		if now.size() >= printed.size():
			printed = now
		if not _header_shown(screen):
			seen["header_lost"] = true
		if count_up._verdict_shown:
			seen["verdict_gold"] = gold
			(seen["verdict_inks"] as Array).append(_ink(receipt.target.over))
		if not screen._counting and not screen._stage.gold_flow.flight.is_flying():
			break
	# The paper's last feed (left column v2: it lengthens to each line it printed) ends.
	for _frame: int in range(MAX_FRAMES):
		if receipt.hang == null or not receipt.hang.is_feeding():
			break
		await get_tree().process_frame
	return seen


## The checkout left every row where it printed on the paper (one per item) and the header showed
## at every frame, through the dessert's end; the paper only grew at its foot (_assert_fed_paper).
func _assert_anchored(
	screen: ShiftScreen, seen: Dictionary, _planned: Array[Rect2], paper: Rect2
) -> void:
	assert_bool(seen["moved"] as bool).override_failure_message(str(seen["moved_at"])).is_false()
	assert_bool(seen["header_lost"] as bool).is_false()
	assert_int(_row_rects(screen).size()).is_equal(screen.run.row.size())
	assert_bool(_header_shown(screen)).is_true()
	_assert_fed_paper(screen, paper)


## The paper hangs in `paper` (the count's room) fed on by the dessert's lines alone: its top on the
## printer's slot, its left edge and width kept, its fed lines on it under its foot;
## nothing right of it; its paid rows, TOTAL and margin on screen (ReceiptFed).
func _assert_fed_paper(screen: ShiftScreen, paper: Rect2) -> void:
	var failures: Array[String] = ReceiptFed.failures(
		screen._receipt, paper, screen.get_viewport_rect()
	)
	assert_array(failures).override_failure_message("\n".join(failures)).is_empty()


## The passed shift's dessert covered no paid row at any frame and printed nothing under the foot
## (the 2026-11-09 play test: no INSPECTION PASSED or tear line), PAID stamped on the header after
## the margin's words; no BONUS stub (2026-11-06).
func _assert_dessert_clear(screen: ShiftScreen, seen: Dictionary, paper: Rect2) -> void:
	(
		assert_bool(seen["covered"] as bool)
		. override_failure_message(str(seen["covered_at"]))
		. is_false()
	)
	var receipt: ReceiptView = screen._receipt
	assert_array(ReceiptFed.lines(receipt)).is_empty()
	var stamps: Array[Node] = receipt.find_children(ReceiptStamps.INSPECTION_NAME, "", true, false)
	assert_array(stamps).is_empty()
	assert_str(receipt.target.stamp.text).is_equal(ReceiptStamps.PAID_TEXT)
	assert_object(receipt.find_child("BonusStub", true, false)).is_null()
	_assert_fed_paper(screen, paper)


## The first thing on the paper a dessert line fed under the foot (INSPECTION PASSED's stamp too,
## once it has landed: it slams in from twice its size) covers: a paid row, the TOTAL
## or the margin line, TODAY'S TARGET or the header; or "".
static func _covered_row(screen: ShiftScreen) -> String:
	var receipt: ReceiptView = screen._receipt
	var covers: Array[Rect2] = []
	for line: Control in ReceiptFed.lines(receipt):
		covers.append(line.get_global_rect())
		var stamp_of: PanelContainer = ReceiptStamps.inspection_of(line)
		if stamp_of != null and stamp_of.scale.is_equal_approx(Vector2.ONE):
			covers.append(stamp_of.get_global_rect())
	var shown: Dictionary[String, Rect2] = {}
	var printed: Array[Control] = receipt.printed_rows()
	for slot: int in range(printed.size()):
		shown["row %d" % slot] = printed[slot].get_global_rect()
	if receipt.target.is_visible_in_tree():
		shown["header"] = receipt.target.get_global_rect()
	for what: String in shown:
		var rect: Rect2 = shown[what].grow(-0.5)
		for cover: Rect2 in covers:
			if cover.has_area() and cover.intersects(rect):
				return "%s %s under %s" % [what, rect, cover]
	return ""


## The machine feeds the stage's paper itself (ReceiptFeed takes it), its whole length: on the
## machine it is the shift screen's receipt, its rows (`rows`, where planning put them on it) and
## its fed lines where the dessert left them on it, covering nothing; once the visit ends it is back
## on the stage, hidden.
func _assert_fed_as_is(screen: ShiftScreen, _planned: Array[Rect2]) -> void:
	var receipt: ReceiptView = screen._receipt
	var rows: Array[Rect2] = _row_rects(screen)
	var fed: Array[Vector2] = _fed_offsets(receipt)
	var paper_at: Rect2 = receipt.get_global_rect()
	var length: float = receipt.size.y
	var view: RewardMachineView = screen._machine.view
	var feed: ReceiptFeed = view.receipt_feed
	for frame: int in range(MAX_FRAMES):
		if feed.paper != null:
			break
		await get_tree().process_frame
	assert_object(feed.paper).is_same(receipt)
	assert_object(receipt.get_parent().get_parent()).is_same(feed.clip)
	assert_float(feed.full_height()).is_equal(length)
	view.show_at(view.plan.fly)
	assert_float(receipt.size.y).is_equal(length)
	assert_array(_row_rects(screen)).is_equal(rows)
	assert_array(_fed_offsets(receipt)).is_equal(fed)
	assert_str(_covered_row(screen)).is_empty()
	screen._machine.debug_skip()
	await _frames(2)
	assert_object(receipt.get_parent()).is_same(screen._stage.receipt_slot)
	assert_float(receipt.get_global_rect().position.x).is_equal(paper_at.position.x)


## Whether the receipt's header (main scene v2: the target and the hero) shows.
static func _header_shown(screen: ShiftScreen) -> bool:
	return screen._receipt.target.is_visible_in_tree()


## Each item row's rect on the printed strip (the receipt's lines' own coordinates: past the
## paper's room the dessert's lines scroll the strip up under the header, v1.18 review, its rows
## with it), in slot order.
static func _row_rects(screen: ShiftScreen) -> Array[Rect2]:
	var rects: Array[Rect2] = []
	var on_paper: Transform2D = screen._receipt._lines.get_global_transform().affine_inverse()
	for row: Control in screen._receipt.printed_rows():
		rects.append(on_paper * row.get_global_rect())
	return rects


## Each fed line's place on the paper (its own coordinates), top to bottom.
static func _fed_offsets(receipt: ReceiptView) -> Array[Vector2]:
	var offsets: Array[Vector2] = []
	var on_paper: Transform2D = receipt.get_global_transform().affine_inverse()
	for line: Control in ReceiptFed.lines(receipt):
		offsets.append(on_paper * line.global_position)
	return offsets


func _screen() -> ShiftScreen:
	var scene: PackedScene = load(SCREEN)
	var screen: ShiftScreen = auto_free(scene.instantiate())
	scene_runner(screen)
	await _frames(4)
	return screen


func _frames(count: int) -> void:
	for i: int in range(count):
		await get_tree().process_frame


static func _ink(label: Label) -> Color:
	return label.get_theme_color("font_color")


static func _contrast(a: Color, b: Color) -> float:
	var la: float = a.srgb_to_linear().get_luminance()
	var lb: float = b.srgb_to_linear().get_luminance()
	return (maxf(la, lb) + 0.05) / (minf(la, lb) + 0.05)


static func _event_log() -> EventLogService:
	return (Engine.get_main_loop() as SceneTree).root.get_node("/root/EventLog")
