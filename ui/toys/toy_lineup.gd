class_name ToyLineup
extends Control
## The hovered machine's lineup (#121, mock-up toy_machines_121_v2.html): a price card hung on
## two chains in the hanging board's place (v0.78, ToyExitArt.price_card), "<AISLE> LINEUP" in
## paper on its tomato band and the aisle's figurines under it as their minis at 2x on the art
## grid, owned ones in colour and unwon ones as grey shapes (ToyExitArt.silhouette); a brass
## pointer under it points down at the machine. It carries no count (the floor plate has the
## only one) and takes no clicks. Sizes in art px.
##
## It is also where a new figurine joins the collection (v1.05, mock-up toy_shelf_unlock.html
## option B, ToyLineupJoin): the join drops the card in (or keeps the hovered one up), flips the
## drawn figurine's grey shape into colour (flip_mini) and, when the aisle is completed, turns the
## band gold with ALL COLLECTED (set_collected) and hops the minis (hop_mini).

const TITLE_TEXT := "%s LINEUP"
## The completed aisle's band (the FIGURINE SHELF's words until v1.30 round 2).
const COLLECTED_TEXT := "ALL COLLECTED"
## The card's top on the stage (its chains hang from the stage's top) and its height; the card
## stays MARGIN art px inside the stage's left and inside RIGHT_LIMIT (left of the doors).
const TOP := 66
const FACE_HEIGHT := 31
const MARGIN := 8
const RIGHT_LIMIT := 512
## The words' cap top and the minis' row, from the strip's top left; a mini is MINI_SIZE art px
## (its 7x7 art at 2x), CELL apart.
const TEXT_AT := Vector2i(8, 4)
const MINIS_AT := Vector2i(8, 14)
const MINI_SIZE := 14
const CELL := 16
## The card is at least its words and TITLE_PADDING wide (the wider of the title and
## COLLECTED_TEXT, so the completed band's words fit too), or the minis and MINIS_PADDING.
const TITLE_PADDING := 16
const MINIS_PADDING := 14
## The pointer: POINTER_ROWS rows from POINTER_GAP rows under the face's ledge.
const POINTER_ROWS := 4
const POINTER_GAP := 3

var _card: TextureRect
var _minis: Array[TextureRect] = []
var _owned: Array[bool] = []
var _title: PixelLine
var _pointer: Control
var _aisle: AisleDefinition
var _width: int = 0
var _rest: Vector2 = Vector2.ZERO
var _collected: bool = false


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false


## Shows `aisle`'s lineup with the items in `unlocked` in colour, pointing down at `centre_x`
## (stage art px).
func show_aisle(aisle: AisleDefinition, unlocked: Dictionary, centre_x: int) -> void:
	for child: Node in get_children():
		remove_child(child)
		child.free()
	_minis = []
	_owned = []
	_aisle = aisle
	_collected = false
	var cards: Array[CardDefinition] = aisle.capsule_cards
	var title_text: String = TITLE_TEXT % aisle.display_name.to_upper()
	var art: float = ArtStyle.ART_SCALE
	var title_width: int = ceili(
		maxf(PixelLine.word_width(title_text), PixelLine.word_width(COLLECTED_TEXT)) / art
	)
	var width: int = maxi(title_width + TITLE_PADDING, MINIS_AT.x + 2 + cards.size() * CELL + 4)
	var left: int = clampi(
		roundi(centre_x - width / 2.0), MARGIN, maxi(MARGIN, RIGHT_LIMIT - width)
	)
	_width = width
	_rest = Vector2(left, TOP) * art
	position = _rest
	_card = UiKit.sprite(ToyExitArt.price_card(Vector2i(width, FACE_HEIGHT), TOP))
	_card.position = Vector2(0, -TOP) * art
	_card.size = Vector2(width, FACE_HEIGHT + TOP) * art
	add_child(_card)
	size = Vector2(width, FACE_HEIGHT) * art
	_title = PixelLine.new()
	_title.show_tokens([title_text], Palette.PAPER, Palette.PAPER)
	_title.position = Vector2(TEXT_AT) * art
	add_child(_title)
	for index: int in cards.size():
		var card: CardDefinition = cards[index]
		var owned: bool = unlocked.has(card.id)
		var figure: Texture2D = mini_art(card)
		var shown: Texture2D = null
		if figure != null:
			shown = figure if owned else ToyExitArt.silhouette(figure)
		var sprite: TextureRect = UiKit.sprite(shown)
		sprite.size = Vector2.ONE * MINI_SIZE * art
		sprite.position = Vector2(MINIS_AT.x + index * CELL, MINIS_AT.y) * art
		sprite.pivot_offset = sprite.size / 2.0
		add_child(sprite)
		_minis.append(sprite)
		_owned.append(owned)
	_pointer = Control.new()
	_pointer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var tip_x: int = centre_x - left
	_pointer.position = Vector2(tip_x - 4, FACE_HEIGHT + POINTER_GAP) * art
	_pointer.size = Vector2(9, POINTER_ROWS) * art
	_pointer.draw.connect(_draw_pointer)
	add_child(_pointer)
	visible = true


