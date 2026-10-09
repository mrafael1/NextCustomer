class_name StyleFrame
extends Control
## The art style frame (full build plan section 6.1, issue #21): the shift screen in the final
## pixel-art style, on a fixed shift 3 of 8 (inspected, one upgrade stamped). The row is scored
## by core/ and CHECKOUT plays the real count-up and receipt, so the motion is the game's own.
## The real shift screen is untouched; it adopts the style in phase 3.
##
## Keys: Enter or CHECKOUT plays the count-up (tap or hold as in the game); R resets; S switches
## between the sharp-pixel shader and plain nearest filtering (A/B); Tab shows Milk at its
## three sizes. `godot --path . res://debug/style_frame/style_frame.tscn -- --capture=<folder>`
## saves the frame and the sizes panel as PNGs at the window's size, then quits.

## A fixed row and hand (card ids in data/cards), chosen to show stamps, a fizzle, the
## inspection and Milk's sprite. Together they are one drawn hand (balance hand_size), placed
## all but two, so the frame shows a state the game can reach, with one slot still empty.
const ROW_IDS: Array[String] = ["eggs", "milk", "bread", "multipack", "cheese", "banana"]
const HAND_IDS: Array[String] = ["banana", "coffee"]
const CARD_PATH := "res://data/cards/%s.tres"
const UPGRADE := preload("res://data/upgrades/coupon_engine.tres")
const INSPECTION := preload("res://data/inspections/spot_check.tres")
const BALANCE := preload("res://data/balance/balance.tres")
const SHIFT := 3
const MILK_ID := "milk"

const STAGE_SIZE := Vector2(1280, 720)
const MARGIN := 20.0
const SLOT_GAP := 10
const BELT_POSITION := Vector2(20, 96)
const BELT_PADDING := Vector4(8, 18, 8, 16)
const COUNTER_TOP := 376.0
const HAND_POSITION := Vector2(40, 404)
const REGISTER_X := 948.0
## The receipt is as wide as the real screen's (300), so its lines wrap the same way.
const RECEIPT_WIDTH := 300.0
## The receipt hangs from the printer's slot over the counter, long enough for a full row.
const RECEIPT_HEIGHT := 594.0
const STAMP_SIZE := Vector2(34, 34)
const STAMP_TILT := -6.0
const CAPTURE_ARGUMENT := "--capture="
const CAPTURE_SETTLE_FRAMES := 8

const WALL_TILE := preload("res://art/scenery/wall_tile.png")
const SALE_BURST := preload("res://art/scenery/sale_burst.png")
const BELT_FRAME := preload("res://art/frames/belt.png")
const COUNTER_FRAME := preload("res://art/frames/counter.png")
const PRINTER_FRAME := preload("res://art/frames/printer.png")
const SIGN_FRAME := preload("res://art/frames/sign.png")
const TAG_FRAME := preload("res://art/frames/inspection_tag.png")
const BUTTON_FRAME := preload("res://art/frames/button.png")
const LOYALTY_FRAME := preload("res://art/frames/loyalty_card.png")
const CARD_FRAME := preload("res://art/frames/card.png")
const SLOT_EMPTY := preload("res://art/frames/slot_empty.png")
const RECEIPT_PAPER := preload("res://art/frames/receipt_paper.png")
const STAMP_EMPTY := preload("res://art/icons/stamp_empty.png")
const STAMP_COUPON_ENGINE := preload("res://art/icons/stamp_coupon_engine.png")

var _row: Array[CardInstance] = []
var _result: ScoreResult
var _stage: Control
var _belt: PanelContainer
var _row_box: HBoxContainer
var _row_views: Array[CardView] = []
var _hand_box: HBoxContainer
var _receipt: ReceiptView
var _subtotal_label: Label
var _projected_label: Label
var _checkout_button: Button
var _stamp: TextureRect
var _tag: PanelContainer
var _sizes_panel: PanelContainer
var _sizes_shade: ColorRect
var _overlay: Control
var _count_up: CountUp
var _counting: bool = false
var _sharp: bool = true
var _tumble: Tween


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	# Text without its own font (the count-up's flying numbers, stamps and verdict) uses the
	# number font.
	theme = Theme.new()
	theme.default_font = ArtStyle.number_font()
	var next_id: int = 1
	for card_id: String in ROW_IDS:
		_row.append(CardInstance.new(_card(card_id), next_id))
		next_id += 1
	_result = Scoring.score(_row, _upgrades(), _inspections())
	_build()
	_show_planning()
	var folder: String = _capture_folder()
	if folder != "":
		_capture(folder)


