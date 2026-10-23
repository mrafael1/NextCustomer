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
##
## v0.50 (mock-up docs/art/mockups/premium_machine_v1.html): a BOOSTED visit (`premium`) turns the
## machine PREMIUM after its receipt is read (premium_at .. premium_end, the transform's juice
## moment, dressing A), and the keys light after it. Since v0.53 a BOOSTED BONUS visit is PREMIUM
## too: from its start when the ticket's visit was (`premium_held`: premium_at and premium_end both
## 0, no beat), else with the transform after its read. The draw is R1's "drop": the tray packs
## (draw .. draw_end), then each prize ticket flies out of the tray to the front (drop_at,
## drop_length) and lands face up at its reveal (reveal_at), where its rarity's effect plays for
## reveal_length; the LEGENDARY one lands a beat later.
##
## Machine v2 (Q1 = A, docs/art/mockups/machine_77_v2.html): the machine stands on the back wall
## and a TICKET visit's intro glides the camera to it (glide .. glide_end, camera_at) while the
## torn receipt travels to the slot (fly .. fly_end) and is fed (.. feed_end); with a BONUS
## pending (Q2 = 2, `stub`) the receipt's gold stub snaps off at `snap` and flies to the slot
## plate's dock. A BONUS visit's ticket goes from the dock to over the slot (fly .. fly_end) and is
## fed (.. feed_end). The return glide after the shift's last visit has its own static times
## (return_camera, return_fade, return_lit, return_length).

enum WaitPoint { CHOOSE, PICK, END }
## What the pick did: a card added (NEW ITEMS, COUPONS), copies upgraded, a register stamped, or
## the draw binned.
enum Landing { NEW_CARD, UPGRADE, REGISTER, BIN }

## set_landing's `next_visit` when no visit follows this shift.
const NO_VISIT := -1
## A time that is not planned (yet): a wait point before its segment is set, a premium transform
## on a visit that has none.
const NOT_SET := -1.0
const MAX_PRIZES := 3

var tuning: MachineTuning
## MachineVisit.Kind.
var kind: int = MachineVisit.Kind.TICKET
var reduced_motion: bool = false
## BONUS: an inspection was passed (false: a bonus extra shift). Texts only; same times.
var inspected: bool = true
## TICKET: a BONUS visit follows, so the receipt carries the gold stub that snaps off (Q2 = 2).
var stub: bool = false
## TICKET or BONUS (v0.53): a BOOSTED visit, so the machine turns PREMIUM after the receipt is
## read (v0.50).
var premium: bool = false
## BONUS (v0.53): the shift's ticket visit was PREMIUM too, so the machine is PREMIUM from the
## visit's start (no transform, no snap back to classic between the two visits).
var premium_held: bool = false
## Positioned at a wait point by resume_at(): the clock starts at `start` and nothing before it
## replays (every node shows the resume frame of build spec 4.3).
var resumed: bool = false
var start: float = 0.0

# INTRO. TICKET: the receipt travels (fly .. fly_end) while the camera glides (glide ..
# glide_end) and its stub snaps at `snap` (NOT_SET without one); BONUS: the ticket goes from the
# dock to the slot (fly .. fly_end). Both are then fed (.. feed_end).
var glide: float = 0.0
var glide_end: float = 0.0
var snap: float = NOT_SET
var fly: float = 0.0
var fly_end: float = 0.0
var feed_end: float = 0.0
var read_end: float = 0.0
## The premium transform (NOT_SET without one): from the read's end over premium_ms.
var premium_at: float = NOT_SET
var premium_end: float = NOT_SET
var lights: float = 0.0
var lights_end: float = 0.0
var choose_at: float = 0.0

# DRAW_TO_REVEALED (set_draw). Ticket i (prize i, reveal order) flies out of the tray from
# drop_at[i] for drop_length[i] (0 under reduced motion) and lands face up at reveal_at[i], where
# its rarity's effect plays for reveal_length[i].
var has_draw: bool = false
var rarities: Array[int] = []
var n_prizes: int = 0
var odds_close: float = 0.0
var draw: float = 0.0
var draw_end: float = 0.0
## The tray's packing ends (the draw's end).
var packed: float = 0.0
var drop_at: Array[float] = []
var drop_length: Array[float] = []
var reveal_at: Array[float] = []
var reveal_length: Array[float] = []
var pick_at: float = NOT_SET

