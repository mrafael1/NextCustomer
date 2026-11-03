class_name PinLanyard
extends Control
## The run's badge pins on the shift screen (mock-up shift_scene_polish_v2 section 3, variant C,
## drawBadge, picked by the user on 2026-11-02): a name badge hung on a teal lanyard from a steel
## hook on the monitor's left side, between the receipt column and the monitor, showing the pins
## the run wears (RunState.pins, one or two: the balance's pin_slots). In stage coordinates
## (RECT, in the stage's world: the camera's glide takes it with the monitor), on the 2 px art
## grid: the hook, the strap down to the clip and the badge's drop shadow are drawn by code; the
## badge is pixel art (art/scenery/pin_badge: the brass plate, the teal band, the paper face),
## with NEXT / CUSTOMER on its band on two lines in the 3x5 pixel capitals (PixelWords, one art px
## per font px: 15 px tall at 1920x1080, mock-up shift_scene_polish_v4 E1; the band grew from 7 to
## 15 art rows for them), CASHIER on its face in the body font, and the worn pins (PinFace) on the
## face, centred. With no pin worn
## it hides.
##
## Hovering a pin opens its card (PinTip: name, rule and the charges left, PinPlay): the pin
## lifts one art px inside a gold ring. A left or right click on a pin keeps the card open (a
## click on the same pin, or a left or right click anywhere else, closes it; the wheel never
## does). The card opens under its pin, between the receipt and the monitor's screen, and pops
## in about its tail (at once under reduced motion); the badge never swings. Outside planning
## (`blocked`: the count, the dessert, the machine, the results) no card opens and a kept one
## closes. It takes clicks on its pins only, never marking another click handled. Display only:
## the shift screen fills it (show_run, through PinFlow.refresh).

## The lanyard's whole rect on the stage: the badge and the hook on the monitor's bezel.
const RECT := Rect2(370, 80, 120, 130)
## In the lanyard's own coordinates: the badge, the hook, the clip, the strap's ends.
const BADGE := Rect2(0, 28, 100, 102)
const HOOK := Rect2(112, 0, 8, 10)
const CLIP := Rect2(40, 20, 20, 12)
const STRAP_TOP := Vector2(116, 4)
const STRAP_BEND := Vector2(50, 12)
const STRAP_WIDTH := 4.0
const PX := 2.0
const BADGE_ART := preload("res://art/scenery/pin_badge.png")
## In the badge's coordinates: the band (under its lit top edge), the paper face, the pins.
const BAND := Rect2(4, 10, 92, 30)
const FACE := Rect2(4, 42, 92, 54)
## The band's lines, each centred on the band on the art's grid, their tops BAND_LINE_TOPS below
## the band's top (the mock-up's E1: 2 art rows over NEXT, 1 between the lines).
const BAND_LINES: Array[String] = ["NEXT", "CUSTOMER"]
const BAND_LINE_TOPS: Array[float] = [4.0, 16.0]
const BAND_CELL := 2.0
const FACE_TEXT := "CASHIER"
## CASHIER's left and baseline, its size and weight (the mock-up's 700 9 px).
const FACE_TEXT_AT := Vector2(8, 52)
const FACE_TEXT_SIZE := 9
const FACE_TEXT_WEIGHT := 700
const SHADOW := Vector2(4, 4)
const SHADOW_ALPHA := 0.35
const PIN_SIZE := 32.0
const PIN_STEP := 40.0
const PIN_TOP := 56.0
## How far the shown pin lifts inside its ring.
const LIFT := 2.0
## The card's room: between the receipt and the monitor's screen (MARGIN off each), down to the
## stage's foot, in stage coordinates.
const CARD_MARGIN := 2.0
## The card's pop (GlyphTips' own).
const POP_S := 0.08
const POP_FROM := 0.6
const CARD_Z := 100
const RELABELS_LEFT := "%d relabel%s left this shift"
const DAYS_OFF_LEFT := "%d day%s off left this week"

