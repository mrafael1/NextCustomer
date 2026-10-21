class_name BayBed
extends Control
## The scanner bay's scan bed (#86 round 7, mock-up count_up_86_v7_bay.html's ALIVE; ScannerBay's
## BED_RECT): a dark bed with a faint GRID px grid and a soft light under the item, the item's art
## at 2x (96x96, PaperBag.art_of) clipped to the bed's inside, in gold corners
## (ScanOverlay.draw_brackets), empty (IDLE_TEXT) with no item and "ALL PAID" once all are bagged.
## It shows planning's items too (ScannerBay.show_planning: belt slot 1's, or the held one's), on
## its own clock there.
##
## The item is alive: it drops in from above and lands with a squash and one bounce (drop_in),
## squashes and wobbles as each sticker slaps on (wobble), bobs while it waits and slides out
## toward the bag, turning and fading (slide_out). Its pose (pose()) is computed from three times
## (the drop's, the wobble's and the slide-out's progress) that run on make_tween's tweens (the
## count-up's, so they follow its taps, holds and hit-stops); the bob runs in real time. A scan
## (scan) sweeps a laser fan of FAN_RAYS rays over the item, then "BEEP!" pops up on it as the bed
## flashes, and the corners light. Reduced motion (`reduced_motion`) keeps every state (the fan
## still at its middle, the BEEP without its pop, the corners) and drops the drop, the bounce, the
## wobble, the bob, the slide-out and the flash. Display only.

## The item left the bed (its slide-out ended, or it went at once): the bed is empty.
signal emptied

