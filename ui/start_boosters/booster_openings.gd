class_name BoosterOpenings
extends RefCounted
## YOUR STORE's boosters (BoosterPage, v1.32): the arrival (ROLL UP, the lamps, the drops), each
## booster's opening beats on its own clock (BoosterOpening's plan: the tear, the rise, the note
## ladder, the hit card's wait, a RARE's freeze and pop), OPEN ALL and the skip, and PICK 2 OF 3.
## Every rule goes through the page's StartBoardActions; the state lives on the page.

var page: BoosterPage


func _init(owner_page: BoosterPage) -> void:
	page = owner_page


## Plays the running openings on `dt` (each at its boost) and fires their beats; slides picked
## boosters to their zones.
func step(dt: float) -> void:
	update_moves()
	for opening: BoosterOpening in page.boosters:
		if opening.state != BoosterOpening.State.OPENING:
			continue
		var before: float = opening.lt
		opening.lt += dt * opening.boost
		_fire_events(opening, before, opening.lt)
		if opening.lt >= opening.plan_end(page.tuning):
			opening.state = BoosterOpening.State.OPEN
			opening.boost = 1.0
		elif opening.boost > 1.0 and opening.at_rest(page.tuning):
			opening.boost = 1.0
			_reveal(opening, opening.waiting_k())


## Whether the store is still arriving (the shutter, the walk-in, the boosters' first drops).
func arrival_busy() -> bool:
	if page.shutter == BoosterPage.Shutter.DOWN:
		return false
	for opening: BoosterOpening in page.boosters:
		if (
			opening.state == BoosterOpening.State.SEALED
			and not opening.restocked
			and page.now < opening.drop_t + page.tuning.drop_s
		):
			return true
	return page.shutter == BoosterPage.Shutter.ROLLING


## ROLL UP: the shutters roll up, the view walks in, the lamps come on one after another and each
## booster drops under its lamp.
func roll_up() -> bool:
	if page.shutter != BoosterPage.Shutter.DOWN:
		return false
	page.shutter = BoosterPage.Shutter.ROLLING
	page.shutter_t = page.now
	page.fx.sfx("rattle_m", -6.0)
	page.fx.sfx("ui_click", -10.0)
	var t0: float = (
		page.now + (0.0 if page.rm else page.tuning.shutter_up_s + page.tuning.walk_in_s)
	)
	if not page.rm:
		page.fx.cue(
			page.now + page.tuning.shutter_up_s, page.fx.sfx.bind("ui_open", -10.0), "arrival"
		)
	var k: int = 0
	for opening: BoosterOpening in page.boosters:
		if opening.state == BoosterOpening.State.GONE:
			continue
		opening.lamp_on = t0 + (0.0 if page.rm else k * page.tuning.lamp_gap_s)
		opening.drop_t = opening.lamp_on + (-1.0 if page.rm else 0.05)
		if not page.rm:
			page.fx.cue(opening.lamp_on, page.fx.sfx.bind("tick", -10.0), "arrival")
			page.fx.cue(opening.drop_t + page.tuning.drop_s, _landed_drop.bind(opening), "arrival")
		k += 1
	page.fx.cue(
		t0 + page.tuning.shutter_up_s + page.tuning.walk_in_s,
		func() -> void: page.shutter = BoosterPage.Shutter.UP,
		"arrival_end"
	)
	if page.rm:
		page.shutter = BoosterPage.Shutter.UP
	return true


func _landed_drop(opening: BoosterOpening) -> void:
	page.fx.sfx("card_place", -6.0)
	page.fx.dust(opening.cx, BoosterArt.COUNTER_Y + 3, 2)


## Skips the arrival to its end (a click, Enter): every lamp on, every booster down, no late cues.
func end_arrival() -> void:
	if page.shutter == BoosterPage.Shutter.DOWN:
		roll_up()
	page.shutter = BoosterPage.Shutter.UP
	page.shutter_t = -INF
	for opening: BoosterOpening in page.boosters:
		opening.lamp_on = minf(opening.lamp_on, page.now - 1.0)
		if opening.state == BoosterOpening.State.SEALED and not opening.restocked:
			opening.drop_t = minf(opening.drop_t, page.now - 1.0)
	page.fx.drop_cues("arrival")


## Whether a counted booster is still sealed.
func any_sealed() -> bool:
	for opening: BoosterOpening in page.boosters:
		if opening.state == BoosterOpening.State.SEALED and opening.is_counted():
			return true
	return false


