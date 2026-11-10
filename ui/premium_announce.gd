class_name PremiumAnnounce
extends Control
## The PREMIUM NEXT announce (v0.50, mock-up premium_machine_v1.html, scene 1): in the planning of
## a shift whose pass earns the next receipt a PREMIUM visit (RewardMachine.premium_if_passed), a
## gold receipt prints down inside the hung monitor's screen over a dithered gold sunburst
## (presentation/dither_burst.gdshader; "NEXT RECEIPT", PREMIUM between two pixel stars, the
## rarity boost it gives, v0.61 #108: "EVERY TICKET RARE+" between two RARE diamonds and "ITEMS BIG
## OR BETTER", then "MEET THIS SHIFT'S QUOTA"), then shrinks and flies up to
## hang, on a short string from the top bar's foot straight above it (since the shift scene
## polish moved the quota gauge into the register tower, so the string never crosses the receipt),
## as a gold "PREMIUM NEXT" tag with a pixel star on the monitor's top bezel, clear of the brief's
## text, that glints every SHINE_PERIOD for the rest of the shift's planning and its count-up.
## A resumed run shows the tag at once; reduced motion (`reduced_motion`) skips the print, the
## flight, the bounce, the sunburst and the sparkles and keeps the tag still (no glint). Display
## only: the shift screen says when (show_tag, clear) and `active` says whether the tag still
## belongs on screen (planning, or the count-up).
## A payday (v0.68, `payday`: passing the Manager's review pays two PREMIUM draws) reads as one
## announce: "PASS THE REVIEW", PAYDAY, "2 PREMIUM DRAWS" and "EVERY TICKET RARE+"; the inspection
## chip then promises no separate bonus ticket. A payday leaves no tag (the user's call of
## 2026-11-10, after playing the tag on the CHECKOUT key: "you can remove the golden payday on top
## of checkout"; the shift's brass look and the calendar's PAYDAY band say it for the rest of the
## shift): its receipt shrinks and flies to the calendar's PAYDAY band (setup's `calendar`),
## fading out on the way, and the announce is then over (is_shown() false). Reduced motion shows
## a payday's receipt still, with no print, sunburst or sparkles, then takes it away at once
## (FLY_FROM); a resumed payday shows nothing.
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
## The tag: its height and its shortest width (it is as wide as its text: tag_width()), how far it
## reaches into the monitor's screen under the top bezel (the brief's text starts lower), and its
## gap from the screen's left edge. Its text starts TAG_TEXT_X px in (the eyelet and the star
## before it) and ends TAG_TEXT_END px before its right edge.
const TAG_SIZE := Vector2(152, 22)
const TAG_TEXT_X := 28.0
const TAG_TEXT_END := 12.0
const TAG_INTO := 4.0
const TAG_MARGIN := 12.0
## A payday's receipt has no tag to fly to: how far through its flight it starts to fade out.
const PAYDAY_FADE_FROM := 0.4
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
## The tag's words: bold Atkinson at TAG_FONT_SIZE, TAG_SPACING px between glyphs (the mock-up's).
const TAG_FONT_SIZE := 13
const TAG_SPACING := 1
const MONO_SIZE := 13
const SMALL_MONO_SIZE := 12
const BOLD_WEIGHT := 800

## Whether reduced motion is on (the profile's setting; the shift screen sets it).
var reduced_motion: Callable = func() -> bool: return false
## Whether the tag still belongs on screen (the shift screen: planning, or the count-up).
var active: Callable = func() -> bool: return true
## The announce is a payday's (v0.68): show_tag sets it.
var payday: bool = false
var _monitor: Control
var _bar: Control
## The day calendar whose PAYDAY band a payday's receipt flies to (setup), or null: it shrinks
## where it is.
var _calendar: DayCalendar
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


## The monitor the receipt prints on, the top bar the tag's string hangs from and the day
## calendar a payday's receipt flies to (null: it shrinks where it is).
func setup(monitor: Control, top_bar: Control, calendar: DayCalendar = null) -> void:
	_monitor = monitor
	_bar = top_bar
	_calendar = calendar


## Shows the announce: printed from the start (`printing`, a shift that just started) or as the
## hanging tag (a resumed run), as a payday's when `is_payday` (v0.68). Reduced motion always
## shows the tag. A payday's has no tag: it prints (reduced motion: its receipt shows still) and
## is then over; a resumed one shows nothing.
func show_tag(printing: bool, is_payday: bool = false) -> void:
	_shown = true
	payday = is_payday
	var printed: bool = printing and (payday or not reduced_motion.call())
	_time = 0.0 if printed else FLY_TO + RING_LENGTH + SHINE_PERIOD
	self_modulate.a = 1.0
	queue_redraw()


