class_name StockDispenser
extends Control
## The cart reveal's TODAY'S STOCK dispenser (variant A of mock-up cart_reveal_v1.html, v0.51),
## drawn in code in the RECEIPT REWARDS machine's language: a mustard marquee with chasing bulbs,
## a slate cabinet, a glass window holding the picks in a heap, an LED, and a chute with a
## swinging flap. Pure ornament: CartReveal sets its state each frame (show_state) and flies the
## picks itself; the dispenser only shows the heap draining to SOLD OUT, the cabinet's jolt, the
## flap and the bulbs. It sits at the reveal's content origin and draws in its coordinates (the
## stage's: the game's 640x360 at 2x).

const CABINET_RECT := Rect2(782, 118, 224, 276)
const MARQUEE_RECT := Rect2(774, 82, 240, 40)
const WINDOW_RECT := Rect2(798, 134, 192, 136)
const LED_RECT := Rect2(806, 280, 176, 28)
const CHUTE_RECT := Rect2(834, 318, 120, 64)
const FLAP_HEIGHT := 16.0
const SOLD_OUT_POSITION := Vector2(830, 180)
const SOLD_OUT_TURN_DEG := -8.0
## Where a pick comes out of the chute (its art's top-left), before its arc.
const EXIT_POINT := Vector2(846, 300)
const MARQUEE_TEXT := "TODAY’S STOCK"
const MARQUEE_SIZE := 19
const LED_SIZE := 15
const SOLD_OUT_SIZE := 22
## The bulbs: BULB_COUNT of BULB_SIZE px along the marquee, alternately above and below it.
const BULB_COUNT := 14
const BULB_SIZE := 6.0
const BULB_X := 780.0
const BULB_STEP := 16.6
const BULB_TOP_Y := 75.0
const BULB_BOTTOM_Y := 122.0
## The heap: up to HEAP_COLUMNS items a row in two rows, in window coordinates.
const HEAP_COLUMNS := 5
const HEAP_LEFT := -26.0
const HEAP_STEP := 48.0
const HEAP_BACK_Y := 30.0
const HEAP_FRONT_Y := 62.0
const HEAP_FRONT_SHIFT := 24.0
const HEAP_JITTER := 8.0
## The cabinet's sides, the window's steel frame and the chute's steel ring, in px.
const SIDE := 8.0
const FRAME := 4.0
const RING := 6.0
const BAND := 4.0
## The glass's glints: bands of the window's diagonal (fractions along it) and their strength.
const GLINT_ANGLE_DEG := 115.0
const GLINTS: Array[Vector3] = [Vector3(0.30, 0.36, 0.55), Vector3(0.44, 0.47, 0.35)]
## The LED's dark inner ring.
const LED_RING := Palette.RUBBER

## The jolting part: the cabinet, the marquee and its bulbs, the window.
var _body: Control
var _window: Control
var _heap: Array[TextureRect] = []
var _heap_rest: Array[Vector2] = []
var _led: Label
var _sold_out: Control
var _flap_open: float = 0.0
var _lit: Array[bool] = []
var _marquee: Label
## The cabinet's jolt now (px): the body draws shifted by it and its children follow. The body
## itself never moves (a moved Control drawing far outside its own rect can be culled).
var _jolt: float = 0.0


## A dispenser whose heap holds `cards` (the picks, in the order they leave: the first leaves
## first, from the front of the heap).
func _init(cards: Array[CardDefinition]) -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_body = Control.new()
	_body.name = "Body"
	_body.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_body.draw.connect(_draw_body)
	add_child(_body)
	_marquee = _text(MARQUEE_TEXT, MARQUEE_SIZE, Palette.INK, MARQUEE_RECT)
	_marquee.add_theme_font_override("font", CartReveal.spaced_font(800, 1))
	_body.add_child(_marquee)
	_window = Control.new()
	_window.name = "Window"
	_window.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_window.clip_contents = true
	_window.position = WINDOW_RECT.position
	_window.size = WINDOW_RECT.size
	_window.draw.connect(_draw_glass)
	_body.add_child(_window)
	# The front row is added last (drawn in front); the first pick leaves from its end.
	var count: int = cards.size()
	for index: int in count:
		var card: CardDefinition = cards[count - 1 - index]
		var art: TextureRect = ItemView.item_art(card)
		var front: bool = index >= HEAP_COLUMNS
		var rest: Vector2 = Vector2(
			HEAP_LEFT + (index % HEAP_COLUMNS) * HEAP_STEP + (HEAP_FRONT_SHIFT if front else 0.0),
			(HEAP_FRONT_Y if front else HEAP_BACK_Y) + float((index * 5) % 9) / 8.0 * HEAP_JITTER
		)
		art.position = rest
		_window.add_child(art)
		_heap.append(art)
		_heap_rest.append(rest)
	var glints: Control = Control.new()
	glints.name = "Glints"
	glints.mouse_filter = Control.MOUSE_FILTER_IGNORE
	glints.size = WINDOW_RECT.size
	glints.draw.connect(_draw_glints.bind(glints))
	_window.add_child(glints)
	_sold_out = _stamp()
	add_child(_sold_out)
	_led = _text("", LED_SIZE, Palette.GOLD, LED_RECT)
	_led.add_theme_font_override("font", CartReveal.font(800))
	_led.add_theme_color_override("font_shadow_color", Color(Palette.GOLD, 0.45))
	_led.add_theme_constant_override("shadow_outline_size", 4)
	_led.add_theme_constant_override("shadow_offset_x", 0)
	_led.add_theme_constant_override("shadow_offset_y", 0)
	add_child(_led)
	var flap: Control = Control.new()
	flap.name = "Flap"
	flap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	flap.draw.connect(_draw_flap.bind(flap))
	add_child(flap)
	_lit.resize(BULB_COUNT)
	_lit.fill(false)


