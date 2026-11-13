class_name SwapWindow
extends RefCounted
## YOUR REGULARS, the swap window over YOUR STORE (BoosterPage; v1.32 swap window, the user's pick
## of 2026-11-13 on mock-up docs/art/mockups/start_regulars_swap.html, variant A "MODAL"): one
## swap booster per stocked aisle (StartSwapBoosters, opened with the page's own booster feel), the
## regulars in a big basket, and a card dragged (or clicked, then its slot clicked) onto a regular
## swaps it. The regular it replaces flies to the card's spot (OUT); drag it back, drag the item
## out of the basket, or RESET to undo. A card on a swapped slot trades places with the one there.
## The basket on page 1 opens it; while a swap is unused NEXT stops once and opens it too, and its
## DONE then goes on to YOUR BUILD. Every rule goes through the page's StartBoardActions (saved at
## once); the motion is cosmetic, on the page's clock. Geometry and drawing: SwapWindowDraw.

## A swap booster's index on its BoosterOpening (its hover ids never meet page 1's).
const INDEX0 := 100
## The drag's pointer travel (art px) under which a press and release is a click (it then follows
## the pointer until the next click: the click-then-click path).
const CLICK_SLOP := 3.0
## The tag of DONE's delayed go-on cue (dropped when the window opens again or NEXT goes on).
const GO_ON_TAG := "swap_go_on"

var page: BoosterPage
var active: bool = false
var open_t: float = -INF
var close_t: float = -INF
## Opened from NEXT (DONE goes on to YOUR BUILD); shown once on this page (NEXT no longer stops).
var from_next: bool = false
var seen: bool = false
## No swap unlocked when it opened: its boosters stay sealed under a padlock.
var locked: bool = false
var boosters: Array[BoosterOpening] = []
var pieces: Array[SwapPiece] = []
## The held piece, its grab offset (art px), whether it follows a click (not a held button).
var held: SwapPiece = null
var held_off: Vector2 = Vector2.ZERO
var sticky: bool = false
var press_at: Vector2 = Vector2.ZERO
## A refused drop: its slot (-1: none), its words, when.
var err_slot: int = -1
var err_text: String = ""
var err_t: float = -INF
## Each slot's pop (a landing), the SWAPS LEFT LED's blink and its number's pop.
var pop_t: Array[float] = []
var led_t: float = -INF
var left_t: float = -INF
var last_left: int = -1
## The slot under a held piece (-1: none) and since when.
var hover_slot: int = -1
var hover_t: float = -INF
## The regulars when it opened (DONE plays the changed ones into page 1's basket).
var before: Array[CardDefinition] = []
## The window's own particles (drawn over the veil) and its note ladder.
var fx: BoosterFx
var flip_n: int = 0
## The hint LED's line and when it started typing.
var hint_line: String = ""
var hint_t: float = 0.0
var _reasons: Dictionary[String, String] = {}
var _blocked: Dictionary[String, bool] = {}
var _cache_key: String = ""


func _init(owner_page: BoosterPage) -> void:
	page = owner_page
	fx = BoosterFx.new(owner_page)


## Whether the regulars can be swapped now: every page-1 booster open and STOCKED! come.
func is_live() -> bool:
	return page.run != null and page.counter.swaps_live()


## Whether NEXT stops on page 1 to open the window: a swap unlocked and unused, every booster
## open, and the window not shown yet on this page.
func wants_stop() -> bool:
	return (
		not seen
		and is_live()
		and StartSetupRules.swaps_left(page.run, page.profile) > 0
		and not page.picking()
	)


