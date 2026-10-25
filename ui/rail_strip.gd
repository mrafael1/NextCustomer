class_name RailStrip
extends Control
## One rail strip along the belt lip (#71, mock-up h1, H1_BUILD_SPEC.md section 5): who gives what
## to whom. A brass strip runs from a plug over the giver's ticket (a stem drops onto it) to a
## pointed cap past its last target: the giver's name printed on an ink plate at its start,
## chevrons pointing from the giver to the targets, and at each target a notch dropping onto its
## ticket. The factor itself ("×3") is only the sticker on the target, never a badge on the strip
## (since the h1 build's play test). On lane 0 (the lip) it lights the rail's gaps between the
## tickets it spans; on lane 1 (the top face's front edge, for a strip sharing a slot with a lane-0
## one) its targets are the tickets' right halves, each with a plain ink drop instead of a notch,
## so they never meet lane 0's, and its stems and drops cross lane 0 on top. A backward strip
## (every target before the giver) keeps its plug at the giver and points left, its cap at the
## leftmost target.
##
## PlanningLayer owns it: the strip's body parts are its own children, while its gap fills and
## gain badges (fills(), gains()) go in the layer's own z-ordered boxes (section 6), all in layer
## coordinates. lay_out places everything from the tickets' rects, so a scaled 8-slot row
## moves the anchors (the offsets scale) while the art never scales. Calm strips are brass and
## nothing loops. Hot (set_hot: its giver or a target hovered, section 5.3) it turns bright gold
## in a pale ring and a gain badge ("+€14", the target's summed gain) stands on each target (or
## only the hovered target's); dimmed (set_dimmed) it fades back. step_chevrons steps the chevrons
## one texel toward the targets, once. Decor only: it takes no clicks, and every gain on it is a
## step's (RailStripSpec).

