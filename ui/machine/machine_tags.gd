class_name MachineTags
extends Control
## The receipt's prize tags coming off at the machine (v1.40, the user's verdict of 2026-11-18:
## "I really like the machine animation showing silver or gold use"; mock-up
## docs/art/mockups/medal_prizes.html, its machine scene). The receipt arrives over the slot with
## the tags its checkout won stapled to its foot (ReceiptPrizeTags), and before it is fed each
## comes off in turn (MachinePlan.tag_flight; the TICKET visit only):
## - the +1 DRAW tag pops off the paper, grows so its words read, holds a beat, then spins down
##   onto the reader plate, where it becomes the extra draw lamp (SlotPlate: the plate shows one
##   lamp fewer until it lands, MachinePlan.lamps_shown), with a burst of sparks;
## - the PREMIUM tag pops off the same way, then flies up into the sign, growing, and slams where
##   the PREMIUM! stamp lands (MachineHead): the machine turns PREMIUM from the slam (MachineLook),
##   the stage jolts (MachineLayers) and gold sparks fly along the sign.
## The tag leaves the paper as its flight starts (ReceiptPrizeTags.take). Reduced motion: no
## flight (the tags are off the paper at the receipt's arrival, the lamp and the PREMIUM look
## there at once). A resumed or fast-forwarded visit shows nothing. On the machine's stage layer
## (stage coordinates, over everything). Display only: frame(t) reads the plan and `t`.

## A flight's shares: the pop off the paper (.. POP), the hold (.. HOLD), then the flight.
const POP := 0.18
const HOLD := 0.5
## The tag's size while it holds (of its size on the shift's receipt), and how far from its place
## on the paper it holds, [the +1 DRAW, the PREMIUM] (stage px).
const BIG := 1.5
const HOLD_OFFSETS: Array[Vector2] = [Vector2(-44, -46), Vector2(8, -50)]
## The hold's bob (px, turns a second) and the flights' arc lifts (stage px, at their middle).
const BOB_PX := 2.0
const BOB_HZ := 2.0
const ARC_LIFTS: Array[float] = [26.0, 54.0]
## The PREMIUM tag lands as wide as the stamp, between these of its own size, tilted as it.
const SLAM_SCALES := Vector2(1.5, 3.0)
## The sparks at a landing: how many, how long (s), how far (stage px), their size (px).
const SPARKS: Array[int] = [10, 18]
const SPARK_SECONDS: Array[float] = [0.35, 0.5]
const SPARK_REACH: Array[float] = [34.0, 120.0]
const SPARK_SIZE := 4.0
const SPARK_COLOURS: Array[Array] = [
	[Palette.PAPER, Palette.STEEL_LIGHT, Palette.TEAL_LIGHT],
	[Palette.PAPER, Palette.GOLD, Palette.MUSTARD],
]

## The machine this part belongs to (setup(), build spec 4.2).
var view: RewardMachineView
var _t: float = 0.0
## Each tag in flight now, [the +1 DRAW, the PREMIUM]: whether it shows, its centre (stage px),
## its scale (of its size on the shift's receipt) and its turn (radians).
var _shown: Array[bool] = [false, false]
var _centres: Array[Vector2] = [Vector2.ZERO, Vector2.ZERO]
var _scales: Array[float] = [1.0, 1.0]
var _turns: Array[float] = [0.0, 0.0]
## Where each tag landed (stage px), for its sparks.
var _landings: Array[Vector2] = [Vector2.ZERO, Vector2.ZERO]


func _init() -> void:
	name = "MachineTags"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false


## Hooks this part to the machine: RewardMachineView calls it once, when it builds the part
## (build spec 4.2).
func setup(machine: RewardMachineView) -> void:
	view = machine


## The tags `run`'s waiting visit's receipt carries, set on its `plan` (the TICKET visit only):
## the +1 DRAW when its checkout won the SILVER medal (its OVERTIME draw is queued), the PREMIUM
## when the GOLD medal made the visit PREMIUM.
static func plan_tags(plan: MachinePlan, run: RunState) -> void:
	if plan.kind != MachineVisit.Kind.TICKET or plan.draw_index > 0 or run.history.is_empty():
		return
	var record: ShiftRecord = run.history[-1]
	var queued: bool = run.machine.pending_kinds().has(MachineVisit.Kind.OVERTIME)
	plan.tag_draw = record.overtime_ticket and queued
	plan.tag_premium = OvertimeTickets.is_premium_visit(run)


## The tags at `t` on view.plan.
func frame(t: float) -> void:
	var plan: MachinePlan = view.plan if view != null else null
	var live: bool = plan != null and not plan.resumed and not view.skipping
	live = live and (plan.tag_draw_at >= 0.0 or plan.tag_premium_at >= 0.0)
	visible = live
	if not live:
		return
	_t = t
	for index: int in range(2):
		_frame_tag(plan, index, t)
	queue_redraw()


## Whether medal `gold`'s tag is in flight now (off the paper, not landed yet).
func is_flying(gold: bool) -> bool:
	return visible and _shown[1 if gold else 0]


## Medal `gold`'s flying tag's rect now (stage px; empty when it isn't flying).
func tag_rect(gold: bool) -> Rect2:
	var index: int = 1 if gold else 0
	if not is_flying(gold):
		return Rect2()
	var size_now: Vector2 = PrizeTagArt.size_of(gold, ReceiptPrizeTags.CELL) * _scales[index]
	return Rect2(_centres[index] - size_now / 2.0, size_now)


