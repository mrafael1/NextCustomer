class_name ToyMachineView
extends Control
## One TOY MACHINE (#121, mock-up toy_machines_121_v2.html, the title's direction C+; full build
## plan 7.1): the aisle's own cabinet (ToyCabinet, data/toy_cabinets/: a fridge, a jar, a washer,
## a market stall, an oven or a vending cabinet) on the shared coin base, 144x280 (72x140 art at
## 2x), with its figurine on a plinth above a shelf-label sign and a floor plate under it. The
## window shows one capsule per item left (as many as the cabinet has slots), the price LED on
## the base a coin and the price.
##
## Its state (CapsuleCounter.State) always shows by more than colour, in one of the cabinet's art
## tones (ToyCabinet.Tone: no haze): OK is lit and takes clicks (a pointing hand; the hovered one
## lights its sign, rises LIFT px with its figurine, whose hop repeats, and marks its floor plate
## with the price-gun tick; the screen's arrow keys pick a machine to the same look); BROKE (out
## of coins) is dim with the slot's lid shut and a padlock on the LED; EMPTY (collected) is dim
## with a tick tag over the slot (none once the whole collection is complete), keeps its
## figurine in colour as a trophy (unless the coins are out) and its floor plate reads
## COLLECTED in a green stripe; OFF (the profile can't be saved) is grey with the OUT OF ORDER
## tape over its window and the slot's lid shut. Only OK takes clicks. The sign and the floor
## plate never move but the hovered floor plate, which steps right like a lit menu plate. The
## screen draws the lamps.

signal picked(aisle: AisleDefinition)
## The pointer entered (true) or left (false) the machine, whatever its state (the screen shows
## the lineup and lights the lamp).
signal hover_changed(machine: ToyMachineView, inside: bool)

const SIZE := Vector2(144, 280)
## The title's machine keeps the old capsules (BareToyMachine, RewardsMenu).
const CAPSULE_PATH := "res://art/scenery/toy_capsule_%s.png"
const CAPSULE_ART := 13
## The base for a cabinet with no art of its own, by ToyCabinet.Tone (lit, dim, off).
const BASE_FALLBACK := preload("res://art/toys/toy_base.png")
const BASE_FALLBACKS: Array[Texture2D] = [
	BASE_FALLBACK,
	preload("res://art/toys/toy_base_dim.png"),
	preload("res://art/toys/toy_base_off.png"),
]
const COIN := preload("res://art/icons/coin.png")
const PADLOCK := preload("res://art/icons/padlock_dim.png")
const LID := preload("res://art/toys/toy_slot_lid.png")
const TAG := preload("res://art/toys/toy_tag.png")
## The art's pieces, in machine art px (0,0 the machine's top left): the cabinet top (and the
## front over its capsules) and the base under it.
const CABINET_RECT := Rect2i(0, 0, 72, 76)
const BASE_RECT := Rect2i(0, 76, 72, 64)
## The slot's lid (out of coins) and the collected tick tag.
const LID_AT := Vector2i(17, 88)
const TAG_AT := Vector2i(14, 81)
## The price LED's coin or padlock and its number's cap top.
const COIN_AT := Vector2i(14, 109)
const PADLOCK_AT := Vector2i(15, 110)
const PRICE_NUMBER_AT := Vector2i(28, 111)
## The OUT OF ORDER tape: PAPER_LEFT art px in, its top TAPE_RISE rows over the window's middle
## (a window-less cabinet uses FALLBACK_WINDOW, on the base: with no cabinet art the tape crosses
## the base, never the empty air above it).
const PAPER_LEFT := 2
const TAPE_RISE := 7
const FALLBACK_WINDOW := Rect2i(10, 80, 52, 40)
## The plinth (PLINTH_SIZE) and the topper (48x48) over the sign: the topper's foot on the
## plinth, so its top is TOPPER_TOP rows up plus the sprite's empty bottom rows.
const PLINTH_AT := Vector2i(18, -6)
const PLINTH_SIZE := Vector2i(36, 6)
const TOPPER_LEFT := 12
const TOPPER_TOP := -54
const TOPPER_ART := 48
## The sign: a 76x15 shelf label from SIGN_AT, its name centred on SIGN_TEXT_X (machine art px),
## its cap top SIGN_TEXT_TOP rows down.
const SIGN_AT := Vector2i(-2, 0)
const SIGN_SIZE := Vector2i(76, 15)
const SIGN_TEXT_X := 39
const SIGN_TEXT_TOP := 4
## The floor plate: 74x14 from FLOOR_AT, its count centred on FLOOR_TEXT_X; COLLECTED is centred
## right of the green stripe (COLLECTED_LEFT, COLLECTED_ROOM wide).
const FLOOR_AT := Vector2i(-1, 144)
const FLOOR_SIZE := Vector2i(74, 14)
const FLOOR_TEXT_X := 39
const FLOOR_TEXT_TOP := 4
const COLLECTED_LEFT := 10
const COLLECTED_ROOM := 63
const COLLECTED_STRIPE := 8
## The contact shadow on the floor under the foot.
const SHADOW_RECT := Rect2i(12, 139, 48, 2)
## The clickable area: the figurine, the sign, the machine and the floor plate (art px).
const HIT_RECT := Rect2i(0, -56, 72, 218)
## How far the hovered machine and its figurine rise, and its floor plate steps right (canvas px).
const LIFT := 4.0
const FLOOR_STEP := 4.0
## The hot machine's figurine hops HOP px more on one HOP_FRAME of every HOP_CYCLE (the
## mock-up's; none under reduced motion).
const HOP := 4.0
const HOP_FRAME := 0.16
const HOP_CYCLE := 4
const LEFT_TEXT := "%d OF %d LEFT"
const COLLECTED_TEXT := "COLLECTED"
const PRICE_TEXT := "%d COIN"
const PRICE_TEXT_PLURAL := "%d COINS"
## The machine's name for screen readers.
const ACCESSIBLE_TEXT := "%s, %d OF %d LEFT"

