class_name ReceiptFeed
extends Control
## The receipt fed into the machine (#77 machine v2, Q1 = A; build spec A3-A4), on the machine's
## stage layer (its unzoomed overlay: stage coordinates of the hud): a second ReceiptView
## (`paper`) printed from the same ScoreResult and shift-end lines as the stage's receipt, which
## hides as it is torn off (the next shift's planning shows it again). The copy lifts off the
## printer (MachineTuning's tear_lift_px and tear_tilt_deg, back to level by the slot) and travels
## with the camera's glide to over the slot plate's mouth, whose live screen rect it follows,
## shrinking to feed_fit of the mouth's width; then it is fed in under a clip at the mouth's line.
## Its top-left is the anchor: the paper's body never moves while its BONUS stub snaps off.
##
## A TICKET visit with a bonus ticket to come (Q2 = 2: view.plan.stub) prints the receipt with the
## gold stub at its foot. At plan.snap the stub shrinks away (plan.stub_left) and a BonusTicket in
## its TICKET form (`ticket`, in its own clip) leaves from the stub's exact rect and flies to the
## cabinet's dock on its kick panel (v0.50; plan.dock_flight; per-axis scale, rotation -6 deg x
## sin(pi g)), where it stays. A BONUS visit moves it from the dock to over the slot (fly ..
## fly_end) and feeds it in under the clip (.. feed_end) with its shine. Reduced motion: the receipt
## cross-fades from the
## printer to the slot instead of travelling, the ticket jumps to the dock, nothing shines.
##
## The copy is printed at the TICKET visit's `feed` beat (none when it is fast-forwarded, and none
## for a resumed visit: the receipt is already fed); the docked ticket shows whenever the plan
## says so, a resumed or fast-forwarded visit's too. No SubViewport and no get_image(): plain
## controls, so headless tests see them and the web build never stalls on a GPU read-back.

const SIZE := Vector2.ZERO
## The ticket's tilt on its way to the dock (degrees, at the flight's middle).
const DOCK_TILT_DEG := -6.0
## The fed paper shakes 1 px at this rate (the slot's rollers).
const JITTER_HZ := 20.0
## The clip keeps the paper above this line (the slot's mouth).
const NO_CLIP := 100000.0

## The machine this part belongs to (setup(), build spec 4.2).
var view: RewardMachineView
## The receipt's copy (null until printed), in a holder that carries its travel's transform; the
## clip hides what has gone into the slot.
var paper: ReceiptView
var clip: Control
## The bonus ticket (null until the plan shows one), in its own clip.
var ticket: BonusTicket
var ticket_clip: Control
var _holder: Control
## Where the stage receipt stood: its left edge and its foot (stage coordinates).
var _rest_x: float = 0.0
var _rest_foot: float = 0.0
## The stub's rect in the holder, as printed (empty until measured), for the ticket's start.
var _stub_local: Rect2 = Rect2()
## The visit the paper was printed for.
var _plan: MachinePlan


func _init() -> void:
	name = "ReceiptFeed"
	size = SIZE
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false
	clip = _new_clip("Clip")
	ticket_clip = _new_clip("TicketClip")


## Hooks this part to the machine: RewardMachineView calls it once, when it builds the part
## (build spec 4.2).
func setup(machine: RewardMachineView) -> void:
	view = machine
	view.beat.connect(_on_beat)


## The paper and the ticket at `t` on view.plan.
func frame(t: float) -> void:
	var plan: MachinePlan = view.plan
	if plan != _plan:
		_clear()
	if plan == null:
		visible = false
		return
	visible = true
	if plan.kind == MachineVisit.Kind.TICKET and is_instance_valid(view.receipt):
		view.receipt.visible = false  # Torn off: the copy (or the slot) has it now.
	_frame_paper(plan, t)
	_frame_ticket(plan, t)


