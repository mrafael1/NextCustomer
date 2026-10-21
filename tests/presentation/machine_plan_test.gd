extends GdUnitTestSuite
## MachinePlan (#77, build spec 4.3-4.4): a visit's times equal the approved page's own
## timelines (tests/fixtures/machine_plan/page_timelines.json, written by running the page's
## buildTimeline() / bonusTimeline() and look F's plan(): see make_fixtures.js there), with the
## page's demo cursor taken out at the wait points: the plan's CHOOSE wait is the page's lights
## end (BONUS: the end of "PICK A CHUTE AGAIN", the page's hover), its PICK wait the page's curPick,
## and the page's cursor time from there to its press is left out. At 1x and under reduced
## motion; TICKET, BONUS with and without an inspection, STAMP DAY; NEW ITEMS, REGISTER and
## UPGRADES shelf landings; 1, 2 and 3 prizes; resume_at for each wait point. Pure data: no saves,
## no event log, no Node.

const TUNING := "res://data/balance/machine_tempo.tres"
const FIXTURE := "res://tests/fixtures/machine_plan/page_timelines.json"
const TOLERANCE := 0.000001
const TICKET := MachineVisit.Kind.TICKET
const BONUS := MachineVisit.Kind.BONUS
const STAMP_DAY := MachineVisit.Kind.STAMP_DAY

var _pages: Dictionary = {}


func before() -> void:
	_pages = JSON.parse_string(FileAccess.get_file_as_string(FIXTURE))


func test_the_tempo_loads_with_every_time_set() -> void:
	var tuning: MachineTuning = load(TUNING) as MachineTuning
	assert_object(tuning).is_not_null()
	assert_int(tuning.flight_ms).is_greater(0)
	assert_int(tuning.lands_ms.size()).is_equal(MachinePlan.MAX_PRIZES)
	for list: PackedInt32Array in [tuning.reveal_ms, tuning.reveal_rm_ms, tuning.end_hold_ms]:
		assert_int(list.size()).is_equal(3)


func test_a_ticket_visit_follows_the_page() -> void:
	for page_name: String in [
		"ticket_new", "ticket_new_rm", "ticket_register", "ticket_register_rm"
	]:
		_assert_visit(page_name, _ticket(page_name, MachinePlan.NO_VISIT), _page(page_name), false)


func test_an_upgrades_shelf_landing_follows_the_page() -> void:
	for page_name: String in ["ticket_shelf", "ticket_shelf_rm"]:
		var plan: MachinePlan = _ticket(page_name, MachinePlan.NO_VISIT)
		assert_int(plan.copies).is_equal(3)
		_assert_visit(page_name, plan, _page(page_name), false)


## Without its waits the first visit of COMMON, COMMON, RARE with a new item lasts 14.5 s: the
## page's 19.8 s less its 1.0 s start, its 3.6 s cursor to CONFIRM and 0.7 s to the pick.
func test_a_ticket_without_waits_is_the_pages_less_its_cursor() -> void:
	var page: Dictionary = _page("ticket_new")
	var plan: MachinePlan = _ticket("ticket_new", MachinePlan.NO_VISIT)
	var cursor: float = (
		float(page["fly"])
		+ float(page["press"])
		- float(page["lightsEnd"])
		+ float(page["pickPress"])
		- float(page["curPick"])
	)
	_near(plan.end_at, float(page["end"]) - cursor, "end")


## The first visit ends where the next one starts: the BONUS TICKET 0.3 s after the punch, STAMP
## DAY 0.5 s after it (the page's b0 and T.sd).
func test_the_first_visit_hands_over_to_the_next() -> void:
	var bonus_page: Dictionary = _page("bonus_new")
	var plan: MachinePlan = _ticket("bonus_new", BONUS)
	_near(plan.end_at, float(bonus_page["bonus"]["T"]["start"]) - _land_offset(bonus_page), "b0")
	var stamp_page: Dictionary = _page("stamp_day")
	plan = _ticket("stamp_day", STAMP_DAY)
	_near(plan.end_at, float(stamp_page["sd"]) - _land_offset(stamp_page), "sd")