const SIZE := Vector2(100, 100)
const BORDER := 2
## The bed's inside (the art's rect), in the bed's coordinates.
const INSIDE := Rect2(2, 2, 96, 96)
## Nothing on an empty bed (the monitor bay follow-up: the count starts with slot 1's item
## already in the bay, and planning shows an empty slot 1 as the bare bed).
const IDLE_TEXT := ""
const END_TEXT := "ALL\nPAID"
const IDLE_FONT_SIZE := 11
const IDLE_SPACING := 1
const IDLE_ALPHA := 0.75
## The bed: a GRID px grid of GRID_LINE px lines at GRID_ALPHA, a soft light (GLOW_ALPHA, two
## steps) on an ellipse GLOW_RADII round GLOW_CENTRE (inside coordinates), and a shade SHADE px
## deep under its top border at SHADE_ALPHA.
const GRID := 12
const GRID_LINE := 2
const GRID_ALPHA := 0.16
const GLOW_CENTRE := Vector2(48, 86)
const GLOW_RADII := Vector2(42, 11)
const GLOW_ALPHA := 0.18
const SHADE := 2
const SHADE_ALPHA := 0.35
## The gold corners, inset BRACKET_INSET px in the inside, lit for BRACKET_LIT_S after a scan.
const BRACKET_INSET := 3.0
const BRACKET_LIT_S := 0.3
## The drop: a fall of FALL_S at most from FALL_FROM px above, stretched FALL_SCALE; then the land
## (LAND_S): a squash (LAND_SQUASH across and down) over LAND_SQUASH_S, one bounce BOUNCE_PX high
## over BOUNCE_S (at BOUNCE_SCALE) and a smaller squash (RESQUASH) over RESQUASH_S.
const FALL_S := 0.14
const FALL_FROM := 100.0
const FALL_SCALE := Vector2(0.92, 1.1)
const LAND_SQUASH_S := 0.06
const LAND_SQUASH := Vector2(0.26, 0.24)
const BOUNCE_S := 0.18
const BOUNCE_PX := 12.0
const BOUNCE_SCALE := Vector2(0.96, 1.05)
const RESQUASH_S := 0.06
const RESQUASH := 0.1
const LAND_S := LAND_SQUASH_S + BOUNCE_S + RESQUASH_S
## A slap's wobble: WOBBLE_HIT for its first WOBBLE_HIT_S, then a swing at WOBBLE_RATE radians per
## second of WOBBLE_SCALE and WOBBLE_DEG degrees, fading over WOBBLE_S.
const WOBBLE_S := 0.5
const WOBBLE_HIT_S := 0.05
const WOBBLE_HIT := Vector2(1.2, 0.82)
const WOBBLE_RATE := 34.0
const WOBBLE_SCALE := 0.1
const WOBBLE_DEG := 8.0
## The bob while the item waits: BOB_PX up on every other half of a BOB_HZ clock (real time).
const BOB_PX := 2.0
const BOB_HZ := 2.2
## The slide-out: over OUT_S at most, OUT_DX across (eased), OUT_DY down (accelerating), turning
## OUT_DEG degrees and fading.
const OUT_S := 0.22
const OUT_DX := -70.0
const OUT_DY := 26.0
const OUT_DEG := -24.0
## The art turns and squashes about its foot.
const ART_PIVOT := Vector2(48, 82)
## The laser fan: FAN_RAYS rays (degrees round the centre angle) from FAN_ORIGIN (art px, 2x)
## reaching FAN_REACH art px, their first FAN_CORE art px in the core colour, with a FAN_CORE_RECT
## block at the origin; the centre sweeps FAN_FROM to FAN_TO degrees over FAN_SWEEP_S, then the
## side rays blink at FAN_BLINK_HZ until FAN_S.
const FAN_ORIGIN := Vector2i(24, 47)
const FAN_RAYS: Array[float] = [-16.0, -8.0, 0.0, 8.0, 16.0]
## The middle ray, which never blinks.
const FAN_MIDDLE := 2
const FAN_FROM := -38.0
const FAN_TO := 38.0
const FAN_SWEEP_S := 0.16
const FAN_S := 0.3
const FAN_BLINK_HZ := 15.0
const FAN_REACH := Vector2i(2, 59)
const FAN_CORE := 8
const FAN_CORE_RECT := Rect2i(22, 46, 4, 2)
## "BEEP!": BEEP_DELAY_S after the scan, for BEEP_S, at BEEP_AT (inside coordinates) turned
## BEEP_TILT degrees about its left middle, popping from BEEP_POP over BEEP_POP_S. Tomato with a
## BEEP_BORDER ink border, BEEP_PAD px either side of its text.
const BEEP_TEXT := "BEEP!"
const BEEP_DELAY_S := 0.16
const BEEP_S := 0.45
const BEEP_POP := 1.6
const BEEP_POP_S := 0.08
const BEEP_TILT := -6.0
const BEEP_AT := Vector2(3, 30)
const BEEP_FONT_SIZE := 10
const BEEP_WEIGHT := 800
const BEEP_SPACING := 1
const BEEP_PAD := 3
const BEEP_BORDER := 2
const BEEP_HEIGHT := 16.0
## The bed flashes with the BEEP, from FLASH_ALPHA over FLASH_S (eased out).
const FLASH_ALPHA := 0.7
const FLASH_S := 0.18
const BED_COLOR := Palette.BACKGROUND
const BED_BORDER_COLOR := Palette.TEAL_BLACK
const GRID_COLOR := Palette.TEAL_LIGHT
const GLOW_COLOR := Palette.TEAL_PALE
const IDLE_COLOR := Palette.TEAL_LIGHT
const BRACKET_COLOR := Palette.MUSTARD_DARK
const BRACKET_LIT_COLOR := Palette.MUSTARD_LIGHT
const FLASH_COLOR := Palette.GLASS_GLOW
const FAN_COLOR := Palette.TOMATO
const FAN_CORE_COLOR := Palette.TOMATO_LIGHT
const FAN_MET_COLOR := Palette.GOOD
const FAN_MET_CORE_COLOR := Palette.GREEN_LIGHT
const BEEP_FACE := Palette.TOMATO
const BEEP_INK := Palette.INK
const BEEP_TEXT_COLOR := Palette.PAPER

