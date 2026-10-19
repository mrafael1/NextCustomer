class_name PlanningLayer
extends Control
## The planning effects' layer over the belt (#71, mock-up h1, H1_BUILD_SPEC.md sections 4 and 6):
## one per stage (ShiftStage.planning_layer), over the items and their tickets, under the top bar,
## the hand, the scan layers and the drag's ghost. For each filled slot of a PlanningModel it shows
## what the item receives and pays: its stickers (EffectSticker) stacked in apply order, the last
## applied at the bottom nearest the ticket, growing up over the item and the back wall (never
## over the ticket, never past the hung monitor's foot or the top bar's: the stack squeezes, then
## its earliest stickers fold into one "…+N"); the pay on its ticket (PayTag, over the ticket's top
## band, never over its text: PriceSticker.set_pay strikes the base and moves the aisle glyph); a
## denied item's rubber stamp (DenyStamp); and a 3-ring item's two sparkles. It boosts (halo and
## lift) and greys the items themselves (ItemView.set_boost, set_denied). A drag's ghost carries
## its slot's stack, stamp and pay tag as its own children, so they follow it. Under all of that,
## along the belt lip, the rail strips (RailStrip, section 5) say who gives what to whom: one per
## giver slot, in its lane (PlanningModel.assign_lanes); an overflowing strip (lane -1) is not
## drawn while calm. The strips hide during a drag (show_strips): the stickers and the QUOTA chip
## say what the drop does.
##
## Every anchor comes from the views' rects mapped into the layer, so a scaled 8- or 9-slot row
## places them by its scaled cells while the art never scales; CLOSED cells and empty slots are no
## view, so they get nothing. The layout follows the views (it is redone whenever a view moves
## relative to the layer, e.g. once the row's containers have sorted). apply_focus lights the
## hovered item's stickers and drains the rest, and dims the unrelated pay tags and stamps; it rings
## the hovered item's ticket (mustard pale, mustard, ink), gives its targets' tickets the "got" face
## and turns the related rail strips hot (section 5.3): the hovered giver's own strip is drawn
## again in lane 0's geometry on top of everything, with every target's gain, and the strips
## giving to it with its gain only (in lane 1 when they share a slot with it), while every other
## strip dims.
##
## Motion (none under `reduced_motion`, and nothing loops): the stickers new since the last
## slap_new slap on, a boosted item's halo steps out from the rings its card showed before, and
## each rebuild steps the strips' chevrons once. Decor only: it takes no clicks, and every number
## on it comes from the model (the score's steps and payouts).

## The bottom of every belt stack (the item's ground line, less ItemView.BOOST_LIFT and 2), and
## its left edge from the cell's (STACK_NUDGE more for every odd sticker: slapped, not aligned).
const STACK_BOTTOM_Y := 374.0
const STACK_LEFT := 72.0
const STACK_NUDGE := 4.0
## Each sticker overlaps the one above it by STACK_OVERLAP, squeezed in STACK_SQUEEZE steps up to
## STACK_OVERLAP_MAX when the stack is too tall for its ceiling.
const STACK_OVERLAP := 6.0
const STACK_OVERLAP_MAX := 14.0
const STACK_SQUEEZE := 2.0
## The frames' tilts by stack index (mod their count), in degrees.
const STICKER_TILTS: Array[float] = [-4.0, 3.0, -3.0, 4.0, -2.0]
## A stack's ceiling: MONITOR_GAP under the hung monitor's drawing when it overlaps its x-range,
## else TOP_BAR_GAP under the top bar's foot.
const MONITOR_GAP := 2.0
const TOP_BAR_GAP := 8.0
## Over a drag's ghost (its coordinates): the stack's left edge, its bottom GHOST_STACK_GAP over
## the sprite's, and the pay tag's place (the ghost has no ticket).
const GHOST_STACK_LEFT := 62.0
const GHOST_STACK_GAP := 2.0
const GHOST_PAY_AT := Vector2(60, 70)
## A denied item's stamp, from its sprite's top-left.
const STAMP_OFFSET := Vector2(2, 26)
## A 3-ring item's sparkles (5x5 art at 2x), from its sprite's top-left.
const SPARKLE_RINGS := 3
const SPARKLE_OFFSETS: Array[Vector2] = [Vector2(2, 14), Vector2(76, -24)]
const SPARKLE_SIZE := Vector2(10, 10)
## A pay tag's overhang past the ticket's right edge and above its top (section 4.5), none on a
## scaled row past the right edge; its bottom at most TAG_MAX_BOTTOM under the ticket's top (the
## summary starts 2 px lower), its left TAG_BASE_GAP after the base's text, and its right at most
## TAG_MAX_RIGHT past the ticket's (else the base shrinks: PriceSticker.BASE_STRUCK_SIZE).
const BURST_OVERHANG := Vector2(6, 6)
const WIDE_OVERHANG := Vector2(6, 10)
const TAG_OVERHANG := Vector2(4, 4)
const TAG_MAX_BOTTOM := 26.0
const TAG_BASE_GAP := 4.0
const TAG_MAX_RIGHT := 16.0
## The hovered item's ticket ring: bands RING_BAND wide round the ticket, inside out.
const RING_BAND := 2.0
const RING_COLOURS: Array[Color] = [Palette.MUSTARD_PALE, Palette.MUSTARD, Palette.INK]

