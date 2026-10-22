extends GdUnitTestSuite
## The monitor's store channel in planning (MonitorChannel; the user's play test of 2026-10-17).
## On the real screen: an empty belt shows the shift's brief (no PROJECTED €0 on the monitor; the
## projected total is on the top bar's QUOTA chip); a run with an inspection, upgrades and coupons
## cycles the brief, one slide per upgrade and the coupons in play (belt first), wiping each slide
## in (cut under reduced motion) with a page dot per slide; slide kinds with nothing to show are
## skipped; a state change keeps the slide shown; a scan takes the screen and the channel resumes
## on its slide; the count-up keeps it off the screen until the next shift's planning. Alone, every
## slide built from the longest real texts in data fits the monitor's screen, and the brief's
## sticker key (#71) shows its entries in order, fits its row and drops out when the brief needs
## the room. The channel's clock is the tests' (`_clock`, ticked explicitly); nothing waits in
## real time. The real saves and logs are never touched.

const SCREEN := "res://ui/shift_screen.tscn"
const CARDS := "res://data/cards"
const UPGRADES := "res://data/upgrades"
const INSPECTIONS := "res://data/inspections"
## Milk, Multipack, Milk x5 = 109: passes the first five quotas.
const PASSING_ROW: Array[String] = ["milk", "multipack", "milk", "milk", "milk", "milk", "milk"]

var _folder: String = ""
## The channel's clock and the scanner's (ms), and where the scanner sees the pointer.
var _clock: int = 0
var _point: Vector2 = Vector2.ZERO


func before_test() -> void:
	_folder = "user://test_channel_%d" % Time.get_ticks_usec()
	_event_log().use_folder(_folder)
	# The run and profile saves go there too, never to the real user:// saves.
	ProjectSettings.set_setting(SaveService.FOLDER_SETTING, _folder)
	_clock = 1000
	_point = Vector2(-100, -100)


func after_test() -> void:
	ProjectSettings.set_setting(SaveService.FOLDER_SETTING, null)
	if DirAccess.dir_exists_absolute(_folder):
		for file_name: String in DirAccess.get_files_at(_folder):
			DirAccess.remove_absolute(_folder.path_join(file_name))
		DirAccess.remove_absolute(_folder)


## The slide's length is data (data/balance/scan.tres), not the neutral 0.
func test_the_slide_length_is_tuned_in_data() -> void:
	var tuning: ScanTuning = load(ScanController.TUNING_PATH)
	assert_int(tuning.channel_slide_ms).is_greater(0)
	var screen: ShiftScreen = await _screen()
	assert_int(screen._monitor.channel.period_ms()).is_equal(tuning.channel_slide_ms)


## An empty belt on a shift with no inspection, no upgrade and no coupon in the hand: the brief
## alone (no dots, it never changes), "SHIFT 1/8", "QUOTA €N" and "No inspection this shift";
## nothing on the monitor says PROJECTED or €0, and the QUOTA chip shows the projected €0.
func test_an_empty_belt_shows_the_brief() -> void:
	var screen: ShiftScreen = await _screen()
	var run: RunState = screen.run
	_drop_coupons(run)
	screen._refresh()
	await _frames(2)
	var monitor: MonitorView = screen._monitor
	var channel: MonitorChannel = monitor.channel
	assert_int(run.row.size()).is_equal(0)
	assert_int(monitor.mode()).is_equal(MonitorView.Mode.CHANNEL)
	assert_bool(screen._led.visible).is_false()
	assert_array(Array(channel.slide_keys())).is_equal([MonitorChannel.BRIEF_KEY])
	var texts: PackedStringArray = _shown_texts(monitor)
	for expected: String in [
		MonitorChannel.SHIFT_WORD,
		MonitorChannel.SHIFT_TEXT % [1, run.shift_count()],
		MonitorChannel.QUOTA_WORD,
		MonitorChannel.QUOTA_TEXT % run.quota(),
		MonitorChannel.INSPECTION_KICKER,
		MonitorChannel.NO_INSPECTION_TEXT,
	]:
		assert_bool(texts.has(expected)).override_failure_message(expected).is_true()
	for absent: String in [LedDisplay.PROJECTED_TEXT, "€0"]:
		assert_bool(texts.has(absent)).override_failure_message(absent).is_false()
	assert_str(screen._quota_meter.amount_label.text).is_equal("€0")
	_clock += 3 * channel.period_ms()
	channel.tick()
	assert_int(channel.current_index()).is_equal(0)
	assert_int(channel.slide_count()).is_equal(1)


