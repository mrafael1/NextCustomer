class_name Storefront
extends Control
## The title's scene (#56, mock-up title_premium_directions.html, direction C+ "Storefront at
## night"): the store seen from the street at night, on the 640x360 art grid at 2x. The 1280x720
## stage is centred in the window like the shift screen's; the sky, the brick and the street run
## on past it (StorefrontArt.backdrop, painted once per window size), so a wider or taller window
## shows more street, never a letterbox gap.
##
## On the stage, back to front: the backdrop's fixed parts; the sky's idle (v0.80: now and then
## a star twinkles, a cross of light for TWINKLE_TIME, and every SHOOTING_GAP seconds a shooting
## star crosses the sky in art px steps); the sconce's light wedge over the
## menu and the sidewalk's neon reflections (both once the sign is lit); the right window's tube,
## which flickers; the doors' warm light spill on the sidewalk; the doors' two sliding leaves; the
## REWARDS bay (a glass annex with the REWARDS vinyl, the locked Loyalty poster and the sign-free
## toy machine, BareToyMachine); the neon sign (NeonSign); and a receipt scrap that blows along
## the sidewalk now and then (every SCRAP_GAP seconds, once the sign is lit). The menu's plates
## go on stage() (the title places them); the brick left of the doors is theirs.
##
## The title drives it: light_up() lights the sign (sign_lit follows), doors_hot (the primary
## entry under the mouse or the marker) cracks the doors DOORS_AJAR art px and brightens the
## spill, bay_hot (REWARDS) lights the bay and jiggles the machine once, scan_sign() is the sign's
## hidden toy (a scan line, the scanner's beep and one blink), open_doors() starts a run (the
## leaves slide apart in DOOR_STEP px steps, then the light floods the screen), and
## slide_bay_glass() opens REWARDS. The hit rects (doors_rect, bay_rect, sign_rect) are in this
## control's coordinates; the scene itself takes no clicks.
##
## `still` (the profile's reduced motion) holds every loop and slide: the tube stays lit, the sign
## lights at once and never stutters, swings or breathes, no star twinkles or shoots, no scrap
## blows, the machine doesn't
## jiggle, the doors and the bay glass don't slide (a start only floods, in steps).

## The sign is fully lit (after light_up()).
signal sign_lit

const STAGE_SIZE := Vector2(1280, 720)
## The sign's top left on the stage, in art px (centred over the doors, in the fascia).
const SIGN_AT := Vector2i(238, 53)
## The doors: a hover cracks them DOORS_AJAR art px; a start slides them DOORS_OPEN apart in
## DOOR_STEP px steps over DOOR_TIME, then the light floods the window in FLOOD_STEPS over
## FLOOD_TIME.
const DOORS_AJAR := 2
const DOORS_OPEN := 52
const DOOR_STEP := 4
const DOOR_TIME := 0.35
const FLOOD_TIME := 0.2
const FLOOD_STEPS := 3
const FLOOD_COLOR := Palette.MUSTARD_PALE
## The machine's jiggle: one art px either way, a step every JIGGLE_STEP for JIGGLE_TIME.
const JIGGLE_STEP := 0.06
const JIGGLE_TIME := 0.3
## The bay glass slides GLASS_STEP art px every GLASS_STEP_TIME for GLASS_TIME.
const GLASS_STEP := 12
const GLASS_STEP_TIME := 0.06
const GLASS_TIME := 0.3
## The tube's flicker (the mock-up's script): off in TUBE_FRAME frames 2 and 4 of every
## TUBE_CYCLE, and frame 9 of every TUBE_CYCLE_2.
const TUBE_FRAME := 0.08
const TUBE_CYCLE := 37
const TUBE_OFF: Array[int] = [2, 4]
const TUBE_CYCLE_2 := 53
const TUBE_OFF_2 := 9
## The receipt scrap: a 5x4 art px cream scrap crossing the window in SCRAP_TIME, bouncing up to
## SCRAP_BOUNCE px over its line SCRAP_Y, every SCRAP_GAP (min, max) seconds.
const SCRAP_TIME := 4.0
const SCRAP_GAP := Vector2(20.0, 30.0)
const SCRAP_Y := 318
const SCRAP_BOUNCE := 6.0
const SCRAP_WAVES := 18.0
const SCRAP_SIZE := Vector2i(5, 4)
## The twinkles: every TWINKLE_EVERY-th star (the backdrop's, on the stage) flashes a cross of
## light for TWINKLE_TIME once every TWINKLE_PERIOD seconds, each star at its own phase,
## TWINKLE_PHASE seconds after the one before.
const TWINKLE_EVERY := 4
const TWINKLE_PERIOD := 5.0
const TWINKLE_PHASE := 1.3
const TWINKLE_TIME := 0.24
## The shooting star: from SHOOTING_FROM (x min, x max, at row SHOOTING_TOP) it falls SHOOTING_STEP
## art px a step (left and down) every SHOOTING_STEP_TIME for SHOOTING_STEPS steps, its tail
## SHOOTING_TAIL px; the first SHOOTING_FIRST seconds in, then every SHOOTING_GAP (min, max).
const SHOOTING_FROM := Vector2i(160, 600)
const SHOOTING_TOP := 4
const SHOOTING_STEP := Vector2i(-3, 1)
const SHOOTING_STEP_TIME := 0.04
const SHOOTING_STEPS := 14
const SHOOTING_TAIL := 10
const SHOOTING_FIRST := 6.0
const SHOOTING_GAP := Vector2(14.0, 24.0)

