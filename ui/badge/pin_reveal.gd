class_name PinReveal
extends Control
## The results' unlock cards (the achievement unlock mock-up of 2026-11-05,
## docs/art/mockups/achievement_unlock.html: the user's picks, look A "Pin card" and reveal R3
## "Spotlight"): until now a pin a run unlocked just showed as owned the next time the badge screen
## opened. Once the final receipt has printed (ResultsPanel), each pin the run unlocked
## (PinUnlockNews) gets a PinUnlockCard, one after another: the screen dims under the card (the
## spotlight shade, over the whole window), the card slides in face down to the window's centre,
## flips over, its pin pops into the blister, the UNLOCKED stamp lands and shakes, sparkles blink;
## it holds there, then slides to its place in the free space right of the receipt as the shade
## lifts. Every card is CARD_MS long, GAP_MS after the receipt and after each other.
##
## The landed cards stack in their place, the newest on top, at most PEEKS older ones peeking
## PEEK_PX each above it, darkened. Once every card has landed, a pager ("‹ 1 / 3 ›") and the next
## milestone still locked ("Next: Repack · Win a run") show under the stack; a click on the stack
## or on ‹ › brings the next or the last card to the top. Settled, a glint crosses the top card's
## pin every GLINT_EVERY_MS (off under reduced motion).
##
## While a card is coming the shade takes every click: a click, or Space, Enter or Escape, shows
## every remaining card at once in its final place (finish). Return to menu, while a card is still
## to come, does the same and stays (ResultsPanel): a second press leaves, so a player clicking
## through never misses an unlock. Under reduced
## motion each card appears in its place, GAP_MS apart, with no shade, slide, flip, pop, shake nor
## sparkle. Sounds: the card's pickup as it comes, its place at the flip, a ding as the pin pops,
## the stamp family's thump and its return as it leaves. The toy machines' aisle completions keep
## their own presentation (the user's call of 2026-11-05): this shows badge pins only.

const GAP_MS := 300
const CARD_MS := 2900
## A card's beats, in ms from its start: it arrives face down, flips, holds, then leaves for its
## place in the stack (the last LEAVE_MS), the shade fading in over SHADE_IN_MS and out with it.
const ARRIVE_MS := 250
const FLIP_MS := 250
const LEAVE_MS := 300
const SHADE_IN_MS := 200
const POP_AT_MS := 940
const POP_MS := 200
const STAMP_AT_MS := 1160
const STAMP_MS := 120
const SHAKE_MS := 120
const SHAKE_STEP_MS := 30
const SHAKE_PX := 4.0
const SPARKLE_AT_MS := 1200
const SPARKLE_MS := 500
## The spotlight shade's alpha at its darkest.
const SHADE_ALPHA := 0.62
## The arriving card starts this far past the window's right edge.
const ARRIVE_FROM_PX := 20.0
const PX := 2.0
const PEEK_PX := 10.0
const PEEKS := 2
## The least gap to the window's edges.
const EDGE := 16.0
## The pager's and the next milestone's rows under the stack.
const PAGER_GAP := 10.0
const PAGER_HEIGHT := 26.0
const NEXT_HEIGHT := 34.0
const NEXT_WIDTH := PinUnlockCard.CARD_SIZE.x  # The stack's width: never over the receipt.
const SPARKLE := preload("res://art/effects/sparkle.png")
## The sparkles round the card, as fractions of its rect grown by SPARKLE_MARGIN.
const SPARKLE_SPOTS: Array[Vector2] = [
	Vector2(0.08, 0.1), Vector2(0.95, 0.22), Vector2(0.04, 0.7), Vector2(0.9, 0.86)
]
const SPARKLE_MARGIN := 12.0
const SKIP_KEYS: Array[Key] = [KEY_SPACE, KEY_ENTER, KEY_KP_ENTER, KEY_ESCAPE]
## Each card's sounds, at these ms from its start (CUE_SOUNDS).
const CUE_MS: Array[int] = [0, ARRIVE_MS, POP_AT_MS, STAMP_AT_MS, CARD_MS - LEAVE_MS]
const CUE_SOUNDS: Array[String] = ["card_pickup", "card_place", "ding", "stamp", "card_return"]
const LAND_SOUND := "card_place"
## The settled top card's glint: one GLINT_MS crossing every GLINT_EVERY_MS.
const GLINT_EVERY_MS := 3000
const GLINT_MS := 600

