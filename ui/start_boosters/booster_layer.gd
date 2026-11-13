class_name BoosterLayer
extends Control
## One drawing layer of YOUR STORE (BoosterPage): the room, the additive light (cones, pools),
## the scene, the dawn on the crate, the swap tray, the storefront and the top bar, each drawn by
## BoosterPageDraw in art px. A layer never takes the mouse: the page hit-tests its own list.

var page: BoosterPage
var layer: String = ""
var pen: ArtPen


func _init(owner_page: BoosterPage, layer_name: String) -> void:
	page = owner_page
	layer = layer_name
	name = layer_name
	size = ShiftStage.SIZE
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	pen = ArtPen.new(self)


func _draw() -> void:
	BoosterPageDraw.draw(self)