## Returns a new tween on the count-up's clock (ScannerBay hands it the monitor's); none means the
## bed's own.
var make_tween: Callable = Callable()
## Returns whether to reduce motion (the profile's setting); an empty Callable means no.
var reduced_motion: Callable = Callable()

var _inside: Control
var _art_layer: Control
var _marks: Control
var _idle: Label
var _beep: Label
var _art: TextureRect
## The item shown (null when the bed is empty).
var _definition: CardDefinition
var _met: bool = false
var _brackets_lit: bool = false
## The drop's time (s; negative: at rest), its fall's length, the wobble's time (negative: none),
## the slide-out's progress (negative: none) and the bob's real-time clock.
var _drop_t: float = -1.0
var _fall_s: float = 0.0
var _wobble_t: float = -1.0
var _out_p: float = -1.0
var _clock: float = 0.0
var _bob: bool = false
## The fan's and the BEEP's time since they started (negative: hidden).
var _fan_t: float = -1.0
var _beep_t: float = -1.0
var _drop_tween: Tween
var _wobble_tween: Tween
var _out_tween: Tween
var _scan_tween: Tween


## The art's pose (offsets on the 2 px grid, turn in degrees, scale, alpha).
class BayPose:
	extends RefCounted
	var offset: Vector2 = Vector2.ZERO
	var rotation_deg: float = 0.0
	var scale: Vector2 = Vector2.ONE
	var alpha: float = 1.0


func _init() -> void:
	name = "BayBed"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	size = SIZE
	_inside = _part(self, "Inside")
	_inside.position = INSIDE.position
	_inside.clip_contents = true
	_art_layer = _part(_inside, "Art")
	_idle = UiKit.display_label(IDLE_TEXT, IDLE_FONT_SIZE, false)
	_idle.add_theme_font_override("font", ArtStyle.spaced_display_font(IDLE_SPACING))
	_idle.add_theme_color_override("font_color", Color(IDLE_COLOR, IDLE_ALPHA))
	_idle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_idle.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_idle.size = INSIDE.size
	_inside.add_child(_idle)
	_marks = _part(_inside, "Marks")
	_marks.draw.connect(_draw_marks)
	_beep = _beep_label()
	_inside.add_child(_beep)
	_place_beep()


func _ready() -> void:
	_idle.size = INSIDE.size
	_place_beep()


func _process(delta: float) -> void:
	_clock += delta
	var bob: bool = _bob_due()
	if bob != _bob:
		_bob = bob
		_apply_pose()


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, SIZE), BED_BORDER_COLOR)
	draw_rect(INSIDE, BED_COLOR)
	var grid: Color = Color(GRID_COLOR, GRID_ALPHA)
	for step: int in range(0, int(INSIDE.size.x), GRID):
		draw_rect(
			Rect2(INSIDE.position.x + step, INSIDE.position.y, GRID_LINE, INSIDE.size.y), grid
		)
		draw_rect(
			Rect2(INSIDE.position.x, INSIDE.position.y + step, INSIDE.size.x, GRID_LINE), grid
		)
	for reach: float in [1.0, 0.6]:
		_draw_glow(reach)
	draw_rect(
		Rect2(INSIDE.position, Vector2(INSIDE.size.x, SHADE)), Color(Palette.INK, SHADE_ALPHA)
	)


## `definition`'s item drops in (the last one goes): a fall of `fall_s` (at most FALL_S; 0 for
## none), then its land. Under reduced motion it is at rest at once.
func drop_in(definition: CardDefinition, fall_s: float) -> void:
	_kill_motion()
	_free_art()
	_art = PaperBag.art_of(definition)
	_definition = definition
	_art.position = Vector2.ZERO
	_art.pivot_offset = ART_PIVOT
	_art_layer.add_child(_art)
	_idle.visible = false
	_fall_s = clampf(fall_s, 0.0, FALL_S)
	_drop_t = -1.0
	if not _reduced() and is_inside_tree():
		_drop_t = 0.0
		var length: float = _fall_s + LAND_S
		_drop_tween = _new_tween()
		_drop_tween.tween_method(_set_drop_t, 0.0, length, length)
		_drop_tween.tween_callback(_set_drop_t.bind(-1.0))
	_apply_pose()


