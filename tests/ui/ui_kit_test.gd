extends GdUnitTestSuite
## The shared pixel-art kit (#55, full build plan section 6.1): FramedButton's normal, hover,
## pressed and disabled looks (disabled shown by a sunk face, not by colour alone), its caption
## and enabled state, no keyboard focus (Space never presses it), the sharp-pixel material on
## art and never on text, the labels' fonts by role, the notice style, the screen theme and the
## palette's ink and light text, and the boutique frames (#55: Redraw's and CHECKOUT's faces on
## the same ledge as the tomato button) and the cream insets.

const RecordingSfx := preload("res://tests/presentation/recording_sfx.gd")

var _folder: String = ""


func before_test() -> void:
	_folder = "user://test_ui_kit_%d" % Time.get_ticks_usec()
	_event_log().use_folder(_folder)
	ProjectSettings.set_setting(SaveService.FOLDER_SETTING, _folder)


func after_test() -> void:
	ProjectSettings.set_setting(SaveService.FOLDER_SETTING, null)
	_remove_folder(_folder)


## Each state looks different, and disabled differs from normal in shape (the sunk face), not
## only in colour.
func test_framed_button_states() -> void:
	var button: FramedButton = _button()
	var looks: Dictionary[int, Array] = {}
	for mode: BaseButton.DrawMode in [
		BaseButton.DRAW_NORMAL,
		BaseButton.DRAW_HOVER,
		BaseButton.DRAW_PRESSED,
		BaseButton.DRAW_DISABLED,
	]:
		button._show_state(mode)
		looks[mode] = [button.face().offset_top, button.face().modulate, button.modulate]
	var normal: Array = looks[BaseButton.DRAW_NORMAL]
	assert_float(normal[0]).is_equal(0.0)
	assert_object(normal[1]).is_equal(Color.WHITE)
	assert_object(normal[2]).is_equal(Color.WHITE)
	assert_object(looks[BaseButton.DRAW_HOVER][1]).is_not_equal(Color.WHITE)
	assert_float(looks[BaseButton.DRAW_HOVER][0]).is_equal(0.0)
	assert_float(looks[BaseButton.DRAW_PRESSED][0]).is_equal(FramedButton.PRESS_DEPTH)
	assert_float(looks[BaseButton.DRAW_DISABLED][0]).is_equal(FramedButton.PRESS_DEPTH)
	assert_object(looks[BaseButton.DRAW_DISABLED][2]).is_equal(FramedButton.DISABLED_MODULATE)
	for mode: int in looks:
		for other: int in looks:
			if mode < other:
				assert_bool(looks[mode] == looks[other]).is_false()


## The caption sinks with the face, so it stays centred on it.
func test_the_caption_sinks_with_the_face() -> void:
	var button: FramedButton = _button()
	var label: Label = button.caption_label()
	var raised: float = label.offset_bottom - label.offset_top
	button._show_state(BaseButton.DRAW_PRESSED)
	assert_float(label.offset_top).is_equal(FramedButton.PRESS_DEPTH)
	assert_float(label.offset_bottom - label.offset_top).is_equal(raised)


## Hovering a live button (Button redraws on the state change) brightens its face.
func test_hover_follows_the_button() -> void:
	var button: FramedButton = _button()
	button.notification(Control.NOTIFICATION_MOUSE_ENTER)
	await await_idle_frame()
	assert_int(button.get_draw_mode()).is_equal(BaseButton.DRAW_HOVER)
	assert_object(button.face().modulate).is_equal(FramedButton.HOVER_FACE)
	button.notification(Control.NOTIFICATION_MOUSE_EXIT)
	await await_idle_frame()
	assert_object(button.face().modulate).is_equal(Color.WHITE)


## Button.disabled sets the look on the next draw; a disabled button drops the hand cursor.
func test_disabled_toggling() -> void:
	var button: FramedButton = _button()
	assert_int(button.mouse_default_cursor_shape).is_equal(Control.CURSOR_POINTING_HAND)
	button.disabled = true
	await await_idle_frame()
	assert_float(button.face().offset_top).is_equal(FramedButton.PRESS_DEPTH)
	assert_object(button.modulate).is_equal(FramedButton.DISABLED_MODULATE)
	assert_int(button.mouse_default_cursor_shape).is_equal(Control.CURSOR_ARROW)
	button.disabled = false
	await await_idle_frame()
	assert_float(button.face().offset_top).is_equal(0.0)
	assert_object(button.modulate).is_equal(Color.WHITE)
	assert_int(button.mouse_default_cursor_shape).is_equal(Control.CURSOR_POINTING_HAND)


## Mouse-only: no focus, so Space (the fast-forward key) never presses it; the button draws no
## text or stylebox of its own.
func test_framed_button_takes_no_focus() -> void:
	var button: FramedButton = _button()
	assert_int(button.focus_mode).is_equal(Control.FOCUS_NONE)
	assert_bool(button.flat).is_true()
	assert_str(button.text).is_empty()
	assert_str(button.accessibility_name).is_equal(button.caption)
	button.grab_focus()
	assert_bool(button.has_focus()).is_false()


