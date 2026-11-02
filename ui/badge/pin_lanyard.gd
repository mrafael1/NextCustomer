class_name PinLanyard
extends Control
## The run's badge pins on the shift screen (mock-up shift_scene_polish_v2 section 3, variant C,
## picked by the user on 2026-11-02): a small name badge hung on a teal lanyard from a steel hook
## on the monitor's left side, between the receipt column and the monitor, showing the pins the run
## wears (RunState.pins, one or two: the balance's pin_slots). Drawn on the 2 px art grid in stage
## coordinates (RECT, in the stage's world: the camera's glide takes it with the monitor): the
## hook, the strap down to the badge's clip, the brass plate with its gold glint, the teal band
## (no word: 2x pixel words don't fit a badge this small), and the worn pins (PinFace) on its
## paper face, centred. With no pin worn it hides.
##
## Hovering a pin opens its card (PinTip: name, rule and the charges left, PinPlay), with a gold
## ring round the pin; a click keeps it open (a click on the same pin, or anywhere else, closes
## it). The card pops in about its tail (at once under reduced motion); the badge never swings.
## It takes clicks on its pins only, never marking another click handled. Display only: the shift
## screen fills it (show_run, through PinFlow.refresh).

## The lanyard's whole rect on the stage: the badge and the hook on the monitor's bezel.
const RECT := Rect2(370, 80, 120, 114)
## In the lanyard's own coordinates: the badge, the hook, the clip, the strap's ends.
const BADGE := Rect2(0, 28, 100, 86)
const HOOK := Rect2(112, 0, 8, 10)
const CLIP := Rect2(40, 20, 20, 12)
const STRAP_TOP := Vector2(116, 4)
const STRAP_BEND := Vector2(50, 12)
const STRAP_WIDTH := 4.0
const PX := 2.0
## In the badge's coordinates: the band, the paper face, the pins.
const BAND := Rect2(4, 8, 92, 16)
const FACE := Rect2(4, 26, 92, 54)
const GLINT := Rect2(6, 4, 6, 2)
const SHADOW := Vector2(4, 4)
const SHADOW_ALPHA := 0.35
const PIN_SIZE := 36.0
const PIN_STEP := 44.0
const PIN_TOP := 34.0
## The card's pop (GlyphTips' own).
const POP_S := 0.08
const POP_FROM := 0.6
const CARD_Z := 100
const RELABELS_LEFT := "%d relabel%s left this shift"
const DAYS_OFF_LEFT := "%d day%s off left this week"

## Returns true when the player asked for reduced motion. None means false.
var reduced_motion: Callable = Callable()

var _run: RunState
var _pins: Array[PinDefinition] = []
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
	_card = PinTip.new()
	_card.z_index = CARD_Z
	_card.visible = false
	add_child(_card)
	visible = false


## Shows the pins `run` wears now (hidden with none), and refreshes an open card's charges.
func show_run(run: RunState) -> void:
	_run = run
	var worn: Array[PinDefinition] = []
	if run != null:
		worn = run.pins
	if worn != _pins:
		_pins = worn.duplicate()
		_build_pins()
	visible = not _pins.is_empty()
	if run != null and RunState.MACHINE_PHASES.has(run.phase):
		_kept = -1
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


## A click on pin `index`: keeps its card open, or closes it when it is the kept one.
func press_pin(index: int) -> void:
	_kept = -1 if _kept == index else index
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


func _input(event: InputEvent) -> void:
	if _kept < 0 or not is_visible_in_tree():
		return
	var press: InputEventMouseButton = event as InputEventMouseButton
	if press == null or not press.pressed:
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
	var showing: int = _kept if _kept >= 0 else _hovered
	if not visible or showing < 0 or showing >= _pins.size():
		showing = -1
	var changed: bool = showing != _shown
	_shown = showing
	queue_redraw()
	if showing < 0:
		_card.visible = false
		return
	var pin_rect: Rect2 = Rect2(_faces[showing].position, _faces[showing].size)
	var screen: Rect2 = Rect2(-RECT.position, ShiftStage.SIZE)
	_card.show_for(
		_pins[showing],
		showing,
		charges_for(_pins[showing], _run),
		_kept == showing,
		pin_rect,
		BADGE,
		screen
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


func _wants_reduced_motion() -> bool:
	return reduced_motion.is_valid() and bool(reduced_motion.call())


func _draw() -> void:
	_draw_strap()
	draw_rect(HOOK, Palette.INK)
	draw_rect(HOOK.grow(-PX), Palette.STEEL_LIGHT)
	var plate: Rect2 = BADGE
	draw_rect(Rect2(plate.position + SHADOW, plate.size), Color(Palette.INK, SHADOW_ALPHA))
	draw_rect(plate, Palette.INK)
	var brass: Rect2 = plate.grow(-PX)
	draw_rect(brass, Palette.BRASS)
	draw_rect(Rect2(brass.position, Vector2(brass.size.x, PX)), Palette.MUSTARD_LIGHT)
	draw_rect(Rect2(brass.position.x, brass.end.y - PX, brass.size.x, PX), Palette.BRASS_DARK)
	draw_rect(_on_badge(GLINT), Palette.GOLD)
	var band: Rect2 = _on_badge(BAND)
	draw_rect(band, Palette.TEAL_DARK)
	draw_rect(Rect2(band.position, Vector2(band.size.x, PX)), Palette.TEAL)
	var face: Rect2 = _on_badge(FACE)
	draw_rect(face, Palette.PAPER)
	draw_rect(Rect2(face.position.x, face.end.y - 2 * PX, face.size.x, PX), Palette.CREAM_SHADE)
	draw_rect(CLIP, Palette.INK)
	draw_rect(CLIP.grow(-PX), Palette.STEEL_LIGHT)
	draw_rect(
		Rect2(CLIP.position + Vector2(PX, PX), Vector2(CLIP.size.x - 2 * PX, PX)),
		Palette.STEEL_HIGHLIGHT
	)
	if _shown >= 0 and _shown < _faces.size():
		_draw_ring(Rect2(_faces[_shown].position, _faces[_shown].size).grow(2 * PX))


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


## A gold ring one art px wide round `rect` (a pin's face grown), on the 2 px grid.
func _draw_ring(rect: Rect2) -> void:
	var cells: int = int(rect.size.x / PX)
	var radius: float = cells / 2.0
	for row: int in cells:
		for column: int in cells:
			var distance: float = Vector2(column + 0.5 - radius, row + 0.5 - radius).length()
			if distance <= radius and distance > radius - 1.0:
				draw_rect(
					Rect2(rect.position + Vector2(column, row) * PX, Vector2(PX, PX)), Palette.GOLD
				)


func _on_badge(rect: Rect2) -> Rect2:
	return Rect2(BADGE.position + rect.position, rect.size)
