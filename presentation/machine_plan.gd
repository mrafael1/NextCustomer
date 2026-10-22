class_name MachinePlan
extends RefCounted
## One RECEIPT REWARDS visit's timeline (#77, build spec 4.3-4.4), in seconds at 1x from the
## visit's start: a port of the approved page's buildTimeline() / bonusTimeline()
## (docs/art/mockups/machine_77_src/flow/flow_template.html) and look F's plan()
## (flow/looks/look_f.js), with the page's demo cursor replaced by wait points where the clock
## holds for the player:
## - CHOOSE: the chute keys are lit (a TICKET or BONUS visit; STAMP DAY has none, its CHOOSE is 0);
## - PICK: the prizes are revealed (the page's curPick);
## - END: the landing is over (the next visit, or the next shift, follows).
## The segments between them are INTRO (0 .. CHOOSE), DRAW_TO_REVEALED (CHOOSE .. PICK) and
## LANDING_TO_END (PICK .. END). The plan grows as the visit goes: the intro from the visit kind,
## the draw from set_draw() once the prizes are drawn, the landing from set_landing() once one is
## picked or the draw binned; times already planned never move.
##
## Pure: it reads only its MachineTuning (data/balance/machine_tempo.tres) and its inputs. Every
## machine node's frame(t) reads only the plan and t, a test seam like the page's `?at=`.
## TICKET t = 0 is the dessert's printer feed (page T.fly); BONUS t = 0 is the page's b0 (the
## first visit's punch end + 0.3); STAMP DAY t = 0 is the page's T.sd.

enum WaitPoint { CHOOSE, PICK, END }
## What the pick did: a card added (NEW ITEMS, COUPONS), copies upgraded, a register stamped, or
## the draw binned.
enum Landing { NEW_CARD, UPGRADE, REGISTER, BIN }

## set_landing's `next_visit` when no visit follows this shift.
const NO_VISIT := -1
## A time that is not planned (yet): a wait point before its segment is set, a box with no belt
## run (reduced motion).
const NOT_SET := -1.0
## Look F's geometry: a box's left edge while still behind the hatch's curtain, and the cells'
## left edges, in machine px; the RESTOCK door and the bays (bay of cell c at BAY_X + BAY_STEP x
## (2 - c), its box BAY_INSET in), in stockroom art px.
const ENTRY := 400.0
const CELL_X: Array[float] = [26.0, 156.0, 286.0]
const DOOR := 182.0
const BAY_X := 60.0
const BAY_STEP := 42.0
const BAY_INSET := 8.0
const MAX_PRIZES := 3

var tuning: MachineTuning
## MachineVisit.Kind.
var kind: int = MachineVisit.Kind.TICKET
var reduced_motion: bool = false
## BONUS: an inspection was passed (false: a bonus extra shift). Texts only; same times.
var inspected: bool = true
## Positioned at a wait point by resume_at(): the clock starts at `start` and nothing before it
## replays (every node shows the resume frame of build spec 4.3).
var resumed: bool = false
var start: float = 0.0

# INTRO. BONUS: the stub prints from 0 to stub_end, then flies.
var stub_end: float = 0.0
var fly: float = 0.0
var fly_end: float = 0.0
var feed_end: float = 0.0
var read_end: float = 0.0
var lights: float = 0.0
var lights_end: float = 0.0
var choose_at: float = 0.0

# DRAW_TO_REVEALED (set_draw). Per box i (prize i, reveal order, in cell cell_of(i, n_prizes)):
# its drop (start, length), its belt run (clears the curtain at run_from, meets its gate at
# run_to; run_from NOT_SET under reduced motion), its bay pick and its exit into the RESTOCK door
# (NOT_SET under reduced motion), its reveal (start, length).
var has_draw: bool = false
var rarities: Array[int] = []
var n_prizes: int = 0
var odds_close: float = 0.0
var draw: float = 0.0
var draw_end: float = 0.0
var drop_at: Array[float] = []
var drop_length: Array[float] = []
var run_from: Array[float] = []
var run_to: Array[float] = []
var picks: Array[float] = []
var exits: Array[float] = []
## The trapdoor fall (s), the runway speed (stockroom art px/s), the belt speed (machine px/s).
var fall: float = 0.0
var runway_speed: float = 0.0
var belt_speed: float = 0.0
## The belt runs from belt_from to belt_to (plus its ramps); NOT_SET under reduced motion.
var belt_from: float = NOT_SET
var belt_to: float = NOT_SET
var packed: float = 0.0
var reveal_at: Array[float] = []
var reveal_length: Array[float] = []
var pick_at: float = NOT_SET

