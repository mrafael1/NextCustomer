class_name BoosterOpenings
extends RefCounted
## YOUR STORE's boosters (BoosterPage, v1.32; since v1.40 the aisle board throws them,
## AisleRoulette, and they wait sealed on the counter until the player opens each one: a click on
## its pouch, its number key or Enter for the next one; the user's play test of 2026-11-19, round
## 2): each booster's opening beats on its own clock
## (BoosterOpening's plan: the tear, the rise, the note ladder, the hit card's tremble, a RARE's
## freeze and pop) and the skip. Every rule goes through the page's StartBoardActions; the state
## lives on the page.

var page: BoosterPage


func _init(owner_page: BoosterPage) -> void:
	page = owner_page


## Plays the running openings on `dt` (each at its boost) and fires their beats; slides picked
## boosters to their zones.
func step(dt: float) -> void:
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


## The next booster to open (Enter): the leftmost one sealed on the counter, or null.
func next_sealed() -> BoosterOpening:
	if page.roulette.busy():
		return null
	for opening: BoosterOpening in page.shown_boosters():
		if opening.state == BoosterOpening.State.SEALED and page.roulette.landed(opening):
			return opening
	return null


## Opens booster `index` (a click on its pouch sealed on the counter, its number key, Enter).
func open_booster(index: int, via: String = "click") -> bool:
	if index < 0 or index >= page.boosters.size():
		return false
	var opening: BoosterOpening = page.boosters[index]
	if opening.state != BoosterOpening.State.SEALED:
		return false
	if not page.roulette.landed(opening):
		return false
	return open_now(opening, false) and via != ""


## Booster `opening` opens (`fast`: at the skip's pace): saved at once, then its opening plays
## with the hit card flipped for the player. A failed save leaves it sealed on the counter, where a
## click tries again.
func open_now(opening: BoosterOpening, fast: bool) -> bool:
	if opening.state != BoosterOpening.State.SEALED:
		return false
	if page.actions == null or not page.actions.open_booster.call(opening.index):
		page.flash("COULD NOT SAVE. TRY AGAIN")
		return false
	_start_open(opening, fast, true, 0.0)
	if fast:
		opening.boost = page.tuning.boost
	StartBoardActions.emit(
		page.actions, TutorialEvents.BOOSTER_OPENED, {TutorialEvents.ARG_INDEX: opening.index}
	)
	return true


func _start_open(opening: BoosterOpening, fast: bool, auto_hit: bool, offset: float) -> void:
	opening.state = BoosterOpening.State.OPENING
	opening.lt = -offset - 0.0001
	opening.boost = 1.0
	opening.open_order = page.opened_n
	page.opened_n += 1
	opening.build_plan(page.tuning, fast, auto_hit, page.rm)
	page.restock_armed = false


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
	return page.roulette.busy()


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
	var pouch: Vector2 = opening.pouch_pos()
	if opening.rm:
		if _crossed(a, z, 0.0):
			page.fx.sfx("rip", -4.0, 1.0 + 0.05 * opening.open_order)
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
	var at: Vector2 = opening.fan_pos(k)
	opening.land_t[k] = page.now
	if opening.notes[k] < 0:
		opening.notes[k] = page.flip_n
		page.flip_n += 1
	var note: int = opening.notes[k]
	var foot: float = (
		at.y + opening.card_h() if opening.in_row() else float(BoosterArt.COUNTER_Y + 3)
	)
	page.cart_n = page.cart_target()
	page.cart_punch_s = 1.22 if beat == BoosterOpening.Beat.RARE else 1.06
	if beat == BoosterOpening.Beat.COMMON:
		page.fx.sfx("tick", -10.0)
		page.fx.note(note, -6.0)
		page.fx.dust(at.x + BoosterArt.CW / 2.0, foot, 2)
	elif beat == BoosterOpening.Beat.HEAVY:
		page.fx.sfx("card_place_4", -4.0)
		page.fx.note(note, -6.0)
		page.fx.dust(at.x + BoosterArt.CW / 2.0, foot, 4)
	else:
		page.rare_n += 1
		page.fx.note(note, -4.0, true)
		page.fx.cue(page.now + 0.10, page.fx.note.bind(note + 2, -4.0, true))
		page.fx.cue(page.now + 0.22, page.fx.note.bind(note + 4, -4.0, true))
		page.fx.cue(page.now + 0.30, page.fx.sfx.bind("armed", -6.0))
		page.fx.sfx("stamp_notice", -4.0)
		if not opening.rm:
			page.shake_t = page.now
			page.fx.sparkles(at.x, at.y, BoosterArt.CW, opening.card_h(), page.now + 0.05, 0.15)
	if waiting_booster() == null:
		page.set_hint("")


func all_open() -> bool:
	if not page.run.start_setup.all_open():
		return false
	for opening: BoosterOpening in page.boosters:
		if opening.state != BoosterOpening.State.OPEN:
			return false
	return true
