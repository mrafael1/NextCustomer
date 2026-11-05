class_name MachineCabinet
extends Control
## The machine's cabinet, front-on (v0.50; the steel-and-brass relook in v0.98, mock-up
## docs/art/mockups/machine_relook.html V2; V3's full-screen prize counter in v0.98, mock-ups
## machine_relook_v2.html and _v3.html), drawn first under every other part: its plinth and
## shadow, the dark teal body with a teal band under the marquee, three steel pillars in the gauge
## housing's language (an ink outline, lit on the left and shaded on the right, a riveted cap at
## the top and the foot, a rivet every PILLAR_RIVET_STEP down the middle): the outer two at both
## edges and the middle one between the machine's module (left) and the prize bay (PrizeBay,
## right), with a brass crest; the stock window's riveted steel frame, the rubber key plate the
## keys stand on (charcoal once PREMIUM) and the kick panel, dithered at its top, with the bonus
## dock under the module and vents under the bay. Once a PREMIUM visit turns PREMIUM (MachineLook)
## the brass runs down the pillars (MachineLook.trim: their steel turns brass from the top, a spark
## at its tip), their caps, rivets and the crest turn gold once it has run, then two sparks glide
## down the outer ones; with the night face the beacons on the outer caps blink (held lit under
## reduced motion).
##
## The bonus ticket's dock (#77 machine v2, Q2 = 2) is on the kick panel (DOCK_RECT: a dashed
## border, the ticket icon and "BONUS TICKET HERE" in hard pixel lettering): it shows while a bonus
## ticket is on its way, through a TICKET visit with a stub (its border turns mustard as the
## receipt reaches the slot, and its caption goes MachineTuning's dock_label_ms later) and a BONUS
## visit until its ticket reaches the slot (mustard, no caption).

const SIZE := Vector2(1040, 584)
## The side pillars (PILLAR_WIDTH wide at both edges, the full height) and their rivets; V3's
## middle pillar (v0.98) between the machine's module and the prize bay, with its brass crest.
const PILLAR_WIDTH := 24.0
const MIDDLE_PILLAR_RECT := Rect2(488, 0, 20, 584)
const CREST_RECT := Rect2(484, 164, 28, 40)
const PILLAR_RIVET_TOP := 48.0
const PILLAR_RIVET_STEP := 80.0
const CAP_HEIGHT := 10.0
## The beacons on the outer pillars' caps (PREMIUM: lit with the night face, blinking at
## BEACON_RATE a second; held lit under reduced motion), with a mustard light halo.
const BEACON_RECTS: Array[Rect2] = [Rect2(4, -18, 16, 12), Rect2(1020, -18, 16, 12)]
const BEACON_RATE := 3.0
const BEACON_HALO := Vector2(28, 24)
const BEACON_HALO_ALPHA := 0.3
## The teal band under the marquee (TEAL, its foot TEAL_LIGHT).
const BAND_HEIGHT := 8.0
## The stock window's steel frame (StockWindow's glass inside it) and the key plate the keys
## stand on.
const WINDOW_FRAME_RECT := Rect2(24, 84, 460, 216)
const PLATE_RECT := Rect2(20, 306, 468, 100)
const PLINTH_RECT := Rect2(-12, 584, 1064, 14)
const SHADOW_RECT := Rect2(-24, 596, 1088, 6)
const SHADOW_ALPHA := 0.35
## The kick panel: its top line and its dithered shade (KICK_DITHER px), and its vents under the
## prize bay (VENTS slots across VENT_SPAN from VENT_AT, two rows VENT_ROW apart).
const KICK_TOP := 528.0
const KICK_DITHER := 8.0
const VENT_AT := Vector2(528, 550)
const VENT_SIZE := Vector2(24, 4)
const VENT_SPAN := 472.0
const VENT_ROW := 8.0
const VENTS := 9
## The bonus ticket's dock on the kick panel under the stock window, on its dark box.
const DOCK_RECT := Rect2(136, 542, 232, 32)
const DOCK_BOX_RECT := Rect2(132, 540, 240, 36)
const DOCK_TEXT := "BONUS TICKET HERE"
const DOCK_ICON := preload("res://art/icons/bonus_ticket.png")
## The dock's dashed border: DOCK_DASH long, DOCK_DASH apart.
const DOCK_DASH := 4.0
const BORDER := 2.0
## The trim's two sparks once it has run (one each outer pillar), gliding down in this many
## seconds.
const SPARK_PERIOD := 2.0

