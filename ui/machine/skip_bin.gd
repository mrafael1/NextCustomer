class_name SkipBin
extends Button
## The SKIP bin (2026-10-29, mock-up pick_skip_cart.html): a small pedal bin centred under the
## prize row, on the machine's card layer, that bins the whole draw before a pick (it replaces the
## display's BIN IT ✕ and the picked ticket's "or bin them all ✕"). Resting the pointer on it (or
## focusing it) opens its lid, and the view makes every ticket shake under a shred mark
## (PrizeTicket.doomed) while the display asks BIN ALL 3?, so it reads as the whole draw going.
## It shows from the draw's last reveal's end until the pick or the bin (frame(t)), on a draw that
## can be binned (RewardMachine.can_bin), and takes a click once the machine has armed. Silent:
## MachineSounds plays the bin's sound when the landing is planned.

## The pointer came onto the bin or left it (focus counts too).
signal hover_changed(over: bool)

const SIZE := Vector2(80, 104)
## Its top, in machine coordinates: under KEEP ONE (PrizeRow.KEEP_MIDDLE_Y), clear of it with the
## lid open.
const TOP := 488.0
const TEXT := "SKIP"
const TEXT_SIZE := 16
const TEXT_WEIGHT := 800
const TEXT_TOP := 78.0
## The bin (px): its body, its lid (hinged at its left end, LID_OPEN degrees when open), its
## handle and its pedal.
const BODY := Rect2(18, 26, 44, 50)
const LID := Rect2(12, 16, 56, 10)
const HANDLE := Rect2(30, 8, 20, 10)
const PEDAL := Rect2(56, 68, 14, 6)
const RIBS := 3
const LID_OPEN := -24.0
## A disabled bin (not armed yet) is drawn this bright.
const DISABLED_SHADE := 0.6

## The machine this part belongs to (setup(), build spec 4.2).
var view: RewardMachineView
var _offered: bool = false
var _over: bool = false
var _label: Label


func _init() -> void:
	name = "SkipBin"
	text = ""
	flat = true
	size = SIZE
	custom_minimum_size = SIZE
	position = Vector2(PrizeRow.MIDDLE_X - SIZE.x / 2.0, TOP)
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	focus_mode = Control.FOCUS_ALL
	tooltip_text = ""
	for state: String in ["normal", "hover", "pressed", "disabled", "focus"]:
		add_theme_stylebox_override(state, StyleBoxEmpty.new())
	_label = UiKit.body_label(TEXT, TEXT_SIZE, Palette.PAPER)
	_label.name = "SkipLabel"
	_label.add_theme_font_override("font", ArtStyle.bold_font(TEXT_WEIGHT))
	_label.add_theme_color_override("font_shadow_color", Palette.INK)
	_label.add_theme_constant_override("shadow_offset_x", 0)
	_label.add_theme_constant_override("shadow_offset_y", 2)
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.position = Vector2(0, TEXT_TOP)
	_label.size = Vector2(SIZE.x, SIZE.y - TEXT_TOP)
	_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_label)
	mouse_entered.connect(func() -> void: _set_over(true))
	mouse_exited.connect(func() -> void: _set_over(false))
	focus_entered.connect(func() -> void: _set_over(true))
	focus_exited.connect(func() -> void: _set_over(false))
	visible = false
	disabled = true


## Hooks this part to the machine: RewardMachineView calls it once, when it builds the part.
func setup(machine: RewardMachineView) -> void:
	view = machine


## Offers the bin on this draw or not (it shows at the times frame(t) gives), and whether it takes
## a click yet.
func set_offered(shown: bool, enabled: bool) -> void:
	_offered = shown
	disabled = not enabled
	var shade: float = DISABLED_SHADE if disabled else 1.0
	modulate = Color(shade, shade, shade, 1.0)
	_show(_at(view.clock if view != null else 0.0))
	queue_redraw()


## Whether this draw offers the bin (set_offered), shown yet or not.
func offered() -> bool:
	return _offered


## Whether the pointer (or focus) is on it, its lid open.
func is_over() -> bool:
	return _over


## The bin at `t` on view.plan: shown from the draw's last reveal's end until the pick or the bin.
func frame(t: float) -> void:
	_show(_at(t))


## Whether the bin shows at `t`: offered, the draw's last reveal over, the pick not yet made (no
## plan: whenever offered).
func _at(t: float) -> bool:
	if not _offered:
		return false
	var plan: MachinePlan = view.plan if view != null else null
	if plan == null:
		return true
	if not plan.has_draw or plan.n_prizes <= 0:
		return false
	var last: int = plan.n_prizes - 1
	if t < plan.reveal_at[last] + plan.reveal_length[last]:
		return false
	return not (plan.has_landing and t >= plan.press)


func _show(shown: bool) -> void:
	if visible == shown:
		return
	visible = shown
	if not shown:
		_set_over(false)


func _set_over(over: bool) -> void:
	over = over and visible and not disabled
	if _over == over:
		return
	_over = over
	_label.add_theme_color_override("font_color", Palette.TOMATO_LIGHT if over else Palette.PAPER)
	queue_redraw()
	hover_changed.emit(over)


func _draw() -> void:
	var px: float = ArtStyle.ART_SCALE
	# The shadow, the body with its ribs and right-hand shade, the pedal.
	draw_rect(Rect2(BODY.position + Vector2(px, px) * 2.0, BODY.size), Color(Palette.INK, 0.35))
	MachineArt.box(self, BODY, Palette.STEEL_LIGHT, Palette.INK)
	draw_rect(
		Rect2(BODY.end.x - 3.0 * px, BODY.position.y + px, 2.0 * px, BODY.size.y - 2.0 * px),
		Palette.STEEL
	)
	var pitch: float = BODY.size.x / (RIBS + 1)
	for rib: int in range(1, RIBS + 1):
		var x: float = MachineArt.snap(BODY.position.x + rib * pitch)
		draw_rect(
			Rect2(x, BODY.position.y + 4.0 * px, px, BODY.size.y - 8.0 * px), Palette.STEEL_SHADE
		)
	MachineArt.box(self, PEDAL, Palette.CHARCOAL, Palette.INK)
	if _over:
		# The open bin's dark mouth.
		draw_rect(
			Rect2(BODY.position.x + px, BODY.position.y - px, BODY.size.x - 2.0 * px, px * 2.0),
			Palette.CHARCOAL
		)
	# The lid, turned on its hinge when open.
	var hinge: Vector2 = Vector2(LID.position.x, LID.end.y)
	var angle: float = deg_to_rad(LID_OPEN) if _over else 0.0
	draw_set_transform(hinge, angle)
	var lid: Rect2 = Rect2(LID.position - hinge, LID.size)
	var handle: Rect2 = Rect2(HANDLE.position - hinge, HANDLE.size)
	MachineArt.box(self, handle, Palette.STEEL, Palette.INK)
	MachineArt.box(self, lid, Palette.STEEL_LIGHT, Palette.INK)
	draw_set_transform(Vector2.ZERO)
