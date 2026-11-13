class_name GlyphTips
extends Control
## The game's hover tips on one screen (#105; the hover tips revamp, design B "paper card", mock-up
## docs/art/mockups/hover_tips.html, approved 2026-11-13): resting the pointer on a TipTarget for
## SHOW_DELAY_S shows its tip (TipCard, from the target's tip_spec()), anchored to the target (never
## to the pointer: it does not follow the mouse's jitter), on the side its screen zone says
## (side_for: the top bar and the monitor below, the left column to the right, tickets below, belt
## things above), kept inside the screen. It pops from POP_FROM to full size in POP_S with a small
## overshoot about its tail (at once under reduced motion), and the keyword and word boxes its rule
## names (TipWords, at most two) pop in beside it BOX_STAGGER_S apart. Leaving hides it at once;
## within SWITCH_GRACE_S of a tip closing, the next target's tip opens with no wait.
##
## Shift keeps a shown tip open (it then takes the pointer: moving away keeps it, and its footer
## says SHIFT KEPT); a click or Esc closes it (and is used up). A right-click on a shown tip asks
## for its handbook page (guide_requested; the footer's RIGHT-CLICK HANDBOOK key shows only where
## guide_for says a page exists).
##
## The targets take no clicks, so this watches the pointer itself (_input, never marking an event
## handled but a kept tip's close): the item under a target keeps its hover, drag and clicks. A
## button press, a scroll or `blocked` (a drag, the count-up) hides the tip, but for a target that
## `shows_while_blocked` (a monitor count row's bag glyph, v1.11); such a target rebuilt under the
## pointer (the count's rows are, each step) keeps its tip.
##
## Mount one over a screen (add it last, so it draws on top): it serves every target under its
## parent that no nearer GlyphTips serves. A target covered by a control that takes the pointer (a
## panel opened over the belt) shows nothing.
##
## shown_changed says which target's tip shows (null: none), once per change: a family glyph's
## lights its family for the mix highlight (#105 piece 3, PlanningEffects.watch_glyphs).

## The target whose tip shows changed: `target`, or null when no tip shows.
signal shown_changed(target: TipTarget)
## The player right-clicked while `target`'s tip showed (v1.06): the staff handbook's deep link
## opens the target's entry (HandbookPage.mount). The tip hides as for any press.
signal guide_requested(target: TipTarget)

const SHOW_DELAY_S := 0.2
const POP_S := 0.12
const POP_FROM := 0.82
const BOX_STAGGER_S := 0.05
const SWITCH_GRACE_S := 0.3
## The screen zones (fractions of the screen) that pick a tip's side (side_for).
const TOP_BAR_FOOT := 0.11
const LEFT_COLUMN_END := 0.23
const MONITOR_ZONE := Rect2(0.36, 0.0, 0.36, 0.36)
## The parent's meta naming the GlyphTips that serves its glyphs.
const SCOPE_META := &"glyph_tips"

## Returns true while no tip may show (a drag, the count-up). None: never.
var blocked: Callable = Callable()
## Returns true when the player asked for reduced motion. None means false.
var reduced_motion: Callable = Callable()
## Returns true when right-clicking a target's tip opens the staff handbook (v1.06,
## HandbookPage.has_entry_for): its tip's footer then shows RIGHT-CLICK HANDBOOK. None: never.
var guide_for: Callable = Callable()
var _tip: TipCard
var _boxes: Array[TipCard] = []
## Shift keeps the shown tip open.
var _kept: bool = false
## The time (s) the last tip closed by the pointer leaving: SWITCH_GRACE_S after it, the next tip
## opens at once.
var _closed_at: float = -INF
var _pointer: Vector2 = Vector2(-INF, -INF)
var _candidate: TipTarget
var _shown: TipTarget
var _waited: float = 0.0
var _pop: Tween
## Whether `blocked` held on the last frame: then only targets that show while blocked serve.
var _held: bool = false
## The shown tip's text (_follow_rebuilt) and the shown spec's words (rebuilt when they change).
var _shown_text: String = ""
var _built: String = ""


