class_name DeckShelf
extends Control
## One shelf of the deck view (#56, deck view B, mock-up screens_deck_b.html): up to `columns`
## cells (DeckCell) side by side, their stickers hanging on a steel price rail (frames/shelf_rail,
## the belt's rail again) that runs the shelf's width, under a band for the section headings
## (PRODUCTS 13, COUPONS 2), each above its section's first cell on this shelf. A heading is a
## shelf-edge label (the cart and run info polish, 2026-11-12): ink words on a mustard plate in an
## ink border, its count in the number font (MixedLabel). Cells sit in columns; a column may stay
## empty (the gap before the coupons), and a note (`note`: CART FULL, ROOM FOR 2 MORE) may be
## stuck to the rail across empty columns on a label of its own.

## The heading band's height (0 for a shelf without headings), the headings' size, plate and
## border.
const BAND_HEIGHT := 24.0
const HEADING_SIZE := 16
const HEADING_PADDING := 8.0
const HEADING_BORDER := 2
## A note on the rail: its words' size and its label's node name.
const NOTE_SIZE := 18
const NOTE_PLATE := "RailNotePlate"
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


## Prints `text` on a shelf-edge label in the heading band above `column`.
func heading(text: String, column: int) -> MixedLabel:
	var plate: PanelContainer = _plate("Heading", Palette.MUSTARD)
	var label: MixedLabel = MixedLabel.new(text, HEADING_SIZE, false, Palette.INK)
	plate.add_child(label)
	plate.position = Vector2(column * (DeckCell.SIZE.x + _gap), 0)
	plate.size = Vector2(0, _band - HEADING_BORDER)
	add_child(plate)
	return label


## Prints `text` in `ink` on a label of `fill` stuck to the rail (the heading's plate, NOTE_PLATE),
## centred across columns `from` to `to` (inclusive, empty ones).
func note(text: String, from: int, to: int, fill: Color, ink: Color) -> MixedLabel:
	var plate: PanelContainer = _plate(NOTE_PLATE, fill)
	var label: MixedLabel = MixedLabel.new(text, NOTE_SIZE, false, ink)
	label.name = "RailNote"
	plate.add_child(label)
	add_child(plate)
	var left: float = from * (DeckCell.SIZE.x + _gap)
	var right: float = to * (DeckCell.SIZE.x + _gap) + DeckCell.SIZE.x
	var wanted: Vector2 = plate.get_combined_minimum_size()
	plate.size = wanted
	plate.position = Vector2(
		roundf((left + right - wanted.x) / 2.0),
		roundf(_band + RAIL_TOP + (RAIL_HEIGHT - wanted.y) / 2.0)
	)
	return label


## A shelf-edge label's plate: `fill` in an ink border, its words padded each side.
static func _plate(plate_name: String, fill: Color) -> PanelContainer:
	var plate: PanelContainer = PanelContainer.new()
	plate.name = plate_name
	plate.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = Palette.INK
	style.set_border_width_all(HEADING_BORDER)
	style.content_margin_left = HEADING_PADDING
	style.content_margin_right = HEADING_PADDING
	# The words' line has room above and below its capitals: the border may run in it, so the
	# plate stays inside its band (a mark under it keeps clear, DeckCell.MARK_CLEAR).
	style.content_margin_top = 0
	style.content_margin_bottom = 0
	plate.add_theme_stylebox_override("panel", style)
	return plate


func cells() -> Array[DeckCell]:
	var found: Array[DeckCell] = []
	for child: Node in get_children():
		if child is DeckCell:
			found.append(child as DeckCell)
	return found