## The time in ms (Time.get_ticks_msec() unless a test replaces it).
var clock: Callable = Time.get_ticks_msec
var _receipt: Control
## Returns whether the receipt is still printing: the cards wait for it.
var _printing: Callable
var _reduced: bool = false
var _news: PinUnlockNews
var _cards: Array[PinUnlockCard] = []
## When the first card starts (clock ms), or -1 before the receipt has printed.
var _start_ms: int = -1
var _skipped: bool = false
var _settled: bool = false
## When every card had landed (clock ms), for the glint.
var _settled_ms: int = 0
## The window's size at the last full refresh, and whether a call since needs another.
var _laid_size: Vector2 = Vector2(-1, -1)
var _dirty: bool = true
## How many cards had landed at the last refresh.
var _landed: int = 0
## The card on top once every card has landed.
var _top: int = 0
## Per card, how many of its cues have played.
var _cues: Array[int] = []
var _shade: float = 0.0
## The sparkles' rect and progress (0 to 1; outside: none).
var _sparkle_rect: Rect2 = Rect2()
var _sparkle_t: float = -1.0
var _pager: Label
var _back_arrow: Label
var _on_arrow: Label
var _next: Label


func _init() -> void:
	name = "PinReveal"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_pager = UiKit.number_label("", 16, true)
	_pager.name = "Pager"
	_pager.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_pager.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	add_child(_pager)
	_back_arrow = _arrow("‹", -1)
	_on_arrow = _arrow("›", 1)
	_next = UiKit.body_label("", 12, Palette.TEAL_PALE)
	_next.name = "NextMilestone"
	_next.add_theme_font_override("font", ArtStyle.bold_font(600))
	_next.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_next.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_next.custom_minimum_size = Vector2(NEXT_WIDTH, 0)
	add_child(_next)
	_show_pager(false)


## The receipt the stack stands right of, and `printing`, which returns whether it is still
## printing.
func setup(receipt: Control, printing: Callable) -> void:
	_receipt = receipt
	_printing = printing


## Starts showing `news`' cards (null or empty: none), once the receipt has printed.
func show_news(news: PinUnlockNews, reduced_motion: bool) -> void:
	for card: PinUnlockCard in _cards:
		remove_child(card)
		card.queue_free()
	_cards = []
	_cues = []
	_news = news
	_reduced = reduced_motion
	_start_ms = -1
	_skipped = false
	_landed = 0
	_settled = news == null or news.is_empty()
	_shade = 0.0
	_sparkle_t = -1.0
	if news != null:
		for index: int in range(news.cards.size()):
			var card: PinUnlockCard = PinUnlockCard.new()
			card.show_unlock(news.cards[index])
			card.visible = false
			card.gui_input.connect(_on_card_input)
			add_child(card)
			_cards.append(card)
			_cues.append(0)
		_top = news.cards.size() - 1
		_next.text = news.next_text
	_show_pager(false)
	_dirty = true
	refresh()


## Shows every remaining card at once in its final place (a click, a skip key, Return to menu).
func finish() -> void:
	if _settled:
		return
	_skipped = true
	if _start_ms < 0:
		_start_ms = clock.call()
	_play(LAND_SOUND)
	_dirty = true
	refresh()


## Whether a card is still to come or coming (from the results' show until the last has landed).
func is_revealing() -> bool:
	return not _settled


func cards() -> Array[PinUnlockCard]:
	return _cards


## The card on top of the stack (null without cards), or the one coming.
func top_card() -> PinUnlockCard:
	if _cards.is_empty():
		return null
	var top: PinUnlockCard = _cards[_top]
	for card: PinUnlockCard in _cards:
		if card.visible and card.get_index() > top.get_index():
			top = card
	return top


