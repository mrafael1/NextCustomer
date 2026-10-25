extends GdUnitTestSuite
## The real shift screen on the screen capture's fixed shift (debug/screen_capture: shift 5 under
## Short belt, a hand of 8 items and four on the belt), in planning, with a hand item scanned and
## with a belt item scanned: style frame v2's layout checks (#75, step 9), ported to the screen
## that replaced the mock-up. Everything lies inside the 1280x720 stage; the top bar's parts stand
## apart above the belt; the cells lie on the belt (#80, mock-up B2's greybox), each belt sprite
## standing on its top face and each ticket on the rail, and the hand's basket items (no stickers,
## #80 step 8) lie in the hand's area; no ticket covers another ticket or a sprite, and no
## planning part covers a ticket's text; planning shows no paid chip and no corner mark, and each
## belt item wears its stickers (#71, mock-up h1);
## every printed character has its glyph; no text carries the pixel material, and the sharp-pixel
## switch reaches every piece of art. Every rect is checked on screen (headless runs use a
## 1280x1280 window: the stage is centred, 280 px down). The capture keeps its saves and log in a
## temporary folder and the test redirects them too, so the real ones are never touched.

const CAPTURE := "res://debug/screen_capture/screen_capture.tscn"
## The states: planning, a hand item scanned and a belt item scanned (each shown on the hung
## monitor, #80): the capture's --scan card ids, "" for none.
const SCANS: Array[String] = ["", "batteries", "multipack"]

var _folder: String = ""
var _errors: PackedStringArray = PackedStringArray()


func before_test() -> void:
	_folder = "user://test_logs_%d" % Time.get_ticks_usec()
	_event_log().use_folder(_folder)
	# The run and profile saves go there too, never to the real user:// saves.
	ProjectSettings.set_setting(SaveService.FOLDER_SETTING, _folder)
	_errors.clear()


func after_test() -> void:
	ProjectSettings.set_setting(SaveService.FOLDER_SETTING, null)
	if DirAccess.dir_exists_absolute(_folder):
		for file_name: String in DirAccess.get_files_at(_folder):
			DirAccess.remove_absolute(_folder.path_join(file_name))
		DirAccess.remove_absolute(_folder)


func test_everything_lies_inside_the_stage() -> void:
	for scan: String in SCANS:
		var screen: ShiftScreen = await _captured(scan)
		var stage: Rect2 = screen._stage.get_global_rect()
		# The stage's hud and its world (in the store's camera since #77 machine v2, at 1x here).
		var controls: Array[Control] = _controls(screen._stage)
		controls.append_array(_controls(screen._stage.world))
		assert_int(controls.size()).is_greater(150)
		for control: Control in controls:
			var rect: Rect2 = control.get_global_rect()
			(
				assert_bool(stage.encloses(rect))
				. override_failure_message("%s: %s %s" % [scan, control.get_path(), rect])
				. is_true()
			)
		# The props by name: the register's parts, the monitor's and the CLOSED cell's.
		var named: Array[Control] = _controls(screen._cabinet)
		named.append_array(_controls(screen._stage.monitor))
		assert_int(screen._row_strip.closed.size()).is_equal(1)
		for closed: Control in screen._row_strip.closed:
			named.append(closed)
			named.append_array(_controls(closed))
		for control: Control in named:
			(
				assert_bool(stage.encloses(control.get_global_rect()))
				. override_failure_message("%s: %s" % [scan, control.get_path()])
				. is_true()
			)


## The top bar's chips and buttons (SHIFT, QUOTA, the inspection when there is one, LOYALTY,
## Cart and the menu): apart, under the stage's top edge and above the belt.
func test_the_top_bar_parts_are_apart_above_the_belt() -> void:
	for scan: String in SCANS:
		var screen: ShiftScreen = await _captured(scan)
		var parts: Array[Rect2] = []
		for child: Node in screen._stage.top_bar.get_children():
			var part: Control = child as Control
			if part != null and part.visible and part.size.x > 0.0:
				parts.append(part.get_global_rect())
		var inspected: int = 1 if screen._inspection_tag.visible else 0
		assert_int(parts.size()).is_equal(5 + inspected)
		var bottom: float = _y(screen, ShiftStage.TOP_BAR_BOTTOM)
		for rect: Rect2 in parts:
			assert_float(rect.end.y).override_failure_message(str(rect)).is_less_equal(bottom)
			assert_float(rect.end.y).is_less_equal(_y(screen, ShiftStage.BELT_RECT.position.y))
		_assert_apart(parts, "top bar")


