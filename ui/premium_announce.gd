class_name PremiumAnnounce
extends Control
## The PREMIUM NEXT announce (v0.50, mock-up premium_machine_v1.html, scene 1): in the planning of
## a shift whose pass earns the next receipt a PREMIUM visit (RewardMachine.premium_if_passed), a
## gold receipt prints down inside the hung monitor's screen over a dithered gold sunburst
## (presentation/dither_burst.gdshader; "NEXT RECEIPT", PREMIUM between two pixel stars, the
## rarity boost it gives, v0.61 #108: "EVERY TICKET RARE+" between two RARE diamonds and "ITEMS BIG
## OR BETTER", then "MEET THIS SHIFT'S QUOTA"), then shrinks and flies up to
## hang, on a string from the quota mark (the flag once the quota is met, else the gauge's end),
## as a gold "PREMIUM NEXT" tag with a pixel star on the monitor's top bezel, clear of the brief's
## text, that glints every SHINE_PERIOD for the rest of the shift's planning and its count-up.
## A resumed run shows the tag at once; reduced motion (`reduced_motion`) skips the print, the
## flight, the bounce, the sunburst and the sparkles and keeps the tag still (no glint). Display
## only: the shift screen says when (show_tag, clear) and `active` says whether the tag still
## belongs on screen (planning, or the count-up).
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
## The receipt (canvas px): its size, how far under the monitor screen's top it prints (it fits
## inside the screen, scaled down only if the screen is shorter), its flown scale.
const RECEIPT_SIZE := Vector2(300, 150)
const RECEIPT_DROP := 4.0
const FLOWN_SCALE := 0.5
## The sunburst behind the receipt (clipped to the monitor's screen): its full radius and spin.
const BURST_RADIUS := 200.0
const BURST_SPIN := 0.5
const BURST_SHADER := preload("res://presentation/dither_burst.gdshader")
## The tag: its size, its gap right of the quota mark, how far it reaches into the monitor's
## screen under the top bezel (the brief's text starts lower), and its gap from the screen's right.
const TAG_SIZE := Vector2(152, 22)
const TAG_RIGHT := 28.0
const TAG_INTO := 4.0
const TAG_MARGIN := 12.0
## The star before PREMIUM NEXT and round PREMIUM: a 5x5 pixel star (PrizeTicket's LEGENDARY pip).
const STAR_GRID := "..x..xxxxx.xxx..x.x.x...x"
const STRING_DOTS := 10
const TAG_TEXT := "PREMIUM NEXT"
const TITLE_TEXT := "PREMIUM"
const HEAD_TEXT := "NEXT RECEIPT"
const FOOT_TEXT := "MEET THIS SHIFT'S QUOTA"
## What a PREMIUM visit gives (v0.61, #108: a rarity boost), on two lines.
const BOOST_TEXTS: Array[String] = ["EVERY TICKET RARE+", "ITEMS BIG OR BETTER"]
const BOOST_SIZES: Array[int] = [16, 13]
## The RARE pip (PrizeTicket's) either side of the first line, its gap from the text.
const DIAMOND_GRID := "..x...xxx.xxxxx.xxx...x.."
const DIAMOND_GAP := 14.0
const TITLE_SIZE := 28
const TAG_FONT_SIZE := 12
const MONO_SIZE := 13
const SMALL_MONO_SIZE := 12
const BOLD_WEIGHT := 800

## Whether reduced motion is on (the profile's setting; the shift screen sets it).
var reduced_motion: Callable = func() -> bool: return false
## Whether the tag still belongs on screen (the shift screen: planning, or the count-up).
var active: Callable = func() -> bool: return true
var _monitor: Control
var _bar: Control
var _flag: Control
var _shown: bool = false
## Seconds on the announce's clock (FLY_TO and later: the tag hangs).
var _time: float = 0.0
## The sunburst, in a clip over the monitor's screen, drawn behind the receipt.
var _burst_clip: Control
var _burst: ColorRect


func _init() -> void:
	name = "PremiumAnnounce"
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_burst_clip = Control.new()
	_burst_clip.name = "BurstClip"
	_burst_clip.clip_contents = true
	_burst_clip.show_behind_parent = true
	_burst_clip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_burst_clip.visible = false
	add_child(_burst_clip)
	_burst = ColorRect.new()
	_burst.name = "Burst"
	_burst.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_burst.size = Vector2.ONE * BURST_RADIUS * 2.0
	var look: ShaderMaterial = ShaderMaterial.new()
	look.shader = BURST_SHADER
	look.set_shader_parameter("rect_size", _burst.size)
	look.set_shader_parameter("outer_colour", Palette.GOLD)
	look.set_shader_parameter("middle_colour", Palette.MUSTARD_LIGHT)
	look.set_shader_parameter("core_colour", Palette.MUSTARD_PALE)
	_burst.material = look
	_burst_clip.add_child(_burst)