const SPARKLE := preload("res://art/effects/sparkle.png")

## The fades', dims' and motion's tuning (PlanningEffects passes data/balance/planning.tres).
var tuning: PlanningTuning
## No slap, halo steps or chevron step (the player's reduced motion; PlanningEffects sets it).
var reduced_motion: bool = false
var _model: PlanningModel
## The view showing each slot (null: none), and the drag's ghost among them, or null.
var _items: Array[ItemView] = []
var _ghost: ItemView
## The views whose boost, grey and ticket were set (put back by the next show_model or clear).
var _painted: Array[ItemView] = []
var _stacks: Dictionary[int, Array] = {}
## Each stack's folded count (0: none folded), to rebuild a stack only when its fold changes.
var _folds: Dictionary[int, int] = {}
var _pays: Dictionary[int, PayTag] = {}
var _stamps: Dictionary[int, DenyStamp] = {}
var _sparkles: Dictionary[int, Array] = {}
var _strips: Array[RailStrip] = []
## Whether the rail strips show (off during a drag).
var _strips_shown: bool = true
## The z-ordered parts' parents (section 6), and the ghost's parts' parent (a child of the ghost).
var _gap_box: Control
var _lane_boxes: Array[Control] = []
var _pay_box: Control
var _stack_box: Control
var _stamp_box: Control
var _sparkle_box: Control
var _ghost_box: Control
var _ring_box: Control
var _hot_box: Control
## The views' transforms into the layer at the last layout.
var _layout_key: Array[Transform2D] = []
## The focus (apply_focus): which stickers stay lit, which slots stay undimmed, the hot strips
## (giver slot: the target whose gain shows, -1 for every target's) and the hovered item's slot.
var _lit: Callable = Callable()
var _related: PackedInt32Array = PackedInt32Array()
var _hot: Dictionary[int, int] = {}
var _focus_slot: int = -1
## The hot strips drawn on top and their lanes, the hovered ticket's ring and the "got" tickets.
var _hot_strips: Array[RailStrip] = []
var _hot_lanes: Array[int] = []
var _ring: RailStrip.Painter
var _got: Array[PriceSticker] = []
## The rings each card's item showed at the last show_model (a halo steps out from there).
var _rings_by_card: Dictionary[CardInstance, int] = {}


func _init() -> void:
	name = "PlanningLayer"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	size = ShiftStage.SIZE
	_gap_box = _box("RailGaps")
	_lane_boxes = [_box("Lane0"), _box("Lane1")]
	_pay_box = _box("Pays")
	_ring_box = _box("TicketRing")
	_stack_box = _box("Stacks")
	_stamp_box = _box("Stamps")
	_sparkle_box = _box("Sparkles")
	_hot_box = _box("HotStrips")