func _init() -> void:
	name = "GlyphTips"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	z_index = 100
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_tip = TipCard.new()
	_tip.visible = false
	add_child(_tip)
	for index: int in range(TipSpec.MAX_SUBS):
		var box: TipCard = TipCard.new(true)
		box.name = "TipBox%d" % index
		box.visible = false
		add_child(box)
		_boxes.append(box)


func _enter_tree() -> void:
	get_parent().set_meta(SCOPE_META, self)


func _exit_tree() -> void:
	var parent: Node = get_parent()
	if parent != null and parent.get_meta(SCOPE_META, null) == self:
		parent.remove_meta(SCOPE_META)


func _input(event: InputEvent) -> void:
	var key: InputEventKey = event as InputEventKey
	if key != null:
		if key.pressed and not key.echo:
			if key.keycode == KEY_SHIFT and shown_glyph() != null and not _kept:
				keep()
			elif key.keycode == KEY_ESCAPE and _kept:
				hide_tip()
				get_viewport().set_input_as_handled()
		return
	if event is InputEventMouseMotion:
		point_at((event as InputEventMouseMotion).position)
	elif event is InputEventMouseButton and (event as InputEventMouseButton).pressed:
		var press: InputEventMouseButton = event as InputEventMouseButton
		var shown: TipTarget = shown_glyph()
		var was_kept: bool = _kept
		hide_tip()
		_candidate = null
		if shown != null and press.button_index == MOUSE_BUTTON_RIGHT:
			guide_requested.emit(shown)
		if was_kept and is_inside_tree():
			get_viewport().set_input_as_handled()


## Keeps the shown tip open (Shift): moving away no longer hides it, its footer says SHIFT KEPT and
## it takes the pointer; a click or Esc closes it.
func keep() -> void:
	if shown_glyph() == null:
		return
	_kept = true
	_tip.mouse_filter = Control.MOUSE_FILTER_STOP
	_built = ""
	_place(_shown)


## Whether the shown tip is kept open (Shift).
func is_kept() -> bool:
	return _kept and shown_glyph() != null


## The pointer is at `at` (the viewport's coordinates): the glyph under it, if any, starts its
## wait (a test calls it as a mouse motion would).
func point_at(at: Vector2) -> void:
	_pointer = at
	if _kept:
		return
	var glyph: TipTarget = glyph_at(at)
	if glyph != _candidate:
		_candidate = glyph
		_waited = 0.0
		if glyph != _shown:
			hide_tip(true)
		if glyph != null and _now() - _closed_at <= SWITCH_GRACE_S:
			_waited = SHOW_DELAY_S


func _process(delta: float) -> void:
	var held: bool = _is_blocked()
	if _kept:
		_held = held
		var gone: bool = not is_instance_valid(_shown) or not _shown.is_inside_tree()
		if gone or not _shown.is_shown() or (held and not _shown.shows_while_blocked):
			hide_tip()
		else:
			_place(_shown)
		return
	if held != _held:
		_held = held
		hide_tip()
		_candidate = glyph_at(_pointer)
		_waited = 0.0
	if _tip.visible and (not is_instance_valid(_shown) or not _shown.is_inside_tree()):
		_follow_rebuilt()
	if _candidate != null and not _serves(_candidate, _pointer):
		_candidate = glyph_at(_pointer)
		_waited = 0.0
		if _candidate != _shown:
			hide_tip(true)
			if _candidate != null and _now() - _closed_at <= SWITCH_GRACE_S:
				_waited = SHOW_DELAY_S
	if _candidate == null or _candidate == _shown:
		if _shown != null:
			_place(_shown)
		return
	_waited += delta
	if _waited >= SHOW_DELAY_S:
		show_tip(_candidate)