## Where medal `gold`'s tag lands (stage px): the +1 DRAW's lamp on the reader plate (the
## leftmost, once it has joined), the PREMIUM's stamp on the sign.
func landing_rect(gold: bool) -> Rect2:
	if gold:
		return _to_stage(view.head.get_global_transform() * view.head.stamp_rect())
	var plate: SlotPlate = view.slot_plate
	var count: int = view.plan.draws if view.plan != null else 1
	return _to_stage(plate.get_global_transform() * plate.lamp_rect(0, count))


func _frame_tag(plan: MachinePlan, index: int, t: float) -> void:
	var gold: bool = index == 1
	var p: float = plan.tag_flight(gold, t)
	_shown[index] = false
	if p < 0.0:  # No such tag (NOT_SET), or still on the paper.
		return
	var paper: ReceiptView = view.receipt_feed.paper
	if is_instance_valid(paper) and paper.gold.tags != null:
		paper.gold.tags.take(gold)
	var to: Rect2 = landing_rect(gold)
	_landings[index] = to.get_center()
	if p >= 1.0 or plan.reduced_motion:
		return
	var from: Rect2 = _from_rect(gold)
	var natural: Vector2 = PrizeTagArt.size_of(gold, ReceiptPrizeTags.CELL)
	var small: float = from.size.x / natural.x
	var hold: Vector2 = from.get_center() + HOLD_OFFSETS[index]
	_shown[index] = true
	_turns[index] = 0.0
	if p < POP:
		var k: float = MachineArt.ease_out(p / POP)
		_centres[index] = from.get_center().lerp(hold, k)
		_scales[index] = lerpf(small, BIG, MachineArt.ease_back(p / POP))
		return
	if p < HOLD:
		_centres[index] = hold + Vector2(0.0, roundf(sin(t * TAU * BOB_HZ) * BOB_PX))
		_scales[index] = BIG
		return
	var e: float = pow((p - HOLD) / (1.0 - HOLD), 2.0)
	var centre: Vector2 = hold.lerp(to.get_center(), e)
	centre.y -= ARC_LIFTS[index] * sin(PI * e)
	_centres[index] = centre
	if gold:
		var slam: float = clampf(to.size.x / natural.x, SLAM_SCALES.x, SLAM_SCALES.y)
		_scales[index] = lerpf(BIG, slam, e)
		_turns[index] = deg_to_rad(MachineHead.BONUS_TILT) * e
	else:
		_scales[index] = lerpf(BIG, to.size.y / natural.y, e)
		_turns[index] = -TAU * e


## Where medal `gold`'s tag sits on the fed paper (stage px): its place on the paper's foot, or
## over the slot's mouth when the paper has no such tag (a stand-in).
func _from_rect(gold: bool) -> Rect2:
	var paper: ReceiptView = view.receipt_feed.paper
	if is_instance_valid(paper) and paper.gold.tags != null:
		var on_paper: Rect2 = paper.gold.tags.tag_rect(gold)
		if on_paper.has_area() and paper.is_inside_tree():
			return _to_stage(paper.get_global_transform() * on_paper)
	var mouth: Rect2 = _to_stage(view.slot_plate.mouth_global_rect())
	var size_now: Vector2 = PrizeTagArt.size_of(gold, ReceiptPrizeTags.CELL) * 0.4
	return Rect2(mouth.get_center() - Vector2(size_now.x / 2.0, size_now.y), size_now)


## A screen rect in this part's coordinates (the stage's).
func _to_stage(rect: Rect2) -> Rect2:
	if not is_inside_tree():
		return rect
	return get_global_transform().affine_inverse() * rect


func _draw() -> void:
	var plan: MachinePlan = view.plan if view != null else null
	if plan == null:
		return
	for index: int in range(2):
		_draw_sparks(plan, index)
	for index: int in range(2):
		if not _shown[index]:
			continue
		var gold: bool = index == 1
		var cell: float = ReceiptPrizeTags.CELL
		draw_set_transform(_centres[index], _turns[index], Vector2.ONE * _scales[index])
		PrizeTagArt.draw(self, -PrizeTagArt.size_of(gold, cell) / 2.0, gold, cell)
	draw_set_transform(Vector2.ZERO)


## Tag `index`'s landing sparks: squares flying out of its landing place, slowing and thinning
## out over SPARK_SECONDS (the PREMIUM's wider, along the sign).
func _draw_sparks(plan: MachinePlan, index: int) -> void:
	var landed: float = plan.tag_premium_end if index == 1 else plan.tag_draw_end
	if landed < 0.0 or plan.reduced_motion:
		return
	var k: float = (_t - landed) / SPARK_SECONDS[index]
	if k < 0.0 or k >= 1.0:
		return
	var out: float = MachineArt.ease_out(k)
	var colours: Array = SPARK_COLOURS[index]
	for spark: int in range(SPARKS[index]):
		if k > 0.6 and spark % 2 == 0:
			continue
		var angle: float = TAU * spark / SPARKS[index] + 0.4 * (spark % 2)
		var reach: float = SPARK_REACH[index] * (0.55 + 0.45 * ((spark * 37) % 10) / 10.0)
		var stretch: Vector2 = Vector2(2.2, 0.7) if index == 1 else Vector2.ONE
		var at: Vector2 = _landings[index] + Vector2.from_angle(angle) * reach * out * stretch
		var side: float = SPARK_SIZE if spark % 3 == 0 else SPARK_SIZE / 2.0
		var colour: Color = colours[spark % colours.size()]
		draw_rect(Rect2((at - Vector2.ONE * side / 2.0).round(), Vector2.ONE * side), colour)
