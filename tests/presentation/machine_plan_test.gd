extends GdUnitTestSuite
## MachinePlan (#77, build spec 4.3-4.4; v0.50 mock-up premium_machine_v1.html): every time of a
## visit follows MachineTuning (data/balance/machine_tempo.tres). The intros (machine v2: the
## receipt's travel with the camera's glide, the stub's snap, the bonus ticket's feed; v0.50: the
## premium transform after the read), R1's draw (the tray packs, then each ticket flies out of it
## and lands face up, the LEGENDARY one a beat later), the landing and the holds, at 1x and under
## reduced motion; TICKET, BONUS with and without an inspection (STAMP DAY is gone since #108);
## resume_at for each wait point. Pure data: no saves, no event log, no Node.

const TUNING := "res://data/balance/machine_tempo.tres"
const TOLERANCE := 0.000001
const TICKET := MachineVisit.Kind.TICKET
const BONUS := MachineVisit.Kind.BONUS
const COMMON := MachinePrize.Rarity.COMMON
const RARE := MachinePrize.Rarity.RARE
const LEGENDARY := MachinePrize.Rarity.LEGENDARY


func test_the_tempo_loads_with_every_time_set() -> void:
	var tuning: MachineTuning = _tuning()
	assert_object(tuning).is_not_null()
	for ms: int in [
		tuning.travel_ms,
		tuning.glide_ms,
		tuning.feed_ms,
		tuning.snap_ms,
		tuning.dock_flight_ms,
		tuning.return_glide_ms,
		tuning.bonus_to_slot_ms,
		tuning.bonus_feed_ms,
		tuning.rm_cut_ms,
		tuning.rm_fade_ms,
		tuning.premium_ms,
		tuning.premium_rm_ms,
		tuning.draw_rm_ms,
		tuning.land_lead_rm_ms,
	]:
		assert_int(ms).is_greater(0)
	assert_float(tuning.feed_fit).is_greater(0.0)
	assert_float(tuning.rm_fade_alpha).is_equal_approx(0.85, 0.0001)
	# Per visit kind (TICKET, BONUS; STAMP DAY is gone since #108) and per rarity.
	for list: PackedInt32Array in [
		tuning.draw_ms, tuning.fly_ms, tuning.first_land_ms, tuning.pick_arm_ms, tuning.end_hold_ms
	]:
		assert_int(list.size()).is_equal(MachineVisit.KIND_NAMES.size())
	for list: PackedInt32Array in [tuning.land_lead_ms, tuning.reveal_ms, tuning.reveal_rm_ms]:
		assert_int(list.size()).is_equal(3)
	# R1: the bigger the rarity, the longer its effect plays and the later it lands.
	assert_int(tuning.reveal_ms[LEGENDARY]).is_greater(tuning.reveal_ms[RARE])
	assert_int(tuning.reveal_ms[RARE]).is_greater(tuning.reveal_ms[COMMON])
	assert_int(tuning.land_lead_ms[LEGENDARY]).is_greater(tuning.land_lead_ms[RARE])