## A scan: the laser fan sweeps (green once `met`), BEEP! pops up BEEP_DELAY_S later as the bed
## flashes, and the corners light for BRACKET_LIT_S. Under reduced motion the fan stands at its
## middle and the BEEP shows without its pop or the flash.
func scan(met: bool) -> void:
	_stop_scan()
	_met = met
	_brackets_lit = true
	_fan_t = 0.0
	if is_inside_tree():
		_scan_tween = _new_tween().set_parallel(true)
		_scan_tween.tween_method(_set_fan_t, 0.0, FAN_S, FAN_S)
		_scan_tween.tween_method(_set_beep_t, 0.0, BEEP_S, BEEP_S).set_delay(BEEP_DELAY_S)
		_scan_tween.tween_callback(_unlight_brackets).set_delay(BRACKET_LIT_S)
	_redraw()


## A sticker slaps on after `delay` (s, on the count's clock): the item squashes, then wobbles.
## Nothing under reduced motion or with the bed empty.
func wobble(delay: float = 0.0) -> void:
	if _art == null or _reduced() or not is_inside_tree():
		return
	if _wobble_tween != null:
		_wobble_tween.kill()
	_wobble_t = -1.0
	_wobble_tween = _new_tween()
	_wobble_tween.tween_method(_set_wobble_t, 0.0, WOBBLE_S, WOBBLE_S).set_delay(delay)
	_wobble_tween.tween_callback(_set_wobble_t.bind(-1.0))


## The item slides out toward the bag over `seconds` (at most OUT_S), then goes (emptied); the
## BEEP goes at once. Under reduced motion (or for 0 s) it goes at once.
func slide_out(seconds: float) -> void:
	if _art == null:
		return
	_set_beep_t(-1.0)
	if _reduced() or seconds <= 0.0 or not is_inside_tree():
		_empty()
		return
	if _out_tween != null:
		_out_tween.kill()
	_out_p = 0.0
	var length: float = minf(seconds, OUT_S)
	_out_tween = _new_tween()
	_out_tween.tween_method(_set_out_p, 0.0, 1.0, length)
	_out_tween.tween_callback(_empty)


## The bed empty with `text` on it (IDLE_TEXT, END_TEXT).
func show_idle(text: String) -> void:
	_kill_motion()
	_free_art()
	_idle.text = text
	_idle.visible = true


## The quota met (a green fan), or not.
func set_met(met: bool) -> void:
	_met = met
	_marks.queue_redraw()


## A new count: idle (IDLE_TEXT), nothing moving.
func reset() -> void:
	_stop_scan()
	show_idle(IDLE_TEXT)
	_met = false
	_redraw()


## The item's art shown (null when the bed is empty), the idle text, the BEEP's label.
func art() -> TextureRect:
	return _art


## The item shown (null when the bed is empty).
func shown_definition() -> CardDefinition:
	return _definition if _art != null else null


## The item stops where it is and rests (its drop, wobble or slide-out cut short; still there).
func settle() -> void:
	_kill_motion()
	_drop_t = -1.0
	_wobble_t = -1.0
	_out_p = -1.0
	_apply_pose()


func idle_label() -> Label:
	return _idle


func beep_label() -> Label:
	return _beep


## The bed's inside (the art's rect, global).
func art_rect() -> Rect2:
	return _inside.get_global_rect()


## The fan's centre angle now (degrees), or NAN when it is not showing.
func fan_angle() -> float:
	if _fan_t < 0.0:
		return NAN
	return FAN_FROM + (FAN_TO - FAN_FROM) * _smoothstep(_fan_progress())


## The fan's rays' colour and their core's now (green once met).
func fan_colours() -> Array[Color]:
	if _met:
		return [FAN_MET_COLOR, FAN_MET_CORE_COLOR]
	return [FAN_COLOR, FAN_CORE_COLOR]


