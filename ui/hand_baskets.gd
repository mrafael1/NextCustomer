class_name HandBaskets
extends Control
## The hand's baskets on their steel ledge (#80, mock-up B2, step 8), in two layers around the
## items (HandRow): the BACK layer under them (the ledge with its shadow on the floor, each
## basket's shadow on the counter front and its contact shadow on the ledge, and the basket's back:
## its rim and the inside seen past the items) and the FRONT layer over them (the inside darkening
## the items toward the rim, then the basket's front: its lip, slotted face, handle and store
## mark), so about two thirds of each item shows above the rim. A basket left of the stage's
## centre shows its left inner wall in shade, one right of it the right wall, lit.
##
## It stands at the stage's origin and draws a basket wherever the hand puts one
## (HandRow.basket_lefts), again each time the hand is laid out. Decor only: it takes no clicks.
## The shadows are drawn in code (ink at an alpha, as mock-up B2 has them).

enum Layer { BACK, FRONT }

## The basket's rows (stage y): the rim's back edge and front edge, the lip's foot, and the face's
## foot (its feet stand 4 px lower, on the ledge's top face).
const RIM_BACK_Y := 576.0
const RIM_FRONT_Y := 592.0
const LIP_BOTTOM_Y := 604.0
const FACE_FOOT_Y := 672.0
## The face narrows TAPER px on each side from the lip to its foot.
const TAPER := 8.0
## The art, from a basket's left edge at the rim: its back and its front.
const BACK_OFFSET := Vector2(-4, 574)
const FRONT_OFFSET := Vector2(-4, 590)
## The ledge's 3-slice margins (art px) and its shadow on the floor under it, 2 px in from each
## end.
const LEDGE_MARGIN := 4
const LEDGE_SHADOW := Rect2(
	ShiftStage.LEDGE_RECT.position.x + 2,
	ShiftStage.LEDGE_RECT.end.y,
	ShiftStage.LEDGE_RECT.size.x - 4,
	4
)
const LEDGE_SHADOW_ALPHA := 0.45
## A basket's shadow on the counter front: a strip SHADOW_WIDTH wide right of the basket (it
## stands out from the counter, the light is top left), from under the rim down to the ledge.
const SHADOW_WIDTH := 6.0
const SHADOW_TOP_Y := 580.0
const SHADOW_ALPHA := 0.32
## Its contact shadow on the ledge's top face, from its left edge.
const CONTACT_SHADOW := Rect2(16, 668, 204, 12)
## The inside darkens the items toward the rim in two flat steps (from the basket's left edge).
const INSIDE_STEPS: Array[Rect2] = [Rect2(4, 584, 200, 4), Rect2(4, 588, 200, 4)]
const INSIDE_ALPHAS: Array[float] = [0.14, 0.28]
const BACK_NAME := &"BasketBack"
const FRONT_NAME := &"BasketFront"
const LEDGE_NAME := &"Ledge"

const BACK_LEFT := preload("res://art/scenery/basket_back_left.png")
const BACK_RIGHT := preload("res://art/scenery/basket_back_right.png")
const FRONT := preload("res://art/scenery/basket_front.png")
const LEDGE := preload("res://art/scenery/basket_ledge.png")

var layer: Layer
var _hand: HandRow
## Each basket's left edge at its rim (stage x), as last drawn.
var _lefts: Array[float] = []


func _init(basket_layer: Layer, hand: HandRow) -> void:
	layer = basket_layer
	_hand = hand
	name = "Baskets" if layer == Layer.BACK else "BasketFronts"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	size = ShiftStage.SIZE
	_hand.laid_out.connect(_rebuild)
	_rebuild()


## Each basket's left edge at its rim (stage x).
func basket_lefts() -> Array[float]:
	return _lefts.duplicate()


## Basket `index`'s rect from its rim down to its feet (stage coordinates).
func basket_rect(index: int) -> Rect2:
	return Rect2(_lefts[index], RIM_BACK_Y, HandRow.BASKET_WIDTH, FACE_FOOT_Y + 4.0 - RIM_BACK_Y)


