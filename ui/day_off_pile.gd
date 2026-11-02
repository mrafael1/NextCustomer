class_name DayOffPile
extends Control
## Day off's pile of gold on the belt (#132, the user's calls of 2026-11-02: "a pile of gold on
## conveyor with quota value", then "when clicking on skip, pile of gold spawns on 1st slot;
## checkout confirms; click the pile or the tag to cancel"). SKIP puts it on belt slot 1: the
## pile (gold_pile, drawn PILE_SCALE x) drops onto the slot's footprint with a bounce and the
## coins' clinks, then the quota's gold burst ("€80", PayTag's BOOSTED look) pops above it with
## a ka-ching. A click on it says `pressed` (PinFlow takes it back: lift). CHECKOUT cashes it
## (cash: the burst punches). Under reduced motion it is simply there, or gone. Decor only: the
## amount is the shift's quota, which the day passes on.

## The pile was clicked (to take the day off back).
signal pressed

const PILE := preload("res://art/scenery/gold_pile.png")
## The pile's texel size on screen (a belt item's: ArtStyle.ART_SCALE) and the burst's scale.
const PILE_SCALE := 2
const TAG_SCALE := 1.25
## How far above its rest it starts falling, and the fall's time.
const DROP_HEIGHT := 220.0
const DROP_TIME := 0.5
## The burst: its gap above the pile's top (negative: it overlaps the pile) and its pop.
const TAG_GAP := -8.0
const TAG_POP_TIME := 0.22
## The clinks as the pile lands or lifts: how many, their gap.
const CLINKS := 3
const CLINK_GAP := 0.07
## Taken back: how far it rises as it fades, and how long.
const LIFT_HEIGHT := 60.0
const LIFT_TIME := 0.22
## Cashed: the burst's punch.
const CASH_PUNCH := 1.3
const CASH_TIME := 0.25

var _pile: TextureRect
var _tag: PayTag
var _rest: Vector2 = Vector2.ZERO
var _tween: Tween


## A pile for a day passed on `quota` euros.
func _init(quota: int) -> void:
	name = "DayOffPile"
	mouse_filter = Control.MOUSE_FILTER_STOP
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	tooltip_text = "Day off: CHECKOUT takes it, a click takes it back"
	var pile_size: Vector2 = Vector2(PILE.get_size()) * PILE_SCALE
	_tag = PayTag.new(PlanningModel.Pay.BOOSTED, "€%d" % quota)
	var tag_size: Vector2 = _tag.size * TAG_SCALE
	size = Vector2(maxf(pile_size.x, tag_size.x), pile_size.y + tag_size.y + TAG_GAP)
	_pile = UiKit.sprite(PILE)
	_pile.name = "Pile"
	_pile.size = pile_size
	_pile.position = Vector2((size.x - pile_size.x) / 2.0, size.y - pile_size.y)
	add_child(_pile)
	_tag.position = Vector2((size.x - _tag.size.x) / 2.0, (tag_size.y - _tag.size.y) / 2.0)
	_tag.pivot_offset = _tag.size / 2.0
	_tag.scale = Vector2.ONE * TAG_SCALE
	add_child(_tag)
	gui_input.connect(_on_input)


## Rests the pile with its foot's middle at `foot` (its parent's coordinates, on the art grid).
func stand_at(foot: Vector2) -> void:
	_rest = Vector2(
		snappedf(foot.x - size.x / 2.0, ArtStyle.ART_SCALE),
		snappedf(foot.y - size.y, ArtStyle.ART_SCALE)
	)
	position = _rest


## The burst over the pile (for tests).
func tag() -> PayTag:
	return _tag


## Drops the pile onto its rest (stand_at) and pops the burst, with `sfx`'s sounds when given.
## Under `reduced` it is there at once, with the ka-ching.
func drop(reduced: bool, sfx: Sfx = null) -> void:
	_stop()
	if reduced or not is_inside_tree():
		position = _rest
		_tag.scale = Vector2.ONE * TAG_SCALE
		if sfx != null:
			sfx.play("kaching")
		return
	position = _rest - Vector2(0.0, DROP_HEIGHT)
	_tag.scale = Vector2.ZERO
	_tween = create_tween()
	(
		_tween
		. tween_property(self, "position", _rest, DROP_TIME)
		. set_trans(Tween.TRANS_BOUNCE)
		. set_ease(Tween.EASE_OUT)
	)
	if sfx != null:
		_tween.tween_callback(sfx.play_series.bind("coin", CLINKS, CLINK_GAP))
	(
		_tween
		. tween_property(_tag, "scale", Vector2.ONE * TAG_SCALE, TAG_POP_TIME)
		. set_trans(Tween.TRANS_BACK)
		. set_ease(Tween.EASE_OUT)
	)
	if sfx != null:
		_tween.parallel().tween_callback(sfx.play.bind("kaching"))


## Taken back: the pile rises and fades with the coins' clinks, then frees itself (at once
## under `reduced`).
func lift(reduced: bool, sfx: Sfx = null) -> void:
	_stop()
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	if sfx != null:
		sfx.play_series("coin", CLINKS, CLINK_GAP)
	if reduced or not is_inside_tree():
		queue_free()
		return
	_tween = create_tween().set_parallel()
	_tween.tween_property(self, "position", position - Vector2(0.0, LIFT_HEIGHT), LIFT_TIME)
	_tween.tween_property(self, "modulate:a", 0.0, LIFT_TIME)
	_tween.chain().tween_callback(queue_free)


## CHECKOUT took the day off: the pile settles at rest and its burst punches.
func cash(reduced: bool) -> void:
	_stop()
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	position = _rest
	_tag.scale = Vector2.ONE * TAG_SCALE
	if reduced or not is_inside_tree():
		return
	_tween = create_tween()
	_tween.tween_property(_tag, "scale", Vector2.ONE * TAG_SCALE * CASH_PUNCH, CASH_TIME / 2.0)
	_tween.tween_property(_tag, "scale", Vector2.ONE * TAG_SCALE, CASH_TIME / 2.0)


func _stop() -> void:
	if _tween != null:
		_tween.kill()
		_tween = null


func _on_input(event: InputEvent) -> void:
	var click: InputEventMouseButton = event as InputEventMouseButton
	if click != null and click.pressed and click.button_index == MOUSE_BUTTON_LEFT:
		accept_event()
		pressed.emit()