## The TICKET intro (machine v2): the receipt travels over travel_ms and is fed over feed_ms
## (feed_rm_ms under reduced motion); the camera glides from glide_lead_ms over glide_ms (a cut
## behind the fade under reduced motion) and the machine lights over its last lit_ramp_ms; with a
## bonus ticket to come the stub snaps snap_lead_ms before the feed, then flies to the dock.
func test_a_ticket_intro_follows_the_tuning() -> void:
	var tuning: MachineTuning = _tuning()
	for rm: bool in [false, true]:
		for stub: bool in [false, true]:
			var tag: String = "rm %s stub %s" % [rm, stub]
			var plan: MachinePlan = MachinePlan.new(tuning, TICKET, rm, true, stub)
			var travel: float = MachineTuning.sec(tuning.travel_ms)
			var feed: float = MachineTuning.sec(tuning.feed_rm_ms if rm else tuning.feed_ms)
			_near(plan.fly, 0.0, tag + " fly")
			_near(plan.fly_end, travel, tag + " fly end")
			_near(plan.feed_end, travel + feed, tag + " feed end")
			_near(plan.read_end, plan.feed_end + MachineTuning.sec(tuning.read_ms), tag + " read")
			_near(plan.glide, MachineTuning.sec(tuning.glide_lead_ms), tag + " glide")
			_near(plan.glide_end, plan.glide + MachineTuning.sec(tuning.glide_ms), tag + " glided")
			assert_float(plan.beat_time(&"glide")).is_equal(plan.glide)
			assert_float(plan.camera_at(0.0)).is_equal(0.0)
			assert_float(plan.camera_at(plan.choose_at)).is_equal(1.0)
			assert_float(plan.lit_at(0.0)).is_equal(0.0)
			assert_float(plan.lit_at(plan.glide_end)).is_equal(1.0)
			if stub:
				_near(plan.snap, travel - MachineTuning.sec(tuning.snap_lead_ms), tag + " snap")
				assert_float(plan.beat_time(&"snap")).is_equal(plan.snap)
				assert_float(plan.stub_left(plan.snap - 0.01)).is_equal(1.0)
				assert_float(plan.dock_flight(plan.snap - 0.01)).is_equal(MachinePlan.NOT_SET)
				var docked: float = plan.snap + MachineTuning.sec(tuning.dock_flight_ms)
				assert_float(plan.dock_flight(docked)).is_equal(1.0)
				assert_float(plan.stub_left(docked)).is_equal(0.0)
			else:
				assert_float(plan.snap).is_equal(MachinePlan.NOT_SET)
				assert_float(plan.beat_time(&"snap")).is_equal(MachinePlan.NOT_SET)
			if rm:
				var cut: float = plan.glide + MachineTuning.sec(tuning.rm_cut_ms)
				assert_float(plan.camera_at(cut - 0.001)).is_equal(0.0)
				assert_float(plan.camera_at(cut)).is_equal(1.0)
				var peak: float = plan.glide + MachineTuning.sec(tuning.rm_fade_ms) / 2.0
				_near(plan.fade_at(peak), tuning.rm_fade_alpha, tag + " fade peak")
			else:
				assert_float(plan.fade_at(plan.glide + 0.3)).is_equal(0.0)
				var mid: float = (plan.glide + plan.glide_end) / 2.0
				_near(plan.camera_at(mid), 0.5, tag + " mid glide")


## A PREMIUM visit (v0.50) turns the machine PREMIUM right after its receipt is read, over
## premium_ms (reduced motion: premium_rm_ms, a cut), and the keys light after it. A PREMIUM BONUS
## visit (v0.53) after a PREMIUM ticket visit is PREMIUM from its start (premium_held: the
## transform at 0 for 0 s, no beat, its times unchanged), else it turns after its own read.
func test_a_premium_visit_turns_after_the_read() -> void:
	var tuning: MachineTuning = _tuning()
	for rm: bool in [false, true]:
		var tag: String = "rm %s" % rm
		var plain: MachinePlan = MachinePlan.new(tuning, TICKET, rm)
		var plan: MachinePlan = MachinePlan.new(tuning, TICKET, rm, true, false, true)
		var length: float = MachineTuning.sec(tuning.premium_rm_ms if rm else tuning.premium_ms)
		assert_bool(plan.premium).is_true()
		_near(plan.premium_at, plan.read_end, tag + " premium at")
		_near(plan.premium_end, plan.read_end + length, tag + " premium end")
		_near(plan.premium_length(), length, tag + " length")
		_near(plan.lights, plan.premium_end, tag + " lights")
		_near(plan.choose_at, plain.choose_at + length, tag + " choose")
		assert_float(plan.beat_time(&"premium")).is_equal(plan.premium_at)
		_near(plan.premium_progress(plan.premium_at + 0.25), 0.25, tag + " progress")
		assert_float(plain.premium_at).is_equal(MachinePlan.NOT_SET)
		assert_float(plain.premium_progress(10.0)).is_equal(MachinePlan.NOT_SET)
		assert_float(plain.premium_length()).is_equal(0.0)
		assert_float(plain.beat_time(&"premium")).is_equal(MachinePlan.NOT_SET)
	for rm: bool in [false, true]:
		var bonus: MachinePlan = MachinePlan.new(tuning, BONUS, rm)
		var held: MachinePlan = MachinePlan.new(tuning, BONUS, rm, true, false, true, true)
		assert_bool(held.premium).is_true()
		assert_bool(held.premium_held).is_true()
		assert_float(held.premium_at).is_equal(0.0)
		assert_float(held.premium_length()).is_equal(0.0)
		assert_float(held.beat_time(&"premium")).is_equal(MachinePlan.NOT_SET)
		_near(held.choose_at, bonus.choose_at, "held choose")
		var look: MachineLook = MachineLook.at(held, 0.0)
		assert_bool(look.night_face()).is_true()
		# The keys stand back up, gold (v0.61, #108: PREMIUM is the rarity boost).
		assert_float(look.keys_up()).is_equal(1.0)
		assert_bool(look.keys_gold()).is_true()
		assert_bool(MachineLook.at(bonus, 0.0).keys_gold()).is_false()
		assert_bool(held.resume_at(MachinePlan.WaitPoint.CHOOSE).premium_held).is_true()
		var turning: MachinePlan = MachinePlan.new(tuning, BONUS, rm, true, false, true, false)
		assert_bool(turning.premium_held).is_false()
		_near(turning.premium_at, turning.read_end, "bonus premium at")
		assert_float(turning.beat_time(&"premium")).is_equal(turning.premium_at)
		assert_bool(MachineLook.at(turning, 0.0).premium()).is_false()
		# Held without a PREMIUM visit means nothing.
		var classic: MachinePlan = MachinePlan.new(tuning, BONUS, rm, true, false, false, true)
		assert_bool(classic.premium or classic.premium_held).is_false()
	var premium: MachinePlan = MachinePlan.new(tuning, TICKET, false, true, false, true)
	assert_bool(premium.resume_at(MachinePlan.WaitPoint.CHOOSE).premium).is_true()