## The art's parts (the ledge, the basket backs or fronts, the contact shadows), in drawing order.
func parts() -> Array[Control]:
	var found: Array[Control] = []
	for child: Node in get_children():
		if not child.is_queued_for_deletion():
			found.append(child as Control)
	return found


func _rebuild() -> void:
	_lefts = []
	for left: float in _hand.basket_lefts():
		_lefts.append(_hand.position.x + left)
	for child: Node in get_children():
		remove_child(child)
		child.queue_free()
	if layer == Layer.BACK:
		var ledge: NinePatchRect = NinePatchRect.new()
		ledge.name = LEDGE_NAME
		ledge.texture = LEDGE
		ledge.mouse_filter = Control.MOUSE_FILTER_IGNORE
		ledge.patch_margin_left = LEDGE_MARGIN * ArtStyle.ART_SCALE
		ledge.patch_margin_right = LEDGE_MARGIN * ArtStyle.ART_SCALE
		ArtStyle.use_pixel_material(ledge)
		_place(ledge, ShiftStage.LEDGE_RECT)
		for index: int in range(_lefts.size()):
			var contact: ContactShadow = ContactShadow.new()
			contact.name = "ContactShadow%d" % index
			var at: Vector2 = CONTACT_SHADOW.position + Vector2(_lefts[index], 0)
			_place(contact, Rect2(at, CONTACT_SHADOW.size))
	for index: int in range(_lefts.size()):
		var left: float = _lefts[index]
		var front: bool = layer == Layer.FRONT
		var texture: Texture2D = FRONT if front else _back_for(left)
		var art: TextureRect = UiKit.sprite(texture)
		art.name = "%s%d" % [FRONT_NAME if front else BACK_NAME, index]
		var offset: Vector2 = FRONT_OFFSET if front else BACK_OFFSET
		_place(art, Rect2(Vector2(left, 0) + offset, texture.get_size()))
	queue_redraw()


## The back for a basket at `left`: its left inner wall left of the stage's centre, else its right.
static func _back_for(left: float) -> Texture2D:
	var centre: float = left + HandRow.BASKET_WIDTH / 2.0
	return BACK_LEFT if centre < ShiftStage.SIZE.x / 2.0 else BACK_RIGHT


## How far the face is in from the rim's ends at row `y` (stage), stepped every 2 px.
static func taper_at(y: float) -> float:
	var depth: float = clampf((y - LIP_BOTTOM_Y) / (FACE_FOOT_Y - LIP_BOTTOM_Y), 0.0, 1.0)
	return roundf(depth * TAPER / ArtStyle.ART_SCALE) * ArtStyle.ART_SCALE


## BACK: the ledge's floor shadow and each basket's shadow on the counter front, under the art.
## FRONT: the inside's darkening over the items, under the fronts.
func _draw() -> void:
	if layer == Layer.FRONT:
		for left: float in _lefts:
			for index: int in range(INSIDE_STEPS.size()):
				var step: Rect2 = INSIDE_STEPS[index]
				draw_rect(
					Rect2(step.position + Vector2(left, 0), step.size),
					Color(Palette.INK, INSIDE_ALPHAS[index])
				)
		return
	draw_rect(LEDGE_SHADOW, Color(Palette.INK, LEDGE_SHADOW_ALPHA))
	var shade: Color = Color(Palette.INK, SHADOW_ALPHA)
	var pixel: float = ArtStyle.ART_SCALE
	for left: float in _lefts:
		var right: float = left + HandRow.BASKET_WIDTH
		var y: float = SHADOW_TOP_Y
		while y < ShiftStage.LEDGE_RECT.position.y + pixel:
			var x: float = right + pixel if y < LIP_BOTTOM_Y else right - taper_at(y)
			draw_rect(Rect2(x, y, SHADOW_WIDTH, pixel), shade)
			y += pixel


func _place(part: Control, rect: Rect2) -> void:
	part.position = rect.position
	part.size = rect.size
	add_child(part)