## Opens the window (the basket's click, or NEXT's stop when `next` is true): its boosters drop
## in sealed (or stand open, as saved), its offers drawn and saved the first time.
func open_window(next: bool = false) -> bool:
	if active or page.run == null:
		return false
	if page.picking():
		page.flash(
			(
				"PICK %d OF %d BOOSTERS"
				% [page.run.balance.dealt_aisle_count, page.run.balance.start_booster_choice_count]
			)
		)
		return false
	if not is_live():
		page.flash("OPEN THE BOOSTERS FIRST")
		return false
	page.fx.drop_cues(GO_ON_TAG)
	if page.restock_armed:
		page.cancel_restock("ui_close")
	if not _build():
		page.flash("COULD NOT SAVE. TRY AGAIN")
		return false
	active = true
	open_t = page.now
	from_next = next
	seen = true
	before = page.run.starter.core_cards.duplicate()
	err_slot = -1
	page.message = ""
	page.set_hint("")
	page.fx.sfx("ui_open", -6.0)
	page.fx.sfx("card_pickup_1", -10.0)
	return true


func _build() -> bool:
	var run: RunState = page.run
	locked = StartSetupRules.swap_limit(run, page.profile) <= 0
	var aisles: Array[StringName] = StartSwapBoosters.swap_aisles(run)
	var offers: Dictionary[StringName, Array] = {}
	if not locked and page.actions != null:
		offers = page.actions.swap_offers.call()
		if offers.is_empty() and not aisles.is_empty():
			return false
	boosters.clear()
	pieces.clear()
	held = null
	# RESTOCK and NEW PACKS change the cards the copy rule counts: fresh reasons each opening.
	_cache_key = ""
	_reasons.clear()
	_blocked.clear()
	pop_t.clear()
	for slot: int in run.starter.core_cards.size():
		pop_t.append(-INF)
	for bi: int in mini(aisles.size(), SwapWindowDraw.BOOSTER_CX.size()):
		var cards: Array[CardDefinition] = []
		for card: Variant in offers.get(aisles[bi], []):
			cards.append(card as CardDefinition)
		var opening: BoosterOpening = BoosterOpening.new(
			StartBooster.new(aisles[bi], cards, 0), INDEX0 + bi, SwapWindowDraw.BOOSTER_CX[bi]
		)
		opening.lamp_on = -10.0
		if run.start_setup.swap_opened.has(aisles[bi]):
			opening.show_open()
		else:
			opening.drop_t = page.now + (-1.0 if page.rm else bi * page.tuning.swap_drop_gap_s)
		boosters.append(opening)
		for k: int in cards.size():
			BoosterArt.face(cards[k], false)
			BoosterChromeDraw.sprite(cards[k])
			pieces.append(SwapPiece.new(false, cards[k], -1, bi, k))
	for slot: int in run.starter.core_cards.size():
		BoosterChromeDraw.sprite(run.start_setup.originals[slot])
		BoosterArt.face(run.start_setup.originals[slot], false)
		pieces.append(SwapPiece.new(true, run.start_setup.originals[slot], slot, -1, -1))
	for piece: SwapPiece in pieces:
		var rest: Dictionary = target(piece)
		piece.pos = rest.pos
		piece.item = rest.item
		piece.key = rest.key
	return true


## Whether the window shows (open, or sliding away).
func visible() -> bool:
	return active or page.now - close_t < page.tuning.swap_out_s


## The window's slide (art px down): in from 60 below, away down the screen; 0 at rest.
func slide() -> float:
	if page.rm:
		return 0.0
	if active:
		var u: float = clampf((page.now - open_t) / maxf(page.tuning.swap_in_s, 0.001), 0.0, 1.0)
		return BoosterPageDraw.stepped((1.0 - BoosterPageDraw.e_out(u)) * 60, 4)
	var v: float = clampf((page.now - close_t) / maxf(page.tuning.swap_out_s, 0.001), 0.0, 1.0)
	return BoosterPageDraw.stepped(BoosterPageDraw.e_in(v) * 340, 4)