## R1's draw: the odds close, the tray packs over draw_ms (draw_rm_ms), then each ticket flies
## out over fly_ms and lands face up at its reveal: the first first_land_ms after the packing, the
## next land_lead_ms of its own rarity later (land_lead_rm_ms); its effect plays for reveal_ms of
## its rarity (reveal_rm_ms); the pick arms pick_arm_ms after the last effect ends.
func test_the_draw_follows_r1() -> void:
	var tuning: MachineTuning = _tuning()
	for kind: int in [TICKET, BONUS]:
		for rm: bool in [false, true]:
			for tiers: Array in [[COMMON, RARE, LEGENDARY], [LEGENDARY, COMMON], [RARE]]:
				var plan: MachinePlan = MachinePlan.new(tuning, kind, rm)
				var rarities: Array[int] = []
				rarities.assign(tiers)
				plan.set_draw(rarities)
				_assert_draw("kind %d rm %s %s" % [kind, rm, tiers], plan)


## A ticket's flight: below 0 before it leaves the tray, 0 .. 1 in the air, 1 landed; reduced
## motion has no flight, the ticket is there from its reveal.
func test_a_ticket_flies_out_of_the_tray() -> void:
	var plan: MachinePlan = MachinePlan.new(_tuning(), TICKET, false)
	plan.set_draw([COMMON, RARE, LEGENDARY] as Array[int])
	assert_float(plan.ticket_flight(0, plan.drop_at[0] - 0.01)).is_less(0.0)
	_near(plan.ticket_flight(1, plan.drop_at[1] + plan.drop_length[1] / 2.0), 0.5, "mid")
	_near(plan.ticket_flight(2, plan.reveal_at[2]), 1.0, "landed")
	assert_float(plan.ticket_flight(3, 0.0)).is_equal(MachinePlan.NOT_SET)
	assert_float(plan.reveal_progress(0, plan.reveal_at[0])).is_equal(0.0)
	_near(plan.reveal_progress(2, plan.reveal_at[2] + plan.reveal_length[2]), 1.0, "effect end")
	var still: MachinePlan = MachinePlan.new(_tuning(), TICKET, true)
	still.set_draw([COMMON, RARE] as Array[int])
	assert_float(still.ticket_flight(0, still.reveal_at[0] - 0.01)).is_less(0.0)
	assert_float(still.ticket_flight(0, still.reveal_at[0])).is_equal(1.0)