## Shows the dispenser's state: `dispensed` picks have left (the heap's front ones gone, the rest
## sunk `sink` px and wobbling `wobble` px), the cabinet jolted `jolt` px, the flap open by
## `flap_open` (0 to 1), the bulbs `lit`, the LED's `message`, and SOLD OUT once `sold_out`.
func show_state(
	dispensed: int,
	sink: float,
	wobble: float,
	jolt: float,
	flap_open: float,
	lit: Array[bool],
	message: String,
	sold_out: bool
) -> void:
	var shift: float = CartReveal.snap(jolt)
	if not is_equal_approx(shift, _jolt):
		_jolt = shift
		_marquee.position.x = MARQUEE_RECT.position.x + shift
		_window.position.x = WINDOW_RECT.position.x + shift
		_body.queue_redraw()
	var count: int = _heap.size()
	for index: int in count:
		var art: TextureRect = _heap[index]
		art.visible = index < count - dispensed
		var wob: float = roundf(sin(wobble + index)) * 2.0 if wobble != 0.0 else 0.0
		art.position = _heap_rest[index] + Vector2(0, CartReveal.snap(sink + wob))
	if lit != _lit:
		_lit = lit.duplicate()
		_body.queue_redraw()
	if not is_equal_approx(flap_open, _flap_open):
		_flap_open = flap_open
		get_node("Flap").queue_redraw()
	_led.text = message
	_sold_out.visible = sold_out


## The LED's text (for tests).
func led_text() -> String:
	return _led.text


## The heap's items still in the window (for tests).
func heap_left() -> int:
	return _heap.filter(func(art: TextureRect) -> bool: return art.visible).size()


## Whether SOLD OUT shows (for tests).
func is_sold_out() -> bool:
	return _sold_out.visible


## The SOLD OUT stamp's rect, unturned, in the dispenser's coordinates (for tests).
func sold_out_rect() -> Rect2:
	return Rect2(_sold_out.position, _sold_out.size)


func _text(text: String, font_size: int, color: Color, rect: Rect2) -> Label:
	var label: Label = UiKit.body_label(text, font_size, color)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.position = rect.position
	label.size = rect.size
	return label


## SOLD OUT: tomato letters in a 3 px tomato frame on faded paper, turned a little.
func _stamp() -> Control:
	var stamp: PanelContainer = PanelContainer.new()
	stamp.name = "SoldOut"
	stamp.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = Color(Palette.PAPER, 0.7)
	style.border_color = Palette.TOMATO
	style.set_border_width_all(3)
	style.content_margin_left = 10
	style.content_margin_right = 10
	style.content_margin_top = 2
	style.content_margin_bottom = 2
	stamp.add_theme_stylebox_override("panel", style)
	var label: Label = UiKit.body_label("SOLD OUT", SOLD_OUT_SIZE, Palette.TOMATO)
	label.add_theme_font_override("font", CartReveal.spaced_font(800, 2))
	stamp.add_child(label)
	stamp.position = SOLD_OUT_POSITION
	stamp.size = stamp.get_combined_minimum_size()
	stamp.pivot_offset = stamp.size / 2.0
	stamp.rotation_degrees = SOLD_OUT_TURN_DEG
	stamp.visible = false
	return stamp


