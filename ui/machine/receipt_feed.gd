class_name ReceiptFeed
extends Control
## The receipt fed into the machine (#77, look F; build spec 4.2-4.3), on the machine's stage
## layer: a second ReceiptView (`paper`) printed from the same ScoreResult and shift-end lines as
## the stage's receipt (which never moves), lifted off the printer and flown from it to
## ShiftStage.MACHINE_SLOT_POINT (shrinking to FEED_SCALE, tilting to TILT_DEG and back, on an
## ARC px arc), then fed into the slot under its clip. A BONUS visit's stub (`stub`, 236x128:
## "SHIFT n/m · BONUS TICKET", INSPECTION PASSED naming the inspection, "1 MORE PRIZE ›") first
## prints up out of the printer's mouth (ShiftStage.MACHINE_STUB_MOUTH), then flies and feeds the
## same way. No SubViewport and no get_image(): both papers are plain controls, so headless tests
## see them and the web build never stalls on a GPU read-back.
##
## The papers are printed at the visit's first beat (`feed`, `bonus`; none when it is
## fast-forwarded, and none for a resumed visit: the receipt is already fed); frame(t) places
## them on view.plan's fly, fly_end and feed_end. Under reduced motion the receipt never flies
## (it is fed at once, as on the approved page) and the stub shows at the printer until its feed.

const SIZE := Vector2.ZERO
const FEED_SCALE := 0.36
const TILT_DEG := -8.0
const ARC := 14.0
## The paper lifts this far as it is torn off, before it flies.
const LIFT := 6.0
## The fed paper shakes 1 px at this rate (the slot's rollers).
const JITTER_HZ := 20.0
const STUB_SIZE := Vector2(236, 128)
## The stub rises out of the printer's mouth from STUB_LEAD after its start to STUB_TAIL before
## its tear (look F).
const STUB_LEAD := 0.05
const STUB_TAIL := 0.1
const STUB_TEXT := "SHIFT %d/%d · BONUS TICKET"
const MORE_TEXT := "1 MORE PRIZE ›"
## The clip keeps the paper above this line (the slot's mouth, or the printer's).
const NO_CLIP := 100000.0

## The machine this part belongs to (setup(), build spec 4.2).
var view: RewardMachineView
## The receipt's copy and the BONUS stub (null until printed), each in a holder that carries its
## flight's transform; the clip hides what has gone into the slot (or is still in the printer).
var paper: ReceiptView
var stub: ReceiptView
var clip: Control
var _holder: Control
## The visit the paper was printed for.
var _plan: MachinePlan


func _init() -> void:
	name = "ReceiptFeed"
	size = SIZE
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false
	clip = Control.new()
	clip.name = "Clip"
	clip.clip_contents = true
	clip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(clip)


## Hooks this part to the machine: RewardMachineView calls it once, when it builds the part
## (build spec 4.2).
func setup(machine: RewardMachineView) -> void:
	view = machine
	view.beat.connect(_on_beat)


## The paper at `t` on view.plan: resting, printing (the stub), flying, being fed, or gone.
func frame(t: float) -> void:
	var plan: MachinePlan = view.plan
	if plan != _plan:
		_clear()
	if plan == null or _holder == null:
		visible = false
		return
	var shown: ReceiptView = stub if stub != null else paper
	var rest: Vector2 = _rest_point(shown)
	var height: float = shown.size.y
	var width: float = shown.size.x
	var slot: Vector2 = ShiftStage.MACHINE_SLOT_POINT
	var target: Vector2 = Vector2(slot.x - width * FEED_SCALE / 2.0, slot.y - height * FEED_SCALE)
	var at: Vector2 = rest
	var paper_scale: float = 1.0
	var tilt: float = 0.0
	var clip_bottom: float = NO_CLIP
	var on: bool = true
	if stub != null and t < plan.fly:
		# Printing: up out of the printer's mouth, hidden below it.
		clip_bottom = ShiftStage.MACHINE_STUB_MOUTH.y
		if not plan.reduced_motion:
			var p: float = _smooth(_seg(t, STUB_LEAD, plan.stub_end - STUB_TAIL))
			at.y = ShiftStage.MACHINE_STUB_MOUTH.y - height * p
			on = p > 0.0
	elif plan.reduced_motion or t >= plan.feed_end:
		on = false
	elif t < plan.fly:
		on = false  # The receipt waits on the printer: the stage's own shows.
	elif t < plan.fly_end:
		var p: float = _smooth(_seg(t, plan.fly, plan.fly_end))
		at = (rest - Vector2(0.0, LIFT)).lerp(target, p) - Vector2(0.0, sin(p * PI) * ARC)
		paper_scale = lerpf(1.0, FEED_SCALE, p)
		tilt = sin(p * PI) * TILT_DEG
	else:
		var p: float = _seg(t, plan.fly_end, plan.feed_end)
		at = target + Vector2(0.0, height * FEED_SCALE * p + float(int(t * JITTER_HZ) % 2))
		paper_scale = FEED_SCALE
		clip_bottom = slot.y
	visible = on
	clip.size = Vector2(NO_CLIP, clip_bottom)
	# The holder's pivot is the paper's top-left, so the paper's corner sits at `at`.
	var corner: Vector2 = shown.position
	_holder.pivot_offset = corner
	_holder.position = at - corner
	_holder.scale = Vector2.ONE * paper_scale
	_holder.rotation = deg_to_rad(tilt)


