class_name MachineFlyer
extends Control
## The picked prize flying home (#77, look F; build spec 4.2-4.3), on the machine's stage layer:
## from its ticket in the prize row (v0.50) to its slot in the cart drawer (an item, a coupon, an
## upgrade's up arrow; a 60 px arc, full size) or to its LOYALTY card box (the stamp ring; a 120 px
## arc, shrinking to 0.3), between view.plan's fly_out and land; none under reduced motion (the
## prize is home at once). It owns the landing's one-shot moments: at beat `land` the LOYALTY card's
## stamp slams down on the register's box (view.plain_landing is off), and the machine's sounds
## (MachineSounds), which it frames.

const SIZE := Vector2(96, 96)
## The arcs' heights and the loyalty stamp's end scale (look F).
const DRAWER_ARC := 60.0
const LOYALTY_ARC := 120.0
const LOYALTY_SCALE := 0.3
## The prize leaves its ticket from its art's middle.
const LEAVE_OFFSET := PrizeTicket.ART_RECT.position + PrizeArt.SPRITE_AT + Vector2(48, 48)
## The up arrow (an upgrade) is drawn at 6x, centred in the flyer.
const UP_ARROW := preload("res://art/icons/up_arrow.png")
const STAMP_RING := preload("res://art/icons/stamp_ring.png")
const ARROW_SCALE := 6.0

## The machine this part belongs to (setup(), build spec 4.2).
var view: RewardMachineView
## The machine's sounds (section 6), framed with the flyer.
var sounds: MachineSounds
## The landing flying, and its sprite.
var landing: MachineLanding
var sprite: TextureRect


func _init() -> void:
	name = "MachineFlyer"
	size = SIZE
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	pivot_offset = SIZE / 2.0
	visible = false
	sprite = UiKit.sprite(null)
	sprite.name = "Sprite"
	add_child(sprite)


## Hooks this part to the machine: RewardMachineView calls it once, when it builds the part
## (build spec 4.2). The flyer plays the landing itself: the machine's plain landing is off.
func setup(machine: RewardMachineView) -> void:
	view = machine
	view.plain_landing = false
	view.beat.connect(_on_beat)
	sounds = MachineSounds.new(machine)


## The flight at `t` on view.plan (shown only between fly_out and land, never under reduced
## motion), and the sounds the clock passed.
func frame(t: float) -> void:
	sounds.frame(t)
	var plan: MachinePlan = view.plan
	var flying: bool = (
		plan != null
		and plan.has_landing
		and view.landing != null
		and plan.landing != MachinePlan.Landing.BIN
		and not plan.reduced_motion
		and t >= plan.fly_out
		and t < plan.land
	)
	visible = flying
	if not flying:
		return
	if view.landing != landing:
		_show(view.landing, plan)
	var to_loyalty: bool = plan.landing == MachinePlan.Landing.REGISTER
	var p: float = _smooth(clampf((t - plan.fly_out) / (plan.land - plan.fly_out), 0.0, 1.0))
	var from: Vector2 = start_point()
	var to: Vector2 = end_point()
	var arc: float = LOYALTY_ARC if to_loyalty else DRAWER_ARC
	var at: Vector2 = from.lerp(to, p) - Vector2(0.0, sin(p * PI) * arc)
	position = (at - SIZE / 2.0).round()
	scale = Vector2.ONE * (lerpf(1.0, LOYALTY_SCALE, p) if to_loyalty else 1.0)


## Where the prize leaves, in stage coordinates: its ticket in the row, lifted.
func start_point() -> Vector2:
	var plan: MachinePlan = view.plan
	var visit: MachineVisit = _visit()
	var index: int = visit.picked if visit != null and visit.picked >= 0 else 0
	var count: int = plan.n_prizes if plan != null else 1
	var ticket: Rect2 = PrizeRow.card_rect(index, maxi(count, 1))
	var lift: Vector2 = Vector2(0, -PrizeTicket.PICK_LIFT)
	return ShiftStage.MACHINE_RECT.position + ticket.position + LEAVE_OFFSET + lift


## Where it lands, in stage coordinates: its cart drawer slot, or its LOYALTY card box (still
## empty during the flight: the card shows the stamp at the landing). With no such box (a full
## card, debug) it heads for the machine's top-left corner.
func end_point() -> Vector2:
	var plan: MachinePlan = view.plan
	if plan != null and plan.landing == MachinePlan.Landing.REGISTER:
		var box: Control = null
		if view.loyalty_card != null and view.landing != null:
			box = view.loyalty_card.any_box(view.landing.box_index)
		if box != null and is_instance_valid(view.stage):
			var centre: Vector2 = box.get_global_rect().get_center()
			return view.stage.get_global_transform().affine_inverse() * centre
		return Vector2(ShiftStage.MACHINE_RECT.position.x, ShiftStage.CART_DRAWER_TOP)
	return view.cart_drawer.dest()


func _show(shown: MachineLanding, plan: MachinePlan) -> void:
	landing = shown
	var texture: Texture2D = STAMP_RING
	var side: float = SIZE.x
	match plan.landing:
		MachinePlan.Landing.UPGRADE:
			texture = UP_ARROW
			side = UP_ARROW.get_size().x * ARROW_SCALE
		MachinePlan.Landing.NEW_CARD:
			var card: CardDefinition = shown.added.definition if shown.added != null else null
			texture = ArtStyle.item_sprite(card) if card != null else STAMP_RING
	sprite.texture = texture
	sprite.size = Vector2(side, side)
	sprite.position = (SIZE - sprite.size) / 2.0


## The landing's moment: the LOYALTY card's stamp on the register's box (not when the beat is
## fast-forwarded: the card shows its stamps once the top bar is refreshed). On the next frame:
## MachineFlow refreshes the top bar (the card's new box) at the same beat, after this part hears
## it, and the card's container lays the new box out (scale 1) at the end of this frame.
func _on_beat(beat_name: StringName, _t0: float) -> void:
	if beat_name != &"land" or view.skipping or view.landing == null:
		return
	var tree: SceneTree = get_tree() if is_inside_tree() else null
	if view.landing.prize.kind == MachinePrize.Kind.REGISTER and view.loyalty_card != null:
		if tree != null:
			var stamp: Callable = _stamp.bind(view.loyalty_card, view.landing.box_index)
			tree.process_frame.connect(stamp, CONNECT_ONE_SHOT)


static func _stamp(card: LoyaltyCard, box: int) -> void:
	if is_instance_valid(card):
		card.play_stamp(box)


func _visit() -> MachineVisit:
	if view.run == null or view.run.history.is_empty() or view.run.history[-1].visits.is_empty():
		return null
	return view.run.history[-1].visits[-1]


static func _smooth(p: float) -> float:
	return p * p * (3.0 - 2.0 * p)
