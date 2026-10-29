extends GdUnitTestSuite
## Sticker stacks with a fold and their fan (#105 piece 3, mock-up readability v3 section 3, fold
## A). fit_stack shows 1 to 3 stickers in full and, from the 4th, the earliest folded into one
## "+N" chip on top (more only when the ceiling still demands it). The chip: a grey label at least
## 64x30, turned -3 degrees, its card-fan mark and the count in ink; it pops in, punches, and in
## the count counts down and goes. The fan's geometry (StackFan.fan_rects): rows of at most 4, 76
## px apart, about 330 px wide at most, the lower row above the sprite, the whole fan inside its
## bounds (clamped at both ends of the belt). On the real shift screen at 1280x720 (the stress row
## on 8 slots, Squashed cake's many stickers): the stack sits on the item's right shoulder with at
## most 3 stickers and the chip on top, overlapping by exactly 4 px (the mock-up's 3 px on the art
## grid) where its ceiling allows, inside the screen and under its ceiling (the last slot's
## shifted left by the screen's edge, at the same height); hovering it fans every
## sticker out in step order, numbered 1 to N, on screen, inside the belt's x-range, under the top
## bar, above the item and never over its ticket or pay tag, the stack hidden meanwhile; the fan
## hovers its item (the mix highlight and #71's focus) and keeps it while the pointer is on it;
## leaving closes it and the focus goes; a drag, the open Cart (the fan's blocked), the count and
## reduced motion behave. The real saves and
## logs are never touched.

const SCREEN := "res://ui/shift_screen.tscn"
const SCREEN_RECT := Rect2(0, 0, 1280, 720)
## planning_layout_test's stress row: Squashed cake (the last) takes 6 stickers.
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
## A row of the fan's width at most: 3 gaps and a burst's width, its giver badge and its number.
const FAN_ROW_MAX := 328.0
const TOLERANCE := 0.01

var _folder: String = ""
var _window_size: Vector2i


func before_test() -> void:
	_folder = "user://test_stack_fold_%d" % Time.get_ticks_usec()
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


func test_a_stack_shows_three_then_folds_the_earliest() -> void:
	for count: int in [1, 2, 3, 4, 5, 7, 12]:
		var specs: Array[StickerSpec] = _specs(count)
		var fitted: Array = PlanningLayer.fit_stack(specs, 374.0, 64.0)
		var shown: Array[StickerSpec] = []
		shown.assign(fitted[0])
		assert_float(fitted[1]).is_equal(PlanningLayer.STACK_OVERLAP)
		if count <= 3:
			assert_array(shown).is_equal(specs)
			continue
		assert_int(shown.size()).is_equal(4)
		assert_int(shown[0].kind).is_equal(StickerSpec.Kind.MORE)
		assert_str(shown[0].text).is_equal("+%d" % (count - 3))
		assert_int(shown[0].folds).is_equal(count - 3)
		# The newest three stay, in order.
		assert_array(shown.slice(1)).is_equal(specs.slice(count - 3))
	# A low ceiling squeezes the three and the chip, then folds more.
	var tight: Array = PlanningLayer.fit_stack(_specs(7), 374.0, 290.0)
	var tight_shown: Array[StickerSpec] = []
	tight_shown.assign(tight[0])
	assert_float(tight[1]).is_equal(PlanningLayer.STACK_OVERLAP_MAX)
	assert_int(tight_shown.size()).is_less(PlanningLayer.STACK_SHOWN + 1)
	assert_int(tight_shown[0].folds).is_equal(7 - (tight_shown.size() - 1))