## Every cell (the CLOSED one too) lies on the belt, apart from the others; each belt item's
## sprite stands on the belt's top face and its ticket on the rail. The hand's basket items lie
## inside the hand's area, apart, with no sticker shown.
func test_cells_lie_inside_the_belt_and_the_tray() -> void:
	for scan: String in SCANS:
		var screen: ShiftScreen = await _captured(scan)
		var belt_panel: BeltPanel = screen._stage.belt
		var belt_rect: Rect2 = belt_panel.get_global_rect()
		var top_face: Rect2 = belt_panel.get_global_transform() * belt_panel.top_face()
		var rail: Rect2 = belt_panel.get_global_transform() * belt_panel.rail()
		var cells: Array[Rect2] = []
		for panel: PanelContainer in screen._row_strip.slots + screen._row_strip.closed:
			var rect: Rect2 = panel.get_global_rect()
			cells.append(rect)
			assert_float(rect.position.x).is_greater_equal(belt_rect.position.x)
			assert_float(rect.end.x).is_less_equal(belt_rect.end.x)
			assert_float(rect.end.y).is_less_equal(rail.end.y)
		# Short belt: 6 of the 7 general slots open, one CLOSED.
		assert_int(cells.size()).is_equal(7)
		_assert_apart(cells, "belt cells")
		var belt: Array[ItemView] = _belt_items(screen)
		assert_int(belt.size()).is_equal(4)
		for view: ItemView in belt:
			var foot: Vector2 = view.sprite().get_global_rect().end - Vector2(1, 1)
			assert_bool(top_face.has_point(foot)).override_failure_message(str(foot)).is_true()
			var ticket: Rect2 = view.sticker().get_global_rect()
			assert_bool(rail.encloses(ticket)).override_failure_message(str(ticket)).is_true()
		var area: Rect2 = _on_stage(screen, ShiftStage.HAND_AREA)
		var items: Array[Rect2] = []
		for view: ItemView in _hand_items(screen):
			var rect: Rect2 = view.get_global_rect()
			items.append(rect)
			assert_bool(area.encloses(rect)).override_failure_message(str(rect)).is_true()
			assert_bool(view.sticker().visible).is_false()
			assert_bool(area.encloses(view.sprite().get_global_rect())).is_true()
		assert_int(items.size()).is_equal(8)
		_assert_apart(items, "basket items")


## No ticket covers another ticket or a sprite (lifted or not), and no planning part (#71, mock-up
## h1: a sticker, a pay tag or a stamp; planning shows no corner mark) covers any ticket's struck
## price or summary text: a pay tag may sit on a ticket's top band only.
func test_stickers_never_cover_a_sticker_a_sprite_or_a_mark() -> void:
	for scan: String in SCANS:
		var screen: ShiftScreen = await _captured(scan)
		var stickers: Array[Rect2] = []
		var others: Array[Rect2] = []
		var texts: Array[Rect2] = []
		for view: ItemView in _belt_items(screen) + _hand_items(screen):
			if view.sticker().visible:
				var ticket: PriceSticker = view.sticker()
				stickers.append(ticket.get_global_rect())
				var to_global: Transform2D = ticket.get_global_transform()
				if ticket.is_struck():
					texts.append(to_global * ticket.struck_rect())
				if ticket.summary_text_rect().has_area():
					texts.append(to_global * ticket.summary_text_rect())
			others.append(view.sprite().get_global_rect())
			assert_object(view._mark).override_failure_message(scan).is_null()
		assert_int(stickers.size()).is_equal(4)
		var parts: Array[Control] = screen._stage.planning_layer.parts()
		assert_int(parts.size()).override_failure_message(scan).is_greater_equal(1)
		for part: Control in parts:
			var rect: Rect2 = part.get_global_rect()
			for text: Rect2 in texts:
				(
					assert_bool(rect.intersects(text))
					. override_failure_message("%s: %s %s over %s" % [scan, part.name, rect, text])
					. is_false()
				)
		_assert_apart(stickers, "stickers")
		for sticker: Rect2 in stickers:
			for other: Rect2 in others:
				(
					assert_bool(sticker.intersects(other))
					. override_failure_message("%s: %s over %s" % [scan, sticker, other])
					. is_false()
				)