## The monitor the receipt prints on, the quota gauge and its flag (the quota mark once met) the
## tag hangs from.
func setup(monitor: Control, gauge: Control, flag: Control = null) -> void:
	_monitor = monitor
	_bar = gauge
	_flag = flag


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


## Seconds until the receipt has flown up and the tag's landing ring is over (0: none printing),
## so the bonus notice can wait for it.
func print_left() -> float:
	if not is_shown():
		return 0.0
	return maxf(0.0, FLY_TO + RING_LENGTH - _time)


## The tag's rect on screen (bounce included): right of the quota mark, on the monitor's top
## bezel, reaching TAG_INTO into its screen and never lower (its bounce only lifts it), kept
## TAG_MARGIN inside the screen's right edge.
func tag_rect() -> Rect2:
	var anchor: Vector2 = _anchor()
	var screen: Rect2 = monitor_screen()
	var bounce: float = 0.0
	if not reduced_motion.call():
		var k: float = maxf(0.0, _time - FLY_TO)
		bounce = -absf(sin(k * BOUNCE_RATE) * BOUNCE_HEIGHT * exp(-k * BOUNCE_DECAY))
	var x: float = minf(anchor.x + TAG_RIGHT, screen.end.x - TAG_MARGIN - TAG_SIZE.x)
	var y: float = screen.position.y + TAG_INTO - TAG_SIZE.y + bounce
	return Rect2(Vector2(floorf(x / 2.0), floorf(y / 2.0)) * 2.0, TAG_SIZE)


## The printed receipt's rect on screen at full size: centred in the monitor's screen,
## RECEIPT_DROP under its top, scaled down (print_scale) if the screen is too short to hold it.
func receipt_rect() -> Rect2:
	var screen: Rect2 = monitor_screen()
	var size_now: Vector2 = RECEIPT_SIZE * print_scale()
	var at: Vector2 = Vector2(screen.get_center().x - size_now.x / 2.0, screen.position.y)
	return Rect2(MachineArt.snap_point(at + Vector2(0, RECEIPT_DROP)), size_now)


## The receipt's scale at full print: 1, or less when the monitor's screen can't hold it.
func print_scale() -> float:
	var screen: Rect2 = monitor_screen()
	return clampf((screen.size.y - 2.0 * RECEIPT_DROP) / RECEIPT_SIZE.y, 0.1, 1.0)


## The monitor's screen (inside its bezel) in this control's coordinates.
func monitor_screen() -> Rect2:
	if _monitor == null:
		return Rect2()
	var to_screen: Transform2D = _monitor.get_global_transform_with_canvas()
	var mine: Transform2D = get_global_transform_with_canvas().affine_inverse()
	return (mine * to_screen) * MonitorView.local(ShiftStage.MONITOR_SCREEN_RECT)


## The tag's text.
func tag_text() -> String:
	return TAG_TEXT


func _process(delta: float) -> void:
	if not _shown:
		_burst_clip.visible = false
		return
	_time += delta
	_frame_burst()
	queue_redraw()


## Whether the sunburst shows now (for tests).
func burst_shown() -> bool:
	return _burst_clip.visible