## The veil's share of its full dark (0..1).
func veil() -> float:
	if active:
		return (
			1.0
			if page.rm
			else clampf((page.now - open_t) / maxf(page.tuning.swap_in_s, 0.001), 0.0, 1.0)
		)
	if page.rm:
		return 0.0
	return 1.0 - clampf((page.now - close_t) / maxf(page.tuning.swap_out_s, 0.001), 0.0, 1.0)


## Where `piece` rests now, from the run's regulars: {pos, item, key}.
func target(piece: SwapPiece) -> Dictionary:
	if piece.regular:
		var card: CardDefinition = page.run.starter.core_cards[piece.slot]
		if card != page.run.start_setup.originals[piece.slot]:
			for other: SwapPiece in pieces:
				if not other.regular and other.card == card:
					return _fan_rest(other)
		return _item_rest(piece.slot)
	var slot: int = slot_of(piece)
	return _item_rest(slot) if slot >= 0 else _fan_rest(piece)


func _fan_rest(piece: SwapPiece) -> Dictionary:
	return {
		"pos": SwapWindowDraw.fan_centre(piece.booster, piece.k),
		"item": false,
		"key": "fan%d_%d" % [piece.booster, piece.k]
	}


func _item_rest(slot: int) -> Dictionary:
	return {"pos": SwapWindowDraw.item_centre(slot), "item": true, "key": "slot%d" % slot}


## The slot a card piece is swapped into (-1: in its fan).
func slot_of(piece: SwapPiece) -> int:
	if piece.regular:
		return -1
	var core: Array[CardDefinition] = page.run.starter.core_cards
	for slot: int in core.size():
		if core[slot] == piece.card and page.run.start_setup.originals[slot] != piece.card:
			return slot
	return -1


## Moves the window on to the page's clock: the swap boosters' openings, the flights.
func step(dt: float) -> void:
	if not visible() or pieces.is_empty():
		return
	for opening: BoosterOpening in boosters:
		if opening.state != BoosterOpening.State.OPENING:
			continue
		var a: float = opening.lt
		opening.lt += dt * opening.boost
		_fire(opening, a, opening.lt)
		if opening.lt >= opening.plan_end(page.tuning):
			opening.state = BoosterOpening.State.OPEN
			opening.boost = 1.0
	for piece: SwapPiece in pieces:
		if piece != held:
			_fly(piece)
	var hs: int = SwapWindowDraw.slot_at(page.mouse - Vector2(0, slide())) if held != null else -1
	if hs != hover_slot:
		hover_slot = hs
		hover_t = page.now
		if hs >= 0:
			page.fx.sfx("ui_click_1", -14.0)
	var line: String = SwapWindowDraw.hint_text(page)
	if line != hint_line:
		hint_line = line
		hint_t = page.now
	var left: int = StartSetupRules.swaps_left(page.run, page.profile)
	if left != last_left:
		last_left = left
		left_t = page.now
	fx.prune(page.now)


func _fly(piece: SwapPiece) -> void:
	var rest: Dictionary = target(piece)
	if rest.key != piece.key:
		var dist: float = piece.pos.distance_to(rest.pos)
		var tuning: StartBoostersTuning = page.tuning
		var dur: float = clampf(
			tuning.swap_fly_min_s + dist / maxf(tuning.swap_fly_px_s, 1.0),
			tuning.swap_fly_min_s,
			tuning.swap_fly_max_s
		)
		dur = 0.001 if page.rm else dur + (tuning.swap_bounce_s if piece.bounce else 0.0)
		piece.fly = {
			"from": piece.pos,
			"from_item": piece.item,
			"from_sc": piece.sc,
			"to": rest.pos,
			"to_item": rest.item,
			"t0": page.now,
			"dur": dur,
			"bounce": piece.bounce,
			"arc": piece.item and not rest.item
		}
		piece.key = rest.key
		piece.bounce = false
	if not piece.fly.is_empty() and not piece.flying(page.now):
		var to_item: bool = piece.fly.to_item
		piece.pos = piece.fly.to
		if to_item and not piece.item:
			piece.land_t = page.now
		piece.item = to_item
		piece.sc = 1.0
		piece.fly = {}


