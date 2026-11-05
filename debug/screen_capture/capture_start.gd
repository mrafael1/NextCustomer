class_name CaptureStart
extends RefCounted
## The opening board's review states for the screen capture (full build plan 7.2):
## --reveal=0,page=1|2,completed=0..6[,<option>...], the options:
## - select: page 1 left in SELECT (nothing dealt, the baskets covered); otherwise the suggestion
##   is locked in first (LOCK IN & DEAL, no animation);
## - draft: in SELECT from 6 completed aisles, the first STARTER CART aisle set to not today (the
##   board waiting for a second one);
## - drag=<slot>: regular <slot> carried, its ghost over the first aisle it can go to;
## - strip=<slot>:<aisle>: regular <slot> dropped on aisle <aisle> (an index of balance.aisles or
##   an id), its item strip open; `swap` then opens the preview of its first item it can take;
## - restock=pick (R, the tags waiting for 1–3) or restock=<basket> (that basket restocked);
## - newpacks: NEW PACKS used on page 2; nopick, preview=n, pins and wear as before (`wear` puts
##   on the catalogue's last pin, unlocking it on the capture's temporary profile).


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
	screen.start_new_run(seed_value, true, true)
	show_board(screen, options, raised)
	return "start_page%s_completed%d_" % [page, count]


static func show_board(screen: ShiftScreen, options: PackedStringArray, raised: int) -> void:
	var board: StartBoard = screen._cart_reveal.board
	screen.profile.set_reduced_motion(true)
	if options.has("draft"):
		board.store.cycle(board.store.draft_green()[0])
	elif not options.has("select"):
		board.lock_in()
	board.store.skip_deal()
	board.show_page(_value(options, "page=").to_int(), "tab")
	if raised >= 0:
		board.pick(raised)
	if options.has("newpacks"):
		board.new_packs()
	if options.has("nopick"):
		board.selected = -1
		board.refresh()
	var preview_text: String = _value(options, "preview=")
	if preview_text != "":
		board._preview(preview_text.to_int())
	var restock_text: String = _value(options, "restock=")
	if restock_text == "pick":
		board.start_restock()
	elif restock_text != "":
		board.restock(restock_text.to_int())
	var drag_text: String = _value(options, "drag=")
	if drag_text != "":
		_drag(board, drag_text.to_int())
	var strip_text: String = _value(options, "strip=")
	if strip_text != "":
		var parts: PackedStringArray = strip_text.split(":")
		var aisle: StringName = StringName(parts[1])
		if parts[1].is_valid_int():
			aisle = screen._balance.aisles[parts[1].to_int()].id
		board._dropped(parts[0].to_int(), aisle, "click")
		if options.has("swap") and board.strip != null:
			board.strip.choose(_first_open(board))
	if options.has("wear"):
		var pin: PinDefinition = screen._catalogue.pins.back()
		if not screen.profile.unlocked_pins.has(pin.id):
			screen.profile.unlocked_pins.append(pin.id)
		board.open_pins()
		board._pins.toggle(pin)
		board.back()
	if options.has("pins"):
		board.open_pins()
	screen.profile.set_reduced_motion(false)


## Carries regular `slot` as a drag, its ghost over the first aisle row it can go to.
static func _drag(board: StartBoard, slot: int) -> void:
	var store: StorePage = board.store
	store.carry(slot, "drag")
	for id: StringName in store.board.ids:
		if id != StartSetup.STAPLES and store._target(id) == &"":
			var rect: Rect2 = store.board.row_rect(id)
			store.ghost.visible = true
			store.ghost.position = (rect.position + Vector2(rect.size.x - 120, -24)).floor()
			store._row_hovered(id)
			return


static func _first_open(board: StartBoard) -> int:
	for at: int in board.strip.items.size():
		if not board.strip.items[at].disabled:
			return at
	return 0


static func _value(options: PackedStringArray, prefix: String) -> String:
	for option: String in options:
		if option.begins_with(prefix):
			return option.trim_prefix(prefix)
	return ""
