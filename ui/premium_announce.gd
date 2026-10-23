class_name PremiumAnnounce
extends Control
## The PREMIUM NEXT announce (v0.50, mock-up premium_machine_v1.html, scene 1): in the planning of
## a shift whose pass earns the next receipt a PREMIUM visit (RewardMachine.boosted_if_passed), a
## gold receipt prints down the hung monitor ("NEXT RECEIPT", PREMIUM, the LOYALTY and UPGRADES
## keys' icons, "MEET THIS SHIFT'S QUOTA"), then shrinks and flies up to hang, on a string from
## the quota gauge's end (the quota mark), as a gold "PREMIUM NEXT" tag that glints every
## SHINE_PERIOD for the rest of the shift's planning and its count-up. A resumed run shows the tag
## at once; reduced motion (`reduced_motion`) skips the print, the flight, the bounce and the
## sparkles and keeps the tag still (no glint). Display only: the shift screen says when (show_tag,
## clear) and `active` says whether the tag still belongs on screen (planning, or the count-up).
## Drawn in code on the screen's own coordinates, at the art's 2 px grid.

## The mock-up's times (s): the print, the flight to the tag.
const PRINT_FROM := 0.5
const PRINT_TO := 1.3
const SPARKLES_FROM := 1.2
const FLY_FROM := 3.0
const FLY_TO := 3.6
const BOUNCE_RATE := 14.0
const BOUNCE_HEIGHT := 6.0
const BOUNCE_DECAY := 5.0
const RING_LENGTH := 0.6
const SHINE_PERIOD := 2.2
const SHINE_LENGTH := 0.5
const SHINE_DELAY := 0.4
## The receipt (canvas px): its size, how far under the monitor's top it prints, its flown scale.
const RECEIPT_SIZE := Vector2(300, 240)
const RECEIPT_DROP := 28.0
const FLOWN_SCALE := 0.32
## The tag: its size, its gap right of the quota mark and under the gauge.
const TAG_SIZE := Vector2(156, 30)
const TAG_RIGHT := 28.0
const TAG_DROP := 24.0
const STRING_DOTS := 10
const TAG_TEXT := "PREMIUM NEXT"
const TITLE_TEXT := "PREMIUM"
const HEAD_TEXT := "NEXT RECEIPT"
const FOOT_TEXT := "MEET THIS SHIFT'S QUOTA"
const KEY_TEXTS: Array[String] = ["LOYALTY", "UPGRADES"]
const TITLE_SIZE := 34
const TAG_FONT_SIZE := 14
const MONO_SIZE := 16
const SMALL_MONO_SIZE := 14
const BOLD_WEIGHT := 800
const UP_ARROW := preload("res://art/icons/up_arrow.png")
const STAMP_RING := preload("res://art/icons/stamp_ring.png")
const STAMP_EMPTY := preload("res://art/icons/stamp_ring_empty.png")
const ICON_SCALE := 4.0
const STAMP_SCALE := 2.0

## Whether reduced motion is on (the profile's setting; the shift screen sets it).
var reduced_motion: Callable = func() -> bool: return false
## Whether the tag still belongs on screen (the shift screen: planning, or the count-up).
var active: Callable = func() -> bool: return true
var _monitor: Control
var _bar: Control
var _shown: bool = false
## Seconds on the announce's clock (FLY_TO and later: the tag hangs).
var _time: float = 0.0


func _init() -> void:
	name = "PremiumAnnounce"
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


## The monitor the receipt prints on and the quota gauge the tag hangs from.
func setup(monitor: Control, gauge: Control) -> void:
	_monitor = monitor
	_bar = gauge


## Shows the announce: printed from the start (`printing`, a shift that just started) or as the
## hanging tag (a resumed run). Reduced motion always shows the tag.
func show_tag(printing: bool) -> void:
	_shown = true
	_time = 0.0 if printing and not reduced_motion.call() else FLY_TO + RING_LENGTH + SHINE_PERIOD
	queue_redraw()


## Takes the announce away (a shift that is not announcing, a new run).
func clear() -> void:
	_shown = false
	queue_redraw()


## Whether the announce is up (printing or hanging).
func is_shown() -> bool:
	return _shown and bool(active.call())


## Whether the tag hangs (the print and the flight are over).
func tag_hangs() -> bool:
	return is_shown() and _time >= FLY_TO


## The tag's rect on screen (bounce included).
func tag_rect() -> Rect2:
	var anchor: Vector2 = _anchor()
	var bounce: float = 0.0
	if not reduced_motion.call():
		var k: float = _time - FLY_TO
		bounce = roundf(sin(k * BOUNCE_RATE) * BOUNCE_HEIGHT * exp(-k * BOUNCE_DECAY) / 2.0) * 2.0
	var at: Vector2 = Vector2(anchor.x + TAG_RIGHT, _bar_rect().end.y + TAG_DROP + bounce)
	return Rect2(MachineArt.snap_point(at), TAG_SIZE)