## Returns true when the player asked for reduced motion. None means false.
var reduced_motion: Callable = Callable()
## Returns true while no card may show (outside planning, or the screen busy). None means false.
var blocked: Callable = Callable()

var _run: RunState
var _pins: Array[PinDefinition] = []
var _plate: TextureRect
var _band_words: Array[PixelWords] = []
var _face_label: Label
var _ring: Control
var _faces: Array[PinFace] = []
var _hits: Array[Control] = []
var _card: PinTip
## The pin under the pointer and the pin kept open by a click (-1: none).
var _hovered: int = -1
var _kept: int = -1
var _shown: int = -1
var _pop: Tween


func _init() -> void:
	name = "PinLanyard"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	position = RECT.position
	size = RECT.size
	_plate = UiKit.sprite(BADGE_ART)
	_plate.name = "Badge"
	_plate.position = BADGE.position
	_plate.size = BADGE.size
	add_child(_plate)
	var band: Rect2 = _on_badge(BAND)
	for line: int in range(BAND_LINES.size()):
		var words: PixelWords = PixelWords.new(
			BAND_LINES[line], PixelWords.Sheet.CAPS, BAND_CELL, Palette.PAPER
		)
		words.name = "Band%d" % line
		var width: float = words.get_combined_minimum_size().x
		words.position = Vector2(
			band.position.x + PX * floorf((band.size.x - width) / (2.0 * PX)),
			band.position.y + BAND_LINE_TOPS[line]
		)
		words.size = words.get_combined_minimum_size()
		add_child(words)
		_band_words.append(words)
	_face_label = UiKit.body_label(FACE_TEXT, FACE_TEXT_SIZE, Palette.MUTED_INK)
	_face_label.name = "FaceText"
	var face_font: Font = ArtStyle.bold_font(FACE_TEXT_WEIGHT)
	_face_label.add_theme_font_override("font", face_font)
	_face_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var baseline: Vector2 = BADGE.position + FACE_TEXT_AT
	_face_label.position = Vector2(
		baseline.x, roundf(baseline.y - face_font.get_ascent(FACE_TEXT_SIZE))
	)
	add_child(_face_label)
	_ring = Control.new()
	_ring.name = "Ring"
	_ring.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ring.size = size
	_ring.draw.connect(_draw_ring)
	add_child(_ring)
	_card = PinTip.new()
	_card.z_index = CARD_Z
	_card.visible = false
	add_child(_card)
	visible = false


## Shows the pins `run` wears now (hidden with none), and refreshes an open card's charges, or
## closes it when it may not show.
func show_run(run: RunState) -> void:
	_run = run
	var worn: Array[PinDefinition] = []
	if run != null:
		worn = run.pins
	if worn != _pins:
		_pins = worn.duplicate()
		_build_pins()
	visible = not _pins.is_empty()
	_update_card()


## The worn pins' faces, left first.
func faces() -> Array[PinFace]:
	return _faces


## The worn pins' click and hover areas, left first.
func hits() -> Array[Control]:
	return _hits


## The pin card (shown or not).
func card() -> PinTip:
	return _card


## The badge's words: the band's lines (NEXT, CUSTOMER) and the face's (CASHIER).
func band_words() -> Array[PixelWords]:
	return _band_words.duplicate()


func face_label() -> Label:
	return _face_label


## The pin whose card shows (-1: none) and the pin kept open by a click (-1: none).
func shown_pin() -> int:
	return _shown if _card.visible else -1


func kept_pin() -> int:
	return _kept


## The badge's plate, in this lanyard's coordinates.
func badge_rect() -> Rect2:
	return BADGE


## The pointer rests on pin `index` (`over`) or left it (a hit's signals; tests call it).
func hover_pin(index: int, over: bool) -> void:
	if over:
		_hovered = index
	elif _hovered == index:
		_hovered = -1
	_update_card()


