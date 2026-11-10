class_name RegisterTower
extends Control
## The register's tower (the shift scene polish, mock-up docs/art/mockups/shift_scene_polish_v2.html
## section 2, variant A2; v4's A1 since): the register column's rubber front carried up from the
## register's top to the top of the screen, with a steel trim along its top and left edges and
## rivets on its right strip, so the printer, the receipt and the keys under them read as one
## machine left of the belt. Since left column v2 (the user's pick of 2026-11-09, mock-up
## docs/art/mockups/left_column_v2.html) the quota gauge has left its left margin for the top bar
## (GaugePanel), so its recessed charcoal well spans the tower's width: the overhead printer
## (OverheadPrinter) hangs at its top and the receipt feeds down from it; the desk calendar and the
## service bell stand on the register's top at its foot. It stands at ShiftStage.TOWER_RECT in the
## fore, behind them all; it never shakes with the register. On a payday (show_payday) a brass
## moulding runs inside the well's edge (PaydayTrim, PAYDAY_TRIM_RECT), behind everything that
## hangs or stands in the well. Decor only: it takes no clicks.

## The tower's face and the receipt's well, 9-slices with TOWER_MARGIN and WELL_MARGIN art px.
const TOWER_FRAME := preload("res://art/frames/register_tower.png")
const TOWER_MARGIN := 8
const WELL_FRAME := preload("res://art/frames/receipt_well.png")
const WELL_MARGIN := 2
## Payday's moulding (stage px): inside the well's frame, from under the printer's body down to
## the well's foot (mock-up payday_day.html, round 2's WALL).
const PAYDAY_TRIM_RECT := Rect2(8, 44, 282, 354)

## Payday's moulding on the well (hidden on other days).
var payday_trim: PaydayTrim


func _init() -> void:
	name = "RegisterTower"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	position = ShiftStage.TOWER_RECT.position
	size = ShiftStage.TOWER_RECT.size
	_add(UiKit.frame_panel(TOWER_FRAME, TOWER_MARGIN), ShiftStage.TOWER_RECT).name = "Face"
	_add(UiKit.frame_panel(WELL_FRAME, WELL_MARGIN), ShiftStage.RECEIPT_WELL_RECT).name = "Well"
	payday_trim = PaydayTrim.new("PaydayTrim", PaydayTrim.Kind.FRAME, local_rect(PAYDAY_TRIM_RECT))
	add_child(payday_trim)


## Shows payday's moulding on the well (`on`), or takes it off.
func show_payday(on: bool) -> void:
	payday_trim.visible = on


## A stage rect in the tower's own coordinates.
static func local_rect(stage_rect: Rect2) -> Rect2:
	return Rect2(stage_rect.position - ShiftStage.TOWER_RECT.position, stage_rect.size)


func _add(node: Control, stage_rect: Rect2) -> Control:
	var rect: Rect2 = local_rect(stage_rect)
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	node.position = rect.position
	node.size = rect.size
	add_child(node)
	return node