## A run with the Spot check, two upgrades and coupons (one on the belt, one in the hand): the
## brief (with the inspection's name and notice), each upgrade (its name, effect and condition)
## and the coupons in play, belt first, each with its sticker's effect; a slide moves on after a
## period, wiped in step by step, and the last wraps to the brief; under reduced motion it cuts.
## The QUOTA chip shows the preview's projected total all along.
func test_the_channel_cycles_through_its_slides() -> void:
	var screen: ShiftScreen = await _rich_screen()
	var run: RunState = screen.run
	var channel: MonitorChannel = screen._monitor.channel
	var keys: Array = ["brief", "upgrade:coupon_engine", "upgrade:slot_engine", "coupons:3"]
	assert_array(Array(channel.slide_keys())).is_equal(keys)
	var spot_check: InspectionDefinition = load(INSPECTIONS.path_join("spot_check.tres"))
	var brief: PackedStringArray = channel.slide_texts(0)
	assert_bool(brief.has(spot_check.display_name)).is_true()
	assert_bool(brief.has(spot_check.notice_text)).is_true()
	assert_bool(brief.has(MonitorChannel.NO_INSPECTION_TEXT)).is_false()
	for index: int in [1, 2]:
		var upgrade: UpgradeDefinition = run.upgrades[index - 1]
		var texts: PackedStringArray = channel.slide_texts(index)
		for expected: String in [upgrade.display_name, upgrade.effect_text, upgrade.condition_text]:
			assert_bool(texts.has(expected)).override_failure_message(expected).is_true()
	var coupons: PackedStringArray = channel.slide_texts(3)
	var on_belt: CardDefinition = load(CARDS.path_join("opening_deal.tres"))
	var in_hand: CardDefinition = load(CARDS.path_join("clearance_tag.tres"))
	assert_str(coupons[0]).is_equal(MonitorChannel.COUPONS_KICKER)
	assert_str(coupons[1]).is_equal(on_belt.display_name)
	assert_str(coupons[2]).is_equal(on_belt.sticker_summary())
	assert_bool(coupons.has(in_hand.display_name)).is_true()
	assert_bool(coupons.has(in_hand.sticker_summary())).is_true()
	assert_str(screen._quota_meter.amount_label.text).is_equal("€%d" % run.preview().total)
	# Cycling: each slide for a period, wiped in from the left.
	assert_int(channel.current_index()).is_equal(0)
	_clock += channel.period_ms() - 1
	channel.tick()
	assert_int(channel.current_index()).is_equal(0)
	_clock += 1
	channel.tick()
	assert_int(channel.current_index()).is_equal(1)
	assert_bool(channel.slide(1).visible).is_true()
	assert_bool(channel.slide(0).visible).is_false()
	assert_object(channel.wipe()).is_not_null()
	assert_float(channel.slide(1).size.x).is_less(channel.size.x)
	channel.wipe().custom_step(MonitorChannel.WIPE_S / 2.0)
	var halfway: float = channel.slide(1).size.x
	assert_float(fmod(halfway, MonitorChannel.WIPE_STEP)).is_equal(0.0)
	channel.wipe().custom_step(MonitorChannel.WIPE_S)
	assert_float(channel.slide(1).size.x).is_equal(channel.size.x)
	for expected: int in [2, 3, 0]:
		_clock += channel.period_ms()
		channel.tick()
		assert_int(channel.current_index()).is_equal(expected)
	# The dots: one per slide under the text, the shown one filled.
	for index: int in range(channel.slide_count()):
		var dot: Rect2 = channel.dot_rect(index)
		assert_bool(Rect2(Vector2.ZERO, channel.size).encloses(dot)).is_true()
		assert_float(dot.position.y).is_greater_equal(MonitorChannel.SLIDE_HEIGHT)
		if index > 0:
			assert_bool(dot.intersects(channel.dot_rect(index - 1))).is_false()
	# Reduced motion: a cut.
	screen.profile.set_reduced_motion(true)
	_clock += channel.period_ms()
	channel.tick()
	assert_int(channel.current_index()).is_equal(1)
	assert_object(channel.wipe()).is_null()
	assert_float(channel.slide(1).size.x).is_equal(channel.size.x)


