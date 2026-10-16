extends GdUnitTestSuite
## The shift screen's boutique look (#55, from style frame v2): the backdrop's window parts (the
## velvet wall, which keeps the background clicks, the marble counter, the brass rails and the
## kickplate at the window's bottom) and the stage's decor in style frame v2's layers (the valance,
## the spotlights and the belt's pool of light on the belt's rubber under the row; the register's,
## the tray's and the purse's pools of light over what they light), at 1280x720 and at
## 1920x1080; the spotlights starting on velvet between the top bar's parts; the FINE GROCERIES
## plaque and the velvet signs in the top bar; the belt's code-drawn treads and rings on its
## rubber. Decor never takes a click: a
## click on an empty slot or a hand card still reaches it, and one on the bare belt reaches the
## wall. The counter band: the cream status and hint insets, the velvet tray, the brass and velvet
## buttons and the closed purse; a notice taking the status panel, and redraw mode narrowing it
## for Cancel; the hand's items and tray fading while the shift is counted. Every new art node is
## pixel art; no text is. The real saves and logs are never touched.

const SCREEN := "res://ui/shift_screen.tscn"
const WINDOWS: Array[Vector2] = [Vector2(1280, 720), Vector2(1920, 1080)]

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


## In a 1280x720 and a 1920x1080 window: the wall fills the window, the counter runs from the
## stage's counter line to the bottom with its brass edge on that line, the picture rail spans
## the window at its row, the kickplate sits on the window's bottom, and the stage's decor moves
## with the centred stage: the valance and the belt's lights are the belt's first children (over
## its rubber, under the row and its value plaques), the register's pool is over the cabinet and
## under the receipt, the tray's over the tray and under the status panel and the hand, and the
## purse's under its shadow.
func test_the_backdrop_fits_each_window() -> void:
	for window_size: Vector2 in WINDOWS:
		var window: Control = auto_free(Control.new())
		window.size = window_size
		add_child(window)
		var wall: TextureRect = BoutiqueBackdrop.screen_parts(window)
		var stage: ShiftStage = ShiftStage.new(7)
		window.add_child(stage)
		await _frames(2)
		var bounds: Rect2 = window.get_global_rect()
		var stage_rect: Rect2 = stage.get_global_rect()
		assert_vector(stage_rect.size).is_equal(ShiftStage.SIZE)
		assert_vector(stage_rect.get_center()).is_equal_approx(bounds.get_center(), Vector2.ONE)
		assert_object(window.get_child(0)).is_same(wall)
		assert_that(wall.get_global_rect()).is_equal(bounds)
		assert_int(wall.mouse_filter).is_equal(Control.MOUSE_FILTER_STOP)
		var counter: Rect2 = (window.get_child(1) as Control).get_global_rect()
		assert_float(counter.position.y).is_equal(stage_rect.position.y + ShiftStage.COUNTER_TOP)
		assert_float(counter.end.y).is_equal(bounds.end.y)
		_assert_band(window, "PictureRail", stage_rect, BoutiqueBackdrop.PICTURE_RAIL, bounds)
		_assert_band(window, "CounterEdge", stage_rect, BoutiqueBackdrop.COUNTER_EDGE, bounds)
		var kickplate: Rect2 = (window.get_node("Kickplate") as Control).get_global_rect()
		assert_float(kickplate.end.y).is_equal(bounds.end.y)
		assert_float(kickplate.size.y).is_equal(BoutiqueBackdrop.KICKPLATE_HEIGHT)
		assert_float(kickplate.size.x).is_equal(bounds.size.x)
		# Nothing on the stage's bottom band reaches the kickplate at 1280x720 (taller windows
		# show more counter under the stage).
		assert_float(stage_rect.position.y + ShiftStage.SEED_RECT.end.y).is_less_equal(
			kickplate.position.y
		)
		assert_float(stage_rect.position.y + ShiftStage.PURSE_RECT.end.y).is_less_equal(
			kickplate.position.y
		)
		# The stage's decor in v2's layers.
		var valance: Control = _valance(stage)
		var lights: Control = _child(stage.belt, BoutiqueBackdrop.LIGHTS_NAME)
		assert_int(valance.get_index()).is_equal(0)
		assert_int(lights.get_index()).is_equal(1)
		assert_object(stage.row_strip.get_parent()).is_same(stage.belt)
		assert_int(stage.row_strip.get_index()).is_greater(lights.get_index())
		assert_that(valance.get_global_rect()).is_equal(
			Rect2(
				stage_rect.position + BoutiqueBackdrop.VALANCE_RECT.position,
				BoutiqueBackdrop.VALANCE_RECT.size
			)
		)
		var register_light: Control = _child(stage, BoutiqueBackdrop.REGISTER_LIGHT_NAME)
		var tray_light: Control = _child(stage, BoutiqueBackdrop.TRAY_LIGHT_NAME)
		var purse_light: Control = _child(stage, BoutiqueBackdrop.PURSE_LIGHT_NAME)
		# Every light canvas uses the stage's coordinates.
		for canvas: Control in [lights, register_light, tray_light, purse_light]:
			(
				assert_that(canvas.get_global_rect())
				. override_failure_message(str(canvas.name))
				. is_equal(stage_rect)
			)
		assert_int(register_light.get_index()).is_greater(stage.cabinet.get_index())
		assert_int(register_light.get_index()).is_less(stage.receipt.get_index())
		assert_int(tray_light.get_index()).is_greater(stage.tray.get_index())
		assert_int(tray_light.get_index()).is_less(stage.status_panel.get_index())
		assert_int(tray_light.get_index()).is_less(stage.hand.get_index())
		assert_int(purse_light.get_index()).is_less(stage.purse_shadow.get_index())
		# The valance hangs from the top bar over the belt's top rail and the cells' plaque band,
		# ending at the mats' top.
		var bar_bottom: float = stage_rect.position.y + RewardPanel.PRINTOUT_TOP
		assert_float(valance.get_global_rect().position.y).is_less(bar_bottom)
		assert_float(valance.get_global_rect().end.y).is_less_equal(
			stage_rect.position.y + ShiftStage.ROW_POSITION.y + RowStrip.MAT_RECT.position.y
		)