## Shows the tip of `glyph` now (after the wait; tests call it directly).
func show_tip(glyph: TipTarget) -> void:
	var changed: bool = _shown != glyph
	if changed and is_instance_valid(_shown):
		_shown.tip_shown(false)
	_shown = glyph
	_candidate = glyph
	_shown_text = glyph.full_tip()
	_built = ""
	# Listeners first: PlanningEffects writes the belt's part of the text (tip_more) on it.
	if changed:
		glyph.tip_shown(true)
		shown_changed.emit(glyph)
	_tip.visible = true
	_place(glyph)
	if _pop != null:
		_pop.kill()
		_pop = null
	if _wants_reduced_motion() or not is_inside_tree():
		_tip.scale = Vector2.ONE
		for box: TipCard in _boxes:
			box.scale = Vector2.ONE
		return
	_pop = create_tween().set_parallel(true)
	_pop_in(_tip, 0.0)
	var delay: float = 0.0
	for box: TipCard in boxes():
		delay += BOX_STAGGER_S
		_pop_in(box, delay)


## Hides the tip and its boxes (`left`: the pointer left it, so the next tip may open at once).
func hide_tip(left: bool = false) -> void:
	var was_shown: bool = _shown != null
	if was_shown and _tip.visible and left:
		_closed_at = _now()
	_kept = false
	_tip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for box: TipCard in _boxes:
		box.visible = false
	if is_instance_valid(_shown):
		_shown.tip_shown(false)
	_shown = null
	_tip.visible = false
	if was_shown:
		shown_changed.emit(null)
	if _pop != null:
		_pop.kill()
		_pop = null


## The tip (its card, place and tail), shown or not.
func tip() -> TipCard:
	return _tip


## The keyword and word boxes shown beside the tip.
func boxes() -> Array[TipCard]:
	var shown: Array[TipCard] = []
	for box: TipCard in _boxes:
		if box.visible:
			shown.append(box)
	return shown


## The side a tip opens on for `glyph` at `rect` on `screen` (one set of coordinates): its own
## tip_side, else below its ticket (tip_below), else by zone: the top bar and the monitor below, the
## left column to the right, the rest (belt things) above.
static func side_for(glyph: TipTarget, rect: Rect2, screen: Rect2) -> TipCard.Opens:
	if glyph.tip_side != TipTarget.SIDE_AUTO:
		return glyph.tip_side as TipCard.Opens
	if glyph.tip_below:
		return TipCard.Opens.BELOW
	var at: Vector2 = (rect.get_center() - screen.position) / screen.size
	if rect.end.y <= screen.position.y + screen.size.y * TOP_BAR_FOOT:
		return TipCard.Opens.BELOW
	if at.x < LEFT_COLUMN_END:
		return TipCard.Opens.RIGHT
	if MONITOR_ZONE.has_point(at):
		return TipCard.Opens.BELOW
	return TipCard.Opens.ABOVE


## The target (a glyph, a ticket's colour) whose tip shows, or null.
func shown_glyph() -> TipTarget:
	return _shown if _tip.visible else null


## The topmost target (a glyph over a ticket's colour, a stuck price label over the next ticket)
## this serves under `at` (viewport coordinates), or null.
func glyph_at(at: Vector2) -> TipTarget:
	var found: TipTarget = null
	for node: Node in get_tree().get_nodes_in_group(TipTarget.GROUP):
		var glyph: TipTarget = node as TipTarget
		if glyph == null or not _serves(glyph, at):
			continue
		if found == null or glyph.drawn_from().is_greater_than(found.drawn_from()):
			found = glyph
	return found


## Whether `glyph` is this one's, shown, under `at` (its hover_rect; inside every clipping
## ancestor: a glyph scrolled out of a ScrollContainer, or outside a sliding page, shows
## nothing), and not covered by a control that takes the pointer (one later in the tree that is
## not its ancestor; later than the layer that draws it over its row for a price label,
## TipTarget.drawn_from).
func _serves(glyph: TipTarget, at: Vector2) -> bool:
	if not is_instance_valid(glyph) or not glyph.is_inside_tree() or not glyph.is_shown():
		return false
	if not glyph.has_tip() or (_held and not glyph.shows_while_blocked):
		return false
	if _scope_of(glyph) != self or not glyph.hover_rect().has_point(at) or is_clipped(glyph, at):
		return false
	var hovered: Control = get_viewport().gui_get_hovered_control()
	if hovered == null or hovered.is_ancestor_of(glyph):
		return true
	return glyph.drawn_from().is_greater_than(hovered)