## Slide kinds with nothing to show are skipped: coupons but no upgrade give the brief and the
## coupons; taking the coupon off the belt and out of the hand while its slide shows goes back to
## the brief. A change that keeps the slide shown (a product placed) stays on it, its time running
## on.
func test_empty_kinds_are_skipped_and_a_change_keeps_the_slide() -> void:
	var screen: ShiftScreen = await _screen()
	var run: RunState = screen.run
	var channel: MonitorChannel = screen._monitor.channel
	_drop_coupons(run)
	var coupon: CardInstance = run.debug_add_to_hand(load(CARDS.path_join("bundle.tres")))
	screen._refresh()
	await _frames(1)
	assert_array(Array(channel.slide_keys())).is_equal(["brief", "coupons:1"])
	_clock += channel.period_ms()
	channel.tick()
	assert_str(channel.current_key()).is_equal("coupons:1")
	# A product placed: the coupons' slide stays on, its time running on.
	_clock += roundi(channel.period_ms() / 2.0)
	var milk: CardInstance = run.debug_add_to_hand(load(CARDS.path_join("milk.tres")))
	assert_bool(run.place(milk, 0)).is_true()
	screen._refresh()
	assert_str(channel.current_key()).is_equal("coupons:1")
	_clock += roundi(channel.period_ms() / 2.0)
	channel.tick()
	assert_str(channel.current_key()).is_equal(MonitorChannel.BRIEF_KEY)
	_clock += channel.period_ms()
	channel.tick()
	assert_str(channel.current_key()).is_equal("coupons:1")
	# The coupon goes: back to the brief alone.
	_drop_from_hand(run, coupon)
	screen._refresh()
	assert_array(Array(channel.slide_keys())).is_equal([MonitorChannel.BRIEF_KEY])
	assert_int(channel.current_index()).is_equal(0)


## A held scan takes the screen and stops the channel's clock; when it ends the channel comes back
## on the slide it was on, for a full period.
func test_a_scan_takes_the_screen_and_the_channel_resumes() -> void:
	var screen: ShiftScreen = await _rich_screen()
	var monitor: MonitorView = screen._monitor
	var channel: MonitorChannel = monitor.channel
	screen.profile.set_reduced_motion(true)
	_clock += channel.period_ms()
	channel.tick()
	assert_int(channel.current_index()).is_equal(1)
	var view: ItemView = screen._row_views[0] as ItemView
	await _frames(1)
	_point = view.sprite().get_global_rect().get_center()
	view.hovered.emit(view)
	_clock += screen._scan.hold_ms()
	await _frames(2)
	assert_int(monitor.mode()).is_equal(MonitorView.Mode.SCAN)
	assert_bool(channel.visible).is_false()
	assert_bool(channel.is_running()).is_false()
	_clock += 3 * channel.period_ms()
	channel.tick()
	assert_int(channel.current_index()).is_equal(1)
	_point = Vector2(-100, -100)
	view.unhovered.emit(view)
	await _frames(2)
	assert_int(monitor.mode()).is_equal(MonitorView.Mode.CHANNEL)
	assert_int(channel.current_index()).is_equal(1)
	_clock += channel.period_ms() - 1
	channel.tick()
	assert_int(channel.current_index()).is_equal(1)
	_clock += 1
	channel.tick()
	assert_int(channel.current_index()).is_equal(2)