# LANDING_TO_END (set_landing). press = pick_at; a bin has no flight (fly_out = land = press),
# no glint and no drawer (glint, glint_end, drawer_in, drawer_out stay NOT_SET).
var has_landing: bool = false
var landing: int = Landing.NEW_CARD
var copies: int = 1
var rises: bool = false
var next_visit: int = NO_VISIT
var press: float = NOT_SET
var fly_out: float = NOT_SET
var land: float = NOT_SET
var glint: float = NOT_SET
var glint_end: float = NOT_SET
var punch: float = NOT_SET
var punch_end: float = NOT_SET
var drawer_in: float = NOT_SET
var drawer_out: float = NOT_SET
## Bay c refills at restock[c].
var restock: Array[float] = []
var end_at: float = NOT_SET

var _beat_names: Array[StringName] = []
var _beat_times: Array[float] = []


func _init(
	machine_tuning: MachineTuning, visit_kind: int, rm: bool, has_inspection: bool = true
) -> void:
	tuning = machine_tuning
	kind = visit_kind
	reduced_motion = rm
	inspected = has_inspection
	_build()


## The visit's prizes are drawn: their rarities (MachinePrize.Rarity) in reveal order, 1 to 3.
func set_draw(prize_rarities: Array[int]) -> void:
	rarities = prize_rarities.duplicate()
	has_draw = true
	_build()


## The pick (or the bin) is made: what landed, how many copies an UPGRADES pick changed, whether
## the chute's Regular meter rose (the punch plays only then; the times stay the same), and the
## next visit's MachineVisit.Kind (NO_VISIT: the shift's last visit).
func set_landing(
	landing_kind: int, upgraded_copies: int, meter_rises: bool, next_kind: int
) -> void:
	landing = landing_kind
	copies = maxi(1, upgraded_copies)
	rises = meter_rises
	next_visit = next_kind
	has_landing = true
	_build()


## The time the clock holds at `point` (WaitPoint), NOT_SET while its segment isn't planned.
func wait_time(point: int) -> float:
	match point:
		WaitPoint.CHOOSE:
			return choose_at
		WaitPoint.PICK:
			return pick_at if has_draw else NOT_SET
	return end_at if has_landing and has_draw else NOT_SET


## A copy positioned at `point` for a resume: resumed, starting at that wait point.
func resume_at(point: int) -> MachinePlan:
	var copy: MachinePlan = MachinePlan.new(tuning, kind, reduced_motion, inspected)
	if has_draw:
		copy.set_draw(rarities)
	if has_landing:
		copy.set_landing(landing, copies, rises, next_visit)
	copy.resumed = true
	copy.start = maxf(0.0, copy.wait_time(point))
	return copy


## The beats after `from` up to and including `to`, in time order.
func beats_between(from: float, to: float) -> Array[StringName]:
	var found: Array[StringName] = []
	for index: int in range(_beat_names.size()):
		if _beat_times[index] > from and _beat_times[index] <= to:
			found.append(_beat_names[index])
	return found


## The time of the beat `beat_name`, NOT_SET when this visit has none.
func beat_time(beat_name: StringName) -> float:
	var index: int = _beat_names.find(beat_name)
	return _beat_times[index] if index >= 0 else NOT_SET


## Every beat's name, in time order.
func beat_names() -> Array[StringName]:
	return _beat_names.duplicate()


## The cell (0 left .. 2 right) prize `index` of `count` sits in: one prize takes the centre
## cell, two the left and centre cells.
static func cell_of(index: int, count: int) -> int:
	return index + 1 if count == 1 else index


## How far the belt has run at `t`, in machine px (a trapezoid speed profile: it ramps up before
## the first box clears the curtain and down after the last meets its gate). 0 under reduced
## motion.
func belt_travel(t: float) -> float:
	if belt_from < 0.0:
		return 0.0
	var ramp_up: float = MachineTuning.sec(tuning.belt_ramp_up_ms)
	var ramp_down: float = MachineTuning.sec(tuning.belt_ramp_down_ms)
	var from: float = belt_from - ramp_up
	if t <= from:
		return 0.0
	var travel: float = 0.0
	var upto: float = minf(t, belt_from)
	if ramp_up > 0.0:
		travel += belt_speed * (upto - from) * (upto - from) / (2.0 * ramp_up)
	if t > belt_from:
		travel += belt_speed * (minf(t, belt_to) - belt_from)
	if t > belt_to:
		var q: float = minf(t, belt_to + ramp_down) - belt_to
		travel += belt_speed * (q - (q * q / (2.0 * ramp_down) if ramp_down > 0.0 else 0.0))
	return travel