## The machine this part belongs to (setup(), build spec 4.2).
var view: RewardMachineView
var _trim: float = 0.0
var _night_plate: bool = false
var _beacons: bool = false
var _spark: float = 0.0
var _dock_on: bool = false
var _dock_lit: bool = false
var _dock_label: MachineLine
var _dock_icon: TextureRect


func _init() -> void:
	name = "MachineCabinet"
	size = SIZE
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var p: float = MachineArt.PIXEL
	_dock_icon = UiKit.sprite(DOCK_ICON)
	_dock_icon.name = "DockIcon"
	_dock_icon.size = DOCK_ICON.get_size() * p
	_dock_label = MachineLine.make("DockLabel", DOCK_TEXT, Palette.TEAL_LIGHT)
	var pair: float = _dock_icon.size.x + 3.0 * p + _dock_label.width()
	var left: float = MachineArt.snap(DOCK_RECT.get_center().x - pair / 2.0)
	var middle: float = DOCK_RECT.get_center().y
	_dock_icon.position = Vector2(left, MachineArt.snap(middle - _dock_icon.size.y / 2.0))
	var text_left: float = left + _dock_icon.size.x + 3.0 * p
	_dock_label.centre_in(Rect2(text_left, DOCK_RECT.position.y, _dock_label.width(), 32.0))
	_dock_label.visible = false
	_dock_icon.visible = false
	add_child(_dock_icon)
	add_child(_dock_label)


## Hooks this part to the machine: RewardMachineView calls it once, when it builds the part
## (build spec 4.2).
func setup(machine: RewardMachineView) -> void:
	view = machine


## The dock's rect on screen, where the bonus ticket waits.
func dock_global_rect() -> Rect2:
	return get_global_transform() * DOCK_RECT


## Whether the dock shows, whether its border is mustard, whether its caption shows.
func dock_state() -> Array[bool]:
	return [_dock_on, _dock_lit, _dock_label.visible]


## The dock's caption (hard pixel lettering), for layout tests.
func dock_label() -> MachineLine:
	return _dock_label


## How far the brass has run down the pillars (0 .. 1).
func trim_shown() -> float:
	return _trim


## Whether the beacons on the outer pillars are lit now.
func beacons_lit() -> bool:
	return _beacons


## Whether the key plate shows its PREMIUM night face.
func night_plate() -> bool:
	return _night_plate


## The trim, the beacons, the key plate and the dock at time `t` (seconds) of view.plan.
func frame(t: float) -> void:
	var plan: MachinePlan = view.plan if view != null else null
	var dock: bool = false
	var dock_lit: bool = false
	var caption: bool = false
	if plan != null and plan.kind == MachineVisit.Kind.TICKET and plan.stub:
		dock = true
		dock_lit = t >= plan.fly_end
		caption = t < plan.fly_end + MachineTuning.sec(view.tuning.dock_label_ms)
	elif plan != null and plan.kind == MachineVisit.Kind.BONUS and t < plan.fly_end:
		dock = true
		dock_lit = true
	_dock_label.visible = caption
	_dock_icon.visible = caption
	var look: MachineLook = MachineLook.at(plan, t)
	var trim: float = look.trim()
	var night: bool = look.night_plate()
	var beacons: bool = false
	if plan != null and look.night_face():
		beacons = plan.reduced_motion or int(floorf(view.idle_time * BEACON_RATE)) % 2 == 0
	var spark: float = fposmod(view.idle_time, SPARK_PERIOD) / SPARK_PERIOD if view != null else 0.0
	var changed: bool = trim != _trim or dock != _dock_on or dock_lit != _dock_lit
	changed = changed or beacons != _beacons or night != _night_plate
	if changed or (trim >= 1.0 and spark != _spark):
		_trim = trim
		_night_plate = night
		_beacons = beacons
		_spark = spark
		_dock_on = dock
		_dock_lit = dock_lit
		queue_redraw()