## The CHECKOUT click takes the channel off the screen: the count-up has the monitor (SUBTOTAL,
## then TOTAL beside the machine) and the channel neither shows nor runs. The next shift's
## planning blanks the LED and brings the channel back on the new shift's brief, even when CHECKOUT
## was clicked on an upgrade's slide (the upgrade still owned), the QUOTA chip on its projected
## total.
func test_the_channel_stays_out_of_the_count_up() -> void:
	var screen: ShiftScreen = await _screen()
	var monitor: MonitorView = screen._monitor
	var channel: MonitorChannel = monitor.channel
	screen._debug.give_upgrade("coupon_engine")
	await _place(screen, PASSING_ROW)
	assert_int(monitor.mode()).is_equal(MonitorView.Mode.CHANNEL)
	_clock += channel.period_ms()
	channel.tick()
	assert_str(channel.current_key()).is_equal("upgrade:coupon_engine")
	screen._on_checkout_pressed()
	await _frames(2)
	assert_int(monitor.mode()).is_equal(MonitorView.Mode.COUNT)
	assert_bool(channel.visible).is_false()
	assert_bool(channel.is_running()).is_false()
	screen._count_up._tap(Time.get_ticks_msec())
	screen._count_up._tap(Time.get_ticks_msec())
	while screen._counting:
		assert_bool(channel.visible).is_false()
		await get_tree().process_frame
	assert_bool(screen._machine.is_open()).is_true()
	assert_int(monitor.mode()).is_equal(MonitorView.Mode.COUNT)
	assert_str(screen._led.caption_label().text).is_equal(LedDisplay.TOTAL_TEXT)
	assert_bool(channel.visible).is_false()
	screen._machine.debug_skip()
	await _frames(2)
	assert_int(screen.run.shift_index).is_equal(1)
	assert_int(monitor.mode()).is_equal(MonitorView.Mode.CHANNEL)
	assert_int(screen._led.mode()).is_equal(LedDisplay.Mode.BLANK)
	assert_str(channel.current_key()).is_equal(MonitorChannel.BRIEF_KEY)
	var shift_text: String = MonitorChannel.SHIFT_TEXT % [2, screen.run.shift_count()]
	assert_bool(channel.slide_texts(0).has(shift_text)).is_true()
	(
		assert_bool(channel.slide_texts(0).has(MonitorChannel.QUOTA_TEXT % screen.run.quota()))
		. is_true()
	)
	var projected: String = "€%d" % screen.run.preview().total
	assert_str(screen._quota_meter.amount_label.text).is_equal(projected)
	var met: bool = screen.run.preview().total >= screen.run.quota()
	assert_bool(screen._quota_meter.flag_shown()).is_equal(met)


## As items are placed the quota chip follows the preview's projected total (core's ScoreResult)
## against the quota, its flag planted once the total reaches the quota (#86), while the monitor
## stays on its channel.
func test_the_quota_meter_shows_the_projected_total() -> void:
	var screen: ShiftScreen = await _screen()
	var run: RunState = screen.run
	var meter: QuotaMeter = screen._quota_meter
	for id: String in ["milk", "bread", "milk"]:
		var card: CardInstance = run.debug_add_to_hand(load(CARDS.path_join("%s.tres" % id)))
		assert_bool(run.place(card, run.row.size())).is_true()
		screen._refresh()
		var total: int = run.preview().total
		assert_str(meter.amount_label.text).is_equal("€%d" % total)
		assert_float(meter.fill()).is_equal_approx(
			QuotaMeter.fill_fraction(total, run.quota()), 0.0001
		)
		assert_bool(meter.flag_shown()).is_equal(total >= run.quota())
		assert_int(screen._monitor.mode()).is_equal(MonitorView.Mode.CHANNEL)


