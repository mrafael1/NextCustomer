extends GdUnitTestSuite
## The planning layer's geometry on the real shift screen at 1280x720 (#71, mock-up h1,
## H1_BUILD_SPEC.md section 13) for 7 and 8 slots and with a CLOSED cell, on the reference row
## and on a stress row with 6 or more stickers on one item and overlapping rail strips: no
## sticker, stamp, pay tag or strip part covers any ticket's struck price or summary text (a pay
## tag sits on its ticket's top band only); every stack stands on STACK_BOTTOM_Y or higher and
## under its ceiling (the hung monitor's foot over its x-range, else the top bar's); every strip's
## body lies
## in its lane's band and the belt's x-range, its notches, plate, plug, stem and cap in the lip
## band, a notch (lane 0) or a drop (lane 1) on each target's ticket and no factor badge on any
## strip, calm or hot (the factor is the target's sticker only, since the h1 build's play test),
## its lit gaps off every ticket, and no two strips of one lane meet; hovered, the hot strips' gain
## badges stand on their targets, inside the lip band and the screen, none on another; every part
## lies on the screen; and nothing is drawn over a CLOSED cell's sign and plate or an empty
## slot's mat and ticket. The real saves and logs are never touched.

const SCREEN := "res://ui/shift_screen.tscn"
const SCREEN_RECT := Rect2(0, 0, 1280, 720)
## #60's reference row (planning_effects_test): Eggs' ×2, a denied Milk, Multipack's ×3, a
## fizzle and Slot engine's stamp.
const REFERENCE_ROW: Array[String] = ["eggs", "bread", "milk", "multipack", "milk", "milk", "milk"]
const REFERENCE_UPGRADES: Array[String] = ["coupon_engine", "slot_engine"]
## Squashed cake, the last product, takes Flickering bulb's +3, Multipack's ×3, Birthday candles'
## +3, Eggs' ×2, Tea bags' ×4 (with the Breakfast tag) and Category engine's bonus. The 8 cards
## need Big basket's 8th slot (v0.56: 7 general slots; Extra coupon slot, which gave it before,
## was removed).
const STRESS_ROW: Array[String] = [
	"bread",
	"flickering_bulb",
	"multipack",
	"birthday_candles",
	"eggs",
	"tea_bags",
	"breakfast_sticker",
	"squashed_cake",
]
const STRESS_UPGRADES: Array[String] = ["big_basket", "category_engine"]
const STRESS_STICKERS := 6
const TOLERANCE := 0.01

var _folder: String = ""
var _window_size: Vector2i


func before_test() -> void:
	_folder = "user://test_logs_%d" % Time.get_ticks_usec()
	_event_log().use_folder(_folder)
	# The run and profile saves go there too, never to the real user:// saves.
	ProjectSettings.set_setting(SaveService.FOLDER_SETTING, _folder)
	_window_size = get_tree().root.size
	get_tree().root.size = Vector2i(SCREEN_RECT.size)


func after_test() -> void:
	get_tree().root.size = _window_size
	ProjectSettings.set_setting(SaveService.FOLDER_SETTING, null)
	if DirAccess.dir_exists_absolute(_folder):
		for file_name: String in DirAccess.get_files_at(_folder):
			DirAccess.remove_absolute(_folder.path_join(file_name))
		DirAccess.remove_absolute(_folder)


## 7 slots: the reference row.
func test_the_reference_row_on_7_slots() -> void:
	var screen: ShiftScreen = await _shift(REFERENCE_UPGRADES, "spot_check", REFERENCE_ROW)
	assert_int(screen._row_strip.slots.size()).is_equal(7)
	assert_int(_layer(screen).parts().size()).is_greater(0)
	_assert_laid_out(screen, "7 slots")
	await _assert_hot(screen, "7 slots")


## 8 slots (Big basket): the reference row and Bread after it.
func test_the_reference_row_on_8_slots() -> void:
	var upgrades: Array[String] = REFERENCE_UPGRADES.duplicate()
	upgrades.append("big_basket")
	var row: Array[String] = REFERENCE_ROW.duplicate()
	row.append("bread")
	var screen: ShiftScreen = await _shift(upgrades, "spot_check", row)
	assert_int(screen._row_strip.slots.size()).is_equal(8)
	_assert_laid_out(screen, "8 slots")
	await _assert_hot(screen, "8 slots")