static var _topper_pads: Dictionary[Texture2D, int] = {}

## Whether the player asked for reduced motion (no hop); unset: motion.
var reduced_motion: Callable = Callable()
var _aisle: AisleDefinition
var _cabinet: ToyCabinet
var _state: CapsuleCounter.State = CapsuleCounter.State.OK
var _tone: ToyCabinet.Tone = ToyCabinet.Tone.LIT
var _hovered: bool = false
## Picked with the arrow keys (the screen): hot like the hovered one.
var _selected: bool = false
var _hop_time: float = 0.0
## The topper's resting top (canvas px), its hop added on top.
var _topper_top: float = 0.0
var _left: int = 0
var _total: int = 0
## Everything that rises on hover: the art, its overlays, the plinth and the topper.
var _lift: Control
var _cabinet_art: TextureRect
var _base: TextureRect
var _capsules: Control
var _front: TextureRect
var _lid: TextureRect
var _tag: TextureRect
var _tape: TextureRect
var _price: Control
var _coin: TextureRect
var _padlock: TextureRect
var _price_number: PixelLine
var _plinth: TextureRect
var _topper: TextureRect
var _sign: ToyPlate
var _sign_line: PixelLine
var _floor: ToyPlate
var _floor_line: PixelLine


func _init() -> void:
	size = SIZE
	custom_minimum_size = SIZE
	mouse_filter = Control.MOUSE_FILTER_STOP
	var shadow: ColorRect = ColorRect.new()
	shadow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	shadow.color = Palette.CHARCOAL
	_put(shadow, SHADOW_RECT.position, SHADOW_RECT.size)
	add_child(shadow)
	_lift = Control.new()
	_lift.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_lift.size = SIZE
	add_child(_lift)
	_cabinet_art = _sprite(CABINET_RECT.position, CABINET_RECT.size)
	_base = _sprite(BASE_RECT.position, BASE_RECT.size)
	_capsules = Control.new()
	_capsules.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_lift.add_child(_capsules)
	_front = _sprite(CABINET_RECT.position, CABINET_RECT.size)
	_lid = _sprite(LID_AT, LID.get_size(), LID)
	_tag = _sprite(TAG_AT, TAG.get_size(), TAG)
	_tape = _sprite(Vector2i.ZERO, ToyExitArt.TAPE_SIZE, ToyExitArt.tape())
	_build_price()
	_plinth = _sprite(PLINTH_AT, PLINTH_SIZE)
	_topper = _sprite(Vector2i(TOPPER_LEFT, TOPPER_TOP), Vector2i.ONE * TOPPER_ART)
	_sign = ToyPlate.new(SIGN_SIZE)
	_sign.position = Vector2(SIGN_AT) * ArtStyle.ART_SCALE
	add_child(_sign)
	_sign_line = PixelLine.new()
	_sign.content().add_child(_sign_line)
	_floor = ToyPlate.new(FLOOR_SIZE)
	add_child(_floor)
	_floor_line = PixelLine.new()
	_floor.content().add_child(_floor_line)
	mouse_entered.connect(_on_hover.bind(true))
	mouse_exited.connect(_on_hover.bind(false))
	set_process(false)


