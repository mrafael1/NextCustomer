class_name MachineLayers
extends RefCounted
## The RECEIPT REWARDS machine's unzoomed layers (#77 machine v2), for RewardMachineView:
## - the feed layer (the receipt feed with the bonus ticket, and the cart drawer): stage
##   coordinates on the stage's hud, just under its top bar (home), so the travelling receipt
##   passes under the bar; it shows with the machine and goes with it (release);
## - the stage layer (the prize's flight, the LEGENDARY flash): top_level, over everything; a
##   LEGENDARY reveal's jolt shakes the stage and flashes it (legendary_shake, legendary_flash);
## - the card layer (the odds card): top_level after the stage layer, on the machine's own
##   transform (follow), so the card keeps the machine's coordinates and draws over every part
##   and any docked ticket (Godot draws top_level items after the others, in tree order).

## A LEGENDARY reveal's jolt (look F, flow_template.html's shake + flash; never under reduced
## motion): between these points of its reveal the machine shakes SHAKE_X px across (flipping
## SHAKE_X_HZ times a second) and SHAKE_Y px down and up (SHAKE_Y_HZ), and earlier a gold flash
## over the stage fades from FLASH_ALPHA to 0.
const SHAKE_FROM := 0.6
const SHAKE_TO := 0.7
const SHAKE_X := 3.0
const SHAKE_Y := 2.0
const SHAKE_X_HZ := 40.0
const SHAKE_Y_HZ := 50.0
const FLASH_FROM := 0.35
const FLASH_TO := 0.45
const FLASH_ALPHA := 0.28


## A layer that takes no click, named `layer_name`, `top` level or not.
static func make(layer_name: String, top: bool) -> Control:
	var layer: Control = Control.new()
	layer.name = layer_name
	layer.top_level = top
	layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return layer


## Moves `feed` onto `stage` (its hud), just under the top bar of a ShiftStage, at 1:1, `shown`.
static func home(feed: Control, stage: Control, shown: bool) -> void:
	if feed.get_parent() != stage:
		feed.get_parent().remove_child(feed)
		stage.add_child(feed)
		var shift_stage: ShiftStage = stage as ShiftStage
		if shift_stage != null and shift_stage.top_bar.get_parent() == stage:
			stage.move_child(feed, shift_stage.top_bar.get_index())
	feed.position = Vector2.ZERO
	feed.scale = Vector2.ONE
	feed.size = stage.size
	feed.visible = shown


## Puts the top_level `layer` on `owner_item`'s global transform (in the tree only).
static func follow(layer: Control, owner_item: Control) -> void:
	if not owner_item.is_inside_tree():
		return
	var own: Transform2D = owner_item.get_global_transform()
	layer.position = own.origin
	layer.scale = own.get_scale()


## Frees `feed` once its machine goes, when it lives elsewhere (on the stage's hud).
static func release(feed: Control, owner_item: Node) -> void:
	if not is_instance_valid(feed):
		return
	var parent: Node = feed.get_parent()
	if parent != owner_item and parent != null:
		parent.remove_child(feed)
		feed.free()


## The machine's shake at `t` on `shown` (zero but during a LEGENDARY reveal's jolt; never under
## reduced motion).
static func legendary_shake(shown: MachinePlan, t: float) -> Vector2:
	if (
		shown == null
		or shown.reduced_motion
		or not _legendary_between(shown, t, SHAKE_FROM, SHAKE_TO)
	):
		return Vector2.ZERO
	var x: float = SHAKE_X if int(floorf(t * SHAKE_X_HZ)) % 2 == 1 else -SHAKE_X
	var y: float = SHAKE_Y if int(floorf(t * SHAKE_Y_HZ)) % 2 == 1 else -SHAKE_Y
	return Vector2(x, y)


## The gold flash's opacity at `t` on `shown` (0 but early in a LEGENDARY reveal; never under
## reduced motion).
static func legendary_flash(shown: MachinePlan, t: float) -> float:
	if shown == null or shown.reduced_motion or not shown.has_draw:
		return 0.0
	var alpha: float = 0.0
	for index: int in range(shown.reveal_at.size()):
		if shown.rarities[index] != MachinePrize.Rarity.LEGENDARY:
			continue
		var p: float = shown.reveal_progress(index, t)
		if p > FLASH_FROM and p < FLASH_TO:
			alpha = FLASH_ALPHA * (1.0 - (p - FLASH_FROM) / (FLASH_TO - FLASH_FROM))
	return alpha


static func _legendary_between(shown: MachinePlan, t: float, from: float, to: float) -> bool:
	if not shown.has_draw:
		return false
	for index: int in range(shown.reveal_at.size()):
		if shown.rarities[index] != MachinePrize.Rarity.LEGENDARY:
			continue
		var p: float = shown.reveal_progress(index, t)
		if p > from and p < to:
			return true
	return false