## The bed's flash now (alpha; 0 for none).
func flash() -> float:
	if _beep_t < 0.0 or _reduced():
		return 0.0
	var left: float = 1.0 - _beep_t / FLASH_S
	return FLASH_ALPHA * left * left if left > 0.0 else 0.0


## The art's pose now.
func art_pose() -> BayPose:
	return pose(_drop_t, _fall_s, _wobble_t, _out_p, _bob)


func is_leaving() -> bool:
	return _out_p >= 0.0


func has_item() -> bool:
	return _art != null


## The slide-out's part of the pose now (offset, turn and alpha; identity when not leaving), which
## the bay's tag and sticker copy.
func out_offset() -> BayPose:
	return out_pose(_out_p)


## The art's pose `drop_t` s after its drop started (negative: at rest) with a fall of `fall_s`,
## `wobble_t` s into a wobble (negative: none), `out_p` of the way out (negative: not leaving) and
## bobbed up or not. Pure.
static func pose(drop_t: float, fall_s: float, wobble_t: float, out_p: float, bob: bool) -> BayPose:
	var result: BayPose = BayPose.new()
	if drop_t >= 0.0 and drop_t < fall_s:
		var fallen: float = drop_t / fall_s
		result.offset.y = -FALL_FROM * (1.0 - fallen * fallen)
		result.scale = FALL_SCALE
	else:
		_land(result, drop_t - fall_s if drop_t >= 0.0 else LAND_S)
		if wobble_t >= 0.0 and wobble_t < WOBBLE_S:
			var fade: float = 1.0 - wobble_t / WOBBLE_S
			var swing: float = sin(wobble_t * WOBBLE_RATE) * fade * fade
			if wobble_t < WOBBLE_HIT_S:
				result.scale *= WOBBLE_HIT
			else:
				result.scale *= Vector2(1.0 + WOBBLE_SCALE * swing, 1.0 - WOBBLE_SCALE * swing)
			result.rotation_deg = WOBBLE_DEG * swing
		elif bob:
			result.offset.y -= BOB_PX
	if out_p >= 0.0:
		var along: float = clampf(out_p, 0.0, 1.0)
		result.offset.x = OUT_DX * _smoothstep(along)
		result.offset.y += OUT_DY * along * along
		result.rotation_deg = OUT_DEG * along
		result.alpha = 1.0 - along
	result.offset = result.offset.snapped(Vector2(2.0, 2.0))
	return result


## The slide-out's offset, turn and alpha at `out_p` of the way out (negative: none). Pure.
static func out_pose(out_p: float) -> BayPose:
	var result: BayPose = BayPose.new()
	if out_p < 0.0:
		return result
	var along: float = clampf(out_p, 0.0, 1.0)
	result.offset = Vector2(OUT_DX * _smoothstep(along), OUT_DY * along * along)
	result.offset = result.offset.snapped(Vector2(2.0, 2.0))
	result.rotation_deg = OUT_DEG * along
	result.alpha = 1.0 - along
	return result


## The land `landed` s after the fall ended: the squash, the bounce and the second squash.
static func _land(result: BayPose, landed: float) -> void:
	if landed < LAND_SQUASH_S:
		var squash: float = 1.0 - landed / LAND_SQUASH_S
		result.scale = Vector2(1.0 + LAND_SQUASH.x * squash, 1.0 - LAND_SQUASH.y * squash)
	elif landed < LAND_SQUASH_S + BOUNCE_S:
		var up: float = (landed - LAND_SQUASH_S) / BOUNCE_S
		result.offset.y = -sin(up * PI) * BOUNCE_PX
		result.scale = BOUNCE_SCALE
	elif landed < LAND_S:
		var squash: float = 1.0 - (landed - LAND_SQUASH_S - BOUNCE_S) / RESQUASH_S
		result.scale = Vector2(1.0 + RESQUASH * squash, 1.0 - RESQUASH * squash)


