class_name MachineLayers
extends RefCounted
## The RECEIPT REWARDS machine's unzoomed layers (#77 machine v2), for RewardMachineView:
## - the feed layer (the receipt feed with the bonus ticket, and the cart drawer): stage
##   coordinates on the stage's hud, just under its top bar (home), so the travelling receipt
##   passes under the bar; it shows with the machine and goes with it (release);
## - the stage layer (the prize row's veil, the prize's flight): top_level, over everything; a
##   LEGENDARY ticket's landing shakes the stage (legendary_shake);
## - the card layer (the prize tickets and KEEP ONE, v0.50): top_level after the stage layer, on
##   the machine's own transform (follow), so the tickets keep the machine's coordinates and draw
##   over every part, the veil and any docked ticket (Godot draws top_level items after the
##   others, in tree order).

## A LEGENDARY ticket's landing jolts the scene (v0.50, R1 "drop"; never under reduced motion):
## for SHAKE_S seconds from its landing the stage shakes SHAKE_X px across (flipping SHAKE_X_HZ
## times a second) and SHAKE_Y px down and up (SHAKE_Y_HZ), easing off.
const SHAKE_S := 0.3
const SHAKE_X := 6.0
const SHAKE_Y := 4.0
const SHAKE_X_HZ := 40.0
const SHAKE_Y_HZ := 50.0


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


## The stage's shake at `t` on `shown` (zero but just after a LEGENDARY ticket lands; never under
## reduced motion), on the 2 px grid.
static func legendary_shake(shown: MachinePlan, t: float) -> Vector2:
	if shown == null or shown.reduced_motion or not shown.has_draw:
		return Vector2.ZERO
	for index: int in range(shown.reveal_at.size()):
		if shown.rarities[index] != MachinePrize.Rarity.LEGENDARY:
			continue
		var since: float = t - shown.reveal_at[index]
		if since < 0.0 or since >= SHAKE_S:
			continue
		var left: float = 1.0 - since / SHAKE_S
		var x: float = SHAKE_X if int(floorf(t * SHAKE_X_HZ)) % 2 == 1 else -SHAKE_X
		var y: float = SHAKE_Y if int(floorf(t * SHAKE_Y_HZ)) % 2 == 1 else -SHAKE_Y
		return MachineArt.snap_point(Vector2(x, y) * left)
	return Vector2.ZERO
