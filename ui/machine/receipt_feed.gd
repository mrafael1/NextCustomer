class_name ReceiptFeed
extends Control
## The receipt fed into the machine (#77 machine v2, Q1 = A; build spec A3-A4), on the machine's
## stage layer (its unzoomed overlay: stage coordinates of the hud). On the shift screen
## (`view.receipt` a ReceiptView) `paper` is the stage's receipt itself (2026-11-05, the user's
## "keep the paper in place ... save the paper movement for when the receipt finishes"): at the
## `feed` beat it moves into the feed's holder as it is, every row, stamp and block where the
## dessert left them, at its scale on the stage, and goes back to its place on the stage, hidden
## (torn off: the next shift's planning shows it again), when the visit ends. Anything else (a
## test's stand-in) gets a second ReceiptView printed from the same ScoreResult and shift-end
## lines instead. The paper lifts off the
## printer (MachineTuning's tear_lift_px and tear_tilt_deg, back to level by the slot) and travels
## with the camera's glide to over the slot plate's mouth, whose live screen rect it follows,
## shrinking to feed_fit of the mouth's width; then it is fed in under a clip at the mouth's line.
## The receipt feeds once (2026-11-06, the week medals): the shift's later draws (a payday's
## second PREMIUM draw, the SILVER medal's extra draw) are paid by the same receipt, counted by the
## reader plate's draw lamps (SlotPlate), so no ticket or stub ever goes into the machine. Reduced
## motion: the receipt cross-fades from the printer to the slot instead of travelling.
##
## The paper is taken at the TICKET visit's `feed` beat (none when it is fast-forwarded, and none
## for a resumed visit: the receipt is already fed), its whole length (the dessert's lines fed on
## at its foot, 2026-11-07: nothing stays at the printer). No SubViewport and no get_image(): plain
## controls, so headless tests see them and the web build never stalls on a GPU read-back.

const SIZE := Vector2.ZERO
## The fed paper shakes 1 px at this rate (the slot's rollers).
const JITTER_HZ := 20.0
## The clip keeps the paper above this line (the slot's mouth).
const NO_CLIP := 100000.0

## The machine this part belongs to (setup(), build spec 4.2).
var view: RewardMachineView
## The receipt fed (the stage's own, or a copy; null until taken), in a holder that carries its
## travel's transform; the clip hides what has gone into the slot.
var paper: ReceiptView
var clip: Control
var _holder: Control
## Where the stage receipt stood: its left edge and its foot (stage coordinates), and its scale.
var _rest_x: float = 0.0
var _rest_foot: float = 0.0
var _rest_scale: float = 1.0
## The stage receipt's own place while the feed holds it (`paper` is it): its parent, its index
## there and its position; null when the paper is a copy.
var _home: Node
var _home_index: int = 0
var _home_position: Vector2 = Vector2.ZERO
## The visit the paper was printed for.
var _plan: MachinePlan


func _init() -> void:
	name = "ReceiptFeed"
	size = SIZE
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false
	clip = _new_clip("Clip")


## Hooks this part to the machine: RewardMachineView calls it once, when it builds the part
## (build spec 4.2).
func setup(machine: RewardMachineView) -> void:
	view = machine
	view.beat.connect(_on_beat)


## The paper at `t` on view.plan.
func frame(t: float) -> void:
	var plan: MachinePlan = view.plan
	if plan != _plan:
		_clear()
	if plan == null:
		visible = false
		return
	visible = true
	var held: bool = _home != null and paper == view.receipt
	if plan.kind == MachineVisit.Kind.TICKET and is_instance_valid(view.receipt) and not held:
		view.receipt.visible = false  # Torn off: the copy (or the slot) has it now.
	_frame_paper(t)