## Shows the `shown` aisle's machine with `left` of its `total` items still in it, in
## `shown_state`, a capsule costing `price` coins; `all_collected`: the whole collection is
## complete (no tick tags); `coins_out`: the profile has no coins (no figurine in colour).
func set_machine(
	shown: AisleDefinition,
	left: int,
	total: int,
	shown_state: CapsuleCounter.State,
	price: int,
	all_collected: bool = false,
	coins_out: bool = false
) -> void:
	_aisle = shown
	_cabinet = ToyCabinet.for_aisle(shown.id)
	_state = shown_state
	_left = left
	_total = total
	var ok: bool = shown_state == CapsuleCounter.State.OK
	var broke: bool = shown_state == CapsuleCounter.State.BROKE
	var off: bool = shown_state == CapsuleCounter.State.OFF
	var empty: bool = shown_state == CapsuleCounter.State.EMPTY
	_tone = ToyCabinet.Tone.LIT
	if off:
		_tone = ToyCabinet.Tone.OFF
	elif not ok:
		_tone = ToyCabinet.Tone.DIM
	_cabinet_art.texture = _cabinet.art("cabinet", _tone)
	_cabinet_art.visible = _cabinet_art.texture != null
	var base: Texture2D = _cabinet.art("base", _tone)
	_base.texture = base if base != null else BASE_FALLBACKS[_tone]
	_front.texture = _cabinet.art("front", _tone)
	_front.visible = _front.texture != null
	_place_capsules(_cabinet.art("capsule_window", _tone), mini(left, _cabinet.slots.size()))
	_lid.visible = broke or off
	_tag.visible = empty and not all_collected
	_tape.visible = off
	var has_window: bool = _cabinet_art.visible and _cabinet.window.has_area()
	var window: Rect2i = _cabinet.window if has_window else FALLBACK_WINDOW
	var tape_top: int = window.position.y + floori(window.size.y / 2.0) - TAPE_RISE
	_tape.position = Vector2(PAPER_LEFT, tape_top) * ArtStyle.ART_SCALE
	_coin.visible = ok
	_padlock.visible = broke
	_price.visible = ok or broke
	var price_colour: Color = Palette.GOLD if ok else Palette.GREY_DARK
	_price_number.show_tokens([str(price)], price_colour, price_colour)
	var trophy: bool = ok or (empty and not coins_out)
	var plinth_tone: ToyCabinet.Tone = ToyCabinet.Tone.LIT if trophy else ToyCabinet.Tone.DIM
	_plinth.texture = _cabinet.art("plinth", ToyCabinet.Tone.OFF if off else plinth_tone)
	_topper.texture = _cabinet.topper_art(not trophy)
	_plinth.visible = _topper.texture != null and _plinth.texture != null
	_topper.visible = _topper.texture != null
	if _topper.visible:
		var top: int = TOPPER_TOP + _topper_pad(_topper.texture)
		_topper_top = top * ArtStyle.ART_SCALE
		_topper.position = Vector2(TOPPER_LEFT * ArtStyle.ART_SCALE, _topper_top)
	_sign.set_stripe(shown.sign_color)
	var sign_colour: Color = Palette.INK if ok else Palette.GREY_DARK
	_sign_line.show_tokens([shown.display_name.to_upper()], sign_colour, sign_colour)
	_centre(_sign_line, SIGN_TEXT_X - SIGN_AT.x, SIGN_TEXT_TOP)
	mouse_default_cursor_shape = CURSOR_POINTING_HAND if ok else CURSOR_ARROW
	tooltip_text = ""
	accessibility_name = ACCESSIBLE_TEXT % [shown.display_name.to_upper(), left, total]
	if not ok:
		_hovered = false
	_show_look()