## 8 slots (Big basket): the stress row, its tall stack squeezed or folded under the monitor.
func test_the_stress_row_on_8_slots() -> void:
	var screen: ShiftScreen = await _shift(STRESS_UPGRADES, "", STRESS_ROW)
	assert_int(screen._row_strip.slots.size()).is_equal(8)
	_assert_stressed(screen)
	_assert_laid_out(screen, "stress, 8 slots")
	var covers: int = await _assert_hot(screen, "stress, 8 slots")
	# Some lane-1 gain stands over the hovered giver's own hot ring here (drawn over it).
	assert_int(covers).is_greater(0)


## Hovering Squashed cake on the stress row, which five belt givers give to: only two of their
## strips turn hot, one per lane (the largest gain to it in lane 0, as it has no strip of its own),
## each showing only its gain to Squashed cake; the other three stay calm and dim, never drawn on
## top of the hot two.
func test_a_target_of_many_givers_shows_two_hot_strips() -> void:
	var screen: ShiftScreen = await _shift(STRESS_UPGRADES, "", STRESS_ROW)
	var cake: int = STRESS_ROW.find("squashed_cake")
	var model: PlanningModel = screen._effects.committed_model()
	var givers: Array[RailStripSpec] = []
	for spec: RailStripSpec in model.strips:
		if spec.targets.has(cake):
			givers.append(spec)
	assert_int(givers.size()).is_greater_equal(3)
	screen._effects.pointer = func() -> Vector2: return Vector2(-500, -500)
	var item: ItemView = screen._row_views[cake] as ItemView
	item.hovered.emit(item)
	await _frames(1)
	var layer: PlanningLayer = _layer(screen)
	var hot: Array[RailStrip] = layer.hot_strips()
	assert_int(hot.size()).is_equal(2)
	assert_float(hot[0].body_rect().position.y).is_equal(RailStrip.LANE_RECTS[0].position.y)
	assert_float(hot[1].body_rect().position.y).is_equal(RailStrip.LANE_RECTS[1].position.y)
	var best: int = 0
	for spec: RailStripSpec in givers:
		best = maxi(best, spec.gains[spec.targets.find(cake)])
	var lane0: RailStripSpec = hot[0].spec()
	assert_int(lane0.gains[lane0.targets.find(cake)]).is_equal(best)
	for strip: RailStrip in hot:
		assert_int(strip.gain_texts().size()).is_less_equal(1)
	var hot_givers: Array[int] = [hot[0].spec().giver_slot, hot[1].spec().giver_slot]
	for strip: RailStrip in layer.strips():
		var drawn_hot: bool = hot_givers.has(strip.spec().giver_slot)
		assert_bool(strip.visible).is_equal(not drawn_hot)
		assert_bool(strip.is_dimmed()).is_equal(not drawn_hot)
	screen._effects.unfocus()


## Eggs gives its ×2 to Bread over Batteries (not Food): its lane-0 strip lights both ticket gaps
## it spans, the two beside Batteries too, calm and hot.
func test_a_strip_lights_every_gap_it_spans() -> void:
	var screen: ShiftScreen = await _shift([], "", ["eggs", "batteries", "bread"])
	var layer: PlanningLayer = _layer(screen)
	var strips: Array[RailStrip] = layer.strips()
	assert_int(strips.size()).is_equal(1)
	assert_array(Array(strips[0].spec().targets)).is_equal([2])
	assert_int(strips[0].spec().lane).is_equal(0)
	assert_int(strips[0].gap_rects().size()).is_equal(2)
	for fill: Control in strips[0].fills():
		assert_bool(fill.visible).is_true()
	_assert_laid_out(screen, "skipped item")
	screen._effects.pointer = func() -> Vector2: return Vector2(-500, -500)
	var eggs: ItemView = screen._row_views[0] as ItemView
	eggs.hovered.emit(eggs)
	await _frames(1)
	var hot: Array[RailStrip] = layer.hot_strips()
	assert_int(hot.size()).is_equal(1)
	assert_int(hot[0].gap_rects().size()).is_equal(2)
	screen._effects.unfocus()


## Short belt: a CLOSED cell after the open slots, and the last open slot left empty.
func test_a_closed_cell_and_an_empty_slot_stay_clear() -> void:
	var row: Array[String] = ["eggs", "bread", "multipack", "milk", "milk"]
	var screen: ShiftScreen = await _shift(REFERENCE_UPGRADES, "short_belt", row)
	assert_int(screen._row_strip.closed.size()).is_equal(1)
	assert_int(screen.run.row.size()).is_less(screen._row_strip.slots.size())
	assert_int(_layer(screen).parts().size()).is_greater(0)
	assert_int(_keep_clear(screen).size()).is_greater(1)
	_assert_laid_out(screen, "CLOSED")
	await _assert_hot(screen, "CLOSED")