## The lanes' bodies (stage px): lane 0 is the belt lip, lane 1 the top face's front edge under
## the items' contact shadows.
const LANE_RECTS: Array[Rect2] = [Rect2(348, 400, 918, 14), Rect2(348, 386, 918, 14)]
## Where every gain badge, notch, plate, plug and cap lies (from the lane-1 gains' tops down to the
## natural row's tickets' tops). The stems and drops reach on down to their tickets, which stand
## lower on a scaled row.
const LIP_BAND := Rect2(348, 380, 918, 44)
## The plug's x from the giver's ticket, and each lane's target centre (its notch or drop, and its
## gain badge) from a target's ticket (both times the row's scale, on the 2 px grid).
const PLUG_OFFSET := 6.0
const TARGET_OFFSETS: Array[float] = [26.0, 84.0]
## The plug (an ink block from (x0, top)) and its lit pip.
const PLUG := Rect2(-2, -2, 12, 18)
const PIP := Rect2(2, 3, 4, 8)
## The stem down to the giver's ticket: ink STEM_WIDTH wide from STEM_LEFT past x0 with a
## STEM_FILL fill centre, from STEM_GAP under the body.
const STEM_LEFT := 1.0
const STEM_WIDTH := 6.0
const STEM_FILL := 2.0
const STEM_GAP := 2.0
## The name plate: the name from PLATE_TEXT past x0, the plate PLATE_PADDING past the text, then a
## DIVIDER wide lit line; the name ends NAME_CLEARANCE before the first target's room (TARGET_ROOM
## before its centre; or before the end of the giver's ticket on a backward strip), else it is
## shortened with ELLIPSIS.
const PLATE_TEXT := 14.0
const PLATE_PADDING := 6.0
const DIVIDER := 2.0
const NAME_SIZE := 13
const NAME_SPACING := 1
const NAME_CLEARANCE := 4.0
const ELLIPSIS := "…"
const TARGET_ROOM := 20.0
## A hot strip's gain badge ("+€14"): centred on its target, else beside it (its near edge GAIN_GAP
## past the target's centre: after it, then before it), GAIN_RISES[lane] over the body's top,
## GAIN_HEIGHT tall, its text GAIN_TEXT_SIZE with GAIN_PADDING on each side; a GAIN_BORDER ink
## border and an ink shadow GAIN_SHADOW down and right.
const GAIN_TEXT := "+€%d"
const GAIN_GAP := 6.0
const GAIN_RISES: Array[float] = [7.0, 3.0]
const GAIN_HEIGHT := 22.0
const GAIN_TEXT_SIZE := 14
const GAIN_PADDING := 6.0
const GAIN_BORDER := 2
const GAIN_SHADOW := Vector2(2, 2)
const GAIN_SHADOW_ALPHA := 0.45
## A hot strip's ring under its body: ink HOT_RING_OUTER past the body, pale HOT_RING_INNER past it.
const HOT_RING_OUTER := 6.0
const HOT_RING_INNER := 4.0
## A hot lit gap's three pale pips (HOT_PIP square), their tops from the gap's top.
const HOT_PIP := 4.0
const HOT_PIP_TOPS: Array[float] = [12.0, 28.0, 44.0]
## The chevrons' step (step_chevrons): one texel, held for CHEVRON_STEP_FRAMES slap frames.
const CHEVRON_STEP := 2.0
const CHEVRON_STEP_FRAMES := 2.0
## Lane 1's targets drop from under the body onto their tickets with a plain ink line DROP_WIDTH
## wide (no notch).
const DROP_WIDTH := 4.0
## The notch (9x5 art at 2x) under the body at a lane-0 target, from NOTCH_LEFT of its centre; its
## tip column (NOTCH_TIP from its left, NOTCH_TAIL wide) goes on down in ink to a lower ticket.
const NOTCH_SIZE := Vector2(18, 10)
const NOTCH_LEFT := 8.0
const NOTCH_TIP := 8.0
const NOTCH_TAIL := 2.0
## The body ends CAP_REACH past the last target's centre, and the cap (5x9 art at 2x) overlaps its
## ink end by CAP_OVERLAP.
const CAP_REACH := 28.0
const CAP_SIZE := Vector2(10, 18)
const CAP_OVERLAP := 2.0
## Chevrons (3x5 art at 2x) every CHEVRON_PITCH from CHEVRON_START past the plate to CHEVRON_END
## before the body's end, CHEVRON_TOP under the body's top, none within CHEVRON_SKIP (before,
## after) of a target's centre (over its notch: the break in the chevrons marks the target).
const CHEVRON_SIZE := Vector2(6, 10)
const CHEVRON_PITCH := 16.0
const CHEVRON_START := 8.0
const CHEVRON_END := 12.0
const CHEVRON_TOP := 2.0
const CHEVRON_SKIP := Vector2(16, 10)
## The body's shadow (ink at SHADOW_ALPHA, SHADOW_OFFSET down and right) and its 9-slice margin
## in art pixels.
const SHADOW_OFFSET := Vector2(2, 2)
const SHADOW_ALPHA := 0.5
const BODY_MARGIN := 2
## A lit rail gap: GAP_WIDTH wide, centred in the gap between two tickets at least that wide, as
## tall as the tickets; its 9-slice margins in art pixels.
const GAP_WIDTH := 12.0
const GAP_MARGIN_TOP := 2
const GAP_MARGIN_BOTTOM := 3

const BODY := preload("res://art/effects/rail_strip.png")
const CAP := preload("res://art/effects/rail_cap.png")
const CHEVRON := preload("res://art/effects/rail_chevron.png")
const NOTCH := preload("res://art/effects/rail_notch.png")
const GAP := preload("res://art/effects/rail_gap.png")
const BODY_HOT := preload("res://art/effects/rail_strip_hot.png")
const CAP_HOT := preload("res://art/effects/rail_cap_hot.png")
const CHEVRON_HOT := preload("res://art/effects/rail_chevron_hot.png")
const NOTCH_HOT := preload("res://art/effects/rail_notch_hot.png")
const GAP_HOT := preload("res://art/effects/rail_gap_hot.png")