## Drops the pointer's hovered look (the reveal or the shelf covers the machine, or the keys
## pick another): it sinks, its sign and lamp cool, until the pointer enters it again.
func clear_hover() -> void:
	_hovered = false
	_show_look()


## Picks the machine with the arrow keys (true) or lets it go: a playable one looks hovered.
func set_selected(on: bool) -> void:
	_selected = on
	_show_look()


func is_selected() -> bool:
	return _selected


## "1 COIN" / "2 COINS".
static func price_text(price: int) -> String:
	return (PRICE_TEXT if price == 1 else PRICE_TEXT_PLURAL) % price


func aisle() -> AisleDefinition:
	return _aisle


func cabinet() -> ToyCabinet:
	return _cabinet


func state() -> CapsuleCounter.State:
	return _state


## The art tone the machine shows (lit, dim or off).
func tone() -> ToyCabinet.Tone:
	return _tone


## The hovered (or key-picked), playable machine: lifted, its sign lit, its lamp hot.
func is_hot() -> bool:
	return _hovered or (_selected and _state == CapsuleCounter.State.OK)


## The figurine's hop above its resting top (canvas px): 0 or HOP.
func topper_hop() -> float:
	return _topper_top - _topper.position.y


func is_lifted() -> bool:
	return _lift.position.y < 0.0


## A piece, for the screen and the tests, by name: "cabinet", "base", "front", "lid", "tag",
## "tape", "price", "coin", "padlock", "price_number", "plinth", "topper", "sign", "sign_text",
## "floor" or "floor_text".
func part(piece: String) -> Control:
	var parts: Dictionary[String, Control] = {
		"cabinet": _cabinet_art,
		"base": _base,
		"front": _front,
		"lid": _lid,
		"tag": _tag,
		"tape": _tape,
		"price": _price,
		"coin": _coin,
		"padlock": _padlock,
		"price_number": _price_number,
		"plinth": _plinth,
		"topper": _topper,
		"sign": _sign,
		"sign_text": _sign_line,
		"floor": _floor,
		"floor_text": _floor_line,
	}
	return parts.get(piece, null)


func sign_rect() -> Rect2:
	return _sign.get_global_rect()


## The floor plate's words: "5 OF 8 LEFT" or "COLLECTED".
func floor_text() -> String:
	return _floor_line.text()


## The price LED's contents (the coin or padlock and the price).
func price_label() -> Control:
	return _price


## The OUT OF ORDER tape.
func paper() -> TextureRect:
	return _tape


## How many capsules the window shows.
func capsule_count() -> int:
	return _capsules.get_child_count()


func capsules() -> Array[TextureRect]:
	var found: Array[TextureRect] = []
	for child: Node in _capsules.get_children():
		found.append(child as TextureRect)
	return found


## The clickable area on screen.
func hit_rect() -> Rect2:
	var local: Rect2 = _hit_local()
	return Rect2(global_position + local.position, local.size)


func _has_point(point: Vector2) -> bool:
	return _hit_local().has_point(point)


## HIT_RECT in the control's canvas px (picking and hit_rect share it).
static func _hit_local() -> Rect2:
	var art: float = ArtStyle.ART_SCALE
	return Rect2(Vector2(HIT_RECT.position) * art, Vector2(HIT_RECT.size) * art)


func _gui_input(event: InputEvent) -> void:
	var press: InputEventMouseButton = event as InputEventMouseButton
	if press == null or not press.pressed or press.button_index != MOUSE_BUTTON_LEFT:
		return
	accept_event()
	if _state == CapsuleCounter.State.OK and _aisle != null:
		picked.emit(_aisle)


func _on_hover(inside: bool) -> void:
	_hovered = inside and _state == CapsuleCounter.State.OK
	_show_look()
	hover_changed.emit(self, inside)


