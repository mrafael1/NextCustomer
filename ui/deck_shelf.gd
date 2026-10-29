class_name DeckShelf
extends Control
## One shelf of the deck view (#56, deck view B, mock-up screens_deck_b.html): up to `columns`
## cells (DeckCell) side by side, their stickers hanging on a steel price rail (frames/shelf_rail,
## the belt's rail again) that runs the shelf's width, under a band for the section headings
## (PRODUCTS, COUPONS; MixedLabel), each printed above its section's first cell on this shelf.
## Cells sit in columns; a column may stay empty (the gap before the coupons).

## The heading band's height (0 for a shelf without headings) and the headings' size.
const BAND_HEIGHT := 20.0
const HEADING_SIZE := 18
## The rail behind the stickers (cell coordinates: the sticker's top is at ItemView.TRAY_STICKER).
const RAIL_TOP := ItemView.TRAY_STICKER.y + 12.0
const RAIL_HEIGHT := 40.0
const RAIL_MARGIN := 3
const RAIL := preload("res://art/frames/shelf_rail.png")

var _columns: int
var _gap: float
var _band: float


## A shelf of `columns` columns `gap` apart, with a heading band when `with_band`.
func _init(columns: int, gap: float, with_band: bool) -> void:
	_columns = columns
	_gap = gap
	_band = BAND_HEIGHT if with_band else 0.0
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size = Vector2(width(columns, gap), _band + DeckCell.SIZE.y)
	size = custom_minimum_size
	var rail: PanelContainer = UiKit.frame_panel(RAIL, RAIL_MARGIN)
	rail.name = "Rail"
	rail.position = Vector2(0, _band + RAIL_TOP)
	rail.size = Vector2(size.x, RAIL_HEIGHT)
	add_child(rail)


## A shelf's width for `columns` cells `gap` apart.
static func width(columns: int, gap: float) -> float:
	return columns * DeckCell.SIZE.x + (columns - 1) * gap


## Puts `cell` in `column`.
func put(cell: DeckCell, column: int) -> void:
	cell.position = Vector2(column * (DeckCell.SIZE.x + _gap), _band)
	add_child(cell)


## Puts a free spot of the cart (CartPlacing's RoomSpot) in `column`.
func put_spot(spot: Control, column: int) -> void:
	spot.position = Vector2(column * (DeckCell.SIZE.x + _gap), _band)
	add_child(spot)


## Prints `text` in the heading band above `column`.
func heading(text: String, column: int) -> MixedLabel:
	var label: MixedLabel = MixedLabel.new(text, HEADING_SIZE, false, Palette.MUSTARD)
	label.position = Vector2(column * (DeckCell.SIZE.x + _gap), 0)
	label.size = Vector2(0, _band)
	add_child(label)
	return label


func cells() -> Array[DeckCell]:
	var found: Array[DeckCell] = []
	for child: Node in get_children():
		if child is DeckCell:
			found.append(child as DeckCell)
	return found
