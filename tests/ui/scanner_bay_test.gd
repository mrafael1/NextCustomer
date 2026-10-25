extends GdUnitTestSuite
## The scanner bay on the monitor's count view (#86 v6 scan count-up, round 7's TALLY, ALIVE and
## QUEUE; ScannerBay with BayBed, BayTag and BayQueue): each beat's landing sticker (landing_spec);
## its geometry on the monitor (at BAY_RECT, its header's queue, bed, art and name inside it, all
## on the paper, the landing sticker's bottom-right at stage (623,195), the tag hanging off its top
## right at stage (565,102), growing to the right only); the tag reading each step's value_after on
## the capture tool's --effects row (paper, gold, back to paper on a denial, none for a coupon at
## €0); the queue's text and pips; the item's pose (drop, land, wobble, slide-out); the scan's
## laser fan, BEEP and flash; a ride's slide-out and drop-in with the tag and sticker leaving with
## the item; reduced motion keeping the states; the slap on make_tween's tweens and the knock-off
## in real time; a resumed checkout's ALL PAID end state; and every card's name fitting its label.

const CARDS := "res://data/cards"
## The landing sticker's bottom-right corner on the stage (the mock-up's).
const STICKER_CORNER := Vector2(623, 195)
## The tag's place and string on the stage (the mock-up's).
const TAG_AT := Vector2(565, 102)
const STRING_AT := Rect2(574, 96, 2, 10)
## The capture tool's --effects shift: its row, upgrades, inspection and quota.
const EFFECTS_ROW: Array[String] = ["eggs", "bread", "milk", "multipack", "milk", "milk", "milk"]
const EFFECTS_UPGRADES: Array[String] = ["coupon_engine", "slot_engine", "category_engine"]
const EFFECTS_QUOTA := 73
## The tag after each of the --effects row's 26 beats: [shown, value, paid] (bay_v7_spec.md
## section 0).
const EFFECTS_TAGS: Array[Array] = [
	[true, 1, true],
	[true, 1, true],
	[true, 5, false],
	[true, 10, true],
	[true, 10, true],
	[true, 4, false],
	[true, 6, true],
	[true, 0, false],
	[true, 0, false],
	[false, 0, false],
	[false, 0, false],
	[false, 0, false],
	[true, 4, false],
	[true, 7, true],
	[true, 21, true],
	[true, 21, true],
	[true, 4, false],
	[true, 8, true],
	[true, 24, true],
	[true, 48, true],
	[true, 48, true],
	[true, 4, false],
	[true, 9, true],
	[true, 21, true],
	[true, 63, true],
	[true, 63, true],
]
## Manual stepping of the count's tweens (seconds per step).
const STEP := 0.01

var _folder: String = ""
## The count's tweens, made paused and stepped by _advance.
var _made: Array[Tween] = []


func before_test() -> void:
	_folder = "user://test_scanner_bay_%d" % Time.get_ticks_usec()
	_event_log().use_folder(_folder)
	ProjectSettings.set_setting(SaveService.FOLDER_SETTING, _folder)
	_made.clear()


func after_test() -> void:
	ProjectSettings.set_setting(SaveService.FOLDER_SETTING, null)
	if DirAccess.dir_exists_absolute(_folder):
		for file_name: String in DirAccess.get_files_at(_folder):
			DirAccess.remove_absolute(_folder.path_join(file_name))
		DirAccess.remove_absolute(_folder)


## Each beat kind's landing sticker, its numbers the step's, its step index the beat's first.
func test_the_landing_spec_follows_the_beat_kind() -> void:
	var spec: StickerSpec = ScannerBay.landing_spec(
		_beat(CountUpBeat.Kind.MERGED_PLAIN, 4), _step(3)
	)
	assert_int(spec.kind).is_equal(StickerSpec.Kind.ADD)
	assert_str(spec.text).is_equal("€3")
	assert_int(spec.step_index).is_equal(4)
	spec = ScannerBay.landing_spec(_beat(CountUpBeat.Kind.BASE, 0), _step(5))
	assert_str(spec.text).is_equal("€5")
	assert_int(spec.kind).is_equal(StickerSpec.Kind.ADD)
	var flat: ScoreStep = _step(2, ScoreStep.StepType.FLAT)
	spec = ScannerBay.landing_spec(_beat(CountUpBeat.Kind.BONUS, 1), flat)
	assert_int(spec.kind).is_equal(StickerSpec.Kind.ADD)
	assert_str(spec.text).is_equal("+2")
	var times: ScoreStep = _step(3, ScoreStep.StepType.MULTIPLIER)
	spec = ScannerBay.landing_spec(_beat(CountUpBeat.Kind.STAMP, 2), times)
	assert_int(spec.kind).is_equal(StickerSpec.Kind.MULTIPLY)
	assert_str(spec.text).is_equal("×3")
	var denied: ScoreStep = _step(0, ScoreStep.StepType.PAYOUT_OVERRIDE)
	spec = ScannerBay.landing_spec(_beat(CountUpBeat.Kind.DENIED, 3), denied)
	assert_int(spec.kind).is_equal(StickerSpec.Kind.FIZZLE)
	assert_str(spec.text).is_equal("€0")
	spec = ScannerBay.landing_spec(_beat(CountUpBeat.Kind.FIZZLE, 3), _step(0))
	assert_int(spec.kind).is_equal(StickerSpec.Kind.FIZZLE)
	for kind: CountUpBeat.Kind in [
		CountUpBeat.Kind.PAYOUT,
		CountUpBeat.Kind.ARMED,
		CountUpBeat.Kind.TAG,
		CountUpBeat.Kind.LINK,
	]:
		assert_object(ScannerBay.landing_spec(_beat(kind, 0), _step(1))).is_null()