## The spotlights stay on the stage, from its top to the counter line, over the belt and apart,
## and the pools of light inside it. Each cone starts on velvet between the top bar's parts: v2's
## SPOT_XS for a top bar like the 1280x720 capture's, moved into the gaps for wider parts, and on
## the real screen's top bar.
func test_the_spotlights_stay_on_the_stage() -> void:
	var no_parts: Array[Rect2] = []
	_assert_spots(BoutiqueBackdrop.SPOT_XS, no_parts)
	# The capture's top bar: the shift sign, the loyalty card, the inspection tag, the plaque.
	var capture: Array[Rect2] = [
		Rect2(20, 8, 260, 44),
		Rect2(297, 8, 213, 44),
		Rect2(527, 8, 263, 44),
		Rect2(846, 18, 156, 24)
	]
	assert_that(BoutiqueBackdrop.spot_xs(capture)).is_equal(BoutiqueBackdrop.SPOT_XS)
	_assert_spots(BoutiqueBackdrop.spot_xs(capture), capture)
	var wider: Array[Rect2] = [
		Rect2(20, 8, 300, 44),
		Rect2(334, 8, 260, 44),
		Rect2(608, 8, 260, 44),
		Rect2(900, 18, 156, 24)
	]
	var moved: Array[float] = BoutiqueBackdrop.spot_xs(wider)
	assert_that(moved).is_equal([326.0, 600.0, 874.0] as Array[float])
	_assert_spots(moved, wider)
	var screen: ShiftScreen = await _screen()
	var origin: Vector2 = screen._stage.get_global_rect().position
	var parts: Array[Rect2] = []
	for child: Node in screen._stage.top_bar.get_children():
		var part: Control = child as Control
		if part.visible and (part is PanelContainer or part is Button):
			parts.append(Rect2(part.get_global_rect().position - origin, part.size))
	assert_int(parts.size()).is_greater_equal(4)
	_assert_spots(screen._stage.spot_xs(), parts)
	var stage: Rect2 = Rect2(Vector2.ZERO, ShiftStage.SIZE)
	for light: Rect2 in BoutiqueBackdrop.LIGHTS:
		var pool: Rect2 = Rect2(light.position - light.size, light.size * 2.0)
		assert_bool(stage.grow(light.size.x).encloses(pool)).is_true()
		assert_bool(stage.has_point(light.position)).is_true()


