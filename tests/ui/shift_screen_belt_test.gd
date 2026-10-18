extends GdUnitTestSuite
## The belt on the real shift screen (#80, mock-up B2, step 6): its art (the perspective top
## face, the lip, apron and rail, the bolts) at its rects with the sharp-pixel material, taking no
## click; the row's cells stand in the row's band over the belt at B2's coordinates, the row's
## cards stand on the belt as belt items on their contact shadows with their tickets on the rail,
## the empty slots' footprints recede to the belt's vanishing point, and 7-slot, CLOSED, 8-slot
## and 9-slot rows stay on the belt with every item's sprite, plaque, sticker and chips inside its
## own cell, each slot's drop target inside it, on the 1280x720 stage. Every rect is checked on
## screen (headless
## runs use a 1280x1280 window: the stage is centred, 280 px down). The real saves and logs are
## never touched.

const SCREEN := "res://ui/shift_screen.tscn"
const SHORT_BELT := preload("res://data/inspections/short_belt.tres")
## Mock-up B2's first cell and the cells' pitch, on the stage.
const CELL_ORIGIN := Vector2(364, 258)
const CELL_PITCH := 128.0
## The smallest a scaled row's sticker summary may print, in canvas pixels.
const MIN_SUMMARY_PX := 10.0

var _folder: String = ""


func before_test() -> void:
	_folder = "user://test_logs_%d" % Time.get_ticks_usec()
	_event_log().use_folder(_folder)
	# The run and profile saves go there too, never to the real user:// saves.
	ProjectSettings.set_setting(SaveService.FOLDER_SETTING, _folder)


func after_test() -> void:
	ProjectSettings.set_setting(SaveService.FOLDER_SETTING, null)
	if DirAccess.dir_exists_absolute(_folder):
		for file_name: String in DirAccess.get_files_at(_folder):
			DirAccess.remove_absolute(_folder.path_join(file_name))
		DirAccess.remove_absolute(_folder)


## The 7 cells stand at the mirrored mock-up B2's places (pitch 128 from (364, 258)) in the row's
## band over the belt; the belt's top face starts at the counter line, and the register stands
## left of the belt, from the stage's left edge to 336.
func test_the_cells_fill_the_rubber_as_in_style_frame_v2() -> void:
	var screen: ShiftScreen = await _screen()
	var stage: Rect2 = screen._stage.get_global_rect()
	assert_int(screen._slots.size()).is_equal(7)
	for slot: int in range(7):
		var cell: Rect2 = screen._slots[slot].get_global_rect()
		var expected: Vector2 = CELL_ORIGIN + Vector2(slot * CELL_PITCH, 0)
		assert_that(cell).is_equal(Rect2(stage.position + expected, ItemView.BELT_SIZE))
	var row: Rect2 = screen._slots[0].get_global_rect().merge(screen._slots[6].get_global_rect())
	assert_bool(_on_stage(screen, ShiftStage.ROW_AREA).encloses(row)).is_true()
	var belt: BeltPanel = screen._stage.belt
	var top_face: Rect2 = belt.get_global_transform() * belt.top_face()
	assert_float(top_face.position.y).is_equal(stage.position.y + ShiftStage.COUNTER_TOP)
	var register: Rect2 = screen._register.get_global_rect()
	assert_float(register.position.x).is_equal(stage.position.x)
	assert_float(register.end.x - stage.position.x).is_equal(336.0)
	assert_float(belt.get_global_rect().position.x).is_greater(register.end.x)


