extends Control
## The boot loader, the game's main scene (2026-11-13, mock-up loading_screen.html, look A
## "shutters down, receipt printing"). The engine's boot splash (art/boot/boot_frame.png on the
## title's sky, #172c2b) is this scene's first frame: the store at closing time, every opening
## shuttered, a receipt hanging from the door shutter's night slot. The title loads on a thread
## (ResourceLoader.load_threaded_request) while the receipt prints a line per stage (LIGHTS OK,
## SHELVES OK ...) with a live STOCK percent; once it is loaded the receipt prints TOTAL 100%
## and THANK YOU! with the printer's sound, then the shutters roll up, door first, carrying the
## receipt away, over the title's own first frame (the title, made and held still under them).
## The title then becomes the current scene as it is: nothing is made twice, so there is no
## flash and no jump in colour. Reduced motion (the profile's, as the title read it) cuts
## straight to the title. On the web build it calls window.ncBootDone() (export/web_shell.html)
## once the title is ready, so the shell's overlay, which holds the finished receipt while the
## engine starts, gives way to this scene.
##
## It must stay tiny and reference no class_name type: one would compile the whole game before
## this scene's first frame, behind the boot splash. So its colours are plain constants (the
## Palette's), its art its own (art/boot/title_first_frame.png, the title's first frame without
## its corner icons, 640x360 art px drawn at 2x), and it talks to the title by method name only.
## Both PNGs are captured from the game (tools/boot_frame.sh): the title's first frame, then
## this scene at 0%.

## The title is made and held still under the shutters (after its _ready).
signal title_made(title: Node)
## The title is the scene now (or, without changes_scene, this scene's child, running).
signal handed_off(title: Node)

enum Stage { LOADING, DONE, ROLLING, HANDED }

const TITLE := "res://ui/title_screen.tscn"
const BASE := preload("res://art/boot/title_first_frame.png")
const DISPLAY_FONT := preload("res://fonts/PixelifySans-Variable.ttf")
const NUMBER_FONT := preload("res://fonts/AtkinsonHyperlegibleNext-Variable-MSDF.ttf")
const PRINT_SOUND := preload("res://audio/sfx/print.wav")
const SFX_BUS := &"SFX"
const STAGE_SIZE := Vector2(1280, 720)
const ART_SCALE := 2.0
## Palette's TEAL_BLACK (the title's sky), INK, PAPER, CREAM_SHADE, GREY, GREEN_DARK, GOOD,
## TOMATO_DARK, BRASS, BRASS_DARK, STEEL, STEEL_SHADE, STEEL_DARK, STEEL_DARKEST, RUBBER_DARK
## and CHARCOAL; NIGHT darkens the doors' light line while their shutter is down.
const SKY := Color("172c2b")
const INK := Color("2b2420")
const PAPER := Color("fbf7ee")
const CREAM_SHADE := Color("ddcba5")
const MUTED := Color("8a8172")
const GREEN_DARK := Color("3d7a45")
const GOOD := Color("5fae5a")
const TOMATO_DARK := Color("a83a3c")
const BRASS := Color("c8932b")
const BRASS_DARK := Color("8a5d1a")
const STEEL := Color("8d8a83")
const STEEL_SHADE := Color("6f6b63")
const STEEL_DARK := Color("57534c")
const STEEL_DARKEST := Color("45423d")
const RUBBER_DARK := Color("2c2926")
const CHARCOAL := Color("24221f")
const NIGHT := Color("2a3542")
## The shuttered openings on the stage (canvas px): the left window, the doors, the till window
## and the REWARDS bay; DOORS is the doors' index. Each rolls up ROLL_TIME seconds from its
## ROLL_START after the hold (the doors first).
const OPENINGS: Array[Rect2] = [
	Rect2(402, 258, 126, 326),
	Rect2(532, 262, 216, 322),
	Rect2(752, 258, 248, 326),
	Rect2(1010, 266, 254, 316),
]
const DOORS := 1
const ROLL_START: Array[float] = [0.224, 0.0, 0.352, 0.48]
const ROLL_TIME := 0.88
## The doors' light on the sidewalk, switched off while their shutter is down (the sidewalk
## SPILL_FROM px to the left laid over it, in 3 steps), and their light line (darkened).
const SPILL := Rect2(508, 590, 268, 78)
const SPILL_FROM := -320.0
const THRESHOLD := Rect2(532, 584, 216, 8)
## The shutters' slats (SLAT px), every SLOT_ROW-th row of the bottom-up count punched.
const SLAT := 12.0
const SLOT_ROW := 4
## The receipt: RECEIPT_X, RECEIPT_W wide, its lines LINE_H apart, coming out of the night slot
## SLOT_UP px above the door shutter's foot. A stage's line prints as STOCK passes its share
## (in LINE_AT), over LINE_GROW of the progress.
const RECEIPT_X := 576.0
const RECEIPT_W := 128.0
const LINE_H := 18.0
const SLOT_UP := 58.0
const LINES: Array[String] = [
	"LIGHTS", "SHELVES", "MILK", "BREAD", "BANANAS", "COUPONS", "TOYS", "TILL"
]
const LINE_AT: Array[float] = [0.06, 0.18, 0.30, 0.42, 0.54, 0.66, 0.78, 0.90]
const LINE_GROW := 0.04
const TEXT_SIZE := 13
const BIG_TEXT_SIZE := 15
const WORD_WEIGHT := 700
const NUMBER_WEIGHT := 750
## The printed share follows the load's at most PRINT_RATE a second (PRINT_RATE_DONE once the
## title is loaded); the finished receipt holds DONE_HOLD seconds before the shutters roll; the
## slot's light blinks LED_HZ times a second while it prints.
const PRINT_RATE := 0.8
const PRINT_RATE_DONE := 2.5
const DONE_HOLD := 0.3
const LED_HZ := 3.0

