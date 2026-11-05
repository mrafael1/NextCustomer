class_name CaptureStart
extends RefCounted
## The opening board's review states for the screen capture (full build plan 7.2; page 1
## "Counter", v1.07): --reveal=0,page=1|2,completed=0..6[,<option>...], the options:
## - restock=pick (RESTOCK pressed, the baskets waiting for a pick), restock=pick:<basket> (the
##   same with that basket hovered: its tag hot, the basket at its hover lift) or
##   restock=<basket> (that basket restocked);
## - swap=<slot>[:<aisle>]: regular <slot>'s swap shelf open (on aisle <aisle>, an index of
##   balance.aisles or an id, when given); swapped=<slot> swaps it to its first open offer first;
## - aisle=<basket>: starter basket <basket>'s aisle choice open; changed=<basket>:<aisle> deals
##   it from that aisle first;
## - seen: the NEW tags already seen;
## the file name gets the state options in order (pick_, restock<n>_, swap<n>_, swapped<n>_,
## aisle<n>_, changed<n>-<aisle>_);
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
	if options.has("seen"):
		for id: StringName in [StorePage.NEW_SWAP, StorePage.NEW_RESTOCK, StorePage.NEW_AISLE]:
			screen.profile.seen.append(id)
	screen.start_new_run(seed_value, true, true)
	show_board(screen, options, raised)
	return "start_page%s_completed%d_%s" % [page, count, _state_part(options)]


## The file name part naming the page-1 state options ("" for none): e.g. "pick_", "swap2_".
static func _state_part(options: PackedStringArray) -> String:
	var part: String = ""
	for option: String in options:
		var pair: PackedStringArray = option.split("=")
		if pair[0] in ["restock", "swap", "swapped", "aisle", "changed"]:
			var value: String = pair[1].replace(":", "-") if pair.size() > 1 else ""
			part += ("pick" if value == "pick" else pair[0] + value) + "_"
	return part


static func show_board(screen: ShiftScreen, options: PackedStringArray, raised: int) -> void:
	var board: StartBoard = screen._cart_reveal.board
	screen.profile.set_reduced_motion(true)
	board.refresh()
	board.store.skip_deal()
	var changed_text: String = _value(options, "changed=")
	if changed_text != "":
		var parts: PackedStringArray = changed_text.split(":")
		board.open_aisles(parts[0].to_int())
		board.change_aisle(_aisle(screen, parts[1]))
	var swapped_text: String = _value(options, "swapped=")
	if swapped_text != "" and board.open_swap(swapped_text.to_int()):
		board.popover.choose(_first_open(board))
	var restock_text: String = _value(options, "restock=")
	var picking: bool = restock_text.begins_with("pick")
	if restock_text != "" and not picking:
		board.restock(restock_text.to_int())
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
	if picking:
		board.start_restock()
		if restock_text.begins_with("pick:"):
			var hovered: int = restock_text.trim_prefix("pick:").to_int()
			board.store._pick_hover(hovered, true)
			var tuning: RedrawTuning = load(BasketRedraw.TUNING_PATH)
			(board.store.bays[hovered].get_node("Bob") as Control).position.y = -tuning.hover_lift
	var swap_text: String = _value(options, "swap=")
	if swap_text != "":
		var parts: PackedStringArray = swap_text.split(":")
		var tab: StringName = _aisle(screen, parts[1]) if parts.size() > 1 else &""
		board.open_swap(parts[0].to_int(), tab)
	var aisle_text: String = _value(options, "aisle=")
	if aisle_text != "":
		board.open_aisles(aisle_text.to_int())
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


## An aisle id from `text`: an index of balance.aisles or an id.
static func _aisle(screen: ShiftScreen, text: String) -> StringName:
	if text.is_valid_int():
		return screen._balance.aisles[text.to_int()].id
	return StringName(text)


static func _first_open(board: StartBoard) -> int:
	for at: int in board.popover.offers.size():
		if not board.popover.offers[at].disabled:
			return at
	return 0


static func _value(options: PackedStringArray, prefix: String) -> String:
	for option: String in options:
		if option.begins_with(prefix):
			return option.trim_prefix(prefix)
	return ""