## Whether the belt is moving at `t` (its ramps included).
func belt_moving(t: float) -> bool:
	if belt_from < 0.0:
		return false
	var ramp_up: float = MachineTuning.sec(tuning.belt_ramp_up_ms)
	var ramp_down: float = MachineTuning.sec(tuning.belt_ramp_down_ms)
	return t >= belt_from - ramp_up and t < belt_to + ramp_down


## Box `index`'s left edge on the belt at `t` (machine px), riding from ENTRY to its cell, or
## NOT_SET when it is not riding (not out yet, at its gate, or reduced motion).
func box_x(index: int, t: float) -> float:
	if index < 0 or index >= run_from.size() or run_from[index] < 0.0:
		return NOT_SET
	var early: float = MachineTuning.sec(tuning.box_show_early_ms)
	if t < run_from[index] - early or t >= run_to[index]:
		return NOT_SET
	var cell: float = CELL_X[cell_of(index, n_prizes)]
	return maxf(cell, ENTRY - maxf(0.0, t - run_from[index]) * belt_speed)


## Reveal `index`'s progress at `t`: below 0 before it starts, 1 at its end; NOT_SET without one.
func reveal_progress(index: int, t: float) -> float:
	if index < 0 or index >= reveal_at.size():
		return NOT_SET
	return (t - reveal_at[index]) / reveal_length[index] if reveal_length[index] > 0.0 else 1.0


func _build() -> void:
	_beat_names = []
	_beat_times = []
	_build_intro()
	if has_draw:
		_build_draw()
		if has_landing:
			_build_landing()
	_sort_beats()


func _build_intro() -> void:
	var rm: bool = reduced_motion
	match kind:
		MachineVisit.Kind.BONUS:
			stub_end = MachineTuning.sec(tuning.stub_rm_ms if rm else tuning.stub_ms)
			fly = stub_end + (0.0 if rm else MachineTuning.sec(tuning.stub_lead_ms))
			fly_end = fly + (0.0 if rm else MachineTuning.sec(tuning.stub_flight_ms))
			feed_end = (
				fly_end + MachineTuning.sec(tuning.stub_feed_rm_ms if rm else tuning.stub_feed_ms)
			)
			read_end = feed_end + MachineTuning.sec(tuning.bonus_read_ms)
			lights = read_end
			lights_end = lights + MachineTuning.sec(tuning.bonus_lights_ms)
			choose_at = maxf(lights_end, feed_end + MachineTuning.sec(tuning.again_ms))
			_beat(&"bonus", 0.0)
		MachineVisit.Kind.STAMP_DAY:
			_beat(&"stamp_day", 0.0)
			return
		_:
			fly = 0.0
			fly_end = fly + MachineTuning.sec(tuning.flight_rm_ms if rm else tuning.flight_ms)
			feed_end = fly_end + MachineTuning.sec(tuning.feed_rm_ms if rm else tuning.feed_ms)
			read_end = feed_end + MachineTuning.sec(tuning.read_ms)
			lights = read_end
			lights_end = lights + MachineTuning.sec(tuning.lights_ms)
			choose_at = lights_end
	_beat(&"feed", fly)
	_beat(&"read", feed_end)
	_beat(&"lights", lights)