## Whether `at` (viewport coordinates) is outside the rect of one of `node`'s ancestors that clip
## their contents, so `node` isn't drawn there.
static func is_clipped(node: Node, at: Vector2) -> bool:
	var parent: Node = node.get_parent()
	while parent != null:
		var control: Control = parent as Control
		if (
			control != null
			and control.clip_contents
			and not control.get_global_rect().has_point(at)
		):
			return true
		parent = parent.get_parent()
	return false


## The GlyphTips serving `glyph`: the nearest one mounted on its ancestors.
static func _scope_of(glyph: Node) -> GlyphTips:
	var node: Node = glyph.get_parent()
	while node != null:
		if node.has_meta(SCOPE_META):
			return node.get_meta(SCOPE_META) as GlyphTips
		node = node.get_parent()
	return null


func _place(glyph: TipTarget) -> void:
	if not is_instance_valid(glyph) or not glyph.is_inside_tree():
		hide_tip()
		return
	var to_local: Transform2D = get_global_transform().affine_inverse()
	var glyph_rect: Rect2 = to_local * glyph.get_global_rect()
	var anchor: Rect2 = glyph_rect
	if glyph.tip_below and is_instance_valid(glyph.tip_anchor):
		anchor = to_local * glyph.tip_anchor.get_global_rect()
	var screen: Rect2 = to_local * get_viewport_rect()
	var made: TipSpec = glyph.tip_spec()
	made.guide = guide_for.is_valid() and bool(guide_for.call(glyph))
	var words: String = "%s|%s|%s" % [made.plain(), made.guide, _kept]
	if words != _built:
		_built = words
		_tip.show_spec(made, _kept)
		var keys: PackedStringArray = made.shown_subs()
		for index: int in range(_boxes.size()):
			var box_spec: TipSpec = TipWords.box(keys[index]) if index < keys.size() else null
			_boxes[index].visible = box_spec != null and _tip.visible
			if box_spec != null:
				_boxes[index].show_spec(box_spec)
	var opens: TipCard.Opens = side_for(glyph, glyph_rect, screen)
	var placed: Array = TipCard.place(glyph_rect, anchor, opens, _tip.size, screen)
	var card_rect: Rect2 = placed[0]
	_tip.position = card_rect.position
	_tip.point_tail(placed[1], glyph_rect)
	var shown: Array[TipCard] = boxes()
	var sizes: Array[Vector2] = []
	for box: TipCard in shown:
		sizes.append(box.size)
	var rects: Array[Rect2] = TipCard.place_boxes(card_rect, placed[1], sizes, screen, glyph_rect)
	for index: int in range(shown.size()):
		shown[index].position = rects[index].position


func _pop_in(card: Control, delay: float) -> void:
	card.scale = Vector2.ONE * POP_FROM
	(
		_pop
		. tween_property(card, "scale", Vector2.ONE, POP_S)
		. set_delay(delay)
		. set_trans(Tween.TRANS_BACK)
		. set_ease(Tween.EASE_OUT)
	)


func _now() -> float:
	return Time.get_ticks_msec() / 1000.0


## The shown target was freed: the one now under the pointer takes its tip at once when it says the
## same (a count row rebuilt each step), else the tip hides.
func _follow_rebuilt() -> void:
	var next: TipTarget = glyph_at(_pointer)
	_shown = null
	if next == null or next.full_tip() != _shown_text:
		hide_tip()
		return
	_shown = next
	_candidate = next
	next.tip_shown(true)
	shown_changed.emit(next)
	_place(next)


func _is_blocked() -> bool:
	if blocked.is_valid() and bool(blocked.call()):
		return true
	return Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT)


func _wants_reduced_motion() -> bool:
	return reduced_motion.is_valid() and bool(reduced_motion.call())