## One item wears STRESS_STICKERS or more stickers in the model, and its stack still fits; its
## givers' strips overlap, so both lanes are drawn.
func _assert_stressed(screen: ShiftScreen) -> void:
	var model: PlanningModel = screen._effects.committed_model()
	var most: int = 0
	for planning: PlanningSlot in model.slots:
		most = maxi(most, planning.stickers.size())
	assert_int(most).is_greater_equal(STRESS_STICKERS)
	var lanes: Array[int] = []
	for strip: RailStrip in _layer(screen).strips():
		if not lanes.has(strip.spec().lane):
			lanes.append(strip.spec().lane)
	lanes.sort()
	assert_array(lanes).is_equal([0, 1])


func _assert_laid_out(screen: ShiftScreen, case: String) -> void:
	var layer: PlanningLayer = _layer(screen)
	var to_layer: Transform2D = layer.get_global_transform().affine_inverse()
	var texts: Array[Rect2] = []
	for view: CardView in screen._row_views:
		var ticket: PriceSticker = (view as ItemView).sticker()
		var to_global: Transform2D = ticket.get_global_transform()
		if ticket.is_struck():
			texts.append(to_global * ticket.struck_rect())
		if ticket.summary_text_rect().has_area():
			texts.append(to_global * ticket.summary_text_rect())
	var clear: Array[Rect2] = _keep_clear(screen)
	_assert_strips(screen, case)
	_assert_no_factor_badges(layer, case)
	for part: Control in layer.parts():
		var rect: Rect2 = part.get_global_rect()
		var message: String = "%s: %s %s" % [case, part.name, rect]
		assert_bool(SCREEN_RECT.encloses(rect)).override_failure_message(message).is_true()
		for text: Rect2 in texts:
			(
				assert_bool(rect.intersects(text))
				. override_failure_message("%s over text %s" % [message, text])
				. is_false()
			)
		for cell: Rect2 in clear:
			(
				assert_bool(rect.intersects(cell))
				. override_failure_message("%s over cell %s" % [message, cell])
				. is_false()
			)
	for slot: int in range(screen._row_views.size()):
		var stickers: Array[EffectSticker] = layer.stack(slot)
		if stickers.is_empty():
			continue
		var span: Rect2 = to_layer * stickers[0].get_global_rect()
		for sticker: EffectSticker in stickers:
			span = span.merge(to_layer * sticker.get_global_rect())
		var message: String = "%s: slot %d stack %s" % [case, slot, span]
		assert_float(span.end.y).override_failure_message(message).is_less_equal(
			PlanningLayer.STACK_BOTTOM_Y + TOLERANCE
		)
		assert_float(span.position.y).override_failure_message(message).is_greater_equal(
			PlanningLayer.stack_ceiling(span) - TOLERANCE
		)
	# No part for a slot with no item.
	for slot: int in range(screen._row_views.size(), screen._row_strip.slots.size()):
		assert_array(layer.stack(slot)).is_empty()
		assert_object(layer.pay_tag(slot)).is_null()
		assert_object(layer.stamp(slot)).is_null()