func test_the_fold_chip_looks_and_moves() -> void:
	var chip: EffectSticker = auto_free(EffectSticker.new(StickerSpec.folded(3), 4.0))
	add_child(chip)
	assert_str(chip.text()).is_equal("+3")
	assert_bool(chip.size.x >= EffectSticker.FOLD_SIZE.x).is_true()
	assert_float(chip.size.y).is_equal(EffectSticker.FOLD_SIZE.y)
	var frame: Control = chip.find_child("Frame", true, false) as Control
	assert_float(frame.rotation_degrees).is_equal(EffectSticker.FOLD_TILT_DEG)
	var mark: TextureRect = chip.find_child("FoldMark", true, false) as TextureRect
	assert_object(mark.texture).is_same(EffectSticker.FOLD_MARK)
	assert_bool(mark.size == Vector2(30, 20)).is_true()
	var label: Label = chip.find_child("Text", true, false) as Label
	assert_bool(label.get_theme_color("font_color") == Palette.INK).is_true()
	assert_int(label.get_theme_constant("outline_size")).is_equal(0)
	assert_int(label.get_theme_font_size("font_size")).is_equal(EffectSticker.FOLD_TEXT_SIZE)
	# The mark and the text sit inside the chip, the text after the mark.
	var inside: Rect2 = Rect2(Vector2.ZERO, chip.size)
	assert_bool(inside.encloses(Rect2(mark.position, mark.size))).is_true()
	assert_bool(inside.encloses(chip.text_rect())).is_true()
	assert_float(chip.text_rect().position.x).is_greater_equal(mark.position.x + mark.size.x)
	# It pops in from 0.3, then punches.
	chip.fold_punch(true, false)
	var inner: Control = chip.get_child(0) as Control
	assert_float(inner.scale.x).is_equal_approx(EffectSticker.FOLD_POP_FROM, 0.001)
	assert_bool(chip.is_firing()).is_true()
	await _seconds(EffectSticker.FOLD_POP_S + 0.2)
	assert_float(inner.scale.x).is_equal_approx(1.0, 0.001)
	chip.fold_punch(false, false)
	assert_bool(chip.is_firing()).is_true()
	chip.fold_punch(false, true)
	assert_bool(chip.is_firing()).is_false()
	# The count: down by one per fire, never a check, then it shrinks away.
	chip.fire(false)
	assert_str(chip.text()).is_equal("+2")
	chip.fire(false)
	assert_str(chip.text()).is_equal("+1")
	chip.fire(false)
	assert_bool(chip.has_check()).is_false()
	await _seconds(EffectSticker.FOLD_POP_S + 0.2)
	assert_float(chip.modulate.a).is_equal(0.0)


func test_a_fanned_sticker_wears_its_number() -> void:
	var sticker: EffectSticker = auto_free(EffectSticker.new(_specs(1)[0], 0.0))
	add_child(sticker)
	assert_bool(sticker.number_rect() == Rect2()).is_true()
	sticker.set_number(7, 0.5)
	var number: Control = sticker.find_child("Number", false, false) as Control
	assert_bool(number.visible).is_true()
	assert_float(number.modulate.a).is_equal(0.5)
	assert_str((number.get_child(0) as Label).text).is_equal("7")
	assert_bool(sticker.number_rect().intersects(Rect2(Vector2.ZERO, sticker.size))).is_true()
	sticker.set_number(0)
	assert_bool(number.visible).is_false()
	# The number never covers the giver's mini, on a label or a burst.
	for kind: StickerSpec.Kind in [StickerSpec.Kind.ADD, StickerSpec.Kind.MULTIPLY]:
		var spec: StickerSpec = _specs(1)[0]
		spec.kind = kind
		spec.badge = GiverBadge.Kind.ITEM
		spec.badge_text = "Eg"
		spec.badge_mini = "res://art/minis/eggs.png"
		var given: EffectSticker = auto_free(EffectSticker.new(spec, 0.0))
		add_child(given)
		given.set_number(1)
		var badge: GiverBadge = given.badge()
		var art: Rect2 = Rect2(badge.position + badge.art_rect().position, badge.art_rect().size)
		(
			assert_bool(given.number_rect().intersects(art))
			. override_failure_message(str(kind))
			. is_false()
		)