## The alpha a dimmed strip fades to (PlanningTuning.dim_strip_alpha).
var dimmed_alpha: float = 1.0
var _spec: RailStripSpec
## The code-drawn rects under the body (its shadow) and over it (plate, plug, stem, drops).
var _under: Painter
var _over: Painter
var _body: Panel
var _name: Label
var _cap: TextureRect
var _chevrons: Array[TextureRect] = []
var _notches: Array[TextureRect] = []
## The gap fills (one per gap of the span), parented by the layer.
var _fills: Array[Control] = []
## The last layout's rects, in layer coordinates.
var _body_rect: Rect2 = Rect2()
var _plate_rect: Rect2 = Rect2()
var _lip_rects: Array[Rect2] = []
var _drop_rects: Array[Rect2] = []
var _gap_rects: Array[Rect2] = []
## Hot (set_hot), and each target's gain badge (null: none shown), parented by the layer.
var _hot: bool = false
var _gains: Array[Control] = []
var _dimmed: bool = false
var _dim_tween: Tween
var _chevron_tween: Tween
## How far the chevrons stand back while their step is pending (0: none).
var _chevron_back: float = 0.0
## The targets' centres and the gain badges' top at the last layout (place_gains).
var _centres: PackedFloat32Array = PackedFloat32Array()
var _gain_top: float = 0.0
## The last layout's arguments (set_hot lays the strip out again).
var _anchors: Dictionary[int, Rect2] = {}
var _lane_rect: Rect2 = Rect2()
var _gap_fill: bool = false


## The strip of `strip_spec`.
func _init(strip_spec: RailStripSpec) -> void:
	_spec = strip_spec
	name = "RailStrip%d" % strip_spec.giver_slot
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_under = Painter.new()
	_under.name = "Shadow"
	add_child(_under)
	_body = Panel.new()
	_body.name = "Body"
	_body.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_body.add_theme_stylebox_override("panel", ArtStyle.frame_style(BODY, BODY_MARGIN))
	ArtStyle.use_pixel_material(_body)
	add_child(_body)
	_over = Painter.new()
	_over.name = "Plate"
	add_child(_over)
	_name = UiKit.display_label(strip_spec.name, NAME_SIZE, false)
	_name.name = "Name"
	_name.add_theme_font_override("font", ArtStyle.spaced_display_font(NAME_SPACING))
	_name.add_theme_color_override("font_color", Palette.MUSTARD_PALE)
	_name.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	add_child(_name)
	for target: int in range(strip_spec.targets.size()):
		var notch: TextureRect = UiKit.sprite(NOTCH)
		notch.name = "Notch"
		notch.size = NOTCH_SIZE
		add_child(notch)
		_notches.append(notch)
		_gains.append(null)
	_cap = UiKit.sprite(CAP)
	_cap.name = "Cap"
	_cap.size = CAP_SIZE
	_cap.flip_h = strip_spec.backward
	add_child(_cap)
	for _gap: int in range(strip_spec.hi() - strip_spec.lo()):
		var fill: Panel = Panel.new()
		fill.name = "RailGap"
		fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
		fill.add_theme_stylebox_override("panel", _gap_style(GAP))
		ArtStyle.use_pixel_material(fill)
		for top: float in HOT_PIP_TOPS:
			var pip: ColorRect = ColorRect.new()
			pip.name = "HotPip"
			pip.mouse_filter = Control.MOUSE_FILTER_IGNORE
			pip.color = Palette.MUSTARD_PALE
			pip.position = Vector2((GAP_WIDTH - HOT_PIP) / 2.0, top)
			pip.size = Vector2(HOT_PIP, HOT_PIP)
			pip.visible = false
			fill.add_child(pip)
		fill.visible = false
		_fills.append(fill)