## Each strip's body in its lane's band and the belt's x-range, its lip parts in the lip band, a
## notch (lane 0) or a drop (lane 1) on each target's ticket, no gain badge while calm, its lit
## gaps off every ticket, and no two strips of one lane overlapping in x.
func _assert_strips(screen: ShiftScreen, case: String) -> void:
	var layer: PlanningLayer = _layer(screen)
	var tickets: Array[Rect2] = []
	var to_layer: Transform2D = layer.get_global_transform().affine_inverse()
	for view: CardView in screen._row_views:
		var ticket: PriceSticker = (view as ItemView).sticker()
		tickets.append(to_layer * ticket.get_global_rect())
	var belt: Rect2 = RailStrip.LIP_BAND
	var spans: Array[Array] = [[], []]
	for strip: RailStrip in layer.strips():
		var lane: int = strip.spec().lane
		var band: Rect2 = RailStrip.LANE_RECTS[lane]
		var body: Rect2 = strip.body_rect()
		var message: String = (
			"%s: strip %d lane %d body %s" % [case, strip.spec().giver_slot, lane, body]
		)
		assert_float(body.position.y).override_failure_message(message).is_greater_equal(
			band.position.y - TOLERANCE
		)
		assert_float(body.end.y).override_failure_message(message).is_less_equal(
			band.end.y + TOLERANCE
		)
		assert_float(body.position.x).override_failure_message(message).is_greater_equal(
			belt.position.x - TOLERANCE
		)
		assert_float(body.end.x).override_failure_message(message).is_less_equal(
			belt.end.x + TOLERANCE
		)
		for piece: Rect2 in strip.lip_rects():
			(
				assert_bool(belt.grow(TOLERANCE).encloses(piece))
				. override_failure_message("%s piece %s" % [message, piece])
				. is_true()
			)
		assert_array(strip.gains()).override_failure_message(message).is_empty()
		# Each target still shows: lane 0's notch, or lane 1's drop, over its ticket.
		var targets: PackedInt32Array = strip.spec().targets
		var marks: Array[Rect2] = strip.lip_rects().slice(3)
		if lane == 1:
			marks = strip.drop_rects().slice(1)
		assert_int(marks.size()).override_failure_message(message).is_equal(targets.size())
		for index: int in range(mini(marks.size(), targets.size())):
			var ticket: Rect2 = tickets[targets[index]]
			var mark: Rect2 = marks[index]
			var over: bool = (
				mark.position.x >= ticket.position.x - TOLERANCE
				and mark.end.x <= ticket.end.x + TOLERANCE
			)
			(
				assert_bool(over)
				. override_failure_message("%s target %s on %s" % [message, mark, ticket])
				. is_true()
			)
		# The stem and drops reach from the lip band down to their (maybe lower) tickets.
		for drop: Rect2 in strip.drop_rects():
			var inside: bool = (
				drop.position.y >= belt.position.y - TOLERANCE
				and drop.position.x >= belt.position.x - TOLERANCE
				and drop.end.x <= belt.end.x + TOLERANCE
			)
			assert_bool(inside).override_failure_message("%s drop %s" % [message, drop]).is_true()
		# Lane 0 lights every ticket gap of its span wide enough, over unrelated items too.
		var wide: int = 0
		for slot: int in range(strip.spec().lo(), strip.spec().hi()):
			if tickets[slot + 1].position.x - tickets[slot].end.x >= RailStrip.GAP_WIDTH:
				wide += 1
		assert_int(strip.gap_rects().size()).override_failure_message(message).is_equal(
			wide if lane == 0 else 0
		)
		for gap: Rect2 in strip.gap_rects():
			assert_int(lane).is_equal(0)
			for ticket: Rect2 in tickets:
				(
					assert_bool(gap.intersects(ticket))
					. override_failure_message("%s gap %s on %s" % [message, gap, ticket])
					. is_false()
				)
		var span: Rect2 = strip.parts_rect()
		for other: Rect2 in spans[lane]:
			var meet: bool = span.position.x < other.end.x and other.position.x < span.end.x
			assert_bool(meet).override_failure_message("%s meets %s" % [message, other]).is_false()
		spans[lane].append(span)


