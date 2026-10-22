class_name RarityTab
extends Control
## A prize ticket's rarity tab (#77, look F; build spec 4.2), over its ticket, inside the tray's
## x range: COMMON (a grey-light tab, bold Atkinson, no tilt), RARE! (a teal plate, Pixelify 24,
## -4 degrees, a hard ink shadow) or LEGENDARY!! (a paper stamp with a mustard-darkest double
## border, Pixelify 24, -8 degrees; at the pick wait it hops 2 px). Each rarity's text, plate and
## tilt differ, so a rarity never shows by colour alone. When a draw's tabs can't sit side by side
## in the tray at full size (PrizeTicket.tab_row), they go compact with less padding: bold
## Atkinson, RARE! 18 (the mock-up's size; Pixelify is only ever 12 or 24 px, full build plan
## 6.1) and LEGENDARY!! 16, so three LEGENDARY!! tabs fit between the tray's rail and the hood.
## It pops in (scaling down to its size) once its ticket's reveal is far enough; under reduced
## motion it appears at once and never hops. PrizeTicket builds it, places it (place()) and frames
## it with its own frame(t); it reads only view.plan, t and view.idle_time.

const TEXTS: Array[String] = ["COMMON", "RARE!", "LEGENDARY!!"]
const TILTS: Array[float] = [0.0, -4.0, -8.0]
const FONT_SIZES: Array[int] = [10, 24, 24]
const PADDING: Array[Vector2] = [Vector2(6, 2), Vector2(8, 2), Vector2(12, 4)]
const COMPACT_SIZES: Array[int] = [10, 18, 16]
const COMPACT_PADDING: Array[Vector2] = [Vector2(6, 2), Vector2(6, 2), Vector2(6, 4)]
## The tab shows from this point of its reveal (reduced motion: SHOW_RM), popping from POPS[r]
## to 1 by POP_ENDS[r].
const SHOW_FROM: Array[float] = [0.6, 0.6, 0.62]
const POP_ENDS: Array[float] = [0.75, 0.72, 0.76]
const POPS: Array[float] = [1.0, 1.8, 2.4]
const SHOW_RM := 0.3
## A LEGENDARY tab hops HOP px HOP_RATE times a second once revealed.
const HOP := 2.0
const HOP_RATE := 2.0
const SHADOW := 3.0
const BOLD_WEIGHT := 800

static var _bounds: Dictionary[int, Vector2] = {}

## The machine this part belongs to (setup(), build spec 4.2).
var view: RewardMachineView
var rarity: int = 0
## The ticket's index (its reveal) and the tab's rest position on the ticket.
var index: int = 0
var rest: Vector2 = Vector2.ZERO
## Whether the tab is at its compact size (set_compact()).
var compact: bool = false
var _label: Label


func _init(tab_rarity: int = 0, ticket_index: int = 0) -> void:
	rarity = clampi(tab_rarity, 0, TEXTS.size() - 1)
	index = ticket_index
	name = "RarityTab"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	if rarity == MachinePrize.Rarity.COMMON:
		_label = UiKit.body_label(TEXTS[rarity], FONT_SIZES[rarity], Palette.INK)
		_label.add_theme_font_override("font", ArtStyle.bold_font(BOLD_WEIGHT))
	else:
		_label = UiKit.display_label(TEXTS[rarity], FONT_SIZES[rarity], false)
	_label.name = "Text"
	_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	match rarity:
		MachinePrize.Rarity.RARE:
			_label.add_theme_color_override("font_color", Palette.PAPER)
			_label.add_theme_color_override("font_shadow_color", Palette.TEAL_SHADE)
			_label.add_theme_constant_override("shadow_offset_x", 2)
			_label.add_theme_constant_override("shadow_offset_y", 2)
		MachinePrize.Rarity.LEGENDARY:
			_label.add_theme_color_override("font_color", Palette.MUSTARD_DARKEST)
	add_child(_label)
	_fit()
	rotation = deg_to_rad(TILTS[rarity])
	visible = false