## The hovered look (risen, the sign lit, the floor plate stepped right with the tick) and the
## state's plates.
func _show_look() -> void:
	var hot: bool = is_hot()
	_lift.position.y = -LIFT if hot else 0.0
	_hop_time = 0.0
	_topper.position.y = _topper_top
	set_process(hot and not _reduced())
	var ok: bool = _state == CapsuleCounter.State.OK
	var sign_mode: ToyPlate.Mode = ToyPlate.Mode.OFF
	if ok:
		sign_mode = ToyPlate.Mode.LIT if hot else ToyPlate.Mode.NORMAL
	_sign.set_mode(sign_mode)
	var art: float = ArtStyle.ART_SCALE
	_floor.position = Vector2(FLOOR_AT) * art + Vector2(FLOOR_STEP if hot else 0.0, 0.0)
	_floor.show_tick(hot)
	var colour: Color = Palette.INK if ok else Palette.GREY_DARK
	if _left == 0:
		_floor.set_mode(ToyPlate.Mode.OFF)
		_floor.set_stripe(Palette.GREEN_DARK, COLLECTED_STRIPE)
		_floor.show_check(true)
		_floor_line.show_tokens([COLLECTED_TEXT], Palette.GREY_DARK, Palette.GREY_DARK)
		var spare: float = COLLECTED_ROOM * art - _floor_line.width()
		var left: float = COLLECTED_LEFT * art + floorf(spare / 2.0 / art) * art
		_floor_line.position = Vector2(left, FLOOR_TEXT_TOP * art)
		return
	_floor.set_mode(sign_mode)
	_floor.set_stripe(Color(0, 0, 0, 0))
	_floor.show_check(false)
	_floor_line.show_tokens(PixelLine.split(LEFT_TEXT % [_left, _total]), colour, colour)
	_centre(_floor_line, FLOOR_TEXT_X, FLOOR_TEXT_TOP)


## The hot machine's figurine hop: up HOP px on frame 1 of every HOP_CYCLE frames of HOP_FRAME s.
func _process(delta: float) -> void:
	_hop_time += delta
	var frame: int = floori(_hop_time / HOP_FRAME) % HOP_CYCLE
	_topper.position.y = _topper_top - (HOP if frame == 1 else 0.0)


func _reduced() -> bool:
	return reduced_motion.is_valid() and bool(reduced_motion.call())


func _build_price() -> void:
	_price = Control.new()
	_price.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_lift.add_child(_price)
	_coin = UiKit.sprite(COIN)
	_put(_coin, COIN_AT, Vector2i(COIN.get_size()))
	_price.add_child(_coin)
	_padlock = UiKit.sprite(PADLOCK)
	_put(_padlock, PADLOCK_AT, Vector2i(PADLOCK.get_size()))
	_price.add_child(_padlock)
	_price_number = PixelLine.new()
	_price_number.position = Vector2(PRICE_NUMBER_AT) * ArtStyle.ART_SCALE
	_price.add_child(_price_number)


## One capsule (2x) per item left, on the cabinet's first `count` slots.
func _place_capsules(texture: Texture2D, count: int) -> void:
	for child: Node in _capsules.get_children():
		_capsules.remove_child(child)
		child.free()
	if texture == null:
		return
	for index: int in range(count):
		var capsule: TextureRect = UiKit.sprite(texture)
		_put(capsule, _cabinet.slots[index], Vector2i(texture.get_size()))
		_capsules.add_child(capsule)


## A sprite on the lift layer at `at` (art px), `art_size` art px.
func _sprite(at: Vector2i, art_size: Vector2i, texture: Texture2D = null) -> TextureRect:
	var result: TextureRect = UiKit.sprite(texture)
	_put(result, at, art_size)
	_lift.add_child(result)
	return result


## Centres `line` on `centre_x` art px of its plate, its cap top `top` rows down.
static func _centre(line: PixelLine, centre_x: int, top: int) -> void:
	var art: float = ArtStyle.ART_SCALE
	var left: float = centre_x * art - floorf(line.width() / 2.0 / art) * art
	line.position = Vector2(left, top * art)


static func _put(control: Control, at: Vector2i, art_size: Vector2i) -> void:
	control.position = Vector2(at) * ArtStyle.ART_SCALE
	control.size = Vector2(art_size) * ArtStyle.ART_SCALE


## The topper sprite's empty bottom rows (its foot stands on the plinth).
static func _topper_pad(texture: Texture2D) -> int:
	if not _topper_pads.has(texture):
		var image: Image = texture.get_image()
		if image.is_compressed():
			image.decompress()
		var used: Rect2i = image.get_used_rect()
		_topper_pads[texture] = image.get_height() - used.end.y if used.has_area() else 0
	return _topper_pads[texture]