func _build_draw() -> void:
	var rm: bool = reduced_motion
	var stamp_day: bool = kind == MachineVisit.Kind.STAMP_DAY
	n_prizes = mini(rarities.size(), MAX_PRIZES)
	belt_speed = float(tuning.belt_px_per_s[kind]) if kind < tuning.belt_px_per_s.size() else 0.0
	runway_speed = (
		float(tuning.runway_px_per_s[kind]) if kind < tuning.runway_px_per_s.size() else 0.0
	)
	fall = 0.0 if rm else MachineTuning.seconds(tuning.fall_ms, kind)
	if stamp_day:
		odds_close = choose_at
		draw = choose_at
		draw_end = choose_at
	else:
		odds_close = choose_at + MachineTuning.seconds(tuning.odds_close_ms, kind)
		draw = odds_close
		var length: float = MachineTuning.sec(tuning.draw_rm_ms)
		if not rm:
			length = MachineTuning.seconds(tuning.draw_ms, kind)
		draw_end = draw + length
	_build_drops(stamp_day)
	_build_picks(stamp_day)
	var last_drop: float = draw_end
	for index: int in range(n_prizes):
		last_drop = maxf(last_drop, drop_at[index] + drop_length[index])
	var at: float = last_drop + MachineTuning.seconds(tuning.reveal_start_ms, kind)
	reveal_at = []
	reveal_length = []
	for index: int in range(n_prizes):
		var length: float = _reveal_length(rarities[index])
		reveal_at.append(at)
		reveal_length.append(length)
		_beat(StringName("reveal_%d" % index), at)
		at += length + MachineTuning.seconds(tuning.reveal_gap_ms, kind)
	pick_at = at + MachineTuning.seconds(tuning.pick_arm_ms, kind)
	_beat(&"draw", draw)
	_beat(&"packed", packed)


## The boxes' drops and belt runs: TICKET and BONUS boxes meet their gates at LANDS after the
## draw's end (reduced motion: they appear at their gates, drop_gap_rm_ms apart); STAMP DAY's drop
## from stamp_drop_ms, their belt runs ending with their drops.
func _build_drops(stamp_day: bool) -> void:
	var rm: bool = reduced_motion
	drop_at = []
	drop_length = []
	run_from = []
	run_to = []
	for index: int in range(n_prizes):
		var at: float
		var length: float
		var meets: float
		var clears: float = NOT_SET
		var travel: float = ENTRY - CELL_X[cell_of(index, n_prizes)]
		if stamp_day:
			var gap: int = tuning.stamp_drop_gap_rm_ms if rm else tuning.stamp_drop_gap_ms
			at = MachineTuning.sec(tuning.stamp_drop_ms + gap * index)
			length = MachineTuning.sec(
				tuning.stamp_drop_length_rm_ms if rm else tuning.stamp_drop_length_ms
			)
			meets = at + length
			if not rm and belt_speed > 0.0:
				clears = meets - travel / belt_speed
		elif rm:
			at = draw_end + MachineTuning.sec(tuning.drop_gap_rm_ms * index)
			length = MachineTuning.sec(tuning.drop_rm_ms)
			meets = at + length
		else:
			meets = draw_end + MachineTuning.seconds(tuning.lands_ms, index)
			clears = meets - (travel / belt_speed if belt_speed > 0.0 else 0.0)
			at = clears
			length = meets - clears
		drop_at.append(at)
		drop_length.append(length)
		run_from.append(clears)
		run_to.append(meets)
	belt_from = NOT_SET
	belt_to = NOT_SET
	if n_prizes > 0 and run_from[0] >= 0.0:
		belt_from = run_from[0]
		belt_to = run_to[n_prizes - 1]


## The bay picks, worked back from each box's belt run so a box never waits off screen (look F's
## trip()), and the PACKED stamp.
func _build_picks(stamp_day: bool) -> void:
	var rm: bool = reduced_motion
	var first: float = draw
	if stamp_day or not rm:
		first += MachineTuning.seconds(tuning.pick_lead_ms, kind)
	var hidden: float = MachineTuning.seconds(tuning.hidden_ms, kind)
	picks = []
	exits = []
	for index: int in range(n_prizes):
		if run_from[index] < 0.0:
			picks.append(first)
			exits.append(NOT_SET)
			continue
		var cell: int = cell_of(index, n_prizes)
		var ride: float = DOOR - (BAY_X + BAY_STEP * (2 - cell) + BAY_INSET)
		var exit: float = run_from[index] - hidden
		exits.append(exit)
		var runway: float = ride / runway_speed if runway_speed > 0.0 else 0.0
		picks.append(maxf(first, exit - runway - fall))
	var last_pick: float = picks[n_prizes - 1] if n_prizes > 0 else first
	if stamp_day:
		packed = last_pick + MachineTuning.sec(tuning.packed_stamp_day_ms)
	elif rm:
		packed = draw + MachineTuning.sec(tuning.packed_rm_ms)
	else:
		packed = last_pick + MachineTuning.sec(tuning.packed_ms)


