class_name CartReveal
extends Control
## The start-of-run cart reveal (v0.51, decided with the user on 2026-10-23: variant A
## "dispenser" of mock-up cart_reveal_v1.html). A new run (not a resumed one) opens it over
## shift 1's planning: the 4 staples are already in the cart with their padlocks (known, never a
## surprise), then the dealt coupon and the 8 products drop out of the TODAY'S STOCK dispenser
## into the cart one by one, and it ends on the summary "CART 13/15 = 4 staples + 1 coupon + 8
## from today's stock" (RevealPanel). About 3 s; a tap (a click anywhere, Space, Enter or Esc)
## skips to the summary, and the next tap folds the panel into the Cart button (its ring
## flashes) and closes it: shift 1's planning goes on. Every timing is CartRevealTuning's
## (data/balance/cart_reveal.tres). With reduced motion it opens on the summary and the tap
## closes it at once.
##
## Who opens it: a new run the player starts (the title's New run or first start, the results'
## New run, the debug panel's new run with a seed). The title asks for it with request() before
## it opens the shift screen, whose reveal takes the request when it is made (`requested`), so a
## screen opened any other way (the tests, the captures) starts its new run without it, and a
## resumed run drops it.
##
## It takes every click and key while open, so nothing behind it can be planned; it dims the
## screen under the top bar (the Cart button stays lit for the fold). Pure display: the run is
## dealt and saved before it opens, so quitting during it resumes shift 1 without it. Its sounds
## play on the screen's Sfx (Sfx.find): ui_open, the padlocks' stamp, a tick as each pick leaves,
## card_place as a product lands (tag for the coupon), ding on the summary, shuffle on the fold.

signal finished

const TUNING_PATH := "res://data/balance/cart_reveal.tres"
## The dim under the top bar, over the store.
const DIM := Color(Palette.TEAL_BLACK, 0.82)
## The Cart button's ring during the fold: 3 px gold, ink outlined, 4 px outside the button.
const RING_WIDTH := 3.0
const RING_GAP := 4.0
## The fold's pivot, in fractions of the panel's size (towards the Cart button, top right).
const FOLD_PIVOT := Vector2(0.96, -0.06)
## The fold shrinks the panel to 1 - FOLD_SHRINK.
const FOLD_SHRINK := 0.9
const LOCK_DB := -12.0
const TICK_DB := -8.0
const LAND_DB := -4.0
const TAP_KEYS: Array[Key] = [KEY_SPACE, KEY_ENTER, KEY_KP_ENTER, KEY_ESCAPE]

static var _fonts: Dictionary[String, Font] = {}
## Set by the title (request) for the next reveal made.
static var _request: bool = false

var tuning: CartRevealTuning
## Whether the title asked for this reveal (request) before it was made.
var requested: bool = false
var reduced_motion: bool = false
var _panel: RevealPanel
## The 1280x720 stage the panel sits on, centred like ShiftStage.
var _stage: Control
## The Cart button the panel folds into (its global rect), or null.
var _cart: Control
var _t: float = 0.0
## The fold's time since the tap at the end; -1 before it.
var _outro: float = -1.0
var _frozen: bool = false
var _dim_alpha: float = 1.0
var _ring_alpha: float = 0.0


func _init() -> void:
	name = "CartReveal"
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false
	requested = _request
	_request = false
	tuning = load(TUNING_PATH) as CartRevealTuning
	_stage = Control.new()
	_stage.name = "Stage"
	_stage.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_stage.set_anchors_preset(Control.PRESET_CENTER)
	_stage.offset_left = -ShiftStage.SIZE.x / 2.0
	_stage.offset_top = -ShiftStage.SIZE.y / 2.0
	_stage.offset_right = ShiftStage.SIZE.x / 2.0
	_stage.offset_bottom = ShiftStage.SIZE.y / 2.0
	add_child(_stage)
	set_process(false)


## The title screen, before it opens the shift screen: the next reveal made is `requested`.
static func request() -> void:
	_request = true