func _draw() -> void:
	var p: float = MachineArt.PIXEL
	draw_rect(SHADOW_RECT, Color(Palette.INK, SHADOW_ALPHA))
	draw_rect(PLINTH_RECT, Palette.INK)
	var plinth: Rect2 = PLINTH_RECT.grow(-p)
	draw_rect(Rect2(plinth.position, Vector2(plinth.size.x, 2.0 * p)), Palette.STEEL_PALE)
	var plinth_foot: Rect2 = Rect2(
		plinth.position.x, plinth.position.y + 2.0 * p, plinth.size.x, 3.0 * p
	)
	draw_rect(plinth_foot, Palette.STEEL_DARK)
	var body: Rect2 = Rect2(Vector2.ZERO, SIZE)
	draw_rect(body, Palette.INK)
	draw_rect(body.grow(-p), Palette.TEAL_DARK)
	draw_rect(Rect2(p, p, SIZE.x - 2.0 * p, BAND_HEIGHT), Palette.TEAL)
	draw_rect(Rect2(p, p + BAND_HEIGHT, SIZE.x - 2.0 * p, p), Palette.TEAL_LIGHT)
	_draw_kick()
	for x: float in [0.0, SIZE.x - PILLAR_WIDTH]:
		_draw_pillar(x, PILLAR_WIDTH)
	_draw_pillar(MIDDLE_PILLAR_RECT.position.x, MIDDLE_PILLAR_RECT.size.x)
	_draw_crest()
	_draw_beacons()
	MachineArt.steel_frame(self, WINDOW_FRAME_RECT, 2.0)
	for corner: Vector2 in MachineArt.corners(WINDOW_FRAME_RECT, p):
		MachineArt.rivet(self, corner)
	draw_rect(PLATE_RECT, Palette.INK)
	var plate: Rect2 = PLATE_RECT.grow(-p)
	draw_rect(plate, Palette.CHARCOAL if _night_plate else Palette.RUBBER)
	var plate_top: Color = Palette.RUBBER if _night_plate else Palette.STEEL_SHADE
	draw_rect(Rect2(plate.position, Vector2(plate.size.x, p)), plate_top)


## The kick panel: its top line, a dithered shade into its dark face, the vents under the bay and,
## while the dock shows, its dark box with its dashed border.
func _draw_kick() -> void:
	var p: float = MachineArt.PIXEL
	var inner: float = SIZE.x - 2.0 * PILLAR_WIDTH
	draw_rect(Rect2(p, KICK_TOP, SIZE.x - 2.0 * p, p), Palette.BACKGROUND)
	_dither_rect(Rect2(PILLAR_WIDTH, KICK_TOP + p, inner, KICK_DITHER))
	var face_top: float = KICK_TOP + p + KICK_DITHER
	draw_rect(Rect2(PILLAR_WIDTH, face_top, inner, SIZE.y - p - face_top), Palette.BACKGROUND)
	for row: int in range(2):
		for index: int in range(VENTS):
			var x: float = MachineArt.snap(VENT_AT.x + index * VENT_SPAN / VENTS)
			draw_rect(Rect2(Vector2(x, VENT_AT.y + row * VENT_ROW), VENT_SIZE), Palette.INK)
	if _dock_on:
		draw_rect(DOCK_BOX_RECT, Palette.TEAL_DARK)
		_dashed_rect(DOCK_RECT, Palette.MUSTARD if _dock_lit else Palette.TEAL_LIGHT)


## A pillar at `x`, `w` wide: steel (the brass run down it `_trim` of the way, PREMIUM), its caps
## and its rivets (gold once the brass has run).
func _draw_pillar(x: float, w: float) -> void:
	var p: float = MachineArt.PIXEL
	draw_rect(Rect2(x, 0, w, SIZE.y), Palette.INK)
	_pillar_body(x, w, p, SIZE.y - 2.0 * p, false)
	var gold_height: float = MachineArt.snap((SIZE.y - 2.0 * p) * _trim)
	if gold_height > 0.0:
		_pillar_body(x, w, p, gold_height, true)
	var gold: bool = _trim >= 1.0
	for cap_y: float in [p, SIZE.y - p - CAP_HEIGHT - p]:
		var cap: Rect2 = Rect2(x + p, cap_y, w - 2.0 * p, CAP_HEIGHT)
		draw_rect(cap, Palette.MUSTARD if gold else Palette.STEEL_PALE)
		var lit: Color = Palette.MUSTARD_PALE if gold else Palette.STEEL_HIGHLIGHT
		draw_rect(Rect2(cap.position, Vector2(cap.size.x, p)), lit)
		draw_rect(Rect2(x + p, cap_y + CAP_HEIGHT, w - 2.0 * p, p), Palette.INK)
		MachineArt.rivet(self, Vector2(x + 2.0 * p, cap_y + 2.0 * p), gold)
		MachineArt.rivet(self, Vector2(x + w - 4.0 * p, cap_y + 2.0 * p), gold)
	var y: float = PILLAR_RIVET_TOP
	while y < SIZE.y - PILLAR_RIVET_TOP:
		MachineArt.rivet(self, Vector2(MachineArt.snap(x + w / 2.0 - p), y), gold_height >= y)
		y += PILLAR_RIVET_STEP
	if _trim > 0.0 and _trim < 1.0:
		MachineArt.sparkle(self, Vector2(x + w / 2.0, p + gold_height), 2.0, 1.0)
	elif gold and w >= PILLAR_WIDTH:
		var side: int = 0 if x < SIZE.x / 2.0 else 1
		var phase: float = fposmod(_spark + side * 0.5, 1.0)
		var at: Vector2 = Vector2(x + w / 2.0, 24.0 + phase * (SIZE.y - 48.0))
		MachineArt.sparkle(self, at, 1.0, sin(phase * PI))


