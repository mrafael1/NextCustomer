class_name BuildLayer
extends Control
## One drawing layer of YOUR BUILD (BuildPage): the staff room with the packs and the deck, the
## floor row, the top bar, the BADGE PINS step and the OPEN STORE flight, each drawn by
## BuildPageDraw in art px. A layer never takes the mouse: the page hit-tests its own list.

var page: BuildPage
var layer: String = ""
var pen: ArtPen


func _init(owner_page: BuildPage, layer_name: String) -> void:
	page = owner_page
	layer = layer_name
	name = layer_name
	size = ShiftStage.SIZE
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	pen = ArtPen.new(self)


func _draw() -> void:
	BuildPageDraw.draw(self)