## On the monitor the bay stands at BAY_RECT, on the paper, and its parts inside it: the queue over
## the header (the light in it), the bed at BED_RECT with the art over its inside (96x96), the name
## label under the bed; the landing sticker lands with its bottom-right at STICKER_CORNER, on the
## paper, in the monitor's sticker layer (clipped to the paper, over the LED).
func test_the_bay_sits_on_the_paper() -> void:
	var monitor: MonitorView = await _monitor()
	var bay: ScannerBay = monitor.bay()
	monitor.reduced_motion = func() -> bool: return true
	# On the screen in every mode (the monitor bay follow-up of #86).
	assert_bool(bay.is_visible_in_tree()).is_true()
	monitor.led.start_count(34)
	await _frames(1)
	assert_bool(bay.is_visible_in_tree()).is_true()
	var rect: Rect2 = bay.get_global_rect()
	assert_that(rect).is_equal(MonitorView.BAY_RECT)
	assert_vector(rect.size).is_equal(ScannerBay.SIZE)
	var paper: Rect2 = MonitorView.PAPER_RECT
	# The bay with its shadow.
	(
		assert_bool(
			paper.encloses(rect.grow_individual(0, 0, ScannerBay.SHADOW, ScannerBay.SHADOW))
		)
		. is_true()
	)
	var bed: Rect2 = _shifted(ScannerBay.BED_RECT, rect.position)
	assert_that(bay.bed().get_global_rect()).is_equal(bed)
	var inside: Rect2 = bed.grow(-ScannerBay.BED_BORDER)
	assert_that(bay.bed().art_rect()).is_equal(inside)
	assert_that(bay.bed().art_rect()).is_equal(_shifted(ScannerBay.ART_RECT, rect.position))
	assert_vector(bay.bed().art_rect().size).is_equal(Vector2(96, 96))
	var header: Rect2 = _shifted(ScannerBay.HEADER_RECT, rect.position)
	assert_that(bay.queue().get_global_rect()).is_equal(header)
	var light: Rect2 = _shifted(ScannerBay.LIGHT_RECT, rect.position)
	var label: Rect2 = bay.name_label().get_global_rect()
	assert_that(label).is_equal(_shifted(ScannerBay.NAME_RECT, rect.position))
	for part: Rect2 in [header, bed, label]:
		(
			assert_bool(rect.grow(-ScannerBay.BORDER).encloses(part))
			. override_failure_message(str(part))
			. is_true()
		)
	assert_bool(header.encloses(light)).is_true()
	assert_bool(header.intersects(bed)).is_false()
	assert_bool(bed.intersects(label)).is_false()
	# The bay apart from the LED's number and € and the right part (channel, scan text).
	assert_bool(rect.intersects(MonitorView.LED_COUNT_RECT)).is_false()
	assert_bool(rect.intersects(MonitorView.RIGHT_RECT)).is_false()
	# A landing sticker at the corner, on the paper.
	var milk: CardDefinition = _card("milk")
	bay.follow_beat(_beat(CountUpBeat.Kind.MERGED_PLAIN, 0, 0, true), _step(3), milk)
	var sticker: EffectSticker = bay.landing_sticker()
	assert_object(sticker).is_not_null()
	await _frames(1)
	var layer: Control = sticker.get_parent() as Control
	assert_object(layer).is_not_same(bay)
	assert_bool(layer.clip_contents).is_true()
	assert_that(layer.get_global_rect()).is_equal(paper)
	assert_int(layer.get_parent().get_index()).is_greater(monitor.led.get_index())
	var placed: Rect2 = sticker.get_global_rect()
	assert_vector(placed.end).is_equal(STICKER_CORNER)
	assert_vector(bay.get_global_transform() * ScannerBay.STICKER_CORNER).is_equal(STICKER_CORNER)
	assert_bool(paper.encloses(placed)).override_failure_message(str(placed)).is_true()
	assert_vector(bay.landing_point()).is_equal(placed.get_center())
	assert_bool(sticker.is_visible_in_tree()).is_true()
	# Outside the count the sticker goes; the bay stays, planning's again.
	monitor.led.clear()
	await _frames(1)
	assert_bool(bay.is_visible_in_tree()).is_true()
	assert_bool(bay.is_planning()).is_true()
	assert_object(bay.landing_sticker()).is_null()