## Planning shows no paid chip (#80, step 7: the receipt lists the payouts) and no corner mark
## (#71); each belt item wears one sticker per effect it receives in the preview's model (shown,
## or folded into "…+N"), and the coupon's fizzles show as a "WASTED" sticker.
func test_planning_shows_marks_and_no_paid_chips() -> void:
	var screen: ShiftScreen = await _captured("")
	var result: ScoreResult = screen.run.preview()
	var model: PlanningModel = screen._effects.committed_model()
	var layer: PlanningLayer = screen._stage.planning_layer
	var belt: Array[ItemView] = _belt_items(screen)
	assert_int(belt.size()).is_equal(result.payouts.size())
	assert_int(model.slots.size()).is_equal(belt.size())
	var fizzles: int = 0
	for slot: int in range(belt.size()):
		assert_bool(belt[slot].badge.visible).is_false()
		assert_object(belt[slot]._mark).is_null()
		var shown: Array[EffectSticker] = layer.stack(slot)
		var expected: int = model.slots[slot].stickers.size()
		var folded: int = 0
		if not shown.is_empty() and shown[0].spec().kind == StickerSpec.Kind.MORE:
			folded = expected - (shown.size() - 1)
		var counted: int = shown.size() - (1 if folded > 0 else 0) + folded
		assert_int(counted).override_failure_message(str(slot)).is_equal(expected)
		for sticker: EffectSticker in shown:
			if sticker.spec().kind == StickerSpec.Kind.FIZZLE:
				fizzles += 1
	# Multipack, the coupon, fizzles here.
	assert_int(fizzles).is_greater_equal(1)


## Every character the screen prints, the items' stickers, the CLOSED cell and the
## monitor's scan text too, is in the font that prints it.
func test_every_printed_character_has_its_glyph() -> void:
	var checked: int = 0
	var printed: PackedStringArray = PackedStringArray()
	for scan: String in SCANS:
		var screen: ShiftScreen = await _captured(scan)
		for label: Label in _labels(screen):
			printed.append(label.text)
			var font: Font = label.get_theme_font("font")
			for character: String in label.text:
				if character.strip_edges().is_empty():
					continue
				checked += 1
				var code: int = character.unicode_at(0)
				(
					assert_bool(font.has_char(code))
					. override_failure_message(
						"%s lacks '%s' (U+%04X) in %s" % [font, character, code, label.get_path()]
					)
					. is_true()
				)
	# The basket items show no stickers (#80, step 8), and the counter no hint lines (step 12):
	# only the belt's tickets print item text.
	assert_int(checked).is_greater(1000)
	var chip: String = "Inspection · %s" % load("res://data/inspections/short_belt.tres").chip_text
	var caption: String = RowStrip.CLOSED_CAPTION_TEXT
	for required: String in [RowStrip.CLOSED_TEXT, "COUPON", caption, chip, "5", "6", "Multipack"]:
		assert_bool(printed.has(required)).override_failure_message(required).is_true()


## No text goes through the sharp-pixel material (the monitor's scan included; the gold number's
## own gold-bands shader aside), and the sharp-pixel switch (ArtStyle.set_sharp, the capture's S
## key) reaches every piece of art, items too.
func test_text_never_carries_the_pixel_material() -> void:
	for scan: String in SCANS:
		var screen: ShiftScreen = await _captured(scan)
		for label: Label in _labels(screen):
			# The checkout column's gold number has its gold-bands shader (TotalNumber), no other.
			var gold: bool = (
				label.material is ShaderMaterial
				and (label.material as ShaderMaterial).shader == TotalNumber.SHADER
			)
			if not gold:
				(
					assert_object(label.material)
					. override_failure_message(str(label.get_path()))
					. is_null()
				)
			assert_bool(label.has_meta(ArtStyle.PIXEL_ART_META)).is_false()
		var marked: Array[CanvasItem] = _pixel_art(screen)
		assert_int(marked.size()).is_greater(60)
		var sprites: int = 0
		for view: ItemView in _belt_items(screen) + _hand_items(screen):
			if marked.has(view.sprite()):
				sprites += 1
		assert_int(sprites).is_equal(12)
		# A grey or a halo (#71) is the node's look, kept in both modes.
		ArtStyle.set_sharp(screen, false)
		for item: CanvasItem in marked:
			if item.has_meta(ArtStyle.LOOK_META):
				assert_object(item.material).is_same(_look(item, null))
			else:
				assert_object(item.material).is_null()
		ArtStyle.set_sharp(screen, true)
		for item: CanvasItem in marked:
			assert_object(item.material).is_same(_look(item, ArtStyle.pixel_material()))