## Off in tests: the title stays this scene's child instead of replacing it.
var changes_scene: bool = true
## Off in captures: nothing loads, show_state() sets what is drawn.
var auto_load: bool = true
## The web build (the shell's overlay waits for ncBootDone).
var on_web: bool = OS.has_feature("web")

var _stage: Stage = Stage.LOADING
## The share printed (0 to 1) and the load's.
var _printed: float = 0.0
var _loaded_share: float = 0.0
var _loaded: bool = false
var _clock: float = 0.0
## Seconds the finished receipt has held, and since the shutters started rolling.
var _held: float = 0.0
var _rolled: float = 0.0
var _title: Node
var _progress: Array = []
var _words: FontVariation
var _numbers: FontVariation
## The layers over the title: the doors' spill switched off, their light line darkened (a
## multiply), and the shutters with the receipt.
var _spill: Control
var _dim: Control
var _front: Control
var _printer: AudioStreamPlayer


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_words = _font(DISPLAY_FONT, WORD_WEIGHT)
	_numbers = _font(NUMBER_FONT, NUMBER_WEIGHT)
	_spill = _layer(_draw_spill)
	_dim = _layer(_draw_dim)
	var multiply: CanvasItemMaterial = CanvasItemMaterial.new()
	multiply.blend_mode = CanvasItemMaterial.BLEND_MODE_MUL
	_dim.material = multiply
	_front = _layer(_draw_front)
	_printer = AudioStreamPlayer.new()
	_printer.stream = PRINT_SOUND
	if AudioServer.get_bus_index(SFX_BUS) >= 0:
		_printer.bus = SFX_BUS
	add_child(_printer)
	resized.connect(_place_layers)
	_place_layers()
	if on_web:
		# The shell's overlay already showed the download; the engine's part starts printed.
		_printed = 1.0
	if auto_load:
		ResourceLoader.load_threaded_request(TITLE, "", true)


## Draws the loader at `share` printed (1: TOTAL and THANK YOU!) and `rolled` seconds into the
## shutters' roll, for captures and tests (with auto_load off).
func show_state(share: float, rolled: float = 0.0) -> void:
	_printed = clampf(share, 0.0, 1.0)
	_loaded = _printed >= 1.0
	_rolled = rolled
	_stage = Stage.ROLLING if rolled > 0.0 else (Stage.DONE if _loaded else Stage.LOADING)
	_redraw()


## The share of the receipt printed (0 to 1).
func printed() -> float:
	return _printed


## The title, once made (null before).
func title() -> Node:
	return _title


## Seconds the shutters take to roll away, the last one included.
func roll_time() -> float:
	var last: float = 0.0
	for start: float in ROLL_START:
		last = maxf(last, start)
	return last + ROLL_TIME


## The shutters have rolled away and the title runs.
func is_handed_off() -> bool:
	return _stage == Stage.HANDED