## Holds every loop and slide (the profile's reduced motion).
var still: bool = false:
	set(value):
		still = value
		_sign.still = value
		_update_live()

## The primary entry (CONTINUE, START RUN) is hot: the doors stand ajar, the spill brightens.
var doors_hot: bool = false:
	set(value):
		doors_hot = value
		if _door_open <= DOORS_AJAR:
			_door_open = DOORS_AJAR if value else 0
		_spill.texture = StorefrontArt.layer("spill_hot" if value else "spill")
		_doors.queue_redraw()

## The REWARDS entry is hot: the bay lights, the machine shows its colours and jiggles once.
var bay_hot: bool = false:
	set(value):
		if value and not bay_hot and not still:
			_jiggle_at = _clock
		bay_hot = value
		_bay_lit.visible = value
		_machine.lit = value

var _clock: float = 0.0
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()
## The art px the backdrop shows past the stage (left, top, right, bottom).
var _extend: Vector4i = Vector4i.ZERO
var _backdrop: TextureRect
var _stage: Control
var _wedge: TextureRect
var _tube: TextureRect
var _reflections: TextureRect
var _spill: TextureRect
var _doors: Control
var _bay: Control
var _bay_lit: TextureRect
var _machine: BareToyMachine
var _glass: TextureRect
var _sign: NeonSign
var _scrap: Control
var _sky: Control
var _flood: ColorRect
## How far apart the door leaves stand, in art px.
var _door_open: int = 0
var _jiggle_at: float = -1.0
var _glass_at: float = -1.0
## The scrap's next start on the clock.
var _scrap_at: float = 0.0
## The shooting star's start on the clock and its first column.
var _shooting_at: float = SHOOTING_FIRST
var _shooting_x: int = 0


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_backdrop = UiKit.sprite(null)
	add_child(_backdrop)
	_stage = Control.new()
	_stage.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_stage.size = STAGE_SIZE
	add_child(_stage)
	_sky = Control.new()
	_sky.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_sky.size = STAGE_SIZE
	_sky.draw.connect(_draw_sky)
	_stage.add_child(_sky)
	_wedge = _add_layer("wedge")
	_tube = _add_layer("tube_on")
	_reflections = _add_layer("reflections")
	_wedge.hide()
	_reflections.hide()
	_spill = _add_layer("spill")
	_doors = Control.new()
	_doors.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_doors.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_doors.position = _canvas(StorefrontArt.DOORS_RECT.position)
	_doors.size = _canvas(StorefrontArt.DOORS_RECT.size)
	_doors.draw.connect(_draw_doors)
	_stage.add_child(_doors)
	_build_bay()
	_sign = NeonSign.new()
	_sign.position = _canvas(SIGN_AT)
	_sign.lit_up.connect(_on_sign_lit)
	_stage.add_child(_sign)
	_scrap = Control.new()
	_scrap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_scrap.size = STAGE_SIZE
	_scrap.draw.connect(_draw_scrap)
	_stage.add_child(_scrap)
	_flood = ColorRect.new()
	_flood.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_flood.color = Color(FLOOD_COLOR, 0.0)
	_flood.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_flood)
	_scrap_at = _rng.randf_range(SCRAP_GAP.x, SCRAP_GAP.y)
	_shooting_x = _rng.randi_range(SHOOTING_FROM.x, SHOOTING_FROM.y)
	resized.connect(_lay_out)
	_lay_out()
	_update_live()