## The tag hangs off the bay's top right on the monitor's top layer: at rest at TAG_AT, its string
## at STRING_AT, MIN_WIDTH wide for "€1"; wider values grow it to the right only, on the 2 px grid,
## on the paper; it sends its chips from (565 + w - 6, 111); its text sits on its face, right of
## TEXT_LEFT.
func test_the_tag_hangs_off_the_bays_top_right() -> void:
	var monitor: MonitorView = await _monitor()
	monitor.reduced_motion = func() -> bool: return true
	monitor.led.start_count(34)
	await _frames(1)
	var tag: BayTag = monitor.bay().tag()
	tag.show_value(1, false)
	await _frames(1)
	assert_bool(tag.is_visible_in_tree()).is_true()
	assert_that(tag.get_global_rect()).is_equal(Rect2(TAG_AT, Vector2(52, 24)))
	assert_that(_shifted(BayTag.STRING_RECT, tag.get_global_rect().position)).is_equal(STRING_AT)
	# Over the bay, the sticker layer and the chips.
	var layer: Control = tag.get_parent() as Control
	assert_int(tag.get_index()).is_greater(monitor.chips().get_index())
	assert_int(layer.get_index()).is_greater(monitor.led.get_index())
	for value: int in [1, 126, 999]:
		tag.show_value(value, true)
		await _frames(1)
		var rect: Rect2 = tag.get_global_rect()
		var message: String = "%s %s" % [tag.text(), rect]
		assert_float(rect.position.x).override_failure_message(message).is_equal(TAG_AT.x)
		assert_float(rect.position.y).is_equal(TAG_AT.y)
		assert_int(int(rect.size.x) % 2).override_failure_message(message).is_equal(0)
		assert_float(rect.size.x).is_greater_equal(BayTag.MIN_WIDTH)
		assert_float(rect.size.x).is_equal(BayTag.width_for(tag.text()))
		var string: Rect2 = _shifted(BayTag.STRING_RECT, rect.position)
		(
			assert_bool(MonitorView.PAPER_RECT.encloses(rect.merge(string)))
			. override_failure_message(message)
			. is_true()
		)
		assert_vector(tag.send_point()).is_equal(Vector2(TAG_AT.x + rect.size.x - 6.0, 111.0))
		var label: Label = tag.get_child(0) as Label
		var face: Rect2 = label.get_global_rect()
		assert_float(face.position.x).is_equal(rect.position.x + BayTag.TEXT_LEFT)
		assert_bool(rect.encloses(face)).override_failure_message(message).is_true()
		var font: Font = label.get_theme_font("font")
		var width: float = (
			font.get_string_size(tag.text(), HORIZONTAL_ALIGNMENT_LEFT, -1, BayTag.FONT_SIZE).x
		)
		assert_float(width).override_failure_message(message).is_less_equal(face.size.x)
	assert_float(BayTag.width_for("€1")).is_equal(BayTag.MIN_WIDTH)
	assert_float(BayTag.width_for("€126")).is_greater(BayTag.width_for("€1"))


## The --effects row (live data, the capture tool's three upgrades and Spot check): after each
## beat the tag reads that beat's step's value_after (paper at the scan, gold on a gain or at the
## payout's rise, paper at €0 on the denial, none for the coupon at €0), the table of
## bay_v7_spec.md section 0; its payouts sum to the plan's total (143 with Category engine).
func test_the_tag_reads_each_steps_value_after() -> void:
	var monitor: MonitorView = await _monitor()
	monitor.reduced_motion = func() -> bool: return true
	var bay: ScannerBay = monitor.bay()
	var row: Array[CardInstance] = []
	for card_id: String in EFFECTS_ROW:
		row.append(CardInstance.new(_card(card_id), row.size() + 1))
	var upgrades: Array[UpgradeDefinition] = []
	for upgrade_id: String in EFFECTS_UPGRADES:
		upgrades.append(load("res://data/upgrades/%s.tres" % upgrade_id) as UpgradeDefinition)
	var inspections: Array[InspectionDefinition] = [
		load("res://data/inspections/spot_check.tres") as InspectionDefinition
	]
	var result: ScoreResult = Scoring.score(row, upgrades, inspections)
	var plan: CountUpPlan = CountUpPlan.build(
		result.steps, EFFECTS_QUOTA, CountUpContext.new(), load(CountUp.TUNING_PATH)
	)
	assert_int(result.total).is_equal(143)
	assert_int(plan.beats.size()).is_equal(EFFECTS_TAGS.size())
	monitor.led.start_count(EFFECTS_QUOTA)
	bay.start(row.size())
	var seen: Array[Array] = []
	var paid_out: int = 0
	for beat: CountUpBeat in plan.beats:
		var step: ScoreStep = result.steps[beat.steps[0]]
		var definition: CardDefinition = row[beat.scan_slot].definition
		bay.follow_beat(beat, step, definition)
		if beat.payout > 0:
			bay.pay()
			paid_out += beat.payout
		var tag: BayTag = bay.tag()
		seen.append([tag.visible, tag.value() if tag.visible else 0, tag.is_paid() and tag.visible])
		# The tag is the step's own reading: no sums of its own.
		var own: ScoreStep = result.steps[beat.steps[beat.steps.size() - 1]]
		if tag.visible and own.slot == beat.scan_slot:
			assert_int(tag.value()).override_failure_message(str(beat.steps)).is_equal(
				own.value_after
			)
	assert_array(seen).is_equal(EFFECTS_TAGS)
	assert_int(paid_out).is_equal(result.total)


## A plain item's payout rise (pay()) that comes before its opening count starts (SLAP_IN_S on
## the count's clock) keeps the tag gold: the waiting count never turns it back to paper; a
## DENIED count still does.
func test_a_rise_before_the_opening_count_stays_gold() -> void:
	var monitor: MonitorView = await _monitor()
	_manual(monitor)
	monitor.led.start_count(40)
	var bay: ScannerBay = monitor.bay()
	var tag: BayTag = bay.tag()
	bay.follow_beat(_beat(CountUpBeat.Kind.MERGED_PLAIN, 0, 0, true), _step(5), _card("milk"))
	assert_bool(tag.is_paid()).is_false()
	_advance(0.06)
	bay.pay()
	assert_bool(tag.is_paid()).is_true()
	_advance(ScannerBay.SLAP_IN_S + BayTag.COUNT_S + 0.1)
	assert_bool(tag.is_paid()).is_true()
	assert_int(tag.value()).is_equal(5)
	assert_array(tag.face_colours()).is_equal(BayTag.PAID_COLOURS)
	var denied: ScoreStep = _step(0, ScoreStep.StepType.PAYOUT_OVERRIDE)
	bay.follow_beat(_beat(CountUpBeat.Kind.DENIED, 1), denied, null)
	_advance(ScannerBay.SLAP_IN_S + BayTag.COUNT_S + 0.1)
	assert_bool(tag.is_paid()).is_false()
	assert_int(tag.value()).is_equal(0)