## Takes the announce away (a shift that is not announcing, a new run).
func clear() -> void:
	_shown = false
	queue_redraw()


## Whether the announce is up (printing or hanging); never once a payday's receipt has gone.
func is_shown() -> bool:
	return _shown and bool(active.call()) and not (payday and _time >= receipt_end())


## Whether the tag hangs (the print and the flight are over); never on a payday.
func tag_hangs() -> bool:
	return is_shown() and not payday and _time >= FLY_TO


## When the receipt leaves the monitor (s on the announce's clock): at the flight's end, or for a
## payday's under reduced motion at once when the flight would start.
func receipt_end() -> float:
	return FLY_FROM if payday and reduced_motion.call() else FLY_TO


## Seconds until the receipt has flown up and the tag's landing ring is over (a payday: until its
## receipt has gone; 0: none printing), so the bonus notice can wait for it.
func print_left() -> float:
	if not is_shown():
		return 0.0
	return maxf(0.0, (receipt_end() if payday else FLY_TO + RING_LENGTH) - _time)


## The tag's rect on screen (bounce included): on the monitor's top bezel, TAG_MARGIN inside its
## screen's left edge, reaching TAG_INTO into its screen and never lower (its bounce only lifts
## it). PREMIUM NEXT's only: a payday has no tag.
func tag_rect() -> Rect2:
	var bounce: float = 0.0
	if not reduced_motion.call():
		var k: float = maxf(0.0, _time - FLY_TO)
		bounce = -absf(sin(k * BOUNCE_RATE) * BOUNCE_HEIGHT * exp(-k * BOUNCE_DECAY))
	var tag_size: Vector2 = Vector2(tag_width(), TAG_SIZE.y)
	var screen: Rect2 = monitor_screen()
	var x: float = screen.position.x + TAG_MARGIN
	var y: float = screen.position.y + TAG_INTO - TAG_SIZE.y + bounce
	return Rect2(Vector2(floorf(x / 2.0), floorf(y / 2.0)) * 2.0, tag_size)


## The tag's width: its text's (tag_font()) and the room before and after it, on even px, at
## least TAG_SIZE.x.
func tag_width() -> float:
	var text: float = MachineArt.text_width(TAG_TEXT, tag_font(), TAG_FONT_SIZE)
	var fitted: float = ceilf((TAG_TEXT_X + text + TAG_TEXT_END) / 2.0) * 2.0
	return maxf(fitted, TAG_SIZE.x)


## The receipt's rect on screen now: receipt_rect(), then shrinking on its way to the tag (a
## payday's: until its centre is on payday_target()).
func flying_rect() -> Rect2:
	var rect: Rect2 = receipt_rect()
	var fly: float = MachineArt.ease_in_out(MachineArt.seg(_time, FLY_FROM, FLY_TO))
	var to: Vector2 = tag_rect().position
	if payday:
		to = payday_target() - rect.size * FLOWN_SCALE / 2.0
	return Rect2(rect.position.lerp(to, fly), rect.size * lerpf(1.0, FLOWN_SCALE, fly))


## Where a payday's receipt flies to, in this control's coordinates: the centre of the day
## calendar's PAYDAY band, or the receipt's own centre when no band shows.
func payday_target() -> Vector2:
	var band: Rect2 = Rect2()
	if _calendar != null and _calendar.is_visible_in_tree():
		band = _calendar.part_rects()["payday_band"]
	if not band.has_area():
		return receipt_rect().get_center()
	var mine: Transform2D = get_global_transform().affine_inverse()
	return mine * band.get_center()


## The tag's font: bold Atkinson, TAG_SPACING px between glyphs.
static func tag_font() -> Font:
	return MachineArt.spaced(ArtStyle.bold_font(BOLD_WEIGHT), TAG_SPACING)


## The tag's string, from where it hangs (the top bar's foot, straight above the eyelet) to the
## tag's eyelet, on screen.
func string_ends() -> PackedVector2Array:
	var eyelet: Vector2 = tag_rect().position + Vector2(9, 9)
	var foot: float = _bar_rect().end.y if _bar != null else eyelet.y
	return PackedVector2Array([Vector2(eyelet.x, minf(foot, eyelet.y)), eyelet])


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


## The printed receipt's texts, top to bottom: the head, the title, the two boosts, the foot.
func receipt_texts() -> PackedStringArray:
	var boosts: Array[String] = Payday.ANNOUNCE_BOOSTS if payday else BOOST_TEXTS
	return PackedStringArray(
		[
			Payday.ANNOUNCE_HEAD if payday else HEAD_TEXT,
			Payday.ANNOUNCE_TITLE if payday else TITLE_TEXT,
			boosts[0],
			boosts[1],
			FOOT_TEXT,
		]
	)