## Opens booster `index` (a click or 1-2): saved at once, then its opening plays.
func open_booster(index: int, via: String = "click") -> bool:
	if index < 0 or index >= page.boosters.size() or page.picking():
		return false
	var opening: BoosterOpening = page.boosters[index]
	if opening.state != BoosterOpening.State.SEALED or not opening.is_counted():
		return false
	if page.now < opening.drop_t + page.tuning.drop_s and not page.rm:
		end_arrival()
	if page.actions == null or not page.actions.open_booster.call(index):
		page.flash("COULD NOT SAVE. TRY AGAIN")
		return false
	_start_open(opening, false, false, 0.0)
	page.set_hint("WAIT FOR THE ? CARD" if opening.hits.has(true) else "")
	return via != ""


func _start_open(opening: BoosterOpening, fast: bool, auto_hit: bool, offset: float) -> void:
	opening.state = BoosterOpening.State.OPENING
	opening.lt = -offset - 0.0001
	opening.boost = 1.0
	opening.open_order = page.opened_n
	page.opened_n += 1
	opening.build_plan(page.tuning, fast, auto_hit, page.rm)
	page.restock_armed = false


## OPEN ALL: every sealed booster (saved), tears tuning.open_all_tear_s apart, the hits queued last
## within open_all_cap_s and flipped for you.
func open_all(via: String = "key") -> bool:
	if page.shutter == BoosterPage.Shutter.DOWN:
		roll_up()
	if page.shutter != BoosterPage.Shutter.UP:
		end_arrival()
	if page.picking():
		page.flash("PICK %d BOOSTERS FIRST" % page.run.balance.dealt_aisle_count)
		return false
	for opening: BoosterOpening in page.boosters:
		if opening.state == BoosterOpening.State.OPENING:
			for k: int in opening.waits.size():
				if opening.waits[k]:
					_reveal(opening, k)
	var sealed: Array[BoosterOpening] = []
	for opening: BoosterOpening in page.boosters:
		if opening.state == BoosterOpening.State.SEALED and opening.is_counted():
			if page.actions != null and page.actions.open_booster.call(opening.index):
				sealed.append(opening)
	if sealed.is_empty():
		return false
	var specials: Array[Array] = []
	var queue_start: float = 0.0
	for i: int in sealed.size():
		var offset: float = 0.0 if page.rm else i * page.tuning.open_all_tear_s
		_start_open(sealed[i], true, true, offset)
		queue_start = maxf(queue_start, offset + sealed[i].plain_end + page.tuning.flip_s)
		for k: int in sealed[i].specials:
			specials.append([sealed[i], k, offset])
	if not page.rm and not specials.is_empty():
		var cap: float = page.tuning.open_all_cap_s - page.tuning.flip_s - page.tuning.rare_rest_s
		var gap: float = 0.0
		if specials.size() > 1:
			gap = minf(
				page.tuning.open_all_gap_s, maxf(0.0, (cap - queue_start) / (specials.size() - 1))
			)
		var g: float = queue_start + 0.05
		for j: int in specials.size():
			if j > 0:
				var previous: Array = specials[j - 1]
				var was_rare: bool = (previous[0] as BoosterOpening).rares[previous[1] as int]
				g = g + page.tuning.flip_s + 0.4 if was_rare else minf(g + gap, maxf(g, cap))
			var entry: Array = specials[j]
			var target: BoosterOpening = entry[0]
			target.flip_at[entry[1] as int] = g - (entry[2] as float)
			target.antic[entry[1] as int] = g - (entry[2] as float) - 0.05
	page.set_hint("")
	return via != ""


## Plays every running opening `boost` times as fast (a skip); false when none runs.
func boost_all() -> bool:
	var any: bool = false
	for opening: BoosterOpening in page.boosters:
		if opening.state == BoosterOpening.State.OPENING and not opening.at_rest(page.tuning):
			opening.boost = page.tuning.boost
			any = true
	return any


## Whether an opening is still playing (a skip has something to speed up).
func opening_now() -> bool:
	for opening: BoosterOpening in page.boosters:
		if opening.state == BoosterOpening.State.OPENING and not opening.at_rest(page.tuning):
			return true
	return page.tote_cards.size() > 0


## The opening whose hit card waits for its click at rest, or null.
func waiting_booster() -> BoosterOpening:
	for opening: BoosterOpening in page.boosters:
		if opening.state == BoosterOpening.State.OPENING and opening.waiting_k() >= 0:
			return opening
	return null