## The top bar's velvet signs and the FINE GROCERIES plaque: decor in the bar's row, after the
## spacer and before Deck, gold lettering on velvet that takes no click.
func test_the_top_bar_wears_velvet_and_the_plaque() -> void:
	var screen: ShiftScreen = await _screen()
	var stage: ShiftStage = screen._stage
	var sign_panel: PanelContainer = stage.top_bar.get_child(0) as PanelContainer
	var style: StyleBoxTexture = sign_panel.get_theme_stylebox("panel") as StyleBoxTexture
	assert_object(style.texture).is_same(UiKit.SIGN_VELVET_FRAME)
	for button: FramedButton in [stage.deck_button, stage.export_button]:
		var face: StyleBoxTexture = button.face().get_theme_stylebox("panel") as StyleBoxTexture
		assert_object(face.texture).is_same(UiKit.SIGN_VELVET_FRAME)
	assert_that(screen._quota_label.get_theme_color("font_color")).is_equal(Palette.GOLD)
	var plaque: PanelContainer = stage.plaque
	assert_object(plaque.get_parent()).is_same(stage.top_bar)
	assert_int(plaque.get_index()).is_equal(stage.deck_button.get_index() - 1)
	assert_int(plaque.mouse_filter).is_equal(Control.MOUSE_FILTER_IGNORE)
	var engraved: Label = plaque.get_child(0) as Label
	assert_str(engraved.text).is_equal(BoutiqueBackdrop.PLAQUE_TEXT)
	assert_int(engraved.mouse_filter).is_equal(Control.MOUSE_FILTER_IGNORE)
	assert_that(engraved.get_theme_color("font_color")).is_equal(Palette.GOLD)
	var rect: Rect2 = plaque.get_global_rect()
	assert_bool(rect.encloses(engraved.get_global_rect())).is_true()
	assert_float(engraved.get_minimum_size().x).is_less_equal(rect.size.x)
	assert_float(rect.end.y).is_less_equal(
		stage.get_global_rect().position.y + RewardPanel.PRINTOUT_TOP
	)


## The belt: a fixed BeltPanel with its treads and rollers' rings inside it; the treads on the
## rubber, the rings on the rollers, every one on the 2 px art grid.
func test_the_belt_draws_its_treads_and_rings() -> void:
	var screen: ShiftScreen = await _screen()
	var belt: BeltPanel = screen._stage.belt
	assert_vector(belt.size).is_equal(ShiftStage.BELT_RECT.size)
	assert_int(belt.mouse_filter).is_equal(Control.MOUSE_FILTER_IGNORE)
	assert_bool(belt.has_meta(ArtStyle.PIXEL_ART_META)).is_true()
	assert_object(belt.frame_style().texture).is_same(BeltPanel.FRAME)
	var rubber: Rect2 = belt.interior()
	var treads: Array[Rect2] = belt.tread_rects()
	assert_int(treads.size()).is_greater(15)
	for tread: Rect2 in treads:
		assert_bool(rubber.encloses(tread)).override_failure_message(str(tread)).is_true()
		assert_float(fmod(tread.position.y, ArtStyle.ART_SCALE)).is_equal(0.0)
	var rings: Array[Rect2] = belt.ring_rects()
	assert_int(rings.size()).is_greater(20)
	for ring: Rect2 in rings:
		var roller: bool = ring.end.x <= rubber.position.x or ring.position.x >= rubber.end.x
		assert_bool(roller).override_failure_message(str(ring)).is_true()
		assert_bool(Rect2(Vector2.ZERO, belt.size).encloses(ring)).is_true()
		assert_float(ring.end.y).is_less_equal(rubber.end.y)
	# The row's cards stand on the rubber, between the rollers.
	for panel: PanelContainer in screen._slots:
		var rect: Rect2 = panel.get_global_rect()
		var on_screen: Rect2 = Rect2(belt.get_global_rect().position + rubber.position, rubber.size)
		assert_bool(on_screen.encloses(rect)).override_failure_message(str(rect)).is_true()