## The belt's art: the top face (belt_top, baked by tools/belt_art.py) at 1:1 over the guard and
## the top face, the front 3-slice (lip, apron, rail) under it at its art's height (only its
## middle column stretches), and on the apron a bolt in each gap between two tickets of the
## 7-slot row, left of the first one too, and the direction chevrons centred under each ticket;
## every part inside the belt, drawn with the sharp-pixel
## material, taking no click. The rail and the top face lie on that art.
func test_the_belt_art_lies_on_the_belt() -> void:
	var screen: ShiftScreen = await _screen()
	var belt: BeltPanel = screen._stage.belt
	var stage: Rect2 = screen._stage.get_global_rect()
	var inside: Rect2 = belt.get_global_rect()
	var top: TextureRect = belt.get_node(NodePath(BeltPanel.TOP_NAME)) as TextureRect
	assert_object(top.texture).is_same(BeltPanel.BELT_TOP)
	assert_vector(top.size).is_equal(Vector2(top.texture.get_size()))
	assert_that(top.get_global_rect()).is_equal(
		Rect2(inside.position + BeltPanel.TOP_RECT.position, BeltPanel.TOP_RECT.size)
	)
	var front: NinePatchRect = belt.get_node(NodePath(BeltPanel.FRONT_NAME)) as NinePatchRect
	assert_object(front.texture).is_same(BeltPanel.BELT_FRONT)
	assert_float(front.size.y).is_equal(float(front.texture.get_height()))
	var margin: int = BeltPanel.FRONT_MARGIN * ArtStyle.ART_SCALE
	assert_int(front.patch_margin_left).is_equal(margin)
	assert_int(front.patch_margin_right).is_equal(margin)
	assert_int(front.patch_margin_top).is_equal(0)
	assert_int(front.patch_margin_bottom).is_equal(0)
	assert_float(front.get_global_rect().position.y).is_equal(top.get_global_rect().end.y)
	var art: Array[Control] = belt.art()
	assert_int(art.size()).is_equal(2 + 2 * BeltPanel.BOLT_COUNT)
	for part: Control in art:
		var rect: Rect2 = part.get_global_rect()
		assert_bool(inside.encloses(rect)).override_failure_message(str(part.name)).is_true()
		assert_object(part.material).is_same(ArtStyle.pixel_material())
		assert_int(part.mouse_filter).is_equal(Control.MOUSE_FILTER_IGNORE)
	var face: Rect2 = belt.get_global_transform() * belt.top_face()
	var rail: Rect2 = belt.get_global_transform() * belt.rail()
	assert_bool(top.get_global_rect().encloses(face)).is_true()
	assert_bool(front.get_global_rect().encloses(rail)).is_true()
	assert_float(rail.end.y - stage.position.y).is_less_equal(ShiftStage.ROW_BOTTOM)
	# The bolts on the apron (between the lip and the rail), each in the gap before its ticket,
	# and the chevrons centred under each ticket, pointing left (toward the register).
	var apron: Rect2 = belt.get_global_transform() * BeltPanel.APRON
	var tickets: Array[Rect2] = []
	for panel: PanelContainer in screen._slots:
		tickets.append(RowStrip.mat(panel).get_global_rect())
	for index: int in range(BeltPanel.BOLT_COUNT):
		var bolt: TextureRect = belt.get_node("Bolt%d" % index) as TextureRect
		var rect: Rect2 = bolt.get_global_rect()
		assert_vector(rect.size).is_equal(Vector2(bolt.texture.get_size()))
		assert_bool(apron.encloses(rect)).override_failure_message(str(rect)).is_true()
		assert_float(rect.end.x).is_less_equal(tickets[index].position.x)
		if index > 0:
			assert_float(rect.position.x).is_greater_equal(tickets[index - 1].end.x)
		var chevrons: TextureRect = belt.get_node("Chevrons%d" % index) as TextureRect
		var cue: Rect2 = chevrons.get_global_rect()
		assert_object(chevrons.texture).is_same(BeltPanel.BELT_CHEVRONS)
		assert_vector(cue.size).is_equal(Vector2(chevrons.texture.get_size()))
		assert_bool(apron.encloses(cue)).override_failure_message(str(cue)).is_true()
		assert_float(cue.get_center().x).is_equal(tickets[index].get_center().x)


## The slats' frame (#83): one per 2 px they have run left, wrapping after the slat pitch.
func test_slat_frame() -> void:
	assert_int(BeltPanel.TOP_FRAMES.size()).is_equal(10)
	assert_float(BeltPanel.SLAT_PITCH).is_equal(BeltPanel.TOP_FRAMES.size() * 2.0)
	assert_int(BeltPanel.slat_frame(0.0)).is_equal(0)
	assert_int(BeltPanel.slat_frame(1.9)).is_equal(0)
	assert_int(BeltPanel.slat_frame(2.0)).is_equal(1)
	assert_int(BeltPanel.slat_frame(19.9)).is_equal(9)
	assert_int(BeltPanel.slat_frame(20.0)).is_equal(0)
	assert_int(BeltPanel.slat_frame(46.0)).is_equal(3)