## Hovering each item turns hot its own strip, on top in lane 0's band, and the strips giving to
## it (PlanningModel.hot_lanes): at most one per lane, as every hot strip spans the hovered item,
## so no two hot strips of one lane meet; no factor badge shows; every gain badge stands on its
## own target (over the target's centre, or its near edge GAIN_GAP past it) and is drawn over
## every hot strip, and every gain badge, plate, plug, cap and notch lies inside the lip band, no
## two gains meet, its ticket is ringed, and every part of the layer stays on screen. Some gain
## shows on every row. Returns how many gains stood over another hot strip's ring.
func _assert_hot(screen: ShiftScreen, case: String) -> int:
	var layer: PlanningLayer = _layer(screen)
	var effects: PlanningEffects = screen._effects
	var to_layer: Transform2D = layer.get_global_transform().affine_inverse()
	effects.pointer = func() -> Vector2: return Vector2(-500, -500)
	var band: Rect2 = RailStrip.LIP_BAND.grow(TOLERANCE)
	var model: PlanningModel = effects.committed_model()
	var shown_gains: int = 0
	var covers: int = 0
	for slot: int in range(screen._row_views.size()):
		var own: RailStripSpec = null
		var givers: int = 0
		for spec: RailStripSpec in model.strips:
			if spec.giver_slot == slot:
				own = spec
			elif spec.targets.has(slot):
				givers += 1
		var item: ItemView = screen._row_views[slot] as ItemView
		item.hovered.emit(item)
		await _frames(1)
		var message: String = "%s: %d hovered" % [case, slot]
		var hot: Array[RailStrip] = layer.hot_strips()
		var expected: int = mini((1 if own != null else 0) + givers, 2)
		assert_int(hot.size()).override_failure_message(message).is_equal(expected)
		if expected == 0:
			continue
		if own != null:
			assert_object(hot[0].spec()).override_failure_message(message).is_same(own)
			assert_float(hot[0].body_rect().position.y).override_failure_message(message).is_equal(
				RailStrip.LANE_RECTS[0].position.y
			)
		var lanes_used: Array[int] = []
		var badges: Array[Rect2] = []
		for strip: RailStrip in hot:
			var top: float = strip.body_rect().position.y
			var lane: int = -1
			for index: int in range(RailStrip.LANE_RECTS.size()):
				if is_equal_approx(top, RailStrip.LANE_RECTS[index].position.y):
					lane = index
			assert_int(lane).override_failure_message(message).is_not_equal(-1)
			assert_bool(lanes_used.has(lane)).override_failure_message(message).is_false()
			lanes_used.append(lane)
			var pieces: Array[Rect2] = strip.lip_rects()
			var gains: Array[Control] = strip.gains()
			var centres: PackedFloat32Array = strip.gain_centres()
			assert_int(centres.size()).override_failure_message(message).is_equal(gains.size())
			for index: int in range(gains.size()):
				var gain: Control = gains[index]
				if not gain.visible:
					continue
				var rect: Rect2 = to_layer * gain.get_global_rect()
				pieces.append(rect)
				badges.append(rect)
				shown_gains += 1
				(
					assert_bool(_on_own_target(rect, centres[index]))
					. override_failure_message(
						"%s gain %s off its target %.1f" % [message, rect, centres[index]]
					)
					. is_true()
				)
				covers += _assert_gain_on_top(gain, rect, hot, message)
			for piece: Rect2 in pieces:
				(
					assert_bool(band.encloses(piece))
					. override_failure_message("%s piece %s" % [message, piece])
					. is_true()
				)
		_assert_no_factor_badges(layer, message)
		# No two gain badges meet.
		for index: int in range(badges.size()):
			for other: int in range(index + 1, badges.size()):
				(
					assert_bool(badges[index].intersects(badges[other]))
					. override_failure_message(
						"%s badges %s %s" % [message, badges[index], badges[other]]
					)
					. is_false()
				)
		assert_bool(layer.ticket_ring().has_area()).override_failure_message(message).is_true()
		for part: Control in layer.parts():
			(
				assert_bool(SCREEN_RECT.grow(TOLERANCE).encloses(part.get_global_rect()))
				. override_failure_message(
					"%s %s %s" % [message, part.name, part.get_global_rect()]
				)
				. is_true()
			)
	effects.unfocus()
	assert_array(layer.hot_strips()).is_empty()
	assert_int(shown_gains).override_failure_message(case).is_greater(0)
	return covers


## Whether gain badge `rect` stands on its own target's centre `centre`: centred over it, or its
## near edge GAIN_GAP past it (after it, then before it: RailStrip.place_gains).
static func _on_own_target(rect: Rect2, centre: float) -> bool:
	var slack: float = ArtStyle.ART_SCALE / 2.0 + TOLERANCE
	return (
		absf(rect.get_center().x - centre) <= slack
		or absf(rect.position.x - (centre + RailStrip.GAIN_GAP)) <= slack
		or absf(rect.end.x - (centre - RailStrip.GAIN_GAP)) <= slack
	)


## A shown gain badge `gain` (at `rect`, layer coordinates) is drawn after every hot strip in
## `hot` (same box, later child), so no hot strip's body or ring covers it. Returns how many of
## the other hot strips' rings it overlaps on screen (the case the draw order matters for).
func _assert_gain_on_top(gain: Control, rect: Rect2, hot: Array[RailStrip], case: String) -> int:
	var overlaps: int = 0
	for strip: RailStrip in hot:
		assert_object(gain.get_parent()).override_failure_message(case).is_same(strip.get_parent())
		(
			assert_int(gain.get_index())
			. override_failure_message("%s gain %s under %s" % [case, rect, strip.spec().name])
			. is_greater(strip.get_index())
		)
		if not strip.gains().has(gain):
			var ring: Rect2 = strip.body_rect().grow(RailStrip.HOT_RING_OUTER)
			overlaps += 1 if rect.intersects(ring) else 0
	return overlaps