## A click on pin `index`: keeps its card open, or closes it when it is the kept one (never
## while `blocked`).
func press_pin(index: int) -> void:
	_kept = -1 if _kept == index or _is_blocked() else index
	_update_card()


## A click away from the pins closes a kept card.
func close_card() -> void:
	_kept = -1
	_hovered = -1
	_update_card()


## The charges `pin` has left on `run` ("" for a pin without charges): Price gun's relabels this
## shift, Day off's days this week (PinPlay).
static func charges_for(pin: PinDefinition, run: RunState) -> String:
	if run == null:
		return ""
	if pin.relabels_per_shift > 0:
		var relabels: int = PinPlay.relabels_left(run)
		return RELABELS_LEFT % [relabels, "" if relabels == 1 else "s"]
	if pin.days_off_per_week > 0:
		var days: int = PinPlay.days_off_left(run)
		return DAYS_OFF_LEFT % [days, "" if days == 1 else "s"]
	return ""


## The card's room on the stage: right of the receipt, left of the monitor's screen (its shadow
## included), under the top bar, inside the stage.
static func card_area() -> Rect2:
	var left: float = ShiftStage.RECEIPT_X + ShiftStage.RECEIPT_WIDTH + CARD_MARGIN
	var right: float = ShiftStage.MONITOR_SCREEN_RECT.position.x - CARD_MARGIN
	var top: float = ShiftStage.TOP_BAR_BOTTOM
	return Rect2(left, top, right - left, ShiftStage.SIZE.y - top)


func _process(_delta: float) -> void:
	# The count, the dessert, the machine or the results began without a refresh: close.
	if _card.visible and _is_blocked():
		close_card()


func _input(event: InputEvent) -> void:
	if _kept < 0 or not is_visible_in_tree():
		return
	var press: InputEventMouseButton = event as InputEventMouseButton
	if press == null or not press.pressed:
		return
	if press.button_index != MOUSE_BUTTON_LEFT and press.button_index != MOUSE_BUTTON_RIGHT:
		return
	for hit: Control in _hits:
		if hit.get_global_rect().has_point(press.global_position):
			return
	close_card()


func _build_pins() -> void:
	for node: Control in _faces + _hits:
		remove_child(node)
		node.free()
	_faces = []
	_hits = []
	_hovered = -1
	_kept = -1
	var count: int = _pins.size()
	var left: float = roundf((BADGE.size.x - (count - 1) * PIN_STEP - PIN_SIZE) / 2.0 / PX) * PX
	for slot: int in count:
		var at: Vector2 = BADGE.position + Vector2(left + slot * PIN_STEP, PIN_TOP)
		var face: PinFace = PinFace.new(PIN_SIZE)
		face.name = "Pin%d" % slot
		face.position = at
		face.show_pin(_pins[slot], slot)
		add_child(face)
		_faces.append(face)
		var hit: Control = Control.new()
		hit.name = "Hit%d" % slot
		hit.position = at
		hit.size = Vector2(PIN_SIZE, PIN_SIZE)
		hit.mouse_filter = Control.MOUSE_FILTER_STOP
		hit.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		hit.mouse_entered.connect(hover_pin.bind(slot, true))
		hit.mouse_exited.connect(hover_pin.bind(slot, false))
		hit.gui_input.connect(_on_hit_input.bind(slot))
		add_child(hit)
		_hits.append(hit)
	move_child(_card, get_child_count() - 1)
	queue_redraw()


func _on_hit_input(event: InputEvent, slot: int) -> void:
	var press: InputEventMouseButton = event as InputEventMouseButton
	if press != null and press.pressed and press.button_index == MOUSE_BUTTON_LEFT:
		press_pin(slot)
		accept_event()