func test_the_fan_geometry() -> void:
	var sprite: Rect2 = Rect2(700, 286, 96, 96)
	var bounds: Rect2 = StackFan.bounds_for(sprite)
	for count: int in [5, 7, 8, 9, 12]:
		var sizes: Array[Vector2] = []
		for index: int in range(count):
			sizes.append(EffectSticker.BURST_SIZE if index % 3 == 1 else Vector2(46, 28))
		var rects: Array[Rect2] = StackFan.fan_rects(sizes, sprite, bounds)
		_assert_fan(rects, sprite, bounds, "%d stickers" % count)
	# The scanner's cell (the belt's left end) and the last cell (its right end) clamp it.
	for sprite_x: float in [374.0, 1160.0]:
		var edge: Rect2 = Rect2(sprite_x, 286, 96, 96)
		var edge_bounds: Rect2 = StackFan.bounds_for(edge)
		var sizes: Array[Vector2] = []
		for index: int in range(8):
			sizes.append(EffectSticker.BURST_SIZE)
		_assert_fan(StackFan.fan_rects(sizes, edge, edge_bounds), edge, edge_bounds, str(sprite_x))
	# Turned by place: the row's ends most, the middle none.
	assert_float(StackFan.turn_of(4, 0)).is_equal_approx(-StackFan.TURN_DEG, 0.001)
	assert_float(StackFan.turn_of(4, 3)).is_equal_approx(StackFan.TURN_DEG, 0.001)
	assert_float(StackFan.turn_of(3, 1)).is_equal(0.0)


func test_a_folded_stack_on_the_shift_screen() -> void:
	var screen: ShiftScreen = await _shift()
	var layer: PlanningLayer = screen._stage.planning_layer
	var slot: int = _folded_slot(screen)
	assert_int(slot).is_greater_equal(0)
	var to_layer: Transform2D = layer.get_global_transform().affine_inverse()
	var pushed: int = 0
	for index: int in range(screen._row_views.size()):
		var shown: Array[EffectSticker] = layer.stack(index)
		if shown.is_empty():
			continue
		var folded: bool = shown[0].spec().kind == StickerSpec.Kind.MORE
		var stickers: int = shown.size() - (1 if folded else 0)
		assert_int(stickers).is_less_equal(PlanningLayer.STACK_SHOWN)
		var item: ItemView = screen._row_views[index] as ItemView
		var sprite: Rect2 = to_layer * BeltRide.sprite_rect(item)
		var span: Rect2 = Rect2()
		for at: int in range(shown.size()):
			var rect: Rect2 = to_layer * shown[at].get_global_rect()
			span = rect if at == 0 else span.merge(rect)
		for at: int in range(shown.size()):
			var rect: Rect2 = to_layer * shown[at].get_global_rect()
			var message: String = "slot %d sticker %d %s" % [index, at, rect]
			(
				assert_bool(SCREEN_RECT.encloses(shown[at].get_global_rect()))
				. override_failure_message(message)
				. is_true()
			)
			# On the right shoulder: from the sprite's middle rightward (the badges overhang),
			# unless the screen's right edge moved it left.
			if span.end.x < SCREEN_RECT.end.x - PlanningLayer.STACK_EDGE_GAP - 2.0:
				assert_float(rect.position.x).override_failure_message(message).is_greater(
					sprite.get_center().x
				)
		# The screen edge shifts the last stack sideways, keeping it attached at the same height.
		if span.end.x >= SCREEN_RECT.end.x - PlanningLayer.STACK_EDGE_GAP - 2.0:
			pushed += 1
		assert_float(span.end.y).override_failure_message("slot %d" % index).is_equal_approx(
			PlanningLayer.STACK_BOTTOM_Y, TOLERANCE
		)
		var ceiling: float = PlanningLayer.stack_ceiling(span)
		assert_float(span.position.y).is_greater_equal(ceiling - TOLERANCE)
		assert_float(span.end.y).is_less_equal(PlanningLayer.STACK_BOTTOM_Y + TOLERANCE)
		# STACK_OVERLAP exactly where the ceiling leaves room (none squeezed).
		var overlap: float = _overlap(shown, to_layer)
		if shown.size() > 1 and span.position.y > ceiling + 2.0 * PlanningLayer.STACK_OVERLAP_MAX:
			assert_float(overlap).override_failure_message("slot %d" % index).is_equal(
				PlanningLayer.STACK_OVERLAP
			)
		if folded:
			# The chip on top, on the stack's left edge.
			var chip: Rect2 = to_layer * shown[0].get_global_rect()
			assert_float(chip.position.y).is_equal(span.position.y)
	# Squashed cake, the last, is the one pushed.
	assert_int(pushed).is_equal(1)
	var cake: Array[EffectSticker] = layer.stack(slot)
	assert_str(cake[0].text()).is_equal(
		"+%d" % (screen._effects.committed_model().slots[slot].stickers.size() - 3)
	)