## A belt starts on BELT_TOP; scroll() runs its slats left and shows the matching frame on the
## same sprite (every frame as big as BELT_TOP, so the top face keeps its rect), at most
## MAX_STEP_PX a call and never back, wrapping after the pitch.
func test_scroll_shows_the_frames() -> void:
	var belt: BeltPanel = auto_free(BeltPanel.new())
	var top: TextureRect = belt.get_node(NodePath(BeltPanel.TOP_NAME)) as TextureRect
	assert_int(belt.frame()).is_equal(0)
	assert_object(top.texture).is_same(BeltPanel.BELT_TOP)
	for texture: Texture2D in BeltPanel.TOP_FRAMES:
		assert_vector(texture.get_size()).is_equal(BeltPanel.BELT_TOP.get_size())
	belt.scroll(2.0)
	assert_int(belt.frame()).is_equal(1)
	assert_object(top.texture).is_same(BeltPanel.TOP_FRAMES[1])
	belt.scroll(1.0)
	belt.scroll(1.0)
	assert_int(belt.frame()).is_equal(2)
	belt.scroll(100.0)
	assert_int(belt.frame()).is_equal(2 + int(BeltPanel.MAX_STEP_PX / 2.0))
	belt.scroll(-6.0)
	assert_int(belt.frame()).is_equal(6)
	for step: int in range(4):
		belt.scroll(2.0)
	assert_int(belt.frame()).is_equal(0)
	assert_object(top.texture).is_same(BeltPanel.BELT_TOP)
	assert_vector(top.size).is_equal(BeltPanel.TOP_RECT.size)
	assert_int(belt.art().size()).is_equal(2 + 2 * BeltPanel.BOLT_COUNT)


## Every belt item stands on its contact shadow, under its art's opaque foot and on the belt's
## top face, a little right of the sprite's middle (the light is top left); the coupon slip drops
## by its art's transparent rows, so its foot and shadow are on the products' line. Empty slots'
## footprints on the real belt recede to its vanishing point.
func test_items_cast_shadows_and_footprints_recede() -> void:
	var screen: ShiftScreen = await _screen()
	_place(screen, ["bread", "milk", "multipack"])
	await _frames(2)
	var belt: BeltPanel = screen._stage.belt
	var face: Rect2 = belt.get_global_transform() * belt.top_face()
	var feet: Array[float] = []
	for view: CardView in screen._row_views:
		var item: ItemView = view as ItemView
		var shadow: Rect2 = item.get_global_transform() * item._belt_shadow()
		var sprite: Rect2 = item.sprite().get_global_rect()
		assert_bool(face.encloses(shadow)).override_failure_message(str(shadow)).is_true()
		assert_float(shadow.get_center().x).is_greater(sprite.get_center().x)
		var foot: float = (
			sprite.position.y
			+ (
				ContactShadow.opaque_bottom(item.sprite().texture)
				* sprite.size.y
				/ item.sprite().texture.get_height()
			)
		)
		assert_bool(shadow.position.y < foot and shadow.end.y > foot).is_true()
		feet.append(foot)
	# The slip's art stands on the products' line, and so does its shadow.
	assert_float(feet[2]).is_equal_approx(feet[0], 0.01)
	var stage: Vector2 = screen._stage.get_global_rect().position
	var vanishing: Vector2 = stage + BeltPanel.VANISHING_POINT
	for slot: int in range(3, screen._slots.size()):
		var footprint: BeltFootprint = RowStrip.footprint(screen._slots[slot])
		assert_bool(footprint.visible).is_true()
		var corners: PackedVector2Array = footprint.get_global_transform() * footprint.outline()
		assert_bool(face.has_point(corners[0])).is_true()
		assert_bool(face.has_point(corners[2] - Vector2(1, 1))).is_true()
		for pair: Vector2i in [Vector2i(0, 3), Vector2i(1, 2)]:
			var edge: Vector2 = (corners[pair.x] - corners[pair.y]).normalized()
			var sine: float = edge.cross((vanishing - corners[pair.y]).normalized())
			assert_float(absf(sine)).override_failure_message(str(slot)).is_less(0.0001)