## Shows the model `shown` on `items` (the view showing each of its slots, null for none): the
## ghost of a drag among them (`ghost`) takes its slot's parts as its own children.
func show_model(shown: PlanningModel, items: Array[ItemView], ghost: ItemView = null) -> void:
	_reset()
	_model = shown
	_items = items.duplicate()
	_ghost = ghost if ghost != null and is_instance_valid(ghost) and items.has(ghost) else null
	if _ghost != null:
		_ghost_box = Control.new()
		_ghost_box.name = "PlanningParts"
		_ghost_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_ghost.add_child(_ghost_box)
	var shown_rings: Dictionary[CardInstance, int] = {}
	for slot: int in range(mini(shown.slots.size(), _items.size())):
		var item: ItemView = _item(slot)
		if item == null:
			continue
		var planning: PlanningSlot = shown.slots[slot]
		item.halo_step_s = _motion(tuning.halo_step_s if tuning != null else 0.0)
		item.halo_start = _rings_by_card.get(item.card, 0)
		item.boost_rings = planning.rings
		shown_rings[item.card] = planning.rings
		item.denied = planning.denied
		_painted.append(item)
		var on_ghost: bool = item == _ghost
		if planning.pay != PlanningModel.Pay.PLAIN:
			var tag: PayTag = PayTag.new(planning.pay, planning.pay_text, planning.glyph)
			tag.dimmed_alpha = tuning.dim_ticket_alpha if tuning != null else 1.0
			(_ghost_box if on_ghost else _pay_box).add_child(tag)
			_pays[slot] = tag
		if planning.has_stamp():
			var stamped: DenyStamp = DenyStamp.new(planning.stamp_amount, planning.stamp_caption)
			(_ghost_box if on_ghost else _stamp_box).add_child(stamped)
			_stamps[slot] = stamped
		if planning.rings >= SPARKLE_RINGS and not on_ghost:
			var made: Array[TextureRect] = []
			for _offset: Vector2 in SPARKLE_OFFSETS:
				var sparkle: TextureRect = UiKit.sprite(SPARKLE)
				sparkle.name = "Sparkle"
				sparkle.size = SPARKLE_SIZE
				_sparkle_box.add_child(sparkle)
				made.append(sparkle)
			_sparkles[slot] = made
	_rings_by_card = shown_rings
	_build_strips()
	_lay_out()
	_paint_focus(0.0)
	var frame_s: float = _motion(tuning.slap_frame_s if tuning != null else 0.0)
	for strip: RailStrip in _strips:
		strip.step_chevrons(frame_s <= 0.0, frame_s)


## Slaps on every sticker shown whose key (StickerSpec.key() and its item's card) is not in
## `known` (none under reduced motion), and returns every shown sticker's key: PlanningEffects
## passes the keys of the last refresh, so only new stickers slap.
func slap_new(known: Dictionary[String, bool]) -> Dictionary[String, bool]:
	var keys: Dictionary[String, bool] = {}
	var frame_s: float = _motion(tuning.slap_frame_s if tuning != null else 0.0)
	for slot: int in _stacks:
		var item: ItemView = _item(slot)
		if item == null:
			continue
		for sticker: EffectSticker in stack(slot):
			var key: String = "%s|%d" % [sticker.spec().key(), item.card.instance_id]
			keys[key] = true
			if not known.has(key):
				sticker.slap(frame_s <= 0.0, frame_s)
	return keys


## The hot rail strips drawn on top (apply_focus), the hovered giver's own first.
func hot_strips() -> Array[RailStrip]:
	var shown: Array[RailStrip] = []
	for index: int in range(_hot_strips.size() - 1, -1, -1):
		if is_instance_valid(_hot_strips[index]):
			shown.append(_hot_strips[index])
	return shown


## The hovered item's ticket ring (layer coordinates), or an empty rect.
func ticket_ring() -> Rect2:
	if _ring == null or not is_instance_valid(_ring):
		return Rect2()
	return Rect2(_ring.position, _ring.size)


## Shows the rail strips (`shown`) or hides them (during a drag).
func show_strips(shown: bool) -> void:
	_strips_shown = shown
	for box: Control in _strip_boxes():
		box.visible = shown


## The rail strips drawn (calm: lanes 0 and 1), in giver order.
func strips() -> Array[RailStrip]:
	var shown: Array[RailStrip] = []
	for strip: RailStrip in _strips:
		if is_instance_valid(strip):
			shown.append(strip)
	return shown


## Lights the stickers `lit_causes` (slot: int, spec: StickerSpec) -> bool says (an invalid
## Callable: every sticker, no focus) and drains the rest; dims the pay tags and drains the stamps
## of slots outside `related`, over `fade_s` seconds (0: at once). With a focus, the strips of
## `hot` (giver slot: the target whose gain shows, -1 for every target's) turn hot and every
## other strip dims, and the item at `focus_slot` (-1: none) gets its ticket ring and its targets'
## tickets the "got" face.
func apply_focus(
	lit_causes: Callable,
	related: PackedInt32Array,
	hot: Dictionary[int, int] = {},
	fade_s: float = 0.0,
	focus_slot: int = -1
) -> void:
	_lit = lit_causes
	_related = related
	_hot = hot.duplicate() if lit_causes.is_valid() else _no_hot()
	_focus_slot = focus_slot if lit_causes.is_valid() else -1
	_paint_focus(fade_s)
	_build_hot()
	if _model != null:
		_lay_out()
	_paint_strips(fade_s)
	for got: PriceSticker in _got:
		if is_instance_valid(got):
			got.set_got(false)
	_got.clear()
	if _model == null:
		return
	for spec: RailStripSpec in _model.strips:
		if spec.giver_slot == _focus_slot:
			for target: int in spec.targets:
				var item: ItemView = _item(target)
				if item != null and item != _ghost:
					item.sticker().set_got(true)
					_got.append(item.sticker())


