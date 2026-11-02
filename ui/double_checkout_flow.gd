class_name DoubleCheckoutFlow
extends RefCounted
## The Double checkout on the shift screen (#122 part 2, a badge pin: RunPins.row_slots; decided
## with the user on 2026-10-31 and 2026-11-01). A shift checks out two rows. Row 1's CHECKOUT
## counts row 1 at once (its lines print on the receipt and the gauge fills part way) but stops
## before the total: no verdict, no dessert, no machine. The hand then refills and planning comes
## back for row 2, whose receipt header says row 1's amount and whose preview, PROJECTED line and
## gauge count on from it. Row 2's CHECKOUT is the shift's: its count carries on from row 1's total
## (ScoreResult.continued) to the one verdict and dessert. Static helpers split out of ShiftScreen
## to keep that file short; they work on the screen's run and display.
##
## What shows the two rows (the user's choice of 2026-11-02): the belt shortened to a row's cells
## (BeltPanel.set_cells), "CHECKOUT 1/2" then "CHECKOUT 2/2" on the key, two pips under the
## quota tube (RowPips, the first gold once row 1 is counted), and a ROW 2 banner popping over the
## belt as the hand refills after row 1's count, then fading (show_banner).

## The receipt header's row line (receipt_header): row 1, then row 2 with row 1's amount.
const ROW_ONE_TEXT := "ROW 1 OF 2"
const ROW_TWO_TEXT := "ROW 1 %s · ROW 2 OF 2"
## The key's row ("CHECKOUT 1/2"), and the banner over the belt for row 2.
const KEY_ROW_TEXT := "%d/2"
const BANNER_TEXT := "ROW 2"
const BANNER_NAME := &"RowBanner"
const BANNER_FONT_SIZE := 44
## Over the belt's top face (stage y), popping in from BANNER_POP over BANNER_IN_SECONDS, held
## BANNER_HOLD_SECONDS, then fading over BANNER_OUT_SECONDS.
const BANNER_Y := 372.0
const BANNER_POP := 0.55
const BANNER_IN_SECONDS := 0.22
const BANNER_HOLD_SECONDS := 0.9
const BANNER_OUT_SECONDS := 0.4


## The result the screen shows for the row on the belt, counted on from row 1's total on a Double
## checkout shift's row 2: the preview (`result`, RunState.preview) while planning.
static func on_from_row_one(run: RunState, result: ScoreResult) -> ScoreResult:
	if run.first_result == null or result == null:
		return result
	return ScoreResult.continued(result, run.first_result.total)


## The checked-out row's result as the count-up plays it: row 2's counted on from row 1's total
## on a Double checkout shift, row 1's alone after its checkout, else the shift's.
static func counted(run: RunState) -> ScoreResult:
	if run.row_result == null:
		return run.last_result
	if run.first_result == null or run.row_result == run.first_result:
		return run.row_result
	return ScoreResult.continued(run.row_result, run.first_result.total)


## The receipt header (ReceiptView.header_lines), with its row line on a Double checkout shift.
static func header(run: RunState) -> PackedStringArray:
	var lines: PackedStringArray = ReceiptView.header_lines(
		run.shift_index + 1, run.shift_count(), run.row.size()
	)
	if RunPins.row_slots(run) <= 0:
		return lines
	var row_line: String = ROW_ONE_TEXT
	if run.first_result != null:
		row_line = ROW_TWO_TEXT % ReceiptView.money(run.first_result.total)
	var with_row: PackedStringArray = lines.duplicate()
	with_row.append(row_line)
	return with_row


## The row on the key and the gauge's pips (none without the pin): row 1 until its count ends,
## then row 2, both pips gold once the shift is checked out.
static func refresh(screen: ShiftScreen) -> void:
	var run: RunState = screen.run
	var pips: RowPips = screen._stage.tower.row_pips
	if RunPins.row_slots(run) <= 0:
		screen._cabinet.set_checkout_row("")
		pips.show_rows(0, 0)
		return
	var row: int = 1 if run.first_result == null else 2
	var done: int = row - 1
	if run.phase != RunState.Phase.PLANNING:
		done = 2
	elif screen._counting and run.row_result == run.first_result:
		done = 0  # Row 1 is being counted: its pip fills when the count ends.
	screen._cabinet.set_checkout_row(KEY_ROW_TEXT % row)
	pips.show_rows(done, 2)


