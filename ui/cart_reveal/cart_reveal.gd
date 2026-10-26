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
##
## Hovering a card shows what it does (v0.54, decided with the user on 2026-10-23 after playing):
## once the pointer has stayed on a staple's tile or a landed pick's tile (the coupon's too) for
## the planning scanner's hold (ScanTuning.hold_ms, data/balance/scan.tres), the planning's scan
## popup (ScanPopup: name, tags and aisle, rule text) opens beside it over the panel, with the
## scanner's soft beep, during the animation and on the summary alike. A slot still waiting for
## its pick shows nothing (it is a surprise). The popup closes when the pointer leaves the tile,
## at the fold and when the reveal closes. Hovering never changes the tap: a click anywhere, on
## a tile or the popup too, still skips to the summary or folds the panel.
##
## The starter pack choice (#107, mock-up starter_choice_107.html layout A, decided with the user
## on 2026-10-26: Q1 C, Q2 A, Q3 B, Q4 A). A run waiting for its pick (RunState.CHOOSE_START)
## opens on the choice: the staples lock on, the offer's three packs drop in under them
## (PackChoice), today's shared products sit in the dispenser's window as pictures (each opens its
## popup on hover, as a pack's cards do), and the reveal waits. A click raises a pack (another
## changes it), 1 to 3 raise, and the push bar or Enter takes the raised one: pack_taken is
## emitted (the screen makes the deck and starts shift 1), then the pack's cards fly into the
## first picks from their places on its face and the shared products drop out of the dispenser
## as before. The good first pick (until the profile's first win) is raised from the start.
## During the packs' drop a tap jumps to the choice, never past it; during the choice a click off
## the packs and the bar, Space and Esc do nothing; after the pick a tap skips as before.

signal finished
## The player took `pack` from the starter pack choice (#107).
signal pack_taken(pack: StarterPackDefinition)

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
## The choice's keys (#107): 1 to 3 raise a pack, Enter takes it.
const RAISE_KEYS: Array[Key] = [KEY_1, KEY_2, KEY_3]
const TAKE_KEYS: Array[Key] = [KEY_ENTER, KEY_KP_ENTER]
## The planning scanner's hold (ms), unless `hover_hold_ms` is set.
const SCAN_TUNING_PATH := "res://data/balance/scan.tres"

static var _fonts: Dictionary[String, Font] = {}
## Set by the title (request) for the next reveal made.
static var _request: bool = false

var tuning: CartRevealTuning
## Whether the title asked for this reveal (request) before it was made.
var requested: bool = false
var reduced_motion: bool = false
## How long the pointer stays on a tile before its popup opens (ms).
var hover_hold_ms: int = 0
var _panel: RevealPanel
## The scan popup, over the panel, and the tile it shows (null: hidden); the tile under the
## pointer and how long it has stayed there (s).
var _popup: ScanPopup
## The popup's target and the target under the pointer: a RevealTile, or (the choice) a dispenser
## heap item.
var _shown_tile: Control
var _hover_tile: Control
var _hover_s: float = 0.0
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
## The starter pack offer being chosen from (#107), or null; whether the choice waits.
var _offer: StartOffer
var _choosing: bool = false
var _core: Array[CardDefinition] = []
var _copy_max: int = 0
var _deck_limit: int = 0
var _shift: int = 1


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
	_popup = ScanPopup.new()
	_popup.name = "ScanPopup"
	_popup.visible = false
	add_child(_popup)
	hover_hold_ms = (load(SCAN_TUNING_PATH) as ScanTuning).hold_ms
	set_process(false)


## The title screen, before it opens the shift screen: the next reveal made is `requested`.
static func request() -> void:
	_request = true