## The aisle shown.
func shown_aisle() -> AisleDefinition:
	return _aisle


## The card's place at rest (its parent's px); the join drops it in from above it.
func rest_position() -> Vector2:
	return _rest


## Mini `index`'s centre in the parent's px, at rest.
func mini_centre(index: int) -> Vector2:
	var art: float = ArtStyle.ART_SCALE
	var corner: Vector2 = Vector2(MINIS_AT.x + index * CELL, MINIS_AT.y) * art
	return _rest + corner + Vector2.ONE * MINI_SIZE * art / 2.0


## Shows mini `index` owned (in colour) or not (its grey shape), `squeeze` its width (1 flat out,
## the flip's ends; near 0 edge on, the flip's middle).
## The join calls this every frame: the art is only looked up when the side shown changes.
func flip_mini(index: int, owned: bool, squeeze: float = 1.0) -> void:
	if owned != _owned[index]:
		var figure: Texture2D = mini_art(_aisle.capsule_cards[index])
		if figure != null:
			_minis[index].texture = figure if owned else ToyExitArt.silhouette(figure)
		_owned[index] = owned
	_minis[index].scale = Vector2(maxf(squeeze, 0.06), 1.0)


## Mini `index` raised `rise` art px (whole pixels: the hop stays on the grid).
func hop_mini(index: int, rise: int) -> void:
	var art: float = ArtStyle.ART_SCALE
	_minis[index].position.y = (MINIS_AT.y - rise) * art


## The completed aisle's card (true): the gold band and ALL COLLECTED in ink; false: its LINEUP.
func set_collected(on: bool) -> void:
	if on == _collected or _aisle == null:
		return
	_collected = on
	_card.texture = ToyExitArt.price_card(Vector2i(_width, FACE_HEIGHT), TOP, on)
	if on:
		_title.show_tokens(PixelLine.split(COLLECTED_TEXT), Palette.INK, Palette.INK)
	else:
		var words: String = TITLE_TEXT % _aisle.display_name.to_upper()
		_title.show_tokens([words], Palette.PAPER, Palette.PAPER)


func is_collected() -> bool:
	return _collected


## The card (without its chains) with its pointer, on screen.
func strip_rect() -> Rect2:
	return Rect2(global_position, size + Vector2(0, POINTER_ROWS * ArtStyle.ART_SCALE))


func minis() -> Array[TextureRect]:
	return _minis


## Whether mini `index` shows in colour (an owned figurine).
func is_owned(index: int) -> bool:
	return _owned[index]


func title_line() -> PixelLine:
	return _title


## The card's art, its chains above it.
func card_art() -> TextureRect:
	return _card


## A figurine's mini (7x7 art), or null without one.
static func mini_art(card: CardDefinition) -> Texture2D:
	var path: String = card.mini_art_ref
	return load(path) as Texture2D if path != "" and ResourceLoader.exists(path) else null


## The pointer: brass rows narrowing to the tip, inked on both sides.
func _draw_pointer() -> void:
	var art: float = ArtStyle.ART_SCALE
	for row: int in POINTER_ROWS:
		var brass: Rect2 = Rect2(Vector2(1 + row, row) * art, Vector2(7 - row * 2, 1) * art)
		_pointer.draw_rect(brass, Palette.BRASS)
		_pointer.draw_rect(Rect2(Vector2(row, row) * art, Vector2.ONE * art), Palette.INK)
		_pointer.draw_rect(Rect2(Vector2(8 - row, row) * art, Vector2.ONE * art), Palette.INK)