## The pose of `piece` this frame: {pos, item, sc, held}.
func pose(piece: SwapPiece) -> Dictionary:
	if piece == held:
		var over: bool = page.mouse.y - slide() > SwapWindowDraw.ITEM_TOP - 10
		var m: Vector2 = page.mouse - Vector2(0, slide())
		return {
			"pos": (m - held_off * (0.6 if over else 1.0)).round(),
			"item": false,
			"sc": 0.6 if over else 1.05,
			"held": true
		}
	if piece.fly.is_empty():
		return {"pos": piece.pos, "item": piece.item, "sc": 1.0, "held": false}
	var f: Dictionary = piece.fly
	var u: float = clampf((page.now - (f.t0 as float)) / (f.dur as float), 0.0, 1.0)
	var eased: float = BoosterPageDraw.e_back(u, 1.4) if f.bounce else BoosterPageDraw.e_out(u)
	var at: Vector2 = (f.from as Vector2).lerp(f.to, eased)
	if f.arc:
		at.y -= sin(u * PI) * 38
	var result: Dictionary = {"pos": at, "item": f.to_item, "sc": 1.0, "held": false}
	if not f.from_item and f.to_item:
		result = {"pos": at, "item": false, "sc": lerpf(f.from_sc, 0.5, BoosterPageDraw.e_in(u))}
	elif f.from_item and not f.to_item:
		result = (
			{"pos": at, "item": true, "sc": 1.0}
			if u < 0.3
			else {
				"pos": at,
				"item": false,
				"sc": lerpf(0.5, 1.0, BoosterPageDraw.e_out((u - 0.3) / 0.7))
			}
		)
	elif not f.to_item:
		result.sc = lerpf(f.from_sc, 1.0, BoosterPageDraw.e_out(u))
	result["held"] = false
	return result


## A press at art point `at` (the window's own, the slide taken off): drops a click-held piece,
## grabs a piece, or acts on the key under it.
func press(at: Vector2) -> void:
	if held != null and sticky:
		_drop(at, false)
		return
	for k: int in range(page.hits.size() - 1, -1, -1):
		var entry: Dictionary = page.hits[k]
		if not (entry.rect as Rect2).has_point(at + Vector2(0, slide())):
			continue
		var piece: SwapPiece = entry.get("piece") as SwapPiece
		if piece != null:
			_grab(piece, at)
		elif (entry.act as Callable).is_valid():
			(entry.act as Callable).call()
		return


## The button let go at `at`: a drag drops there; a click (no travel) keeps the piece held until
## the next click.
func release(at: Vector2) -> void:
	if held == null or sticky:
		return
	if at.distance_to(press_at) < CLICK_SLOP:
		sticky = true
		page.set_hint("")
		return
	_drop(at, false)


## Esc: a held piece goes home (a swapped item back to its slot, still swapped), else the window
## closes (without going on). True when used.
func escape() -> bool:
	if held != null:
		_drop(page.mouse - Vector2(0, slide()), true)
		return true
	if active:
		close(false)
		return true
	return false


func _grab(piece: SwapPiece, at: Vector2) -> void:
	if held != null or piece.flying(page.now):
		return
	held = piece
	held_off = at - piece.pos
	press_at = at
	sticky = false
	if piece.item:
		piece.item = false
		piece.sc = 0.5
	err_slot = -1
	page.fx.sfx("card_pickup_%d" % (1 + piece.slot % 3 if piece.regular else 1 + piece.k % 3), -6.0)