# --- Helpers ---------------------------------------------------------------------------------


## `item`'s look material (ArtStyle.set_look), else `plain`.
static func _look(item: CanvasItem, plain: Material) -> Material:
	if item.has_meta(ArtStyle.LOOK_META):
		return item.get_meta(ArtStyle.LOOK_META) as Material
	return plain


## The capture's shift, laid out, with `scan`'s item scanned ("" for none).
func _captured(scan: String) -> ShiftScreen:
	var capture: Control = scene_runner(CAPTURE).scene()
	capture.set("report_error", _record)
	await _frames(3)
	var screen: ShiftScreen = capture.call("screen")
	if scan != "":
		await capture.call("scan", scan)
		await _frames(2)
		var scanned: ItemView = screen._scan.scanned()
		assert_object(scanned).override_failure_message(scan).is_not_null()
		assert_str(scanned.card.definition.id).is_equal(scan)
		assert_int(screen._monitor.mode()).is_equal(MonitorView.Mode.SCAN)
	assert_array(_errors).is_empty()
	return screen


static func _belt_items(screen: ShiftScreen) -> Array[ItemView]:
	var items: Array[ItemView] = []
	for view: CardView in screen._row_views:
		items.append(view as ItemView)
	return items


static func _hand_items(screen: ShiftScreen) -> Array[ItemView]:
	var items: Array[ItemView] = []
	for view: Control in screen._hand_box.cards():
		items.append(view as ItemView)
	return items


## Every visible control under `node` with a size, internal children included.
static func _controls(node: Node) -> Array[Control]:
	var found: Array[Control] = []
	for child: Node in node.get_children(true):
		var control: Control = child as Control
		if control == null or not control.is_visible_in_tree():
			continue
		if control.size.x > 0.0 and control.size.y > 0.0:
			found.append(control)
		found.append_array(_controls(control))
	return found


## Every visible label with text under `node`, internal children included.
static func _labels(node: Node) -> Array[Label]:
	var found: Array[Label] = []
	for control: Control in _controls(node):
		var label: Label = control as Label
		if label != null and not label.text.is_empty():
			found.append(label)
	return found


static func _pixel_art(node: Node) -> Array[CanvasItem]:
	var found: Array[CanvasItem] = []
	var item: CanvasItem = node as CanvasItem
	if item != null and item.has_meta(ArtStyle.PIXEL_ART_META):
		found.append(item)
	for child: Node in node.get_children():
		found.append_array(_pixel_art(child))
	return found


func _assert_apart(rects: Array[Rect2], what: String) -> void:
	for first: int in range(rects.size()):
		for second: int in range(first + 1, rects.size()):
			(
				assert_bool(rects[first].intersects(rects[second]))
				. override_failure_message(
					"%s overlap: %s %s" % [what, rects[first], rects[second]]
				)
				. is_false()
			)


## `rect` (stage coordinates) on screen.
static func _on_stage(screen: ShiftScreen, rect: Rect2) -> Rect2:
	return Rect2(screen._stage.get_global_rect().position + rect.position, rect.size)


static func _y(screen: ShiftScreen, stage_y: float) -> float:
	return screen._stage.get_global_rect().position.y + stage_y


func _record(message: String) -> void:
	_errors.append(message)


func _frames(count: int) -> void:
	for _frame: int in range(count):
		await get_tree().process_frame


static func _event_log() -> EventLogService:
	return (Engine.get_main_loop() as SceneTree).root.get_node("/root/EventLog")