## Takes every part off and puts every view's look and ticket back.
func clear() -> void:
	_reset()
	_model = null
	_items.clear()
	_rings_by_card.clear()
	show_strips(true)


## The stickers on `slot`, top (first applied, or the fold) to bottom.
func stack(slot: int) -> Array[EffectSticker]:
	var shown: Array[EffectSticker] = []
	for sticker: EffectSticker in _stacks.get(slot, []):
		if is_instance_valid(sticker):
			shown.append(sticker)
	return shown


## The pay tag on `slot`'s ticket, or null.
func pay_tag(slot: int) -> PayTag:
	return _pays.get(slot, null)


## The stamp over `slot`'s item, or null.
func stamp(slot: int) -> DenyStamp:
	return _stamps.get(slot, null)


## The sparkles by `slot`'s item (none unless it has SPARKLE_RINGS rings).
func sparkles(slot: int) -> Array[TextureRect]:
	var shown: Array[TextureRect] = []
	for sparkle: TextureRect in _sparkles.get(slot, []):
		shown.append(sparkle)
	return shown


## Every part shown: rail strips, their gap fills and gain badges, stickers, pay tags, stamps and
## sparkles (the ghost's too).
func parts() -> Array[Control]:
	var shown: Array[Control] = []
	var boxes: Array[Control] = _strip_boxes()
	boxes.append_array([_pay_box, _ring_box, _stack_box, _stamp_box, _sparkle_box, _hot_box])
	boxes.append(_ghost_box)
	for box: Control in boxes:
		if box != null and is_instance_valid(box) and box.visible:
			for child: Node in box.get_children():
				var part: Control = child as Control
				if part.visible and not part.is_queued_for_deletion():
					shown.append(part)
	return shown


## The model shown, or null.
func model() -> PlanningModel:
	return _model


## The ceiling of a stack spanning `stack_rect` (layer coordinates; only its x-range counts):
## MONITOR_GAP under the hung monitor's drawing when it overlaps the monitor's x-range, else
## TOP_BAR_GAP under the top bar's foot.
static func stack_ceiling(stack_rect: Rect2) -> float:
	var monitor: Rect2 = MonitorView.DRAWN_RECT
	if stack_rect.position.x < monitor.end.x and stack_rect.end.x > monitor.position.x:
		return monitor.end.y + MONITOR_GAP
	return ShiftStage.TOP_BAR_BOTTOM + TOP_BAR_GAP


## What a stack of `specs` shows under a `ceiling`, its bottom at `bottom`: [shown specs,
## overlap]. It squeezes first, then folds the earliest stickers into one MORE sticker.
static func fit_stack(specs: Array[StickerSpec], bottom: float, ceiling: float) -> Array:
	var room: float = bottom - ceiling
	var overlap: float = STACK_OVERLAP
	while _height(specs, overlap) > room and overlap < STACK_OVERLAP_MAX:
		overlap += STACK_SQUEEZE
	if _height(specs, overlap) <= room:
		return [specs, overlap]
	for kept: int in range(specs.size() - 1, -1, -1):
		var shown: Array[StickerSpec] = [StickerSpec.folded(specs.size() - kept)]
		shown.append_array(specs.slice(specs.size() - kept))
		if _height(shown, overlap) <= room or kept == 0:
			return [shown, overlap]
	return [specs, overlap]


func _process(_delta: float) -> void:
	if _model != null and _key() != _layout_key:
		_lay_out()


## Places every part by the views as they stand now.
func _lay_out() -> void:
	_layout_key = _key()
	for slot: int in range(mini(_model.slots.size(), _items.size())):
		var item: ItemView = _item(slot)
		if item == null:
			continue
		var planning: PlanningSlot = _model.slots[slot]
		if item == _ghost:
			_lay_out_ghost(slot, planning, item)
		else:
			_lay_out_belt(slot, planning, item)
	for strip: RailStrip in strips():
		var lane: int = strip.spec().lane
		strip.lay_out(_anchors(strip.spec()), RailStrip.LANE_RECTS[lane], lane == 0)
	_lay_out_focus()
	_hide_hot_calm()