## The sunburst behind the printing receipt: it grows with the print, turns, and fades as the
## receipt flies off; none under reduced motion or once the tag hangs.
func _frame_burst() -> void:
	var on: bool = is_shown() and _monitor != null and _time >= PRINT_FROM and _time < FLY_TO
	_burst_clip.visible = on and not reduced_motion.call()
	if not _burst_clip.visible:
		return
	var screen: Rect2 = monitor_screen()
	_burst_clip.position = screen.position
	_burst_clip.size = screen.size
	var centre: Vector2 = receipt_rect().get_center() - screen.position
	_burst.position = MachineArt.snap_point(centre - _burst.size / 2.0)
	var grow: float = MachineArt.ease_back(MachineArt.seg(_time, PRINT_FROM, PRINT_TO))
	var fade: float = 1.0 - MachineArt.seg(_time, FLY_FROM, FLY_TO)
	var look: ShaderMaterial = _burst.material as ShaderMaterial
	look.set_shader_parameter("radius", MachineArt.snap(BURST_RADIUS * grow))
	look.set_shader_parameter("alpha", fade)
	look.set_shader_parameter("rotation", _time * BURST_SPIN)


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
	var scale_by: float = print_scale() * lerpf(1.0, FLOWN_SCALE, fly)
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
					-12.0 + float((index * 94) % int(rect.size.x + 24.0)),
					12.0 + float((index * 58) % int(maxf(rect.size.y - 12.0, 1.0)))
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
	_text_if(HEAD_TEXT, Vector2(mid, 17), mono, MONO_SIZE, ink, cut)
	if cut >= 58.0:
		MachineArt.centred_text(
			self, TITLE_TEXT, Vector2(mid, 40), bold, TITLE_SIZE, ink, Palette.MUSTARD_PALE
		)
		var half: float = MachineArt.text_width(TITLE_TEXT, bold, TITLE_SIZE) / 2.0
		_draw_star(Vector2(mid - half - 18.0, 40), ink)
		_draw_star(Vector2(mid + half + 18.0, 40), ink)
	if cut >= 60.0:
		draw_rect(Rect2(24, 58, w - 48, 2), Palette.BRASS)
	_text_if(BOOST_TEXTS[0], Vector2(mid, 80), bold, BOOST_SIZES[0], ink, cut)
	if cut >= 90.0:
		var reach: float = MachineArt.text_width(BOOST_TEXTS[0], bold, BOOST_SIZES[0]) / 2.0
		_draw_grid(DIAMOND_GRID, Vector2(mid - reach - DIAMOND_GAP, 80), Palette.TEAL)
		_draw_grid(DIAMOND_GRID, Vector2(mid + reach + DIAMOND_GAP, 80), Palette.TEAL)
	_text_if(BOOST_TEXTS[1], Vector2(mid, 106), bold, BOOST_SIZES[1], ink, cut)
	if cut >= 126.0:
		draw_rect(Rect2(24, 124, w - 48, 2), Palette.BRASS)
	_text_if(FOOT_TEXT, Vector2(mid, 137), mono, SMALL_MONO_SIZE, ink, cut)


## The pixel star (STAR_GRID, 2 px per cell) centred on `centre`, in `colour`.
func _draw_star(centre: Vector2, colour: Color) -> void:
	_draw_grid(STAR_GRID, centre, colour)


## A 5x5 pixel grid (`grid`: "x" cells lit, 2 px per cell) centred on `centre`, in `colour`.
func _draw_grid(grid: String, centre: Vector2, colour: Color) -> void:
	var origin: Vector2 = MachineArt.snap_point(centre - Vector2(5, 5))
	for cell: int in range(25):
		if grid[cell] == "x":
			var at: Vector2 = origin + Vector2(cell % 5, floori(cell / 5.0)) * 2.0
			draw_rect(Rect2(at, Vector2(2, 2)), colour)


func _text_if(
	text: String, centre: Vector2, font: Font, font_size: int, colour: Color, cut: float
) -> void:
	if centre.y + font_size / 2.0 <= cut:
		MachineArt.centred_text(self, text, centre, font, font_size, colour)


## The hanging tag, its string from the quota mark, its glint and its landing sparkles.
func _draw_tag() -> void:
	var rect: Rect2 = tag_rect()
	var from: Vector2 = _anchor()
	var eyelet: Vector2 = rect.position + Vector2(9, 9)
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
	draw_rect(Rect2(rect.position + Vector2(6, 8), Vector2(6, 6)), Palette.BRASS_DARKEST)
	var bold: Font = ArtStyle.bold_font(BOLD_WEIGHT)
	var centre: Vector2 = rect.get_center() + Vector2(12, 0)
	MachineArt.centred_text(self, TAG_TEXT, centre, bold, TAG_FONT_SIZE, Palette.BRASS_DARKEST)
	var half: float = MachineArt.text_width(TAG_TEXT, bold, TAG_FONT_SIZE) / 2.0
	_draw_star(Vector2(centre.x - half - 10.0, centre.y), Palette.BRASS_DARKEST)
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


## Where the string hangs from: the quota mark, half way down the gauge: the flag once the quota
## is met (it stands at quota / spend), else the gauge's end.
func _anchor() -> Vector2:
	var bar: Rect2 = _bar_rect()
	if _flag != null and _flag.is_visible_in_tree():
		return Vector2(_screen_rect(_flag).get_center().x, bar.get_center().y)
	return Vector2(bar.end.x, bar.get_center().y)


func _bar_rect() -> Rect2:
	return _screen_rect(_bar)


## `item`'s rect in this control's coordinates (through the store camera's zoom, if any).
func _screen_rect(item: Control) -> Rect2:
	var to_screen: Transform2D = item.get_global_transform_with_canvas()
	var mine: Transform2D = get_global_transform_with_canvas().affine_inverse()
	return (mine * to_screen) * Rect2(Vector2.ZERO, item.size)