## Flips the waiting hit card of booster `index` (its click).
func flip_hit(index: int) -> bool:
	if index < 0 or index >= page.boosters.size():
		return false
	var opening: BoosterOpening = page.boosters[index]
	if opening.state != BoosterOpening.State.OPENING or not opening.at_rest(page.tuning):
		return false
	return _reveal(opening, opening.waiting_k())


func _reveal(opening: BoosterOpening, k: int) -> bool:
	if not opening.reveal_hit(k):
		return false
	page.fx.sfx("ui_click", -8.0)
	page.set_hint("")
	return true


func _fire_events(opening: BoosterOpening, a: float, z: float) -> void:
	var pouch: Vector2 = BoosterArt.pouch_pos(opening.cx)
	if opening.rm:
		if _crossed(a, z, 0.0):
			page.fx.sfx("rip", -4.0, 1.0 + 0.05 * opening.open_order)
			_light_shelf(opening)
	else:
		if _crossed(a, z, 0.0):
			page.fx.sfx("card_pickup", -4.0)
		if _crossed(a, z, page.tuning.grab_s):
			page.fx.sfx("rattle_s", -8.0)
		if _crossed(a, z, page.tuning.rattle_end_s):
			page.fx.sfx("rip", -2.0, 1.0 + 0.05 * opening.open_order)
		if _crossed(a, z, page.tuning.burst_s):
			page.fx.scraps(
				pouch.x + BoosterArt.BW / 2.0, pouch.y + 8, BoosterArt.ramp(opening.aisle)
			)
			opening.flash_t = page.now
			opening.lamp_hot_t = page.now
			_light_shelf(opening)
		if _crossed(a, z, page.tuning.rise_start_s):
			page.fx.sfx("fan", -6.0)
	for k: int in opening.cards.size():
		var f: float = opening.flip_at[k]
		if _crossed(a, z, opening.antic[k]):
			_anticipate(opening, k)
		if f == INF:
			continue
		if (
			not opening.rm
			and opening.beats[k] == BoosterOpening.Beat.RARE
			and _crossed(a, z, f + page.tuning.flip_s / 2.0 - 0.02)
		):
			var hold: float = (
				0.04
				if opening.boost > 1.0
				else (
					0.06
					if opening.fast
					else page.tuning.freeze_s - (0.08 if page.rare_n >= 2 else 0.0)
				)
			)
			if not page.frozen:
				page.hitstop_until = Time.get_ticks_msec() + roundi(maxf(0.04, hold) * 1000.0)
		if _crossed(a, z, f + page.tuning.flip_s):
			_land(opening, k)


static func _crossed(a: float, z: float, at: float) -> bool:
	return a < at and at <= z


func _anticipate(opening: BoosterOpening, k: int) -> void:
	var count: int = 4 if opening.restocked else 3
	for i: int in count:
		page.fx.cue(page.now + i * 0.05, page.fx.sfx.bind("slot_tick", -6.0))
	page.set_hint("CLICK THE ? CARD" if opening.waits[k] else "· · ·")


func _land(opening: BoosterOpening, k: int) -> void:
	var beat: BoosterOpening.Beat = opening.beats[k]
	var at: Vector2 = BoosterArt.fan_pos(opening.cx, k)
	opening.land_t[k] = page.now
	if opening.notes[k] < 0:
		opening.notes[k] = page.flip_n
		page.flip_n += 1
	var note: int = opening.notes[k]
	page.cart_n = page.cart_target()
	page.cart_punch_s = 1.22 if beat == BoosterOpening.Beat.RARE else 1.06
	if beat == BoosterOpening.Beat.COMMON:
		page.fx.sfx("tick", -10.0)
		page.fx.note(note, -6.0)
		page.fx.dust(at.x + BoosterArt.CW / 2.0, BoosterArt.COUNTER_Y + 3, 2)
	elif beat == BoosterOpening.Beat.HEAVY:
		page.fx.sfx("card_place_4", -4.0)
		page.fx.note(note, -6.0)
		page.fx.dust(at.x + BoosterArt.CW / 2.0, BoosterArt.COUNTER_Y + 3, 4)
	else:
		page.rare_n += 1
		page.fx.note(note, -4.0, true)
		page.fx.cue(page.now + 0.10, page.fx.note.bind(note + 2, -4.0, true))
		page.fx.cue(page.now + 0.22, page.fx.note.bind(note + 4, -4.0, true))
		page.fx.cue(page.now + 0.30, page.fx.sfx.bind("armed", -6.0))
		page.fx.sfx("stamp_notice", -4.0)
		if not opening.rm:
			page.shake_t = page.now
			page.fx.sparkles(at.x, at.y, BoosterArt.CW, BoosterArt.CH, page.now + 0.05, 0.15)
	if waiting_booster() == null:
		page.set_hint("")