## Decor takes no click: the window parts other than the wall, the valance, the light canvases,
## the belt and the plaque are MOUSE_FILTER_IGNORE. A click on an empty slot or a hand card reaches
## it, and one on the bare belt between two slots reaches the wall (the background click).
func test_decor_takes_no_clicks() -> void:
	var screen: ShiftScreen = await _screen()
	var stage: ShiftStage = screen._stage
	var wall: Control = screen.get_child(0) as Control
	assert_int(wall.mouse_filter).is_equal(Control.MOUSE_FILTER_STOP)
	assert_bool(wall.gui_input.is_connected(screen._on_background_input)).is_true()
	for index: int in range(1, stage.get_index()):
		var part: Control = screen.get_child(index) as Control
		assert_int(part.mouse_filter).override_failure_message(str(part.name)).is_equal(
			Control.MOUSE_FILTER_IGNORE
		)
	for decor: Control in [
		_valance(stage),
		_child(stage.belt, BoutiqueBackdrop.LIGHTS_NAME),
		_child(stage, BoutiqueBackdrop.REGISTER_LIGHT_NAME),
		_child(stage, BoutiqueBackdrop.TRAY_LIGHT_NAME),
		_child(stage, BoutiqueBackdrop.PURSE_LIGHT_NAME),
		stage.belt,
		stage.plaque,
	]:
		assert_int(decor.mouse_filter).override_failure_message(str(decor.name)).is_equal(
			Control.MOUSE_FILTER_IGNORE
		)
	var slot: PanelContainer = screen._slots[2]
	var slot_hit: Control = _topmost_at(screen, slot.get_global_rect().get_center())
	assert_bool(slot_hit == slot or slot.is_ancestor_of(slot_hit)).is_true()
	var card: Control = screen._hand_box.cards()[0]
	var card_hit: Control = _topmost_at(screen, card.get_global_rect().get_center())
	assert_bool(card_hit == card or card.is_ancestor_of(card_hit)).is_true()
	# The gap between slots 0 and 1, on the belt's rubber.
	var gap: Vector2 = Vector2(
		slot.get_global_rect().position.x - RowStrip.SEPARATION / 2.0,
		slot.get_global_rect().get_center().y
	)
	assert_object(_topmost_at(screen, gap)).is_same(wall)
	# The valance and the picture rail above the belt.
	var valance: Rect2 = _valance(stage).get_global_rect()
	var above: Vector2 = Vector2(valance.get_center().x, valance.position.y + 4.0)
	assert_object(_topmost_at(screen, above)).is_same(wall)


## Every new art node carries the pixel-art mark (so the sharp-pixel shader reaches it); no text
## does.
func test_the_new_art_is_pixel_art() -> void:
	var screen: ShiftScreen = await _screen()
	var stage: ShiftStage = screen._stage
	var art: Array[CanvasItem] = [
		screen.get_child(0) as CanvasItem,
		screen.get_child(1) as CanvasItem,
		screen.get_node("PictureRail") as CanvasItem,
		screen.get_node("CounterEdge") as CanvasItem,
		_valance(stage),
		stage.belt,
	]
	for item: CanvasItem in art:
		(
			assert_bool(item.has_meta(ArtStyle.PIXEL_ART_META))
			. override_failure_message(str(item.name))
			. is_true()
		)
	var engraved: Label = stage.plaque.get_child(0) as Label
	assert_bool(engraved.has_meta(ArtStyle.PIXEL_ART_META)).is_false()
	assert_object(engraved.material).is_null()