## The landing after the pick: the flight leaves pick_lead_flight_ms after the press and lands
## pick_flight_ms later (pick_flight_rm_ms); the glint, the settle and the holds follow; the next
## visit's hold replaces the end hold.
func test_the_landing_follows_the_tuning() -> void:
	var tuning: MachineTuning = _tuning()
	for rm: bool in [false, true]:
		for landing: int in [
			MachinePlan.Landing.NEW_CARD, MachinePlan.Landing.UPGRADE, MachinePlan.Landing.REGISTER
		]:
			var tag: String = "rm %s landing %d" % [rm, landing]
			var plan: MachinePlan = _full(TICKET, rm, [COMMON, RARE, LEGENDARY], landing)
			var flight: float = MachineTuning.sec(tuning.pick_flight_rm_ms)
			if not rm:
				flight = MachineTuning.seconds(tuning.pick_flight_ms, TICKET)
			_near(plan.press, plan.pick_at, tag + " press")
			var lead: float = MachineTuning.seconds(tuning.pick_lead_flight_ms, TICKET)
			_near(plan.fly_out, plan.press + lead, tag + " fly out")
			_near(plan.land, plan.fly_out + flight, tag + " land")
			assert_float(plan.glint).is_greater_equal(plan.land)
			assert_float(plan.punch).is_greater(plan.land)
			var settle: float = MachineTuning.sec(tuning.punch_length_ms)
			_near(plan.punch_end, plan.punch + settle, tag + " settle")
			var hold: float = MachineTuning.seconds(tuning.end_hold_ms, TICKET)
			_near(plan.end_at, plan.punch_end + hold, tag + " end")
			var drawer: float = MachineTuning.sec(tuning.drawer_lead_ms)
			_near(plan.drawer_in, plan.fly_out - drawer, tag + " drawer")
	var to_bonus: MachinePlan = _full(TICKET, false, [COMMON], MachinePlan.Landing.NEW_CARD, BONUS)
	var gap: float = MachineTuning.sec(tuning.before_bonus_ms)
	_near(to_bonus.end_at, to_bonus.punch_end + gap, "before bonus")


func test_a_bonus_visit_follows_the_tuning() -> void:
	for rm: bool in [false, true]:
		var plan: MachinePlan = _full(
			BONUS, rm, [RARE, RARE, LEGENDARY], MachinePlan.Landing.UPGRADE
		)
		_assert_bonus_intro("bonus rm %s" % rm, plan)
		_assert_draw("bonus rm %s" % rm, plan)


## A bonus extra shift (no inspection) plays the same times; only its texts differ.
func test_a_bonus_without_an_inspection_keeps_the_times() -> void:
	var inspected: MachinePlan = _full(BONUS, false, [COMMON, RARE], MachinePlan.Landing.NEW_CARD)
	var extra: MachinePlan = MachinePlan.new(_tuning(), BONUS, false, false)
	extra.set_draw([COMMON, RARE] as Array[int])
	extra.set_landing(MachinePlan.Landing.NEW_CARD, 1, MachinePlan.NO_VISIT)
	assert_bool(extra.inspected).is_false()
	for point: int in [
		MachinePlan.WaitPoint.CHOOSE, MachinePlan.WaitPoint.PICK, MachinePlan.WaitPoint.END
	]:
		_near(extra.wait_time(point), inspected.wait_time(point), "wait %d" % point)
	assert_array(extra.beat_names()).is_equal(inspected.beat_names())