## Brings the next card (`step` 1) or the last one (-1) to the top, once every card has landed.
func turn(step: int) -> void:
	if not _settled or _cards.size() < 2:
		return
	_top = posmod(_top + step, _cards.size())
	_play(LAND_SOUND)
	_dirty = true
	refresh()


## The spotlight shade's alpha now (0: none).
func shade_alpha() -> float:
	return _shade


## Where a card is revealed: the window's centre.
func centre_rect() -> Rect2:
	var at: Vector2 = ((size - PinUnlockCard.CARD_SIZE) / 2.0).snapped(Vector2.ONE * PX)
	return Rect2(at, PinUnlockCard.CARD_SIZE)


## The stack's top card's place: centred in the free space right of the receipt (never past the
## window's edge), the stack with its pager and next milestone centred on the window's height.
func slot_rect() -> Rect2:
	var card: Vector2 = PinUnlockCard.CARD_SIZE
	var right: float = size.x / 2.0
	if _receipt != null:
		right = _receipt.position.x + _receipt.size.x
	var x: float = right + floorf((size.x - right - card.x) / 2.0 / PX) * PX
	x = clampf(x, EDGE, size.x - EDGE - card.x)
	var peeks: int = mini(_cards.size() - 1, PEEKS)
	var block: float = peeks * PEEK_PX + card.y + _below_height()
	var y: float = snappedf((size.y - block) / 2.0, PX) + peeks * PEEK_PX
	return Rect2(Vector2(x, y), card)


## The pager "1 / 3" (for tests and layout checks; hidden with one card).
func pager() -> Label:
	return _pager


## The next milestone's line (for tests and layout checks).
func next_line() -> Label:
	return _next


## Lays the cards out for the time now (each frame until settled; then on a resize, a turn or
## a new show).
func refresh() -> void:
	_laid_size = size
	_dirty = false
	if _cards.is_empty():
		_shade = 0.0
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		queue_redraw()
		return
	var now: int = clock.call()
	if _start_ms < 0:
		if _printing.is_valid() and bool(_printing.call()):
			return
		_start_ms = now + GAP_MS
	var length: int = 0 if _reduced else CARD_MS
	var elapsed: int = now - _start_ms
	var landed: Array[int] = []
	var active: int = -1
	for index: int in range(_cards.size()):
		var local: int = elapsed - index * (length + GAP_MS)
		if _skipped or (local >= 0 and local >= length):
			landed.append(index)
		elif local >= 0:
			active = index
		_cards[index].visible = _skipped or local >= 0
	if _reduced and not _skipped and landed.size() > _landed:
		_play(LAND_SOUND)  # Under reduced motion a card just appears in its place.
	_landed = landed.size()
	var was_settled: bool = _settled
	_settled = landed.size() == _cards.size()
	if _settled and not was_settled:
		_top = _cards.size() - 1
		_settled_ms = now
	_stack(landed)
	_shade = 0.0
	_sparkle_t = -1.0
	if active >= 0:
		_animate(active, elapsed - active * (length + GAP_MS))
	var blocking: bool = not _settled and elapsed >= 0 and not _reduced
	mouse_filter = Control.MOUSE_FILTER_STOP if blocking else Control.MOUSE_FILTER_IGNORE
	_show_pager(_settled)
	_glint(now)
	queue_redraw()


func _process(_delta: float) -> void:
	if not is_visible_in_tree():
		return
	if _settled and not _dirty and size == _laid_size:
		if not _cards.is_empty():
			_glint(clock.call())
		return
	refresh()


func _gui_input(event: InputEvent) -> void:
	var button: InputEventMouseButton = event as InputEventMouseButton
	if button != null and button.pressed and button.button_index == MOUSE_BUTTON_LEFT:
		finish()
		accept_event()


func _input(event: InputEvent) -> void:
	var key: InputEventKey = event as InputEventKey
	if key == null or not key.pressed or key.echo or not is_visible_in_tree():
		return
	if mouse_filter == Control.MOUSE_FILTER_STOP and SKIP_KEYS.has(key.keycode):
		finish()
		get_viewport().set_input_as_handled()