## The register cabinet (RegisterCabinet) at its rect, the stage's rattle target: its plate, LED,
## key bed and printer slot at their stage rects; the key bed and the TOTAL key at their art's
## native size (never resampled); every part pixel art or plain colour and IGNORE (the TOTAL
## key is decor, not a button), its texts unshaded. set_total_down() swaps the key's face and
## drops its caption by TOTAL_KEY_DROP.
func test_the_register_cabinet() -> void:
	var screen: ShiftScreen = await _screen()
	var stage: ShiftStage = screen._stage
	var cabinet: RegisterCabinet = stage.cabinet
	var origin: Vector2 = stage.get_global_rect().position
	assert_object(stage.register).is_same(cabinet)
	assert_object(stage.led).is_same(cabinet.led)
	assert_that(cabinet.get_global_rect()).is_equal(
		Rect2(origin + ShiftStage.REGISTER_RECT.position, ShiftStage.REGISTER_RECT.size)
	)
	var parts: Dictionary[String, Rect2] = {
		"Plate": ShiftStage.PLATE_RECT,
		"Led": ShiftStage.LED_RECT,
		"Keys": ShiftStage.KEYS_RECT,
		"TotalKey": ShiftStage.TOTAL_KEY_RECT,
	}
	for part: String in parts:
		var node: Control = cabinet.get_node(part) as Control
		var rect: Rect2 = parts[part]
		assert_that(node.get_global_rect()).override_failure_message(part).is_equal(
			Rect2(origin + rect.position, rect.size)
		)
	# The printer slot: its brass lip spans the cabinet between its frame's inner edges, its mouth
	# PRINTER_SLOT_INSET in from each end under the lip, and the receipt hangs from the mouth
	# RECEIPT_MOUTH_GAP inside it at each side.
	var slot: Rect2 = ShiftStage.PRINTER_SLOT_RECT
	var lip: Rect2 = (cabinet.get_node("PrinterSlot") as Control).get_global_rect()
	var mouth: Rect2 = (cabinet.get_node("PrinterMouth") as Control).get_global_rect()
	var frame: float = RegisterCabinet.BODY_MARGIN * ArtStyle.ART_SCALE
	var body: Rect2 = cabinet.get_global_rect()
	assert_that(lip).is_equal(
		Rect2(
			body.position.x + frame,
			origin.y + slot.position.y,
			body.size.x - 2.0 * frame,
			RegisterCabinet.PRINTER_LIP
		)
	)
	assert_that(mouth).is_equal(
		Rect2(
			lip.position.x + RegisterCabinet.PRINTER_SLOT_INSET,
			lip.end.y,
			lip.size.x - 2.0 * RegisterCabinet.PRINTER_SLOT_INSET,
			origin.y + slot.end.y - lip.end.y
		)
	)
	assert_bool(Rect2(origin + slot.position, slot.size).encloses(lip.merge(mouth))).is_true()
	var receipt: Rect2 = stage.receipt.get_global_rect()
	assert_float(receipt.position.y).is_equal(mouth.end.y)
	assert_float(receipt.position.x).is_equal(mouth.position.x + ShiftStage.RECEIPT_MOUTH_GAP)
	assert_float(receipt.end.x).is_equal(mouth.end.x - ShiftStage.RECEIPT_MOUTH_GAP)
	# Canvas-size scenery at its native size.
	for part: String in ["Keys", "TotalKey"]:
		var sprite: TextureRect = cabinet.get_node(part) as TextureRect
		assert_vector(sprite.size).override_failure_message(part).is_equal(
			sprite.texture.get_size()
		)
	for node: Node in cabinet.find_children("*", "Control", true, false):
		var control: Control = node as Control
		assert_int(control.mouse_filter).override_failure_message(str(control.name)).is_equal(
			Control.MOUSE_FILTER_IGNORE
		)
		if control is Label:
			assert_bool(control.has_meta(ArtStyle.PIXEL_ART_META)).is_false()
		elif control is TextureRect or control is PanelContainer or control is LedDisplay:
			(
				assert_bool(control.has_meta(ArtStyle.PIXEL_ART_META))
				. override_failure_message(str(control.name))
				. is_true()
			)
	assert_int(cabinet.mouse_filter).is_equal(Control.MOUSE_FILTER_IGNORE)
	# The plate's text fits the plate; the TOTAL caption fits its key.
	var plate: Control = cabinet.get_node("Plate") as Control
	var plate_text: Label = plate.get_child(0) as Label
	assert_float(plate_text.get_minimum_size().x).is_less_equal(plate.size.x)
	var label: Label = cabinet.total_label()
	var key: Rect2 = cabinet.total_key().get_global_rect()
	assert_bool(key.encloses(label.get_global_rect())).is_true()
	# Up on a shift in planning; down drops the caption.
	assert_bool(cabinet.is_total_down()).is_false()
	assert_object(cabinet.total_key().texture).is_same(RegisterCabinet.TOTAL_KEY_UP)
	var up_y: float = label.position.y
	cabinet.set_total_down(true)
	assert_bool(cabinet.is_total_down()).is_true()
	assert_object(cabinet.total_key().texture).is_same(RegisterCabinet.TOTAL_KEY_DOWN)
	assert_float(label.position.y).is_equal(up_y + RegisterCabinet.TOTAL_KEY_DROP)
	assert_bool(key.encloses(label.get_global_rect())).is_true()
	cabinet.set_total_down(false)
	assert_float(label.position.y).is_equal(up_y)