## The size of the tilted tab's bounding box (in the parent's px) for `tab_rarity` at full or
## compact size, so PrizeTicket can lay a draw's tabs out as a row.
static func bounds_of(tab_rarity: int, is_compact: bool) -> Vector2:
	var key: int = tab_rarity * 2 + (1 if is_compact else 0)
	if not _bounds.has(key):
		var tab: RarityTab = RarityTab.new(tab_rarity)
		tab.set_compact(is_compact)
		_bounds[key] = tab.tilted_size()
		tab.free()
	return _bounds[key]


## Hooks the tab to the machine (PrizeTicket calls it from its own setup()).
func setup(machine: RewardMachineView) -> void:
	view = machine


## Switches the tab to its compact size (or back), keeping its tilt about its centre.
func set_compact(on: bool) -> void:
	compact = on
	if rarity != MachinePrize.Rarity.COMMON:
		var font: Font = ArtStyle.bold_font(BOLD_WEIGHT) if on else ArtStyle.DISPLAY_FONT
		_label.add_theme_font_override("font", font)
	_label.add_theme_font_size_override("font_size", font_size())
	_fit()


## The size of the tab's bounding box once tilted about its centre.
func tilted_size() -> Vector2:
	var turn: float = absf(deg_to_rad(TILTS[rarity]))
	return Vector2(size.x * cos(turn) + size.y * sin(turn), size.x * sin(turn) + size.y * cos(turn))


## The tab's rest position on its ticket (top left, before its tilt).
func place(at: Vector2) -> void:
	rest = at
	position = at


## Shows the tab at time `t` (seconds) of view.plan.
func frame(t: float) -> void:
	var plan: MachinePlan = view.plan if view != null else null
	if plan == null or not plan.has_draw:
		visible = plan == null
		return
	var p: float = plan.reveal_progress(index, t)
	var rm: bool = plan.reduced_motion
	visible = p != MachinePlan.NOT_SET and p >= (SHOW_RM if rm else SHOW_FROM[rarity])
	var pop: float = 1.0
	var hop: float = 0.0
	if visible and not rm:
		var eased: float = StockroomWindow.ease_out(
			StockroomWindow.seg(p, SHOW_FROM[rarity], POP_ENDS[rarity])
		)
		pop = lerpf(POPS[rarity], 1.0, eased)
		var hopping: bool = rarity == MachinePrize.Rarity.LEGENDARY and p >= 1.0
		if hopping and int(floorf(view.idle_time * HOP_RATE)) % 2 == 1:
			hop = -HOP
	scale = Vector2(pop, pop)
	position = rest + Vector2(0, hop)


## The tab's text.
func text() -> String:
	return _label.text


## The tab's tilt in degrees (0 COMMON, -4 RARE, -8 LEGENDARY).
func tilt() -> float:
	return TILTS[rarity]


## The pixel size of its text.
func font_size() -> int:
	return COMPACT_SIZES[rarity] if compact else FONT_SIZES[rarity]


func _fit() -> void:
	var padding: Vector2 = COMPACT_PADDING[rarity] if compact else PADDING[rarity]
	_label.notification(Control.NOTIFICATION_THEME_CHANGED)
	_label.size = Vector2.ZERO
	size = (_label.get_minimum_size() + padding * 2.0).snapped(Vector2(2, 2))
	_label.size = size
	pivot_offset = size / 2.0


func _draw() -> void:
	var rect: Rect2 = Rect2(Vector2.ZERO, size)
	match rarity:
		MachinePrize.Rarity.RARE:
			draw_rect(Rect2(Vector2(SHADOW, SHADOW), size), Palette.INK)
			draw_rect(rect, Palette.INK)
			draw_rect(rect.grow(-2.0), Palette.TEAL)
		MachinePrize.Rarity.LEGENDARY:
			# A paper stamp with a double border.
			draw_rect(rect, Palette.MUSTARD_DARKEST)
			draw_rect(rect.grow(-2.0), Palette.PAPER)
			draw_rect(rect.grow(-4.0), Palette.MUSTARD_DARKEST)
			draw_rect(rect.grow(-6.0), Palette.PAPER)
		_:
			draw_rect(rect, Palette.INK)
			draw_rect(rect.grow(-2.0), Palette.GREY_LIGHT)