## Places the strip by `anchors` (slot: its ticket's rect in layer coordinates, for the giver,
## every target and the items between them) on `lane_rect` (one of LANE_RECTS), lighting the
## rail's gaps between the spanned tickets when `gap_fill` (lane 0 only). Lane 1's targets are the
## tickets' right halves, with a plain drop instead of a notch.
func lay_out(anchors: Dictionary[int, Rect2], lane_rect: Rect2, gap_fill: bool) -> void:
	_anchors = anchors
	_lane_rect = lane_rect
	_gap_fill = gap_fill
	var lane: int = 0 if is_equal_approx(lane_rect.position.y, LANE_RECTS[0].position.y) else 1
	var giver: Rect2 = anchors[_spec.giver_slot]
	var row_scale: float = giver.size.x / PriceSticker.SIZE.x
	var top: float = lane_rect.position.y
	var bottom: float = lane_rect.end.y
	var ticket_top: float = giver.position.y
	var x0: float = snappedf(giver.position.x + _scaled(PLUG_OFFSET, row_scale), ArtStyle.ART_SCALE)
	# The targets' centres.
	var centres: PackedFloat32Array = PackedFloat32Array()
	for index: int in range(_spec.targets.size()):
		var ticket: Rect2 = anchors[_spec.targets[index]]
		centres.append(
			snappedf(
				ticket.position.x + _scaled(TARGET_OFFSETS[lane], row_scale), ArtStyle.ART_SCALE
			)
		)
	_centres = centres
	_gain_top = top - GAIN_RISES[lane]
	# The name, shortened to end before the first target's room on its side (or the giver's
	# ticket).
	var limit: float = giver.end.x - NAME_CLEARANCE
	if not _spec.backward:
		limit = INF
		for index: int in range(centres.size()):
			if _spec.targets[index] > _spec.giver_slot:
				limit = minf(limit, centres[index] - TARGET_ROOM - NAME_CLEARANCE)
	var name_end: float = _fit_name(x0, limit)
	# The body: from the plug (or the cap end of a backward strip) to the cap (or past the plate).
	var left: float = x0
	var right: float = name_end + DIVIDER
	for index: int in range(centres.size()):
		if _spec.targets[index] > _spec.giver_slot:
			right = maxf(right, centres[index] + CAP_REACH)
		else:
			left = minf(left, centres[index] - CAP_REACH)
	left = snappedf(left, ArtStyle.ART_SCALE)
	right = snappedf(right, ArtStyle.ART_SCALE)
	_body_rect = Rect2(left, top, right - left, bottom - top)
	var cap_at: Vector2 = Vector2(right - CAP_OVERLAP, top + PLUG.position.y)
	if _spec.backward:
		cap_at.x = left + CAP_OVERLAP - CAP_SIZE.x
	var cap_rect: Rect2 = Rect2(cap_at, CAP_SIZE)
	# Everything placed relative to the strip's own rect.
	var plug: Rect2 = Rect2(Vector2(x0, top) + PLUG.position, PLUG.size)
	var stem: Rect2 = _down(x0 + STEM_LEFT, STEM_WIDTH, bottom + STEM_GAP, ticket_top)
	var notches: Array[Rect2] = []
	var drops: Array[Rect2] = []
	for index: int in range(centres.size()):
		var target_top: float = anchors[_spec.targets[index]].position.y
		if lane == 0:
			var notch: Rect2 = Rect2(Vector2(centres[index] - NOTCH_LEFT, bottom), NOTCH_SIZE)
			notches.append(notch)
			# A scaled row's tickets stand lower: the notch's tip reaches on down to its ticket.
			if target_top > notch.end.y:
				var tip: float = notch.position.x + NOTCH_TIP
				drops.append(_down(tip, NOTCH_TAIL, notch.end.y, target_top))
		else:
			drops.append(_down(centres[index] - DROP_WIDTH / 2.0, DROP_WIDTH, bottom, target_top))
	var plate: Rect2 = Rect2(x0, top, name_end - x0 + DIVIDER, bottom - top)
	_plate_rect = plate
	_lip_rects = [plug, plate, cap_rect]
	_lip_rects.append_array(notches)
	_drop_rects = [stem]
	_drop_rects.append_array(drops)
	var bounds: Rect2 = _body_rect.grow_individual(0, 0, SHADOW_OFFSET.x, SHADOW_OFFSET.y)
	if _hot:
		bounds = bounds.merge(_body_rect.grow(HOT_RING_OUTER))
	for rect: Rect2 in _lip_rects + _drop_rects:
		bounds = bounds.merge(rect)
	position = bounds.position
	size = bounds.size
	var origin: Vector2 = bounds.position
	_under.position = Vector2.ZERO
	_under.size = size
	var under: Array[Rect2] = []
	var under_colours: Array[Color] = []
	if _hot:
		var outer: Rect2 = _body_rect.grow(HOT_RING_OUTER)
		var inner: Rect2 = _body_rect.grow(HOT_RING_INNER)
		under.append(Rect2(outer.position - origin, outer.size))
		under.append(Rect2(inner.position - origin, inner.size))
		under_colours.append_array([Palette.INK, Palette.MUSTARD_PALE])
	under.append(Rect2(_body_rect.position + SHADOW_OFFSET - origin, _body_rect.size))
	under_colours.append(Color(Palette.INK, SHADOW_ALPHA))
	_under.paint(under, under_colours)
	_body.position = _body_rect.position - origin
	_body.size = _body_rect.size
	_over.position = Vector2.ZERO
	_over.size = size
	var rects: Array[Rect2] = [
		Rect2(Vector2(x0, top) - origin, Vector2(name_end - x0, bottom - top)),
		Rect2(Vector2(name_end, top) - origin, Vector2(DIVIDER, bottom - top)),
		Rect2(plug.position - origin, plug.size),
		Rect2(Vector2(x0, top) + PIP.position - origin, PIP.size),
		Rect2(stem.position - origin, stem.size),
		Rect2(
			stem.position + Vector2((STEM_WIDTH - STEM_FILL) / 2.0, 0.0) - origin,
			Vector2(STEM_FILL, stem.size.y)
		),
	]
	var lit: Color = Palette.MUSTARD_PALE if _hot else Palette.MUSTARD_LIGHT
	var colours: Array[Color] = [
		Palette.INK,
		lit,
		Palette.INK,
		lit,
		Palette.INK,
		Palette.MUSTARD if _hot else Palette.MUSTARD_DARK,
	]
	for drop: Rect2 in drops:
		rects.append(Rect2(drop.position - origin, drop.size))
		colours.append(Palette.INK)
	_over.paint(rects, colours)
	_name.position = Vector2(x0 + PLATE_TEXT, top) - origin
	_name.size = Vector2(name_end - PLATE_PADDING - x0 - PLATE_TEXT, bottom - top)
	for index: int in range(_notches.size()):
		_notches[index].visible = lane == 0
		if lane == 0:
			_notches[index].position = notches[index].position - origin
	_cap.position = cap_at - origin
	_lay_out_chevrons(x0, name_end, centres, origin)
	_lay_out_fills(anchors, gap_fill)
	place_gains([])