func _unhandled_key_input(event: InputEvent) -> void:
	var key: InputEventKey = event as InputEventKey
	if key == null or not key.pressed or key.echo:
		return
	match key.keycode:
		KEY_ENTER, KEY_KP_ENTER:
			_on_checkout_pressed()
		KEY_R:
			if not _counting:
				_show_planning()
		KEY_S:
			_set_sharp(not _sharp)
		KEY_TAB:
			_show_sizes(not _sizes_panel.visible)
		_:
			return
	get_viewport().set_input_as_handled()


func _on_checkout_pressed() -> void:
	if _counting:
		return
	_counting = true
	_set_enabled(_checkout_button, false)
	_show_sizes(false)
	_projected_label.text = ""
	var stamps: Array[Control] = [_stamp]
	var tags: Array[Control] = [_tag]
	await _count_up.play(
		_result,
		_row_views,
		_names(_row),
		_quota(),
		stamps,
		LoyaltyCard.names(_upgrades()),
		tags,
		InspectionTag.names(_inspections()),
		""
	)
	_counting = false
	_set_enabled(_checkout_button, true)


## The planning state: the receipt's preview, each card's projected payout and tags.
func _show_planning() -> void:
	_receipt.show_result(
		_result, _names(_row), LoyaltyCard.names(_upgrades()), InspectionTag.names(_inspections())
	)
	for slot: int in range(_row_views.size()):
		var view: CardView = _row_views[slot]
		view.reset_motion()
		view.show_badge(_result.payouts[slot], false)
		view.set_tags(_result.tags[slot])
	_subtotal_label.text = ""
	_projected_label.text = "Projected €%d" % _result.total
	_projected_label.add_theme_color_override(
		"font_color", Palette.GOOD if _result.total >= _quota() else Palette.TOMATO
	)


func _build() -> void:
	var wall: TextureRect = _tiled(WALL_TILE)
	wall.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(wall)
	var counter: PanelContainer = _panel(COUNTER_FRAME, 3)
	counter.set_anchors_preset(Control.PRESET_FULL_RECT)
	counter.anchor_top = 0.5
	counter.offset_top = COUNTER_TOP - STAGE_SIZE.y / 2.0
	counter.offset_bottom = 8
	counter.offset_left = -8
	counter.offset_right = 8
	add_child(counter)

	# Everything else sits on a 1280x720 stage centred in the window, so a wider window only
	# shows more wall and counter.
	_stage = Control.new()
	_stage.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_stage.set_anchors_preset(Control.PRESET_CENTER)
	_stage.size = STAGE_SIZE
	_stage.position = -STAGE_SIZE / 2.0
	add_child(_stage)
	_build_top_bar()
	_build_belt()
	_build_row_status()
	_build_hand()
	_build_register()

	_overlay = Control.new()
	_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_overlay)
	var sfx: Sfx = Sfx.new()
	add_child(sfx)
	_count_up = CountUp.new()
	add_child(_count_up)
	_count_up.setup(_overlay, _receipt, _subtotal_label, sfx, _row_box)
	_build_sizes_panel()


