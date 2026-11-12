class_name FamilyStickerFlow
extends RefCounted
## The Family sticker on the shift screen (v1.29, the user's answer 2 of 2026-11-11): a part of
## PinFlow, like the Price gun, working on the screen's run and display. The UI only shows what
## FamilySticker resolves and asks it to pick; it never decides a family itself.
## - Each Family sticker on the belt wears a family tag on its art's bottom left (TAG_NODE, clear
##   of the sticker stack and its WASTED plate on the art's right): a button in the family's
##   colours with its glyph centred, the family the sticker gives now (picked, preset or
##   pre-filled; FamilySticker.given on the planning preview). Its ticket reads it too ("Next joins
##   Breakfast", PriceSticker.sticker_family).
## - A click on the tag (or Enter on it: it takes the keyboard focus, shown by a light FOCUS_RING
##   on the dark belt) opens the Price gun's family picker above it (PriceGunPicker, with the
##   sticker's art and a title naming the next item), its current family marked and focused, the
##   families the next item already has dimmed (FamilySticker.held: picking one fizzles); a chip
##   picks (FamilySticker.pick), free and any number of times before CHECKOUT, kept across shifts
##   and saved with the run.
## - The item after it shows the family it gains as a gained glyph on its price sticker (as a Price
##   gun relabel does), from planning through the count-up.

const TITLE := "Family sticker: the next item joins"
## The title naming the next item.
const TITLE_ITEM := "Family sticker: %s joins"
const TAG_NODE := "FamilyStickerTag"
const TAG_SIZE := Vector2(34, 34)
## The tag's place on the sticker's art: its bottom left, a little out over the left and bottom
## edges.
const TAG_OUT := Vector2(4, 2)
## The keyboard focus ring: light, so it shows on the dark belt round the tag's ink rim.
const FOCUS_RING := Palette.MUSTARD_LIGHT
const TAG_TIP := "Family sticker: the next item joins %s · click to pick another family"
const PICKED := "Family sticker: the next item joins %s"
const ART := preload("res://art/icons/coupon_family_sticker_v2.png")

var _screen: ShiftScreen
var _log: EventLogService
var _picker: PriceGunPicker
## The sticker whose picker is open, or null.
var _open_card: CardInstance
## The families the belt's stickers give, by the instance id of the item gaining it: kept from the
## last planning refresh, so the count-up still shows them.
var _gains: Dictionary[int, String] = {}
## The family each belt sticker gives, by its instance id (for its tag), likewise.
var _gives: Dictionary[int, String] = {}


func _init(screen: ShiftScreen, event_log: EventLogService) -> void:
	_screen = screen
	_log = event_log


## Shows the stickers' tags for the run as it is now, and works out the families their items gain
## (gained_of; call before the Price gun's tags, which show them). Outside planning the last
## planning's stay (the count-up), their tags no longer clickable.
func refresh() -> void:
	var run: RunState = _screen.run
	if run == null:
		return
	var planning: bool = run.phase == RunState.Phase.PLANNING and not _screen._busy()
	if planning:
		_resolve(run)
	else:
		close_picker()
	for view: ItemView in _screen.item_views():
		_show_tag(view, _gives.get(view.card.instance_id, ""), planning)


## The family a belt sticker gives `card` (the item after it), or "".
func gained_of(card: CardInstance) -> String:
	return _gains.get(card.instance_id, "")


## The family picker, while open (for tests).
func picker() -> PriceGunPicker:
	return _picker


## The family tag on `view`'s sticker, or null.
static func tag_of(view: ItemView) -> Button:
	var tag: Button = view.sprite().get_node_or_null(TAG_NODE) as Button
	return tag if tag != null and not tag.is_queued_for_deletion() else null


## Opens the picker for the Family sticker `card` on the belt (its tag's click); false when it
## can't be picked now.
func open_picker(card: CardInstance) -> bool:
	var run: RunState = _screen.run
	var choices: PackedStringArray = FamilySticker.choices_now(run, card)
	if choices.is_empty() or _screen._busy():
		return false
	close_picker()
	var families: Array[FamilyStyle] = FamilyPalette.shared().styles(choices)
	var next: CardInstance = FamilySticker.next_item(run, card)
	var title: String = TITLE_ITEM % next.definition.display_name if next != null else TITLE
	_picker = PriceGunPicker.new(card.definition.display_name, families, false, ART, title)
	_open_card = card
	_picker.chosen.connect(func(tag: String) -> void: _pick(card, tag))
	_picker.dismissed.connect(_dismiss)
	_screen._overlay.add_child(_picker)
	var stage: Rect2 = _screen._stage.get_global_rect()
	var area: Rect2 = stage.grow_individual(
		-ShiftStage.COLUMN_RECT.end.x, -ShiftStage.PANEL_TOP, 0.0, 0.0
	)
	var window: Rect2 = _screen.get_viewport_rect()
	var monitor: Rect2 = _screen._stage.monitor.get_global_rect()
	var reduced: bool = _screen.profile != null and _screen.profile.reduced_motion()
	_picker.open_at(_view_rect(card), area.intersection(window), window, monitor, reduced, true)
	_picker.select(_gives.get(card.instance_id, ""))
	if next != null:
		_picker.mark_held(FamilySticker.held(run, card), next.definition.display_name)
	return true