func _light_shelf(opening: BoosterOpening) -> void:
	var zone: int = BoosterArt.zone_of(opening.cx)
	page.shelf_on[zone] = page.now
	page.shelf_off[zone] = -INF


func update_moves() -> void:
	for opening: BoosterOpening in page.boosters:
		if opening.move_t0 == INF:
			continue
		var u: float = 1.0
		if opening.move_s > 0.0:
			u = clampf((page.now - opening.move_t0) / opening.move_s, 0.0, 1.0)
		elif page.now < opening.move_t0:
			u = 0.0
		var e: float = 1.0 - pow(1.0 - u, 3.0)
		opening.cx = (
			opening.move_to
			if u >= 1.0
			else opening.move_from + roundf((opening.move_to - opening.move_from) * e / 4.0) * 4.0
		)
		if u >= 1.0:
			opening.move_t0 = INF


## PICK 2 OF 3: picks booster `index`; the second pick keeps the pair (saved), the third booster
## gets SOLD OUT, its lamp goes dark and pulls up, and the pair slides to the two zones.
func pick_booster(index: int) -> bool:
	if not page.picking() or index < 0 or index >= page.boosters.size():
		return false
	var opening: BoosterOpening = page.boosters[index]
	if opening.picked or opening.state == BoosterOpening.State.GONE:
		return false
	var picked: Array[int] = []
	for other: BoosterOpening in page.boosters:
		if other.picked:
			picked.append(other.index)
	if picked.size() + 1 >= page.run.balance.dealt_aisle_count:
		var pair: Array[int] = picked.duplicate()
		pair.append(index)
		if page.actions == null or not page.actions.pick_boosters.call(pair):
			page.flash("COULD NOT SAVE. TRY AGAIN")
			return false
	opening.picked = true
	opening.pick_t = page.now
	opening.lamp_hot_t = page.now
	page.fx.sfx("card_pickup_1", -4.0)
	page.fx.sfx("stamp_1", -10.0)
	if picked.size() + 1 < page.run.balance.dealt_aisle_count:
		page.set_hint("PICK %d MORE" % (page.run.balance.dealt_aisle_count - picked.size() - 1))
		return true
	_resolve_pick()
	return true


func _resolve_pick() -> void:
	var r: float = 0.0 if page.rm else 1.0
	var kept: Array[BoosterOpening] = []
	for opening: BoosterOpening in page.boosters:
		if page.run.start_setup.boosters[opening.index].sold_out:
			opening.sold_t = page.now + 0.25 * r
			opening.lamp_off = page.now + 0.35 * r
			opening.sink_t = page.now + 0.9 * r
			page.fx.cue(page.now + 0.25 * r, page.fx.sfx.bind("stamp_notice", -4.0))
			page.fx.cue(
				page.now + 1.35 * r, func() -> void: opening.state = BoosterOpening.State.GONE
			)
		elif opening.state != BoosterOpening.State.GONE:
			kept.append(opening)
	kept.sort_custom(func(a: BoosterOpening, b: BoosterOpening) -> bool: return a.cx < b.cx)
	var move_at: float = page.now + page.tuning.pick_move_at_s * r
	page.pick_settle_t = move_at
	for k: int in kept.size():
		kept[k].move_from = kept[k].cx
		kept[k].move_to = [BoosterArt.ZONE_A, BoosterArt.ZONE_B][mini(k, 1)]
		kept[k].move_t0 = move_at
		kept[k].move_s = page.tuning.pick_sink_s * r
		kept[k].picked = false
	page.fx.cue(move_at, page.fx.sfx.bind("card_place_2", -8.0))
	page.set_hint("")


## Whether the counter still wears PICK 2 OF 3's dress (three plates; no RESTOCK, tote or board):
## while picking, and after the second pick until the kept pair starts its slide
## to the two aisle places (BoosterPage.pick_settle_t), so the dress changes with the boosters.
func pick_layout() -> bool:
	return page.picking() or page.now < page.pick_settle_t


func all_open() -> bool:
	if page.picking() or not page.run.start_setup.all_open():
		return false
	for opening: BoosterOpening in page.boosters:
		if opening.is_counted() and opening.state != BoosterOpening.State.OPEN:
			return false
	return true
