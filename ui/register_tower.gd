class_name RegisterTower
extends Control
## The register's tower (the shift scene polish, mock-up docs/art/mockups/shift_scene_polish_v2.html
## section 2, variant A2): the register column's charcoal front carried up from the printer to the
## top of the screen, so the receipt, the quota gauge and the keys under them read as one zone left
## of the belt. On it, back to front: the charcoal well the receipt rises in, the quota gauge
## (QuotaMeter: a liquid tube in the column's left margin, beside the receipt, that fills up toward
## the quota) and, under the tube, a Double checkout's row pips (RowPips, stacked from the foot up;
## hidden on a shift of one row). It stands at ShiftStage.TOWER_RECT in the fore, behind the
## receipt; it never shakes with the register (the count-up rattles RegisterCabinet only), so the
## gauge stays still under the count. Decor and display only: it takes no clicks.

## The tower's face and the receipt's well, 9-slices with TOWER_MARGIN and WELL_MARGIN art px.
const TOWER_FRAME := preload("res://art/frames/register_tower.png")
const TOWER_MARGIN := 4
const WELL_FRAME := preload("res://art/frames/receipt_well.png")
const WELL_MARGIN := 2

## The quota gauge, and a Double checkout's row pips under it.
var quota_meter: QuotaMeter
var row_pips: RowPips


func _init() -> void:
	name = "RegisterTower"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	position = ShiftStage.TOWER_RECT.position
	size = ShiftStage.TOWER_RECT.size
	_add(UiKit.frame_panel(TOWER_FRAME, TOWER_MARGIN), ShiftStage.TOWER_RECT).name = "Face"
	_add(UiKit.frame_panel(WELL_FRAME, WELL_MARGIN), ShiftStage.RECEIPT_WELL_RECT).name = "Well"
	quota_meter = QuotaMeter.new()
	_add(quota_meter, ShiftStage.TUBE_RECT)
	row_pips = RowPips.new()
	row_pips.vertical = true
	row_pips.reduced_motion = _reduced
	_add(row_pips, Rect2(ShiftStage.ROW_PIPS_POSITION, Vector2.ZERO))


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