## A coupon at €0 hangs no tag; a step that gives it worth shows it (gold).
func test_a_coupon_has_no_tag_until_it_pays() -> void:
	var monitor: MonitorView = await _monitor()
	monitor.reduced_motion = func() -> bool: return true
	monitor.led.start_count(34)
	var bay: ScannerBay = monitor.bay()
	var multipack: CardDefinition = _card("multipack")
	assert_bool(multipack.is_coupon()).is_true()
	bay.follow_beat(_beat(CountUpBeat.Kind.MERGED_PLAIN, 0, 0, true), _step(0), multipack)
	assert_bool(bay.tag().visible).is_false()
	bay.follow_beat(
		_beat(CountUpBeat.Kind.ARMED, 1), _step(3, ScoreStep.StepType.WASTED), multipack
	)
	assert_bool(bay.tag().visible).is_false()
	var gain: ScoreStep = _step(2, ScoreStep.StepType.FLAT)
	gain.value_after = 2
	bay.follow_beat(_beat(CountUpBeat.Kind.BONUS, 2), gain, multipack)
	assert_bool(bay.tag().visible).is_true()
	assert_int(bay.tag().value()).is_equal(2)
	assert_bool(bay.tag().is_paid()).is_true()


## The queue: "SCANNER" with no pips outside a count; start(5) reads "5 LEFT" with five teal
## pips; each ride in counts down ("4 LEFT" … "LAST"), the item in the bay tomato light (green
## light once met), the bagged ones gold; after the last ride DONE, every pip gold.
func test_the_queue_counts_down_and_colours_its_pips() -> void:
	var monitor: MonitorView = await _monitor()
	monitor.reduced_motion = func() -> bool: return true
	var bay: ScannerBay = monitor.bay()
	var queue: BayQueue = bay.queue()
	assert_str(queue.text()).is_equal(BayQueue.IDLE_TEXT)
	assert_array(queue.pip_rects()).is_empty()
	monitor.led.start_count(34)
	bay.start(5)
	assert_str(queue.text()).is_equal("5 LEFT")
	assert_array(queue.pip_colours()).is_equal(_colours(5, BayQueue.TO_COME_COLOR))
	var milk: CardDefinition = _card("milk")
	var texts: PackedStringArray = PackedStringArray()
	for slot: int in range(5):
		bay.ride(slot - 1, slot, milk, 0.0)
		var opening: CountUpBeat = _beat(CountUpBeat.Kind.MERGED_PLAIN, slot, slot, true)
		bay.follow_beat(opening, _step(3, ScoreStep.StepType.BASE, slot), milk)
		texts.append(queue.text())
		var colours: Array[Color] = queue.pip_colours()
		assert_that(colours[slot]).is_equal(BayQueue.IN_COLOR)
		for earlier: int in range(slot):
			assert_that(colours[earlier]).is_equal(BayQueue.BAGGED_COLOR)
		for later: int in range(slot + 1, 5):
			assert_that(colours[later]).is_equal(BayQueue.TO_COME_COLOR)
	assert_array(texts).is_equal(
		PackedStringArray(["4 LEFT", "3 LEFT", "2 LEFT", "1 LEFT", "LAST"])
	)
	bay.set_met(true)
	assert_that(queue.pip_colours()[4]).is_equal(BayQueue.IN_MET_COLOR)
	bay.ride(4, -1, null, 0.0)
	assert_str(queue.text()).is_equal(BayQueue.DONE_TEXT)
	assert_array(queue.pip_colours()).is_equal(_colours(5, BayQueue.BAGGED_COLOR))
	assert_str(bay.name_label().text).is_equal(ScannerBay.END_NAME)
	assert_str(bay.bed().idle_label().text).is_equal(BayBed.END_TEXT)
	assert_bool(bay.bed().idle_label().visible).is_true()