## Every slide built from data fits the monitor's screen: the brief with each inspection (and with
## none) at the widest shift and quota, every upgrade in data/upgrades and every coupon in
## data/cards in play. Each label lies inside the slide's text area (above the dots) and the
## screen's paper, whole (its text needs no more than its rect), apart from the others.
func test_every_slide_fits_the_screen() -> void:
	var monitor: MonitorView = await _monitor()
	var channel: MonitorChannel = monitor.channel
	var upgrades: Array[UpgradeDefinition] = []
	for path: String in _files(UPGRADES):
		upgrades.append(load(path) as UpgradeDefinition)
	var coupons: Array[CardDefinition] = []
	for path: String in _files(CARDS):
		var card: CardDefinition = load(path)
		if card.is_coupon():
			coupons.append(card)
	assert_int(upgrades.size()).is_greater(0)
	assert_int(coupons.size()).is_greater(0)
	var briefs: Array[Array] = [[]]
	for path: String in _files(INSPECTIONS):
		briefs.append([load(path) as InspectionDefinition])
	var paper: Rect2 = Rect2(
		ShiftStage.MONITOR_SCREEN_RECT.position + Vector2.ONE * MonitorView.OUTLINE,
		ShiftStage.MONITOR_SCREEN_RECT.size - Vector2.ONE * 2 * MonitorView.OUTLINE
	)
	for brief: Array in briefs:
		var inspections: Array[InspectionDefinition] = []
		inspections.assign(brief)
		monitor.channel.show_state(8, 8, 138, inspections, upgrades, coupons)
		await _frames(1)
		for index: int in range(channel.slide_count()):
			var area: Rect2 = Rect2(
				channel.get_global_position(), Vector2(channel.size.x, MonitorChannel.SLIDE_HEIGHT)
			)
			var labels: Array[Label] = channel.slide_labels(index)
			assert_int(labels.size()).is_greater(1)
			for label: Label in labels:
				var rect: Rect2 = label.get_global_rect()
				var where: String = "%s %s: %s" % [channel.slide_keys()[index], label.text, rect]
				assert_bool(area.encloses(rect)).override_failure_message(where).is_true()
				assert_bool(paper.encloses(rect)).override_failure_message(where).is_true()
				var needed: Vector2 = label.get_minimum_size()
				(
					assert_bool(needed.x <= rect.size.x + 0.5 and needed.y <= rect.size.y + 0.5)
					. override_failure_message("%s needs %s" % [where, needed])
					. is_true()
				)
				for other: Label in labels:
					if other != label:
						(
							assert_bool(rect.intersects(other.get_global_rect()))
							. override_failure_message("%s overlaps %s" % [where, other.text])
							. is_false()
						)
		prints("#80 channel slides:", channel.slide_keys())
	# Every upgrade has its slide, and every coupon a row.
	var keys: PackedStringArray = channel.slide_keys()
	for upgrade: UpgradeDefinition in upgrades:
		assert_bool(keys.has("upgrade:%s" % upgrade.id)).is_true()
	var shown: PackedStringArray = PackedStringArray()
	for index: int in range(channel.slide_count()):
		shown.append_array(channel.slide_texts(index))
	for coupon: CardDefinition in coupons:
		assert_bool(shown.has(coupon.display_name)).override_failure_message(coupon.id).is_true()