func _build_top_bar() -> void:
	var shift_sign: PanelContainer = _panel(SIGN_FRAME, 3, Vector4(14, 4, 14, 6))
	shift_sign.position = Vector2(MARGIN, 10)
	_stage.add_child(shift_sign)
	var sign_row: HBoxContainer = HBoxContainer.new()
	sign_row.add_theme_constant_override("separation", 18)
	shift_sign.add_child(sign_row)
	sign_row.add_child(_display("SHIFT", 20, true))
	sign_row.add_child(_number("%d / %d" % [SHIFT, BALANCE.quotas.size()], 20, true))
	sign_row.add_child(_display("QUOTA", 20, true))
	sign_row.add_child(_number("€%d" % _quota(), 20, true))

	var card: PanelContainer = _panel(LOYALTY_FRAME, 3, Vector4(10, 6, 8, 4))
	card.position = Vector2(320, 6)
	_stage.add_child(card)
	var card_row: HBoxContainer = HBoxContainer.new()
	card_row.add_theme_constant_override("separation", 6)
	card.add_child(card_row)
	var title: Label = _display("LOYALTY\nCARD", 11, false)
	title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	card_row.add_child(title)
	# One box per upgrade shift, as on the real loyalty card.
	for index: int in range(BALANCE.upgrade_shifts.size()):
		var box: TextureRect = _sprite(STAMP_COUPON_ENGINE if index == 0 else STAMP_EMPTY)
		box.custom_minimum_size = STAMP_SIZE
		box.pivot_offset = STAMP_SIZE / 2.0
		if index == 0:
			box.rotation_degrees = STAMP_TILT
			box.tooltip_text = LoyaltyCard.tooltip_for(UPGRADE)
			box.mouse_filter = Control.MOUSE_FILTER_PASS
			_stamp = box
		card_row.add_child(box)

	_tag = _panel(TAG_FRAME, 3, Vector4(10, 4, 10, 5))
	_tag.position = Vector2(540, 12)
	_tag.tooltip_text = INSPECTION.notice_text
	_tag.mouse_filter = Control.MOUSE_FILTER_PASS
	_stage.add_child(_tag)
	_tag.add_child(_display("INSPECTED · %s" % INSPECTION.display_name.to_upper(), 16, true))

	var poster: TextureRect = _sprite(SALE_BURST)
	poster.custom_minimum_size = Vector2(64, 64)
	poster.size = Vector2(64, 64)
	poster.position = Vector2(860, 14)
	poster.pivot_offset = Vector2(32, 32)
	poster.rotation_degrees = 8.0
	_stage.add_child(poster)


func _build_belt() -> void:
	_belt = PanelContainer.new()
	_belt.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ArtStyle.use_pixel_material(_belt)
	var style: StyleBoxTexture = StyleBoxTexture.new()
	style.texture = BELT_FRAME
	style.texture_margin_top = 4 * ArtStyle.ART_SCALE
	style.texture_margin_bottom = 3 * ArtStyle.ART_SCALE
	style.axis_stretch_horizontal = StyleBoxTexture.AXIS_STRETCH_MODE_TILE
	style.axis_stretch_vertical = StyleBoxTexture.AXIS_STRETCH_MODE_TILE
	style.content_margin_left = BELT_PADDING.x
	style.content_margin_top = BELT_PADDING.y
	style.content_margin_right = BELT_PADDING.z
	style.content_margin_bottom = BELT_PADDING.w
	_belt.add_theme_stylebox_override("panel", style)
	_belt.position = BELT_POSITION
	_stage.add_child(_belt)
	_row_box = HBoxContainer.new()
	_row_box.add_theme_constant_override("separation", SLOT_GAP)
	_belt.add_child(_row_box)
	for card: CardInstance in _row:
		var view: ArtCardView = ArtCardView.new(card)
		_row_views.append(view)
		_row_box.add_child(view)
	for _slot: int in range(RowCapacity.card_limit(_limits()) - _row.size()):
		var empty: TextureRect = _sprite(SLOT_EMPTY)
		empty.custom_minimum_size = ArtCardView.SIZE
		_row_box.add_child(empty)


func _build_row_status() -> void:
	var status: Label = _body(
		(
			"Products %d/%d · Coupon slot %d/%d"
			% [
				RowCapacity.product_count(_row),
				_limits().slot_count,
				RowCapacity.coupon_slots_used(_limits(), _row),
				_limits().coupon_slot_count,
			]
		),
		14
	)
	status.position = Vector2(MARGIN + 8, 342)
	_stage.add_child(status)
	_projected_label = _number("", 22, true)
	_projected_label.position = Vector2(330, 334)
	_stage.add_child(_projected_label)
	_subtotal_label = _number("", 40, true)
	_subtotal_label.add_theme_constant_override("outline_size", 8)
	_subtotal_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_subtotal_label.position = Vector2(560, 326)
	_subtotal_label.size = Vector2(240, 48)
	_subtotal_label.pivot_offset = _subtotal_label.size / 2.0
	_stage.add_child(_subtotal_label)