## The paper at `t`: its top-left `at` (stage coordinates), `scale`, `tilt` (degrees), `alpha`,
## the clip's `line` (stage y) and whether it shows (`on`): resting, travelling to the slot, fed
## in, or gone.
func paper_anchor(t: float) -> Dictionary:
	var plan: MachinePlan = view.plan
	var width: float = maxf(paper.size.x, 1.0) if paper != null else 1.0
	var full: float = full_height()
	var rest: Vector2 = Vector2(_rest_x, _rest_foot - full * _rest_scale)
	var mouth: Rect2 = _mouth_rect()
	var sc: float = mouth.size.x / width * view.tuning.feed_fit
	var line: float = mouth.get_center().y
	var target: Vector2 = Vector2(mouth.get_center().x - width * sc / 2.0, line - full * sc)
	var anchor: Dictionary = {
		"at": rest, "scale": _rest_scale, "tilt": 0.0, "alpha": 1.0, "line": NO_CLIP, "on": true
	}
	if plan == null or t >= plan.feed_end:
		anchor.on = false
	elif t < plan.fly_end:
		var p: float = _seg(t, plan.fly, plan.fly_end)
		if plan.reduced_motion:
			# A cross-fade on the camera's cut: out at the printer before it, in over the slot
			# after it, as fast.
			var cut: float = clampf(plan.cut_at(), plan.fly, plan.fly_end)
			var second: bool = t >= cut
			var span: float = maxf(cut - plan.fly, MachineTuning.sec(1))
			anchor.at = target if second else rest
			anchor.scale = sc if second else _rest_scale
			if second:
				anchor.alpha = minf((t - cut) / span, 1.0)
			else:
				anchor.alpha = 1.0 - (t - plan.fly) / span
		else:
			var e: float = StoreCamera.ease_in_out(p)
			var bump: float = sin(p * PI)
			anchor.at = rest.lerp(target, e) - Vector2(0.0, view.tuning.tear_lift_px * bump)
			anchor.scale = lerpf(_rest_scale, sc, e)
			anchor.tilt = -view.tuning.tear_tilt_deg * bump
	else:
		var p: float = _seg(t, plan.fly_end, plan.feed_end)
		var jitter: float = 0.0 if plan.reduced_motion else float(int(t * JITTER_HZ) % 2)
		anchor.at = target + Vector2(0.0, full * sc * p + jitter)
		anchor.scale = sc
		anchor.line = line
	return anchor


## The paper's whole height as printed, its fed lines included.
func full_height() -> float:
	if paper == null:
		return 0.0
	return paper.size.y


## The holder's transform at `t` (stage coordinates): the paper's top-left at the anchor.
func paper_transform(t: float) -> Transform2D:
	var anchor: Dictionary = paper_anchor(t)
	var corner: Vector2 = paper.position if paper != null else Vector2.ZERO
	var s: float = float(anchor.scale)
	var tilt: float = deg_to_rad(float(anchor.tilt))
	var turn: Transform2D = Transform2D(tilt, Vector2(s, s), 0.0, anchor.at)
	return turn * Transform2D(0.0, -corner)


func _frame_paper(t: float) -> void:
	if _holder == null or paper == null:
		clip.visible = false
		return
	var anchor: Dictionary = paper_anchor(t)
	clip.visible = bool(anchor.on)
	if _home != null:
		paper.visible = bool(anchor.on)  # The stage's own: gone into the slot once fed.
	clip.size = Vector2(NO_CLIP, float(anchor.line))
	_holder.modulate.a = float(anchor.alpha)
	var xform: Transform2D = paper_transform(t)
	_holder.position = xform.origin
	_holder.rotation = xform.get_rotation()
	_holder.scale = xform.get_scale()


## The slot plate's mouth in stage coordinates (it follows the camera).
func _mouth_rect() -> Rect2:
	return _to_stage(view.slot_plate.mouth_global_rect())


## A screen rect in stage coordinates (the stage layer's, which _place keeps on the stage).
func _to_stage(rect: Rect2) -> Rect2:
	if is_instance_valid(view.stage):
		return view.stage.get_global_transform().affine_inverse() * rect
	return get_global_transform().affine_inverse() * rect


## The stage receipt's rect in stage coordinates.
func _receipt_rect() -> Rect2:
	var receipt: Control = view.receipt
	if not is_instance_valid(receipt) or not is_instance_valid(view.stage):
		return Rect2(
			Vector2(ShiftStage.RECEIPT_X, ShiftStage.RECEIPT_TOP),
			Vector2(ShiftStage.RECEIPT_WIDTH, ShiftStage.RECEIPT_BOTTOM - ShiftStage.RECEIPT_TOP)
		)
	return _to_stage(receipt.get_global_rect())


