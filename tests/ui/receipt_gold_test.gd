extends GdUnitTestSuite
## The receipt's gold paper and its anchored count (2026-11-05: ReceiptGold, ReceiptGoldFlow,
## ReceiptPaidRows) on the real shift screen and alone: a payday shift's receipt is gold from its
## opening (a resume's too, at once under reduced motion) through its verdict, passed or missed, and
## cream again at the next ordinary shift; an ordinary shift's turns gold, with the "3× QUOTA"
## stamp, when its paid total reaches the overtime PREMIUM laps (reached on its last item too); the
## count pays planning's rows in place, every row keeping its place on the paper, and its dessert
## covers no paid row (a passed payday's inspection, a full belt: its lines print on the paper under
## its foot, which grows and rises by them, 2026-11-07, never on a slip beside it; no stub prints
## since 2026-11-06, the receipt pays every draw; nor the TOTAL, the margin, the target with its
## stamp or the header), and the machine feeds that very paper, its whole length. The gold is the
## announce slip's material (GoldPaperArt: its glint and sparkles, none under reduced motion). On
## the gold the ink stays dark and the warnings legible. Layout asserts on-screen geometry (memory:
## UI tests check layout).

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


## The gold paper alone: gold at once when `instant` (no glint, no sparkles), after its fade
## otherwise (glinting); on it the light inks step darker (tomato, the waiting grey, green, teal)
## and the dashed rules turn amber; back on cream every ink is its own again. Every ink on the gold
## reads: the ink dark (7:1 and more), the stepped ones 3:1 and more. The paper is never tinted
## flat: its gold is drawn (GoldPaperArt).
func test_the_gold_paper_keeps_its_inks_legible() -> void:
	var receipt: ReceiptView = auto_free(ReceiptView.new())
	add_child(receipt)
	var notice: Label = receipt.add_notice("NEXT: SPOT CHECK").get_child(0) as Label
	var waiting: Label = (
		receipt.add_line("5 ·····", "", ReceiptView.LineStyle.WAITING).get_child(0) as Label
	)
	var projected: Control = receipt.add_line("PROJECTED", "9.00€", ReceiptView.LineStyle.PROJECTED)
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
	# A brief change in place: the gold fades in, glinting, the paper never moves.
	var rect: Rect2 = receipt.get_global_rect()
	receipt.gold.show_gold(true)
	assert_float(receipt.gold.amount()).is_less(1.0)
	assert_bool(receipt.gold.shines()).is_true()
	await get_tree().create_timer(ReceiptGold.FADE_SECONDS + 0.1).timeout
	assert_float(receipt.gold.amount()).is_equal(1.0)
	assert_object(receipt.get_global_rect()).is_equal(rect)


## The gold is the PAYDAY / PREMIUM NEXT announce slip's: its gold face, its glint every
## SHINE_PERIOD (sweeping across, then gone till the next), its sparkles only as it turns gold.
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


## A payday shift opens gold (PAYDAY NEXT's check), its planning receipt's short line stepped to
## tomato dark; an ordinary shift opens cream; under reduced motion the switch is at once; a
## resumed payday planning is gold too.
func test_a_payday_shift_opens_gold() -> void:
	var screen: ShiftScreen = await _screen()
	screen._debug.skip_to_shift(PAYDAY_SHIFT)
	await _frames(2)
	assert_bool(ReceiptGoldFlow.payday(screen.run)).is_true()
	assert_bool(screen._receipt.gold.is_gold()).is_true()
	await get_tree().create_timer(ReceiptGold.FADE_SECONDS + 0.1).timeout
	assert_float(screen._receipt.gold.amount()).is_equal(1.0)
	var against: Label = screen._receipt._against.get_child(1) as Label
	assert_object(_ink(against)).is_equal(ReceiptGold.ink_on_gold(Palette.TOMATO))
	assert_object(screen._receipt.gold.stamp()).is_null()
	screen._debug.skip_to_shift(ORDINARY_SHIFT)
	await _frames(1)
	assert_bool(ReceiptGoldFlow.payday(screen.run)).is_false()
	assert_bool(screen._receipt.gold.is_gold()).is_false()
	screen.profile.settings[ProfileState.REDUCED_MOTION_KEY] = true
	screen._debug.skip_to_shift(PAYDAY_SHIFT)
	# Reduced motion: gold in the very frame the shift opens, with no glint.
	assert_float(screen._receipt.gold.amount()).is_equal(1.0)
	assert_bool(screen._receipt.gold.shines()).is_false()
	var resumed: ShiftScreen = await _screen()
	assert_int(resumed.run.shift_index).is_equal(PAYDAY_SHIFT - 1)
	assert_int(resumed.run.phase).is_equal(RunState.Phase.PLANNING)
	assert_bool(resumed._receipt.gold.is_gold()).is_true()