func _build_hand() -> void:
	_hand_box = HBoxContainer.new()
	_hand_box.add_theme_constant_override("separation", SLOT_GAP)
	_hand_box.position = HAND_POSITION
	_stage.add_child(_hand_box)
	var next_id: int = 100
	for card_id: String in HAND_IDS:
		_hand_box.add_child(ArtCardView.new(CardInstance.new(_card(card_id), next_id)))
		next_id += 1
	var hint: Label = _body("tap Space or the mouse to skip the count, hold to fast-forward", 13)
	hint.add_theme_color_override("font_color", ArtStyle.INK)
	hint.position = Vector2(HAND_POSITION.x, HAND_POSITION.y + ArtCardView.SIZE.y + 14)
	_stage.add_child(hint)

	_checkout_button = _button("CHECKOUT", 28, BUTTON_FRAME, Vector2(220, 72))
	_checkout_button.position = Vector2(712, 412)
	_checkout_button.pressed.connect(_on_checkout_pressed)
	_stage.add_child(_checkout_button)
	var redraw_text: String = (
		"Redraw up to %d (%d left)" % [BALANCE.redraw_limit, _limits().redraws]
	)
	var redraw: Button = _button(redraw_text, 15, SIGN_FRAME, Vector2(220, 44))
	(redraw.get_child(1) as Label).add_theme_font_override("font", ArtStyle.number_font())
	redraw.position = Vector2(712, 500)
	# Decoration: disabled, so a click on it during the count-up still counts as a tap.
	_set_enabled(redraw, false)
	_stage.add_child(redraw)


func _build_register() -> void:
	var printer: PanelContainer = _panel(PRINTER_FRAME, 4, Vector4(14, 8, 14, 12))
	printer.position = Vector2(REGISTER_X, 82)
	printer.custom_minimum_size = Vector2(STAGE_SIZE.x - REGISTER_X - MARGIN, 0)
	_stage.add_child(printer)
	var name_label: Label = _display("NEXT CUSTOMER · REGISTER 3", 13, false)
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	printer.add_child(name_label)
	_receipt = ReceiptView.new()
	var paper: StyleBoxTexture = ArtStyle.frame_style(RECEIPT_PAPER, 2)
	paper.set_content_margin_all(14)
	_receipt.add_theme_stylebox_override("panel", paper)
	ArtStyle.use_pixel_material(_receipt)
	_receipt.position = Vector2(
		REGISTER_X + (printer.custom_minimum_size.x - RECEIPT_WIDTH) / 2.0, 120
	)
	_receipt.size = Vector2(RECEIPT_WIDTH, RECEIPT_HEIGHT)
	_stage.add_child(_receipt)
	_stage.move_child(_receipt, printer.get_index())


