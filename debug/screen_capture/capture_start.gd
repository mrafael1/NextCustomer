class_name CaptureStart
extends RefCounted
## The opening board's review states for the screen capture (full build plan 7.2; page 1 YOUR
## STORE, v1.32 boosters): --reveal=0,page=1|2,completed=0..6[,<option>...], the options:
## - do=<step>+<step>+...: page 1 played step by step on its own clock (frozen between steps, so
##   the capture shows that exact frame): roll (ROLL UP), t<seconds> (the clock moves on, in 1/60 s
##   steps), open<i>, flip<i> (the waiting hit card), all (OPEN ALL), arm (RESTOCK armed),
##   restock<i>, pick<i> (PICK 2 OF 3), hold (Space held), at<x>:<y> (the pointer at art px x,
##   y), primary; the swap window (v1.32): win (opened from the crate), sb<i> (its booster i
##   opened), grab<n> (piece n pressed where it rests: booster 0's cards, booster 1's, then the
##   regulars), over<k> (the pointer over basket slot k), drop (the button let go there), done
##   (DONE), esc; the file name gets the steps (do_<steps>_);
## - page 2 (YOUR BUILD, v1.32): pins=<n> leaves the catalogue's first n earned pins (those with an
##   unlock condition; the pins every profile starts with stay owned) unlocked and none worn on the
##   capture's temporary profile: n > 0 holds the packs for the BADGE PINS step, pins=0 deals them
##   at once (every pin owned: pins=3). While the step holds the packs, pick<i>, newpacks and open
##   do nothing but open the step: play confirm first. won marks a won run (no good first
##   pick), p2=<step>+<step>+... plays page 2 on its own clock: t<seconds>, hover<i> (the pointer
##   on pack i), deck (the pointer on the deck pile), corkboard (the pointer on it), pick<i>,
##   newpacks, pins (the step opens), wear<i> (owned pin i toggled), confirm, esc, open (OPEN
##   STORE: the flight); the file name gets the steps (p2_<steps>_).

## The capture's step on the page clock (s).
const STEP_S := 1.0 / 60.0


static func open(
	screen: ShiftScreen, options: PackedStringArray, raised: int, seed_value: int
) -> String:
	var page: String = _value(options, "page=")
	if page == "":
		return ""
	var count: int = _value(options, "completed=").to_int()
	for index: int in mini(count, screen._balance.aisles.size()):
		for card: CardDefinition in screen._balance.aisles[index].capsule_cards:
			screen.profile.unlocked_items[card.id] = 0
	if count > 0:
		for aisle: AisleDefinition in screen._balance.aisles:
			if aisle.base_cards.is_empty():
				for card: CardDefinition in aisle.capsule_cards.slice(
					0, screen._balance.aisle_listable_min
				):
					screen.profile.unlocked_items[card.id] = 0
	var pins: int = _value(options, "pins=").to_int()
	if _value(options, "pins=") != "":
		screen.profile.unlocked_pins.clear()
		screen.profile.worn_pins.clear()
		var earned: Array[PinDefinition] = []
		for pin: PinDefinition in screen._catalogue.pins:
			if pin.unlock_condition != null:
				earned.append(pin)
		for pin: PinDefinition in earned.slice(0, pins):
			screen.profile.unlocked_pins.append(pin.id)
	if options.has("won"):
		screen.profile.stats[ProfileState.RUNS_WON] = 1
	screen.start_new_run(seed_value, true, true)
	show_board(screen, options, raised)
	var steps: String = _value(options, "do=")
	var part: String = ("do_%s_" % steps.replace("+", "-").replace(":", "x")) if steps != "" else ""
	var p2: String = _value(options, "p2=")
	if p2 != "":
		part += "p2_%s_" % p2.replace("+", "-")
	if pins > 0:
		part += "pins%d_" % pins
	if options.has("won"):
		part += "won_"
	return "start_page%s_completed%d_%s" % [page, count, part]


static func show_board(screen: ShiftScreen, options: PackedStringArray, raised: int) -> void:
	var board: StartBoard = screen._cart_reveal.board
	board.refresh()
	var store: BoosterPage = board.store
	store.frozen = true
	var steps: String = _value(options, "do=")
	if steps != "":
		for step: String in steps.split("+", false):
			play(store, step)
	if _value(options, "page=") == "2":
		_open_all(board)
		board.show_page(2, "tab")
		board._end_slide()
		var build: BuildPage = board.staff
		build.frozen = true
		if raised >= 0:
			board.pick(raised)
		var p2: String = _value(options, "p2=")
		for step: String in p2.split("+", false):
			play_build(build, step)


