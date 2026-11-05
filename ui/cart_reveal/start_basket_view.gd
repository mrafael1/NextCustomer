class_name StartBasketView
extends Control
## One of the counter's three baskets (full build plan 7.2): its source label (glyph and name),
## a wire basket holding its two dealt items, covered by a gingham cloth until LOCK IN & DEAL,
## its RESTOCK tag and, once restocked, the RESTOCKED stamp.

signal restock_pressed(index: int)

const SIZE := Vector2(246, 206)
## The wire body under the label, the two tiles' tops, and the RESTOCK tag (basket px).
const BODY := Rect2(0, 32, 246, 146)
const TILE_TOP := 38.0
const TAG := Rect2(0, 182, 246, 24)
## The reveal: the cloth lifting, and each tile's pop after it.
const LIFT_S := 0.18
const POP_S := 0.16
const POP_STAGGER_S := 0.06

var index: int = 0
var source: StringName = &""
var covered: bool = false
var tiles: Array[Control] = []
var cover: Control
## The RESTOCK tag (null when none shows) and the RESTOCKED stamp (null when not restocked).
var tag: Button
var stamp: Control
var label: Label


func _init(slot: int) -> void:
	index = slot
	name = "Basket%d" % slot
	size = SIZE
	mouse_filter = Control.MOUSE_FILTER_IGNORE


## Shows the basket: `title` and `glyph` for its source, `cards` (covered: under the cloth), and
## its RESTOCK tag in `tag_state` (&"" none, &"open", &"pick" waiting for 1–3, &"locked",
## &"none") with `tag_tip`; `restocked` stamps it.
func show_basket(
	basket_source: StringName,
	title: String,
	glyph: Texture2D,
	cards: Array[CardDefinition],
	is_covered: bool,
	tag_state: StringName,
	tag_tip: String,
	restocked: bool
) -> void:
	StartBoardKit.clear(self)
	tiles.clear()
	tag = null
	stamp = null
	source = basket_source
	covered = is_covered
	var band: Panel = StartBoardKit.panel(self, Rect2(0, 0, SIZE.x, 28), Palette.PAPER)
	band.name = "Label"
	var left: float = 8
	if glyph != null:
		StartBoardKit.icon(band, glyph, Vector2(8, 4))
		left = 34
	label = StartBoardKit.tag(
		band,
		title,
		Rect2(left, 0, SIZE.x - left - 40, 26),
		Palette.INK if source != &"" else Palette.GREY
	)
	label.name = "Name"
	var key: Panel = StartBoardKit.panel(band, Rect2(SIZE.x - 30, 3, 24, 22), Palette.CREAM)
	key.name = "Key"
	var number: Label = StartBoardKit.number(
		key, str(index + 1), Rect2(0, -2, 24, 22), Palette.INK, 20
	)
	number.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var body: Control = Control.new()
	body.name = "Body"
	body.position = BODY.position
	body.size = BODY.size
	body.mouse_filter = Control.MOUSE_FILTER_IGNORE
	body.draw.connect(_draw_wire.bind(body))
	add_child(body)
	for at: int in cards.size():
		var tile: StartItemTile = StartItemTile.new(cards[at])
		tile.name = "Tile%d" % at
		tile.position = Vector2(10 + at * 118, TILE_TOP)
		add_child(tile)
		tiles.append(tile)
	var lip: Panel = StartBoardKit.panel(
		self, Rect2(0, 172, SIZE.x, 8), Palette.STEEL_LIGHT, Palette.STEEL_DARK
	)
	lip.name = "Lip"
	cover = _cloth(source == &"")
	cover.visible = covered
	if restocked:
		stamp = StartBoardKit.panel(self, Rect2(118, 14, 124, 28), Palette.MUSTARD)
		stamp.name = "Stamp"
		stamp.rotation = deg_to_rad(-5)
		StartBoardKit.tag(stamp, "RESTOCKED", Rect2(2, 0, 120, 26), Palette.INK, 2, true)
	if tag_state == &"":
		return
	var caption: String = "RESTOCK" if tag_state != &"pick" else "%d  RESTOCK" % (index + 1)
	tag = StartBoardKit.key(self, caption, TAG, func() -> void: restock_pressed.emit(index))
	tag.name = "Restock"
	tag.tooltip_text = tag_tip
	tag.disabled = tag_state in [&"locked", &"none"]
	var words: Label = StartBoardKit.key_caption(tag)
	if tag_state == &"pick":
		StartBoardKit.restyle(tag, Palette.GOLD, Palette.INK, 2)
		words.add_theme_color_override("font_color", Palette.INK)
	elif tag.disabled:
		words.add_theme_color_override("font_color", Palette.INK_LIGHT)
		if tag_state == &"locked":
			var lock: TextureRect = StartBoardKit.icon(tag, StartBoardKit.PADLOCK, Vector2(10, 3))
			lock.name = "Padlock"
	UiKit.place_pixel_label(words, Rect2(8, 0, TAG.size.x - 16, TAG.size.y - 6), true)
	StartBoardKit.centre(words, Rect2(8, 0, TAG.size.x - 16, TAG.size.y - 6))