## The gain badges made (hot only), in target order, for the layer's box.
func gains() -> Array[Control]:
	var shown: Array[Control] = []
	for gain: Control in _gains:
		if gain != null:
			shown.append(gain)
	return shown


## Each gain badge's own target centre (layer x at the last layout), in gains() order, so a gain
## can be checked against its own target rather than any of the strip's (for tests).
func gain_centres() -> PackedFloat32Array:
	var centres: PackedFloat32Array = PackedFloat32Array()
	for index: int in range(_gains.size()):
		if _gains[index] != null:
			centres.append(_centres[index] if index < _centres.size() else NAN)
	return centres


## The gain badges' texts shown, in target order (for tests).
func gain_texts() -> PackedStringArray:
	var texts: PackedStringArray = PackedStringArray()
	for gain: Control in _gains:
		if gain != null and gain.visible:
			texts.append((gain.get_node("Text") as Label).text)
	return texts


## Places each gain badge on its target, clear of `obstacles` (layer coordinates: the other hot
## strips' gains), of this strip's name plate and of its own other gains, inside the lip band:
## centred on the target, else just after it, else just before it (its near edge GAIN_GAP past the
## target's centre). A gain with no clear place is hidden rather than drawn over another (its
## target's sticker and the receipt still say it). Returns the shown gains' rects. lay_out calls it
## with no obstacles; PlanningLayer calls it again with the other hot strips'.
func place_gains(obstacles: Array[Rect2]) -> Array[Rect2]:
	var placed: Array[Rect2] = []
	var blocked: Array[Rect2] = obstacles.duplicate()
	blocked.append(_plate_rect)
	for index: int in range(_gains.size()):
		var gain: Control = _gains[index]
		if gain == null or index >= _centres.size():
			continue
		var centre: float = _centres[index]
		var width: float = gain.size.x
		var sides: Array[Rect2] = []
		for left: float in [centre - width / 2.0, centre + GAIN_GAP, centre - GAIN_GAP - width]:
			sides.append(Rect2(snappedf(left, ArtStyle.ART_SCALE), _gain_top, width, gain.size.y))
		var chosen: Rect2 = Rect2()
		for side: Rect2 in sides:
			var inside: bool = (
				side.position.x >= LIP_BAND.position.x and side.end.x <= LIP_BAND.end.x
			)
			if (
				inside
				and not blocked.any(func(other: Rect2) -> bool: return side.intersects(other))
			):
				chosen = side
				break
		gain.visible = chosen.has_area()
		gain.position = (chosen if gain.visible else sides[0]).position
		if gain.visible:
			placed.append(chosen)
			blocked.append(chosen)
	return placed