## Places the hot strips in their lanes and the hovered item's ticket ring.
func _lay_out_focus() -> void:
	for index: int in range(_hot_strips.size()):
		var strip: RailStrip = _hot_strips[index]
		var lane: int = _hot_lanes[index]
		strip.lay_out(_anchors(strip.spec()), RailStrip.LANE_RECTS[lane], lane == 0)
	# Each gain clear of the other hot strip's gains (the hovered giver's own placed first).
	var taken: Array[Rect2] = []
	for strip: RailStrip in hot_strips():
		taken.append_array(strip.place_gains(taken))
	var item: ItemView = _item(_focus_slot)
	if _ring == null or item == null or item == _ghost:
		return
	var to_ticket: Transform2D = _to_layer(item) * Transform2D(0.0, item.sticker().position)
	var ticket: Rect2 = to_ticket * Rect2(Vector2.ZERO, PriceSticker.SIZE)
	var outer: Rect2 = ticket.grow(RING_BAND * RING_COLOURS.size())
	_ring.position = outer.position
	_ring.size = outer.size
	var rects: Array[Rect2] = []
	var colours: Array[Color] = []
	for band: int in range(RING_COLOURS.size()):
		var edge: Rect2 = Rect2(ticket.position - outer.position, ticket.size).grow(
			RING_BAND * (band + 1)
		)
		for side: Rect2 in _frame(edge, RING_BAND):
			rects.append(side)
			colours.append(RING_COLOURS[band])
	_ring.paint(rects, colours)


## The hot strips (apply_focus): each one's calm strip hidden, a hot copy drawn on top in its lane
## (PlanningModel.hot_lanes: the hovered giver's own in lane 0, drawn last, and at most one strip
## giving to it in the other lane; the rest stay calm and dim), all their gains over every hot
## strip; and the hovered item's ticket ring.
func _build_hot() -> void:
	for child: Node in _hot_box.get_children() + _ring_box.get_children():
		child.get_parent().remove_child(child)
		child.queue_free()
	_hot_strips.clear()
	_hot_lanes.clear()
	_ring = null
	if _model == null:
		return
	var drawable: Array[RailStripSpec] = []
	for spec: RailStripSpec in _model.strips:
		if _hot.has(spec.giver_slot) and not _anchors(spec).is_empty():
			drawable.append(spec)
	var lane_of: Dictionary[int, int] = PlanningModel.hot_lanes(drawable, _hot)
	var placed: Array[RailStripSpec] = []
	var lanes: Array[int] = []
	for spec: RailStripSpec in drawable:
		if lane_of.has(spec.giver_slot):
			placed.append(spec)
			lanes.append(lane_of[spec.giver_slot])
	# Lane 1 first, so lane 0's (the hovered giver's own last) draw over them; every gain after
	# every hot strip, so no strip's body or ring covers another's gain.
	var gains: Array[Control] = []
	for pass_lane: int in [1, 0]:
		for index: int in range(placed.size() - 1, -1, -1):
			if lanes[index] != pass_lane:
				continue
			var strip: RailStrip = RailStrip.new(placed[index])
			strip.set_hot(true, _hot[placed[index].giver_slot])
			if pass_lane == 0:
				for fill: Control in strip.fills():
					_hot_box.add_child(fill)
			_hot_box.add_child(strip)
			gains.append_array(strip.gains())
			_hot_strips.append(strip)
			_hot_lanes.append(pass_lane)
	for gain: Control in gains:
		_hot_box.add_child(gain)
	var item: ItemView = _item(_focus_slot)
	if item != null and item != _ghost:
		_ring = RailStrip.Painter.new()
		_ring.name = "TicketRing"
		_ring_box.add_child(_ring)


## Hides each hot strip's calm strip and lit gaps (its hot copy is drawn on top) and shows the
## others' (their gaps as their layout left them).
func _hide_hot_calm() -> void:
	for strip: RailStrip in strips():
		var hot: bool = _has_hot(strip.spec().giver_slot)
		strip.visible = not hot
		if hot:
			for fill: Control in strip.fills():
				fill.visible = false