## A passed payday keeps its gold through the count and the verdict (the TOTAL green dark on the
## gold), its dessert covering no paid row at any frame, then the next ordinary shift opens cream.
func test_a_passed_payday_stays_gold_through_its_verdict() -> void:
	var screen: ShiftScreen = await _screen()
	_low_quotas(screen, 5)
	screen._debug.skip_to_shift(PAYDAY_SHIFT)
	await _frames(2)
	_place_milks(screen, 2)
	await _frames(2)
	var rows: Array[Rect2] = _row_rects(screen)
	var paper: Rect2 = screen._receipt.get_global_rect()
	assert_bool(_header_shown(screen)).is_true()
	var seen: Dictionary = await _checkout_watching(screen, rows)
	assert_bool(seen["cream_frames"] as bool).is_false()
	assert_bool(screen.run.history[-1].passed).is_true()
	assert_bool(screen._receipt.gold.is_gold()).is_true()
	await _frames(1)
	_assert_anchored(screen, seen, rows, paper)
	_assert_dessert_clear(screen, seen, paper)
	var total: Label = screen._receipt.total_label()
	var verdict: String = ReceiptView.verdict_text(screen.run.last_result.total, screen.run.quota())
	assert_str(total.text).is_equal(verdict)
	assert_object(_ink(total)).is_equal(Palette.GREEN_DARK)
	screen._machine.debug_skip()
	await _frames(2)
	assert_int(screen.run.shift_index).is_equal(ORDINARY_SHIFT - 1)
	assert_bool(screen._receipt.gold.is_gold()).is_false()
	assert_object(screen._receipt.gold.stamp()).is_null()


## A missed payday keeps its gold through the verdict (the TOTAL and SHORT tomato dark), then the
## next ordinary shift (its slip moves the run on) opens cream.
func test_a_missed_payday_stays_gold_through_its_verdict() -> void:
	var screen: ShiftScreen = await _screen()
	screen._debug.skip_to_shift(PAYDAY_SHIFT)
	await _frames(2)
	_place_milks(screen, 1)
	assert_int(screen.run.preview().total).is_less(screen.run.quota())
	await _frames(2)
	var rows: Array[Rect2] = _row_rects(screen)
	var paper: Rect2 = screen._receipt.get_global_rect()
	var seen: Dictionary = await _checkout_watching(screen, rows)
	assert_bool(seen["cream_frames"] as bool).is_false()
	assert_bool(seen["verdict_gold"] as bool).is_true()
	assert_bool(screen.run.history[-1].passed).is_false()
	var inks: Array = seen["verdict_inks"]
	assert_array(inks).contains([Palette.TOMATO_DARK])
	await _frames(1)
	_assert_anchored(screen, seen, rows, paper)
	assert_bool(screen._receipt.gold.is_gold()).is_true()
	# A missed shift has no machine visit: the run moves on to the next (ordinary) shift by itself
	# (its slip), which opens on cream, with no stamp.
	assert_int(screen.run.phase).is_equal(RunState.Phase.SCORED)
	for _frame: int in range(MAX_FRAMES):
		if screen.run.phase != RunState.Phase.SCORED:
			break
		await get_tree().process_frame
	assert_int(screen.run.phase).is_equal(RunState.Phase.PLANNING)
	assert_int(screen.run.shift_index).is_equal(ORDINARY_SHIFT - 1)
	assert_bool(ReceiptGoldFlow.payday(screen.run)).is_false()
	assert_bool(screen._receipt.gold.is_gold()).is_false()
	await get_tree().create_timer(ReceiptGold.FADE_SECONDS + 0.1).timeout
	assert_float(screen._receipt.gold.amount()).is_equal(0.0)
	assert_object(screen._receipt.gold.stamp()).is_null()


