class_name BareToyMachine
extends Control
## The title's TOY MACHINE (#56, mock-up title_premium_directions.html, toy_machine_bare): the
## machine with no sign board (art/scenery/toy_machine_bare.png, 72x118 art at 2x: 144x236),
## its globe holding one capsule of each aisle on the mock-up's spots. It stands in the REWARDS
## bay of the storefront and on the REWARDS menu's TOY MACHINES card; the toy machines screen
## keeps its own ToyMachineView.
##
## At night it sits behind dark glass, hazed (NIGHT_HAZE, drawn in code as the art's haze always
## is); `lit` (the REWARDS entry under the mouse or the keyboard marker) shows its full colours.
## It never moves on its own: the bay's hover jiggle belongs to the scene.

const SIZE := Vector2(144, 236)
const BODY := preload("res://art/scenery/toy_machine_bare.png")
## Each aisle's capsule (art/scenery/toy_capsule_<aisle>.png, 13x13 art) and its top left in
## the globe, in art px from the machine's top left, drawn in this order (back to front).
const CAPSULE_PATH := ToyMachineView.CAPSULE_PATH
const CAPSULE_SPOTS: Dictionary[String, Vector2i] = {
	"snacks": Vector2i(17, 38),
	"bakery": Vector2i(29, 40),
	"fruit_and_veg": Vector2i(41, 38),
	"cold_cases": Vector2i(23, 28),
	"pantry": Vector2i(36, 29),
	"household": Vector2i(30, 18),
}
## The night haze (the mock-up's teal black at 32 % over the art) and the lit look (none).
const NIGHT_HAZE := Color(0.7, 0.74, 0.74)
const LIT := Color.WHITE

## The machine shows its full colours (else the night haze).
var lit: bool = false:
	set(value):
		lit = value
		_art.modulate = LIT if value else NIGHT_HAZE

## The body and the capsules, hazed together.
var _art: Control


func _init() -> void:
	size = SIZE
	custom_minimum_size = SIZE
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_art = Control.new()
	_art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_art.size = SIZE
	add_child(_art)
	var body: TextureRect = UiKit.sprite(BODY)
	body.size = SIZE
	_art.add_child(body)
	var scale_px: float = ArtStyle.ART_SCALE
	for aisle_id: String in CAPSULE_SPOTS:
		var capsule: TextureRect = UiKit.sprite(load(CAPSULE_PATH % aisle_id) as Texture2D)
		capsule.size = Vector2(ToyMachineView.CAPSULE_ART, ToyMachineView.CAPSULE_ART) * scale_px
		capsule.position = Vector2(CAPSULE_SPOTS[aisle_id]) * scale_px
		_art.add_child(capsule)
	lit = false


## The capsule sprites in the globe, in drawing order.
func capsules() -> Array[TextureRect]:
	var result: Array[TextureRect] = []
	for child: Node in _art.get_children().slice(1):
		result.append(child as TextureRect)
	return result
