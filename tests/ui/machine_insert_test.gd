extends GdUnitTestSuite
## The RECEIPT REWARDS machine's insert and its week odds tag (v0.99, the user's play test: "prenium
## machine has ticket that stay mid inserted" and "weeks odd + 1 is just sitting weirdly"). After
## the feed nothing sticks out of the slot on a CLASSIC, a PREMIUM or a PREMIUM BONUS visit (the
## gold receipt pops up during the transform and is swallowed); the week's odds raise is a tag under
## each lit column's odds plates, inside the window, clear of every other line. The views are driven
## directly (no screen, no input events), on a 1280x720 stage.

const BALANCE := "res://data/balance/balance.tres"
const STARTER := "res://data/decks/starter.tres"
const SPOT_CHECK := "res://data/inspections/spot_check.tres"
## Milk, Multipack, then five Milks (109): passes shift 1.
const PASSING_ROW: Array[String] = ["milk", "multipack", "milk", "milk", "milk", "milk", "milk"]
const EPSILON := 0.001

var _folder: String = ""


func before_test() -> void:
	_folder = "user://test_machine_insert_%d" % Time.get_ticks_usec()
	_event_log().use_folder(_folder)
	ProjectSettings.set_setting(SaveService.FOLDER_SETTING, _folder)


func after_test() -> void:
	ProjectSettings.set_setting(SaveService.FOLDER_SETTING, null)
	if DirAccess.dir_exists_absolute(_folder):
		for file_name: String in DirAccess.get_files_at(_folder):
			DirAccess.remove_absolute(_folder.path_join(file_name))
		DirAccess.remove_absolute(_folder)


## Once fed, the receipt (CLASSIC and PREMIUM) and the bonus ticket (a PREMIUM BONUS visit) are gone
## and nothing stands in the slot (after the feed, after a PREMIUM transform, at the keys' wait),
## with and without reduced motion.
## On a PREMIUM ticket visit the gold receipt sticks out of the slot as the transform starts, is fed
## in during it (less of it out each time) and is gone by its end.
func test_nothing_stays_in_the_slot_after_the_insert() -> void:
	for kind: String in ["classic", "premium", "premium bonus"]:
		for rm: bool in [false, true]:
			var where: String = "%s, rm %s" % [kind, rm]
			var run: RunState = _run(kind)
			var view: RewardMachineView = await _open(run, rm)
			var plan: MachinePlan = view.plan
			var feed: ReceiptFeed = view.receipt_feed
			assert_bool(plan.premium).override_failure_message(where).is_equal(kind != "classic")
			if kind == "premium" and not rm:
				var seen: Array[float] = []
				var step: float = plan.premium_length() / 40.0
				var t: float = plan.premium_at + EPSILON
				while t < plan.premium_end:
					view.show_at(t)
					seen.append(MachineLook.at(plan, t).stub_left())
					t += step
				assert_float(seen[0]).override_failure_message(where).is_equal(1.0)
				assert_float(seen.max()).is_equal(1.0)
				for index: int in range(1, seen.size()):
					assert_float(seen[index]).is_less_equal(seen[index - 1])
				assert_float(seen[-1]).override_failure_message(where).is_equal(0.0)
			for t: float in [plan.feed_end, plan.premium_end, plan.choose_at]:
				if t < plan.feed_end:
					continue
				view.show_at(t + EPSILON)
				await _frames(1)
				var at: String = "%s at %.2f" % [where, t]
				(
					assert_bool(feed.paper_anchor(t + EPSILON).on)
					. override_failure_message(at)
					. is_false()
				)
				assert_bool(feed.clip.visible and feed.paper != null).is_false()
				assert_bool(feed.ticket != null and feed.ticket.visible).is_false()
				assert_bool(view.slot_plate.stub_shown()).override_failure_message(at).is_false()
			view.close()
			remove_child(view)
			view.queue_free()
			await _frames(2)