## An ordinary shift reaching the PREMIUM laps (×3) only with its last item: the paper is cream
## until that item is counted, then gold with the "3× QUOTA" stamp; through the count the paper
## never moves and every row keeps its place, paid in place; the stamp sits on the target, inside
## the paper. A resumed screen shows it all at once.
func test_overtime_on_the_last_item_turns_the_receipt_gold() -> void:
	var screen: ShiftScreen = await _screen()
	var laps: int = ReceiptGoldFlow.premium_laps(screen.run)
	assert_int(laps).is_equal(screen.run.balance.machine.overtime_premium_laps)
	assert_int(laps).is_greater(0)
	await _last_item_reaches(screen, laps)
	assert_bool(screen._receipt.gold.is_gold()).is_false()
	var rows: Array[Rect2] = _row_rects(screen)
	var paper: Rect2 = screen._receipt.get_global_rect()
	var last: int = screen.run.row.size() - 1
	var seen: Dictionary = await _checkout_watching(screen, rows, last)
	assert_bool(seen["moved"] as bool).override_failure_message(str(seen["moved_at"])).is_false()
	assert_bool(seen["early_gold"] as bool).is_false()
	assert_bool(seen["gold_while_counting"] as bool).is_true()
	_assert_fed_paper(screen, paper)
	assert_bool(screen._receipt.gold.is_gold()).is_true()
	var stamp: PanelContainer = screen._receipt.gold.stamp()
	assert_object(stamp).is_not_null()
	assert_str((stamp.get_child(0) as Label).text).is_equal(
		"%d%s QUOTA" % [laps, OvertimeWords.TIMES]
	)
	assert_bool(screen._receipt.get_global_rect().encloses(stamp.get_global_rect())).is_true()
	var digits: Rect2 = screen._receipt.target.digits_rect()
	var target: Rect2 = screen._receipt.target.get_global_rect()
	var number: Rect2 = Rect2(target.position + digits.position, digits.size)
	assert_bool(stamp.get_global_rect().intersects(number)).is_false()
	# The rows were paid in place: each item's amount is its payout, in ink.
	for slot: int in range(screen.run.row.size()):
		var amount: Label = screen._receipt._items[slot].get_child(1) as Label
		assert_str(amount.text).is_equal(ReceiptView.money(screen.run.last_result.payouts[slot]))
		assert_object(_ink(amount)).is_equal(Palette.INK)
	assert_str((screen._receipt._projected.get_child(0) as Label).text).is_equal(
		ReceiptView.TOTAL_TEXT
	)
	var resumed: ShiftScreen = await _screen()
	assert_int(resumed.run.phase).is_equal(RunState.Phase.MACHINE_CHOOSE)
	assert_bool(resumed._receipt.gold.is_gold()).is_true()
	assert_object(resumed._receipt.gold.stamp()).is_not_null()
	assert_str((resumed._receipt._projected.get_child(0) as Label).text).is_equal(
		ReceiptView.TOTAL_TEXT
	)
	assert_int(resumed._receipt._items.size()).is_equal(screen.run.row.size())