## The counter band: the status panel and the hint's cream insets at their rects behind their
## texts, the hand's velvet tray around the hand, brass Cancel and Redraw with ink captions, the
## velvet CHECKOUT with its gold caption, and the closed purse on its shadow at its art's native
## size. All of it is decor that takes no click (a click on the purse or the tray's rim reaches
## the wall); the art is pixel art, no text is.
func test_the_counter_band() -> void:
	var screen: ShiftScreen = await _screen()
	var stage: ShiftStage = screen._stage
	var origin: Vector2 = stage.get_global_rect().position
	var expected: Dictionary[Control, Rect2] = {
		stage.status_panel: ShiftStage.STATUS_RECT,
		stage.hint_inset: ShiftStage.HINT_RECT,
		stage.tray: ShiftStage.TRAY_RECT,
		stage.purse: ShiftStage.PURSE_RECT,
		stage.purse_shadow: ShiftStage.PURSE_SHADOW_RECT,
	}
	for part: Control in expected:
		var rect: Rect2 = expected[part]
		assert_that(part.get_global_rect()).override_failure_message(str(part.name)).is_equal(
			Rect2(origin + rect.position, rect.size)
		)
		assert_int(part.mouse_filter).override_failure_message(str(part.name)).is_equal(
			Control.MOUSE_FILTER_IGNORE
		)
	for inset: Panel in [stage.status_panel, stage.hint_inset]:
		var style: StyleBoxFlat = inset.get_theme_stylebox("panel") as StyleBoxFlat
		assert_that(style.bg_color).is_equal(Palette.CREAM)
		assert_that(style.border_color).is_equal(Palette.CREAM_SHADE)
	# Each inset is drawn before (under) its texts; the tray under the hand.
	for label: Label in [stage.capacity_label, stage.cue_label, stage.notice_label]:
		assert_int(label.get_index()).is_greater(stage.status_panel.get_index())
	assert_int(stage.hint_label.get_index()).is_greater(stage.hint_inset.get_index())
	assert_int(stage.hand.get_index()).is_greater(stage.tray.get_index())
	var tray_style: StyleBoxTexture = stage.tray.get_theme_stylebox("panel") as StyleBoxTexture
	assert_object(tray_style.texture).is_same(UiKit.TRAY_FRAME)
	assert_bool(stage.tray.get_global_rect().encloses(stage.hand.get_global_rect())).is_true()
	# The purse: one closed purse sprite at its native size, with no text, over its shadow.
	assert_object(stage.purse.texture).is_same(ShiftStage.PURSE_CLOSED)
	assert_vector(stage.purse.size).is_equal(stage.purse.texture.get_size())
	assert_int(stage.purse.get_child_count()).is_equal(0)
	assert_int(stage.purse.get_index()).is_greater(stage.purse_shadow.get_index())
	var purse_light: Control = _child(stage, BoutiqueBackdrop.PURSE_LIGHT_NAME)
	assert_int(purse_light.get_index()).is_less(stage.purse_shadow.get_index())
	assert_bool(stage.purse.get_global_rect().intersects(stage.tray.get_global_rect())).is_false()
	for art: CanvasItem in [stage.tray, stage.purse]:
		(
			assert_bool(art.has_meta(ArtStyle.PIXEL_ART_META))
			. override_failure_message(str(art.name))
			. is_true()
		)
	# The buttons' faces and captions.
	var faces: Dictionary[FramedButton, Texture2D] = {
		stage.cancel_button: UiKit.BUTTON_BRASS_FRAME,
		stage.redraw_button: UiKit.BUTTON_BRASS_FRAME,
		stage.checkout_button: UiKit.BUTTON_VELVET_FRAME,
	}
	for button: FramedButton in faces:
		var face: StyleBoxTexture = button.face().get_theme_stylebox("panel") as StyleBoxTexture
		assert_object(face.texture).is_same(faces[button])
		var caption: Label = button.caption_label()
		assert_bool(caption.has_meta(ArtStyle.PIXEL_ART_META)).is_false()
		var gold: bool = button == stage.checkout_button
		assert_that(caption.get_theme_color("font_color")).is_equal(
			Palette.GOLD if gold else Palette.INK
		)
		assert_int(caption.get_theme_constant("outline_size")).is_equal(
			ShiftStage.CHECKOUT_OUTLINE if gold else 0
		)
	# Clicks on the purse and on the tray's bottom rim reach the wall.
	var wall: Control = screen.get_child(0) as Control
	assert_object(_topmost_at(screen, stage.purse.get_global_rect().get_center())).is_same(wall)
	var rim: Vector2 = Vector2(
		stage.tray.get_global_rect().get_center().x, stage.tray.get_global_rect().end.y - 2.0
	)
	assert_object(_topmost_at(screen, rim)).is_same(wall)


## A notice takes the status panel's two rows: the capacity line and the cue hide while it shows
## and come back when it is cleared or has faded (NoticeLabel.showing_changed).
func test_a_notice_takes_the_status_panel() -> void:
	var screen: ShiftScreen = await _screen()
	var stage: ShiftStage = screen._stage
	var notice: NoticeLabel = stage.notice_label
	var recorded: Array[bool] = []
	notice.showing_changed.connect(func(showing: bool) -> void: recorded.append(showing))
	assert_bool(notice.is_showing()).is_false()
	assert_bool(stage.capacity_label.visible).is_true()
	assert_bool(stage.cue_label.visible).is_true()
	notice.show_notice("Row full (9/9 items): take an item out first")
	assert_bool(notice.is_showing()).is_true()
	assert_bool(stage.capacity_label.visible).is_false()
	assert_bool(stage.cue_label.visible).is_false()
	assert_that(notice.get_theme_color("font_color")).is_equal(Palette.TOMATO_DARK)
	assert_int(notice.get_theme_constant("outline_size")).is_equal(0)
	# A second notice while one shows changes nothing.
	notice.show_notice("Closed by the inspection this shift")
	notice.clear_notice()
	assert_bool(stage.capacity_label.visible).is_true()
	assert_bool(stage.cue_label.visible).is_true()
	notice.show_notice("Closed by the inspection this shift")
	notice._on_faded()
	assert_bool(notice.is_showing()).is_false()
	assert_bool(stage.capacity_label.visible).is_true()
	assert_bool(stage.cue_label.visible).is_true()
	assert_that(recorded).is_equal([true, false, true, false] as Array[bool])