# LANDING_TO_END (set_landing). press = pick_at; a bin has no flight (fly_out = land = press),
# no glint and no drawer (glint, glint_end, drawer_in, drawer_out stay NOT_SET).
var has_landing: bool = false
var landing: int = Landing.NEW_CARD
var copies: int = 1
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
var end_at: float = NOT_SET

var _beat_names: Array[StringName] = []
var _beat_times: Array[float] = []


func _init(
	machine_tuning: MachineTuning,
	visit_kind: int,
	rm: bool,
	has_inspection: bool = true,
	has_stub: bool = false,
	is_premium: bool = false,
	held: bool = false
) -> void:
	tuning = machine_tuning
	kind = visit_kind
	reduced_motion = rm
	inspected = has_inspection
	stub = has_stub and visit_kind == MachineVisit.Kind.TICKET
	premium = is_premium and visit_kind != MachineVisit.Kind.STAMP_DAY
	premium_held = premium and held and visit_kind == MachineVisit.Kind.BONUS
	_build()


## The visit's prizes are drawn: their rarities (MachinePrize.Rarity) in reveal order, 1 to 3.
func set_draw(prize_rarities: Array[int]) -> void:
	rarities = prize_rarities.duplicate()
	has_draw = true
	_build()


## The pick (or the bin) is made: what landed, how many copies an UPGRADES pick changed, and the
## next visit's MachineVisit.Kind (NO_VISIT: the shift's last visit).
func set_landing(landing_kind: int, upgraded_copies: int, next_kind: int) -> void:
	landing = landing_kind
	copies = maxi(1, upgraded_copies)
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
	var copy: MachinePlan = MachinePlan.new(
		tuning, kind, reduced_motion, inspected, stub, premium, premium_held
	)
	if has_draw:
		copy.set_draw(rarities)
	if has_landing:
		copy.set_landing(landing, copies, next_visit)
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


## How far the premium transform is at `t`, in seconds since it started: below 0 before it,
## premium_length() or more once done; NOT_SET on a visit that doesn't turn PREMIUM.
func premium_progress(t: float) -> float:
	if premium_at < 0.0:
		return NOT_SET
	return t - premium_at


## The premium transform's length (seconds; reduced motion: its cut), 0 without one.
func premium_length() -> float:
	return premium_end - premium_at if premium_at >= 0.0 else 0.0


## Ticket `index`'s flight out of the tray at `t` (0 leaving the tray .. 1 landed in its place),
## below 0 before it leaves, NOT_SET without one; under reduced motion it is 1 from its landing.
func ticket_flight(index: int, t: float) -> float:
	if index < 0 or index >= drop_at.size():
		return NOT_SET
	if drop_length[index] <= 0.0:
		return 1.0 if t >= reveal_at[index] else -1.0
	return (t - drop_at[index]) / drop_length[index]


## The camera's progress to the machine at `t` (0: the store at 1x, 1: the machine at 2x, not
## eased): a TICKET visit glides it in from glide to glide_end (reduced motion: a cut at glide +
## rm_cut_ms); every other visit is at the machine.
func camera_at(t: float) -> float:
	if kind != MachineVisit.Kind.TICKET:
		return 1.0
	if reduced_motion:
		return 1.0 if t >= cut_at() else 0.0
	return _seg(t, glide, glide_end)


## When the reduced-motion cut puts the camera at the machine (camera_at's switch).
func cut_at() -> float:
	return glide + MachineTuning.sec(tuning.rm_cut_ms)


## How lit the machine is at `t` (0: dimmed on the wall, 1: lit): a TICKET visit lights it over
## the glide's last lit_ramp_ms.
func lit_at(t: float) -> float:
	if kind != MachineVisit.Kind.TICKET:
		return 1.0
	return _seg(t, glide_end - MachineTuning.sec(tuning.lit_ramp_ms), glide_end)


