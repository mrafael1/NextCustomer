extends GdUnitTestSuite
## The scanner bay on the monitor (#86 v6 scan count-up, round 7's ALIVE and QUEUE; #105 piece 2:
## ScannerBay with BayBed, BayQueue and its FamilyChip): its geometry on the monitor (at BAY_RECT,
## its header's queue, bed, art and family chip inside it, all on the paper, apart from the item
## column); the queue's text and pips; the item's pose (drop, land, wobble, slide-out); the scan's
## laser fan, BEEP and flash; a ride's slide-out and drop-in with the chip following the item;
## reduced motion keeping the states; the motion on the count-up's tweens; a resumed checkout's
## ALL PAID end state; and every card's chip naming what the item works with, fitting its face.
## The bay's price and lines went to the item column (MonitorItemColumn, monitor_layout_test).

const CARDS := "res://data/cards"
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


## On the monitor the bay stands at BAY_RECT, on the paper (its shadow too), in every mode, and its
## parts inside it: the queue over the header (the light in it), the bed at BED_RECT with the art
## over its inside (96x96), the family chip under the bed at CHIP_AT; the bay apart from the item
## column and the checkout column.
func test_the_bay_sits_on_the_paper() -> void:
	var monitor: MonitorView = await _monitor()
	var bay: ScannerBay = monitor.bay()
	monitor.reduced_motion = func() -> bool: return true
	assert_bool(bay.is_visible_in_tree()).is_true()
	monitor.led.start_count(34)
	await _frames(1)
	assert_bool(bay.is_visible_in_tree()).is_true()
	var rect: Rect2 = bay.get_global_rect()
	assert_that(rect).is_equal(MonitorView.BAY_RECT)
	assert_vector(rect.size).is_equal(ScannerBay.SIZE)
	var paper: Rect2 = MonitorView.PAPER_RECT
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
	var chip: Rect2 = bay.chip().get_global_rect()
	assert_that(chip).is_equal(Rect2(rect.position + ScannerBay.CHIP_AT, FamilyChip.SIZE))
	for part: Rect2 in [header, bed, chip]:
		(
			assert_bool(rect.grow(-ScannerBay.BORDER).encloses(part))
			. override_failure_message(str(part))
			. is_true()
		)
	assert_bool(header.encloses(light)).is_true()
	assert_bool(header.intersects(bed)).is_false()
	assert_bool(bed.intersects(chip)).is_false()
	assert_bool(rect.intersects(MonitorView.ITEM_RECT)).is_false()
	assert_bool(rect.intersects(MonitorView.CHECKOUT_RECT)).is_false()
	# Outside the count the bay stays, planning's again.
	monitor.led.clear()
	await _frames(1)
	assert_bool(bay.is_visible_in_tree()).is_true()
	assert_bool(bay.is_planning()).is_true()


## The queue: "SCANNER" with no pips outside a count; start(5) reads "5 LEFT" with five teal
## pips; each ride in counts down ("4 LEFT" … "LAST"), the item in the bay tomato light (green
## light once met), the bagged ones gold; after the last ride DONE, every pip gold, THANK YOU on
## the chip and ALL PAID on the bed.
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
	assert_str(bay.chip().chip_text()).is_equal(ScannerBay.END_NAME)
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


## A ride: the item in the bay slides out over OUT_SHARE of it, the bed empty with GONE_NAME on the
## chip, then the next drops in and lands as the belt brings it, its chip naming it; its pip and
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
	assert_str(bay.chip().chip_text()).is_equal(FamilyChip.item_text(milk))
	bay.follow_beat(_beat(CountUpBeat.Kind.MERGED_PLAIN, 0, 0, true), _step(3), milk)
	_advance(1.0)
	var old: TextureRect = bed.art()
	bay.ride(0, 1, bread, 0.3)
	var out_s: float = 0.3 * ScannerBay.OUT_SHARE
	assert_bool(bed.is_leaving()).is_true()
	_advance(out_s / 2.0)
	await _frames(1)
	assert_float(old.position.x).is_less(0.0)
	assert_float(old.modulate.a).is_less(1.0)
	_advance(out_s / 2.0 + STEP / 2.0)
	assert_object(bed.art()).is_null()
	assert_str(bay.chip().chip_text()).is_equal(ScannerBay.GONE_NAME)
	assert_str(bay.queue().text()).is_equal("1 LEFT")
	_advance(0.3 - out_s - BayBed.FALL_S / 2.0)
	assert_object(bed.art()).is_not_null()
	assert_str(bay.chip().chip_text()).is_equal(FamilyChip.item_text(bread))
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
	assert_str(bay.chip().chip_text()).is_equal(ScannerBay.END_NAME)
	assert_bool(bed.idle_label().visible).is_true()
	assert_str(bed.idle_label().text).is_equal(BayBed.END_TEXT)


## Reduced motion keeps the states: the item shows at its opening beat, at rest; the fan stands at
## its middle for FAN_S, the BEEP shows unpopped, no flash; a later landing doesn't wobble it; a
## ride takes the item out at once.
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
	var bonus: ScoreStep = _step(2, ScoreStep.StepType.FLAT)
	bonus.value_after = 5
	var landing: CountUpBeat = _beat(CountUpBeat.Kind.BONUS, 1)
	landing.land = CountUpBeat.Land.ADD
	bay.follow_beat(landing, bonus, milk)
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
	assert_str(bay.chip().chip_text()).is_equal(ScannerBay.GONE_NAME)
	_advance(0.3)
	assert_object(bed.art()).is_null()