func _draw() -> void:
	if _shade > 0.0:
		draw_rect(Rect2(Vector2.ZERO, size), Color(Palette.CHARCOAL, _shade))
	if _sparkle_t < 0.0 or _sparkle_t > 1.0:
		return
	for spot: int in range(SPARKLE_SPOTS.size()):
		var local: float = _sparkle_t * 4.0 - spot * 0.5
		if local < 0.0 or local > 1.4 or floori(local * 6.0) % 2 == 1:
			continue
		var at: Vector2 = _sparkle_rect.position + _sparkle_rect.size * SPARKLE_SPOTS[spot]
		var art: Rect2 = Rect2(at.snapped(Vector2.ONE * PX), SPARKLE.get_size() * PX)
		draw_texture_rect(SPARKLE, art, false)


## The settled top card's glint at `now` (the others none).
func _glint(now: int) -> void:
	var top: int = _top if _settled else -1
	for index: int in range(_cards.size()):
		var progress: float = -1.0
		if index == top and not _reduced:
			progress = float(posmod(now - _settled_ms, GLINT_EVERY_MS)) / GLINT_MS
		_cards[index].set_glint(progress)


## Puts the landed cards in the stack: the top one in its place, at most PEEKS older ones peeking
## above it, darkened a step each, the rest hidden under it. While cards are coming the newest
## landed is on top; once all have landed, _top (turn).
func _stack(landed: Array[int]) -> void:
	if landed.is_empty():
		return
	var top: int = _top if _settled else landed[-1]
	var under: Array[int] = []
	if _settled:
		for step: int in range(1, _cards.size()):
			under.append(posmod(top + step, _cards.size()))
	else:
		under.assign(landed.slice(0, landed.size() - 1))
	var slot: Rect2 = slot_rect()
	var peeking: Array[int] = under.slice(maxi(under.size() - PEEKS, 0))
	for index: int in under:
		_cards[index].visible = peeking.has(index)
	for place: int in range(peeking.size()):
		var depth: int = peeking.size() - place
		_land(_cards[peeking[place]], slot.position - Vector2(0, depth * PEEK_PX), depth)
	_land(_cards[top], slot.position, 0)


func _land(card: PinUnlockCard, at: Vector2, depth: int) -> void:
	card.position = at
	card.scale = Vector2.ONE
	card.show_back(false)
	card.set_pop(1.0)
	card.set_stamp(1.0)
	card.set_depth(depth)
	card.mouse_filter = (
		Control.MOUSE_FILTER_STOP if _settled and depth == 0 else Control.MOUSE_FILTER_IGNORE
	)
	move_child(card, -1)