## The usual 7-slot row, a CLOSED row (Short belt) and a 9-slot row (Big basket and Extra coupon
## slot, scaled to the 7-slot width) stay in the row's band over the belt, apart, clear of the
## receipt, resting on ROW_BOTTOM, with each value plaque under the top bar, inside its cell and
## clear of its sprite. Row items are belt items (ItemView.BELT_SIZE, the 7-slot row
## never scaled) whose sprite is the moving body.
func test_the_rows_stay_on_the_belt() -> void:
	var screen: ShiftScreen = await _screen()
	var run: RunState = screen.run
	_place(screen, ["bread", "milk", "eggs"])
	await _frames(2)
	_assert_row_on_belt(screen, 7)
	assert_int(screen._row_views.size()).is_equal(3)
	for view: CardView in screen._row_views:
		assert_bool(view is ItemView).is_true()
		assert_vector(view.get_global_rect().size).is_equal(ItemView.BELT_SIZE)
		assert_vector(view.body.get_global_rect().size).is_equal(ItemView.SPRITE_SIZE)

	run.inspections = [SHORT_BELT]
	run.debug_skip_to_shift(run.shift_index)
	screen._on_shift_started()
	_place(screen, ["bread", "milk"])
	await _frames(2)
	assert_int(screen._row_strip.closed.size()).is_equal(1)
	assert_vector(screen._row_strip.box.scale).is_equal(Vector2.ONE)
	_assert_row_on_belt(screen, 7)

	run.inspections = []
	screen._debug.give_upgrade("big_basket")
	screen._debug.give_upgrade("extra_coupon_slot")
	_place(screen, ["bread", "milk", "eggs", "cheese"])
	await _frames(3)
	assert_int(screen._slots.size()).is_equal(9)
	assert_float(screen._row_strip.box.scale.x).is_less(1.0)
	_assert_row_on_belt(screen, 9)
	# The belt keeps its size; the scaled row rests on its bottom line, the empty band above it.
	var row: Rect2 = screen._slots[0].get_global_rect()
	var stage: Rect2 = screen._stage.get_global_rect()
	assert_float(row.end.y).is_equal_approx(stage.position.y + ShiftStage.ROW_BOTTOM, 0.5)
	assert_float(row.position.y).is_greater(stage.position.y + ShiftStage.ROW_POSITION.y)


## Full 8- and 9-slot rows (a full row of products and coupons, two chips each): every item's
## sprite stays above its ticket, its plaque (a four-digit payout), sticker and chips in its own
## cell, so nothing reaches a neighbour, all of it on the stage and in the row's band; the sticker's
## summary prints at least MIN_SUMMARY_PX tall.
func test_full_wide_rows_keep_each_item_in_its_cell() -> void:
	var screen: ShiftScreen = await _screen()
	screen._debug.give_upgrade("big_basket")
	await _frames(2)
	await _assert_full_row_fits(screen, 8)
	screen._debug.give_upgrade("extra_coupon_slot")
	await _frames(2)
	await _assert_full_row_fits(screen, 9)


func _assert_full_row_fits(screen: ShiftScreen, count: int) -> void:
	assert_int(screen._slots.size()).is_equal(count)
	screen.run.row.clear()
	var ids: Array[String] = ["milk", "repeat", "banana", "two_for_one", "cheese"]
	var cards: Array[String] = []
	for slot: int in range(count):
		cards.append(ids[slot % ids.size()])
	_place(screen, cards)
	await _frames(2)
	assert_int(screen._row_views.size()).is_equal(count)
	var stage: Rect2 = screen._stage.get_global_rect()
	var rubber: Rect2 = _on_stage(screen, ShiftStage.ROW_AREA).grow(0.01)
	for slot: int in range(count):
		var item: ItemView = screen._row_views[slot] as ItemView
		item.show_badge(9999, false)
		item.show_mark(true)
		var message: String = "%d slots, item %d" % [count, slot]
		var cell: Rect2 = screen._slots[slot].get_global_rect()
		assert_bool(rubber.encloses(cell)).override_failure_message(message).is_true()
		var mat: Rect2 = RowStrip.mat(screen._slots[slot]).get_global_rect()
		var sprite: Rect2 = item.body.get_global_rect()
		assert_float(sprite.end.y).override_failure_message(message).is_less_equal(mat.position.y)
		var parts: Array[Control] = [item._mark, item.sticker()]
		var face: Rect2 = (item.badge as PayoutPlaque).face().get_global_rect()
		# The paid chip rises over the cell's top, in its column, under the hung monitor.
		assert_float(face.position.x).is_greater_equal(cell.position.x - 0.01)
		assert_float(face.end.x).is_less_equal(cell.end.x + 0.01)
		assert_float(face.position.y).is_greater_equal(
			_on_stage(screen, ShiftStage.MONITOR_UNDER_RECT).end.y
		)
		for part: Control in parts:
			var rect: Rect2 = part.get_global_rect()
			(
				assert_bool(cell.grow(0.01).encloses(rect))
				. override_failure_message("%s: %s at %s" % [message, part.get_class(), rect])
				. is_true()
			)
			assert_bool(stage.encloses(rect)).override_failure_message(message).is_true()
		var summary: Label = item.sticker().summary_label()
		var shown: float = (
			summary.get_theme_font_size("font_size") * summary.get_global_transform().get_scale().y
		)
		assert_float(shown).override_failure_message(message).is_greater_equal(MIN_SUMMARY_PX)