## The glide back after the shift's last visit: the camera from 1 to 0 over return_glide_ms (a
## cut at rm_cut_ms behind the fade under reduced motion), the machine dimming after it.
func test_the_return_glide_follows_the_tuning() -> void:
	var tuning: MachineTuning = _tuning()
	var glide: float = MachineTuning.sec(tuning.return_glide_ms)
	assert_float(MachinePlan.return_camera(tuning, 0.0, false)).is_equal(1.0)
	_near(MachinePlan.return_camera(tuning, glide / 2.0, false), 0.5, "mid")
	assert_float(MachinePlan.return_camera(tuning, glide, false)).is_equal(0.0)
	var cut: float = MachineTuning.sec(tuning.rm_cut_ms)
	assert_float(MachinePlan.return_camera(tuning, cut - 0.001, true)).is_equal(1.0)
	assert_float(MachinePlan.return_camera(tuning, cut, true)).is_equal(0.0)
	var peak: float = MachineTuning.sec(tuning.rm_fade_ms) / 2.0
	_near(MachinePlan.return_fade(tuning, peak, true), tuning.rm_fade_alpha, "fade peak")
	assert_float(MachinePlan.return_fade(tuning, 0.5, false)).is_equal(0.0)
	assert_float(MachinePlan.return_lit(tuning, 0.0)).is_equal(1.0)
	var length: float = MachinePlan.return_length(tuning, false)
	assert_float(MachinePlan.return_lit(tuning, length)).is_equal(0.0)
	assert_float(length).is_greater_equal(glide)


## resume_at(point) keeps every time and starts the clock at the wait point, resumed.
func test_resume_at_starts_at_each_wait_point() -> void:
	var plan: MachinePlan = _full(TICKET, false, [0, 0, 1], MachinePlan.Landing.NEW_CARD)
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


## The beats come in time order; a planned time never moves when the plan grows; there is no
## punch beat (v0.47: the Regular meter is gone, its settle time stays).
func test_beats_are_ordered_and_grow_with_the_visit() -> void:
	var plan: MachinePlan = MachinePlan.new(_tuning(), TICKET, false)
	assert_array(plan.beat_names()).is_equal([&"feed", &"glide", &"read", &"lights"])
	var choose: float = plan.choose_at
	plan.set_draw([0, 0, 1] as Array[int])
	_near(plan.choose_at, choose, "choose kept")
	assert_array(plan.beats_between(choose, plan.pick_at)).is_equal(
		[&"draw", &"packed", &"reveal_0", &"reveal_1", &"reveal_2"]
	)
	plan.set_landing(MachinePlan.Landing.NEW_CARD, 1, MachinePlan.NO_VISIT)
	assert_array(plan.beats_between(plan.pick_at - 0.001, plan.end_at)).is_equal([&"pick", &"land"])
	assert_float(plan.beat_time(&"punch")).is_equal(MachinePlan.NOT_SET)
	assert_float(plan.punch).is_greater(plan.land)
	var times: Array[float] = []
	for beat_name: StringName in plan.beat_names():
		times.append(plan.beat_time(beat_name))
	var sorted: Array[float] = times.duplicate()
	sorted.sort()
	assert_array(times).is_equal(sorted)


## A binned draw has no flight and no landing beat: its settle (`punch`) follows the bin press.
func test_a_bin_settles_after_the_press() -> void:
	var plan: MachinePlan = MachinePlan.new(_tuning(), TICKET, false)
	plan.set_draw([0, 1, 2] as Array[int])
	plan.set_landing(MachinePlan.Landing.BIN, 1, MachinePlan.NO_VISIT)
	_near(plan.punch, plan.pick_at + MachineTuning.sec(plan.tuning.punch_bin_ms), "punch")
	assert_float(plan.beat_time(&"land")).is_equal(MachinePlan.NOT_SET)
	assert_float(plan.beat_time(&"punch")).is_equal(MachinePlan.NOT_SET)
	# Nothing lands in the cart drawer or glints on a bin.
	assert_float(plan.drawer_in).is_equal(MachinePlan.NOT_SET)
	assert_float(plan.drawer_out).is_equal(MachinePlan.NOT_SET)
	assert_float(plan.glint).is_equal(MachinePlan.NOT_SET)
	assert_float(plan.glint_end).is_equal(MachinePlan.NOT_SET)


## The plan of a `kind` visit drawing `tiers` and landing `landing`, followed by `next_kind`.
func _full(
	kind: int, rm: bool, tiers: Array, landing: int, next_kind: int = MachinePlan.NO_VISIT
) -> MachinePlan:
	var plan: MachinePlan = MachinePlan.new(_tuning(), kind, rm)
	var rarities: Array[int] = []
	rarities.assign(tiers)
	plan.set_draw(rarities)
	plan.set_landing(landing, 1, next_kind)
	return plan