func test_a_bonus_visit_follows_the_page() -> void:
	for page_name: String in [
		"bonus_new", "bonus_new_rm", "bonus_shelf", "bonus_shelf_rm", "bonus_register"
	]:
		var entry: Dictionary = _pages[page_name]["bonus"]
		var page: Dictionary = entry["T"].duplicate()
		page["plan"] = entry["plan"]
		var plan: MachinePlan = _plan(BONUS, page_name, entry, MachinePlan.NO_VISIT, true)
		_assert_bonus_intro(page_name, plan, page)
		_assert_visit(page_name, plan, page, true)


## A bonus extra shift (no inspection) plays the same times; only its texts differ.
func test_a_bonus_without_an_inspection_keeps_the_times() -> void:
	var entry: Dictionary = _pages["bonus_new"]["bonus"]
	var inspected: MachinePlan = _plan(BONUS, "bonus_new", entry, MachinePlan.NO_VISIT, true)
	var extra: MachinePlan = _plan(BONUS, "bonus_new", entry, MachinePlan.NO_VISIT, false)
	assert_bool(extra.inspected).is_false()
	for point: int in [
		MachinePlan.WaitPoint.CHOOSE, MachinePlan.WaitPoint.PICK, MachinePlan.WaitPoint.END
	]:
		_near(extra.wait_time(point), inspected.wait_time(point), "wait %d" % point)
	assert_array(extra.beat_names()).is_equal(inspected.beat_names())


func test_a_stamp_day_visit_follows_the_page() -> void:
	for page_name: String in ["stamp_day", "stamp_day_rm"]:
		var all: Dictionary = _pages[page_name]
		var page: Dictionary = all["T"]
		var plan: MachinePlan = _plan(
			STAMP_DAY,
			page_name,
			{"tiers": all["stamp_day"], "drawer": "", "copies": 1},
			MachinePlan.NO_VISIT,
			true
		)
		var start: float = float(page["sd"])
		assert_float(plan.wait_time(MachinePlan.WaitPoint.CHOOSE)).is_equal(0.0)
		var drops: Array = page["sdDrops"]
		var reveals: Array = page["sdRev"]
		for index: int in range(plan.n_prizes):
			var tag: String = "%s %d" % [page_name, index]
			_near(plan.drop_at[index], float(drops[index][0]) - start, tag + " drop")
			_near(plan.drop_length[index], float(drops[index][1]), tag + " drop length")
			_near(plan.reveal_at[index], float(reveals[index]["t0"]) - start, tag + " reveal")
			_near(plan.reveal_length[index], float(reveals[index]["d"]), tag + " reveal length")
			_near(
				plan.picks[index], float(all["plan"]["sd"]["picks"][index]) - start, tag + " pick"
			)
			if not all["rm"]:
				var run: Dictionary = all["plan"]["sd"]["runs"][index]
				_near(plan.run_from[index], float(run["e"]) - start, tag + " run")
				_near(plan.run_to[index], float(run["L"]) - start, tag + " gate")
		_near(plan.pick_at, float(page["sdPick"]) - start, page_name + " pick wait")
		var landed: float = start + float(page["sdPress"]) - float(page["sdPick"])
		_near(plan.fly_out, float(page["sdFly"]) - landed, page_name + " flight")
		_near(plan.land, float(page["sdLand"]) - landed, page_name + " land")
		for bay: int in range(MachinePlan.MAX_PRIZES):
			_near(plan.restock[bay], float(all["plan"]["sdRestock"][bay]) - landed, "restock")
		_near(plan.end_at, float(page["end"]) - landed, page_name + " end")
		assert_float(plan.beat_time(&"punch")).is_equal(MachinePlan.NOT_SET)
		assert_float(plan.beat_time(&"stamp_day")).is_equal(0.0)