## Dims every calm strip but the hot ones while something is focused, over `fade` seconds.
func _paint_strips(fade: float) -> void:
	var focused: bool = _lit.is_valid()
	for strip: RailStrip in strips():
		strip.set_dimmed(focused and not _has_hot(strip.spec().giver_slot), fade)


## Whether a hot copy of `giver`'s strip is drawn.
func _has_hot(giver: int) -> bool:
	for strip: RailStrip in _hot_strips:
		if is_instance_valid(strip) and strip.spec().giver_slot == giver:
			return true
	return false


## The four sides (`width` wide) of a frame just inside `rect`.
static func _frame(rect: Rect2, width: float) -> Array[Rect2]:
	return [
		Rect2(rect.position, Vector2(rect.size.x, width)),
		Rect2(rect.position.x, rect.end.y - width, rect.size.x, width),
		Rect2(rect.position.x, rect.position.y + width, width, rect.size.y - 2.0 * width),
		Rect2(rect.end.x - width, rect.position.y + width, width, rect.size.y - 2.0 * width),
	]


static func _no_hot() -> Dictionary[int, int]:
	var none: Dictionary[int, int] = {}
	return none


## `seconds` of motion: none under reduced motion.
func _motion(seconds: float) -> float:
	return 0.0 if reduced_motion else seconds


func _lay_out_belt(slot: int, planning: PlanningSlot, item: ItemView) -> void:
	var to_layer: Transform2D = _to_layer(item)
	var scale_x: float = to_layer.get_scale().x
	var sprite: Rect2 = _sprite_rect(item, to_layer)
	var left: float = (to_layer * Vector2(STACK_LEFT, 0)).x
	_lay_out_stack(slot, planning, Vector2(left, STACK_BOTTOM_Y), Vector2.ZERO, _stack_box)
	var ticket_xf: Transform2D = to_layer * Transform2D(0.0, item.sticker().position)
	var ticket: Rect2 = ticket_xf * Rect2(Vector2.ZERO, PriceSticker.SIZE)
	var tag: PayTag = _pays.get(slot, null)
	var tag_rect: Rect2 = Rect2()
	if tag != null:
		tag_rect = _tag_rect(tag, ticket, item.sticker(), scale_x)
		tag.position = tag_rect.position
	item.sticker().set_pay(planning.struck, ticket_xf.affine_inverse() * tag_rect)
	var stamped: DenyStamp = _stamps.get(slot, null)
	if stamped != null:
		stamped.position = (sprite.position + STAMP_OFFSET * scale_x).snappedf(ArtStyle.ART_SCALE)
	var raised: Vector2 = Vector2(0, -ItemView.BOOST_LIFT * scale_x)
	var made: Array = _sparkles.get(slot, [])
	for index: int in range(made.size()):
		var at: Vector2 = sprite.position + raised + SPARKLE_OFFSETS[index] * scale_x
		(made[index] as Control).position = at.snappedf(ArtStyle.ART_SCALE)


## The ghost's parts in its own coordinates: the stack over its sprite's right side, its ceiling
## from where the ghost stands in the layer now, the stamp on its sprite and the pay tag pinned.
func _lay_out_ghost(slot: int, planning: PlanningSlot, ghost: ItemView) -> void:
	var origin: Vector2 = _to_layer(ghost).origin
	var sprite: Rect2 = _sprite_rect(ghost, Transform2D.IDENTITY)
	var anchor: Vector2 = Vector2(GHOST_STACK_LEFT, sprite.end.y - GHOST_STACK_GAP)
	_lay_out_stack(slot, planning, origin + anchor, origin, _ghost_box)
	var tag: PayTag = _pays.get(slot, null)
	if tag != null:
		tag.position = GHOST_PAY_AT
	var stamped: DenyStamp = _stamps.get(slot, null)
	if stamped != null:
		stamped.position = sprite.position + STAMP_OFFSET