func _process(delta: float) -> void:
	if not _shown:
		_burst_clip.visible = false
		return
	_time += delta
	if payday and _time >= receipt_end():
		clear()  # A payday's receipt has gone: it leaves no tag.
		_burst_clip.visible = false
		return
	self_modulate.a = receipt_alpha()
	_frame_burst()
	queue_redraw()


## The receipt's and the tag's opacity now: 1, but a payday's receipt fades out over the end of
## its flight (from PAYDAY_FADE_FROM of the way).
func receipt_alpha() -> float:
	if not payday or reduced_motion.call():
		return 1.0
	var fly: float = MachineArt.seg(_time, FLY_FROM, FLY_TO)
	return 1.0 - MachineArt.seg(fly, PAYDAY_FADE_FROM, 1.0)


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
		if payday and reduced_motion.call():
			_draw_still_receipt()
		else:
			_draw_receipt()
		return
	_draw_tag()


## A payday's receipt under reduced motion: whole and still until it goes (is_shown).
func _draw_still_receipt() -> void:
	var scale_by: float = print_scale()
	draw_set_transform(receipt_rect().position, 0.0, Vector2(scale_by, scale_by))
	_draw_slip(Rect2(Vector2.ZERO, RECEIPT_SIZE))
	draw_set_transform(Vector2.ZERO)


## The gold receipt: printing down (its height grows), then shrinking on its way to the tag (a
## payday's: to the calendar's PAYDAY band, its centre landing on the band's, fading out).
func _draw_receipt() -> void:
	if _time < PRINT_FROM:
		return
	var rect: Rect2 = receipt_rect()
	var fly: float = MachineArt.ease_in_out(MachineArt.seg(_time, FLY_FROM, FLY_TO))
	var shown: float = MachineArt.ease_out(MachineArt.seg(_time, PRINT_FROM, PRINT_TO))
	var scale_by: float = flying_rect().size.x / RECEIPT_SIZE.x
	draw_set_transform(flying_rect().position, 0.0, Vector2(scale_by, scale_by))
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
	var texts: PackedStringArray = receipt_texts()
	_text_if(texts[0], Vector2(mid, 17), mono, MONO_SIZE, ink, cut)
	if cut >= 58.0:
		MachineArt.centred_text(
			self, texts[1], Vector2(mid, 40), bold, TITLE_SIZE, ink, Palette.MUSTARD_PALE
		)
		var half: float = MachineArt.text_width(texts[1], bold, TITLE_SIZE) / 2.0
		_draw_star(Vector2(mid - half - 18.0, 40), ink)
		_draw_star(Vector2(mid + half + 18.0, 40), ink)
	if cut >= 60.0:
		draw_rect(Rect2(24, 58, w - 48, 2), Palette.BRASS)
	_text_if(texts[2], Vector2(mid, 80), bold, BOOST_SIZES[0], ink, cut)
	if cut >= 90.0:
		var reach: float = MachineArt.text_width(texts[2], bold, BOOST_SIZES[0]) / 2.0
		_draw_grid(DIAMOND_GRID, Vector2(mid - reach - DIAMOND_GAP, 80), Palette.TEAL)
		_draw_grid(DIAMOND_GRID, Vector2(mid + reach + DIAMOND_GAP, 80), Palette.TEAL)
	_text_if(texts[3], Vector2(mid, 106), bold, BOOST_SIZES[1], ink, cut)
	if cut >= 126.0:
		draw_rect(Rect2(24, 124, w - 48, 2), Palette.BRASS)
	_text_if(texts[4], Vector2(mid, 137), mono, SMALL_MONO_SIZE, ink, cut)


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


## The hanging tag, its string from the top bar's foot, its glint and its landing sparkles.
func _draw_tag() -> void:
	var rect: Rect2 = tag_rect()
	var ends: PackedVector2Array = string_ends()
	var from: Vector2 = ends[0]
	var eyelet: Vector2 = ends[1]
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
	var font: Font = tag_font()
	var tag: String = TAG_TEXT
	var half: float = MachineArt.text_width(tag, font, TAG_FONT_SIZE) / 2.0
	var centre: Vector2 = Vector2(rect.position.x + TAG_TEXT_X + half, rect.get_center().y)
	MachineArt.centred_text(self, tag, centre, font, TAG_FONT_SIZE, Palette.BRASS_DARKEST)
	_draw_star(Vector2(rect.position.x + TAG_TEXT_X - 8.0, centre.y), Palette.BRASS_DARKEST)
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


## The top bar's rect in this control's coordinates (through the store camera's zoom, if any).
func _bar_rect() -> Rect2:
	var to_screen: Transform2D = _bar.get_global_transform_with_canvas()
	var mine: Transform2D = get_global_transform_with_canvas().affine_inverse()
	return (mine * to_screen) * Rect2(Vector2.ZERO, _bar.size)