## How far the shutter of opening `index` (in OPENINGS) is down: 1 shut, 0 rolled up.
func shutter_closed(index: int) -> float:
	if _stage != Stage.ROLLING and _stage != Stage.HANDED:
		return 1.0
	var share: float = clampf((_rolled - ROLL_START[index]) / ROLL_TIME, 0.0, 1.0)
	return 1.0 - _ease(share)


## The receipt's lines now, top down: [words, number, kind, grown share (0 to 1)], kind one of
## "big_centre" (the header), "mute" (centred, grey), "dash" (a rule), "ok" (a stage, OK on its
## right), "live" (STOCK and its percent), "big" (TOTAL) and "centre" (THANK YOU!).
func receipt_lines() -> Array[Array]:
	var lines: Array[Array] = [
		["NEXT CUSTOMER", "", "big_centre", 1.0],
		["STORE OPENING", "", "mute", 1.0],
		["", "", "dash", 1.0],
	]
	for i: int in LINES.size():
		lines.append([LINES[i], "", "ok", _grown(LINE_AT[i])])
	lines.append(["", "", "dash", clampf((_printed - 0.95) / 0.03, 0.0, 1.0)])
	if _loaded and _printed >= 1.0:
		lines.append(["TOTAL", "100%", "big", 1.0])
		lines.append(["THANK YOU!", "", "centre", 1.0])
	else:
		lines.append(["STOCK", "%d%%" % floori(_printed * 100.0), "live", 1.0])
	return lines


func _process(delta: float) -> void:
	_clock += delta
	match _stage:
		Stage.LOADING:
			if auto_load:
				_follow_load(delta)
		Stage.DONE:
			_held += delta
			if _held >= DONE_HOLD:
				_stage = Stage.ROLLING
		Stage.ROLLING:
			_rolled += delta
			if _rolled >= roll_time():
				_hand_off()
	_redraw()


## Prints up to the load's share; once the title is loaded and the receipt printed, makes it.
func _follow_load(delta: float) -> void:
	if not _loaded:
		var status: ResourceLoader.ThreadLoadStatus = ResourceLoader.load_threaded_get_status(
			TITLE, _progress
		)
		if not _progress.is_empty():
			_loaded_share = maxf(_loaded_share, float(_progress[0]))
		if status == ResourceLoader.THREAD_LOAD_LOADED:
			_loaded = true
			_loaded_share = 1.0
		elif (
			status == ResourceLoader.THREAD_LOAD_FAILED
			or status == ResourceLoader.THREAD_LOAD_INVALID_RESOURCE
		):
			# Nothing to hand over to: the plain change reports why.
			set_process(false)
			get_tree().change_scene_to_file(TITLE)
			return
	var rate: float = PRINT_RATE_DONE if _loaded else PRINT_RATE
	_printed = maxf(_printed, move_toward(_printed, _loaded_share, delta * rate))
	if _loaded and _printed >= 1.0:
		_make_title()


## The title, made from the loaded scene and held still under the shutters: its first frame.
## TOTAL and THANK YOU! print (the printer's sound now obeys the profile, which the title has
## applied); reduced motion hands over at once.
func _make_title() -> void:
	var packed: PackedScene = ResourceLoader.load_threaded_get(TITLE) as PackedScene
	_title = packed.instantiate()
	_title.process_mode = Node.PROCESS_MODE_DISABLED
	add_child(_title)
	move_child(_title, 0)
	title_made.emit(_title)
	_stage = Stage.DONE
	_held = 0.0
	_rolled = 0.0
	if on_web:
		_boot_done.call_deferred()
	var still: bool = _title.has_method("reduced_motion") and bool(_title.call("reduced_motion"))
	if still:
		_hand_off()
		return
	_printer.play()


## The shell's overlay gives way (web): the finished receipt is on the canvas by now.
func _boot_done() -> void:
	JavaScriptBridge.eval("window.ncBootDone && window.ncBootDone()")


## The title runs: as the current scene (this scene leaves), or here in tests.
func _hand_off() -> void:
	_stage = Stage.HANDED
	set_process(false)
	for layer: Control in [_spill, _dim, _front]:
		layer.hide()
	if _title == null:
		return
	if changes_scene:
		var tree: SceneTree = get_tree()
		remove_child(_title)
		tree.root.add_child(_title)
		tree.current_scene = _title
		_title.process_mode = Node.PROCESS_MODE_INHERIT
		handed_off.emit(_title)
		queue_free()
		return
	_title.process_mode = Node.PROCESS_MODE_INHERIT
	handed_off.emit(_title)