## Lights the sign letter by letter (at once when `still`); sign_lit follows.
func light_up() -> void:
	_sign.light_up()


## Lights the sign at once (a click or key during the title's intro); sign_lit follows unless it
## was already lit.
func light_now() -> void:
	_sign.light_now()


## The sign is fully lit.
func is_lit() -> bool:
	return _sign.is_lit()


## The sign's hidden toy: a scan line sweeps across it with the scanner's beep, then it blinks.
func scan_sign() -> void:
	_sign.scan()
	Sfx.play_at(self, "scan")


## Starts a run: the doors slide open in DOOR_STEP px steps (not when `still`), then the light
## floods the window in FLOOD_STEPS. The title changes scene when the tween finishes.
func open_doors() -> Tween:
	var tween: Tween = create_tween()
	_spill.texture = StorefrontArt.layer("spill_hot")
	if not still:
		tween.tween_method(_set_doors_opening, 0.0, 1.0, DOOR_TIME)
	tween.tween_method(_set_flood, 0.0, 1.0, FLOOD_TIME)
	return tween


## Opens REWARDS: the bay's glass slides aside in GLASS_STEP px steps (nothing when `still`).
func slide_bay_glass() -> Tween:
	var tween: Tween = create_tween()
	if still:
		tween.tween_callback(_glass.hide)
		return tween
	_glass_at = _clock
	_glass.position.x = _canvas(StorefrontArt.BAY_GLASS.position).x
	_glass.show()
	tween.tween_interval(GLASS_TIME)
	tween.tween_callback(_glass.hide)
	return tween


## The stage the menu goes on (1280x720, centred in the window).
func stage() -> Control:
	return _stage


## The doors (a click starts the run), in this control's coordinates.
func doors_rect() -> Rect2:
	return _on_stage(StorefrontArt.DOORS_RECT)


## The REWARDS bay (a click opens REWARDS), in this control's coordinates.
func bay_rect() -> Rect2:
	return _on_stage(StorefrontArt.BAY_RECT)


## The neon sign with its tag (a click scans it), in this control's coordinates.
func sign_rect() -> Rect2:
	return Rect2(_stage.position + _sign.position, _sign.size)


## The neon sign, the bay's toy machine, and how far apart the door leaves stand (art px), for
## tests.
func neon_sign() -> NeonSign:
	return _sign


func machine() -> BareToyMachine:
	return _machine


func door_gap() -> int:
	return _door_open


## The flood's share now (0 none, 1 the whole window lit).
func flood() -> float:
	return _flood.color.a


## The art px the backdrop shows past the stage on each side (left, top, right, bottom).
func backdrop_extend() -> Vector4i:
	return _extend


## A live layer, for tests: "wedge", "tube_on", "reflections", "spill", "bay_lit", "glass",
## "scrap" or "sky" (null for any other id).
func layer(id: String) -> CanvasItem:
	var layers: Dictionary[String, CanvasItem] = {
		"wedge": _wedge,
		"tube_on": _tube,
		"reflections": _reflections,
		"spill": _spill,
		"bay_lit": _bay_lit,
		"glass": _glass,
		"scrap": _scrap,
		"sky": _sky,
	}
	return layers.get(id, null)


func _process(delta: float) -> void:
	_clock += delta
	_update_live()