## The paper at `t`: its top-left `at` (stage coordinates), `scale`, `tilt` (degrees), `alpha`,
## the clip's `line` (stage y) and whether it shows (`on`): resting, travelling to the slot, fed
## in, or gone.
func paper_anchor(t: float) -> Dictionary:
	var plan: MachinePlan = view.plan
	var width: float = maxf(paper.size.x, 1.0) if paper != null else 1.0
	var full: float = full_height()
	var rest: Vector2 = Vector2(_rest_x, _rest_foot - full)
	var mouth: Rect2 = _mouth_rect()
	var sc: float = mouth.size.x / width * view.tuning.feed_fit
	var line: float = mouth.get_center().y
	var target: Vector2 = Vector2(mouth.get_center().x - width * sc / 2.0, line - full * sc)
	var anchor: Dictionary = {
		"at": rest, "scale": 1.0, "tilt": 0.0, "alpha": 1.0, "line": NO_CLIP, "on": true
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
			anchor.scale = sc if second else 1.0
			if second:
				anchor.alpha = minf((t - cut) / span, 1.0)
			else:
				anchor.alpha = 1.0 - (t - plan.fly) / span
		else:
			var e: float = StoreCamera.ease_in_out(p)
			var bump: float = sin(p * PI)
			anchor.at = rest.lerp(target, e) - Vector2(0.0, view.tuning.tear_lift_px * bump)
			anchor.scale = lerpf(1.0, sc, e)
			anchor.tilt = -view.tuning.tear_tilt_deg * bump
	else:
		var p: float = _seg(t, plan.fly_end, plan.feed_end)
		var jitter: float = 0.0 if plan.reduced_motion else float(int(t * JITTER_HZ) % 2)
		anchor.at = target + Vector2(0.0, full * sc * p + jitter)
		anchor.scale = sc
		anchor.line = line
	return anchor


## The paper's whole height as printed (with its stub, however much of it has snapped off).
func full_height() -> float:
	if paper == null:
		return 0.0
	return paper.size.y + (paper.stub.lost() if paper.stub != null else 0.0)


## The holder's transform at `t` (stage coordinates): the paper's top-left at the anchor.
func paper_transform(t: float) -> Transform2D:
	var anchor: Dictionary = paper_anchor(t)
	var corner: Vector2 = paper.position if paper != null else Vector2.ZERO
	var s: float = float(anchor.scale)
	var tilt: float = deg_to_rad(float(anchor.tilt))
	var turn: Transform2D = Transform2D(tilt, Vector2(s, s), 0.0, anchor.at)
	return turn * Transform2D(0.0, -corner)


## The ticket at `t`: its rect (stage coordinates) and tilt (degrees); an empty rect when it is
## not shown.
func ticket_rect(t: float) -> Array:
	var plan: MachinePlan = view.plan
	if plan == null:
		return [Rect2(), 0.0]
	var dock: Rect2 = _to_stage(view.cabinet.dock_global_rect())
	if plan.kind == MachineVisit.Kind.BONUS:
		return [_bonus_rect(plan, t, dock), 0.0]
	if plan.kind != MachineVisit.Kind.TICKET or not plan.stub:
		return [Rect2(), 0.0]
	if plan.resumed:
		return [dock, 0.0]
	var g: float = plan.dock_flight(t)
	if g < 0.0:
		return [Rect2(), 0.0]
	var from: Rect2 = dock
	if paper != null and _stub_local.has_area():
		from = paper_transform(plan.snap) * _stub_local
	var e: float = StoreCamera.ease_in_out(g)
	return [_lerp_rect(from, dock, e), DOCK_TILT_DEG * sin(PI * g)]


## The bonus visit's ticket: from the dock to over the slot, then fed in (gone at feed_end).
func _bonus_rect(plan: MachinePlan, t: float, dock: Rect2) -> Rect2:
	if t >= plan.feed_end:
		return Rect2()
	var mouth: Rect2 = _mouth_rect()
	var size_at: Vector2 = (
		BonusTicket.SIZE * (mouth.size.x / BonusTicket.SIZE.x * view.tuning.feed_fit)
	)
	var line: float = mouth.get_center().y
	var over: Rect2 = Rect2(
		Vector2(mouth.get_center().x - size_at.x / 2.0, line - size_at.y), size_at
	)
	if t < plan.fly_end:
		var g: float = _seg(t, plan.fly, plan.fly_end)
		var e: float = 1.0 if plan.reduced_motion else StoreCamera.ease_in_out(g)
		return _lerp_rect(dock, over, e)
	var p: float = _seg(t, plan.fly_end, plan.feed_end)
	return Rect2(over.position + Vector2(0.0, size_at.y * p), size_at)


func _frame_paper(plan: MachinePlan, t: float) -> void:
	if _holder == null or paper == null:
		clip.visible = false
		return
	var anchor: Dictionary = paper_anchor(t)
	clip.visible = bool(anchor.on)
	clip.size = Vector2(NO_CLIP, float(anchor.line))
	_holder.modulate.a = float(anchor.alpha)
	var xform: Transform2D = paper_transform(t)
	_holder.position = xform.origin
	_holder.rotation = xform.get_rotation()
	_holder.scale = xform.get_scale()
	if paper.stub == null or plan.snap < 0.0:
		return
	if t < plan.snap or not _stub_local.has_area():
		_measure_stub()
	if t >= plan.snap:
		paper.stub.snap(BonusTicket.SIZE.y * plan.stub_left(t))
		paper.fit_height()


## The stub's rect in the holder (as it shows: clipped to the paper's width).
func _measure_stub() -> void:
	var stub: ReceiptStub = paper.stub
	var to_holder: Transform2D = _holder.get_global_transform().affine_inverse()
	var rect: Rect2 = to_holder * stub.get_global_transform() * stub.stub_rect()
	var paper_rect: Rect2 = Rect2(paper.position, paper.size)
	var left: float = maxf(rect.position.x, paper_rect.position.x)
	var right: float = minf(rect.end.x, paper_rect.end.x)
	_stub_local = Rect2(left, rect.position.y, maxf(right - left, 0.0), rect.size.y)


func _frame_ticket(plan: MachinePlan, t: float) -> void:
	var shown: Array = ticket_rect(t)
	var rect: Rect2 = shown[0]
	if not rect.has_area():
		if ticket != null:
			ticket.visible = false
		return
	if ticket == null:
		ticket = BonusTicket.new(BonusTicket.Form.TICKET, _ticket_sub(plan))
		ticket.pivot_offset = BonusTicket.SIZE / 2.0
		ticket_clip.add_child(ticket)
	ticket.visible = true
	ticket.size = BonusTicket.SIZE
	ticket.scale = rect.size / BonusTicket.SIZE
	ticket.position = rect.get_center() - BonusTicket.SIZE / 2.0
	ticket.rotation = deg_to_rad(float(shown[1]))
	var feeding: bool = plan.kind == MachineVisit.Kind.BONUS and t >= plan.fly_end
	ticket_clip.size = Vector2(NO_CLIP, _mouth_rect().get_center().y if feeding else NO_CLIP)
	var shine: float = -1.0
	if feeding and not plan.reduced_motion:
		shine = _seg(t, plan.fly_end, plan.feed_end)
	ticket.set_shine(shine)


func _ticket_sub(plan: MachinePlan) -> String:
	var shift: int = view.run.shift_index + 1 if view.run != null else 0
	return BonusTicket.sub_line(plan.inspected, shift)


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
	if is_instance_valid(view.receipt):
		view.receipt.visible = false
	if view.skipping or view.run == null:
		return
	_print_receipt(rect)


## The receipt's copy where the stage's stood (`rect`), as the count-up and the dessert left it:
## every line, the shift's end (PAID, INSPECTION PASSED, the bonus stub when the plan has one) and
## the next inspection's notice, scrolled to its end.
func _print_receipt(rect: Rect2) -> void:
	_clear()
	_plan = view.plan
	_rest_x = rect.position.x
	_rest_foot = rect.end.y
	# The holder carries the paper's travel; the paper stands in it as on the printer.
	var room: float = ShiftStage.RECEIPT_BOTTOM - ShiftStage.RECEIPT_TOP
	_holder = Control.new()
	_holder.name = "Holder"
	_holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	clip.add_child(_holder)
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
			view.receipt_header
		)
	var sub: String = _ticket_sub(_plan) if _plan.stub else ""
	paper.show_shift_end(
		view.shift_total,
		view.shift_quota,
		view.shift_notice,
		", ".join(view.receipt_inspections),
		sub
	)
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


func _new_clip(clip_name: String) -> Control:
	var made: Control = Control.new()
	made.name = clip_name
	made.clip_contents = true
	made.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(made)
	return made


func _clear() -> void:
	_plan = view.plan if view != null else null
	paper = null
	_stub_local = Rect2()
	if _holder != null:
		clip.remove_child(_holder)
		_holder.queue_free()
	_holder = null
	if ticket != null:
		ticket_clip.remove_child(ticket)
		ticket.queue_free()
	ticket = null


static func _lerp_rect(from: Rect2, to: Rect2, p: float) -> Rect2:
	return Rect2(from.position.lerp(to.position, p), from.size.lerp(to.size, p))


static func _seg(t: float, from: float, to: float) -> float:
	if to <= from:
		return 1.0 if t >= from else 0.0
	return clampf((t - from) / (to - from), 0.0, 1.0)