## Where the shown paper rests at the printer, in stage coordinates (its top-left).
func _rest_point(shown: ReceiptView) -> Vector2:
	if shown == stub:
		return ShiftStage.MACHINE_STUB_MOUTH - Vector2(0.0, STUB_SIZE.y)
	return _receipt_rect().position


## The stage receipt's rect in stage coordinates.
func _receipt_rect() -> Rect2:
	var receipt: Control = view.receipt
	if not is_instance_valid(receipt) or not is_instance_valid(view.stage):
		return Rect2(
			Vector2(ShiftStage.RECEIPT_X, ShiftStage.RECEIPT_TOP),
			Vector2(ShiftStage.RECEIPT_WIDTH, ShiftStage.RECEIPT_BOTTOM - ShiftStage.RECEIPT_TOP)
		)
	return view.stage.get_global_transform().affine_inverse() * receipt.get_global_rect()


func _on_beat(beat_name: StringName, _t0: float) -> void:
	if view.skipping or view.run == null:
		return
	if beat_name == &"feed" and view.plan.kind == MachineVisit.Kind.TICKET:
		_print_receipt()
	elif beat_name == &"bonus":
		_print_stub()


## The receipt's copy, as the count-up and the dessert left the stage's: every line, the shift's
## end (PAID, INSPECTION PASSED) and the next inspection's notice, scrolled to its end.
func _print_receipt() -> void:
	_clear()
	_plan = view.plan
	var rect: Rect2 = _receipt_rect()
	# The holder stands where the stage receipt may grow (its top cap to its foot).
	var room: float = ShiftStage.RECEIPT_BOTTOM - ShiftStage.RECEIPT_TOP
	_holder = _new_holder(Vector2(rect.position.x, ShiftStage.RECEIPT_TOP))
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
	paper.show_shift_end(
		view.shift_total, view.shift_quota, view.shift_notice, ", ".join(view.receipt_inspections)
	)
	paper.fit_height()


## The BONUS TICKET's stub: the header, INSPECTION PASSED naming the inspection (none for a bonus
## extra shift), "1 MORE PRIZE ›".
func _print_stub() -> void:
	_clear()
	_plan = view.plan
	_holder = _new_holder(Vector2.ZERO)
	stub = _new_paper("BonusStub", STUB_SIZE)
	_holder.add_child(stub)
	stub.position = ShiftStage.MACHINE_STUB_MOUTH - Vector2(0.0, STUB_SIZE.y)
	var header: PackedStringArray = PackedStringArray()
	if not view.receipt_header.is_empty():
		header.append(view.receipt_header[0])
	var record: ShiftRecord = view.run.history[-1] if not view.run.history.is_empty() else null
	header.append(STUB_TEXT % [record.shift if record != null else 0, view.run.shift_count()])
	stub.begin(header)
	var visit: MachineVisit = view.run.machine.current_visit()
	var inspected: bool = visit != null and not visit.why.is_empty()
	if inspected:
		ReceiptStamps.stamp_inspection(stub, ", ".join(view.receipt_inspections))
	var more: Control = stub.add_line("", MORE_TEXT, ReceiptView.LineStyle.MARGIN)
	(more.get_child(1) as Label).add_theme_color_override("font_color", Palette.GREEN_DARK)


func _new_holder(at: Vector2) -> Control:
	var holder: Control = Control.new()
	holder.name = "Holder"
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.position = at
	clip.add_child(holder)
	return holder


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


func _clear() -> void:
	_plan = view.plan if view != null else null
	paper = null
	stub = null
	if _holder != null:
		clip.remove_child(_holder)
		_holder.queue_free()
	_holder = null


static func _seg(t: float, from: float, to: float) -> float:
	if to <= from:
		return 1.0 if t >= from else 0.0
	return clampf((t - from) / (to - from), 0.0, 1.0)


static func _smooth(p: float) -> float:
	return p * p * (3.0 - 2.0 * p)