func _drop(at: Vector2, cancel: bool) -> void:
	var piece: SwapPiece = held
	var where: Dictionary = pose(piece)
	piece.pos = where.pos
	piece.sc = where.sc
	piece.item = false
	var via: String = "click" if sticky else "drag"
	held = null
	sticky = false
	piece.key = ""
	var slot: int = -1 if cancel else SwapWindowDraw.slot_at(at)
	if cancel or _is_home(piece, slot):
		# Back where it rests (a swapped item to its own slot): no rule call, nothing changes.
		page.fx.sfx("card_place_1", -10.0)
		return
	if slot < 0:
		var from: int = slot_of(piece)
		if from >= 0:
			_undo(from, via)
		else:
			page.fx.sfx("card_place_1", -10.0)
		return
	var why: String = drop_reason(piece, slot)
	if why != "":
		_refuse(slot, why)
		piece.bounce = true
		return
	_apply(piece, slot, via)


## Whether `piece` is a swapped-in item over its own slot (dropping it there changes nothing).
func _is_home(piece: SwapPiece, slot: int) -> bool:
	return slot >= 0 and not piece.regular and slot_of(piece) == slot


## Why `piece` can't go on basket slot `slot` ("" when it can): the refusal words shown.
func drop_reason(piece: SwapPiece, slot: int) -> String:
	var key: String = "%d:%d" % [pieces.find(piece), slot]
	_check_cache()
	if _reasons.has(key):
		return _reasons[key]
	var why: String = ""
	if piece.regular:
		if slot != piece.slot:
			why = "BACK TO ITS SPOT"
		elif (
			page.run.starter.core_cards[slot] != page.run.start_setup.originals[slot]
			and not StartSetupRules.can_restore(page.run, slot)
		):
			why = "%d IN THE CART" % page.run.starter.copy_max
	else:
		var from: int = slot_of(piece)
		if from != slot:
			why = _words(StartSetupRules.swap_block(page.run, page.profile, slot, piece.card, from))
	_reasons[key] = why
	return why


func _words(block: StringName) -> String:
	if block == &"":
		return ""
	var words: Dictionary[StringName, String] = {
		&"locked": "SWAPS LOCKED",
		&"swaps": "NO SWAPS LEFT",
		&"copies": "%d IN THE CART" % page.run.starter.copy_max,
		&"slot": "SAME ITEM",
	}
	return words.get(block, "OPEN THE BOOSTERS FIRST")


## Whether a fan card fits no basket slot under the copy limit (dimmed, "2 IN THE CART").
func blocked(piece: SwapPiece) -> bool:
	if piece.regular or slot_of(piece) >= 0 or locked:
		return false
	_check_cache()
	var key: String = String(piece.card.id)
	if not _blocked.has(key):
		_blocked[key] = not StartSwapBoosters.placeable(page.run, page.profile, piece.card)
	return _blocked[key]


func _check_cache() -> void:
	var ids: PackedStringArray = []
	for card: CardDefinition in page.run.starter.core_cards:
		ids.append(String(card.id))
	var key: String = ",".join(ids)
	if key != _cache_key:
		_cache_key = key
		_reasons.clear()
		_blocked.clear()


func _apply(piece: SwapPiece, slot: int, via: String) -> void:
	if piece.regular:
		_undo(slot, via)
		return
	var from: int = slot_of(piece)
	var traded: bool = page.run.starter.core_cards[slot] != page.run.start_setup.originals[slot]
	if page.actions == null or not page.actions.swap_staple.call(slot, piece.card, via, from):
		page.flash("COULD NOT SAVE. TRY AGAIN")
		piece.bounce = true
		return
	pop_t[slot] = page.now + 0.22
	page.fx.sfx("card_pickup_2", -8.0)
	page.fx.sfx("card_return_2" if traded else "card_return_1", -6.0, 1.05)
	page.fx.cue(page.now + 0.22, _landed.bind(slot))
	var note: int = 4 + StartSetupRules.applied_swaps(page.run)
	page.fx.cue(page.now + 0.3, page.fx.note.bind(note, -8.0))
	page.cart_punch_t = page.now
	page.cart_punch_s = 1.12