## The reduced-motion cut's charcoal fade at `t` (0 but under reduced motion, during a TICKET
## visit's cut): up to rm_fade_alpha and down again over rm_fade_ms from the glide's start.
func fade_at(t: float) -> float:
	if kind != MachineVisit.Kind.TICKET or not reduced_motion:
		return 0.0
	return triangle(t - glide, MachineTuning.sec(tuning.rm_fade_ms)) * tuning.rm_fade_alpha


## The stub's height share at `t` (1 whole .. 0 snapped off): it shrinks from snap +
## snap_delay_ms over snap_ms (reduced motion: gone at the snap). 1 without a stub.
func stub_left(t: float) -> float:
	if snap < 0.0 or t < snap:
		return 1.0
	if reduced_motion:
		return 0.0
	var from: float = snap + MachineTuning.sec(tuning.snap_delay_ms)
	return 1.0 - _seg(t, from, from + MachineTuning.sec(tuning.snap_ms))


## The bonus ticket's flight from the stub to the dock at `t` (0 at the snap .. 1 docked;
## reduced motion: docked at the snap), or NOT_SET before the snap or without a stub.
func dock_flight(t: float) -> float:
	if snap < 0.0 or t < snap:
		return NOT_SET
	if reduced_motion:
		return 1.0
	return _seg(t, snap, snap + MachineTuning.sec(tuning.dock_flight_ms))


## The return glide's camera progress `t` seconds after it starts (1 at the machine .. 0 back in
## the store; reduced motion: the cut at rm_cut_ms).
static func return_camera(machine_tuning: MachineTuning, t: float, rm: bool) -> float:
	if rm:
		return 0.0 if t >= MachineTuning.sec(machine_tuning.rm_cut_ms) else 1.0
	return 1.0 - _seg(t, 0.0, MachineTuning.sec(machine_tuning.return_glide_ms))


## How lit the machine is `t` seconds into the return glide: it dims over dim_ms.
static func return_lit(machine_tuning: MachineTuning, t: float) -> float:
	return 1.0 - _seg(t, 0.0, MachineTuning.sec(machine_tuning.dim_ms))


## The return glide's charcoal fade `t` seconds into it (reduced motion only, as the cut in).
static func return_fade(machine_tuning: MachineTuning, t: float, rm: bool) -> float:
	if not rm:
		return 0.0
	var length: float = MachineTuning.sec(machine_tuning.rm_fade_ms)
	return triangle(t, length) * machine_tuning.rm_fade_alpha


## How long the return glide lasts: the glide and the dimming (reduced motion: the cut and its
## fade, and the dimming).
static func return_length(machine_tuning: MachineTuning, rm: bool) -> float:
	var dim: float = MachineTuning.sec(machine_tuning.dim_ms)
	if rm:
		var cut: float = MachineTuning.sec(machine_tuning.rm_cut_ms)
		return maxf(maxf(MachineTuning.sec(machine_tuning.rm_fade_ms), cut), dim)
	return maxf(MachineTuning.sec(machine_tuning.return_glide_ms), dim)


## A triangle over `length` seconds: 0 at 0, 1 halfway, 0 at `length` and after (0 before 0).
static func triangle(t: float, length: float) -> float:
	if length <= 0.0 or t <= 0.0 or t >= length:
		return 0.0
	return 1.0 - absf(t / length * 2.0 - 1.0)