## `slot`'s stack with its bottom-left at `anchor` (layer coordinates), as children of `parent`
## whose origin is at `origin` in the layer: fitted under its ceiling, rebuilt when its fold
## changes, each sticker placed bottom up.
func _lay_out_stack(
	slot: int, planning: PlanningSlot, anchor: Vector2, origin: Vector2, parent: Control
) -> void:
	if planning.stickers.is_empty():
		return
	var span: Rect2 = _span(planning.stickers, anchor.x)
	var fitted: Array = fit_stack(planning.stickers, anchor.y, stack_ceiling(span))
	var shown: Array[StickerSpec] = []
	shown.assign(fitted[0])
	var overlap: float = fitted[1]
	var folded: int = 0
	if _folded(shown):
		folded = planning.stickers.size() - (shown.size() - 1)
	if not _stacks.has(slot) or _folds.get(slot, -1) != folded:
		_build_stack(slot, shown, parent)
		_folds[slot] = folded
	var stickers: Array = _stacks[slot]
	var y: float = anchor.y
	for index: int in range(stickers.size() - 1, -1, -1):
		var sticker: EffectSticker = stickers[index]
		y -= sticker.size.y
		var x: float = anchor.x + (STACK_NUDGE if index % 2 == 1 else 0.0)
		sticker.position = (Vector2(x, y) - origin).snappedf(ArtStyle.ART_SCALE)
		y += overlap


func _build_stack(slot: int, shown: Array[StickerSpec], parent: Control) -> void:
	for old: EffectSticker in stack(slot):
		old.get_parent().remove_child(old)
		old.queue_free()
	var made: Array[EffectSticker] = []
	for index: int in range(shown.size()):
		var sticker: EffectSticker = EffectSticker.new(
			shown[index], STICKER_TILTS[index % STICKER_TILTS.size()]
		)
		parent.add_child(sticker)
		made.append(sticker)
	_stacks[slot] = made
	_paint_focus(0.0)


## The pay tag's rect for `ticket` (layer coordinates) of `sticker`, at the row's `scale_x`:
## overhanging the ticket's top right (not past its right edge on a scaled row), after the base's
## text (shrunk if the tag would reach past TAG_MAX_RIGHT), its bottom over the summary.
func _tag_rect(tag: PayTag, ticket: Rect2, sticker: PriceSticker, scale_x: float) -> Rect2:
	var overhang: Vector2 = TAG_OVERHANG
	if tag.pay == PlanningModel.Pay.BOOSTED:
		var wide: bool = tag.size.x > PayTag.BURST_SIZE.x
		overhang = WIDE_OVERHANG if wide else BURST_OVERHANG
	if scale_x < 1.0:
		overhang.x = 0.0
	var natural_left: float = ticket.end.x + overhang.x - tag.size.x
	var after_base: float = ticket.position.x + TAG_BASE_GAP
	var left: float = maxf(
		natural_left, after_base + sticker.base_text_end(PriceSticker.BASE_SIZE) * scale_x
	)
	if left + tag.size.x > ticket.end.x + TAG_MAX_RIGHT:
		var small_end: float = sticker.base_text_end(PriceSticker.BASE_STRUCK_SIZE) * scale_x
		left = maxf(natural_left, after_base + small_end)
	var top: float = minf(
		ticket.position.y - overhang.y, ticket.position.y + TAG_MAX_BOTTOM * scale_x - tag.size.y
	)
	return Rect2(Vector2(left, top).snappedf(ArtStyle.ART_SCALE), tag.size)


## The focus's look on every part (apply_focus); a denied item's stickers stay drained.
func _paint_focus(fade: float) -> void:
	var focused: bool = _lit.is_valid()
	for slot: int in _stacks:
		var stamped: bool = _stamps.has(slot)
		for sticker: EffectSticker in stack(slot):
			var lit: bool = not focused or bool(_lit.call(slot, sticker.spec()))
			sticker.set_drained(stamped or not lit)
	for slot: int in _pays:
		_pays[slot].set_dimmed(focused and not _related.has(slot), fade)
	for slot: int in _stamps:
		_stamps[slot].set_drained(focused and not _related.has(slot))


## Takes every part off, and every painted view's boost, grey and ticket pay.
func _reset() -> void:
	for item: ItemView in _painted:
		if is_instance_valid(item):
			item.boost_rings = 0
			item.denied = false
			item.sticker().set_pay(false, Rect2())
	_painted.clear()
	for got: PriceSticker in _got:
		if is_instance_valid(got):
			got.set_got(false)
	_got.clear()
	var boxes: Array[Control] = _strip_boxes()
	boxes.append_array([_pay_box, _ring_box, _stack_box, _stamp_box, _sparkle_box, _hot_box])
	for box: Control in boxes:
		for child: Node in box.get_children():
			box.remove_child(child)
			child.queue_free()
	_strips.clear()
	_hot_strips.clear()
	_hot_lanes.clear()
	_ring = null
	if _ghost_box != null and is_instance_valid(_ghost_box):
		_ghost_box.get_parent().remove_child(_ghost_box)
		_ghost_box.queue_free()
	_ghost_box = null
	_ghost = null
	_stacks.clear()
	_folds.clear()
	_pays.clear()
	_stamps.clear()
	_sparkles.clear()
	_layout_key.clear()
	_lit = Callable()
	_related = PackedInt32Array()
	_hot = _no_hot()
	_focus_slot = -1