## A payday reaching the PREMIUM laps only with its last item: the paper is gold from the
## shift's opening and never fades again; the GOLD medal stays in its socket (a payday's visit is
## PREMIUM already, 2026-11-06), while the SILVER, still to spend, lands its "2× QUOTA" stamp once
## its lap is counted; the rows stay put through the dessert.
func test_a_payday_reaching_overtime_gets_the_stamp_only() -> void:
	var screen: ShiftScreen = await _screen()
	screen._debug.skip_to_shift(PAYDAY_SHIFT)
	await get_tree().create_timer(ReceiptGold.FADE_SECONDS + 0.1).timeout
	var laps: int = ReceiptGoldFlow.premium_laps(screen.run)
	await _last_item_reaches(screen, laps)
	assert_bool(ReceiptGoldFlow.payday(screen.run)).is_true()
	assert_bool(screen._receipt.gold.is_gold()).is_true()
	assert_float(screen._receipt.gold.amount()).is_equal(1.0)
	assert_object(screen._receipt.gold.stamp()).is_null()
	var rows: Array[Rect2] = _row_rects(screen)
	var paper: Rect2 = screen._receipt.get_global_rect()
	var silver: int = ReceiptGoldFlow.ticket_laps(screen.run)
	var seen: Dictionary = await _checkout_watching(screen, rows, -1, silver)
	assert_bool(seen["cream_frames"] as bool).is_false()
	assert_bool(seen["tint_changed"] as bool).is_false()
	assert_bool(seen["stamp_while_counting"] as bool).is_true()
	assert_str(_stamp_text(screen._receipt)).starts_with(str(silver))
	var spent: Array[int] = [WeekMedals.State.USED, WeekMedals.State.AVAILABLE]
	assert_array(screen._stage.top_bar.week_chip.medals().states()).is_equal(spent)
	_assert_anchored(screen, seen, rows, paper)


## Under reduced motion the overtime's gold switches at once: the first gold frame of the count is
## already all gold, with no glint and no sparkles, and the stamp lands at its size.
func test_overtime_gold_is_instant_under_reduced_motion() -> void:
	var screen: ShiftScreen = await _screen()
	screen.profile.settings[ProfileState.REDUCED_MOTION_KEY] = true
	await _last_item_reaches(screen, ReceiptGoldFlow.premium_laps(screen.run))
	var seen: Dictionary = await _checkout_watching(screen)
	assert_float(seen["first_gold_tint"] as float).is_equal(1.0)
	assert_bool(screen._receipt.gold.shines()).is_false()
	var stamp: PanelContainer = screen._receipt.gold.stamp()
	assert_object(stamp.scale).is_equal(Vector2.ONE)


## The 2026-11-05 review: a shift reaching the overtime ticket's laps (×2) only with its last item
## turns its receipt SILVER as that item is counted (not gold), with a steel "2× QUOTA" stamp, its
## lighter inks stepped darker as on gold; no OVERTIME stub prints at its foot; the week badge's
## SILVER medal is spent (its socket empty), the GOLD still there (2026-11-06). A resumed screen
## shows the silver, the stamp and the empty socket at once.
func test_the_tickets_laps_turn_the_receipt_silver() -> void:
	var screen: ShiftScreen = await _screen()
	var laps: int = ReceiptGoldFlow.ticket_laps(screen.run)
	assert_int(laps).is_equal(screen.run.balance.machine.overtime_ticket_laps)
	assert_int(laps).is_between(1, ReceiptGoldFlow.premium_laps(screen.run) - 1)
	await _last_item_reaches(screen, laps)
	var receipt: ReceiptView = screen._receipt
	assert_bool(receipt.gold.is_silver()).is_false()
	await Rush.checkout(screen)
	await get_tree().create_timer(ReceiptGold.FADE_SECONDS + 0.1).timeout
	assert_bool(receipt.gold.is_silver()).is_true()
	assert_bool(receipt.gold.is_gold()).is_false()
	assert_float(receipt.gold.silver_amount()).is_equal(1.0)
	assert_object(receipt.gold.face_colour()).is_equal(GoldPaperArt.SILVER[0])
	# The ink stays legible on the silver as on the gold.
	assert_float(_contrast(Palette.INK, GoldPaperArt.SILVER[0])).is_greater_equal(7.0)
	for ink: Color in ReceiptGold.INKS.values():
		(
			assert_float(_contrast(ink, GoldPaperArt.SILVER[0]))
			. override_failure_message(ink.to_html())
			. is_greater_equal(3.0)
		)
	var stamp: PanelContainer = receipt.gold.stamp()
	assert_object(stamp).is_not_null()
	assert_str((stamp.get_child(0) as Label).text).is_equal(
		"%d%s QUOTA" % [laps, OvertimeWords.TIMES]
	)
	var style: StyleBoxFlat = stamp.get_theme_stylebox("panel") as StyleBoxFlat
	assert_object(style.bg_color).is_equal(ReceiptGold.SILVER_STAMP_FACE)
	assert_object(receipt.find_child("BonusStub", true, false)).is_null()
	var rule: HSeparator = receipt.find_children("*", "HSeparator", true, false)[0] as HSeparator
	assert_object(ReceiptGold.rule_ink(rule, Palette.CREAM_SHADE)).is_equal(
		ReceiptGold.SILVER_RULE_INK
	)
	var spent: Array[int] = [WeekMedals.State.USED, WeekMedals.State.AVAILABLE]
	assert_array(screen._stage.top_bar.week_chip.medals().states()).is_equal(spent)
	var resumed: ShiftScreen = await _screen()
	assert_bool(resumed._receipt.gold.is_silver()).is_true()
	assert_object(resumed._receipt.gold.stamp()).is_not_null()
	assert_array(resumed._stage.top_bar.week_chip.medals().states()).is_equal(spent)