## The face has the sharp-pixel material; the caption (text) and the button itself don't, and
## neither child takes the mouse from the button.
func test_no_material_on_text() -> void:
	var button: FramedButton = _button()
	assert_object(button.face().material).is_same(ArtStyle.pixel_material())
	assert_bool(button.face().has_meta(ArtStyle.PIXEL_ART_META)).is_true()
	assert_object(button.caption_label().material).is_null()
	assert_bool(button.caption_label().use_parent_material).is_false()
	assert_object(button.material).is_null()
	assert_int(button.face().mouse_filter).is_equal(Control.MOUSE_FILTER_IGNORE)
	assert_int(button.caption_label().mouse_filter).is_equal(Control.MOUSE_FILTER_IGNORE)
	for label: Label in [
		UiKit.display_label("A", 12, true),
		UiKit.number_label("€1", 12, true),
		UiKit.body_label("rule", 12),
		UiKit.receipt_label("1 Milk", 12),
	]:
		assert_object(label.material).is_null()
		label.free()


## The caption is text you can read and change; the button grows to fit it but keeps at least
## its requested size.
func test_caption_and_size() -> void:
	var button: FramedButton = _button()
	assert_str(button.caption).is_equal("CHECKOUT")
	assert_str(button.caption_label().text).is_equal("CHECKOUT")
	assert_vector(button.custom_minimum_size).is_equal(Vector2(220, 72))
	button.caption = "A MUCH LONGER CAPTION THAN THE BUTTON IS WIDE"
	assert_str(button.caption_label().text).is_equal(button.caption)
	assert_str(button.accessibility_name).is_equal(button.caption)
	assert_float(button.custom_minimum_size.x).is_greater(220.0)
	await await_idle_frame()
	var face: Rect2 = button.face().get_global_rect()
	assert_bool(face.encloses(button.caption_label().get_global_rect())).is_true()


## UiKit.framed_button adds it to its parent and clicks before the action.
func test_framed_button_helper_clicks_then_acts() -> void:
	var scene: Control = auto_free(Control.new())
	add_child(scene)
	var sfx: RecordingSfx = RecordingSfx.new()
	scene.add_child(sfx)
	var heard_first: Array[bool] = []
	var action: Callable = func() -> void: heard_first.append(sfx.sounds.size() > 0)
	var button: FramedButton = UiKit.framed_button(scene, "Cart", action, 16, UiKit.SIGN_FRAME)
	assert_object(button.get_parent()).is_same(scene)
	button.pressed.emit()
	assert_array(heard_first).is_equal([true])
	assert_array(sfx.sound_names()).is_equal(["ui_click"])


## Fonts by role: display (Pixelify Sans) for signs, buttons and titles; body (Atkinson) for
## rules, hints and notices; the number font for numbers; JetBrains Mono for the receipt.
func test_fonts_by_role() -> void:
	var button: FramedButton = _button()
	assert_object(button.caption_label().get_theme_font("font")).is_same(ArtStyle.DISPLAY_FONT)
	var labels: Array[Label] = [
		UiKit.display_label("SHIFT", 20, true),
		UiKit.number_label("€12", 20, true),
		UiKit.body_label("Doubles the next item", 13),
		UiKit.receipt_label("TOTAL", 14),
	]
	var fonts: Array[Font] = [
		ArtStyle.DISPLAY_FONT, ArtStyle.number_font(), ArtStyle.BODY_FONT, ArtStyle.MONO_FONT
	]
	for index: int in labels.size():
		assert_object(labels[index].get_theme_font("font")).is_same(fonts[index])
	for label: Label in labels:
		label.free()
	var light: Label = UiKit.display_label("QUOTA", 20, true)
	assert_object(light.get_theme_color("font_color")).is_equal(Palette.PAPER)
	assert_object(light.get_theme_color("font_outline_color")).is_equal(ArtStyle.INK)
	light.free()
	var ink: Label = UiKit.display_label("LOYALTY", 11, false)
	assert_object(ink.get_theme_color("font_color")).is_equal(ArtStyle.INK)
	assert_int(ink.get_theme_constant("outline_size")).is_equal(0)
	ink.free()


## A notice is tomato body-font text.
func test_notice_style() -> void:
	var notice: NoticeLabel = auto_free(NoticeLabel.new())
	assert_object(notice.get_theme_font("font")).is_same(ArtStyle.BODY_FONT)
	assert_object(notice.get_theme_color("font_color")).is_equal(Palette.TOMATO)
	assert_int(notice.get_theme_font_size("font_size")).is_equal(UiKit.NOTICE_FONT_SIZE)


## The screen root's theme falls back to the number font.
func test_screen_theme_uses_the_number_font() -> void:
	assert_object(UiKit.screen_theme().default_font).is_same(ArtStyle.number_font())