## Steps the live layers to the clock: the tube's flicker, the machine's jiggle, the glass's
## slide and the scrap.
func _update_live() -> void:
	_tube.visible = still or _tube_lit()
	var jiggle: int = 0
	var since_jiggle: float = _clock - _jiggle_at
	if _jiggle_at >= 0.0 and since_jiggle < JIGGLE_TIME and not still:
		jiggle = 1 if int(since_jiggle / JIGGLE_STEP) % 2 else -1
	_machine.position = _canvas(StorefrontArt.BAY_MACHINE + Vector2i(jiggle, 0))
	if _glass.visible and _glass_at >= 0.0:
		var steps: int = int((_clock - _glass_at) / GLASS_STEP_TIME)
		_glass.position.x = (
			_canvas(StorefrontArt.BAY_GLASS.position + Vector2i(steps * GLASS_STEP, 0)).x
		)
	if is_lit() and not still and _clock >= _scrap_at + SCRAP_TIME:
		_scrap_at = _clock + _rng.randf_range(SCRAP_GAP.x, SCRAP_GAP.y)
	_scrap.queue_redraw()
	if _clock >= _shooting_at + SHOOTING_STEPS * SHOOTING_STEP_TIME:
		_shooting_at = _clock + _rng.randf_range(SHOOTING_GAP.x, SHOOTING_GAP.y)
		_shooting_x = _rng.randi_range(SHOOTING_FROM.x, SHOOTING_FROM.y)
	_sky.queue_redraw()


## The stars twinkling now (their stage art px), none when `still`.
func twinkles() -> Array[Vector2i]:
	var shown: Array[Vector2i] = []
	if still:
		return shown
	var star: int = 0
	for i: int in StorefrontArt.STARS:
		if i % StorefrontArt.STAR_HIDDEN_EVERY == 0 or i % TWINKLE_EVERY:
			continue
		var at: float = fmod(_clock + star * TWINKLE_PHASE, TWINKLE_PERIOD)
		star += 1
		if at < TWINKLE_TIME:
			shown.append(StorefrontArt.star_at(i))
	return shown


## The shooting star's head now (stage art px), or (-1, -1) when none is crossing.
func shooting_star() -> Vector2i:
	var since: float = _clock - _shooting_at
	if still or since < 0.0 or since >= SHOOTING_STEPS * SHOOTING_STEP_TIME:
		return Vector2i(-1, -1)
	var step: int = int(since / SHOOTING_STEP_TIME)
	return Vector2i(_shooting_x, SHOOTING_TOP) + SHOOTING_STEP * step


func _tube_lit() -> bool:
	var frame: int = int(_clock / TUBE_FRAME)
	return not (frame % TUBE_CYCLE in TUBE_OFF or frame % TUBE_CYCLE_2 == TUBE_OFF_2)


## Places the stage in the window's middle and the backdrop round it.
func _lay_out() -> void:
	var scale_px: int = ArtStyle.ART_SCALE
	var stage_at: Vector2 = ((size - STAGE_SIZE) / 2.0).floor()
	_stage.position = stage_at
	var left: int = maxi(ceili(stage_at.x / scale_px), 0)
	var top: int = maxi(ceili(stage_at.y / scale_px), 0)
	var right: int = maxi(ceili((size.x - stage_at.x - STAGE_SIZE.x) / scale_px), 0)
	var bottom: int = maxi(ceili((size.y - stage_at.y - STAGE_SIZE.y) / scale_px), 0)
	var extend := Vector4i(left, top, right, bottom)
	if extend != _extend or _backdrop.texture == null:
		_extend = extend
		_backdrop.texture = StorefrontArt.backdrop(extend)
	_backdrop.size = _backdrop.texture.get_size() * scale_px
	_backdrop.position = stage_at - Vector2(left, top) * scale_px


func _build_bay() -> void:
	var bay_rect_art: Rect2i = StorefrontArt.BAY_RECT
	_bay = Control.new()
	_bay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_bay.clip_contents = true
	_bay.position = _canvas(bay_rect_art.position)
	_bay.size = _canvas(bay_rect_art.size)
	_stage.add_child(_bay)
	var night: TextureRect = UiKit.sprite(StorefrontArt.layer("bay_night"))
	night.size = _bay.size
	_bay.add_child(night)
	_bay_lit = UiKit.sprite(StorefrontArt.layer("bay_lit"))
	_bay_lit.size = _bay.size
	_bay_lit.hide()
	_bay.add_child(_bay_lit)
	_machine = BareToyMachine.new()
	_machine.position = _canvas(StorefrontArt.BAY_MACHINE)
	_bay.add_child(_machine)
	_glass = UiKit.sprite(StorefrontArt.layer("glass"))
	_glass.size = _canvas(StorefrontArt.BAY_GLASS.size)
	_glass.position = _canvas(StorefrontArt.BAY_GLASS.position)
	_glass.hide()
	_bay.add_child(_glass)