func test_hovering_the_item_or_its_ticket_opens_the_folded_stack() -> void:
	var screen: ShiftScreen = await _shift()
	var fan: StackFan = screen._stage.planning_layer.fan()
	var slot: int = _folded_slot(screen)
	var item: ItemView = screen._row_views[slot] as ItemView
	var previous_pointer: Vector2 = screen.get_viewport().get_mouse_position()
	for point: Vector2 in [
		BeltRide.sprite_rect(item).get_center(), item.sticker().get_global_rect().get_center()
	]:
		fan.point_at(Vector2(-500, -500))
		await _seconds(StackFan.OPEN_S + 0.1)
		# Use real input dispatch, rather than calling the fan's hit test directly.
		var motion: InputEventMouseMotion = InputEventMouseMotion.new()
		motion.position = point
		Input.parse_input_event(motion)
		await _frames(2)
		assert_int(fan.fanned()).is_equal(slot)
		await _seconds(StackFan.OPEN_S + 0.1)
		assert_int(fan.copies().size()).is_equal(
			screen._effects.committed_model().slots[slot].stickers.size()
		)
		assert_object(screen._effects.focused_card()).is_same(item.card)
	var restore: InputEventMouseMotion = InputEventMouseMotion.new()
	restore.position = previous_pointer
	Input.parse_input_event(restore)
	await _frames(1)


func test_hovering_a_folded_stack_fans_it_out() -> void:
	var screen: ShiftScreen = await _shift()
	var layer: PlanningLayer = screen._stage.planning_layer
	var fan: StackFan = layer.fan()
	var slot: int = _folded_slot(screen)
	var item: ItemView = screen._row_views[slot] as ItemView
	var specs: Array[StickerSpec] = screen._effects.committed_model().slots[slot].stickers
	var stack: Array[EffectSticker] = layer.stack(slot)
	fan.point_at(Vector2(-500, -500))
	assert_int(fan.fanned()).is_equal(-1)
	fan.point_at(stack[0].get_global_rect().get_center())
	assert_int(fan.fanned()).is_equal(slot)
	# Opening it hovers its item.
	assert_object(screen._effects.focused_card()).is_same(item.card)
	await _seconds(StackFan.OPEN_S + 0.1)
	assert_float(fan.openness()).is_equal(1.0)
	var copies: Array[EffectSticker] = fan.copies()
	assert_int(copies.size()).is_equal(specs.size())
	var to_layer: Transform2D = layer.get_global_transform().affine_inverse()
	var sprite: Rect2 = to_layer * BeltRide.sprite_rect(item)
	var ticket: Rect2 = to_layer * item.sticker().get_global_rect()
	var keep_off: Array[Rect2] = [ticket]
	if layer.pay_tag(slot) != null:
		keep_off.append(to_layer * layer.pay_tag(slot).get_global_rect())
	var rects: Array[Rect2] = []
	for index: int in range(copies.size()):
		var copy: EffectSticker = copies[index]
		assert_object(copy.spec()).is_same(specs[index])
		assert_str(copy.text()).is_equal(specs[index].text)
		var number: Control = copy.find_child("Number", false, false) as Control
		assert_str((number.get_child(0) as Label).text).is_equal(str(index + 1))
		assert_float(number.modulate.a).is_equal(1.0)
		var rect: Rect2 = to_layer * copy.get_global_rect()
		assert_bool(rect.is_equal_approx(fan.fan_places()[index])).is_true()
		rects.append(rect)
		var message: String = "copy %d %s" % [index, rect]
		(
			assert_bool(SCREEN_RECT.encloses(copy.get_global_rect()))
			. override_failure_message(message)
			. is_true()
		)
		for clear: Rect2 in keep_off:
			assert_bool(rect.intersects(clear)).override_failure_message(message).is_false()
	_assert_fan(rects, sprite, StackFan.bounds_for(sprite), "on screen")
	# The stack hides while the fan is open.
	for sticker: EffectSticker in layer.stack(slot):
		assert_float(sticker.modulate.a).is_equal(0.0)
	# Moving onto the fan keeps it, and the item's focus past the unfocus delay (the pointer has
	# left the item's own rect); leaving both closes it, the stack shows again and the focus goes.
	fan.point_at(layer.get_global_transform() * rects[0].get_center())
	assert_int(fan.fanned()).is_equal(slot)
	item.unhovered.emit(item)
	await _seconds(screen._effects.tuning.unfocus_delay_s * 2.0 + 0.05)
	assert_object(screen._effects.focused_card()).is_same(item.card)
	fan.point_at(Vector2(-500, -500))
	await _seconds(StackFan.OPEN_S + screen._effects.tuning.unfocus_delay_s * 2.0 + 0.1)
	assert_int(fan.fanned()).is_equal(-1)
	assert_array(fan.copies()).is_empty()
	assert_object(screen._effects.focused_card()).is_null()
	for sticker: EffectSticker in layer.stack(slot):
		assert_float(sticker.modulate.a).is_equal(1.0)
	# The open Cart covers the belt: no fan under it.
	screen._on_deck_button_pressed()
	await _frames(2)
	fan.point_at(stack[0].get_global_rect().get_center())
	assert_int(fan.fanned()).is_equal(-1)
	screen._deck_view._close()
	await _frames(2)
	# A drag blocks it.
	var blocked: Callable = fan.blocked
	fan.blocked = func() -> bool: return true
	fan.point_at(stack[0].get_global_rect().get_center())
	assert_int(fan.fanned()).is_equal(-1)
	fan.blocked = blocked
	# Reduced motion: open and shut at once.
	screen._debug.set_reduced_motion(true)
	screen._effects.show_all(screen.run.preview(), screen._row_views, screen.run)
	await _frames(2)
	stack = layer.stack(slot)
	fan.point_at(stack[0].get_global_rect().get_center())
	assert_float(fan.openness()).is_equal(1.0)
	fan.point_at(Vector2(-500, -500))
	assert_int(fan.fanned()).is_equal(-1)
	# The count: no fan.
	fan.point_at(stack[0].get_global_rect().get_center())
	screen._on_checkout_pressed()
	await _frames(2)
	assert_int(fan.fanned()).is_equal(-1)
	fan.point_at(layer.stack(slot)[0].get_global_rect().get_center())
	assert_int(fan.fanned()).is_equal(-1)