## The printed receipt's rect on screen at full size (under the monitor's top, centred on it).
func receipt_rect() -> Rect2:
	var screen: Rect2 = _screen_rect(_monitor)
	var at: Vector2 = Vector2(screen.get_center().x - RECEIPT_SIZE.x / 2.0, screen.position.y)
	return Rect2(MachineArt.snap_point(at + Vector2(0, RECEIPT_DROP)), RECEIPT_SIZE)


## The tag's text.
func tag_text() -> String:
	return TAG_TEXT


func _process(delta: float) -> void:
	if not _shown:
		return
	_time += delta
	queue_redraw()


func _draw() -> void:
	if not is_shown() or _monitor == null or _bar == null:
		return
	if _time < FLY_TO:
		_draw_receipt()
		return
	_draw_tag()


## The gold receipt: printing down (its height grows), then shrinking on its way to the tag.
func _draw_receipt() -> void:
	if _time < PRINT_FROM:
		return
	var rect: Rect2 = receipt_rect()
	var fly: float = MachineArt.ease_in_out(MachineArt.seg(_time, FLY_FROM, FLY_TO))
	var shown: float = MachineArt.ease_out(MachineArt.seg(_time, PRINT_FROM, PRINT_TO))
	var to: Vector2 = tag_rect().position
	var origin: Vector2 = rect.position.lerp(to, fly)
	var scale_by: float = lerpf(1.0, FLOWN_SCALE, fly)
	draw_set_transform(origin, 0.0, Vector2(scale_by, scale_by))
	var height: float = MachineArt.snap(RECEIPT_SIZE.y * shown)
	_draw_slip(Rect2(Vector2.ZERO, Vector2(RECEIPT_SIZE.x, height)))
	draw_set_transform(Vector2.ZERO)
	if fly <= 0.0 and _time > SPARKLES_FROM:
		for index: int in range(5):
			var a: float = fmod(_time * 0.9 + index * 0.21, 1.0)
			var at: Vector2 = (
				rect.position
				+ Vector2(
					-12.0 + float((index * 94) % int(RECEIPT_SIZE.x + 24.0)),
					20.0 + float((index * 58) % 200)
				)
			)
			MachineArt.sparkle(self, at, 2.0 if a < 0.3 else 1.0, sin(PI * a))


## The slip's face, `area` tall (it prints top first), in its own coordinates.
func _draw_slip(area: Rect2) -> void:
	if area.size.y < MachineArt.PIXEL * 4.0:
		return
	var w: float = RECEIPT_SIZE.x
	var face: Rect2 = Rect2(Vector2.ZERO, RECEIPT_SIZE)
	var cut: float = area.size.y
	MachineArt.box(self, Rect2(Vector2.ZERO, Vector2(w, cut)), Palette.GOLD, Palette.BRASS_DARKEST)
	draw_rect(Rect2(2, 2, w - 4, 4), Palette.MUSTARD_PALE)
	if cut >= RECEIPT_SIZE.y:
		var zx: float = 0.0
		while zx < w:
			draw_rect(Rect2(zx, RECEIPT_SIZE.y - 2.0, 6, 6), Palette.GOLD)
			zx += 12.0
	var mono: Font = ArtStyle.MONO_FONT
	var bold: Font = ArtStyle.bold_font(BOLD_WEIGHT)
	var ink: Color = Palette.BRASS_DARKEST
	var mid: float = face.get_center().x
	_text_if(HEAD_TEXT, Vector2(mid, 30), mono, MONO_SIZE, ink, cut)
	if cut >= 84.0:
		MachineArt.centred_text(
			self, TITLE_TEXT, Vector2(mid, 68), bold, TITLE_SIZE, ink, Palette.MUSTARD_PALE
		)
		var half: float = MachineArt.text_width(TITLE_TEXT, bold, TITLE_SIZE) / 2.0
		MachineArt.sparkle(self, Vector2(mid - half - 20.0, 68), 2.0, 1.0)
		MachineArt.sparkle(self, Vector2(mid + half + 20.0, 68), 2.0, 1.0)
	if cut >= 98.0:
		draw_rect(Rect2(24, 96, w - 48, 2), Palette.BRASS)
	if cut >= 152.0:
		_draw_punch(Vector2(mid - 68.0, 132))
		var arrow: Vector2 = UP_ARROW.get_size() * ICON_SCALE
		var arrow_at: Vector2 = MachineArt.snap_point(Vector2(mid + 72.0, 132) - arrow / 2.0)
		draw_texture_rect(UP_ARROW, Rect2(arrow_at, arrow), false)
	_text_if(KEY_TEXTS[0], Vector2(mid - 68.0, 168), mono, SMALL_MONO_SIZE, ink, cut)
	_text_if(KEY_TEXTS[1], Vector2(mid + 72.0, 168), mono, SMALL_MONO_SIZE, ink, cut)
	if cut >= 190.0:
		draw_rect(Rect2(24, 188, w - 48, 2), Palette.BRASS)
	_text_if(FOOT_TEXT, Vector2(mid, 210), mono, SMALL_MONO_SIZE, ink, cut)