func _landed(slot: int) -> void:
	page.fx.sfx("card_place_2", -4.0)
	page.fx.sfx("tag", -6.0)
	var cx: float = SwapWindowDraw.slot_cx(slot)
	_dust(cx, SwapWindowDraw.FRONT_Y - 2, 4)
	if not page.rm:
		fx.sparkles(cx - 40, SwapWindowDraw.ITEM_TOP + 4, 80, 60, page.now + 0.02, 0.05)


func _dust(x: float, y: float, count: int) -> void:
	fx.dust(x, y, count)


## Puts swapped regular `slot` back (its OUT regular dragged home, or its item dragged out).
func _undo(slot: int, via: String) -> void:
	if not StartSetupRules.can_restore(page.run, slot):
		_refuse(slot, "%d IN THE CART" % page.run.starter.copy_max)
		return
	if page.actions == null or not page.actions.restore_regular.call(slot, via):
		page.flash("COULD NOT SAVE. TRY AGAIN")
		return
	pop_t[slot] = page.now + 0.2
	page.fx.sfx("card_return_2", -6.0)
	page.fx.cue(page.now + 0.2, _put_back.bind(slot))


func _put_back(slot: int) -> void:
	page.fx.sfx("card_place_1", -6.0)
	_dust(SwapWindowDraw.slot_cx(slot), SwapWindowDraw.FRONT_Y - 2, 3)


func _refuse(slot: int, why: String) -> void:
	err_slot = slot
	err_text = why
	err_t = page.now
	if why == "NO SWAPS LEFT":
		page.flash("NO SWAPS LEFT · DRAG ONE BACK TO UNDO")
	elif why == "SWAPS LOCKED":
		page.flash("SWAPS LOCKED · COMPLETE AN AISLE")
	else:
		page.flash(why)
	if why == "NO SWAPS LEFT" or why == "SWAPS LOCKED":
		led_t = page.now
	page.fx.sfx("card_return_2", -8.0, 0.9)


## RESET: every regular back to its original (saved).
func reset() -> bool:
	if held != null:
		_drop(page.mouse, true)
	if StartSetupRules.applied_swaps(page.run) == 0:
		page.flash("NOTHING TO RESET")
		return false
	if page.actions == null or not page.actions.reset_regulars.call():
		page.flash("COULD NOT SAVE. TRY AGAIN")
		return false
	page.fx.sfx("shuffle", -6.0)
	page.fx.cue(page.now + 0.24, page.fx.sfx.bind("card_place_3", -6.0))
	return true


## Swap booster `bi` (a click, 1-2): opens it (saved; it uses no swap), or speeds it up.
func open_booster(bi: int, via: String = "click") -> bool:
	if bi < 0 or bi >= boosters.size():
		return false
	if locked:
		_refuse(-1, "SWAPS LOCKED")
		return false
	var opening: BoosterOpening = boosters[bi]
	if opening.state == BoosterOpening.State.OPENING:
		opening.boost = page.tuning.boost
		return true
	if opening.state != BoosterOpening.State.SEALED:
		return false
	if page.actions == null or not page.actions.open_swap_booster.call(opening.aisle):
		page.flash("COULD NOT SAVE. TRY AGAIN")
		return false
	opening.drop_t = minf(opening.drop_t, page.now - page.tuning.drop_s)
	opening.state = BoosterOpening.State.OPENING
	opening.lt = -0.0001
	opening.boost = 1.0
	opening.build_plan(page.tuning, false, true, page.rm)
	return via != ""