## Plays one page-2 capture step (see the class doc).
static func play_build(build: BuildPage, step: String) -> void:
	var number: int = step.lstrip("abcdefghijklmnopqrstuvwxyz").to_int()
	if step.begins_with("t"):
		var left: float = step.trim_prefix("t").to_float()
		while left > 0.0001:
			build.advance(minf(STEP_S, left))
			left -= STEP_S
	elif step.begins_with("hover"):
		build.mouse = Vector2(BuildPage.STX[number] + 30, 200)
		build.advance(0.0)
	elif step == "deck":
		build.mouse = Vector2(BuildPage.DECK) + Vector2(30, 40)
		build.advance(0.0)
	elif step == "corkboard":
		build.mouse = Vector2(60, 100)
		build.advance(0.0)
	elif step.begins_with("pick"):
		build.pick_pack(number, "key")
	elif step == "newpacks":
		build.new_packs()
	elif step == "pins":
		build.pins.open(build.now)
	elif step.begins_with("wear"):
		build.pins.toggle_at(number)
	elif step == "confirm":
		build.pins.confirm("key")
	elif step == "esc":
		build.pins.close()
	elif step == "open":
		build.primary("key")


## Plays one capture step on the page (see the class doc).
static func play(store: BoosterPage, step: String) -> void:
	var number: int = step.lstrip("abcdefghijklmnopqrstuvwxyz").to_int()
	if step == "roll":
		store.openings.roll_up()
	elif step == "all":
		store.openings.open_all("key")
	elif step == "arm":
		store.counter.arm_restock()
	elif step == "hold":
		store.space(true)
	elif step == "primary" or step == "done":
		store.primary("key")
	elif step in ["win", "drop", "esc"] or step.begins_with("sb"):
		_play_swap(store, step, number)
	elif step.begins_with("grab") or step.begins_with("over"):
		_play_swap(store, step, number)
	elif step.begins_with("t"):
		var left: float = step.trim_prefix("t").to_float()
		while left > 0.0001:
			store.advance(minf(STEP_S, left))
			left -= STEP_S
	elif step.begins_with("open"):
		store.openings.open_booster(number)
	elif step.begins_with("flip"):
		store.openings.flip_hit(number)
	elif step.begins_with("restock"):
		store.counter.restock(number)
	elif step.begins_with("pick"):
		store.openings.pick_booster(number)
	elif step.begins_with("at"):
		var xy: PackedStringArray = step.trim_prefix("at").split(":")
		store.mouse = Vector2(xy[0].to_float(), xy[1].to_float())
		store.advance(0.0)


## One swap window step (see the class doc).
static func _play_swap(store: BoosterPage, step: String, number: int) -> void:
	var window: SwapWindow = store.swap
	if step == "win":
		window.open_window(false)
	elif step.begins_with("sb"):
		window.open_booster(number, "key")
	elif step.begins_with("grab") and number < window.pieces.size():
		var at: Vector2 = window.pieces[number].pos
		store.mouse = at
		window.press(at)
		store.mouse = at + Vector2(6, -4)
	elif step.begins_with("over"):
		store.mouse = SwapWindowDraw.item_centre(number) + Vector2(4, -6)
	elif step == "drop":
		window.release(store.mouse)
	elif step == "esc":
		window.escape()
	store.advance(0.0)


## Page 2 needs every booster open (and the pair picked): as the page itself, at once.
static func _open_all(board: StartBoard) -> void:
	var store: BoosterPage = board.store
	if store.shutter == BoosterPage.Shutter.DOWN:
		store.openings.roll_up()
	store.openings.end_arrival()
	if store.picking():
		store.openings.pick_booster(0)
		store.openings.pick_booster(1)
	store.openings.open_all("key")
	for k: int in 600:
		store.advance(STEP_S)


static func _value(options: PackedStringArray, prefix: String) -> String:
	for option: String in options:
		if option.begins_with(prefix):
			return option.trim_prefix(prefix)
	return ""