## Two prizes use the left and centre cells, one the centre: their boxes meet their gates at
## LANDS in order, the reveals start after the last real box and keep the page's spacing.
func test_short_draws_follow_their_last_real_box() -> void:
	for page_name: String in ["ticket_two", "ticket_one"]:
		var page: Dictionary = _page(page_name)
		var plan: MachinePlan = _ticket(page_name, MachinePlan.NO_VISIT)
		var count: int = plan.n_prizes
		assert_int(count).is_equal((_pages[page_name]["tiers"] as Array).size())
		var last: int = count - 1
		var tuning: MachineTuning = plan.tuning
		for index: int in range(count):
			_near(
				plan.run_to[index],
				plan.draw_end + MachineTuning.seconds(tuning.lands_ms, index),
				"%s gate %d" % [page_name, index]
			)
		assert_int(MachinePlan.cell_of(0, count)).is_equal(1 if count == 1 else 0)
		_near(
			plan.reveal_at[0],
			plan.run_to[last] + MachineTuning.seconds(tuning.reveal_start_ms, TICKET),
			page_name + " first reveal"
		)
		var reveals: Array = page["rev"]
		for index: int in range(1, count):
			_near(
				plan.reveal_at[index] - plan.reveal_at[index - 1],
				float(reveals[index]["t0"]) - float(reveals[index - 1]["t0"]),
				page_name + " spacing"
			)
		_near(
			plan.pick_at - plan.reveal_at[last],
			float(page["curPick"]) - float(reveals[last]["t0"]),
			page_name + " pick wait"
		)
		if count == 2:
			var two_page: Array = page["drops"]
			for index: int in range(count):
				_near(plan.drop_at[index], float(two_page[index][0]) - _draw_offset(page), "drop")


## resume_at(point) keeps every time and starts the clock at the wait point, resumed.
func test_resume_at_starts_at_each_wait_point() -> void:
	var plan: MachinePlan = _ticket("ticket_new", MachinePlan.NO_VISIT)
	for point: int in [
		MachinePlan.WaitPoint.CHOOSE, MachinePlan.WaitPoint.PICK, MachinePlan.WaitPoint.END
	]:
		var resumed: MachinePlan = plan.resume_at(point)
		assert_bool(resumed.resumed).is_true()
		assert_bool(plan.resumed).is_false()
		_near(resumed.start, plan.wait_time(point), "start %d" % point)
		_near(resumed.end_at, plan.end_at, "end %d" % point)
		assert_array(resumed.beat_names()).is_equal(plan.beat_names())
	var choosing: MachinePlan = MachinePlan.new(_tuning(), TICKET, false)
	assert_float(choosing.wait_time(MachinePlan.WaitPoint.PICK)).is_equal(MachinePlan.NOT_SET)
	_near(choosing.resume_at(MachinePlan.WaitPoint.CHOOSE).start, choosing.choose_at, "choose")


## The beats come in time order; a planned time never moves when the plan grows; the punch
## beat is there only when the meter rises.
func test_beats_are_ordered_and_grow_with_the_visit() -> void:
	var plan: MachinePlan = MachinePlan.new(_tuning(), TICKET, false)
	assert_array(plan.beat_names()).is_equal([&"feed", &"read", &"lights"])
	var choose: float = plan.choose_at
	plan.set_draw([0, 0, 1] as Array[int])
	_near(plan.choose_at, choose, "choose kept")
	assert_array(plan.beats_between(choose, plan.pick_at)).is_equal(
		[&"draw", &"packed", &"reveal_0", &"reveal_1", &"reveal_2"]
	)
	plan.set_landing(MachinePlan.Landing.NEW_CARD, 1, false, MachinePlan.NO_VISIT)
	assert_array(plan.beats_between(plan.pick_at - 0.001, plan.end_at)).is_equal(
		[&"pick", &"land", &"restock"]
	)
	plan.set_landing(MachinePlan.Landing.NEW_CARD, 1, true, MachinePlan.NO_VISIT)
	assert_array(plan.beats_between(plan.pick_at - 0.001, plan.end_at)).is_equal(
		[&"pick", &"land", &"punch", &"restock"]
	)
	var times: Array[float] = []
	for beat_name: StringName in plan.beat_names():
		times.append(plan.beat_time(beat_name))
	var sorted: Array[float] = times.duplicate()
	sorted.sort()
	assert_array(times).is_equal(sorted)