## A stack growing past 3 stickers: the chip pops in (from 0.3) and each newly folded sticker,
## shown at the last refresh, shrinks into it and goes.
func test_the_chip_pops_in_as_the_stack_folds() -> void:
	var screen: ShiftScreen = await _shift()
	var layer: PlanningLayer = screen._stage.planning_layer
	var slot: int = _folded_slot(screen)
	var item: ItemView = screen._row_views[slot] as ItemView
	var specs: Array[StickerSpec] = screen._effects.committed_model().slots[slot].stickers
	var known: Dictionary[String, bool] = {}
	for spec: StickerSpec in specs:
		known["%s|%d" % [spec.key(), item.card.instance_id]] = true
	layer._folds_by_card.clear()
	layer.slap_new(known)
	var chip: EffectSticker = layer.stack(slot)[0]
	assert_bool(chip.is_firing()).is_true()
	var going: Array[Node] = _folding(chip.get_parent())
	assert_int(going.size()).is_equal(specs.size() - PlanningLayer.STACK_SHOWN)
	for node: Node in going:
		assert_int(node.get_index()).is_less(chip.get_index())
	await _seconds(EffectSticker.FOLD_PUNCH_S + 0.2)
	assert_array(_folding(chip.get_parent())).is_empty()
	# A refresh with no new fold: no punch.
	layer.slap_new(known)
	assert_bool(layer.stack(slot)[0].is_firing()).is_false()