## Redraw mode narrows the status panel so Cancel fits before Redraw: the capacity line (at its
## longest) wraps over both rows and fits, the cue makes way, and the longest notices fit two
## lines in the narrowed panel. Cancel puts it all back.
func test_redraw_mode_narrows_the_status_panel() -> void:
	var screen: ShiftScreen = await _screen()
	var stage: ShiftStage = screen._stage
	var run: RunState = screen.run
	screen._debug.give_upgrade("extra_coupon_slot")
	run.inspections = [load("res://data/inspections/short_belt.tres")]
	run.debug_skip_to_shift(run.shift_index)
	screen._on_shift_started()
	await _frames(1)
	var origin: Vector2 = stage.get_global_rect().position
	assert_bool(stage.cancel_button.visible).is_false()
	assert_that(stage.status_panel.get_global_rect()).is_equal(
		Rect2(origin + ShiftStage.STATUS_RECT.position, ShiftStage.STATUS_RECT.size)
	)
	screen._on_redraw_pressed()
	await _frames(1)
	assert_bool(stage.cancel_button.visible).is_true()
	var panel: Rect2 = stage.status_panel.get_global_rect()
	assert_that(panel).is_equal(
		Rect2(origin + ShiftStage.STATUS_REDRAW_RECT.position, ShiftStage.STATUS_REDRAW_RECT.size)
	)
	var cancel: Rect2 = stage.cancel_button.get_global_rect()
	assert_bool(panel.intersects(cancel)).is_false()
	assert_bool(cancel.intersects(stage.redraw_button.get_global_rect())).is_false()
	assert_bool(stage.cue_label.visible).is_false()
	var capacity: Label = stage.capacity_label
	assert_str(capacity.text).contains("(inspection −1)").contains("Coupon slots")
	assert_that(capacity.get_global_rect()).is_equal(
		Rect2(
			origin + ShiftStage.CAPACITY_REDRAW_RECT.position, ShiftStage.CAPACITY_REDRAW_RECT.size
		)
	)
	assert_float(capacity.get_minimum_size().y).is_less_equal(capacity.size.y)
	assert_int(capacity.get_line_count()).is_less_equal(2)
	assert_bool(panel.encloses(capacity.get_global_rect())).is_true()
	var notice: NoticeLabel = stage.notice_label
	for text: String in [
		"Row full (9/9 items): take an item out first", "Closed by the inspection this shift"
	]:
		notice.show_notice(text)
		await _frames(1)
		assert_that(notice.get_global_rect()).is_equal(
			Rect2(
				origin + ShiftStage.NOTICE_REDRAW_RECT.position, ShiftStage.NOTICE_REDRAW_RECT.size
			)
		)
		assert_int(notice.get_line_count()).is_less_equal(2)
		assert_float(notice.get_minimum_size().y).is_less_equal(notice.size.y)
		assert_bool(panel.encloses(notice.get_global_rect())).is_true()
	notice.clear_notice()
	screen._on_cancel_pressed()
	await _frames(1)
	assert_bool(stage.cancel_button.visible).is_false()
	assert_that(stage.status_panel.get_global_rect()).is_equal(
		Rect2(origin + ShiftStage.STATUS_RECT.position, ShiftStage.STATUS_RECT.size)
	)
	assert_that(capacity.get_global_rect()).is_equal(
		Rect2(origin + ShiftStage.CAPACITY_RECT.position, ShiftStage.CAPACITY_RECT.size)
	)
	assert_int(capacity.get_line_count()).is_equal(1)
	assert_bool(stage.cue_label.visible).is_true()


# --- Helpers ---------------------------------------------------------------------------------