## Opens the reveal for `run`'s dealt starting deck (a recipe's: a fixed deck has no picks and
## shows nothing; returns whether it opened), folding into `cart` at the end.
## A run waiting for its starter pack (#107) opens on the choice instead.
func play(run: RunState, cart: Control, reduced: bool) -> bool:
	close()
	_cart = cart
	reduced_motion = reduced
	_core = run.starter.core_cards.duplicate()
	_copy_max = run.starter.copy_max
	_deck_limit = run.balance.deck_limit
	_shift = run.shift_index + 1
	_choosing = run.phase == RunState.Phase.CHOOSE_START and run.start_offer != null
	_offer = run.start_offer if _choosing else null
	var picks: Array[CardDefinition] = StartingDeck.picks(run.starter)
	if _choosing:
		var none: Array[CardDefinition] = []
		var from: Array[Vector2] = []
		_panel = RevealPanel.new(_core, none, _copy_max, _deck_limit, _shift, null, from, _offer)
	elif picks.is_empty():
		return false
	else:
		var from: Array[Vector2] = []
		_panel = RevealPanel.new(
			_core, picks, _copy_max, _deck_limit, _shift, run.starter.starter_pack, from
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
	_hover_tile = null
	_choosing = false
	_hide_popup()
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


## During the choice (#107): when the packs have dropped in and the choice waits.
func end_time() -> float:
	if _panel == null:
		return 0.0
	if _choosing:
		return PackChoice.ready_time(tuning, _offer.packs.size())
	return tuning.end_time(_panel.picks.size())


## Whether the starter pack choice waits for the pick (#107).
func is_choosing() -> bool:
	return visible and _choosing


## Raises pack `index` of the choice (#107; a click on its face, or its 1 to 3 key).
func raise_pack(index: int) -> void:
	if not is_choosing() or index < 0 or index >= _panel.choice.faces.size():
		return
	_skip_to_choice()
	if _panel.choice.raised_index != index:
		_panel.choice.raise(index)
		Sfx.play_at(self, "ui_click")
	_render()


## Takes the raised pack (#107; the push bar or Enter): emits pack_taken, then the pack's cards
## and today's products fly into the cart. False when no pack is raised.
func take_pack() -> bool:
	if not is_choosing():
		return false
	var pack: StarterPackDefinition = _panel.choice.raised_pack()
	if pack == null:
		return false
	var face: PackFace = _panel.choice.faces[_panel.choice.raised_index]
	var from: Array[Vector2] = []
	for tile: RevealTile in face.tiles:
		from.append(face.position + tile.position + RevealTile.SPRITE_POSITION * tile.scale)
	var shared: Array[CardDefinition] = _offer.shared.duplicate()
	_choosing = false
	_hover_tile = null
	_hide_popup()
	_panel.queue_free()
	_panel = RevealPanel.new(_core, pack.cards + shared, _copy_max, _deck_limit, _shift, pack, from)
	_stage.add_child(_panel)
	_t = end_time() if reduced_motion else tuning.pick_start_s
	Sfx.play_at(self, "ui_confirm")
	pack_taken.emit(pack)
	_render()
	return true


## During the packs' drop: jumps to the waiting choice.
func _skip_to_choice() -> void:
	if _choosing and _t < end_time() - 0.001:
		_t = end_time()
		_render()


## Whether the panel is folding into the Cart button (after the tap at the end).
func is_folding() -> bool:
	return _outro >= 0.0


## A tap: before the end it skips to the summary; at the end it folds the panel into the Cart
## button (at once with reduced motion), then the reveal closes.
func tap() -> void:
	if not visible or _outro >= 0.0:
		return
	if _choosing:
		# The choice never ends on a tap (#107): it only jumps to the waiting packs.
		_skip_to_choice()
		return
	if _t < end_time() - 0.001:
		_t = end_time()
		Sfx.play_at(self, "ding")
		_render()
		return
	Sfx.play_at(self, "shuffle")
	_hover_tile = null
	_hide_popup()
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
	elif _choosing:
		_t = minf(_t + seconds, end_time())
	else:
		var before: float = _t
		_t = minf(_t + seconds, end_time() + 3.0)
		_play_sounds(before, _t)
	_render()


func _process(delta: float) -> void:
	if not _frozen:
		advance(delta)
	hover_for(delta)


## The popup's tile (for tests and captures), or null when it is hidden (or shows a dispenser
## item).
func popup_tile() -> RevealTile:
	return _shown_tile as RevealTile


## The scan popup (for tests and captures).
func popup() -> ScanPopup:
	return _popup


## The tile under `point` (global) that can show its popup: a staple's, or a landed pick's
## (its tile shown); null over anything else, and while folding.
func tile_at(point: Vector2) -> RevealTile:
	if _panel == null or _outro >= 0.0:
		return null
	var tiles: Array[RevealTile] = _panel.staple_tiles + _panel.pick_tiles
	if _panel.choice != null:
		tiles.append_array(_panel.choice.tiles())
	for tile: RevealTile in tiles:
		if tile.is_visible_in_tree() and tile.get_global_rect().has_point(point):
			return tile
	return null


## What under `point` (global) can show its popup: a tile (tile_at), or during the choice (#107,
## Q2 A) one of today's products in the dispenser's window; null over anything else.
func target_at(point: Vector2) -> Control:
	var tile: RevealTile = tile_at(point)
	if tile != null or not _choosing or _panel == null:
		return tile
	var card: CardDefinition = _panel.dispenser.card_at(point)
	return _panel.dispenser.art_of(card) if card != null else null


## The pointer is over `tile` (a target_at target; null: none): another one starts its hold
## again, and leaving the shown one hides the popup.
func hover(tile: Control) -> void:
	if tile == _hover_tile:
		return
	_hover_tile = tile
	_hover_s = 0.0
	if tile != _shown_tile:
		_hide_popup()


## Moves the hover's hold on by `seconds` (as _process does each frame): the popup opens once the
## pointer has stayed on its tile for hover_hold_ms. A landed pick under a still pointer counts
## as hovered from its landing.
func hover_for(seconds: float) -> void:
	if not visible:
		return
	if _hover_tile == null and get_global_rect().has_point(get_global_mouse_position()):
		hover(target_at(get_global_mouse_position()))
	if _hover_tile == null or _hover_tile == _shown_tile:
		return
	_hover_s += seconds
	if _hover_s * 1000.0 >= hover_hold_ms:
		show_popup(_hover_tile)


## Opens the popup for `tile` (a target_at target) at once (the hold's end; development tools and
## tests).
func show_popup(tile: Control) -> void:
	var card: CardDefinition = _card_of(tile)
	if card == null:
		return
	_hover_tile = tile
	_shown_tile = tile
	_popup.visible = true
	_popup.show_card(card, card.tags)
	_place_popup()
	Sfx.play_at(self, ScanController.HOVER_SOUND, ScanController.HOVER_DB)


## Places the popup beside its tile over the panel, on the stage (ScanPopup.place_at).
func _place_popup() -> void:
	if _shown_tile == null or _panel == null:
		return
	var tile_rect: Rect2 = _shown_tile.get_global_rect()
	var stage_rect: Rect2 = _stage.get_global_rect()
	_popup.place_at(tile_rect, tile_rect, stage_rect, _panel.get_global_rect())


## The card a popup target shows: a tile's, or a dispenser item's.
func _card_of(target: Control) -> CardDefinition:
	var tile: RevealTile = target as RevealTile
	if tile != null:
		return tile.card
	if _panel == null:
		return null
	return _panel.dispenser.card_at(target.get_global_rect().get_center())


func _hide_popup() -> void:
	_shown_tile = null
	if _popup != null:
		_popup.visible = false


func _notification(what: int) -> void:
	if what == NOTIFICATION_MOUSE_EXIT:
		hover(null)


func _gui_input(event: InputEvent) -> void:
	var motion: InputEventMouseMotion = event as InputEventMouseMotion
	if motion != null:
		var point: Vector2 = get_global_transform() * motion.position
		hover(target_at(point))
		if is_choosing():
			_panel.choice.set_pointer(_panel.choice.face_at(point), _panel.choice.bar_has(point))
		return
	var click: InputEventMouseButton = event as InputEventMouseButton
	if click != null and click.pressed and click.button_index == MOUSE_BUTTON_LEFT:
		accept_event()
		if is_choosing():
			_click_choice(get_global_transform() * click.position)
			return
		tap()


## A click during the choice (#107): during the packs' drop it jumps to the choice; then a click on
## a pack raises it and one on the bar takes the raised pack; anywhere else does nothing.
func _click_choice(point: Vector2) -> void:
	if _t < end_time() - 0.001:
		_skip_to_choice()
		return
	var index: int = _panel.choice.face_at(point)
	if index >= 0:
		raise_pack(index)
	elif _panel.choice.bar_has(point):
		take_pack()


func _input(event: InputEvent) -> void:
	if not visible:
		return
	var key: InputEventKey = event as InputEventKey
	if key == null or not key.pressed or key.echo:
		return
	if is_choosing():
		if RAISE_KEYS.has(key.keycode):
			get_viewport().set_input_as_handled()
			raise_pack(RAISE_KEYS.find(key.keycode))
		elif TAKE_KEYS.has(key.keycode):
			get_viewport().set_input_as_handled()
			if _t < end_time() - 0.001:
				_skip_to_choice()
			else:
				take_pack()
		elif TAP_KEYS.has(key.keycode):
			# Space and Esc only jump to the choice.
			get_viewport().set_input_as_handled()
			_skip_to_choice()
		return
	if TAP_KEYS.has(key.keycode):
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
	_place_popup()
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