static func _seg(t: float, from: float, to: float) -> float:
	if to <= from:
		return 1.0 if t >= from else 0.0
	return clampf((t - from) / (to - from), 0.0, 1.0)


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
	snap = NOT_SET
	premium_at = NOT_SET
	premium_end = NOT_SET
	glide = 0.0
	glide_end = 0.0
	match kind:
		MachineVisit.Kind.BONUS:
			fly = 0.0
			fly_end = fly + MachineTuning.sec(tuning.bonus_to_slot_ms)
			feed_end = fly_end + MachineTuning.sec(tuning.bonus_feed_ms)
			read_end = feed_end + MachineTuning.sec(tuning.bonus_read_ms)
			lights = read_end
			if premium_held:
				premium_at = 0.0
				premium_end = 0.0
			elif premium:
				lights = _plan_premium(read_end)
			lights_end = lights + MachineTuning.sec(tuning.bonus_lights_ms)
			choose_at = maxf(lights_end, feed_end + MachineTuning.sec(tuning.again_ms))
			_beat(&"bonus", 0.0)
		MachineVisit.Kind.STAMP_DAY:
			_beat(&"stamp_day", 0.0)
			return
		_:
			fly = 0.0
			fly_end = fly + MachineTuning.sec(tuning.travel_ms)
			feed_end = fly_end + MachineTuning.sec(tuning.feed_rm_ms if rm else tuning.feed_ms)
			read_end = feed_end + MachineTuning.sec(tuning.read_ms)
			lights = read_end
			if premium:
				lights = _plan_premium(read_end)
			lights_end = lights + MachineTuning.sec(tuning.lights_ms)
			choose_at = lights_end
			glide = MachineTuning.sec(tuning.glide_lead_ms)
			glide_end = glide + MachineTuning.sec(tuning.glide_ms)
			_beat(&"glide", glide)
			if stub:
				snap = maxf(fly, fly_end - MachineTuning.sec(tuning.snap_lead_ms))
				_beat(&"snap", snap)
	_beat(&"feed", fly)
	_beat(&"read", feed_end)
	_beat(&"lights", lights)


## The premium transform from `at` (premium_ms, reduced motion premium_rm_ms) and its beat;
## returns its end, where the keys light.
func _plan_premium(at: float) -> float:
	premium_at = at
	premium_end = (
		premium_at
		+ MachineTuning.sec(tuning.premium_rm_ms if reduced_motion else tuning.premium_ms)
	)
	_beat(&"premium", premium_at)
	return premium_end


func _build_draw() -> void:
	var rm: bool = reduced_motion
	n_prizes = mini(rarities.size(), MAX_PRIZES)
	odds_close = choose_at
	if kind != MachineVisit.Kind.STAMP_DAY:
		odds_close += MachineTuning.seconds(tuning.odds_close_ms, kind)
	draw = odds_close
	var packing: float = MachineTuning.sec(tuning.draw_rm_ms)
	if not rm:
		packing = MachineTuning.seconds(tuning.draw_ms, kind)
	draw_end = draw + packing
	packed = draw_end
	var flying: float = 0.0 if rm else MachineTuning.seconds(tuning.fly_ms, kind)
	drop_at = []
	drop_length = []
	reveal_at = []
	reveal_length = []
	var at: float = draw_end + MachineTuning.seconds(tuning.first_land_ms, kind)
	var settled: float = draw_end
	for index: int in range(n_prizes):
		var rarity: int = rarities[index]
		if index > 0:
			var lead: float = MachineTuning.sec(tuning.land_lead_rm_ms)
			if not rm:
				lead = MachineTuning.seconds(tuning.land_lead_ms, rarity)
			at += lead
		var length: float = MachineTuning.seconds(
			tuning.reveal_rm_ms if rm else tuning.reveal_ms, rarity
		)
		drop_at.append(at - flying)
		drop_length.append(flying)
		reveal_at.append(at)
		reveal_length.append(length)
		settled = maxf(settled, at + length)
		_beat(StringName("reveal_%d" % index), at)
	pick_at = settled + MachineTuning.seconds(tuning.pick_arm_ms, kind)
	_beat(&"draw", draw)
	_beat(&"packed", packed)


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
	if stamp_day:
		end_at = land + MachineTuning.seconds(tuning.end_hold_ms, kind)
	elif next_visit == MachineVisit.Kind.BONUS:
		end_at = punch_end + MachineTuning.sec(tuning.before_bonus_ms)
	elif next_visit == MachineVisit.Kind.STAMP_DAY:
		end_at = punch_end + MachineTuning.sec(tuning.before_stamp_day_ms)
	else:
		end_at = punch_end + MachineTuning.seconds(tuning.end_hold_ms, kind)
	_beat(&"pick", press)


## The settle after the landing (`punch`, where the Regular meter's punch played until v0.47; its
## times stay): after the landing (a new card, a register stamp) or the glint's end (UPGRADES);
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