## The stamp alone: "N× QUOTA" with the data's laps; 0 takes it off.
func test_the_quota_stamp_reads_the_laps() -> void:
	var receipt: ReceiptView = auto_free(ReceiptView.new())
	add_child(receipt)
	receipt.size = Vector2(ShiftStage.RECEIPT_WIDTH, 300.0)
	receipt.target.show_quota(65)
	await _frames(2)
	receipt.gold.show_stamp(3, true)
	var stamp: PanelContainer = receipt.gold.stamp()
	assert_str((stamp.get_child(0) as Label).text).is_equal("3× QUOTA")
	assert_bool(receipt.get_global_rect().encloses(stamp.get_global_rect())).is_true()
	receipt.gold.show_stamp(0, true)
	await _frames(1)
	assert_object(receipt.gold.stamp()).is_null()


## A full belt on a passed payday with its review (the inspection): through the count and the
## dessert nothing on the paper is ever covered; the dessert's lines (INSPECTION PASSED, the tear)
## print on the gold paper under its foot, the paper growing at its foot and rising by them, and
## nothing prints beside it (2026-11-07); no BONUS stub prints and no banner shows (2026-11-06: the
## receipt itself pays the payday's two PREMIUM draws). The machine then feeds that very paper,
## its whole length, every row where it stood.
func test_a_full_belt_keeps_every_row_in_sight() -> void:
	var screen: ShiftScreen = await _screen()
	_low_quotas(screen, 5)
	screen._debug.skip_to_shift(PAYDAY_SHIFT)
	await _frames(2)
	_fill_belt(screen)
	await _frames(2)
	assert_bool(RowCapacity.fits(screen.run.limits, screen.run.row)).is_false()
	var rows: Array[Rect2] = _row_rects(screen)
	var paper: Rect2 = screen._receipt.get_global_rect()
	var seen: Dictionary = await _checkout_watching(screen, rows)
	assert_bool(screen.run.history[-1].passed).is_true()
	assert_object(screen.run.history[-1].inspection).is_not_null()
	_assert_anchored(screen, seen, rows, paper)
	_assert_dessert_clear(screen, seen, paper)
	assert_bool(screen._receipt.gold.is_gold()).is_true()
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