## On the real screen the bay's motion runs on the count-up's tweens (it follows taps, holds and
## hit-stops), as the item column's, the checkout column's and the chips' do.
func test_the_bay_runs_on_the_count_ups_tweens() -> void:
	var screen: ShiftScreen = await _screen()
	var maker: Callable = screen._count_up.tween_maker()
	var monitor: MonitorView = screen._monitor
	assert_bool(monitor.bay().make_tween == maker).is_true()
	assert_bool(monitor.item_column().make_tween == maker).is_true()
	assert_bool(monitor.checkout().make_tween == maker).is_true()
	assert_bool(monitor.chips().make_tween == maker).is_true()


## A resumed checkout's end state: every item paid and bagged (no art; ALL PAID, THANK YOU, DONE
## with every pip gold), met or not, nothing moving.
func test_the_end_state_reads_all_paid() -> void:
	var monitor: MonitorView = await _monitor()
	var bay: ScannerBay = monitor.bay()
	monitor.led.start_count(34)
	var milk: CardDefinition = _card("milk")
	bay.follow_beat(_beat(CountUpBeat.Kind.MERGED_PLAIN, 0, 0, true), _step(3), milk)
	bay.show_end_state(5, true)
	assert_object(bay.bed().art()).is_null()
	assert_bool(bay.bed().idle_label().visible).is_true()
	assert_str(bay.bed().idle_label().text).is_equal(BayBed.END_TEXT)
	assert_str(bay.chip().chip_text()).is_equal(ScannerBay.END_NAME)
	assert_str(bay.queue().text()).is_equal(BayQueue.DONE_TEXT)
	assert_array(bay.queue().pip_colours()).is_equal(_colours(5, BayQueue.BAGGED_COLOR))
	assert_bool(bay.is_met()).is_true()
	assert_that(bay.light_colour()).is_equal(ScannerBay.LIGHT_MET_COLOR)
	assert_bool(is_nan(bay.bed().fan_angle())).is_true()
	bay.show_end_state(3, false)
	assert_bool(bay.is_met()).is_false()
	assert_str(bay.queue().text()).is_equal(BayQueue.DONE_TEXT)
	assert_int(bay.queue().pip_rects().size()).is_equal(3)


## Every card's chip (#105 piece 2) names what the item works with (FamilyChip.item_text: a
## family, a card, the item itself, both halves of a split ticket, or COUPON), in its ticket's
## colour, on one line inside the chip's text room without being cut; so do THANK YOU and the dash
## between items, which the chip's font has glyphs for.
func test_every_chip_fits() -> void:
	var monitor: MonitorView = await _monitor()
	monitor.reduced_motion = func() -> bool: return true
	var bay: ScannerBay = monitor.bay()
	monitor.led.start_count(34)
	var chip: FamilyChip = bay.chip()
	var slot: int = 0
	var splits: int = 0
	for definition: CardDefinition in _cards():
		var opening: CountUpBeat = _beat(CountUpBeat.Kind.BASE, slot, slot, true)
		bay.follow_beat(opening, _step(1, ScoreStep.StepType.BASE, slot), definition)
		slot += 1
		var message: String = String(definition.id)
		assert_str(chip.chip_text()).override_failure_message(message).is_equal(
			FamilyChip.item_text(definition)
		)
		if chip.chip_text().contains(" + "):
			splits += 1
		_assert_chip_fits(chip, message)
		assert_str(chip.tip_text).override_failure_message(message).is_not_empty()
	prints("#105 split tickets' chips:", splits)
	bay.ride(slot - 1, -1, null, 0.0)
	assert_str(chip.chip_text()).is_equal(ScannerBay.END_NAME)
	_assert_chip_fits(chip, ScannerBay.END_NAME)
	var font: Font = chip.text_label().get_theme_font("font")
	assert_bool(font.has_char(ScannerBay.GONE_NAME.unicode_at(0))).is_true()


## `chip`'s text fits its label on one line (no ellipsis) inside the chip.
func _assert_chip_fits(chip: FamilyChip, message: String) -> void:
	var label: Label = chip.text_label()
	var width: float = _label_width(label)
	(
		assert_float(width)
		. override_failure_message(
			"%s: %s %.1f in %.1f" % [message, label.text, width, label.size.x]
		)
		. is_less_equal(label.size.x)
	)
	var rect: Rect2 = Rect2(label.position, label.size)
	assert_bool(Rect2(Vector2.ZERO, chip.size).encloses(rect)).is_true()
	if chip.glyph_sprite().visible:
		var glyph: Rect2 = Rect2(chip.glyph_sprite().position, chip.glyph_sprite().size)
		assert_bool(glyph.intersects(rect)).override_failure_message(message).is_false()


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


## The bay's count tweens made paused, for _advance to step.
func _manual(monitor: MonitorView) -> void:
	monitor.bay().make_tween = func() -> Tween:
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