## The item's pose (pure): it falls from FALL_FROM px up, stretched; lands squashed; bounces
## BOUNCE_PX up at the bounce's middle; rests; a wobble's hit squashes it; the slide-out ends
## OUT_DX across and OUT_DY down, turned OUT_DEG, gone. Offsets stay on the 2 px grid.
func test_alive_pose() -> void:
	var fall: float = BayBed.FALL_S
	var pose: BayBed.BayPose = BayBed.pose(0.0, fall, -1.0, -1.0, false)
	assert_vector(pose.offset).is_equal(Vector2(0, -BayBed.FALL_FROM))
	assert_vector(pose.scale).is_equal(BayBed.FALL_SCALE)
	pose = BayBed.pose(fall, fall, -1.0, -1.0, false)
	assert_vector(pose.scale).is_equal_approx(Vector2(1.26, 0.76), Vector2(0.001, 0.001))
	pose = BayBed.pose(fall + BayBed.LAND_SQUASH_S + BayBed.BOUNCE_S / 2.0, fall, -1.0, -1.0, false)
	assert_vector(pose.offset).is_equal(Vector2(0, -BayBed.BOUNCE_PX))
	assert_vector(pose.scale).is_equal(BayBed.BOUNCE_SCALE)
	for drop_t: float in [fall + BayBed.LAND_S, -1.0]:
		pose = BayBed.pose(drop_t, fall, -1.0, -1.0, false)
		assert_vector(pose.offset).is_equal(Vector2.ZERO)
		assert_vector(pose.scale).is_equal(Vector2.ONE)
		assert_float(pose.rotation_deg).is_equal(0.0)
		assert_float(pose.alpha).is_equal(1.0)
	# A fall of 0 (item 0, already in the scanner's cell): the land alone.
	pose = BayBed.pose(0.0, 0.0, -1.0, -1.0, false)
	assert_vector(pose.scale).is_equal_approx(Vector2(1.26, 0.76), Vector2(0.001, 0.001))
	pose = BayBed.pose(-1.0, fall, 0.02, -1.0, false)
	assert_vector(pose.scale).is_equal_approx(BayBed.WOBBLE_HIT, Vector2(0.001, 0.001))
	pose = BayBed.pose(-1.0, fall, -1.0, -1.0, true)
	assert_vector(pose.offset).is_equal(Vector2(0, -BayBed.BOB_PX))
	pose = BayBed.pose(-1.0, fall, -1.0, 1.0, false)
	assert_vector(pose.offset).is_equal(Vector2(BayBed.OUT_DX, BayBed.OUT_DY))
	assert_float(pose.rotation_deg).is_equal(BayBed.OUT_DEG)
	assert_float(pose.alpha).is_equal(0.0)
	assert_vector(BayBed.out_pose(1.0).offset).is_equal(pose.offset)
	assert_vector(BayBed.out_pose(-1.0).offset).is_equal(Vector2.ZERO)
	for index: int in range(60):
		var at: float = index * 0.01
		for checked: BayBed.BayPose in [
			BayBed.pose(at, fall, -1.0, -1.0, false),
			BayBed.pose(-1.0, fall, at, -1.0, true),
			BayBed.pose(-1.0, fall, -1.0, at / 0.6, false),
		]:
			assert_float(fmod(absf(checked.offset.x), 2.0)).is_equal(0.0)
			assert_float(fmod(absf(checked.offset.y), 2.0)).is_equal(0.0)


## A scan on the count's clock: the fan sweeps FAN_FROM to FAN_TO over FAN_SWEEP_S and is gone
## after FAN_S; BEEP! shows from BEEP_DELAY_S for BEEP_S at BEEP_AT, turned BEEP_TILT, inside the
## art, as the bed flashes; the fan is green once met.
func test_the_fan_and_beep_follow_the_scan() -> void:
	var monitor: MonitorView = await _monitor()
	_manual(monitor)
	monitor.led.start_count(34)
	var bay: ScannerBay = monitor.bay()
	var bed: BayBed = bay.bed()
	bay.follow_beat(_beat(CountUpBeat.Kind.MERGED_PLAIN, 0, 0, true), _step(3), _card("milk"))
	assert_float(bed.fan_angle()).is_equal_approx(BayBed.FAN_FROM, 0.001)
	assert_array(bed.fan_colours()).is_equal([BayBed.FAN_COLOR, BayBed.FAN_CORE_COLOR])
	var beep: Label = bed.beep_label()
	assert_bool(beep.visible).is_false()
	_advance(BayBed.FAN_SWEEP_S)
	assert_float(bed.fan_angle()).is_equal_approx(BayBed.FAN_TO, 0.5)
	_advance(0.03)
	assert_bool(beep.visible).is_true()
	assert_float(bed.flash()).is_greater(0.0)
	assert_vector(beep.position).is_equal(BayBed.BEEP_AT)
	assert_float(beep.rotation_degrees).is_equal(BayBed.BEEP_TILT)
	await _frames(1)
	var art: Rect2 = bed.art_rect()
	var drawn: Rect2 = beep.get_global_rect()
	assert_bool(art.grow(2.0).encloses(drawn)).override_failure_message(str(drawn)).is_true()
	_advance(BayBed.FAN_S - BayBed.FAN_SWEEP_S)
	assert_bool(is_nan(bed.fan_angle())).is_true()
	_advance(BayBed.BEEP_S)
	assert_bool(beep.visible).is_false()
	assert_float(bed.flash()).is_equal(0.0)
	bay.set_met(true)
	assert_array(bed.fan_colours()).is_equal([BayBed.FAN_MET_COLOR, BayBed.FAN_MET_CORE_COLOR])