## R1's draw times of `plan` against its tuning (see test_the_draw_follows_r1).
func _assert_draw(tag: String, plan: MachinePlan) -> void:
	var tuning: MachineTuning = plan.tuning
	var kind: int = plan.kind
	var rm: bool = plan.reduced_motion
	var close: float = MachineTuning.seconds(tuning.odds_close_ms, kind)
	_near(plan.odds_close, plan.choose_at + close, tag + " odds close")
	_near(plan.draw, plan.odds_close, tag + " draw")
	var packing: float = MachineTuning.sec(tuning.draw_rm_ms)
	if not rm:
		packing = MachineTuning.seconds(tuning.draw_ms, kind)
	_near(plan.draw_end, plan.draw + packing, tag + " draw end")
	_near(plan.packed, plan.draw_end, tag + " packed")
	assert_int(plan.n_prizes).is_equal(plan.rarities.size())
	var at: float = plan.draw_end + MachineTuning.seconds(tuning.first_land_ms, kind)
	var settled: float = plan.draw_end
	for index: int in range(plan.n_prizes):
		var rarity: int = plan.rarities[index]
		if index > 0:
			if rm:
				at += MachineTuning.sec(tuning.land_lead_rm_ms)
			else:
				at += MachineTuning.seconds(tuning.land_lead_ms, rarity)
		var flying: float = 0.0 if rm else MachineTuning.seconds(tuning.fly_ms, kind)
		var effects: PackedInt32Array = tuning.reveal_rm_ms if rm else tuning.reveal_ms
		var length: float = MachineTuning.seconds(effects, rarity)
		var at_tag: String = "%s %d" % [tag, index]
		_near(plan.reveal_at[index], at, at_tag + " reveal")
		_near(plan.drop_length[index], flying, at_tag + " flight")
		_near(plan.drop_at[index], at - flying, at_tag + " drop")
		_near(plan.reveal_length[index], length, at_tag + " effect")
		_near(plan.beat_time(StringName("reveal_%d" % index)), at, at_tag + " beat")
		settled = maxf(settled, at + length)
	var arm: float = MachineTuning.seconds(tuning.pick_arm_ms, kind)
	_near(plan.pick_at, settled + arm, tag + " pick")
	_near(plan.wait_time(MachinePlan.WaitPoint.PICK), plan.pick_at, tag + " pick wait")


## The BONUS intro (machine v2): the ticket goes from the dock to over the slot in
## bonus_to_slot_ms, is fed in over bonus_feed_ms, then read, relit and chosen again; the camera
## is at the machine and the machine lit throughout.
func _assert_bonus_intro(tag: String, plan: MachinePlan) -> void:
	var tuning: MachineTuning = plan.tuning
	var fed: float = plan.fly_end + MachineTuning.sec(tuning.bonus_feed_ms)
	var read: float = plan.feed_end + MachineTuning.sec(tuning.bonus_read_ms)
	_near(plan.fly, 0.0, tag + " fly")
	_near(plan.fly_end, MachineTuning.sec(tuning.bonus_to_slot_ms), tag + " fly end")
	_near(plan.feed_end, fed, tag + " feed end")
	_near(plan.read_end, read, tag + " read end")
	_near(plan.lights_end, plan.lights + MachineTuning.sec(tuning.bonus_lights_ms), tag + " lit")
	var again: float = plan.feed_end + MachineTuning.sec(tuning.again_ms)
	_near(plan.choose_at, maxf(plan.lights_end, again), tag + " choose")
	assert_float(plan.camera_at(0.0)).is_equal(1.0)
	assert_float(plan.lit_at(0.0)).is_equal(1.0)
	assert_float(plan.snap).is_equal(MachinePlan.NOT_SET)


func _near(actual: float, expected: float, tag: String) -> void:
	(
		assert_float(actual)
		. override_failure_message("%s: %f, expected %f" % [tag, actual, expected])
		. is_equal_approx(expected, TOLERANCE)
	)


func _tuning() -> MachineTuning:
	return load(TUNING) as MachineTuning