## The week's odds raise (Holiday rush's +1) is a gold tag "ODDS +1 · WEEK" under each lit column's
## odds plates: attached to them (a 2 art px gap, as wide as their row), inside its column and the
## window above the sill, clear of the plates' and the legend's lines and of the sealed tickets.
## Without a raise there is no tag.
func test_the_week_odds_tag_sits_under_its_odds_plates() -> void:
	for raise: int in [0, 1]:
		var run: RunState = _run("classic", raise)
		var view: RewardMachineView = await _open(run, false)
		view.fast_forward()
		await _frames(2)
		var stock: StockWindow = view.stock
		var window: Rect2 = stock.get_global_rect()
		var to_global: Transform2D = stock.get_global_transform()
		for column: int in range(StockWindow.COLUMNS):
			var line: MachineLine = stock.week_odds_label(column)
			if raise == 0:
				assert_bool(line.visible).is_false()
				continue
			assert_bool(stock.column_lit(column)).is_true()
			assert_bool(line.is_visible_in_tree()).is_true()
			assert_str(line.text()).is_equal(StockWindow.WEEK_ODDS_TEXT % raise)
			assert_str(line.text()).is_equal("ODDS +1 · WEEK")
			var tag: Rect2 = to_global * StockWindow.week_tag_rect(column)
			var text: Rect2 = line.get_global_rect()
			(
				assert_bool(tag.grow(-MachineArt.PIXEL).encloses(text))
				. override_failure_message("%s in %s" % [text, tag])
				. is_true()
			)
			assert_bool(window.encloses(tag)).is_true()
			var sill: Rect2 = to_global * StockWindow.sill_rect()
			assert_float(tag.end.y).is_less_equal(sill.position.y)
			var first: Rect2 = to_global * StockWindow.plate_rect(column, 0)
			var last: Rect2 = to_global * StockWindow.plate_rect(column, 2)
			assert_float(tag.position.x).is_equal_approx(first.position.x, 0.01)
			assert_float(tag.end.x).is_equal_approx(last.end.x, 0.01)
			var gap: float = (tag.position.y - first.end.y) / to_global.get_scale().y
			assert_float(gap).is_equal_approx(StockWindow.WEEK_TAG_GAP * MachineArt.PIXEL, 0.01)
			var half: float = (StockWindow.SIZE.x - StockWindow.DIVIDER) / StockWindow.COLUMNS
			var cell: Rect2 = Rect2(
				column * (half + StockWindow.DIVIDER), 0, half, StockWindow.SIZE.y
			)
			assert_bool((to_global * cell).encloses(tag)).is_true()
			for other: MachineLine in stock.lines():
				if other.is_visible_in_tree():
					assert_bool(tag.intersects(other.get_global_rect())).is_false()
			var ticket_foot: float = StockWindow.TICKET_TOP + StockWindow.TICKET_SIZE.y
			assert_float(StockWindow.week_tag_rect(column).position.y).is_greater(ticket_foot)
			for rarity: int in range(3):
				var plate: Rect2 = to_global * StockWindow.plate_rect(column, rarity)
				assert_bool(tag.intersects(plate)).is_false()
		view.close()
		remove_child(view)
		view.queue_free()
		await _frames(2)


## A run waiting at the machine after shift 1: "classic" (its ticket visit), "premium" (a PREMIUM
## ticket visit) or "premium bonus" (the PREMIUM BONUS visit after a passed Spot check, its ticket
## having taken an UPGRADE prize); `odds_raise` raises the odds by shift 1's week event.
static func _run(kind: String, odds_raise: int = 0) -> RunState:
	var balance: BalanceDefinition = load(BALANCE)
	var run: RunState = RunState.new(
		21, load(STARTER) as DeckDefinition, balance, RunStock.starting(balance)
	)
	if kind != "classic":
		MachineSteps.premium_run(run, [1] as Array[int])
	if odds_raise > 0:
		run.balance = balance.duplicate() as BalanceDefinition
		run.balance.weeks = balance.weeks.duplicate()
		run.balance.weeks[0] = balance.weeks[0].duplicate() as WeekEventDefinition
		run.balance.weeks[0].odds_level_delta = odds_raise
	run.start_shift()
	for id: String in PASSING_ROW:
		run.place(run.debug_add_to_hand(load("res://data/cards/%s.tres" % id)), run.row.size())
	run.checkout()
	if kind == "premium bonus":
		run.history[-1].inspection = load(SPOT_CHECK)
		MachineSteps.bonus_after_inspection(run)
		run.machine.begin_after_checkout(run)
		MachineSteps.choose(run, RewardMachine.Chute.UPGRADE)
		MachineSteps.take(run, 0)
	return run


## The machine on a stage, its visit opened at its start.
func _open(run: RunState, rm: bool) -> RewardMachineView:
	var stage: Control = auto_free(Control.new())
	stage.size = ShiftStage.SIZE
	add_child(stage)
	var view: RewardMachineView = RewardMachineView.new()
	view.reduced_motion = func() -> bool: return rm
	add_child(view)
	view.position = ShiftStage.MACHINE_RECT.position
	view.receipt_names = CardInstance.names(run.row)
	view.open_visit(run, stage, stage, false)
	await _frames(2)
	return view


func _frames(count: int) -> void:
	for i: int in range(count):
		await get_tree().process_frame


static func _event_log() -> EventLogService:
	return (Engine.get_main_loop() as SceneTree).root.get_node("/root/EventLog")