## A ride: the item in the bay slides out over OUT_SHARE of it (its tag and sticker with it), the
## bed empty with GONE_NAME, then the next drops in and lands as the belt brings it; its pip and
## the bagged one's follow; the last ride ends ALL PAID, THANK YOU, DONE.
func test_a_ride_slides_out_then_drops_in() -> void:
	var monitor: MonitorView = await _monitor()
	_manual(monitor)
	monitor.led.start_count(34)
	var bay: ScannerBay = monitor.bay()
	var bed: BayBed = bay.bed()
	bay.start(2)
	var milk: CardDefinition = _card("milk")
	var bread: CardDefinition = _card("bread")
	bay.ride(-1, 0, milk, 0.0)
	assert_object(bed.art()).is_not_null()
	assert_str(bay.name_label().text).is_equal("MILK")
	bay.follow_beat(_beat(CountUpBeat.Kind.MERGED_PLAIN, 0, 0, true), _step(3), milk)
	_advance(1.0)
	var tag: BayTag = bay.tag()
	var sticker: EffectSticker = bay.landing_sticker()
	var tag_rest: Vector2 = tag.position
	var sticker_rest: Vector2 = sticker.position
	var old: TextureRect = bed.art()
	bay.ride(0, 1, bread, 0.3)
	var out_s: float = 0.3 * ScannerBay.OUT_SHARE
	assert_bool(bed.is_leaving()).is_true()
	_advance(out_s / 2.0)
	await _frames(1)
	assert_float(old.position.x).is_less(0.0)
	assert_float(old.modulate.a).is_less(1.0)
	assert_float(tag.position.x).is_less(tag_rest.x)
	assert_float(sticker.position.x).is_less(sticker_rest.x)
	_advance(out_s / 2.0 + STEP / 2.0)
	assert_object(bed.art()).is_null()
	assert_bool(tag.visible).is_false()
	assert_object(bay.landing_sticker()).is_null()
	assert_str(bay.name_label().text).is_equal(ScannerBay.GONE_NAME)
	assert_str(bay.queue().text()).is_equal("1 LEFT")
	_advance(0.3 - out_s - BayBed.FALL_S / 2.0)
	assert_object(bed.art()).is_not_null()
	assert_str(bay.name_label().text).is_equal("BREAD")
	assert_float(bed.art_pose().offset.y).is_less(0.0)
	assert_str(bay.queue().text()).is_equal("LAST")
	assert_that(bay.queue().pip_colours()[0]).is_equal(BayQueue.IN_COLOR)
	_advance(BayBed.FALL_S / 2.0 + BayBed.LAND_S + STEP)
	assert_vector(bed.art_pose().scale).is_equal(Vector2.ONE)
	assert_float(bed.art_pose().offset.x).is_equal(0.0)
	assert_that(bay.queue().pip_colours()[0]).is_equal(BayQueue.BAGGED_COLOR)
	# The last ride: out over its whole length (at most OUT_S), then all done.
	bay.ride(1, -1, null, 0.3)
	_advance(BayBed.OUT_S + STEP)
	assert_object(bed.art()).is_null()
	assert_str(bay.queue().text()).is_equal("LAST")
	_advance(0.3 - BayBed.OUT_S + STEP)
	assert_str(bay.queue().text()).is_equal(BayQueue.DONE_TEXT)
	assert_str(bay.name_label().text).is_equal(ScannerBay.END_NAME)
	assert_bool(bed.idle_label().visible).is_true()
	assert_str(bed.idle_label().text).is_equal(BayBed.END_TEXT)


## Reduced motion keeps the states: the item shows at its opening beat, at rest; the fan stands at
## its middle for FAN_S, the BEEP shows unpopped, no flash; the tag shows at once; a ride takes the
## item out at once; no wobble.
func test_reduced_motion_keeps_the_states() -> void:
	var monitor: MonitorView = await _monitor()
	_manual(monitor)
	monitor.reduced_motion = func() -> bool: return true
	monitor.led.start_count(34)
	var bay: ScannerBay = monitor.bay()
	var bed: BayBed = bay.bed()
	bay.start(2)
	var milk: CardDefinition = _card("milk")
	bay.ride(-1, 0, milk, 0.0)
	assert_object(bed.art()).is_null()
	bay.follow_beat(_beat(CountUpBeat.Kind.BASE, 0, 0, true), _step(3), milk)
	assert_object(bed.art()).is_not_null()
	assert_vector(bed.art_pose().offset).is_equal(Vector2.ZERO)
	assert_vector(bed.art().scale).is_equal(Vector2.ONE)
	assert_float(bed.fan_angle()).is_equal(0.0)
	assert_bool(bay.tag().visible).is_true()
	assert_int(bay.tag().value()).is_equal(3)
	assert_bool(bay.tag().is_paid()).is_false()
	var bonus: ScoreStep = _step(2, ScoreStep.StepType.FLAT)
	bonus.value_after = 5
	bay.follow_beat(_beat(CountUpBeat.Kind.BONUS, 1), bonus, milk)
	assert_int(bay.tag().value()).is_equal(5)
	assert_bool(bay.tag().is_paid()).is_true()
	assert_vector(bay.tag().scale).is_equal(Vector2.ONE)
	_advance(BayBed.BEEP_DELAY_S + 0.05)
	assert_float(bed.fan_angle()).is_equal(0.0)
	assert_bool(bed.beep_label().visible).is_true()
	assert_vector(bed.beep_label().scale).is_equal(Vector2.ONE)
	assert_float(bed.flash()).is_equal(0.0)
	assert_vector(bed.art().scale).is_equal(Vector2.ONE)
	_advance(BayBed.FAN_S)
	assert_bool(is_nan(bed.fan_angle())).is_true()
	bay.ride(0, 1, _card("bread"), 0.2)
	assert_object(bed.art()).is_null()
	assert_bool(bay.tag().visible).is_false()
	assert_str(bay.name_label().text).is_equal(ScannerBay.GONE_NAME)
	_advance(0.3)
	assert_object(bed.art()).is_null()