func _grown(at: float) -> float:
	return clampf((_printed - at) / LINE_GROW, 0.0, 1.0)


static func _ease(share: float) -> float:
	if share < 0.5:
		return 2.0 * share * share
	return 1.0 - pow(-2.0 * share + 2.0, 2.0) / 2.0


static func _q2(value: float) -> float:
	return roundf(value / 2.0) * 2.0


static func _font(base: Font, weight: int) -> FontVariation:
	var font: FontVariation = FontVariation.new()
	font.base_font = base
	var tag: int = TextServerManager.get_primary_interface().name_to_tag("wght")
	font.variation_opentype = {tag: weight}
	return font


func _layer(drawn: Callable) -> Control:
	var layer: Control = Control.new()
	layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	layer.size = STAGE_SIZE
	layer.draw.connect(drawn)
	add_child(layer)
	return layer


## The stage centred in the window, as the title's Storefront places it.
func _stage_at() -> Vector2:
	return ((size - STAGE_SIZE) / 2.0).floor()


func _place_layers() -> void:
	for layer: Control in [_spill, _dim, _front]:
		layer.position = _stage_at()
	queue_redraw()


func _redraw() -> void:
	queue_redraw()
	_spill.queue_redraw()
	_dim.queue_redraw()
	_front.queue_redraw()


## The sky round the stage and the title's first frame on it (the title covers both once made).
func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), SKY)
	draw_texture_rect(BASE, Rect2(_stage_at(), STAGE_SIZE), false)


func _draw_spill() -> void:
	var share: float = roundf(shutter_closed(DOORS) * 3.0) / 3.0
	if share <= 0.0:
		return
	var source := Rect2(
		(SPILL.position + Vector2(SPILL_FROM, 0.0)) / ART_SCALE, SPILL.size / ART_SCALE
	)
	_spill.draw_texture_rect_region(BASE, SPILL, source, Color(1.0, 1.0, 1.0, share))


func _draw_dim() -> void:
	var share: float = roundf(shutter_closed(DOORS) * 4.0) / 4.0
	if share > 0.0:
		_dim.draw_rect(THRESHOLD, Color.WHITE.lerp(NIGHT, share))


func _draw_front() -> void:
	for i: int in OPENINGS.size():
		if i != DOORS:
			_draw_shutter(OPENINGS[i], shutter_closed(i), false)
	var doors: Rect2 = OPENINGS[DOORS]
	var closed: float = shutter_closed(DOORS)
	_draw_shutter(doors, closed, true)
	var slot_y: float = doors.position.y + _q2(doors.size.y * closed) - SLOT_UP
	if slot_y > doors.position.y:
		_draw_receipt(slot_y, doors.position.y)


## A shutter `closed` of the way down `opening`: slats riding with its foot, the guide rails,
## the bottom rail and its brass handle, and on the door shutter the night slot and its light.
func _draw_shutter(opening: Rect2, closed: float, slot: bool) -> void:
	var height: float = _q2(opening.size.y * closed)
	if height <= 0.0:
		return
	var clip := Rect2(opening.position, Vector2(opening.size.x, height))
	var x: float = opening.position.x
	var width: float = opening.size.x
	var bottom: float = opening.position.y + height
	var y: float = bottom - SLAT
	while y > opening.position.y - SLAT:
		_rect(clip, Rect2(x, y, width, SLAT), STEEL_DARK)
		_rect(clip, Rect2(x, y, width, 2), STEEL_SHADE)
		_rect(clip, Rect2(x, y + 8, width, 2), STEEL_DARKEST)
		_rect(clip, Rect2(x, y + 10, width, 2), RUBBER_DARK)
		if roundi((bottom - y) / SLAT) % SLOT_ROW == 2:
			var hole: float = x + 10
			while hole < x + width - 14:
				_rect(clip, Rect2(hole, y + 4, 8, 2), CHARCOAL)
				hole += 18
		y -= SLAT
	_rect(clip, Rect2(x, opening.position.y, 4, height), STEEL_DARKEST)
	_rect(clip, Rect2(x + width - 4, opening.position.y, 4, height), STEEL_DARKEST)
	_rect(clip, Rect2(x, bottom - 10, width, 10), STEEL_DARKEST)
	_rect(clip, Rect2(x, bottom - 10, width, 2), STEEL)
	var handle: float = _q2(x + width / 2.0 - 10)
	_rect(clip, Rect2(handle, bottom - 8, 20, 4), BRASS)
	_rect(clip, Rect2(handle, bottom - 4, 20, 2), BRASS_DARK)
	if slot:
		var slot_y: float = bottom - SLOT_UP
		_rect(clip, Rect2(568, slot_y, 144, 16), BRASS_DARK)
		_rect(clip, Rect2(570, slot_y + 2, 140, 12), BRASS)
		_rect(clip, Rect2(576, slot_y + 6, 128, 4), CHARCOAL)
		_rect(clip, Rect2(700, slot_y + 2, 6, 4), GOOD if _led_on() else GREEN_DARK)


