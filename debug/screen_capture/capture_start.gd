class_name CaptureStart
extends RefCounted
## The opening board's review states for the screen capture (full build plan 7.2; page 1 YOUR
## STORE, the aisle board of v1.44): --reveal=0,page=1|2,completed=0..6[,<option>...] (completed=0
## leaves the aisles a new profile has not unlocked behind their padlocks), the options:
## - guided: the guided first run (the fixed pair, no light);
## - do=<step>+<step>+...: page 1 played step by step on its own clock (frozen between steps, so
##   the capture shows that exact frame): t<seconds> (the clock moves on, in 1/60 s steps), skip
##   (a click: the light, the throws or an opening skipped), all (everything played to its end,
##   each sealed booster opened in turn), open<i> (booster i opened, as its click; round 2 of the
##   2026-11-19 play test: the boosters wait sealed for it), pouch<i> (the pointer on booster i's
##   sealed pouch), arm (RESTOCK armed), restock<i>, card<b>_<k> (the
##   pointer on booster b's card k: its full card pops), at<x>:<y> (the pointer at art px x, y),
##   primary; the swap window, on page 2 since v1.44 (play these in p2=): win (the SWAP key),
##   sb<i> (its booster i opened), grab<n> (piece n pressed where it rests: booster 0's cards,
##   booster 1's, then the regulars), over<k> (the pointer over basket slot k), drop (the button
##   let go there), done (DONE), esc; options (polish batch 2: the board's Esc, the options with
##   BACK TO TITLE), optup (Up in them: BACK TO TITLE marked); tip<what> (v1.33 hover tips: the
##   board's tip of the StartTips target <what> at full size: card<b>_<k> an opened booster card
##   shown in full (compact_fan_cards off), card<b>_<k>fam its first family chip, piece<n> a swap
##   window card, slot<k> its basket's item; play it last); the file name gets the steps
##   (do_<steps>_);
## - page 2 (YOUR BUILD, v1.32): pins=<n> leaves the catalogue's first n earned pins (those with an
##   unlock condition; the pins every profile starts with stay owned) unlocked and none worn on the
##   capture's temporary profile: n > 0 holds OPEN STORE for the BADGE PINS step, pins=0 lets it
##   go at once (every pin owned: pins=3). While the step waits, open does nothing but open the
##   step: play confirm first. won marks a won run, p2=<step>+<step>+... plays page 2 on its own
##   clock: t<seconds>, corkboard (the pointer on it), pins (the step opens), wear<i> (owned pin i
##   toggled), confirm, esc, open (OPEN STORE: the flight), swapkey (the pointer on the SWAP key),
##   the swap window's steps; the file name gets the steps (p2_<steps>_).

## The capture's step on the page clock (s).
const STEP_S := 1.0 / 60.0


static func open(screen: ShiftScreen, options: PackedStringArray, seed_value: int) -> String:
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
	screen.start_new_run(seed_value, true, true, options.has("guided"))
	show_board(screen, options)
	var steps: String = _value(options, "do=")
	var part: String = ("do_%s_" % steps.replace("+", "-").replace(":", "x")) if steps != "" else ""
	var p2: String = _value(options, "p2=")
	if p2 != "":
		part += "p2_%s_" % p2.replace("+", "-")
	if pins > 0:
		part += "pins%d_" % pins
	if options.has("won"):
		part += "won_"
	if options.has("guided"):
		part += "guided_"
	return "start_page%s_completed%d_%s" % [page, count, part]


static func show_board(screen: ShiftScreen, options: PackedStringArray) -> void:
	var board: StartBoard = screen._cart_reveal.board
	board.refresh()
	var store: BoosterPage = board.store
	store.frozen = true
	var steps: String = _value(options, "do=")
	if steps != "":
		for step: String in steps.split("+", false):
			if step == "options":
				board.back("esc")
			elif step == "optup":
				screen._pause.options.move_marker(-1)
			else:
				play(store, step)
	if _value(options, "page=") == "2":
		_open_all(board)
		board.show_page(2, "tab")
		board._end_slide()
		var build: BuildPage = board.staff
		build.frozen = true
		var p2: String = _value(options, "p2=")
		for step: String in p2.split("+", false):
			if _is_swap_step(step):
				_play_swap(board, step)
			elif board.swap_showing() and step.begins_with("t") and not step.begins_with("tip"):
				play(board.store, step)  # The window runs on page 1's clock.
			else:
				play_build(build, step)