func close_picker() -> void:
	if _picker != null:
		_picker.queue_free()
		_picker = null
	_open_card = null


## The families the belt's stickers give on the planning preview, and their items'.
func _resolve(run: RunState) -> void:
	_gains.clear()
	_gives.clear()
	var result: ScoreResult = run.preview()
	for slot: int in range(mini(run.row.size(), result.payouts.size())):
		var card: CardInstance = run.row[slot]
		if not FamilySticker.is_family_sticker(card.definition):
			continue
		var family: String = FamilySticker.given(result, slot)
		_gives[card.instance_id] = family
		for step: ScoreStep in result.steps:
			var gain: bool = step.step_type == ScoreStep.StepType.TAG_ADDED
			if gain and step.source_slot == slot and step.slot < run.row.size():
				_gains[run.row[step.slot].instance_id] = step.tag


## Puts `view`'s family tag on (`family`, clickable while `planning`) or takes it off ("").
func _show_tag(view: ItemView, family: String, planning: bool) -> void:
	var tag: Button = tag_of(view)
	var style: FamilyStyle = FamilyPalette.shared().style(family) if not family.is_empty() else null
	view.sticker().sticker_family = family if style != null else ""
	if style == null:
		if tag != null:
			view.sprite().remove_child(tag)
			tag.queue_free()
		return
	if tag == null or tag.get_meta("family", "") != family:
		if tag != null:
			view.sprite().remove_child(tag)
			tag.queue_free()
		tag = _new_tag(view.card, style)
		view.sprite().add_child(tag)
	tag.disabled = not planning
	tag.focus_mode = Control.FOCUS_ALL if planning else Control.FOCUS_NONE
	tag.mouse_default_cursor_shape = (
		Control.CURSOR_POINTING_HAND if planning else Control.CURSOR_ARROW
	)


## A sticker's family tag: a button in the family's face with its glyph and an ink rim.
func _new_tag(card: CardInstance, style: FamilyStyle) -> Button:
	var tag: Button = Button.new()
	tag.name = TAG_NODE
	tag.set_meta("family", style.id)
	tag.custom_minimum_size = TAG_SIZE
	tag.size = TAG_SIZE
	tag.position = Vector2(-TAG_OUT.x, ItemView.SPRITE_SIZE.y - TAG_SIZE.y + TAG_OUT.y)
	tag.tooltip_text = TAG_TIP % style.display_name
	tag.add_theme_stylebox_override("normal", _box(style.face, 2))
	tag.add_theme_stylebox_override("hover", _box(style.light, 2))
	tag.add_theme_stylebox_override("pressed", _box(style.shade, 2))
	tag.add_theme_stylebox_override("disabled", _box(style.face, 2))
	tag.add_theme_stylebox_override("focus", _focus_box())
	tag.pressed.connect(func() -> void: open_picker(card))
	if style.glyph != null:
		var glyph: FamilyGlyph = FamilyGlyph.new(style, true)
		glyph.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var centre: CenterContainer = CenterContainer.new()
		centre.name = "Centre"
		centre.mouse_filter = Control.MOUSE_FILTER_IGNORE
		tag.add_child(centre)
		centre.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		centre.add_child(glyph)
	return tag


static func _box(face: Color, border: int) -> StyleBoxFlat:
	var box: StyleBoxFlat = StyleBoxFlat.new()
	box.bg_color = face
	box.border_color = Palette.INK
	box.set_border_width_all(border)
	box.set_corner_radius_all(5)
	box.shadow_color = Color(Palette.INK, 0.35)
	box.shadow_offset = Vector2(0, 2)
	return box


static func _focus_box() -> StyleBoxFlat:
	var ring: StyleBoxFlat = StyleBoxFlat.new()
	ring.draw_center = false
	ring.border_color = FOCUS_RING
	ring.set_border_width_all(3)
	ring.set_corner_radius_all(6)
	ring.set_expand_margin_all(3.0)
	return ring


func _view_rect(card: CardInstance) -> Rect2:
	for view: ItemView in _screen.item_views():
		if view.card == card:
			var tag: Button = tag_of(view)
			return tag.get_global_rect() if tag != null else view.get_global_rect()
	return Rect2(_screen.get_viewport_rect().get_center(), Vector2.ZERO)


func _pick(card: CardInstance, tag: String) -> void:
	var run: RunState = _screen.run
	close_picker()
	if not FamilySticker.pick(run, card, tag):
		return
	_log.log_event(
		"family_sticker", {"shift": run.shift_index + 1, "card": card.instance_id, "family": tag}
	)
	_screen._sfx.play("ui_confirm")
	_screen._notice_label.show_notice(PICKED % tag)
	_screen._save_run()
	_screen._refresh()
	_focus_tag(card)


## Escape or a click outside: closes, the focus back on the sticker's tag.
func _dismiss() -> void:
	var card: CardInstance = _open_card
	close_picker()
	if card != null:
		_focus_tag(card)


func _focus_tag(card: CardInstance) -> void:
	for view: ItemView in _screen.item_views():
		var tag: Button = tag_of(view) if view.card == card else null
		if tag != null and tag.focus_mode != Control.FOCUS_NONE:
			tag.grab_focus.call_deferred()