func _text_if(
	text: String, centre: Vector2, font: Font, font_size: int, colour: Color, cut: float
) -> void:
	if centre.y + font_size / 2.0 <= cut:
		MachineArt.centred_text(self, text, centre, font, font_size, colour)


## The LOYALTY key's mini punch card (the top bar's stamp slots, two stamped), centred on `centre`.
func _draw_punch(centre: Vector2) -> void:
	var card: Rect2 = Rect2(centre - Vector2(50, 18), Vector2(100, 38))
	MachineArt.box(self, card, Palette.CREAM, Palette.INK)
	draw_rect(Rect2(centre - Vector2(48, 16), Vector2(96, 4)), Palette.TEAL)
	for slot: int in range(3):
		var texture: Texture2D = STAMP_RING if slot < 2 else STAMP_EMPTY
		var at: Vector2 = centre + Vector2(-44 + slot * 30, -10)
		draw_texture_rect(texture, Rect2(at, texture.get_size() * STAMP_SCALE), false)


## The hanging tag, its string from the quota mark, its glint and its landing sparkles.
func _draw_tag() -> void:
	var rect: Rect2 = tag_rect()
	var from: Vector2 = _anchor()
	var eyelet: Vector2 = rect.position + Vector2(10, 14)
	for index: int in range(STRING_DOTS + 1):
		var at: Vector2 = from.lerp(eyelet, float(index) / STRING_DOTS)
		draw_rect(Rect2(MachineArt.snap_point(at), Vector2(2, 4)), Palette.BRASS_DARKEST)
	draw_rect(Rect2(rect.position + Vector2(2, 2), rect.size), Color(Palette.INK, 0.3))
	MachineArt.box(self, rect, Palette.GOLD, Palette.BRASS_DARKEST)
	draw_rect(
		Rect2(rect.position + Vector2(2, 2), Vector2(rect.size.x - 4, 2)), Palette.MUSTARD_PALE
	)
	var low: Vector2 = rect.position + Vector2(2, rect.size.y - 4)
	draw_rect(Rect2(low, Vector2(rect.size.x - 4, 2)), Palette.BRASS)
	draw_rect(Rect2(rect.position + Vector2(8, 12), Vector2(6, 6)), Palette.BRASS_DARKEST)
	var bold: Font = ArtStyle.bold_font(BOLD_WEIGHT)
	var centre: Vector2 = rect.get_center() + Vector2(10, 0)
	MachineArt.centred_text(self, TAG_TEXT, centre, bold, TAG_FONT_SIZE, Palette.BRASS_DARKEST)
	var half: float = MachineArt.text_width(TAG_TEXT, bold, TAG_FONT_SIZE) / 2.0
	MachineArt.sparkle(self, Vector2(centre.x - half - 10.0, centre.y), 1.0, 1.0)
	if reduced_motion.call():
		return
	var k: float = _time - FLY_TO
	var p: float = fmod(maxf(0.0, k - SHINE_DELAY), SHINE_PERIOD) / SHINE_LENGTH
	MachineArt.shine(self, rect.grow(-2.0), p, Palette.PAPER)
	if k < RING_LENGTH:
		for index: int in range(6):
			var angle: float = index / 6.0 * TAU
			var spot: Vector2 = (
				rect.get_center()
				+ Vector2(cos(angle) * (16.0 + k * 100.0), sin(angle) * (8.0 + k * 50.0))
			)
			MachineArt.sparkle(self, spot, 1.0, 1.0 - k / RING_LENGTH)


## Where the string hangs from: the gauge's end (the quota mark while short), half way down it.
func _anchor() -> Vector2:
	var bar: Rect2 = _bar_rect()
	return Vector2(bar.end.x, bar.get_center().y)


func _bar_rect() -> Rect2:
	return _screen_rect(_bar)


## `item`'s rect in this control's coordinates (through the store camera's zoom, if any).
func _screen_rect(item: Control) -> Rect2:
	var to_screen: Transform2D = item.get_global_transform_with_canvas()
	var mine: Transform2D = get_global_transform_with_canvas().affine_inverse()
	return (mine * to_screen) * Rect2(Vector2.ZERO, item.size)