func _draw_body() -> void:
	_body.draw_set_transform(Vector2(_jolt, 0))
	# The cabinet: slate with a lit left side and a shaded right side.
	_outlined(_body, CABINET_RECT, Palette.SLATE)
	_body.draw_rect(
		Rect2(CABINET_RECT.position, Vector2(SIDE, CABINET_RECT.size.y)), Palette.STEEL_DARK
	)
	_body.draw_rect(
		Rect2(CABINET_RECT.end.x - SIDE, CABINET_RECT.position.y, SIDE, CABINET_RECT.size.y),
		Palette.SLATE_DARK
	)
	# The marquee: mustard with a light top band and a dark bottom band.
	_outlined(_body, MARQUEE_RECT, Palette.MUSTARD)
	_body.draw_rect(
		Rect2(MARQUEE_RECT.position, Vector2(MARQUEE_RECT.size.x, BAND)), Palette.MUSTARD_LIGHT
	)
	_body.draw_rect(
		Rect2(MARQUEE_RECT.position.x, MARQUEE_RECT.end.y - BAND, MARQUEE_RECT.size.x, BAND),
		Palette.MUSTARD_DARK
	)
	for index: int in BULB_COUNT:
		var bulb: Rect2 = Rect2(
			CartReveal.snap(BULB_X + index * BULB_STEP),
			BULB_TOP_Y if index % 2 == 1 else BULB_BOTTOM_Y,
			BULB_SIZE,
			BULB_SIZE
		)
		_body.draw_rect(bulb.grow(1), Palette.INK)
		_body.draw_rect(bulb, Palette.GOLD if _lit[index] else Palette.MUSTARD_DARKEST)
	# The window's frame (the glass and the heap are its children).
	_body.draw_rect(WINDOW_RECT.grow(2), Palette.INK)
	_body.draw_rect(WINDOW_RECT, Palette.STEEL_LIGHT)
	# The LED's box and the chute with its steel ring, which never jolt.
	_body.draw_set_transform(Vector2.ZERO)
	_body.draw_rect(LED_RECT.grow(2), Palette.INK)
	_body.draw_rect(LED_RECT, LED_RING)
	_body.draw_rect(LED_RECT.grow(-2), Palette.CHARCOAL)
	_body.draw_rect(CHUTE_RECT.grow(RING + 2), Palette.INK)
	_body.draw_rect(CHUTE_RECT.grow(RING), Palette.STEEL)
	_outlined(_body, CHUTE_RECT, Palette.CHARCOAL)


## The glass inside the window's steel frame.
func _draw_glass() -> void:
	_window.draw_rect(Rect2(Vector2.ZERO, WINDOW_RECT.size), Palette.STEEL_LIGHT)
	_window.draw_rect(
		Rect2(Vector2.ONE * FRAME, WINDOW_RECT.size - Vector2.ONE * FRAME * 2.0), Palette.TEAL_PALE
	)


## The glass's diagonal glints over the heap (the mock-up's 115° gradient bands).
func _draw_glints(glints: Control) -> void:
	var box: Vector2 = WINDOW_RECT.size
	var angle: float = deg_to_rad(GLINT_ANGLE_DEG)
	var along: Vector2 = Vector2(sin(angle), -cos(angle))
	var across: Vector2 = Vector2(-along.y, along.x)
	var length: float = absf(box.x * along.x) + absf(box.y * along.y)
	var centre: Vector2 = box / 2.0
	var reach: float = box.length()
	for glint: Vector3 in GLINTS:
		var near: Vector2 = centre + along * (glint.x - 0.5) * length
		var far: Vector2 = centre + along * (glint.y - 0.5) * length
		var band: PackedVector2Array = PackedVector2Array(
			[
				near - across * reach,
				far - across * reach,
				far + across * reach,
				near + across * reach
			]
		)
		glints.draw_colored_polygon(band, Color(Palette.GLASS_GLOW, glint.z))


## The flap over the chute's mouth, folding up as a pick comes out.
func _draw_flap(flap: Control) -> void:
	var height: float = CartReveal.snap(FLAP_HEIGHT * (1.0 - 0.8 * _flap_open))
	var rect: Rect2 = Rect2(CHUTE_RECT.position, Vector2(CHUTE_RECT.size.x, maxf(height, 2.0)))
	_outlined(flap, rect, Palette.STEEL_LIGHT)
	var lip: float = minf(BAND, rect.size.y)
	flap.draw_rect(Rect2(rect.position.x, rect.end.y - lip, rect.size.x, lip), Palette.STEEL)


static func _outlined(item: CanvasItem, rect: Rect2, fill: Color) -> void:
	item.draw_rect(rect.grow(2), Palette.INK)
	item.draw_rect(rect, fill)