## Opens the reveal for `run`'s dealt starting deck (a recipe's: a fixed deck has no picks and
## shows nothing; returns whether it opened), folding into `cart` at the end.
func play(run: RunState, cart: Control, reduced: bool) -> bool:
	close()
	var picks: Array[CardDefinition] = StartingDeck.picks(run.starter)
	if picks.is_empty():
		return false
	_cart = cart
	reduced_motion = reduced
	_panel = RevealPanel.new(
		run.starter.core_cards,
		picks,
		run.starter.copy_max,
		run.balance.deck_limit,
		run.shift_index + 1
	)
	_stage.add_child(_panel)
	_t = end_time() if reduced_motion else 0.0
	_outro = -1.0
	_frozen = false
	visible = true
	set_process(true)
	Sfx.play_at(self, "ui_open")
	if reduced_motion:
		Sfx.play_at(self, "ding")
	_render()
	return true


## Closes the reveal at once (a new run, a resume), with no fold and no signal.
func close() -> void:
	visible = false
	set_process(false)
	_outro = -1.0
	if _panel != null:
		_panel.queue_free()
		_panel = null


func is_open() -> bool:
	return visible


## The panel (for tests and captures), or null when closed.
func panel() -> RevealPanel:
	return _panel


## The time on the reveal's timeline (s), and when it is done (the summary shown).
func time() -> float:
	return _t


func end_time() -> float:
	return tuning.end_time(_panel.picks.size()) if _panel != null else 0.0


## Whether the panel is folding into the Cart button (after the tap at the end).
func is_folding() -> bool:
	return _outro >= 0.0


## A tap: before the end it skips to the summary; at the end it folds the panel into the Cart
## button (at once with reduced motion), then the reveal closes.
func tap() -> void:
	if not visible or _outro >= 0.0:
		return
	if _t < end_time() - 0.001:
		_t = end_time()
		Sfx.play_at(self, "ding")
		_render()
		return
	Sfx.play_at(self, "shuffle")
	if reduced_motion:
		_finish()
		return
	_outro = 0.0
	_render()


## Development tools and tests: shows the reveal at time `t` (and `outro` seconds into the fold
## when >= 0), frozen there.
func freeze_at(t: float, outro: float = -1.0) -> void:
	_frozen = true
	_t = t
	_outro = outro
	_render()


## Moves the timeline on by `seconds` (as _process does each frame).
func advance(seconds: float) -> void:
	if _panel == null:
		return
	if _outro >= 0.0:
		_outro += seconds
		if _outro >= tuning.outro_s:
			_finish()
			return
	else:
		var before: float = _t
		_t = minf(_t + seconds, end_time() + 3.0)
		_play_sounds(before, _t)
	_render()


func _process(delta: float) -> void:
	if not _frozen:
		advance(delta)


func _gui_input(event: InputEvent) -> void:
	var click: InputEventMouseButton = event as InputEventMouseButton
	if click != null and click.pressed and click.button_index == MOUSE_BUTTON_LEFT:
		accept_event()
		tap()


func _input(event: InputEvent) -> void:
	if not visible:
		return
	var key: InputEventKey = event as InputEventKey
	if key != null and key.pressed and not key.echo and TAP_KEYS.has(key.keycode):
		get_viewport().set_input_as_handled()
		tap()


func _finish() -> void:
	close()
	finished.emit()


## The sounds of the moments between `before` and `now` on the timeline.
func _play_sounds(before: float, now: float) -> void:
	var crossed: Callable = func(at: float) -> bool: return before < at and at <= now
	for index: int in _panel.staple_tiles.size():
		if crossed.call(tuning.lock_start_s + tuning.lock_gap_s * index):
			Sfx.play_at(self, "stamp", LOCK_DB)
	for index: int in _panel.picks.size():
		if crossed.call(tuning.pick_start(index)):
			Sfx.play_at(self, "tick", TICK_DB)
		if crossed.call(tuning.pick_land(index)):
			var coupon: bool = _panel.picks[index].is_coupon()
			Sfx.play_at(self, "tag" if coupon else "card_place", LAND_DB)
	if crossed.call(tuning.summary_start(_panel.picks.size())):
		Sfx.play_at(self, "ding")