## Checks out (rushed) and watches every frame until the checkout ends: whether the paper was
## ever cream (`cream_frames`), the rows moved from `rows` before the total (`moved`), gold showed
## before item `last` was counted (`early_gold`) or while counting (`gold_while_counting`), the
## tint of the first gold frame, and the TOTAL's inks once the verdict showed.
func _checkout_watching(
	screen: ShiftScreen, rows: Array[Rect2] = [], last: int = -1, laps: int = -1
) -> Dictionary:
	var stamp_laps: int = laps if laps > 0 else ReceiptGoldFlow.premium_laps(screen.run)
	var seen: Dictionary = {
		"cream_frames": false,
		"moved": false,
		"moved_at": "",
		"early_gold": false,
		"gold_while_counting": false,
		"first_gold_tint": -1.0,
		"covered": false,
		"covered_at": "",
		"verdict_gold": false,
		"verdict_inks": [],
		"header_lost": false,
		"tint_changed": false,
		"early_stamp": false,
		"stamp_while_counting": false,
		"banner_seen": false,
	}
	var opening_tint: float = screen._receipt.gold.amount()
	var count_up: CountUp = screen._count_up
	(func() -> void: Rush.rush(count_up)).call_deferred()
	screen._on_checkout_pressed()
	var receipt: ReceiptView = screen._receipt
	for frame: int in range(MAX_FRAMES):
		await get_tree().process_frame
		var gold: bool = receipt.gold.is_gold()
		seen["cream_frames"] = (seen["cream_frames"] as bool) or not gold
		var framed: Control = receipt._framed_line()
		if gold and (seen["first_gold_tint"] as float) < 0.0:
			seen["first_gold_tint"] = receipt.gold.amount()
		# A medal lands a flight after its lap (MedalFlight, 2026-11-06): under the rushed count
		# that can be after the count, before the machine feeds the paper.
		if gold:
			seen["gold_while_counting"] = true
			var counting: bool = count_up._playing and last >= 0 and framed != null
			if counting and framed != receipt._items.get(last):
				seen["early_gold"] = true
		# The `stamp_laps` stamp (the ×2's silver stamp may land earlier: it is the SILVER's).
		var stamped: bool = _stamp_text(receipt).begins_with(str(stamp_laps))
		if stamped and screen._counting:
			seen["stamp_while_counting"] = true
			if last >= 0 and framed != null and framed != receipt._items.get(last):
				seen["early_stamp"] = true
		if receipt.gold.amount() != opening_tint:
			seen["tint_changed"] = true
		var beside: Array[String] = ReceiptFed.beside(screen, receipt.get_global_rect())
		if not beside.is_empty() and not (seen["banner_seen"] as bool):
			seen["banner_seen"] = true
			seen["banner_at"] = "frame %d: %s" % [frame, beside]
		var cover: String = _covered_row(screen)
		if not cover.is_empty() and not (seen["covered"] as bool):
			seen["covered"] = true
			seen["covered_at"] = "frame %d: %s" % [frame, cover]
		# Through the count and the dessert, to the checkout's end: rows and header stay put.
		if not rows.is_empty() and _row_rects(screen) != rows:
			seen["moved"] = true
			seen["moved_at"] = "frame %d: %s" % [frame, _row_rects(screen)]
		if not rows.is_empty() and not _header_shown(screen):
			seen["header_lost"] = true
		if count_up._verdict_shown and receipt.total_label() != null:
			seen["verdict_gold"] = gold
			(seen["verdict_inks"] as Array).append(_ink(receipt.total_label()))
		if not screen._counting and not screen._stage.gold_flow.flight.is_flying():
			break
	await get_tree().create_timer(ReceiptGold.STAMP_SLAM_SECONDS + 0.1).timeout  # Settled.
	return seen


## The checkout left every row where planning put it on the paper and the SHIFT line showed at
## every frame, through the dessert's end; the paper only grew at its foot by the dessert's lines
## (_assert_fed_paper).
func _assert_anchored(
	screen: ShiftScreen, seen: Dictionary, rows: Array[Rect2], paper: Rect2
) -> void:
	assert_bool(seen["moved"] as bool).override_failure_message(str(seen["moved_at"])).is_false()
	assert_bool(seen["header_lost"] as bool).is_false()
	assert_array(_row_rects(screen)).is_equal(rows)
	assert_bool(_header_shown(screen)).is_true()
	_assert_fed_paper(screen, paper)


## The paper is `paper` (planning's) fed on by the dessert's lines alone: its foot on the printer,
## its left edge and width kept, as much taller as its fed lines, which lie on it under its foot;
## nothing right of it; its paid rows, TOTAL and margin on screen (ReceiptFed).
func _assert_fed_paper(screen: ShiftScreen, paper: Rect2) -> void:
	var failures: Array[String] = ReceiptFed.failures(
		screen._receipt, paper, screen.get_viewport_rect()
	)
	assert_array(failures).override_failure_message("\n".join(failures)).is_empty()