## A live layer's sprite at its rect on the stage.
func _add_layer(id: String) -> TextureRect:
	var rect_art: Rect2i = StorefrontArt.layer_rect(id)
	var sprite: TextureRect = UiKit.sprite(StorefrontArt.layer(id))
	sprite.position = _canvas(rect_art.position)
	sprite.size = _canvas(rect_art.size)
	_stage.add_child(sprite)
	return sprite


func _on_sign_lit() -> void:
	_wedge.show()
	_reflections.show()
	sign_lit.emit()


func _set_doors_opening(share: float) -> void:
	var steps: int = floori(float(DOORS_OPEN) / DOOR_STEP)
	_door_open = mini(DOORS_OPEN, floori(share * steps) * DOOR_STEP)
	_doors.queue_redraw()


func _set_flood(share: float) -> void:
	_flood.color.a = floorf(share * FLOOD_STEPS) / FLOOD_STEPS


## The two leaves, `_door_open` art px apart (each slides into the wall beside it, so only its
## part inside the doorway shows), and the threshold over their feet.
func _draw_doors() -> void:
	_doors.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE * ArtStyle.ART_SCALE)
	var leaf: Texture2D = StorefrontArt.layer("leaf")
	var leaf_size: Vector2i = StorefrontArt.LEAF_SIZE
	var shown: int = leaf_size.x - _door_open
	if shown > 0:
		_doors.draw_texture_rect_region(
			leaf, Rect2(0, 0, shown, leaf_size.y), Rect2(_door_open, 0, shown, leaf_size.y)
		)
		_doors.draw_texture_rect_region(
			leaf,
			Rect2(leaf_size.x + _door_open, 0, shown, leaf_size.y),
			Rect2(0, 0, shown, leaf_size.y)
		)
	var doorway: Vector2i = StorefrontArt.DOORS_RECT.size
	_doors.draw_rect(Rect2(-2, doorway.y - 2, doorway.x + 4, 2), Palette.STEEL_DARK)


## The twinkling stars' crosses and the shooting star with its fading tail.
func _draw_sky() -> void:
	_sky.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE * ArtStyle.ART_SCALE)
	for star: Vector2i in twinkles():
		_sky.draw_rect(Rect2(star, Vector2.ONE), Palette.PAPER)
		for arm: Vector2i in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
			_sky.draw_rect(Rect2(star + arm, Vector2.ONE), Palette.TEAL_LIGHT)
	var head: Vector2i = shooting_star()
	if head.x < 0:
		return
	var run: int = absi(SHOOTING_STEP.x)
	for i: int in range(SHOOTING_TAIL, -1, -1):
		var colour: Color = Palette.PAPER
		if i > 0:
			colour = Palette.TEAL_LIGHT if i * 2 <= SHOOTING_TAIL else Palette.TEAL_SHADE
		var back: Vector2i = Vector2i(-signi(SHOOTING_STEP.x) * i, -floori(float(i) / run))
		_sky.draw_rect(Rect2(head + back, Vector2.ONE), colour)


## The receipt scrap on its way along the sidewalk, from the window's left edge to its right.
func _draw_scrap() -> void:
	var since: float = _clock - _scrap_at
	if not is_lit() or still or since < 0.0 or since >= SCRAP_TIME:
		return
	var share: float = since / SCRAP_TIME
	var from: float = -_extend.x - 10.0
	var to: float = StorefrontArt.STAGE.x + _extend.z + 10.0
	var x: int = roundi(lerpf(from, to, share))
	var y: int = SCRAP_Y - absi(roundi(sin(share * SCRAP_WAVES) * SCRAP_BOUNCE))
	_scrap.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE * ArtStyle.ART_SCALE)
	_scrap.draw_rect(Rect2(Vector2i(x, y), SCRAP_SIZE), Palette.CREAM)
	_scrap.draw_rect(Rect2(x, y + SCRAP_SIZE.y - 1, SCRAP_SIZE.x, 1), Palette.CREAM_SHADE)


func _on_stage(rect_art: Rect2i) -> Rect2:
	return Rect2(_stage.position + _canvas(rect_art.position), _canvas(rect_art.size))


static func _canvas(art: Vector2i) -> Vector2:
	return Vector2(art) * ArtStyle.ART_SCALE