## Plays one page-2 capture step (see the class doc).
static func play_build(build: BuildPage, step: String) -> void:
	var number: int = step.lstrip("abcdefghijklmnopqrstuvwxyz").to_int()
	if step.begins_with("t"):
		var left: float = step.trim_prefix("t").to_float()
		while left > 0.0001:
			build.advance(minf(STEP_S, left))
			left -= STEP_S
	elif step == "corkboard":
		build.mouse = Vector2(60, 100)
		build.advance(0.0)
	elif step == "swapkey":
		build.mouse = Rect2(BuildRegulars.SWAP_RECT).get_center()
		build.advance(0.0)
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
	if step == "skip":
		store.click(Vector2(320, 200))
	elif step == "all":
		_play_out(store)
	elif step == "arm":
		store.counter.arm_restock()
	elif step.begins_with("open"):
		store.openings.open_booster(number, "click")
	elif step.begins_with("pouch"):
		var pouch: Vector2 = store.boosters[number].pouch_pos()
		store.mouse = pouch + Vector2(BoosterArt.BW / 2.0, BoosterArt.BH / 2.0)
		store.advance(0.0)
		store.advance(0.0)
	elif step == "primary":
		store.primary("key")
	elif step.begins_with("card"):
		var place: PackedStringArray = step.trim_prefix("card").split("_")
		var opening: BoosterOpening = store.boosters[place[0].to_int()]
		store.mouse = opening.card_rect(place[1].to_int()).get_center()
		store.advance(0.0)
		store.advance(0.0)
	elif step.begins_with("tip"):
		store.advance(0.0)
		show_tip(store.tips, step.trim_prefix("tip"))
	elif step.begins_with("t"):
		var left: float = step.trim_prefix("t").to_float()
		while left > 0.0001:
			store.advance(minf(STEP_S, left))
			left -= STEP_S
	elif step.begins_with("restock"):
		store.counter.restock(number)
	elif step.begins_with("at"):
		var xy: PackedStringArray = step.trim_prefix("at").split(":")
		store.mouse = Vector2(xy[0].to_float(), xy[1].to_float())
		store.advance(0.0)


## Shows the board's hover tip of `tips`' target `what` (see the class doc) at full size, its pop
## skipped, the pointer resting on it.
static func show_tip(tips: StartTips, what: String) -> void:
	var chip: bool = what.ends_with("fam")
	var prefix: String = what.trim_suffix("fam") + "|"
	var target: TipTarget = null
	for shown: TipTarget in tips.shown_targets():
		var key: String = shown.get_meta(StartTips.KEY_META, "")
		if key.begins_with(prefix) and key.contains("|fam") == chip:
			target = shown
			break
	var node: Node = tips.get_parent()
	while node != null and not node is StartBoard:
		node = node.get_parent()
	if target == null or node == null:
		push_warning("CaptureStart: no tip target for %s" % what)
		return
	var board_tips: GlyphTips = (node as StartBoard).tips
	board_tips.hide_tip()
	board_tips.point_at(target.get_global_rect().get_center())
	board_tips.show_tip(target)
	if board_tips._pop != null:
		board_tips._pop.kill()
	board_tips.tip().scale = Vector2.ONE
	for box: TipCard in board_tips.boxes():
		box.scale = Vector2.ONE


static func _is_swap_step(step: String) -> bool:
	if step in ["win", "drop", "esc", "done"]:
		return true
	return step.begins_with("sb") or step.begins_with("grab") or step.begins_with("over")


## One swap window step on page 2 (see the class doc).
static func _play_swap(board: StartBoard, step: String) -> void:
	var store: BoosterPage = board.store
	var number: int = step.lstrip("abcdefghijklmnopqrstuvwxyz").to_int()
	var window: SwapWindow = store.swap
	store.frozen = true
	if step == "win":
		board.open_swap()
	elif step == "done":
		store.primary("key")
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


## Page 2 needs every booster open: as the page itself, at once.
static func _open_all(board: StartBoard) -> void:
	_play_out(board.store)


## Plays page 1 to its end: the light skipped, every booster opened in turn.
static func _play_out(store: BoosterPage) -> void:
	store.roulette.skip()
	for k: int in 900:
		if store.page_done():
			break
		var next: BoosterOpening = store.openings.next_sealed()
		if next != null:
			store.openings.open_booster(next.index, "click")
		store.advance(STEP_S)


static func _value(options: PackedStringArray, prefix: String) -> String:
	for option: String in options:
		if option.begins_with(prefix):
			return option.trim_prefix(prefix)
	return ""