## Pops BANNER_TEXT over the belt's middle, holds it, then fades it out and frees it.
static func show_banner(screen: ShiftScreen) -> Label:
	var stage: ShiftStage = screen._stage
	var old: Node = stage.get_node_or_null(NodePath(BANNER_NAME))
	if old != null:
		old.free()
	var banner: Label = UiKit.display_label(BANNER_TEXT, BANNER_FONT_SIZE, true)
	banner.name = BANNER_NAME
	banner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	banner.add_theme_color_override("font_color", Palette.GOLD)
	stage.add_child(banner)
	banner.size = banner.get_minimum_size()
	var belt: BeltPanel = stage.belt
	var middle: float = (
		ShiftStage.BELT_RECT.position.x + (ShiftStage.BELT_RECT.size.x - belt.cut()) / 2.0
	)
	banner.position = Vector2(middle - banner.size.x / 2.0, BANNER_Y).round()
	banner.pivot_offset = banner.size / 2.0
	var tween: Tween = banner.create_tween()
	if not screen.profile.reduced_motion():
		banner.scale = Vector2.ONE * BANNER_POP
		(
			tween
			. tween_property(banner, "scale", Vector2.ONE, BANNER_IN_SECONDS)
			. set_trans(Tween.TRANS_BACK)
			. set_ease(Tween.EASE_OUT)
		)
	tween.tween_interval(BANNER_HOLD_SECONDS)
	tween.tween_property(banner, "modulate:a", 0.0, BANNER_OUT_SECONDS)
	tween.tween_callback(banner.queue_free)
	return banner


## A Double checkout shift's count-up context: row 1 stops before the total (`more_rows`) and
## measures its size against every earlier shift; row 2 counts on from row 1's total.
static func dress(run: RunState, context: CountUpContext) -> void:
	if RunPins.row_slots(run) <= 0 or run.first_result == null:
		return
	if run.row_result == run.first_result and run.phase == RunState.Phase.PLANNING:
		context.more_rows = true
		for record: ShiftRecord in run.history:
			context.best_so_far = maxi(context.best_so_far, record.total)
		return
	context.start_total = run.first_result.total


## Row 1's CHECKOUT, after RunState.checkout scored and spent it (`committed`: its cards, in row
## order): logged as row_checkout and saved at the click, counted to its last item (no total),
## then planning comes back for row 2 with the refilled hand.
static func count_row_one(screen: ShiftScreen, committed: Array[CardInstance]) -> void:
	var run: RunState = screen.run
	var result: ScoreResult = run.first_result
	(
		screen
		. _log
		. log_event(
			"row_checkout",
			{
				"shift": run.shift_index + 1,
				"row": 1,
				"final_order": RunEvents.card_ids(committed),
				"score": result.total,
				"quota": run.quota(),
			}
		)
	)
	screen._save_run()
	# The belt shows row 1 as it was checked out while it counts: the run's row is already empty.
	screen._refresh()
	var views: Array[CardView] = screen._row_strip.show_cards(
		committed, -1, screen._on_row_card_clicked, run.balance
	)
	screen._row_views = views
	screen._effects.show_count(result, views, run)
	var context: CountUpContext = screen.count_up_context()
	screen._monitor.upgrades = run.upgrades.duplicate()
	screen._ride.begin(result, views, context.reduced_motion)
	await (screen._count_up.play(
		result,
		views,
		CardInstance.names(committed),
		run.quota(),
		context,
		screen._loyalty_card.stamped_boxes(),
		LoyaltyCard.names(run.upgrades),
		(screen._top_bar as TopBar).event_sources(
			WeekSchedule.shift_events(run), RunPins.pin_events(run).size()
		),
		InspectionTag.names(WeekSchedule.shift_events(run))
	))
	screen._counting = false
	screen._close_overlays()
	screen._cabinet.set_total_down(false)
	screen._stage.dim_hand(false)
	screen._sfx.play("shuffle")
	screen._refresh()
	show_banner(screen)