func _fire(opening: BoosterOpening, a: float, z: float) -> void:
	var tuning: StartBoostersTuning = page.tuning
	var at: Vector2 = SwapWindowDraw.pouch_pos(opening.cx)
	if _crossed(a, z, 0.0):
		page.fx.sfx("card_pickup_%d" % (2 + opening.index % 2), -4.0)
	if not opening.rm:
		if _crossed(a, z, tuning.grab_s):
			page.fx.sfx("rattle_s", -8.0)
		if _crossed(a, z, tuning.rattle_end_s):
			page.fx.sfx("rip", -2.0, 1.0 + 0.05 * (opening.index - INDEX0))
		if _crossed(a, z, tuning.burst_s):
			fx.scraps(at.x + BoosterArt.BW / 2.0, at.y + 8, BoosterArt.ramp(opening.aisle))
			opening.flash_t = page.now
		if _crossed(a, z, tuning.rise_start_s):
			page.fx.sfx("fan", -6.0)
	for k: int in opening.cards.size():
		if _crossed(a, z, opening.flip_at[k] + tuning.flip_s):
			opening.land_t[k] = page.now
			page.fx.sfx("tick", -10.0)
			page.fx.note(flip_n, -6.0)
			flip_n += 1
			var centre: Vector2 = SwapWindowDraw.fan_centre(opening.index - INDEX0, k)
			_dust(centre.x, centre.y + BoosterArt.CH / 2.0 + 2, 2)


static func _crossed(a: float, z: float, at: float) -> bool:
	return a < at and at <= z


## Whether a swap booster is still opening.
func busy() -> bool:
	for opening: BoosterOpening in boosters:
		if opening.state == BoosterOpening.State.OPENING:
			return true
	return false


## DONE (its key, Enter): speeds up an opening; else closes, going on to YOUR BUILD when NEXT
## opened the window.
func primary(_via: String = "key") -> bool:
	if busy():
		for opening: BoosterOpening in boosters:
			if opening.state == BoosterOpening.State.OPENING:
				opening.boost = page.tuning.boost
		return true
	close(true)
	return true


## Closes the window (DONE: `go_on`; Esc and the close key: not): page 1's basket plays each
## changed regular in, one after the other; a window NEXT opened then goes on to YOUR BUILD.
func close(go_on: bool) -> void:
	if not active:
		return
	if held != null:
		_drop(page.mouse, true)
	for opening: BoosterOpening in boosters:
		if opening.state == BoosterOpening.State.OPENING:
			opening.lt = opening.plan_end(page.tuning)
			opening.state = BoosterOpening.State.OPEN
	active = false
	close_t = page.now
	page.fx.sfx("ui_close", -6.0)
	var tuning: StartBoostersTuning = page.tuning
	var n: int = 0
	for slot: int in page.run.starter.core_cards.size():
		if page.run.starter.core_cards[slot] == before[slot]:
			continue
		var t0: float = page.now
		if not page.rm:
			t0 += tuning.swap_play_in_at_s + n * tuning.swap_play_in_step_s
		page.swap_t[slot] = t0
		page.swap_from[slot] = before[slot]
		page.fx.cue(t0 + tuning.swap_play_in_s * 0.6, _thud.bind(slot))
		page.fx.cue(t0 + tuning.swap_play_in_s * 0.75, page.fx.sfx.bind("tag", -6.0))
		n += 1
	page.set_hint("")
	if go_on and from_next:
		page.fx.cue(page.now + (0.0 if page.rm else tuning.swap_next_hold_s), _go_on, GO_ON_TAG)


## DONE's go-on, once the play-in has had its moment: only while this window is still the page's,
## shut, and page 1 still done (not reopened, no RESTOCK armed, the board not left).
func _go_on() -> void:
	if page.swap != self or active or not from_next or page.run == null:
		return
	if not page.page_done() or page.restock_armed or page.picking():
		return
	page.press_next()


## Page 1's basket as a changed regular lands in it: its thud and dust.
func _thud(slot: int) -> void:
	page.fx.sfx("card_place_%d" % (1 + slot % 3), -4.0)
	page.fx.dust(BoosterChromeDraw.regular_x(slot) + 24, 222 + BoosterArt.DY, 3)