## The hand is tray items (#75), and while the shift is counted the hand and its tray fade to
## COUNTING_HAND_ALPHA; they come back once the count-up ends.
func test_the_hand_is_items_that_dim_while_counting() -> void:
	var screen: ShiftScreen = await _screen()
	var views: Array[Control] = screen._hand_box.cards()
	assert_int(views.size()).is_equal(screen.run.balance.hand_size)
	for view: Control in views:
		assert_object(view).is_instanceof(ItemView)
		assert_int((view as ItemView).form).is_equal(ItemView.Form.TRAY)
	var stage: ShiftStage = screen._stage
	assert_float(stage.tray.modulate.a).is_equal(1.0)
	assert_float(stage.hand.modulate.a).is_equal(1.0)
	# Read on the first frame of the count-up.
	var counting_alphas: Array[float] = []
	var record: Callable = func() -> void:
		counting_alphas.assign([stage.tray.modulate.a, stage.hand.modulate.a])
	get_tree().process_frame.connect(record, CONNECT_ONE_SHOT)
	await screen._on_checkout_pressed()
	assert_int(counting_alphas.size()).is_equal(2)
	for alpha: float in counting_alphas:
		assert_float(alpha).is_equal_approx(ShiftStage.COUNTING_HAND_ALPHA, 0.001)
	assert_float(stage.tray.modulate.a).is_equal(1.0)
	assert_float(stage.hand.modulate.a).is_equal(1.0)


## Spotlights at `xs` (stage coordinates), one per SPOT_XS: each cone's foot on the stage, the
## cone over the belt (not the register), its top clear of every part of `parts`, and each at
## least SPOT_SPACING right of the one before it.
func _assert_spots(xs: Array[float], parts: Array[Rect2]) -> void:
	var stage: Rect2 = Rect2(Vector2.ZERO, ShiftStage.SIZE)
	assert_int(xs.size()).is_equal(BoutiqueBackdrop.SPOT_XS.size())
	for index: int in range(xs.size()):
		var x: float = xs[index]
		var foot: Rect2 = Rect2(
			x - BoutiqueBackdrop.SPOT_BOTTOM,
			0,
			2.0 * BoutiqueBackdrop.SPOT_BOTTOM,
			ShiftStage.COUNTER_TOP
		)
		assert_bool(stage.encloses(foot)).override_failure_message(str(foot)).is_true()
		assert_float(x).is_greater(ShiftStage.BELT_RECT.position.x)
		assert_float(x).is_less(ShiftStage.BELT_RECT.end.x)
		var top: Rect2 = Rect2(
			x - BoutiqueBackdrop.SPOT_TOP,
			0,
			2.0 * BoutiqueBackdrop.SPOT_TOP,
			ShiftStage.COUNTER_TOP
		)
		for part: Rect2 in parts:
			(
				assert_bool(top.intersects(part))
				. override_failure_message("spot at %s under %s" % [x, part])
				. is_false()
			)
		if index > 0:
			assert_float(x - xs[index - 1]).is_greater_equal(BoutiqueBackdrop.SPOT_SPACING)


## The stage's valance, on the belt.
static func _valance(stage: ShiftStage) -> Control:
	return _child(stage.belt, BoutiqueBackdrop.VALANCE_NAME)


## `parent`'s child named `child_name`.
static func _child(parent: Node, child_name: StringName) -> Control:
	return parent.find_child(String(child_name), false, false) as Control


## The screen past the impulse rack, laid out.
func _screen() -> ShiftScreen:
	var runner: GdUnitSceneRunner = scene_runner(SCREEN)
	var screen: ShiftScreen = runner.scene()
	screen._on_reward_skipped()
	await _frames(3)
	return screen


## The control a click at `point` reaches, picked as the GUI does: the last drawn visible
## control under the point that doesn't ignore the mouse (children over their parent, later
## siblings over earlier ones), or null.
static func _topmost_at(node: Node, point: Vector2) -> Control:
	for index: int in range(node.get_child_count() - 1, -1, -1):
		var child: Node = node.get_child(index)
		var item: CanvasItem = child as CanvasItem
		if item != null and not item.visible:
			continue
		var found: Control = _topmost_at(child, point)
		if found != null:
			return found
	var control: Control = node as Control
	if (
		control != null
		and control.mouse_filter != Control.MOUSE_FILTER_IGNORE
		and control.get_global_rect().has_point(point)
	):
		return control
	return null


func _assert_band(window: Control, part: String, stage: Rect2, rect: Rect2, bounds: Rect2) -> void:
	var band: Control = window.get_node(part) as Control
	var shown: Rect2 = band.get_global_rect()
	assert_float(shown.position.y).is_equal(stage.position.y + rect.position.y)
	assert_float(shown.size.y).is_equal(rect.size.y)
	assert_float(shown.position.x).is_less_equal(bounds.position.x)
	assert_float(shown.end.x).is_greater_equal(bounds.end.x)
	assert_int(band.mouse_filter).is_equal(Control.MOUSE_FILTER_IGNORE)


func _frames(count: int) -> void:
	for _frame: int in range(count):
		await get_tree().process_frame


static func _event_log() -> EventLogService:
	return (Engine.get_main_loop() as SceneTree).root.get_node("/root/EventLog")