## The passed shift's dessert covered no paid row at any frame: INSPECTION PASSED is its first
## fed line, on the paper under its foot; no BONUS stub (2026-11-06).
func _assert_dessert_clear(screen: ShiftScreen, seen: Dictionary, paper: Rect2) -> void:
	(
		assert_bool(seen["covered"] as bool)
		. override_failure_message(str(seen["covered_at"]))
		. is_false()
	)
	var receipt: ReceiptView = screen._receipt
	var fed: Array[Control] = ReceiptFed.lines(receipt)
	assert_bool(fed.is_empty()).is_false()
	assert_object(ReceiptStamps.inspection_of(fed[0])).is_not_null()
	assert_object(receipt.find_child("BonusStub", true, false)).is_null()
	_assert_fed_paper(screen, paper)


## The first thing on the paper a dessert line fed under the foot (INSPECTION PASSED's stamp too,
## once it has landed: it slams in from twice its size) covers: a paid row, the TOTAL
## or the margin line, TODAY'S TARGET (its quota stamp too) or the header; or "".
static func _covered_row(screen: ShiftScreen) -> String:
	var receipt: ReceiptView = screen._receipt
	var covers: Array[Rect2] = []
	for line: Control in ReceiptFed.lines(receipt):
		covers.append(line.get_global_rect())
		var stamp_of: PanelContainer = ReceiptStamps.inspection_of(line)
		if stamp_of != null and stamp_of.scale.is_equal_approx(Vector2.ONE):
			covers.append(stamp_of.get_global_rect())
	var shown: Dictionary[String, Rect2] = {}
	for slot: int in receipt._items:
		shown["row %d" % slot] = receipt._items[slot].get_global_rect()
	var lines: Array[Control] = [receipt._projected, receipt._against, receipt.target]
	for line: Control in lines:
		if is_instance_valid(line) and line.is_visible_in_tree():
			shown[str(line.name)] = line.get_global_rect()
	for line: Control in receipt._header:
		if line.is_visible_in_tree():
			shown["header"] = line.get_global_rect()
	var stamp: PanelContainer = receipt.gold.stamp()
	if stamp != null:
		shown["quota stamp"] = stamp.get_global_rect()
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
func _assert_fed_as_is(screen: ShiftScreen, rows: Array[Rect2]) -> void:
	var receipt: ReceiptView = screen._receipt
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
	assert_object(receipt.get_parent()).is_same(screen._stage.fore)
	assert_float(receipt.get_global_rect().position.x).is_equal(paper_at.position.x)


## Whether the receipt's header (its SHIFT line) shows.
static func _header_shown(screen: ShiftScreen) -> bool:
	for line: Control in screen._receipt._header:
		if not line.is_visible_in_tree():
			return false
	return not screen._receipt._header.is_empty()


## Each item row's rect on the paper (its own coordinates: the paper rises as the printer feeds
## the dessert's lines on, 2026-11-07, its rows with it), in slot order.
static func _row_rects(screen: ShiftScreen) -> Array[Rect2]:
	var rects: Array[Rect2] = []
	var on_paper: Transform2D = screen._receipt.get_global_transform().affine_inverse()
	for slot: int in range(screen._receipt._items.size()):
		rects.append(on_paper * screen._receipt._items[slot].get_global_rect())
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


static func _stamp_text(receipt: ReceiptView) -> String:
	var stamp: PanelContainer = receipt.gold.stamp()
	return (stamp.get_child(0) as Label).text if stamp != null else ""


static func _contrast(a: Color, b: Color) -> float:
	var la: float = a.srgb_to_linear().get_luminance()
	var lb: float = b.srgb_to_linear().get_luminance()
	return (maxf(la, lb) + 0.05) / (minf(la, lb) + 0.05)


static func _event_log() -> EventLogService:
	return (Engine.get_main_loop() as SceneTree).root.get_node("/root/EventLog")