## A calm rail strip for every strip of the model in a lane whose giver and targets are all shown
## on the belt (none touches the ghost: the strips hide during a drag anyway). Lane 0's strips
## light the rail's gaps.
func _build_strips() -> void:
	for spec: RailStripSpec in _model.strips:
		if spec.lane < 0 or _anchors(spec).is_empty():
			continue
		var strip: RailStrip = RailStrip.new(spec)
		strip.dimmed_alpha = tuning.dim_strip_alpha if tuning != null else 1.0
		_lane_boxes[spec.lane].add_child(strip)
		if spec.lane == 0:
			for fill: Control in strip.fills():
				_gap_box.add_child(fill)
		_strips.append(strip)
	show_strips(_strips_shown)


## The tickets' rects (layer coordinates) of every slot `spec` spans (its giver, its targets and
## the items it passes over, whose gaps it lights too), or empty when its giver or a target has no
## belt view (none, freed, or the ghost).
func _anchors(spec: RailStripSpec) -> Dictionary[int, Rect2]:
	var anchors: Dictionary[int, Rect2] = {}
	for slot: int in range(spec.lo(), spec.hi() + 1):
		var item: ItemView = _item(slot)
		var anchored: bool = slot == spec.giver_slot or spec.targets.has(slot)
		if item == null or item == _ghost:
			if anchored:
				return {}
			continue
		var to_ticket: Transform2D = _to_layer(item) * Transform2D(0.0, item.sticker().position)
		anchors[slot] = to_ticket * Rect2(Vector2.ZERO, PriceSticker.SIZE)
	return anchors


func _strip_boxes() -> Array[Control]:
	var boxes: Array[Control] = [_gap_box]
	boxes.append_array(_lane_boxes)
	return boxes


## The view showing `slot`, or null (none, or freed).
func _item(slot: int) -> ItemView:
	if slot < 0 or slot >= _items.size():
		return null
	var item: ItemView = _items[slot]
	return item if item != null and is_instance_valid(item) else null


## `item`'s coordinates in the layer's.
func _to_layer(item: Control) -> Transform2D:
	return get_global_transform().affine_inverse() * item.get_global_transform()


## `item`'s sprite at rest (no lift or boost) through `to_layer` (`item`'s coordinates into the
## ones wanted).
static func _sprite_rect(item: ItemView, to_layer: Transform2D) -> Rect2:
	var centre: Vector2 = to_layer * (item.get_global_transform().affine_inverse() * item.center())
	var shown: Vector2 = ItemView.SPRITE_SIZE * to_layer.get_scale()
	return Rect2(centre - shown / 2.0, shown)


## Every shown view's transform into the layer (freed views as the identity).
func _key() -> Array[Transform2D]:
	var key: Array[Transform2D] = []
	for slot: int in range(_items.size()):
		var item: ItemView = _item(slot)
		key.append(_to_layer(item) if item != null else Transform2D.IDENTITY)
	return key


func _box(box_name: String) -> Control:
	var box: Control = Control.new()
	box.name = box_name
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(box)
	return box


## The x-range a stack of `specs` with its left at `left` spans, badges and nudges included.
static func _span(specs: Array[StickerSpec], left: float) -> Rect2:
	var start: float = left
	var end: float = left
	for index: int in range(specs.size()):
		var x: float = left + (STACK_NUDGE if index % 2 == 1 else 0.0)
		start = minf(start, x - EffectSticker.badge_overhang(specs[index]))
		end = maxf(end, x + EffectSticker.size_for(specs[index]).x)
	return Rect2(start, 0.0, end - start, 0.0)


## A stack's height with each sticker overlapping the one above by `overlap`.
static func _height(specs: Array[StickerSpec], overlap: float) -> float:
	var height: float = 0.0
	for spec: StickerSpec in specs:
		height += EffectSticker.size_for(spec).y
	return height - overlap * maxi(specs.size() - 1, 0)


static func _folded(shown: Array[StickerSpec]) -> bool:
	return not shown.is_empty() and shown[0].kind == StickerSpec.Kind.MORE