static func _smoothstep(progress: float) -> float:
	var along: float = clampf(progress, 0.0, 1.0)
	return along * along * (3.0 - 2.0 * along)


## Over the art: the flash, the laser fan and the gold corners.
func _draw_marks() -> void:
	var rect: Rect2 = Rect2(Vector2.ZERO, INSIDE.size)
	var alpha: float = flash()
	if alpha > 0.0:
		_marks.draw_rect(rect, Color(FLASH_COLOR, alpha))
	if _fan_t >= 0.0:
		_draw_fan()
	var corners: Color = BRACKET_LIT_COLOR if _brackets_lit else BRACKET_COLOR
	ScanOverlay.draw_brackets(_marks, rect.grow(-BRACKET_INSET), corners)


## The fan's rays, cell by cell (2x), stopping at the art's edge, and its core block.
func _draw_fan() -> void:
	var colours: Array[Color] = fan_colours()
	var colour: Color = colours[0]
	var core: Color = colours[1]
	var centre: float = fan_angle()
	var blink: bool = (
		not _reduced() and _fan_t > FAN_SWEEP_S and int(_fan_t * FAN_BLINK_HZ * 2.0) % 2 == 1
	)
	var cells: int = int(INSIDE.size.x / ArtStyle.ART_SCALE)
	for index: int in range(FAN_RAYS.size()):
		if blink and index != FAN_MIDDLE:
			continue
		var angle: float = deg_to_rad(centre + FAN_RAYS[index])
		var along: Vector2 = Vector2(sin(angle), -cos(angle))
		for reach: int in range(FAN_REACH.x, FAN_REACH.y + 1):
			var cell: Vector2i = Vector2i((Vector2(FAN_ORIGIN) + along * reach).round())
			if cell.x < 0 or cell.x >= cells or cell.y < 0:
				break
			_marks.draw_rect(
				_cell(Rect2i(cell, Vector2i.ONE)), core if reach < FAN_CORE else colour
			)
	_marks.draw_rect(_cell(FAN_CORE_RECT), core)


## An art-px rect in the inside's px.
static func _cell(rect: Rect2i) -> Rect2:
	return Rect2(
		Vector2(rect.position) * ArtStyle.ART_SCALE, Vector2(rect.size) * ArtStyle.ART_SCALE
	)


## The soft light under the item: an ellipse (GLOW_RADII times `reach`) of 2 px rows.
func _draw_glow(reach: float) -> void:
	var radii: Vector2 = GLOW_RADII * reach
	var colour: Color = Color(GLOW_COLOR, GLOW_ALPHA)
	var row: float = -radii.y
	while row <= radii.y:
		var across: float = radii.x * sqrt(maxf(0.0, 1.0 - pow(row / radii.y, 2.0)))
		var half: float = snappedf(across, 2.0)
		var y: float = snappedf(GLOW_CENTRE.y + row, 2.0)
		if half > 0.0 and y < INSIDE.size.y:
			draw_rect(
				Rect2(INSIDE.position + Vector2(GLOW_CENTRE.x - half, y), Vector2(2.0 * half, 2.0)),
				colour
			)
		row += 2.0


func _fan_progress() -> float:
	if _reduced():
		return 0.5
	return clampf(_fan_t / FAN_SWEEP_S, 0.0, 1.0)


func _set_drop_t(seconds: float) -> void:
	_drop_t = seconds
	_apply_pose()


func _set_wobble_t(seconds: float) -> void:
	_wobble_t = seconds
	_apply_pose()


func _set_out_p(progress: float) -> void:
	_out_p = progress
	_apply_pose()


func _set_fan_t(seconds: float) -> void:
	_fan_t = seconds if seconds < FAN_S else -1.0
	_marks.queue_redraw()