func _reveal_length(rarity: int) -> float:
	var rm: bool = reduced_motion
	if kind == MachineVisit.Kind.STAMP_DAY:
		var lengths: PackedInt32Array = (
			tuning.reveal_stamp_day_rm_ms if rm else tuning.reveal_stamp_day_ms
		)
		return MachineTuning.seconds(lengths, rarity)
	return MachineTuning.seconds(tuning.reveal_rm_ms if rm else tuning.reveal_ms, rarity)


func _build_landing() -> void:
	var rm: bool = reduced_motion
	press = pick_at
	if landing == Landing.BIN:
		fly_out = press
		land = press
		glint = NOT_SET
		glint_end = NOT_SET
		punch = press + MachineTuning.sec(tuning.punch_bin_ms)
	else:
		fly_out = press + MachineTuning.seconds(tuning.pick_lead_flight_ms, kind)
		var flight: float = MachineTuning.sec(tuning.pick_flight_rm_ms)
		if not rm:
			flight = MachineTuning.seconds(tuning.pick_flight_ms, kind)
		land = fly_out + flight
		glint = (
			land
			+ (
				MachineTuning.sec(tuning.glint_rm_ms)
				if rm
				else MachineTuning.seconds(tuning.glint_ms, kind)
			)
		)
		glint_end = glint
		if not rm:
			glint_end += MachineTuning.sec(
				tuning.glint_copy_ms * (copies - 1) + tuning.glint_tail_ms
			)
		punch = _punch_time()
		_beat(&"land", land)
	var stamp_day: bool = kind == MachineVisit.Kind.STAMP_DAY
	punch_end = punch if stamp_day else punch + MachineTuning.sec(tuning.punch_length_ms)
	drawer_in = NOT_SET
	drawer_out = NOT_SET
	if landing != Landing.BIN:
		drawer_in = fly_out - MachineTuning.sec(tuning.drawer_lead_ms)
		drawer_out = punch + MachineTuning.sec(tuning.drawer_tail_ms)
	var refill: float = punch + MachineTuning.sec(tuning.restock_ms)
	if stamp_day:
		refill = land + MachineTuning.sec(tuning.restock_stamp_day_ms)
	restock = []
	for bay: int in range(MAX_PRIZES):
		restock.append(refill + (0.0 if rm else MachineTuning.sec(tuning.restock_gap_ms * bay)))
	if stamp_day:
		end_at = land + MachineTuning.seconds(tuning.end_hold_ms, kind)
	elif next_visit == MachineVisit.Kind.BONUS:
		end_at = punch_end + MachineTuning.sec(tuning.before_bonus_ms)
	elif next_visit == MachineVisit.Kind.STAMP_DAY:
		end_at = punch_end + MachineTuning.sec(tuning.before_stamp_day_ms)
	else:
		end_at = punch_end + MachineTuning.seconds(tuning.end_hold_ms, kind)
	_beat(&"pick", press)
	if rises and not stamp_day:
		_beat(&"punch", punch)
	_beat(&"restock", restock[0])


## The punch: after the landing (a new card, a register stamp) or the glint's end (UPGRADES);
## STAMP DAY has none (its time is the landing's).
func _punch_time() -> float:
	if kind == MachineVisit.Kind.STAMP_DAY:
		return land
	var after: float = glint_end if landing == Landing.UPGRADE else land
	if reduced_motion:
		return after + MachineTuning.seconds(tuning.punch_rm_ms, kind)
	match landing:
		Landing.UPGRADE:
			return after + MachineTuning.seconds(tuning.punch_upgrade_ms, kind)
		Landing.REGISTER:
			return after + MachineTuning.seconds(tuning.punch_register_ms, kind)
	return after + MachineTuning.seconds(tuning.punch_new_ms, kind)


func _beat(beat_name: StringName, at: float) -> void:
	_beat_names.append(beat_name)
	_beat_times.append(at)


## Orders the beats by time (a stable insertion sort: equal times keep their planned order).
func _sort_beats() -> void:
	for index: int in range(1, _beat_names.size()):
		var at: float = _beat_times[index]
		var beat_name: StringName = _beat_names[index]
		var to: int = index
		while to > 0 and _beat_times[to - 1] > at:
			_beat_times[to] = _beat_times[to - 1]
			_beat_names[to] = _beat_names[to - 1]
			to -= 1
		_beat_times[to] = at
		_beat_names[to] = beat_name