## Pixel-art helpers carry the sharp-pixel material; a tiled one repeats its texture.
func test_sprites_and_panels_use_the_pixel_material() -> void:
	var sprite: TextureRect = auto_free(UiKit.sprite(UiKit.BUTTON_FRAME))
	var tiled: TextureRect = auto_free(UiKit.tiled(UiKit.BUTTON_FRAME))
	var panel: PanelContainer = auto_free(
		UiKit.frame_panel(UiKit.SIGN_FRAME, 3, Vector4(1, 2, 3, 4))
	)
	for item: CanvasItem in [sprite, tiled, panel]:
		assert_object(item.material).is_same(ArtStyle.pixel_material())
	assert_int(tiled.stretch_mode).is_equal(TextureRect.STRETCH_TILE)
	var style: StyleBoxTexture = panel.get_theme_stylebox("panel") as StyleBoxTexture
	assert_float(style.content_margin_top).is_equal(2.0)
	assert_float(style.texture_margin_left).is_equal(3.0 * ArtStyle.ART_SCALE)


## The palette's ink is the art's warm ink, and light text is the art palette's paper white.
func test_palette_matches_the_art() -> void:
	assert_object(Palette.INK).is_equal(ArtStyle.INK)
	assert_object(Palette.INK).is_equal(Color("2b2420"))
	assert_object(Palette.LIGHT_TEXT).is_equal(Color("fbf7ee"))


## The boutique frames (#55) load and are big enough for their 9-slice margins.
func test_boutique_frames() -> void:
	var margins: Dictionary[Texture2D, int] = {
		UiKit.SIGN_VELVET_FRAME: FramedButton.FRAME_MARGIN,
		UiKit.BUTTON_BRASS_FRAME: FramedButton.FRAME_MARGIN,
		UiKit.BUTTON_VELVET_FRAME: FramedButton.FRAME_MARGIN,
		UiKit.TRAY_FRAME: UiKit.TRAY_MARGIN,
		UiKit.PLAQUE_FRAME: UiKit.PLAQUE_MARGIN,
	}
	for frame: Texture2D in margins:
		var corners: int = 2 * margins[frame] * ArtStyle.ART_SCALE
		assert_int(frame.get_width()).override_failure_message(frame.resource_path).is_greater(
			corners
		)
		assert_int(frame.get_height()).override_failure_message(frame.resource_path).is_greater(
			corners
		)


## Redraw's brass face and CHECKOUT's velvet face stand on the same ledge as BUTTON_FRAME, so
## FramedButton's PRESS_DEPTH sinks them onto it: the LEDGE art rows above the bottom outline are
## each one colour across the face, and the face row above them isn't.
func test_brass_and_velvet_buttons_have_the_ledge() -> void:
	for frame: Texture2D in [
		UiKit.BUTTON_FRAME, UiKit.BUTTON_BRASS_FRAME, UiKit.BUTTON_VELVET_FRAME
	]:
		var image: Image = frame.get_image()
		var rows: int = floori(image.get_height() / float(ArtStyle.ART_SCALE))
		var bottom: int = rows - 1 - FramedButton.LEDGE
		for row: int in range(bottom, rows - 1):
			(
				assert_bool(_uniform_row(image, row))
				. override_failure_message("%s ledge row %d" % [frame.resource_path, row])
				. is_true()
			)
		(
			assert_bool(_uniform_row(image, bottom - 1))
			. override_failure_message(frame.resource_path)
			. is_false()
		)


## The cream insets: cream with a cream-shade edge.
func test_inset_style() -> void:
	var style: StyleBoxFlat = UiKit.inset_style()
	assert_object(style.bg_color).is_equal(Palette.CREAM)
	assert_object(style.border_color).is_equal(Palette.CREAM_SHADE)
	assert_int(style.border_width_top).is_equal(UiKit.INSET_EDGE)
	assert_int(style.border_width_left).is_equal(UiKit.INSET_EDGE)


func _button() -> FramedButton:
	var button: FramedButton = auto_free(
		FramedButton.new("CHECKOUT", 28, UiKit.BUTTON_FRAME, Vector2(220, 72))
	)
	add_child(button)
	return button


## Whether an art row (inside the frame's 1 art px outline) is one colour.
static func _uniform_row(image: Image, row: int) -> bool:
	var y: int = row * ArtStyle.ART_SCALE
	var first: Color = image.get_pixel(ArtStyle.ART_SCALE, y)
	for x: int in range(ArtStyle.ART_SCALE, image.get_width() - ArtStyle.ART_SCALE):
		if image.get_pixel(x, y) != first:
			return false
	return true


static func _remove_folder(folder: String) -> void:
	if not DirAccess.dir_exists_absolute(folder):
		return
	for sub: String in DirAccess.get_directories_at(folder):
		_remove_folder(folder.path_join(sub))
	for file_name: String in DirAccess.get_files_at(folder):
		DirAccess.remove_absolute(folder.path_join(file_name))
	DirAccess.remove_absolute(folder)


static func _event_log() -> EventLogService:
	return (Engine.get_main_loop() as SceneTree).root.get_node("/root/EventLog")