## Turns the strip hot (`hot`: bright gold in its ring and a gain badge on each target, or only
## `gain_target`'s; none for a target whose gain was cancelled or is nothing) or calm again, and
## lays it out again if it was. New gain badges join the old ones' parent (with none, the caller
## parents them: gains()).
func set_hot(hot: bool, gain_target: int = -1) -> void:
	_hot = hot
	_body.add_theme_stylebox_override(
		"panel", ArtStyle.frame_style(BODY_HOT if hot else BODY, BODY_MARGIN)
	)
	_cap.texture = CAP_HOT if hot else CAP
	for chevron: TextureRect in _chevrons:
		chevron.texture = CHEVRON_HOT if hot else CHEVRON
	for notch: TextureRect in _notches:
		notch.texture = NOTCH_HOT if hot else NOTCH
	for fill: Control in _fills:
		fill.add_theme_stylebox_override("panel", _gap_style(GAP_HOT if hot else GAP))
		for pip: Node in fill.get_children():
			(pip as CanvasItem).visible = hot
	_name.add_theme_color_override("font_color", Palette.PAPER if hot else Palette.MUSTARD_PALE)
	var parent: Node = null
	for index: int in range(_gains.size()):
		if _gains[index] != null:
			parent = _gains[index].get_parent()
			_gains[index].queue_free()
			_gains[index] = null
	for index: int in range(_gains.size()):
		var gain: int = _spec.gains[index]
		if hot and gain > 0 and (gain_target < 0 or gain_target == _spec.targets[index]):
			_gains[index] = _make_gain(GAIN_TEXT % gain)
			if parent != null:
				parent.add_child(_gains[index])
	if not _anchors.is_empty():
		lay_out(_anchors, _lane_rect, _gap_fill)


func is_hot() -> bool:
	return _hot


## Fades the strip, its gains and its lit gaps to `dimmed_alpha` (`dimmed`) or back, over `fade`
## seconds (0: at once).
func set_dimmed(dimmed: bool, fade: float = 0.0) -> void:
	_dimmed = dimmed
	if _dim_tween != null:
		_dim_tween.kill()
		_dim_tween = null
	var alpha: float = dimmed_alpha if dimmed else 1.0
	var parts: Array[Control] = [self]
	parts.append_array(gains())
	parts.append_array(_fills)
	if fade > 0.0 and is_inside_tree():
		_dim_tween = create_tween().set_parallel()
		for part: Control in parts:
			_dim_tween.tween_property(part, "modulate:a", alpha, fade)
	else:
		for part: Control in parts:
			part.modulate.a = alpha


func is_dimmed() -> bool:
	return _dimmed


## Steps the chevrons one texel toward the targets, once: they start a step back and land after
## CHEVRON_STEP_FRAMES frames of `frame_s` seconds. Nothing under `reduced_motion`; it never loops.
func step_chevrons(reduced_motion: bool, frame_s: float = 0.0) -> void:
	if _chevron_tween != null:
		_chevron_tween.kill()
		_chevron_tween = null
	_step_chevrons(0.0)
	if reduced_motion or frame_s <= 0.0 or not is_inside_tree() or _chevrons.is_empty():
		return
	_step_chevrons(CHEVRON_STEP if _spec.backward else -CHEVRON_STEP)
	_chevron_tween = create_tween()
	_chevron_tween.tween_interval(frame_s * CHEVRON_STEP_FRAMES)
	_chevron_tween.tween_callback(_step_chevrons.bind(0.0))


## Whether the chevrons' step is playing (for tests).
func is_stepping() -> bool:
	return _chevron_tween != null and _chevron_tween.is_running()


## The lit rail gaps (one per gap of the span; hidden when not laid out), for the layer's gap box.
func fills() -> Array[Control]:
	return _fills