## A binned draw has no flight and no landing beat: its punch follows the bin press.
func test_a_bin_punches_after_the_press() -> void:
	var plan: MachinePlan = MachinePlan.new(_tuning(), TICKET, false)
	plan.set_draw([0, 1, 2] as Array[int])
	plan.set_landing(MachinePlan.Landing.BIN, 1, true, MachinePlan.NO_VISIT)
	_near(plan.punch, plan.pick_at + MachineTuning.sec(plan.tuning.punch_bin_ms), "punch")
	assert_float(plan.beat_time(&"land")).is_equal(MachinePlan.NOT_SET)
	assert_float(plan.beat_time(&"punch")).is_greater(plan.pick_at)
	# Nothing lands in the cart drawer or glints on a bin.
	assert_float(plan.drawer_in).is_equal(MachinePlan.NOT_SET)
	assert_float(plan.drawer_out).is_equal(MachinePlan.NOT_SET)
	assert_float(plan.glint).is_equal(MachinePlan.NOT_SET)
	assert_float(plan.glint_end).is_equal(MachinePlan.NOT_SET)


## The belt's travel and the boxes' positions are look F's: still before its ramp, a box at
## ENTRY as it clears the curtain and at its cell when it meets its gate; none under reduced
## motion.
func test_belt_and_boxes_follow_look_f() -> void:
	var plan: MachinePlan = _ticket("ticket_new", MachinePlan.NO_VISIT)
	assert_float(plan.belt_travel(plan.belt_from - 0.5)).is_equal(0.0)
	assert_float(plan.belt_travel(plan.belt_to + 1.0)).is_greater(0.0)
	assert_bool(plan.belt_moving(plan.belt_from)).is_true()
	assert_bool(plan.belt_moving(plan.belt_to + 1.0)).is_false()
	_near(plan.box_x(0, plan.run_from[0]), MachinePlan.ENTRY, "entry")
	_near(plan.box_x(0, plan.run_to[0] - 0.000000001), MachinePlan.CELL_X[0], "cell")
	assert_float(plan.box_x(0, plan.run_to[0])).is_equal(MachinePlan.NOT_SET)
	var still: MachinePlan = _ticket("ticket_new_rm", MachinePlan.NO_VISIT)
	assert_float(still.belt_travel(still.end_at)).is_equal(0.0)
	assert_float(still.box_x(0, still.drop_at[0])).is_equal(MachinePlan.NOT_SET)


## The plan of a TICKET visit on page `page_name`, followed by `next_kind`.
func _ticket(page_name: String, next_kind: int) -> MachinePlan:
	return _plan(TICKET, page_name, _pages[page_name], next_kind, true)


func _plan(
	kind: int, page_name: String, entry: Dictionary, next_kind: int, inspected: bool
) -> MachinePlan:
	var plan: MachinePlan = MachinePlan.new(_tuning(), kind, _pages[page_name]["rm"], inspected)
	var tiers: Array[int] = []
	for tier: Variant in entry["tiers"]:
		tiers.append(int(tier))
	plan.set_draw(tiers)
	var landing: int = MachinePlan.Landing.REGISTER
	if entry["drawer"] == "new":
		landing = MachinePlan.Landing.NEW_CARD
	elif entry["drawer"] == "up":
		landing = MachinePlan.Landing.UPGRADE
	plan.set_landing(landing, int(entry["copies"]), true, next_kind)
	return plan


## The page's T for `page_name`'s first visit, with look F's plan() under "plan".
func _page(page_name: String) -> Dictionary:
	var page: Dictionary = (_pages[page_name]["T"] as Dictionary).duplicate()
	page["plan"] = _pages[page_name]["plan"]
	page["bonus"] = _pages[page_name].get("bonus", {})
	return page


## The page's time before our t = 0 and its demo cursor before the CHOOSE wait's release.
func _draw_offset(page: Dictionary) -> float:
	return float(page["fly"]) + float(page["press"]) - float(page["lightsEnd"])


func _land_offset(page: Dictionary) -> float:
	return _draw_offset(page) + float(page["pickPress"]) - float(page["curPick"])