## The slot's light: blinking while the receipt prints, steady once it is done.
func _led_on() -> bool:
	if _stage != Stage.LOADING:
		return true
	return posmod(floori(_clock * LED_HZ * 2.0), 2) == 0


## The receipt out of the slot at `slot_y`, its lines bottom up, clipped at the doors' top.
func _draw_receipt(slot_y: float, clip_top: float) -> void:
	var lines: Array[Array] = receipt_lines()
	var height: float = 10.0
	for line: Array in lines:
		height += LINE_H * float(line[3])
	height = _q2(height)
	var top: float = slot_y - height
	var clip := Rect2(RECEIPT_X - 4, clip_top, RECEIPT_W + 8, slot_y - clip_top)
	_rect(clip, Rect2(RECEIPT_X, top, RECEIPT_W, height), PAPER)
	_rect(clip, Rect2(RECEIPT_X + RECEIPT_W, top + 2, 2, height - 2), CREAM_SHADE)
	var tooth: float = 0.0
	while tooth < RECEIPT_W:
		_rect(clip, Rect2(RECEIPT_X + tooth + 2, top - 2, 4, 2), PAPER)
		tooth += 8
	var y: float = top + 8
	for line: Array in lines:
		var grown: float = float(line[3])
		if grown >= 1.0 and y >= clip_top:
			_draw_line(line, y + LINE_H - 4, clip)
		y += LINE_H * grown


## One receipt line on `baseline`: a dashed rule, or its words (Pixelify) and number (the number
## font), a stage's OK in green.
func _draw_line(line: Array, baseline: float, clip: Rect2) -> void:
	var kind: String = line[2]
	if kind == "dash":
		var dash: float = 6.0
		while dash < RECEIPT_W - 6:
			_rect(clip, Rect2(RECEIPT_X + dash, baseline - 6, 4, 2), MUTED)
			dash += 8
		return
	var big: bool = kind.begins_with("big") or kind == "live"
	var text_size: int = BIG_TEXT_SIZE if big else TEXT_SIZE
	var colour: Color = MUTED if kind == "mute" else INK
	var inner: float = RECEIPT_W - 16
	if kind.ends_with("centre") or kind == "mute":
		_text(
			_words,
			line[0],
			RECEIPT_X,
			baseline,
			RECEIPT_W,
			HORIZONTAL_ALIGNMENT_CENTER,
			text_size,
			colour
		)
	else:
		_text(
			_words,
			line[0],
			RECEIPT_X + 8,
			baseline,
			inner,
			HORIZONTAL_ALIGNMENT_LEFT,
			text_size,
			colour
		)
	if kind == "ok":
		_text(
			_words,
			"OK",
			RECEIPT_X + 8,
			baseline,
			inner,
			HORIZONTAL_ALIGNMENT_RIGHT,
			TEXT_SIZE,
			GREEN_DARK
		)
	if line[1] != "":
		var value_colour: Color = TOMATO_DARK if kind == "live" else INK
		_text(
			_numbers,
			line[1],
			RECEIPT_X + 8,
			baseline,
			inner,
			HORIZONTAL_ALIGNMENT_RIGHT,
			text_size,
			value_colour
		)


func _text(
	font: Font,
	text: String,
	x: float,
	baseline: float,
	width: float,
	align: HorizontalAlignment,
	text_size: int,
	colour: Color
) -> void:
	_front.draw_string(font, Vector2(x, baseline), text, align, width, text_size, colour)


## Fills the part of `rect` inside `clip` on the front layer.
func _rect(clip: Rect2, rect: Rect2, colour: Color) -> void:
	var inside: Rect2 = rect.intersection(clip)
	if inside.has_area():
		_front.draw_rect(inside, colour)