func _assert_fan(rects: Array[Rect2], sprite: Rect2, bounds: Rect2, case: String) -> void:
	var rows: Array[Array] = []
	for rect: Rect2 in rects:
		var placed: bool = false
		for row: Array in rows:
			if absf((row[0] as Rect2).get_center().y - rect.get_center().y) < StackFan.ROW / 2.0:
				row.append(rect)
				placed = true
				break
		if not placed:
			rows.append([rect])
	assert_int(rows.size()).override_failure_message(case).is_equal(
		ceili(rects.size() / float(StackFan.PER_ROW))
	)
	for row: Array in rows:
		assert_int(row.size()).override_failure_message(case).is_less_equal(StackFan.PER_ROW)
		var reach: Rect2 = StackFan._drawn(row[0])
		for rect: Rect2 in row:
			reach = reach.merge(StackFan._drawn(rect))
		var message: String = "%s row %s" % [case, reach]
		assert_float(reach.size.x).override_failure_message(message).is_less_equal(FAN_ROW_MAX)
		assert_float(reach.position.x).override_failure_message(message).is_greater_equal(
			bounds.position.x - TOLERANCE
		)
		assert_float(reach.end.x).override_failure_message(message).is_less_equal(
			bounds.end.x + TOLERANCE
		)
		assert_float(reach.position.y).override_failure_message(message).is_greater_equal(
			bounds.position.y - TOLERANCE
		)
		assert_float(reach.end.y).override_failure_message(message).is_less_equal(bounds.end.y)
	# Step order: the oldest row on top, each row read left to right.
	for index: int in range(1, rects.size()):
		var earlier: Rect2 = rects[index - 1]
		var later: Rect2 = rects[index]
		var next_row: bool = later.get_center().y > earlier.get_center().y + StackFan.ROW / 2.0
		(
			assert_bool(next_row or later.position.x > earlier.position.x)
			. override_failure_message(case)
			. is_true()
		)
	# The lower row stands over the sprite.
	var lowest: float = 0.0
	for rect: Rect2 in rects:
		lowest = maxf(lowest, rect.get_center().y)
	assert_float(lowest).override_failure_message(case).is_less(sprite.position.y)


## The overlap between neighbouring stickers of `shown` (layer coordinates), the same for all.
func _overlap(shown: Array[EffectSticker], to_layer: Transform2D) -> float:
	var overlap: float = -1.0
	for index: int in range(shown.size() - 1):
		var upper: Rect2 = to_layer * shown[index].get_global_rect()
		var lower: Rect2 = to_layer * shown[index + 1].get_global_rect()
		var here: float = upper.end.y - lower.position.y
		if overlap >= 0.0:
			assert_float(here).is_equal(overlap)
		overlap = here
	return overlap


static func _specs(count: int) -> Array[StickerSpec]:
	var specs: Array[StickerSpec] = []
	for index: int in range(count):
		var spec: StickerSpec = StickerSpec.new()
		spec.kind = StickerSpec.Kind.MULTIPLY if index % 2 == 1 else StickerSpec.Kind.ADD
		spec.text = "×%d" % (index + 2) if index % 2 == 1 else "+%d" % (index + 1)
		spec.step_index = index
		specs.append(spec)
	return specs


## The stickers shrinking into a chip under `box` (still in the tree).
static func _folding(box: Node) -> Array[Node]:
	var found: Array[Node] = []
	for child: Node in box.get_children():
		if child is EffectSticker and String(child.name).contains("Folding"):
			if not child.is_queued_for_deletion():
				found.append(child)
	return found


## The first slot whose stack folds.
static func _folded_slot(screen: ShiftScreen) -> int:
	var layer: PlanningLayer = screen._stage.planning_layer
	for slot: int in range(screen._row_views.size()):
		var shown: Array[EffectSticker] = layer.stack(slot)
		if not shown.is_empty() and shown[0].spec().kind == StickerSpec.Kind.MORE:
			return slot
	return -1


## The stress row on Big basket's 8 slots, placed card by card.
func _shift() -> ShiftScreen:
	var runner: GdUnitSceneRunner = scene_runner(SCREEN)
	var screen: ShiftScreen = runner.scene()
	screen._week.skip()  # The time card (v0.70) stays out of the way.
	await _frames(2)
	for upgrade: String in STRESS_UPGRADES:
		screen._debug.give_upgrade(upgrade)
	for id: String in STRESS_ROW:
		screen._debug.add_card(id)
		screen._on_hand_card_clicked(_view_for(screen, screen.run.hand()[-1]))
		screen._on_slot_input(_left_click(), screen.run.row.size())
	assert_int(screen.run.row.size()).is_equal(STRESS_ROW.size())
	await _frames(3)
	return screen


func _frames(count: int) -> void:
	for _frame: int in range(count):
		await get_tree().process_frame


func _seconds(seconds: float) -> void:
	await get_tree().create_timer(seconds).timeout


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