## The brief's sticker key (#71, H1_BUILD_SPEC.md section 7): pinned to the slide's bottom under
## its dashed rule, each entry a real sticker (its badge included) and its caption, in order,
## skipping one that doesn't fit the width left, with the brief's text over it; a state change
## keeps it; a brief too tall to leave it room drops it (and is built at full height); an empty key
## takes it off.
func test_the_brief_keys_the_stickers() -> void:
	var monitor: MonitorView = await _monitor()
	var channel: MonitorChannel = monitor.channel
	var none: Array[InspectionDefinition] = []
	var no_upgrades: Array[UpgradeDefinition] = []
	var no_coupons: Array[CardDefinition] = []
	channel.show_state(1, 8, 30, none, no_upgrades, no_coupons)
	await _frames(1)
	assert_object(channel.key_row()).is_null()
	var entries: Array[StickerSpec] = [
		_entry(StickerSpec.Kind.ADD, "+3", GiverBadge.Kind.NONE, ""),
		_entry(StickerSpec.Kind.MULTIPLY, "×3", GiverBadge.Kind.ITEM, "Eg"),
		_entry(StickerSpec.Kind.MULTIPLY, "×3", GiverBadge.Kind.COUPON, "Mu"),
		_entry(StickerSpec.Kind.ADD, "+12", GiverBadge.Kind.LOYALTY, "SlE"),
		_entry(StickerSpec.Kind.FIZZLE, "pfff", GiverBadge.Kind.NONE, ""),
	]
	var expected: PackedStringArray = PackedStringArray()
	for entry: StickerSpec in entries:
		expected.append(MonitorChannel.KEY_TEXT % [entry.text, PlanningModel.key_caption(entry)])
	assert_str(expected[0]).is_equal("+3 own rule")
	monitor.set_planning_key(entries)
	await _frames(1)
	_assert_key(channel, expected)
	# The coupon's entry doesn't fit after the first two and is skipped; the narrower loyalty one
	# still fits (as in h1), and the fizzle's no longer does.
	assert_array(Array(channel.key_texts())).is_equal([expected[0], expected[1], expected[3]])
	# A state change keeps the key.
	channel.show_state(2, 8, 45, none, no_upgrades, no_coupons)
	await _frames(1)
	_assert_key(channel, expected)
	# Every inspection on one brief leaves no room for the key: the brief is built without it.
	var crowded: Array[InspectionDefinition] = []
	for path: String in _files(INSPECTIONS):
		crowded.append(load(path) as InspectionDefinition)
	channel.show_state(2, 8, 45, crowded, no_upgrades, no_coupons)
	await _frames(1)
	assert_object(channel.key_row()).is_null()
	assert_array(Array(channel.key_texts())).is_empty()
	# Back to room, then an empty key takes it off.
	channel.show_state(3, 8, 60, none, no_upgrades, no_coupons)
	await _frames(1)
	_assert_key(channel, expected)
	var no_key: Array[StickerSpec] = []
	monitor.set_planning_key(no_key)
	await _frames(1)
	assert_object(channel.key_row()).is_null()
	assert_array(Array(channel.key_texts())).is_empty()


## The brief shows a key whose texts are `expected` in order with some skipped (its first entry
## always shown), inside the slide under the brief's labels, with every sticker and caption inside
## its row.
func _assert_key(channel: MonitorChannel, expected: PackedStringArray) -> void:
	var texts: PackedStringArray = channel.key_texts()
	assert_int(texts.size()).is_greater(0)
	assert_str(texts[0]).is_equal(expected[0])
	assert_bool(_in_order(texts, expected)).override_failure_message(str(texts)).is_true()
	var row: Control = channel.key_row()
	assert_object(row).is_not_null()
	var brief: int = Array(channel.slide_keys()).find(MonitorChannel.BRIEF_KEY)
	var area: Rect2 = Rect2(
		channel.get_global_position(), Vector2(channel.size.x, MonitorChannel.SLIDE_HEIGHT)
	)
	var row_rect: Rect2 = row.get_global_rect()
	assert_bool(area.encloses(row_rect)).override_failure_message(str(row_rect)).is_true()
	assert_float(row_rect.size.y).is_equal(MonitorChannel.KEY_HEIGHT)
	for label: Label in channel.slide_labels(brief):
		assert_float(label.get_global_rect().end.y).is_less_equal(row_rect.position.y)
	var stickers: int = 0
	for child: Node in row.get_children():
		var part: Control = child as Control
		var rect: Rect2 = part.get_global_rect()
		if part is EffectSticker:
			stickers += 1
			var badge: GiverBadge = (part as EffectSticker).badge()
			if badge != null:
				rect = rect.merge(badge.get_global_rect())
		(
			assert_bool(row_rect.grow(0.5).encloses(rect))
			. override_failure_message("%s %s" % [part.name, rect])
			. is_true()
		)
	assert_int(stickers).is_equal(texts.size())


static func _entry(
	kind: StickerSpec.Kind, text: String, badge: GiverBadge.Kind, initials: String
) -> StickerSpec:
	var entry: StickerSpec = StickerSpec.new()
	entry.kind = kind
	entry.text = text
	entry.badge = badge
	entry.badge_text = initials
	return entry