func _update_card() -> void:
	if _is_blocked():
		_kept = -1
	var showing: int = _kept if _kept >= 0 else _hovered
	if not visible or _is_blocked() or showing < 0 or showing >= _pins.size():
		showing = -1
	var changed: bool = showing != _shown
	_shown = showing
	_lift_pins()
	if showing < 0:
		_card.visible = false
		return
	_card.show_for(
		_pins[showing],
		showing,
		charges_for(_pins[showing], _run),
		_kept == showing,
		_hits[showing].get_rect(),
		Rect2(card_area().position - RECT.position, card_area().size)
	)
	_card.visible = true
	if not changed:
		return
	if _pop != null:
		_pop.kill()
		_pop = null
	if _wants_reduced_motion() or not is_inside_tree():
		_card.scale = Vector2.ONE
		return
	_card.scale = Vector2.ONE * POP_FROM
	_pop = create_tween()
	_pop.tween_property(_card, "scale", Vector2.ONE, POP_S)


## The shown pin lifts LIFT px (its hit area stays), the others rest.
func _lift_pins() -> void:
	for slot: int in _faces.size():
		var lift: float = LIFT if slot == _shown else 0.0
		_faces[slot].position = _hits[slot].position - Vector2(0, lift)
	_ring.queue_redraw()


func _is_blocked() -> bool:
	return blocked.is_valid() and bool(blocked.call())


func _wants_reduced_motion() -> bool:
	return reduced_motion.is_valid() and bool(reduced_motion.call())


func _draw() -> void:
	_draw_strap()
	draw_rect(HOOK, Palette.INK)
	draw_rect(HOOK.grow(-PX), Palette.STEEL_LIGHT)
	draw_rect(Rect2(BADGE.position + SHADOW, BADGE.size), Color(Palette.INK, SHADOW_ALPHA))
	draw_rect(CLIP, Palette.INK)
	draw_rect(CLIP.grow(-PX), Palette.STEEL_LIGHT)
	draw_rect(
		Rect2(CLIP.position + Vector2(PX, PX), Vector2(CLIP.size.x - 2 * PX, PX)),
		Palette.STEEL_HIGHLIGHT
	)


## The teal strap with its ink edge: from the hook down-left to the bend over the clip, then down
## to the clip, in 2 px steps.
func _draw_strap() -> void:
	var steps: Array[Rect2] = []
	var run: float = STRAP_TOP.x - STRAP_BEND.x
	for x: int in range(int(STRAP_TOP.x), int(STRAP_BEND.x) - 1, -int(PX)):
		var t: float = (STRAP_TOP.x - x) / run
		var y: float = roundf(lerpf(STRAP_TOP.y, STRAP_BEND.y, t) / PX) * PX
		steps.append(Rect2(x - STRAP_WIDTH / 2.0, y, STRAP_WIDTH, STRAP_WIDTH))
	for y: int in range(int(STRAP_BEND.y), int(CLIP.position.y), int(PX)):
		steps.append(Rect2(STRAP_BEND.x - STRAP_WIDTH / 2.0, y, STRAP_WIDTH, PX))
	for step: Rect2 in steps:
		draw_rect(step.grow(PX), Palette.INK)
	for step: Rect2 in steps:
		draw_rect(step, Palette.TEAL)


## A gold ring one art px wide round the shown pin (its face grown two art px), on the 2 px grid,
## on the badge's face.
func _draw_ring() -> void:
	if _shown < 0 or _shown >= _faces.size():
		return
	var rect: Rect2 = Rect2(_faces[_shown].position, _faces[_shown].size).grow(2 * PX)
	var cells: int = int(rect.size.x / PX)
	var radius: float = cells / 2.0
	for row: int in cells:
		for column: int in cells:
			var distance: float = Vector2(column + 0.5 - radius, row + 0.5 - radius).length()
			if distance <= radius and distance > radius - 1.0:
				_ring.draw_rect(
					Rect2(rect.position + Vector2(column, row) * PX, Vector2(PX, PX)), Palette.GOLD
				)


static func _on_badge(rect: Rect2) -> Rect2:
	return Rect2(BADGE.position + rect.position, rect.size)