func _on_beat(beat_name: StringName, _t0: float) -> void:
	if beat_name != &"feed" or view.plan.kind != MachineVisit.Kind.TICKET:
		return
	var rect: Rect2 = _receipt_rect()
	if view.skipping or view.run == null:
		if is_instance_valid(view.receipt):
			view.receipt.visible = false
		return
	if is_instance_valid(view.receipt) and view.receipt is ReceiptView:
		_take_receipt(rect)
		return
	if is_instance_valid(view.receipt):
		view.receipt.visible = false
	_print_receipt(rect)


## Takes the stage's receipt itself where it stood (`rect`, stage coordinates), exactly as the
## count-up and the dessert left it: the paper never changes on its way to the slot.
func _take_receipt(rect: Rect2) -> void:
	_new_holder(rect)
	paper = view.receipt as ReceiptView
	_home = paper.get_parent()
	_home_index = paper.get_index()
	_home_position = paper.position
	_rest_scale = rect.size.x / maxf(paper.size.x, 1.0)
	paper.reparent(_holder, false)
	paper.visible = true


## Gives the stage's receipt back to its place on the stage (hidden: torn off), if the feed holds
## it.
func _give_back() -> void:
	var held: ReceiptView = paper if _home != null else null
	var home: Node = _home
	_home = null
	if not is_instance_valid(held) or not is_instance_valid(home):
		return
	if held.get_parent() != null:
		held.get_parent().remove_child(held)
	if not home.is_inside_tree() or home.is_queued_for_deletion():
		held.queue_free()  # The stage is going too.
		return
	home.add_child(held)
	home.move_child(held, mini(_home_index, home.get_child_count() - 1))
	held.position = _home_position
	held.visible = false


## A holder for the paper's travel, the paper's rest at `rect` (stage coordinates).
func _new_holder(rect: Rect2) -> void:
	_clear()
	_plan = view.plan
	_rest_x = rect.position.x
	_rest_foot = rect.end.y
	_rest_scale = 1.0
	# The holder carries the paper's travel; the paper stands in it as on the printer.
	_holder = Control.new()
	_holder.name = "Holder"
	_holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	clip.add_child(_holder)


## A copy of the receipt where a stand-in stood (`rect`): every line, the shift's end (PAID,
## INSPECTION PASSED) and the next inspection's notice, scrolled to its end.
func _print_receipt(rect: Rect2) -> void:
	_new_holder(rect)
	var room: float = ShiftStage.RECEIPT_BOTTOM - ShiftStage.RECEIPT_TOP
	paper = _new_paper("FedReceipt", Vector2(rect.size.x, 0.0))
	_holder.add_child(paper)
	paper.position = Vector2(0.0, room)
	paper.fit_up(room, 0.0)
	var result: ScoreResult = view.run.last_result
	if result != null:
		paper.show_result(
			result,
			view.receipt_names,
			view.receipt_upgrades,
			view.receipt_inspections,
			view.receipt_header,
			view.receipt_cards
		)
	# INSPECTION PASSED names the inspections, never a boon day's event (v0.69).
	var passed: PackedStringArray = PackedStringArray()
	for inspection_name: String in view.receipt_inspections:
		if not view.receipt_boons.has(inspection_name):
			passed.append(inspection_name)
	paper.show_shift_end(view.shift_total, view.shift_quota, view.shift_notice, ", ".join(passed))
	paper.fit_height()


## A paper like the stage receipt (its paper frame), `paper_size` wide (and high).
func _new_paper(paper_name: String, paper_size: Vector2) -> ReceiptView:
	var copy: ReceiptView = ReceiptView.new()
	copy.name = paper_name
	copy.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if is_instance_valid(view.receipt):
		var paper_frame: StyleBox = view.receipt.get_theme_stylebox("panel")
		if paper_frame != null:
			copy.add_theme_stylebox_override("panel", paper_frame)
	copy.size = paper_size
	return copy


func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE:
		_give_back()  # The machine goes first: the stage keeps its receipt.


func _new_clip(clip_name: String) -> Control:
	var made: Control = Control.new()
	made.name = clip_name
	made.clip_contents = true
	made.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(made)
	return made


func _clear() -> void:
	_plan = view.plan if view != null else null
	_give_back()
	paper = null
	if _holder != null:
		clip.remove_child(_holder)
		_holder.queue_free()
	_holder = null


static func _seg(t: float, from: float, to: float) -> float:
	if to <= from:
		return 1.0 if t >= from else 0.0
	return clampf((t - from) / (to - from), 0.0, 1.0)