## Milk at its three sizes: alone (1x, the conveyor and the shelf), on its card (2x) and
## tumbling into the bag (1x to 2x, any rotation).
func _build_sizes_panel() -> void:
	_sizes_shade = ColorRect.new()
	_sizes_shade.color = Color(ArtStyle.INK, 0.6)
	_sizes_shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	_sizes_shade.visible = false
	add_child(_sizes_shade)
	_sizes_panel = _panel(CARD_FRAME, 3, Vector4(24, 16, 24, 20))
	_sizes_panel.visible = false
	_sizes_panel.set_anchors_preset(Control.PRESET_CENTER)
	add_child(_sizes_panel)
	var column: VBoxContainer = VBoxContainer.new()
	column.add_theme_constant_override("separation", 12)
	_sizes_panel.add_child(column)
	column.add_child(_display("MILK AT ITS THREE SIZES", 22, false))
	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override("separation", 40)
	column.add_child(row)
	var milk: Texture2D = ArtStyle.item_texture(_card(MILK_ID))
	row.add_child(_size_sample(milk, 1, "alone · 1x"))
	row.add_child(_size_sample(milk, 2, "on its card · 2x"))
	var tumble_box: Control = _size_sample(milk, 2, "tumbling · 1x to 2x")
	row.add_child(tumble_box)
	var card_row: HBoxContainer = HBoxContainer.new()
	card_row.alignment = BoxContainer.ALIGNMENT_CENTER
	column.add_child(card_row)
	card_row.add_child(ArtCardView.new(CardInstance.new(_card(MILK_ID), 999)))
	_sizes_panel.resized.connect(
		func() -> void: _sizes_panel.position = (size - _sizes_panel.size) / 2.0
	)
	var sprite: TextureRect = tumble_box.get_child(0).get_child(0) as TextureRect
	sprite.pivot_offset = sprite.custom_minimum_size / 2.0
	_tumble = create_tween().set_loops()
	_tumble.tween_property(sprite, "rotation_degrees", 360.0, 1.2).from(0.0)
	_tumble.parallel().tween_property(sprite, "scale", Vector2.ONE, 1.2).from(Vector2(0.5, 0.5))
	_tumble.tween_interval(0.4)
	_tumble.pause()


func _size_sample(texture: Texture2D, art_scale: int, caption: String) -> Control:
	var column: VBoxContainer = VBoxContainer.new()
	column.add_theme_constant_override("separation", 6)
	var holder: CenterContainer = CenterContainer.new()
	holder.custom_minimum_size = Vector2(96, 96)
	column.add_child(holder)
	var sprite: TextureRect = _sprite(texture)
	sprite.custom_minimum_size = texture.get_size() * art_scale
	holder.add_child(sprite)
	var label: Label = _body(caption, 13)
	label.add_theme_color_override("font_color", ArtStyle.INK)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(label)
	return column


func _show_sizes(shown: bool) -> void:
	_sizes_panel.visible = shown
	_sizes_shade.visible = shown
	if shown:
		_sizes_panel.position = (size - _sizes_panel.size) / 2.0
		_tumble.play()
	else:
		_tumble.pause()


## A/B: the sharp-pixel shader, or plain nearest filtering without it.
func _set_sharp(sharp: bool) -> void:
	_sharp = sharp
	_apply_sharp(self)


func _apply_sharp(node: Node) -> void:
	var item: CanvasItem = node as CanvasItem
	if item != null and item.has_meta(ArtStyle.PIXEL_ART_META):
		item.material = ArtStyle.pixel_material() if _sharp else null
		item.texture_filter = (
			CanvasItem.TEXTURE_FILTER_PARENT_NODE if _sharp else CanvasItem.TEXTURE_FILTER_NEAREST
		)
	for child: Node in node.get_children():
		_apply_sharp(child)


func _capture(folder: String) -> void:
	DirAccess.make_dir_recursive_absolute(folder)
	for _frame: int in range(CAPTURE_SETTLE_FRAMES):
		await RenderingServer.frame_post_draw
	var window: Vector2i = get_window().size
	_save_screen(folder.path_join("style_frame_%dx%d.png" % [window.x, window.y]))
	_show_sizes(true)
	for _frame: int in range(CAPTURE_SETTLE_FRAMES):
		await RenderingServer.frame_post_draw
	_save_screen(folder.path_join("style_frame_sizes_%dx%d.png" % [window.x, window.y]))
	get_tree().quit()


func _save_screen(path: String) -> void:
	var image: Image = get_viewport().get_texture().get_image()
	var error: Error = image.save_png(path)
	if error != OK:
		push_error("Can't save %s (error %d)" % [path, error])


func _capture_folder() -> String:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with(CAPTURE_ARGUMENT):
			return argument.trim_prefix(CAPTURE_ARGUMENT)
	return ""


func _quota() -> int:
	return _limits().quota


## The shift's limits, as the game computes them (ShiftLimits).
func _limits() -> ShiftLimits:
	return ShiftLimits.for_shift(BALANCE, _upgrades(), SHIFT - 1)


func _upgrades() -> Array[UpgradeDefinition]:
	return [UPGRADE]


func _inspections() -> Array[InspectionDefinition]:
	return [INSPECTION]