## The screen on shift 1, the channel and the scanner on the tests' clock.
func _screen() -> ShiftScreen:
	var runner: GdUnitSceneRunner = scene_runner(SCREEN)
	var screen: ShiftScreen = runner.scene()
	screen._scan.pointer = func() -> Vector2: return _point
	screen._scan.now_ms = func() -> int: return _clock
	var channel: MonitorChannel = screen._monitor.channel
	channel.now_ms = func() -> int: return _clock
	# Started again on the tests' clock.
	channel.set_running(false)
	channel.set_running(true)
	await _frames(3)
	return screen


## Shift 1 with the Spot check, Coupon engine and Slot engine, Opening deal and Milk on the belt
## and a Clearance tag in the hand (no other coupon).
func _rich_screen() -> ShiftScreen:
	var screen: ShiftScreen = await _screen()
	screen._debug.set_inspection("spot_check")
	screen._debug.give_upgrade("coupon_engine")
	screen._debug.give_upgrade("slot_engine")
	var run: RunState = screen.run
	_drop_coupons(run)
	for id: String in ["opening_deal", "milk"]:
		var card: CardInstance = run.debug_add_to_hand(load(CARDS.path_join("%s.tres" % id)))
		assert_bool(run.place(card, run.row.size())).override_failure_message(id).is_true()
	run.debug_add_to_hand(load(CARDS.path_join("clearance_tag.tres")))
	screen._refresh()
	await _frames(2)
	assert_str(screen._monitor.channel.current_key()).is_equal(MonitorChannel.BRIEF_KEY)
	return screen


## Puts copies of cards into the row, in order, and refreshes the screen.
func _place(screen: ShiftScreen, card_ids: Array[String]) -> void:
	var run: RunState = screen.run
	for card_id: String in card_ids:
		var card: CardInstance = run.debug_add_to_hand(load(CARDS.path_join("%s.tres" % card_id)))
		assert_bool(run.place(card, run.row.size())).override_failure_message(card_id).is_true()
	screen._refresh()
	await _frames(2)


## Takes every coupon out of the hand (the starter hand may hold Final markdown).
static func _drop_coupons(run: RunState) -> void:
	for card: CardInstance in run.hand():
		if card.definition.is_coupon():
			_drop_from_hand(run, card)


## Takes `card` out of this shift's hand (the deck keeps it).
static func _drop_from_hand(run: RunState, card: CardInstance) -> void:
	var hand: Array[CardInstance] = run.deck.hand()
	hand.erase(card)
	run.deck.restore(run.deck.cards, hand, run.deck.draw_pile(), run.deck.next_instance_id())


## A monitor alone at its stage place, in the tree.
func _monitor() -> MonitorView:
	var holder: Control = auto_free(Control.new())
	get_tree().root.add_child(holder)
	var monitor: MonitorView = MonitorView.new()
	holder.add_child(monitor)
	await _frames(1)
	return monitor


static func _shown_texts(monitor: MonitorView) -> PackedStringArray:
	var texts: PackedStringArray = PackedStringArray()
	for label: Label in monitor.shown_labels():
		texts.append(label.text)
	return texts


static func _files(folder: String) -> Array[String]:
	var paths: Array[String] = []
	for file_name: String in DirAccess.get_files_at(folder):
		if file_name.ends_with(".tres"):
			paths.append(folder.path_join(file_name))
	return paths


func _frames(count: int) -> void:
	for _frame: int in range(count):
		await get_tree().process_frame


static func _event_log() -> EventLogService:
	return (Engine.get_main_loop() as SceneTree).root.get_node("/root/EventLog")


## Whether every text of `shown` is in `all`, in the same order (a subsequence).
static func _in_order(shown: PackedStringArray, all: PackedStringArray) -> bool:
	var at: int = 0
	for text: String in shown:
		at = all.find(text, at)
		if at < 0:
			return false
		at += 1
	return true