## The BONUS intro: t = 0 is the page's b0; its CHOOSE wait is the page's hover.
func _assert_bonus_intro(tag: String, plan: MachinePlan, page: Dictionary) -> void:
	var start: float = float(page["start"])
	_near(plan.stub_end, float(page["tear"]) - start, tag + " stub")
	_near(plan.fly, float(page["fly"]) - start, tag + " fly")
	_near(plan.fly_end, float(page["flyEnd"]) - start, tag + " fly end")
	_near(plan.feed_end, float(page["feedEnd"]) - start, tag + " feed end")
	_near(plan.read_end, float(page["readEnd"]) - start, tag + " read end")
	_near(plan.lights_end, float(page["lightsEnd"]) - start, tag + " lights end")
	_near(plan.choose_at, float(page["hover"]) - start, tag + " choose")


## The draw and the landing of `plan` against `page` (a TICKET's T, or a BONUS's).
func _assert_visit(tag: String, plan: MachinePlan, page: Dictionary, bonus: bool) -> void:
	var intro: float = float(page["start"]) if bonus else float(page["fly"])
	var wait: float = float(page["hover"]) if bonus else float(page["lightsEnd"])
	if not bonus:
		_near(plan.fly_end, float(page["flyEnd"]) - intro, tag + " fly end")
		_near(plan.feed_end, float(page["feedEnd"]) - intro, tag + " feed end")
		_near(plan.read_end, float(page["readEnd"]) - intro, tag + " read end")
		_near(plan.choose_at, wait - intro, tag + " choose")
	var drawn: float = intro + float(page["press"]) - wait
	_near(plan.odds_close, float(page["oddsClose"]) - drawn, tag + " odds close")
	_near(plan.draw_end, float(page["drawEnd"]) - drawn, tag + " draw end")
	var looks: Dictionary = page["plan"]
	for index: int in range(plan.n_prizes):
		var at: String = "%s %d" % [tag, index]
		_near(plan.drop_at[index], float(page["drops"][index][0]) - drawn, at + " drop")
		_near(plan.drop_length[index], float(page["drops"][index][1]), at + " drop length")
		_near(plan.picks[index], float(looks["picks"][index]) - drawn, at + " bay pick")
		_near(plan.reveal_at[index], float(page["rev"][index]["t0"]) - drawn, at + " reveal")
		_near(plan.reveal_length[index], float(page["rev"][index]["d"]), at + " reveal length")
	_near(plan.packed, float(looks["packed"]) - drawn, tag + " packed")
	if (looks["belt"] as Array).is_empty():
		assert_float(plan.belt_from).is_equal(MachinePlan.NOT_SET)
	else:
		_near(plan.belt_from, float(looks["belt"][0]["a"]) - drawn, tag + " belt from")
		_near(plan.belt_to, float(looks["belt"][0]["b"]) - drawn, tag + " belt to")
	_near(plan.pick_at, float(page["curPick"]) - drawn, tag + " pick wait")
	var landed: float = drawn + float(page["pickPress"]) - float(page["curPick"])
	_near(plan.fly_out, float(page["fly2"]) - landed, tag + " flight")
	_near(plan.land, float(page["land"]) - landed, tag + " land")
	_near(plan.glint, float(page["xf"]) - landed, tag + " glint")
	_near(plan.glint_end, float(page["xfEnd"]) - landed, tag + " glint end")
	_near(plan.punch, float(page["punch"]) - landed, tag + " punch")
	_near(plan.punch_end, float(page["punchEnd"]) - landed, tag + " punch end")
	_near(plan.drawer_in, float(page["drawerIn"]) - landed, tag + " drawer in")
	_near(plan.drawer_out, float(page["drawerOut"]) - landed, tag + " drawer out")
	for bay: int in range(MachinePlan.MAX_PRIZES):
		_near(plan.restock[bay], float(looks["restock"][bay]) - landed, tag + " restock")
	if bonus or not page.has("bonus") or (page["bonus"] as Dictionary).is_empty():
		_near(plan.end_at, float(page["end"]) - landed, tag + " end")


func _near(actual: float, expected: float, tag: String) -> void:
	(
		assert_float(actual)
		. override_failure_message("%s: %f, page %f" % [tag, actual, expected])
		. is_equal_approx(expected, TOLERANCE)
	)


func _tuning() -> MachineTuning:
	return load(TUNING) as MachineTuning