func _assert_row_on_belt(screen: ShiftScreen, panel_count: int) -> void:
	var stage: Rect2 = screen._stage.get_global_rect()
	var bar_bottom: float = stage.position.y + RewardPanel.PRINTOUT_TOP
	var belt: Rect2 = (screen._row_strip.get_parent() as Control).get_global_rect()
	var receipt: Rect2 = screen._receipt.get_global_rect()
	assert_that(belt).is_equal(_on_stage(screen, ShiftStage.BELT_RECT))
	assert_bool(stage.encloses(belt)).is_true()
	# In the row's band over the belt.
	# (Grown by a hair: a scaled row ends on the band's edge, give or take float rounding.)
	var interior: Rect2 = _on_stage(screen, ShiftStage.ROW_AREA).grow(0.01)
	var panels: Array[PanelContainer] = screen._slots + screen._row_strip.closed
	assert_int(panels.size()).is_equal(panel_count)
	var previous: Rect2 = Rect2()
	var previous_drop: Rect2 = Rect2()
	var top_face: Rect2 = screen._stage.belt.get_global_transform() * screen._stage.belt.top_face()
	var rail: Rect2 = screen._stage.belt.get_global_transform() * screen._stage.belt.rail()
	for index: int in range(panels.size()):
		var rect: Rect2 = panels[index].get_global_rect()
		assert_bool(interior.encloses(rect)).override_failure_message(str(rect)).is_true()
		# An open slot's drop target: its cell's column and half the gap on each side (the row's
		# band holds it), from the top of an item's art (over the top face, under the hung
		# monitor) down to the rail's foot, meeting the previous slot's with no overlap and
		# never reaching a CLOSED cell.
		if index < screen._slots.size():
			var drop: Rect2 = RowStrip.drop_rect(panels[index])
			var half_gap: float = (
				RowStrip.separation_for(panel_count) / 2.0 * screen._row_strip.box.scale.x
			)
			var column: Rect2 = rect.grow_individual(half_gap, 0, half_gap, 0).grow(0.01)
			assert_bool(column.encloses(drop)).override_failure_message(str(drop)).is_true()
			assert_bool(interior.encloses(drop)).override_failure_message(str(drop)).is_true()
			assert_float(drop.position.y).is_less(top_face.position.y)
			assert_float(drop.position.y).is_greater_equal(
				_on_stage(screen, ShiftStage.MONITOR_UNDER_RECT).end.y
			)
			assert_float(drop.end.y).is_less_equal(rail.end.y + 0.01)
			if index > 0:
				assert_float(drop.position.x).is_equal_approx(previous_drop.end.x, 0.01)
			for closed: PanelContainer in screen._row_strip.closed:
				assert_bool(drop.intersects(closed.get_global_rect())).is_false()
			previous_drop = drop
		assert_bool(rect.intersects(receipt)).override_failure_message(str(rect)).is_false()
		# Every row rests on the same line.
		assert_float(rect.end.y).is_equal_approx(stage.position.y + ShiftStage.ROW_BOTTOM, 0.5)
		# (A scaled row's cells touch, give or take float rounding.)
		if index > 0:
			assert_float(rect.position.x).is_greater_equal(previous.end.x - 0.01)
		previous = rect
	# Planning shows no paid chip (#80, step 7); a mark stays in its cell, off the receipt.
	for view: CardView in screen._row_views:
		assert_bool(view.badge.visible).is_false()
		var mark: EffectMark = (view as ItemView)._mark
		if mark != null:
			var rect: Rect2 = mark.get_global_rect()
			assert_float(rect.position.y).is_greater_equal(bar_bottom)
			assert_bool(view.get_global_rect().encloses(rect)).is_true()
			assert_bool(rect.intersects(receipt)).is_false()


## Puts copies of cards into the row, in order, and refreshes the screen.
func _place(screen: ShiftScreen, card_ids: Array[String]) -> void:
	var run: RunState = screen.run
	for card_id: String in card_ids:
		var card: CardInstance = run.debug_add_to_hand(load("res://data/cards/%s.tres" % card_id))
		assert_bool(run.place(card, run.row.size())).is_true()
	screen._refresh()


## The screen past the impulse rack, laid out.
func _screen() -> ShiftScreen:
	var runner: GdUnitSceneRunner = scene_runner(SCREEN)
	var screen: ShiftScreen = runner.scene()
	screen._on_reward_skipped()
	await _frames(3)
	return screen


## `rect` (stage coordinates) on screen.
static func _on_stage(screen: ShiftScreen, rect: Rect2) -> Rect2:
	return Rect2(screen._stage.get_global_rect().position + rect.position, rect.size)


func _frames(count: int) -> void:
	for _frame: int in range(count):
		await get_tree().process_frame


static func _event_log() -> EventLogService:
	return (Engine.get_main_loop() as SceneTree).root.get_node("/root/EventLog")
