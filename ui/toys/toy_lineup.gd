class_name ToyLineup
extends Control
## The hovered machine's lineup (#121, mock-up toy_machines_121_v2.html): a lit shelf label in
## the hanging board's place, its stripe in the aisle's sign colour, "<AISLE> LINEUP" and the
## aisle's figurines as their minis at 2x on the art grid, owned ones in colour and unwon ones as
## grey shapes (ToyExitArt.silhouette); a brass pointer under it points down at the machine. It
## carries no count (the floor plate has the only one) and takes no clicks. Sizes in art px.

const TITLE_TEXT := "%s LINEUP"
## The strip's top on the stage and its face's height; the strip stays MARGIN art px inside the
## stage's left and inside RIGHT_LIMIT (left of the doors).
const TOP := 30
const FACE_HEIGHT := 31
const MARGIN := 8
const RIGHT_LIMIT := 512
## The words' cap top and the minis' row, from the strip's top left; a mini is MINI_SIZE art px
## (its 7x7 art at 2x), CELL apart.
const TEXT_AT := Vector2i(8, 4)
const MINIS_AT := Vector2i(8, 14)
const MINI_SIZE := 14
const CELL := 16
## The strip is at least the title and TITLE_PADDING wide, or the minis and MINIS_PADDING.
const TITLE_PADDING := 16
const MINIS_PADDING := 14
## The pointer: POINTER_ROWS rows from POINTER_GAP rows under the face's ledge.
const POINTER_ROWS := 4
const POINTER_GAP := 3

var _plate: ToyPlate
var _minis: Array[TextureRect] = []
var _owned: Array[bool] = []
var _title: PixelLine
var _pointer: Control


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
	var cards: Array[CardDefinition] = aisle.capsule_cards
	var title_text: String = TITLE_TEXT % aisle.display_name.to_upper()
	var art: float = ArtStyle.ART_SCALE
	var title_width: int = ceili(PixelLine.word_width(title_text) / art)
	var width: int = maxi(title_width + TITLE_PADDING, MINIS_AT.x + 2 + cards.size() * CELL + 4)
	var left: int = clampi(
		roundi(centre_x - width / 2.0), MARGIN, maxi(MARGIN, RIGHT_LIMIT - width)
	)
	position = Vector2(left, TOP) * art
	_plate = ToyPlate.new(Vector2i(width, FACE_HEIGHT))
	_plate.set_mode(ToyPlate.Mode.LIT)
	_plate.set_stripe(aisle.sign_color)
	add_child(_plate)
	size = _plate.size
	_title = PixelLine.new()
	_title.show_tokens([title_text], Palette.INK, Palette.INK)
	_title.position = Vector2(TEXT_AT) * art
	_plate.content().add_child(_title)
	for index: int in cards.size():
		var card: CardDefinition = cards[index]
		var owned: bool = unlocked.has(card.id)
		var figure: Texture2D = _mini(card)
		var shown: Texture2D = null
		if figure != null:
			shown = figure if owned else ToyExitArt.silhouette(figure)
		var sprite: TextureRect = UiKit.sprite(shown)
		sprite.size = Vector2.ONE * MINI_SIZE * art
		sprite.position = Vector2(MINIS_AT.x + index * CELL, MINIS_AT.y) * art
		_plate.content().add_child(sprite)
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


## The strip with its pointer, on screen.
func strip_rect() -> Rect2:
	return Rect2(global_position, size + Vector2(0, POINTER_ROWS * ArtStyle.ART_SCALE))


func minis() -> Array[TextureRect]:
	return _minis


## Whether mini `index` shows in colour (an owned figurine).
func is_owned(index: int) -> bool:
	return _owned[index]


func title_line() -> PixelLine:
	return _title


func plate() -> ToyPlate:
	return _plate


static func _mini(card: CardDefinition) -> Texture2D:
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