func _set_beep_t(seconds: float) -> void:
	_beep_t = seconds if seconds < BEEP_S else -1.0
	_beep.visible = _beep_t >= 0.0
	var pop: float = 1.0
	if _beep_t >= 0.0 and _beep_t < BEEP_POP_S and not _reduced():
		pop = BEEP_POP + (1.0 - BEEP_POP) * _beep_t / BEEP_POP_S
	_beep.scale = Vector2.ONE * pop
	_marks.queue_redraw()


func _unlight_brackets() -> void:
	_brackets_lit = false
	_marks.queue_redraw()


## The art's pose from the times now.
func _apply_pose() -> void:
	if _art == null:
		return
	var now: BayPose = art_pose()
	_art.position = now.offset
	_art.rotation_degrees = now.rotation_deg
	_art.scale = now.scale
	_art.modulate.a = now.alpha


## Whether the art bobs up now: landed, still, not leaving, with motion.
func _bob_due() -> bool:
	if _art == null or _out_p >= 0.0 or _drop_t >= 0.0 or _reduced():
		return false
	return int(floorf(_clock * BOB_HZ)) % 2 == 1


## The item went: the bed empty (no idle text between items).
func _empty() -> void:
	_kill_motion()
	_free_art()
	_set_beep_t(-1.0)
	_idle.visible = false
	emptied.emit()


func _free_art() -> void:
	if _art != null:
		_art.queue_free()
		_art = null
	_definition = null
	_drop_t = -1.0
	_wobble_t = -1.0
	_out_p = -1.0
	_bob = false


func _kill_motion() -> void:
	for tween: Tween in [_drop_tween, _wobble_tween, _out_tween]:
		if tween != null:
			tween.kill()
	_drop_tween = null
	_wobble_tween = null
	_out_tween = null


func _stop_scan() -> void:
	if _scan_tween != null:
		_scan_tween.kill()
		_scan_tween = null
	_fan_t = -1.0
	_set_beep_t(-1.0)
	_brackets_lit = false


## The BEEP's label: tomato, an ink border, paper text letter-spaced, hidden.
func _beep_label() -> Label:
	var label: Label = Label.new()
	label.name = "Beep"
	label.text = BEEP_TEXT
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var font: FontVariation = FontVariation.new()
	font.base_font = ArtStyle.bold_font(BEEP_WEIGHT)
	font.spacing_glyph = BEEP_SPACING
	label.add_theme_font_override("font", font)
	label.add_theme_font_size_override("font_size", BEEP_FONT_SIZE)
	label.add_theme_color_override("font_color", BEEP_TEXT_COLOR)
	label.add_theme_constant_override("outline_size", 0)
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	var face: StyleBoxFlat = StyleBoxFlat.new()
	face.bg_color = BEEP_FACE
	face.border_color = BEEP_INK
	face.set_border_width_all(BEEP_BORDER)
	face.content_margin_left = BEEP_PAD + BEEP_BORDER
	face.content_margin_right = BEEP_PAD + BEEP_BORDER
	face.content_margin_top = 0
	face.content_margin_bottom = 0
	label.add_theme_stylebox_override("normal", face)
	label.visible = false
	return label


## The BEEP at BEEP_AT, its own size, turned BEEP_TILT about its left middle.
func _place_beep() -> void:
	_beep.size = Vector2(_beep.get_minimum_size().x, BEEP_HEIGHT)
	_beep.position = BEEP_AT
	_beep.pivot_offset = Vector2(0.0, BEEP_HEIGHT / 2.0)
	_beep.rotation_degrees = BEEP_TILT


## A part of `parent` over its whole inside, taking no clicks.
static func _part(parent: Control, part_name: String) -> Control:
	var part: Control = Control.new()
	part.name = part_name
	part.mouse_filter = Control.MOUSE_FILTER_IGNORE
	part.size = INSIDE.size
	parent.add_child(part)
	return part


func _redraw() -> void:
	queue_redraw()
	_marks.queue_redraw()


func _new_tween() -> Tween:
	return make_tween.call() as Tween if make_tween.is_valid() else create_tween()


func _reduced() -> bool:
	return reduced_motion.is_valid() and bool(reduced_motion.call())
