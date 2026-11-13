class_name CartLayout
extends RefCounted
## The deck view's Cart cards laid out (the cart as cards, mock-up docs/art/mockups/
## cart_cards.html, its "2x8 cart face", approved by the user on 2026-11-13): each card's top left
## in the grid (the products, then the coupons), the columns each group takes, the rows, the gap
## between columns, the coupons' first column's x (-1: none) and the grid's height. Up to COLUMNS
## columns in at least ROWS rows, GRID_PAD from the page's sides, the coupons' group GROUP_GAP
## after the products, the columns at most GAP_MAX apart, the rows ROW_GAP apart under each
## card's tab. DashLine is the dashed line before the coupons' group.

const COLUMNS := 8
const ROWS := 2
const GRID_PAD := 10.0
const GROUP_GAP := 30.0
const GAP_MAX := 18.0
const ROW_GAP := 12.0
## The dashed line before the coupons: dashes DASH long, DASH_LINE wide.
const DASH := 6.0
const DASH_LINE := 2.0

var positions: Array[Vector2] = []
var product_columns: int = 0
var coupon_columns: int = 0
var rows: int = 0
var gap: float = 0.0
var coupon_x: float = -1.0
var height: float = 0.0


## The cards laid out for `products` products then `coupons` coupons across `width` px: at least
## ROWS rows, the coupons in ceil(coupons / rows) columns after the products, the products in the
## columns left (all of them up to COLUMNS, filled row by row); a row more while the products
## don't fit.
static func of(products: int, coupons: int, width: float) -> CartLayout:
	var layout: CartLayout = CartLayout.new()
	var row_total: int = ROWS
	var coupons_wide: int = 0
	while true:
		coupons_wide = ceili(coupons / float(row_total)) if coupons > 0 else 0
		var room: int = COLUMNS - coupons_wide
		if (products == 0 and room >= 0) or (room > 0 and products <= room * row_total):
			break
		row_total += 1
	var products_wide: int = 0
	if products > 0:
		products_wide = maxi(
			ceili(products / float(row_total)), mini(products, COLUMNS - coupons_wide)
		)
	var columns: int = products_wide + coupons_wide
	var group: float = GROUP_GAP if products_wide > 0 and coupons_wide > 0 else 0.0
	var room_x: float = width - 2.0 * GRID_PAD - columns * DeckCell.SIZE.x - group
	var spacing: float = minf(GAP_MAX, room_x / maxf(1.0, columns - 1.0))
	var pitch: float = DeckCell.SIZE.y + DeckCell.TOP_ROOM + ROW_GAP
	var column_x: Callable = func(column: int) -> float:
		return (
			GRID_PAD
			+ column * (DeckCell.SIZE.x + spacing)
			+ (group if column >= products_wide else 0.0)
		)
	for index: int in products:
		var row: int = floori(index / float(products_wide))
		layout.positions.append(
			Vector2(column_x.call(index % products_wide), DeckCell.TOP_ROOM + row * pitch)
		)
	for index: int in coupons:
		var row: int = floori(index / float(coupons_wide))
		var column: int = products_wide + index % coupons_wide
		layout.positions.append(Vector2(column_x.call(column), DeckCell.TOP_ROOM + row * pitch))
	layout.product_columns = products_wide
	layout.coupon_columns = coupons_wide
	layout.rows = row_total
	layout.gap = spacing
	layout.coupon_x = column_x.call(products_wide) if coupons_wide > 0 else -1.0
	layout.height = row_total * (DeckCell.SIZE.y + DeckCell.TOP_ROOM) + (row_total - 1) * ROW_GAP
	return layout


## The dashed line before the coupons' group.
class DashLine:
	extends Control

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var y: float = 0.0
		while y < size.y:
			draw_rect(Rect2(0, y, size.x, minf(DASH, size.y - y)), Palette.TEAL_SHADE)
			y += DASH * 2.0 - 2.0