func spec() -> RailStripSpec:
	return _spec


## The body's rect at the last layout, in layer coordinates.
func body_rect() -> Rect2:
	return _body_rect


## The targets' centres (each one's notch or drop, and its gain's anchor) at the last layout, in
## target order, in layer coordinates.
func target_centres() -> PackedFloat32Array:
	return _centres


## The plug, plate, cap and notches at the last layout, in layer coordinates.
func lip_rects() -> Array[Rect2]:
	return _lip_rects


## The stem and the drops down to the tickets at the last layout, in layer coordinates.
func drop_rects() -> Array[Rect2]:
	return _drop_rects


## The lit rail gaps shown at the last layout, in layer coordinates.
func gap_rects() -> Array[Rect2]:
	return _gap_rects


## Every part's rect (the strip's own, its shown gains and gap fills), in layer coordinates.
func parts_rect() -> Rect2:
	var bounds: Rect2 = Rect2(position, size)
	for gain: Control in gains():
		if gain.visible:
			bounds = bounds.merge(Rect2(gain.position, gain.size))
	for rect: Rect2 in _gap_rects:
		bounds = bounds.merge(rect)
	return bounds


## The gains' and gap fills' nodes go with the strip.
func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE:
		for part: Control in gains() + _fills:
			if is_instance_valid(part):
				part.queue_free()


## Stands the chevrons `back` along the strip from their places (0: on them; step_chevrons).
func _step_chevrons(back: float) -> void:
	for chevron: TextureRect in _chevrons:
		chevron.position.x += back - _chevron_back
	_chevron_back = back


## Places the name from `x0` and returns the plate's end (on the 2 px grid), shortening the name
## with ELLIPSIS while the plate would pass `limit`.
func _fit_name(x0: float, limit: float) -> float:
	var font: Font = ArtStyle.spaced_display_font(NAME_SPACING)
	var text: String = _spec.name
	_name.text = text
	var name_end: float = _plate_end(x0, font, text)
	while name_end > limit and text.length() > 1:
		text = text.substr(0, text.length() - 1).strip_edges()
		_name.text = text + ELLIPSIS
		name_end = _plate_end(x0, font, _name.text)
	return name_end


static func _plate_end(x0: float, font: Font, text: String) -> float:
	var width: float = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, NAME_SIZE).x
	return snappedf(ceilf(x0 + PLATE_TEXT + width + PLATE_PADDING), ArtStyle.ART_SCALE)


## The chevrons along the body, pointing from the giver to its targets: right of the plate on a
## forward strip, left of the plug on a backward one, none over a target's notch.
func _lay_out_chevrons(
	x0: float, name_end: float, centres: PackedFloat32Array, origin: Vector2
) -> void:
	var spots: Array[float] = []
	if _spec.backward:
		var x: float = snappedf(
			x0 + PLUG.position.x - CHEVRON_START - CHEVRON_SIZE.x, ArtStyle.ART_SCALE
		)
		while x > _body_rect.position.x + CHEVRON_END - CHEVRON_SIZE.x:
			if _clear_of(x, centres):
				spots.append(x)
			x -= CHEVRON_PITCH
	else:
		var x: float = snappedf(name_end + CHEVRON_START, ArtStyle.ART_SCALE)
		while x < _body_rect.end.x - CHEVRON_END:
			if _clear_of(x, centres):
				spots.append(x)
			x += CHEVRON_PITCH
	while _chevrons.size() < spots.size():
		var chevron: TextureRect = UiKit.sprite(CHEVRON_HOT if _hot else CHEVRON)
		chevron.name = "Chevron"
		chevron.size = CHEVRON_SIZE
		chevron.flip_h = _spec.backward
		add_child(chevron)
		_chevrons.append(chevron)
	for index: int in range(_chevrons.size()):
		var shown: bool = index < spots.size()
		_chevrons[index].visible = shown
		if shown:
			var at: Vector2 = Vector2(
				spots[index] + _chevron_back, _body_rect.position.y + CHEVRON_TOP
			)
			_chevrons[index].position = at - origin