## The card coming, `local` ms into its CARD_MS: arriving face down, flipping, holding with its
## pin popping and stamp landing, then leaving for its place in the stack; the shade under it.
func _animate(index: int, local: int) -> void:
	var card: PinUnlockCard = _cards[index]
	var centre: Vector2 = centre_rect().position
	var at: Vector2 = centre
	var width: float = 1.0
	var back: bool = false
	if local < ARRIVE_MS:
		var from: float = size.x + ARRIVE_FROM_PX
		at.x = lerpf(from, centre.x, _ease_out(float(local) / ARRIVE_MS))
		back = true
	elif local < ARRIVE_MS + FLIP_MS:
		var turned: float = float(local - ARRIVE_MS) / FLIP_MS
		var full: float = PinUnlockCard.CARD_SIZE.x
		width = maxf(snappedf(full * absf(cos(turned * PI)), PX), PX) / full
		back = turned < 0.5
	elif local >= CARD_MS - LEAVE_MS:
		var leaving: float = float(local - (CARD_MS - LEAVE_MS)) / LEAVE_MS
		at = centre.lerp(slot_rect().position, _ease_out(leaving))
	card.position = at.snapped(Vector2.ONE * PX)
	card.scale = Vector2(width, 1.0)
	card.show_back(back)
	card.set_depth(0)
	card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.set_pop(clampf(float(local - POP_AT_MS) / POP_MS, 0.0, 1.0))
	var shake_ms: int = local - STAMP_AT_MS - STAMP_MS
	var shake: float = 0.0
	if shake_ms >= 0 and shake_ms < SHAKE_MS:
		shake = SHAKE_PX if floori(float(local) / SHAKE_STEP_MS) % 2 == 1 else -SHAKE_PX
	card.set_stamp(clampf(float(local - STAMP_AT_MS) / STAMP_MS, 0.0, 1.0), shake)
	move_child(card, -1)
	var light: float = 1.0
	if local < SHADE_IN_MS:
		light = float(local) / SHADE_IN_MS
	elif local > CARD_MS - LEAVE_MS:
		light = float(CARD_MS - local) / LEAVE_MS
	_shade = SHADE_ALPHA * clampf(light, 0.0, 1.0)
	_sparkle_rect = Rect2(card.position, PinUnlockCard.CARD_SIZE).grow(SPARKLE_MARGIN)
	_sparkle_t = float(local - SPARKLE_AT_MS) / SPARKLE_MS
	while _cues[index] < CUE_MS.size() and local >= CUE_MS[_cues[index]]:
		_play(CUE_SOUNDS[_cues[index]])
		_cues[index] += 1


## The pager's and next milestone's rows under the stack.
func _below_height() -> float:
	var height: float = 0.0
	if _cards.size() > 1:
		height += PAGER_GAP + PAGER_HEIGHT
	if _news != null and not _news.next_text.is_empty():
		height += PAGER_GAP + NEXT_HEIGHT
	return height


func _show_pager(on: bool) -> void:
	var paged: bool = on and _cards.size() > 1
	_pager.visible = paged
	_back_arrow.visible = paged
	_on_arrow.visible = paged
	_next.visible = on and _news != null and not _news.next_text.is_empty()
	if not on:
		return
	var slot: Rect2 = slot_rect()
	var y: float = slot.end.y + PAGER_GAP
	if paged:
		_pager.text = "%d / %d" % [_top + 1, _cards.size()]
		_pager.position = Vector2(slot.position.x, y)
		_pager.size = Vector2(slot.size.x, PAGER_HEIGHT)
		_back_arrow.position = Vector2(slot.position.x, y)
		_on_arrow.position = Vector2(slot.end.x - _on_arrow.size.x, y)
		y += PAGER_HEIGHT + PAGER_GAP
	var left: float = clampf(
		slot.get_center().x - NEXT_WIDTH / 2.0, EDGE, size.x - EDGE - NEXT_WIDTH
	)
	_next.position = Vector2(left, y)
	_next.size = Vector2(NEXT_WIDTH, NEXT_HEIGHT)


func _arrow(text: String, step: int) -> Label:
	var arrow: Label = UiKit.display_label(text, 24, false)
	arrow.name = "Turn%d" % step
	arrow.add_theme_color_override("font_color", Palette.TEAL_PALE)
	arrow.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	arrow.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	arrow.size = Vector2(PAGER_HEIGHT, PAGER_HEIGHT)
	arrow.mouse_filter = Control.MOUSE_FILTER_STOP
	arrow.gui_input.connect(
		func(event: InputEvent) -> void:
			var button: InputEventMouseButton = event as InputEventMouseButton
			if button != null and button.pressed and button.button_index == MOUSE_BUTTON_LEFT:
				turn(step)
	)
	add_child(arrow)
	return arrow


func _on_card_input(event: InputEvent) -> void:
	var button: InputEventMouseButton = event as InputEventMouseButton
	if button != null and button.pressed and button.button_index == MOUSE_BUTTON_LEFT:
		turn(1)


func _play(sound: String) -> void:
	var sfx: Sfx = Sfx.find(self)
	if sfx != null:
		sfx.play(sound)


static func _ease_out(progress: float) -> float:
	return 1.0 - pow(1.0 - clampf(progress, 0.0, 1.0), 3.0)