## The scan's slap runs on make_tween's tweens (the count-up's on the real screen); reduced
## motion keeps the states (the sticker at its size) and drops the slap.
func test_the_slap_runs_on_the_count_ups_tweens() -> void:
	var monitor: MonitorView = await _monitor()
	var bay: ScannerBay = monitor.bay()
	var reduced: Array[bool] = [false]
	monitor.reduced_motion = func() -> bool: return reduced[0]
	var made: Array[Tween] = []
	monitor.led.beat().make_tween = func() -> Tween:
		var tween: Tween = monitor.create_tween()
		made.append(tween)
		return tween
	monitor.led.start_count(34)
	var milk: CardDefinition = _card("milk")
	bay.follow_beat(_beat(CountUpBeat.Kind.MERGED_PLAIN, 0, 0, true), _step(3), milk)
	assert_int(made.size()).is_greater_equal(4)
	var sticker: EffectSticker = bay.landing_sticker()
	assert_float(sticker.scale.x).is_equal_approx(ScannerBay.SLAP_FROM, 0.001)
	await get_tree().create_timer(ScannerBay.SLAP_IN_S + ScannerBay.SLAP_SETTLE_S + 0.1).timeout
	assert_vector(sticker.scale).is_equal_approx(Vector2.ONE, Vector2(0.001, 0.001))
	reduced[0] = true
	bay.follow_beat(
		_beat(CountUpBeat.Kind.MERGED_PLAIN, 1, 1, true), _step(4, ScoreStep.StepType.BASE, 1), milk
	)
	assert_vector(bay.landing_sticker().scale).is_equal(Vector2.ONE)
	# On the real screen the LED's beat takes the count-up's tweens, which the bay uses.
	var screen: ShiftScreen = await _screen()
	assert_bool(screen._led.beat().make_tween == screen._count_up._tween).is_true()


## The knock-off sends the sticker off left and up, spinning, on the bay's own real-time tween
## (a frozen count-up clock never holds it), then frees it; under reduced motion it goes at once,
## and a reset mid-flight frees it too.
func test_the_knock_off_flies_in_real_time() -> void:
	var monitor: MonitorView = await _monitor()
	var bay: ScannerBay = monitor.bay()
	var reduced: Array[bool] = [true]
	monitor.reduced_motion = func() -> bool: return reduced[0]
	# A frozen count-up clock: the slap never moves on it.
	monitor.led.beat().make_tween = func() -> Tween:
		return monitor.create_tween().set_speed_scale(0.0)
	monitor.led.start_count(34)
	var milk: CardDefinition = _card("milk")
	bay.follow_beat(_beat(CountUpBeat.Kind.MERGED_PLAIN, 0, 0, true), _step(3), milk)
	var sticker: EffectSticker = bay.landing_sticker()
	bay.knock_off()
	assert_object(bay.landing_sticker()).is_null()
	await _frames(1)
	assert_bool(is_instance_valid(sticker)).is_false()
	reduced[0] = false
	bay.land(ScannerBay.landing_spec(_beat(CountUpBeat.Kind.BASE, 1), _step(4)))
	sticker = bay.landing_sticker()
	var start: Vector2 = sticker.position
	bay.knock_off()
	assert_vector(sticker.scale).is_equal(Vector2.ONE)
	await get_tree().create_timer(ScannerBay.KNOCK_S * 0.4).timeout
	assert_float(sticker.position.x).is_less(start.x)
	assert_float(sticker.position.y).is_less(start.y)
	assert_float(sticker.rotation_degrees).is_less(0.0)
	await get_tree().create_timer(ScannerBay.KNOCK_S).timeout
	assert_bool(is_instance_valid(sticker)).is_false()
	# Nothing to knock off: nothing happens.
	bay.knock_off()
	assert_object(bay.landing_sticker()).is_null()
	# A reset mid-flight (the LED leaving the count, a new count) frees the flying sticker.
	bay.land(ScannerBay.landing_spec(_beat(CountUpBeat.Kind.BASE, 2), _step(5)))
	sticker = bay.landing_sticker()
	bay.knock_off()
	await get_tree().create_timer(ScannerBay.KNOCK_S * 0.3).timeout
	assert_bool(is_instance_valid(sticker)).is_true()
	bay.reset()
	await _frames(1)
	assert_bool(is_instance_valid(sticker)).is_false()


## A resumed checkout's end state: every item paid and bagged (no art, no tag, no sticker; ALL
## PAID, THANK YOU, DONE with every pip gold), met or not, nothing moving.
func test_the_end_state_reads_all_paid() -> void:
	var monitor: MonitorView = await _monitor()
	var bay: ScannerBay = monitor.bay()
	monitor.led.start_count(34)
	var milk: CardDefinition = _card("milk")
	bay.follow_beat(_beat(CountUpBeat.Kind.MERGED_PLAIN, 0, 0, true), _step(3), milk)
	bay.show_end_state(5, true)
	assert_object(bay.bed().art()).is_null()
	assert_bool(bay.tag().visible).is_false()
	assert_object(bay.landing_sticker()).is_null()
	assert_bool(bay.bed().idle_label().visible).is_true()
	assert_str(bay.bed().idle_label().text).is_equal(BayBed.END_TEXT)
	assert_str(bay.name_label().text).is_equal(ScannerBay.END_NAME)
	assert_str(bay.queue().text()).is_equal(BayQueue.DONE_TEXT)
	assert_array(bay.queue().pip_colours()).is_equal(_colours(5, BayQueue.BAGGED_COLOR))
	assert_bool(bay.is_met()).is_true()
	assert_that(bay.light_colour()).is_equal(ScannerBay.LIGHT_MET_COLOR)
	assert_bool(is_nan(bay.bed().fan_angle())).is_true()
	bay.show_end_state(3, false)
	assert_bool(bay.is_met()).is_false()
	assert_str(bay.queue().text()).is_equal(BayQueue.DONE_TEXT)
	assert_int(bay.queue().pip_rects().size()).is_equal(3)