## No factor badge ("×3", "+3") anywhere on the layer: the factor is the target's sticker only.
## Every strip, calm or hot, is made only of its own parts (its painted shadow and plate, body,
## name, and notch, cap and chevron art), its one label the giver's name; and no label on the
## layer outside the stickers reads like a factor.
func _assert_no_factor_badges(layer: PlanningLayer, case: String) -> void:
	var art: Array[Texture2D] = [
		RailStrip.NOTCH,
		RailStrip.NOTCH_HOT,
		RailStrip.CAP,
		RailStrip.CAP_HOT,
		RailStrip.CHEVRON,
		RailStrip.CHEVRON_HOT,
	]
	var strips: Array[RailStrip] = layer.strips()
	strips.append_array(layer.hot_strips())
	for strip: RailStrip in strips:
		for child: Node in strip.get_children():
			var known: bool = (
				child is RailStrip.Painter
				or (child is Panel and child.name == "Body")
				or (child is Label and child.name == "Name")
				or (child is TextureRect and art.has((child as TextureRect).texture))
			)
			(
				assert_bool(known)
				. override_failure_message("%s: %s on %s" % [case, child, strip.spec().name])
				. is_true()
			)
		var labels: Array[Node] = strip.find_children("*", "Label", true, false)
		assert_int(labels.size()).override_failure_message(case).is_equal(1)
		assert_str(String(labels[0].name)).is_equal("Name")
	var factor: RegEx = RegEx.create_from_string("^\\s*[×x+]\\s*\\d")
	for node: Node in layer.find_children("*", "Label", true, false):
		var label: Label = node as Label
		var parent: Node = label.get_parent()
		var in_sticker: bool = false
		while parent != null and parent != layer:
			in_sticker = in_sticker or parent is EffectSticker
			parent = parent.get_parent()
		if in_sticker or not label.is_visible_in_tree():
			continue
		(
			assert_object(factor.search(label.text))
			. override_failure_message("%s: factor text %s" % [case, label.text])
			. is_null()
		)


## What nothing may cover: every CLOSED cell's drawn parts (the rope, its posts and the plate)
## and every empty slot's cell under the stack line (its mat and ticket), on screen.
static func _keep_clear(screen: ShiftScreen) -> Array[Rect2]:
	var rects: Array[Rect2] = []
	var line: float = (
		(
			screen._stage.planning_layer.get_global_transform()
			* Vector2(0, PlanningLayer.STACK_BOTTOM_Y)
		)
		. y
	)
	for panel: PanelContainer in screen._row_strip.closed:
		for node: Node in panel.find_children("*", "Control", true, false):
			var part: Control = node as Control
			if part.is_visible_in_tree() and part.get_global_rect().has_area():
				rects.append(part.get_global_rect())
	for slot: int in range(screen._row_views.size(), screen._row_strip.slots.size()):
		var cell: Rect2 = screen._row_strip.slots[slot].get_global_rect()
		var below: float = maxf(cell.position.y, line)
		rects.append(Rect2(cell.position.x, below, cell.size.x, cell.end.y - below))
	return rects


static func _layer(screen: ShiftScreen) -> PlanningLayer:
	return screen._stage.planning_layer


## A shift with `upgrades` given, `inspection` set (none when empty) and `ids` placed in order.
func _shift(upgrades: Array[String], inspection: String, ids: Array[String]) -> ShiftScreen:
	var runner: GdUnitSceneRunner = scene_runner(SCREEN)
	var screen: ShiftScreen = runner.scene()
	await _frames(2)
	for upgrade: String in upgrades:
		screen._debug.give_upgrade(upgrade)
	if not inspection.is_empty():
		screen._debug.set_inspection(inspection)
	for id: String in ids:
		screen._debug.add_card(id)
		screen._on_hand_card_clicked(_view_for(screen, screen.run.hand()[-1]))
		screen._on_slot_input(_left_click(), screen.run.row.size())
	assert_int(screen.run.row.size()).is_equal(ids.size())
	await _frames(3)
	return screen


func _frames(count: int) -> void:
	for _frame: int in range(count):
		await get_tree().process_frame


static func _view_for(screen: ShiftScreen, card: CardInstance) -> CardView:
	for child: Node in screen._hand_box.get_children():
		var view: CardView = child as CardView
		if view and view.card == card and not view.is_queued_for_deletion():
			return view
	return null


static func _left_click() -> InputEventMouseButton:
	var click: InputEventMouseButton = InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	return click


static func _event_log() -> EventLogService:
	return (Engine.get_main_loop() as SceneTree).root.get_node("/root/EventLog")
