class_name GlyphTips
extends Control
## The family glyphs' and the ticket colours' tooltips on one screen (#105, mock-up readability v3):
## resting the pointer on a TipTarget (a FamilyGlyph, or a ticket's colour, which a glyph on it
## covers) for SHOW_DELAY_S shows its tip (GlyphTip: the family's name, or what the colour means),
## below its ticket on a rail or shelf ticket, else above the glyph; it pops from POP_FROM to full
## size in POP_S about its tail (at once under reduced motion). The glyphs take no clicks, so this
## watches the pointer itself (_input, never marking an event handled): the item under a glyph keeps
## its hover, drag and clicks. A button press, a scroll or `blocked` (a drag, the count-up) hides
## the tip.
##
## Mount one over a screen (add it last, so it draws on top): it serves every glyph under its
## parent that no nearer GlyphTips serves. A glyph covered by a control that takes the pointer (a
## panel opened over the belt) shows nothing.

const SHOW_DELAY_S := 0.15
const POP_S := 0.08
const POP_FROM := 0.6
## The parent's meta naming the GlyphTips that serves its glyphs.
const SCOPE_META := &"glyph_tips"

## Returns true while no tip may show (a drag, the count-up). None: never.
var blocked: Callable = Callable()
## Returns true when the player asked for reduced motion. None means false.
var reduced_motion: Callable = Callable()
var _tip: GlyphTip
var _pointer: Vector2 = Vector2(-INF, -INF)
var _candidate: TipTarget
var _shown: TipTarget
var _waited: float = 0.0
var _pop: Tween


func _init() -> void:
	name = "GlyphTips"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	z_index = 100
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_tip = GlyphTip.new()
	_tip.visible = false
	add_child(_tip)


func _enter_tree() -> void:
	get_parent().set_meta(SCOPE_META, self)


func _exit_tree() -> void:
	var parent: Node = get_parent()
	if parent != null and parent.get_meta(SCOPE_META, null) == self:
		parent.remove_meta(SCOPE_META)


func _input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		point_at((event as InputEventMouseMotion).position)
	elif event is InputEventMouseButton and (event as InputEventMouseButton).pressed:
		hide_tip()
		_candidate = null


## The pointer is at `at` (the viewport's coordinates): the glyph under it, if any, starts its
## wait (a test calls it as a mouse motion would).
func point_at(at: Vector2) -> void:
	_pointer = at
	var glyph: TipTarget = glyph_at(at)
	if glyph != _candidate:
		_candidate = glyph
		_waited = 0.0
		if glyph != _shown:
			hide_tip()


func _process(delta: float) -> void:
	if _is_blocked():
		hide_tip()
		_candidate = null
		return
	if _candidate != null and not _serves(_candidate, _pointer):
		_candidate = glyph_at(_pointer)
		_waited = 0.0
		if _candidate != _shown:
			hide_tip()
	if _candidate == null or _candidate == _shown:
		if _shown != null:
			_place(_shown)
		return
	_waited += delta
	if _waited >= SHOW_DELAY_S:
		show_tip(_candidate)


## Shows the tip of `glyph` now (after the wait; tests call it directly).
func show_tip(glyph: TipTarget) -> void:
	_shown = glyph
	_candidate = glyph
	_place(glyph)
	_tip.visible = true
	if _pop != null:
		_pop.kill()
		_pop = null
	if _wants_reduced_motion() or not is_inside_tree():
		_tip.scale = Vector2.ONE
		return
	_tip.scale = Vector2.ONE * POP_FROM
	_pop = create_tween()
	_pop.tween_property(_tip, "scale", Vector2.ONE, POP_S)


func hide_tip() -> void:
	_shown = null
	_tip.visible = false
	if _pop != null:
		_pop.kill()
		_pop = null


## The tip (its text, place and tail), shown or not.
func tip() -> GlyphTip:
	return _tip


## The target (a glyph, a ticket's colour) whose tip shows, or null.
func shown_glyph() -> TipTarget:
	return _shown if _tip.visible else null


## The topmost target (a glyph over a ticket's colour) this serves under `at` (viewport
## coordinates), or null.
func glyph_at(at: Vector2) -> TipTarget:
	var found: TipTarget = null
	for node: Node in get_tree().get_nodes_in_group(TipTarget.GROUP):
		var glyph: TipTarget = node as TipTarget
		if glyph == null or not _serves(glyph, at):
			continue
		if found == null or glyph.is_greater_than(found):
			found = glyph
	return found


## Whether `glyph` is this one's, shown, under `at` (inside every clipping ancestor: a glyph
## scrolled out of a ScrollContainer, or outside a sliding page, shows nothing), and not covered
## by a control that takes the pointer (one later in the tree that is not its ancestor).
func _serves(glyph: TipTarget, at: Vector2) -> bool:
	if not is_instance_valid(glyph) or not glyph.is_inside_tree() or not glyph.is_shown():
		return false
	if _scope_of(glyph) != self:
		return false
	if not glyph.get_global_rect().has_point(at) or is_clipped(glyph, at):
		return false
	var hovered: Control = get_viewport().gui_get_hovered_control()
	if hovered == null or hovered.is_ancestor_of(glyph):
		return true
	return glyph.is_greater_than(hovered)


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
	_tip.show_for(glyph.tip_text, glyph_rect, anchor, glyph.tip_below, screen)


func _is_blocked() -> bool:
	if blocked.is_valid() and bool(blocked.call()):
		return true
	return Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT)


func _wants_reduced_motion() -> bool:
	return reduced_motion.is_valid() and bool(reduced_motion.call())