static func _card(card_id: String) -> CardDefinition:
	return load(CARD_PATH % card_id) as CardDefinition


static func _names(cards: Array[CardInstance]) -> PackedStringArray:
	var names: PackedStringArray = PackedStringArray()
	for card: CardInstance in cards:
		names.append(card.definition.display_name)
	return names


## A pixel-art TextureRect at the texture's own size (frames are pre-scaled; sprites are 1x).
func _sprite(texture: Texture2D) -> TextureRect:
	var sprite: TextureRect = TextureRect.new()
	sprite.texture = texture
	sprite.mouse_filter = Control.MOUSE_FILTER_IGNORE
	sprite.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	sprite.stretch_mode = TextureRect.STRETCH_SCALE
	ArtStyle.use_pixel_material(sprite)
	return sprite


func _tiled(texture: Texture2D) -> TextureRect:
	var tiled: TextureRect = _sprite(texture)
	tiled.stretch_mode = TextureRect.STRETCH_TILE
	tiled.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	return tiled


## A panel drawn with a 9-slice frame. `margin` is the frame's margin in art pixels; `padding`
## is left, top, right, bottom in canvas pixels (defaults to the frame margin).
func _panel(
	texture: Texture2D, margin: int, padding: Vector4 = Vector4(-1, -1, -1, -1)
) -> PanelContainer:
	var panel: PanelContainer = PanelContainer.new()
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style: StyleBoxTexture = ArtStyle.frame_style(texture, margin)
	if padding.x >= 0:
		style.content_margin_left = padding.x
		style.content_margin_top = padding.y
		style.content_margin_right = padding.z
		style.content_margin_bottom = padding.w
	panel.add_theme_stylebox_override("panel", style)
	ArtStyle.use_pixel_material(panel)
	return panel


## A button drawn with a 9-slice frame. The frame is a child panel with the sharp-pixel
## material and the text a child label, so the shader never touches the font.
func _button(text: String, font_size: int, frame: Texture2D, button_size: Vector2) -> Button:
	var button: Button = Button.new()
	button.flat = true
	button.focus_mode = Control.FOCUS_NONE
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	button.custom_minimum_size = button_size
	var face: PanelContainer = _panel(frame, 3)
	face.set_anchors_preset(Control.PRESET_FULL_RECT)
	button.add_child(face)
	var label: Label = _display(text, font_size, true)
	label.set_anchors_preset(Control.PRESET_FULL_RECT)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	# The frame's ledge is its bottom 2 art pixels: centre the text on the face above it.
	label.offset_bottom = -2 * ArtStyle.ART_SCALE
	button.add_child(label)
	button.button_down.connect(func() -> void: face.modulate = Color(0.85, 0.85, 0.85))
	button.button_up.connect(func() -> void: face.modulate = Color.WHITE)
	return button


## Enables or disables a framed button and dims it while disabled (its look comes from its child
## face and label, which a disabled flat Button doesn't change).
static func _set_enabled(button: Button, enabled: bool) -> void:
	button.disabled = not enabled
	button.modulate = Color.WHITE if enabled else Color(0.75, 0.75, 0.75)


## Display-font text: light with an ink outline (on signs and the wall), or plain ink.
func _display(text: String, font_size: int, light: bool) -> Label:
	var label: Label = Label.new()
	label.text = text
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_override("font", ArtStyle.DISPLAY_FONT)
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", Palette.PAPER if light else ArtStyle.INK)
	label.add_theme_constant_override("line_spacing", 0)
	if light:
		label.add_theme_constant_override("outline_size", 6)
		label.add_theme_color_override("font_outline_color", ArtStyle.INK)
	return label


## Numbers and money: the number font, light with an ink outline or plain ink.
func _number(text: String, font_size: int, light: bool) -> Label:
	var label: Label = _display(text, font_size, light)
	label.add_theme_font_override("font", ArtStyle.number_font())
	return label


func _body(text: String, font_size: int) -> Label:
	var label: Label = Label.new()
	label.text = text
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_override("font", ArtStyle.BODY_FONT)
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", Palette.PAPER)
	return label