## Plays the reveal after `delay` s: the cloth lifts, then the tiles pop in. Returns its tween.
func play_reveal(delay: float) -> Tween:
	cover.visible = true
	cover.scale = Vector2.ONE
	for tile: Control in tiles:
		tile.pivot_offset = tile.size / 2.0
		tile.scale = Vector2.ZERO
	var tween: Tween = create_tween()
	tween.tween_interval(delay)
	tween.tween_method(
		func(fraction: float) -> void: cover.scale.y = 1.0 - floorf(fraction * 6) / 6.0,
		0.0,
		1.0,
		LIFT_S
	)
	tween.tween_callback(func() -> void: cover.visible = false)
	for at: int in tiles.size():
		(
			tween
			. parallel()
			. tween_property(tiles[at], "scale", Vector2.ONE, POP_S)
			. set_delay(at * POP_STAGGER_S)
			. set_trans(Tween.TRANS_BACK)
			. set_ease(Tween.EASE_OUT)
		)
	return tween


## The reveal's last frame.
func settle() -> void:
	cover.visible = covered
	cover.scale = Vector2.ONE
	for tile: Control in tiles:
		tile.scale = Vector2.ONE


## The gingham cloth over the basket; `empty`: no source picked yet.
func _cloth(empty: bool) -> Control:
	var cloth: Control = Control.new()
	cloth.name = "Cloth"
	cloth.position = Vector2(4, 30)
	cloth.size = Vector2(SIZE.x - 8, 146)
	cloth.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cloth.draw.connect(
		func() -> void:
			cloth.draw_rect(Rect2(Vector2.ZERO, cloth.size), Palette.CREAM)
			for y: int in range(0, int(cloth.size.y), 16):
				for x: int in range(0, int(cloth.size.x), 16):
					var band: bool = (floori(x / 16.0) + floori(y / 16.0)) % 2 == 0
					cloth.draw_rect(
						Rect2(x, y, 8, 16), Palette.TOMATO_LIGHT if band else Palette.TOMATO_PALE
					)
					cloth.draw_rect(Rect2(x, y, 16, 8), Color(Palette.TOMATO, 0.55))
			cloth.draw_rect(Rect2(0, cloth.size.y - 6, cloth.size.x, 6), Palette.TOMATO_DARK)
	)
	add_child(cloth)
	var card: Panel = StartBoardKit.panel(
		cloth, Rect2(28, 52, cloth.size.x - 56, 40), Palette.PAPER
	)
	card.name = "Card"
	StartBoardKit.tag(
		card,
		"PICK AN AISLE" if empty else "2 ITEMS",
		Rect2(0, 6, card.size.x, 26),
		Palette.GREY if empty else Palette.INK,
		2,
		true
	)
	return cloth


func _draw_wire(body: Control) -> void:
	var rect: Rect2 = Rect2(Vector2.ZERO, body.size)
	body.draw_rect(rect, Palette.STEEL_DARK)
	body.draw_rect(rect.grow(-2), Palette.STEEL_DARKEST)
	for x: int in range(6, int(rect.size.x) - 4, 12):
		body.draw_rect(Rect2(x, 4, 2, rect.size.y - 8), Palette.STEEL_SHADE)
	for y: int in range(10, int(rect.size.y) - 4, 16):
		body.draw_rect(Rect2(4, y, rect.size.x - 8, 2), Palette.STEEL_SHADE)
	body.draw_rect(Rect2(-6, 6, 6, 30), Palette.STEEL_LIGHT)
	body.draw_rect(Rect2(rect.size.x, 6, 6, 30), Palette.STEEL_LIGHT)