## The pillar's body from `top`, `height` px: its face lit on the left and shaded on the right,
## steel or brass.
func _pillar_body(x: float, w: float, top: float, height: float, gold: bool) -> void:
	var p: float = MachineArt.PIXEL
	draw_rect(Rect2(x + p, top, w - 2.0 * p, height), Palette.BRASS if gold else Palette.STEEL)
	draw_rect(Rect2(x + p, top, p, height), Palette.MUSTARD_LIGHT if gold else Palette.STEEL_LIGHT)
	draw_rect(Rect2(x + 2.0 * p, top, p, height), Palette.MUSTARD if gold else Palette.STEEL_PALE)
	var shade: Color = Palette.BRASS_DARK if gold else Palette.STEEL_SHADE
	draw_rect(Rect2(x + w - 3.0 * p, top, p, height), shade)
	var dark: Color = Palette.BRASS_DARKEST if gold else Palette.STEEL_DARK
	draw_rect(Rect2(x + w - 2.0 * p, top, p, height), dark)


## The middle pillar's crest: a brass plate (gold once the trim has run) with an engraved star.
func _draw_crest() -> void:
	var p: float = MachineArt.PIXEL
	draw_rect(CREST_RECT, Palette.INK)
	var plate: Rect2 = CREST_RECT.grow(-p)
	draw_rect(plate, Palette.GOLD if _trim >= 1.0 else Palette.BRASS)
	draw_rect(Rect2(plate.position, Vector2(plate.size.x, p)), Palette.MUSTARD_PALE)
	var middle: Vector2 = plate.get_center()
	var engraved: Color = Palette.BRASS_DARKEST
	draw_rect(Rect2(middle.x - p, middle.y - 4.0 * p, 2.0 * p, 8.0 * p), engraved)
	draw_rect(Rect2(middle.x - 4.0 * p, middle.y - p, 8.0 * p, 2.0 * p), engraved)
	draw_rect(Rect2(middle.x - 2.0 * p, middle.y - 2.0 * p, 4.0 * p, 4.0 * p), engraved)


## The beacons on the outer pillars' caps: brass dark, gold with a halo while lit.
func _draw_beacons() -> void:
	var p: float = MachineArt.PIXEL
	for rect: Rect2 in BEACON_RECTS:
		if _beacons:
			var halo: Rect2 = Rect2(rect.get_center() - BEACON_HALO / 2.0, BEACON_HALO)
			draw_rect(halo, Color(Palette.MUSTARD_LIGHT, BEACON_HALO_ALPHA))
		draw_rect(rect, Palette.INK)
		var lamp: Rect2 = Rect2(rect.position + Vector2(p, p), rect.size - Vector2(2.0 * p, p))
		draw_rect(lamp, Palette.GOLD if _beacons else Palette.BRASS_DARK)
		draw_rect(Rect2(lamp.position + Vector2(p, 0), Vector2(2.0 * p, p)), Palette.MUSTARD_PALE)


## A dither of BACKGROUND over the panel in `rect`: every other art px, the rows alternating.
func _dither_rect(rect: Rect2) -> void:
	var p: float = MachineArt.PIXEL
	var row: int = 0
	var y: float = rect.position.y
	while y < rect.end.y:
		var x: float = rect.position.x + (row % 2) * p
		while x < rect.end.x:
			draw_rect(Rect2(x, y, p, p), Palette.BACKGROUND)
			x += 2.0 * p
		y += p
		row += 1


## A dashed 2 px border inside `rect`, in `colour`.
func _dashed_rect(rect: Rect2, colour: Color) -> void:
	var x: float = rect.position.x
	while x < rect.end.x:
		var w: float = minf(DOCK_DASH, rect.end.x - x)
		draw_rect(Rect2(x, rect.position.y, w, BORDER), colour)
		draw_rect(Rect2(x, rect.end.y - BORDER, w, BORDER), colour)
		x += DOCK_DASH * 2.0
	var y: float = rect.position.y
	while y < rect.end.y:
		var h: float = minf(DOCK_DASH, rect.end.y - y)
		draw_rect(Rect2(rect.position.x, y, BORDER, h), colour)
		draw_rect(Rect2(rect.end.x - BORDER, y, BORDER, h), colour)
		y += DOCK_DASH * 2.0