func _render() -> void:
	if _panel == null:
		return
	_panel.show_at(_t, tuning)
	var pop: float = clampf(_t / tuning.pop_s, 0.0, 1.0) if tuning.pop_s > 0.0 else 1.0
	var panel_scale: float = 1.0 - tuning.pop_from + tuning.pop_from * ease_out_back(pop)
	var alpha: float = pop
	_dim_alpha = 1.0
	_ring_alpha = 0.0
	if _outro >= 0.0:
		var u: float = clampf(_outro / tuning.fold_s, 0.0, 1.0)
		panel_scale = 1.0 - FOLD_SHRINK * ease_out(u)
		alpha = 1.0 - u
		_dim_alpha = 1.0 - u
		var ring: float = (_outro - tuning.ring_start_s) / (tuning.outro_s - tuning.ring_start_s)
		_ring_alpha = sin(clampf(ring, 0.0, 1.0) * PI)
		_panel.pivot_offset = _panel.size * FOLD_PIVOT
	else:
		_panel.pivot_offset = _panel.size / 2.0
	_panel.scale = Vector2.ONE * panel_scale
	_panel.modulate.a = alpha
	queue_redraw()


func _draw() -> void:
	var top: float = _stage.position.y + ShiftStage.TOP_BAR_BOTTOM
	draw_rect(Rect2(0, top, size.x, size.y - top), Color(DIM, DIM.a * _dim_alpha))
	if _ring_alpha > 0.0 and _cart != null and is_instance_valid(_cart):
		var ring: Rect2 = get_global_transform().affine_inverse() * _cart.get_global_rect()
		ring = ring.grow(RING_GAP + RING_WIDTH / 2.0)
		draw_rect(ring.grow(RING_WIDTH / 2.0 + 1.0), Color(Palette.INK, _ring_alpha), false, 2.0)
		draw_rect(ring, Color(Palette.GOLD, _ring_alpha), false, RING_WIDTH)


## Bold Atkinson at `weight`, falling back to the mono font for marks it lacks (✓, ›).
static func font(weight: int) -> Font:
	return spaced_font(weight, 0)


## font(weight) with its glyphs `spacing` px apart (the mock-up's letter-spaced headings).
static func spaced_font(weight: int, spacing: int) -> Font:
	var key: String = "%d/%d" % [weight, spacing]
	if not _fonts.has(key):
		var variation: FontVariation = FontVariation.new()
		variation.base_font = ArtStyle.BODY_FONT
		var tag: int = TextServerManager.get_primary_interface().name_to_tag("wght")
		variation.variation_opentype = {tag: weight}
		variation.spacing_glyph = spacing
		var fallbacks: Array[Font] = [ArtStyle.MONO_FONT]
		variation.fallbacks = fallbacks
		_fonts[key] = variation
	return _fonts[key]


## `value` on the 2 px art grid.
static func snap(value: float) -> float:
	return roundf(value / ArtStyle.ART_SCALE) * ArtStyle.ART_SCALE


static func ease_out(u: float) -> float:
	return 1.0 - (1.0 - u) * (1.0 - u)


static func ease_out_back(u: float) -> float:
	var c: float = 1.70158
	return 1.0 + (c + 1.0) * pow(u - 1.0, 3.0) + c * pow(u - 1.0, 2.0)


## 1st, 2nd, 3rd, 4th ...
static func ordinal(number: int) -> String:
	var suffix: String = "th"
	if number % 100 < 11 or number % 100 > 13:
		match number % 10:
			1:
				suffix = "st"
			2:
				suffix = "nd"
			3:
				suffix = "rd"
	return "%d%s" % [number, suffix]
