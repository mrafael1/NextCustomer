class_name RegisterTower
extends Control
## The register's tower (the shift scene polish, mock-up docs/art/mockups/shift_scene_polish_v2.html
## section 2, variant A2; v4's A1 since): the register column's rubber front carried up from the
## printer to the top of the screen, with a steel trim along its top and left edges and rivets on
## its right strip, so the receipt, the quota gauge and the keys under them read as one machine
## left of the belt. On it, back to front: the recessed charcoal well the receipt rises in, the
## gauge's steel housing and the brass plate under it (GaugeHousing, in the column's left margin),
## the quota gauge (QuotaMeter: the housing's glass, with its lap lamp over the housing) and, on
## the plate, a Double checkout's row pips (RowPips, side by side; hidden on a shift of one row,
## the plate's € shows then). It stands at ShiftStage.TOWER_RECT in the fore, behind the receipt;
## it never shakes with the register (the count-up rattles RegisterCabinet only), so the gauge
## stays still under the count. Decor and display only: it takes no clicks.

## The tower's face and the receipt's well, 9-slices with TOWER_MARGIN and WELL_MARGIN art px.
const TOWER_FRAME := preload("res://art/frames/register_tower.png")
const TOWER_MARGIN := 8
const WELL_FRAME := preload("res://art/frames/receipt_well.png")
const WELL_MARGIN := 2

## The gauge's housing, the quota gauge, and a Double checkout's row pips on the housing's plate.
var housing: GaugeHousing
var quota_meter: QuotaMeter
var row_pips: RowPips


func _init() -> void:
	name = "RegisterTower"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	position = ShiftStage.TOWER_RECT.position
	size = ShiftStage.TOWER_RECT.size
	_add(UiKit.frame_panel(TOWER_FRAME, TOWER_MARGIN), ShiftStage.TOWER_RECT).name = "Face"
	_add(UiKit.frame_panel(WELL_FRAME, WELL_MARGIN), ShiftStage.RECEIPT_WELL_RECT).name = "Well"
	housing = GaugeHousing.new()
	var margin: Vector2 = Vector2(ShiftStage.HOUSING_RECT.end.x, ShiftStage.TOWER_RECT.size.y)
	_add(housing, Rect2(ShiftStage.TOWER_RECT.position, margin))
	quota_meter = QuotaMeter.new()
	_add(quota_meter, ShiftStage.TUBE_RECT)
	row_pips = RowPips.new()
	row_pips.reduced_motion = _reduced
	_add(row_pips, Rect2(ShiftStage.ROW_PIPS_POSITION, Vector2.ZERO))
	housing.pips = row_pips


## A stage rect in the tower's own coordinates.
static func local_rect(stage_rect: Rect2) -> Rect2:
	return Rect2(stage_rect.position - ShiftStage.TOWER_RECT.position, stage_rect.size)


## The gauge's reduced motion setting (the screen sets it), for the pips too.
func _reduced() -> bool:
	var reduced: Callable = quota_meter.reduced_motion
	return reduced.is_valid() and bool(reduced.call())


func _add(node: Control, stage_rect: Rect2) -> Control:
	var rect: Rect2 = local_rect(stage_rect)
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	node.position = rect.position
	node.size = rect.size
	add_child(node)
	return node