## Every product's name (uppercase) fits the name label's inside on one line at one of
## NAME_SIZES, most plain names at the largest; a BIG or GOLDEN name too long for it shows its
## plain product's name (v0.48), which fits; so do THANK YOU and the dash between items, which
## Pixelify has a glyph for.
func test_every_name_fits_the_label() -> void:
	var monitor: MonitorView = await _monitor()
	monitor.reduced_motion = func() -> bool: return true
	var bay: ScannerBay = monitor.bay()
	monitor.led.start_count(34)
	var label: Label = bay.name_label()
	var room: float = ScannerBay.NAME_RECT.size.x - 2.0 * ScannerBay.NAME_BORDER
	var at_largest: int = 0
	var products: int = 0
	var shortened: int = 0
	var slot: int = 0
	for definition: CardDefinition in _cards():
		if definition.is_coupon():
			continue
		var opening: CountUpBeat = _beat(CountUpBeat.Kind.BASE, slot, slot, true)
		bay.follow_beat(opening, _step(1, ScoreStep.StepType.BASE, slot), definition)
		slot += 1
		var own: String = definition.display_name.to_upper()
		if definition.tier != CardDefinition.Tier.PLAIN:
			if label.text != own:
				shortened += 1
				assert_bool(ScannerBay.name_fits(own)).override_failure_message(own).is_false()
				assert_str(label.text).is_equal(definition.product_card().display_name.to_upper())
			_assert_label_fits(label, room)
			continue
		products += 1
		assert_str(label.text).is_equal(own)
		var font_size: int = label.get_theme_font_size("font_size")
		if font_size == ScannerBay.NAME_SIZES[0]:
			at_largest += 1
		_assert_label_fits(label, room)
	prints("#86 bay names at the largest size:", at_largest, "of", products)
	prints("v0.48 tier names shown as their plain product's:", shortened)
	assert_int(shortened).is_greater(0)
	assert_int(2 * at_largest).is_greater(products)
	bay.ride(slot - 1, -1, null, 0.0)
	assert_str(label.text).is_equal(ScannerBay.END_NAME)
	assert_float(_label_width(label)).is_less_equal(room)
	assert_bool(ArtStyle.DISPLAY_FONT.has_char(ScannerBay.GONE_NAME.unicode_at(0))).is_true()


## `label`'s text fits `room` on one line at its font size.
func _assert_label_fits(label: Label, room: float) -> void:
	var font_size: int = label.get_theme_font_size("font_size")
	(
		assert_float(_label_width(label))
		. override_failure_message("%s at %d" % [label.text, font_size])
		. is_less_equal(room)
	)


## A beat of `kind` on step `step_index`, slot `slot`, the scan on `slot` (opening it when
## `opens`).
static func _beat(
	kind: CountUpBeat.Kind, step_index: int, slot: int = 0, opens: bool = false
) -> CountUpBeat:
	var beat: CountUpBeat = CountUpBeat.new()
	beat.kind = kind
	beat.steps = PackedInt32Array([step_index])
	beat.slot = slot
	beat.scan_slot = slot
	beat.opens_slot = opens
	return beat


## A step of `value` (its value_after too) on `slot`.
static func _step(
	value: int, step_type: ScoreStep.StepType = ScoreStep.StepType.BASE, slot: int = 0
) -> ScoreStep:
	var step: ScoreStep = ScoreStep.new()
	step.step_type = step_type
	step.value = value
	step.value_after = value
	step.slot = slot
	return step


static func _colours(count: int, colour: Color) -> Array[Color]:
	var colours: Array[Color] = []
	for _index: int in range(count):
		colours.append(colour)
	return colours


static func _card(card_id: String) -> CardDefinition:
	return load("%s/%s.tres" % [CARDS, card_id]) as CardDefinition


static func _cards() -> Array[CardDefinition]:
	var cards: Array[CardDefinition] = []
	for file_name: String in DirAccess.get_files_at(CARDS):
		if file_name.ends_with(".tres"):
			cards.append(load(CARDS.path_join(file_name)) as CardDefinition)
	return cards


static func _shifted(rect: Rect2, origin: Vector2) -> Rect2:
	return Rect2(origin + rect.position, rect.size)


static func _label_width(label: Label) -> float:
	var font: Font = label.get_theme_font("font")
	var font_size: int = label.get_theme_font_size("font_size")
	return font.get_string_size(label.text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x


## The monitor's count tweens made paused, for _advance to step.
func _manual(monitor: MonitorView) -> void:
	monitor.led.beat().make_tween = func() -> Tween:
		var tween: Tween = monitor.create_tween()
		tween.pause()
		_made.append(tween)
		return tween


## Steps every count tween made so far (and those they make) by `seconds`, STEP at a time.
func _advance(seconds: float) -> void:
	var left: float = seconds
	while left > 0.00001:
		var step: float = minf(STEP, left)
		for tween: Tween in _made.duplicate():
			if tween.is_valid():
				tween.custom_step(step)
		left -= step


## A monitor alone at its stage place, in the tree.
func _monitor() -> MonitorView:
	var holder: Control = auto_free(Control.new())
	get_tree().root.add_child(holder)
	var monitor: MonitorView = MonitorView.new()
	holder.add_child(monitor)
	await _frames(1)
	return monitor


## The real screen, its saves and log in a temporary folder.
func _screen() -> ShiftScreen:
	var runner: GdUnitSceneRunner = scene_runner("res://ui/shift_screen.tscn")
	var screen: ShiftScreen = runner.scene()
	await _frames(2)
	return screen


func _frames(count: int) -> void:
	for _frame: int in range(count):
		await get_tree().process_frame


static func _event_log() -> EventLogService:
	return (Engine.get_main_loop() as SceneTree).root.get_node("/root/EventLog")