static func _clear_of(x: float, centres: PackedFloat32Array) -> bool:
	for centre: float in centres:
		if x >= centre - CHEVRON_SKIP.x and x <= centre + CHEVRON_SKIP.y:
			return false
	return true


## The lit rail gaps between the spanned tickets that are at least GAP_WIDTH apart (lane 0).
func _lay_out_fills(anchors: Dictionary[int, Rect2], gap_fill: bool) -> void:
	_gap_rects.clear()
	var lo: int = _spec.lo()
	for index: int in range(_fills.size()):
		var fill: Control = _fills[index]
		fill.visible = false
		var slot: int = lo + index
		if not gap_fill or not anchors.has(slot) or not anchors.has(slot + 1):
			continue
		var here: Rect2 = anchors[slot]
		var next: Rect2 = anchors[slot + 1]
		var gap: float = next.position.x - here.end.x
		if gap < GAP_WIDTH:
			continue
		var x: float = snappedf(here.end.x + (gap - GAP_WIDTH) / 2.0, ArtStyle.ART_SCALE)
		var rect: Rect2 = Rect2(x, here.position.y, GAP_WIDTH, here.size.y)
		fill.position = rect.position
		fill.size = rect.size
		fill.visible = true
		_gap_rects.append(rect)


## A hot strip's gain badge showing `shown` ("+€14"): a paper box with an ink border and shadow,
## the gain in the number font in mustard darkest, GAIN_PADDING each side of it, GAIN_HEIGHT tall.
static func _make_gain(shown: String) -> Control:
	var gain: Control = Control.new()
	gain.name = "GainBadge"
	gain.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var width: float = snappedf(
		ceilf(_text_width(shown, GAIN_TEXT_SIZE) + GAIN_PADDING * 2.0), ArtStyle.ART_SCALE
	)
	gain.size = Vector2(width, GAIN_HEIGHT)
	var shadow: ColorRect = ColorRect.new()
	shadow.name = "Shadow"
	shadow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	shadow.color = Color(Palette.INK, GAIN_SHADOW_ALPHA)
	shadow.position = GAIN_SHADOW
	gain.add_child(shadow)
	var box: Panel = Panel.new()
	box.name = "Box"
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = Palette.PAPER
	style.border_color = Palette.INK
	style.set_border_width_all(GAIN_BORDER)
	box.add_theme_stylebox_override("panel", style)
	gain.add_child(box)
	var text: Label = UiKit.number_label(shown, GAIN_TEXT_SIZE, false)
	text.name = "Text"
	text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	text.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	text.add_theme_font_size_override("font_size", GAIN_TEXT_SIZE)
	text.add_theme_color_override("font_color", Palette.MUSTARD_DARKEST)
	gain.add_child(text)
	for part: Control in [shadow, box, text]:
		part.size = gain.size
	return gain


static func _text_width(token: String, text_size: int) -> float:
	var font: Font = ArtStyle.number_font()
	return font.get_string_size(token, HORIZONTAL_ALIGNMENT_LEFT, -1, text_size).x


## A lit gap's 9-slice of `texture`.
static func _gap_style(texture: Texture2D) -> StyleBoxTexture:
	var style: StyleBoxTexture = StyleBoxTexture.new()
	style.texture = texture
	style.texture_margin_top = GAP_MARGIN_TOP * ArtStyle.ART_SCALE
	style.texture_margin_bottom = GAP_MARGIN_BOTTOM * ArtStyle.ART_SCALE
	return style


## A rect `width` wide at `x` from `from` down to `to` (none when `to` is above `from`).
static func _down(x: float, width: float, from: float, to: float) -> Rect2:
	return Rect2(x, from, width, maxf(to - from, 0.0))


static func _scaled(offset: float, row_scale: float) -> float:
	return snappedf(offset * row_scale, ArtStyle.ART_SCALE)


## Flat rects in palette colours, drawn in order (the strip's code-drawn parts).
class Painter:
	extends Control
	var _rects: Array[Rect2] = []
	var _colours: Array[Color] = []

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		for index: int in range(_rects.size()):
			draw_rect(_rects[index], _colours[index])

	## Draws `rects` in `colours` (one each), in order.
	func paint(rects: Array[Rect2], colours: Array[Color]) -> void:
		_rects = rects
		_colours = colours
		queue_redraw()
