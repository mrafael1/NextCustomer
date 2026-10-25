extends Control
## The screen capture (#55, #75; full build plan section 6.1): the real shift screen on fixed
## data, to review the look and to record it in docs/art/. It replaces the style frames, whose
## captures (docs/art/style_frame_*.png and style_frame_v2_*.png) stay as the record of the
## approved frames. #56 adds the other screens.
##
## The shift: shift 5 of 8 on a fixed seed, under Short belt (6 slots and a CLOSED one),
## with a fixed full hand of 8 items in its baskets, four items on the belt with their tickets
## and corner marks, the itemised planning receipt, and a 4-box loyalty card (a starting upgrade
## and the upgrades of shifts 2 and 4 stamped, shift 6's box empty). The hand and the belt hold
## staples, coupons and one product from each of the 6 aisles, so every aisle glyph shows. The
## screen is the game's own and stays playable; it is driven through its public API
## (start_new_run, debug_show_shift, debug_scan) and the run's.
##
## It never touches the player's saves or playtest logs: both go to a temporary folder, deleted
## on exit. Keys: S switches between the sharp-pixel shader and plain nearest filtering (A/B).
## `godot --path . [--resolution 1920x1080] res://debug/screen_capture/screen_capture.tscn --
## --capture=docs/art` saves shift_screen_<width>x<height>.png at the window's size, then quits;
## the real pointer drives nothing meanwhile (hold_pointer).
## With `--scan=<card id>` the scanner first fully scans that card's item (the belt's first,
## else the hand's), waits for it to land in the monitor's scanner bay, and the file is
## shift_screen_scan_<width>x<height>.png.
## With `--effects` the shift shows the planning effects (#71) on a richer belt: #60's reference
## row under the Spot check (Eggs lands ×2 on Bread, the 3rd product is denied, Multipack arms ×3
## and Coupon engine fizzles on it, Slot engine stamps slot 6 under its talker), and the file is
## shift_screen_effects_<width>x<height>.png. `--effects=<card id>` also hovers that card's belt
## item (the first), highlighting its causes and targets, and lets its scan finish so the monitor
## explains it (its "gives" line, as in mock-up h1's hover); the file is
## shift_screen_effects_focus_<width>x<height>.png. `--effects=<card id>,hand` hovers that card's
## item in the hand baskets instead (#105 piece 3: the mix highlight on the belt and the baskets);
## the file is shift_screen_effects_focus_hand_<width>x<height>.png. With --effects, `--tip=...`
## (below) shows the mix highlight of the glyph's family too.
## With `--checkout=<seconds>` CHECKOUT is pressed and the capture waits that many seconds of the
## count-up (#86), and the file is shift_screen_[effects_]checkout_<tenths>_<width>x<height>.png.
## With `--machine=<seconds>[,<option>...]` (#77) shift 1's passing row is checked out and the
## RECEIPT REWARDS machine opens beside the receipt, its visit played from the printer feed (see
## machine() for the options: a chute to choose or whose odds card to show, the bonus ticket's or
## STAMP DAY's visit, a full cart, a draw's rarities, a pick, reduced motion, a resumed visit);
## the capture waits `seconds` after the last step, and the file is
## shift_screen_machine_<options>_<tenths>_<width>x<height>.png.
## With `--announce=<seconds>` (v0.50) a new run's shift 1 is the shift before a PREMIUM visit: its
## planning prints the gold PREMIUM receipt on the monitor, which then hangs as the PREMIUM NEXT
## tag; the capture waits `seconds` from the shift's start, and the file is
## shift_screen_announce_<tenths>_<width>x<height>.png. `--announce=<seconds>,shift=<n>` instead
## jumps to shift n of the real schedule (shift 3: inspected, and the shift before the first
## PREMIUM visit), named shift_screen_announce_shift<n>_<tenths>_<width>x<height>.png.
## With `--reveal=<seconds>[,outro=<seconds>][,seed=<seed>][,hover=<n>]` (v0.51) a new run opens on
## the cart reveal, frozen at that time of its timeline (and of its fold into the Cart button), and
## the file is shift_screen_reveal_[outro_<tenths>_][hover<n>_]<tenths>_<width>x<height>.png;
## `hover=<n>` (v0.54) opens the scan popup of tile n (the staples, then the picks, from 0).
## With `--tip=<card id>[,<n>]` (#105) the glyph tooltip of glyph n (from 0) on that card's first
## belt ticket shows (below the ticket), `--tip=<card id>,colour` its colour's tooltip, and
## `--tip=monitor[,<n>]` that of the monitor scan's glyph n (above it; with --effects=<card id>);
## the file name gets tip_<what>_<n>_ (tip_<what>_colour_).
## With `--deck=<page>[,<option>...]` (#56) a new run opens the deck view (see deck() for the pages
## and options), and the file is shift_screen_deck_<page>[_<options>]_<width>x<height>.png.
## With `--stack` (#105 piece 3) the belt holds the planning layout test's stress row on Big
## basket's 8 slots (Squashed cake wears 6 stickers, so its stack folds into the "+N" chip), and
## the file is shift_screen_stack_<width>x<height>.png; `--stack=fan` also hovers that stack,
## fanning it out (shift_screen_stack_fan_<width>x<height>.png).

const SCREEN := preload("res://ui/shift_screen.tscn")
const SEED := 20261014
const SHIFT := 5
const INSPECTION := "short_belt"
## The starting upgrade (full build plan 7.3), then the upgrades taken on shifts 2 and 4.
const UPGRADE_IDS: Array[String] = ["coupon_engine", "slot_engine", "category_engine"]
## The hand of 8 (card ids in data/cards), in place of the dealt one: staples, a coupon and a
## product from Pantry, Household and Snacks.
const HAND_IDS: Array[String] = [
	"eggs", "tea_bags", "banana", "batteries", "two_for_one", "crisps", "coffee", "milk"
]
## The cards on the belt: a product from Cold cases, Fruit & veg and Bakery, and a coupon.
const ROW_IDS: Array[String] = ["cheese", "strawberries", "croissant", "multipack"]
## --effects' shift (#71): #60's reference row on the belt under the Spot check.
const EFFECTS_INSPECTION := "spot_check"
const EFFECTS_ROW_IDS: Array[String] = [
	"eggs", "bread", "milk", "multipack", "milk", "milk", "milk"
]
const CAPTURE_ARGUMENT := "--capture="
const SCAN_ARGUMENT := "--scan="
const EFFECTS_ARGUMENT := "--effects"
const CHECKOUT_ARGUMENT := "--checkout="
const MACHINE_ARGUMENT := "--machine="
const ANNOUNCE_ARGUMENT := "--announce="
## An --announce capture's file name part: announce_<tenths>_.
const ANNOUNCE_PREFIX := "announce_%d_"
const ANNOUNCE_SHIFT_PREFIX := "announce_shift%d_%d_"
const REVEAL_ARGUMENT := "--reveal="
## A --reveal capture's file name part: reveal_[outro_<tenths>_]<tenths>_.
const REVEAL_PREFIX := "reveal_%s%d_"
const DECK_ARGUMENT := "--deck="
const TIP_ARGUMENT := "--tip="
## --stack's shift: planning_layout_test's stress row, with the upgrades it needs.
const STACK_ARGUMENT := "--stack"
const STACK_UPGRADE_IDS: Array[String] = ["coupon_engine", "big_basket", "category_engine"]
const STACK_ROW_IDS: Array[String] = [
	"bread",
	"flickering_bulb",
	"multipack",
	"birthday_candles",
	"eggs",
	"tea_bags",
	"breakfast_sticker",
	"squashed_cake",
]
const STACK_PREFIX := "stack_"
const STACK_FAN_PREFIX := "stack_fan_"
const TIP_PREFIX := "tip_%s_%d_"
const TIP_COLOUR_PREFIX := "tip_%s_colour_"
const COLOUR_TIP := "colour"
## --deck's full cart: the first copies upgraded to these tiers, and this coupon added.
const FULL_TIERS: Dictionary[String, String] = {"banana": "banana_golden", "milk": "milk_big"}
const FULL_COUPON_ID := "multipack"
## --deck's Run info: the inspection of the shift and the prize the chooser is for.
const DECK_INSPECTION := "short_belt"
const CHOOSER_PRIZE_ID := "breakfast_sticker"
## --machine's shift (#77): shift 1's passing row (Milk, Multipack, Milk x5 = 109), and the
## inspection a bonus ticket's shift passes.
const MACHINE_ROW_IDS: Array[String] = ["milk", "multipack", "milk", "milk", "milk", "milk", "milk"]
const BONUS_INSPECTION := "spot_check"
## A full cart is filled up with this card.
const FILLER_ID := "milk"
## A --machine capture's file name part: machine_<options>_<tenths>_.
const MACHINE_PREFIX := "machine_%s%d_"
## The rarities --machine's draw=<letters> sets (c, r, l).
const RARITY_LETTERS := "crl"
## How long --machine waits (real time, at most) for the machine to arm at a wait point.
const ARM_LIMIT_MS := 3000
## A capture's file name: shift_screen_[scan_|effects_[focus_]]<width>x<height>.png.
const FILE_NAME := "shift_screen_%s%dx%d.png"
const SCAN_PREFIX := "scan_"
const EFFECTS_PREFIX := "effects_"
const FOCUS_PREFIX := "effects_focus_"
## --effects=<card id>,hand: the hand's item is hovered (#105 piece 3).
const HAND_OPTION := "hand"
const HAND_PREFIX := "hand_"
const CHECKOUT_PREFIX := "checkout_%d_"
## Frames for the shift's items to be laid out before one is scanned.
const SCAN_SETTLE_FRAMES := 2
const CAPTURE_SETTLE_FRAMES := 12
## After a scan, the monitor's scanner bay swaps to the scanned item (the old one slides out, the
## new one drops in): the capture waits for it to land (real time).
const BAY_SETTLE_S := ScannerBay.PLAN_OUT_S + BayBed.FALL_S + 0.1

## Where capture() reports a failed save (push_error by default), so tests never print errors.
var report_error: Callable = Callable()
## Grabs the screen for capture() (the viewport's image by default; tests pass their own).
var grab_image: Callable = Callable()

var _folder: String = ""
var _screen: ShiftScreen
var _sharp: bool = true
var _scanned: bool = false
## Since effects(): the planning effects' shift, and whether an item is hovered.
var _effects: bool = false
var _focused: bool = false
## Since checkout(): the count-up's seconds waited, -1 before.
var _checkout_s: float = -1.0
## Since machine(): the file name part naming its options and wait ("" before).
var _machine_part: String = ""
## Since reveal(): the file name part naming its time ("" before).
var _reveal_part: String = ""
## A --tip capture's file name part.
var _tip_part: String = ""
## Since stack(): the file name part (stack_ or stack_fan_).
var _stack_part: String = ""
## Since hold_pointer(): the real pointer drives no hover, tooltip or click.
var _holding_pointer: bool = false


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	# Saves and logs go to a temporary folder before the screen loads anything.
	_folder = OS.get_temp_dir().path_join("next_customer_capture_%d" % Time.get_ticks_usec())
	DirAccess.make_dir_recursive_absolute(_folder)
	ProjectSettings.set_setting(SaveService.FOLDER_SETTING, _folder)
	_event_log().use_folder(_folder)
	var capture_folder: String = _argument(CAPTURE_ARGUMENT)
	if capture_folder != "":
		hold_pointer()
	_screen = SCREEN.instantiate()
	add_child(_screen)
	var effects_on: bool = OS.get_cmdline_user_args().has(EFFECTS_ARGUMENT)
	var focus_id: String = _argument(EFFECTS_ARGUMENT + "=")
	var reveal_spec: String = _argument(REVEAL_ARGUMENT)
	var deck_spec: String = _argument(DECK_ARGUMENT)
	var stack_spec: String = _argument(STACK_ARGUMENT + "=")
	if reveal_spec != "":
		reveal(reveal_spec)
	elif deck_spec != "":
		await deck(deck_spec)
	elif stack_spec != "" or OS.get_cmdline_user_args().has(STACK_ARGUMENT):
		await stack(stack_spec == "fan")
	elif effects_on or focus_id != "":
		await effects(focus_id)
	else:
		_set_up_shift(INSPECTION, ROW_IDS)
	if capture_folder != "":
		var scan_id: String = _argument(SCAN_ARGUMENT)
		if scan_id != "":
			await scan(scan_id)
		var checkout_s: String = _argument(CHECKOUT_ARGUMENT)
		if checkout_s != "":
			await checkout(checkout_s.to_float())
		var machine_spec: String = _argument(MACHINE_ARGUMENT)
		if machine_spec != "":
			await machine(machine_spec)
		var tip_spec: String = _argument(TIP_ARGUMENT)
		if tip_spec != "":
			await tip(tip_spec)
		var announce_s: String = _argument(ANNOUNCE_ARGUMENT)
		if announce_s != "":
			var announce_parts: PackedStringArray = announce_s.split(",")
			var announce_shift: int = 0
			if announce_parts.size() > 1 and announce_parts[1].begins_with("shift="):
				announce_shift = announce_parts[1].trim_prefix("shift=").to_int()
			await announce(announce_parts[0].to_float(), announce_shift)
		await capture(capture_folder)
		get_tree().quit()


func _exit_tree() -> void:
	if _holding_pointer:
		get_viewport().gui_disable_input = false
	ProjectSettings.set_setting(SaveService.FOLDER_SETTING, null)
	_remove_folder(_folder)


func _unhandled_key_input(event: InputEvent) -> void:
	var key: InputEventKey = event as InputEventKey
	if key == null or not key.pressed or key.echo or key.keycode != KEY_S:
		return
	_sharp = not _sharp
	ArtStyle.set_sharp(self, _sharp)
	get_viewport().set_input_as_handled()


## Sets up the fixed shift under the inspection `inspection_id` (none when empty) and the upgrades
## `upgrade_ids` with the cards `row_ids` on the belt.
func _set_up_shift(
	inspection_id: String, row_ids: Array[String], upgrade_ids: Array[String] = UPGRADE_IDS
) -> void:
	_screen.start_new_run(SEED)
	var run: RunState = _screen.run
	var starter: DeckDefinition = run.starter.duplicate()
	starter.starting_upgrade = _upgrade(upgrade_ids[0])
	run.starter = starter
	var upgrades: Array[UpgradeDefinition] = []
	for upgrade_id: String in upgrade_ids:
		upgrades.append(_upgrade(upgrade_id))
	run.upgrades = upgrades
	run.debug_skip_to_shift(SHIFT - 1)
	# The same shift again: it keeps the inspection set here.
	run.inspections = []
	if inspection_id != "":
		run.inspections = [load("res://data/inspections/%s.tres" % inspection_id)]
	run.debug_skip_to_shift(SHIFT - 1)
	# The fixed hand replaces the dealt one, which is set aside for the shift.
	run.deck.restore(run.deck.cards, [], run.deck.draw_pile(), run.deck.next_instance_id())
	for card_id: String in HAND_IDS + row_ids:
		run.debug_add_to_hand(_card(card_id))
	var cards: Array[CardInstance] = run.hand()
	for card: CardInstance in cards.slice(HAND_IDS.size()):
		run.place(card, run.row.size())
	_screen.debug_show_shift()


## Stops the real pointer from driving the screen until the capture leaves the tree: a capture
## records the fixed data only, never a hover, tooltip or click from wherever the OS pointer happens
## to rest over the window. Scans and hovers asked for (scan(), effects()) still play, being driven
## through the screen's API. A capture run (--capture) holds it from the start.
func hold_pointer() -> void:
	_holding_pointer = true
	get_viewport().gui_disable_input = true


## The screen being captured (for the smoke test).
func screen() -> ShiftScreen:
	return _screen


## Scans the item of the first card with `card_id` (on the belt, else in the hand) once the
## items are laid out, as the player's hover would; capture() then names its file
## shift_screen_scan_<w>x<h>.png. A card that isn't on the counter goes to report_error.
func scan(card_id: String) -> void:
	for _frame: int in range(SCAN_SETTLE_FRAMES):
		await get_tree().process_frame
	for card: CardInstance in _screen.run.row + _screen.run.hand():
		if card.definition.id == card_id and _screen.debug_scan(card):
			_scanned = true
			await get_tree().create_timer(BAY_SETTLE_S).timeout
			return
	_report("No %s on the counter to scan" % card_id)


## Sets up --effects' shift (a new run on the same fixed data: #60's reference row on the belt
## under the Spot check) and, for a `card_spec` (a card id, with ",hand" for the hand's item),
## hovers the first belt (or basket) item of that card once the items are laid out and scans it,
## as the player's resting pointer would; capture() then names its file
## shift_screen_effects_[focus_[hand_]]<w>x<h>.png. A card that isn't there goes to report_error.
func effects(card_spec: String = "") -> void:
	_set_up_shift(EFFECTS_INSPECTION, EFFECTS_ROW_IDS)
	_effects = true
	_focused = false
	if card_spec == "":
		return
	var parts: PackedStringArray = card_spec.split(",", false)
	var card_id: String = parts[0]
	var hand: bool = parts.size() > 1 and parts[1] == HAND_OPTION
	var form: ItemView.Form = ItemView.Form.BASKET if hand else ItemView.Form.BELT
	if hand:
		_stack_part = HAND_PREFIX
	for _frame: int in range(SCAN_SETTLE_FRAMES):
		await get_tree().process_frame
	for found: Node in _screen.find_children("*", "ItemView", true, false):
		var item: ItemView = found as ItemView
		var shown: bool = item.form == form and not item.is_queued_for_deletion()
		if shown and item.card.definition.id == card_id:
			item.hovered.emit(item)
			# The pointer rests on it past the scan's delay: the monitor explains it (mock-up h1).
			_screen.debug_scan(item.card)
			_focused = true
			return
	_report("No %s %s to hover" % [card_id, "in the hand" if hand else "on the belt"])


## Sets up --stack's shift (the stress row on 8 slots, no inspection) and, when `fan`, hovers the
## first folded stack's item once the items are laid out, waiting for its fan to open; capture()
## then names its file shift_screen_stack_[fan_]<w>x<h>.png. No folded stack goes to report_error.
func stack(fan: bool) -> void:
	_set_up_shift("", STACK_ROW_IDS, STACK_UPGRADE_IDS)
	_stack_part = STACK_FAN_PREFIX if fan else STACK_PREFIX
	if not fan:
		return
	for _frame: int in range(SCAN_SETTLE_FRAMES):
		await get_tree().process_frame
	var layer: PlanningLayer = _screen._stage.planning_layer
	for slot: int in range(_screen.run.row.size()):
		var shown: Array[EffectSticker] = layer.stack(slot)
		if not shown.is_empty() and shown[0].spec().kind == StickerSpec.Kind.MORE:
			var item: ItemView = _screen._row_views[slot] as ItemView
			layer.fan().point_at(item.get_global_transform() * item.hit_rect().get_center())
			await get_tree().create_timer(StackFan.OPEN_S + 0.2).timeout
			return
	_report("No folded stack to fan")


## Presses CHECKOUT once the items are laid out and waits `seconds` of the count-up; capture()
## then names its file shift_screen_[effects_]checkout_<tenths>_<w>x<h>.png.
func checkout(seconds: float) -> void:
	for _frame: int in range(SCAN_SETTLE_FRAMES):
		await get_tree().process_frame
	# As the debug panel's checkout (ShiftDebug): the player's press.
	_screen._on_checkout_pressed()
	_checkout_s = seconds
	await get_tree().create_timer(seconds).timeout


## Saves the screen into `folder` as shift_screen_<w>x<h>.png (shift_screen_scan_<w>x<h>.png
## after scan(), shift_screen_effects_[focus_]<w>x<h>.png after effects()) once it has settled. A
## failed save goes to report_error.
func capture(folder: String) -> void:
	DirAccess.make_dir_recursive_absolute(folder)
	for _frame: int in range(CAPTURE_SETTLE_FRAMES):
		# A headless run (the tests) draws nothing, so it waits for frames instead.
		if DisplayServer.get_name() == "headless":
			await get_tree().process_frame
		else:
			await RenderingServer.frame_post_draw
	var window: Vector2i = get_window().size
	var prefix: String = SCAN_PREFIX if _scanned else ""
	if _effects:
		prefix = FOCUS_PREFIX if _focused else EFFECTS_PREFIX
	if _checkout_s >= 0.0:
		prefix += CHECKOUT_PREFIX % roundi(_checkout_s * 10.0)
	prefix += _machine_part + _reveal_part + _tip_part + _stack_part
	var path: String = folder.path_join(FILE_NAME % [prefix, window.x, window.y])
	var image: Image = (
		grab_image.call() as Image
		if grab_image.is_valid()
		else get_viewport().get_texture().get_image()
	)
	var error: Error = ERR_UNAVAILABLE if image == null else image.save_png(path)
	if error != OK:
		_report("Can't save %s (error %d)" % [path, error])


## Shows a family glyph's tooltip (#105): `spec` is "<card id>[,<n>]" (glyph n of that card's first
## belt ticket), "<card id>,colour" (that ticket's colour) or "monitor[,<n>]" (glyph n of the
## monitor's scan). A missing glyph goes to report_error.
func tip(spec: String) -> void:
	for _frame: int in range(SCAN_SETTLE_FRAMES):
		await get_tree().process_frame
	var parts: PackedStringArray = spec.split(",", false)
	var what: String = parts[0] if not parts.is_empty() else ""
	var colour: bool = parts.size() > 1 and parts[1] == COLOUR_TIP
	var index: int = parts[1].to_int() if parts.size() > 1 and not colour else 0
	var targets: Array[TipTarget] = []
	if what == "monitor":
		for found: Node in _screen._monitor.find_children("*", "FamilyGlyph", true, false):
			targets.append(found as FamilyGlyph)
	else:
		for found: Node in _screen.find_children("*", "ItemView", true, false):
			var item: ItemView = found as ItemView
			if item.form == ItemView.Form.BELT and item.card.definition.id == what:
				if colour:
					targets.append(
						item.sticker().get_node(PriceSticker.COLOUR_SPOT_NAME) as TipTarget
					)
				else:
					targets.append_array(item.sticker().glyphs())
				break
	if index >= targets.size():
		_report("No glyph %d for %s" % [index, what])
		return
	var target: TipTarget = targets[index]
	# The pointer rests on it (the real pointer drives nothing in a capture): a colour off the
	# ticket's glyphs, at its lower left.
	var rect: Rect2 = target.get_global_rect()
	var at: Vector2 = rect.position + Vector2(4, rect.size.y - 6) if colour else rect.get_center()
	_screen._glyph_tips.point_at(at)
	_screen._glyph_tips.show_tip(target)
	_tip_part = (TIP_COLOUR_PREFIX % what) if colour else (TIP_PREFIX % [what, index])


## Starts a new run (SEED, or `seed=<seed>`) on the cart reveal (v0.51), frozen at `spec`'s seconds
## (and `outro=<seconds>` into its fold); capture() then names its file
## shift_screen_reveal_[outro_<tenths>_]<tenths>_<w>x<h>.png.
func reveal(spec: String) -> void:
	var options: PackedStringArray = spec.split(",", false)
	var seconds: float = options[0].to_float() if not options.is_empty() else 0.0
	var outro: float = -1.0
	var seed_value: int = SEED
	var hovered: int = -1
	for option: String in options.slice(1):
		if option.begins_with("outro="):
			outro = option.trim_prefix("outro=").to_float()
		elif option.begins_with("seed="):
			seed_value = option.trim_prefix("seed=").to_int()
		elif option.begins_with("hover="):
			hovered = option.trim_prefix("hover=").to_int()
	_screen.start_new_run(seed_value, true, true)
	var cart_reveal: CartReveal = _screen._cart_reveal
	cart_reveal.freeze_at(seconds, outro)
	var fold: String = "outro_%d_" % roundi(outro * 10.0) if outro >= 0.0 else ""
	if hovered >= 0:
		var tiles: Array[RevealTile] = (
			cart_reveal.panel().staple_tiles + cart_reveal.panel().pick_tiles
		)
		cart_reveal.show_popup(tiles[hovered])
		fold += "hover%d_" % hovered
	_reveal_part = REVEAL_PREFIX % [fold, roundi(seconds * 10.0)]


## Opens the deck view (#56) on a new run (SEED), as the top bar's Cart would; capture() then names
## its file shift_screen_deck_<page>[_<options>]_<w>x<h>.png. `spec` is "<page>[,<option>...]":
## the page is cart, info (Run info: the capture's upgrades, a Short belt shift, a new arrival in
## the stock) or chooser (the machine's deck-full chooser for a Breakfast sticker, on a full cart);
## the options:
## - seed=<n>: the run's seed;
## - full: the cart filled to the deck limit with distinct items (the dealt deck with one copy of
##   each card but its first repeated one, the first Banana GOLDEN and the first Milk BIG, a
##   Multipack, then stocked products it lacks);
## - hover=<i>: the page's item i is hovered (its scan popup opens beside it).
func deck(spec: String) -> void:
	var options: PackedStringArray = spec.split(",", false)
	var page: String = options[0] if not options.is_empty() else "cart"
	options = options.slice(1)
	var seed_value: String = _option_value(options, "seed=")
	_screen.start_new_run(seed_value.to_int() if seed_value != "" else SEED, false)
	var run: RunState = _screen.run
	if options.has("full") or page == "chooser":
		_fill_cart(run)
	if page == "info":
		var upgrades: Array[UpgradeDefinition] = []
		for upgrade_id: String in UPGRADE_IDS:
			upgrades.append(_upgrade(upgrade_id))
		run.upgrades = upgrades
		run.inspections = [load("res://data/inspections/%s.tres" % DECK_INSPECTION)]
		run.stock.new_arrivals = [DeckSummary.in_view_order(run.stock.cards)[5]]
		_screen._refresh_loyalty_card()
	var view: DeckView = _screen._deck_view
	if page == "chooser":
		var prize: CardDefinition = _card(CHOOSER_PRIZE_ID)
		view.open(
			run,
			(
				"Cart full (%d/%d): choose an item to remove for %s"
				% [run.deck.size(), run.balance.deck_limit, prize.display_name]
			),
			true
		)
	else:
		_screen._on_deck_button_pressed()
	view.show_page(page == "info")
	# Past the pop-in (and its overshoot), laid out.
	await get_tree().create_timer(UiKit.POP_IN_SECONDS + 0.2).timeout
	var hovered: String = _option_value(options, "hover=")
	if hovered != "":
		view.hover(view.cells()[hovered.to_int()])
	var named: String = "_".join(options).replace("=", "")
	_machine_part = "deck_%s_" % (page + ("_" + named if named != "" else ""))


## Fills `run`'s cart to the deck limit with distinct items (see deck()'s full).
func _fill_cart(run: RunState) -> void:
	var kept: Array[CardDefinition] = []
	var repeated: CardDefinition = null
	for card: CardInstance in run.deck.cards.duplicate():
		if not kept.has(card.definition):
			kept.append(card.definition)
		elif repeated == null or repeated == card.definition:
			repeated = card.definition
		else:
			run.deck.remove_card(card)
	for card_id: String in FULL_TIERS:
		for card: CardInstance in run.deck.cards:
			if card.definition.id == StringName(card_id):
				run.deck.upgrade(card, _card(FULL_TIERS[card_id]))
				break
	run.deck.add_card(_card(FULL_COUPON_ID))
	for card: CardDefinition in DeckSummary.in_view_order(run.stock.cards):
		if run.deck_is_full():
			break
		var owned: bool = run.deck.cards.any(
			func(owned_card: CardInstance) -> bool:
				return owned_card.definition.is_same_product(card)
		)
		if card.is_product() and not owned:
			run.deck.add_card(card)


## Opens the RECEIPT REWARDS machine (#77) on a new run (the same seed) whose shift 1 checked out
## its passing row, as the dessert's printer feed would, then waits `spec`'s seconds; capture()
## then names its file shift_screen_machine_<options>_<tenths>_<w>x<h>.png. `spec` is
## "<seconds>[,<option>...]", the options (in any order):
## - new_items, coupons, register or upgrades: that chute is chosen at the keys (its draw plays);
## - odds: that chute's odds card is shown above its key instead (as on hover); press: that
##   chute's key is pressed instead (the display's title with CONFIRM ›);
## - bonus: the shift passed a Spot check; its ticket picks a NEW ITEMS prize (with boosted: a
##   LOYALTY prize, and the BONUS visit is PREMIUM too, v0.53), and the bonus ticket's visit is
##   shown; stampday: the shift is a STAMP DAY's; its ticket bins a NEW ITEMS
##   draw, and STAMP DAY's draw is shown (pick=<i> picks a stamp);
## - cartfull: the cart is at the deck limit before the checkout;
## - draw=<letters>: the draw's rarities, c, r or l per prize (a debug draw: the prizes drawn,
##   relabelled), shown rarest last;
## - pick=<i>: once the prizes are armed, prize i is picked (its landing plays);
## - hover=<i> (v0.53): once the prizes are armed, the pointer rests on prize i (its popup opens);
## - boosted (v0.50): the shift's ticket visit is BOOSTED, so the machine turns PREMIUM (its
##   chutes: register, upgrades);
## - rm: reduced motion; resume: the visit as a resumed run shows it (at its wait point, no
##   replay; with a chute, the run was saved after that chute's draw: resumed at the pick).
## The seconds count from the last step: the machine's open, the choice, or the pick. A spec
## that can't be played goes to report_error.
func machine(spec: String) -> void:
	var options: PackedStringArray = spec.split(",", false)
	var seconds: float = options[0].to_float() if not options.is_empty() else 0.0
	options = options.slice(1)
	_screen.profile.set_reduced_motion(options.has("rm"))
	_screen.start_new_run(SEED)
	var run: RunState = _screen.run
	if not _check_out_machine_shift(run, options):
		return
	var chute: int = _machine_chute(options)
	var resumed_pick: bool = (
		options.has("resume")
		and chute >= 0
		and not options.has("odds")
		and not options.has("press")
	)
	if resumed_pick and run.phase == RunState.Phase.MACHINE_CHOOSE:
		run.machine.choose(run, chute)  # Saved after the draw: resumed at the pick.
	var saved: RunSave = RunSave.new()
	saved.run = run
	saved.run_id = "capture"
	_screen._resume_run(saved)
	var flow: MachineFlow = _screen._machine
	if not options.has("resume"):
		flow.open(false)  # Replays the visit from the printer feed.
	if chute >= 0 and run.phase == RunState.Phase.MACHINE_CHOOSE:
		await _machine_armed(flow.view)
		if options.has("odds"):
			flow.view.hover_key(chute)
		elif options.has("press"):
			flow.view.press_key(chute)
		elif not flow._choose(chute):
			_report("The machine can't choose %s" % MachineVisit.CHUTE_NAMES[chute])
			return
	var rarities: String = _option_value(options, "draw=")
	if rarities != "" and run.phase == RunState.Phase.MACHINE_PICK:
		_rig_draw(run, rarities)
		flow.view.show_draw(run)
	var hover: String = _option_value(options, "hover=")
	if hover != "":
		await _machine_armed(flow.view)
		flow.view.popup.open_for(flow.view.tickets[hover.to_int()])
	var pick: String = _option_value(options, "pick=")
	if pick != "":
		await _machine_armed(flow.view)
		flow.view.pick(pick.to_int())
	var named: String = "_".join(options).replace("=", "")
	_machine_part = MACHINE_PREFIX % [named + "_" if named != "" else "", roundi(seconds * 10.0)]
	await get_tree().create_timer(seconds).timeout
	await _machine_settled(flow.view)


## Checks out --machine's shift on `run` (shift 1's passing row; `options`: a bonus ticket's Spot
## check, a STAMP DAY, a BOOSTED visit, a full cart) and plays its ticket to the visit asked for.
## False (with a report) when the run doesn't get there.
func _check_out_machine_shift(run: RunState, options: PackedStringArray) -> bool:
	if options.has("stampday"):
		run.machine.machine = run.machine.machine.duplicate() as MachineDefinition
		run.machine.machine.stamp_day_shifts = PackedInt32Array([run.shift_index + 1])
		run.machine.machine.stamp_day_floor = PackedInt32Array([1])
	if options.has("boosted"):
		run.machine.machine = run.machine.machine.duplicate() as MachineDefinition
		run.machine.machine.boosted_shifts = PackedInt32Array([run.shift_index + 1])
	if options.has("cartfull"):
		while run.deck.size() < run.balance.deck_limit:
			run.deck.add_card(_card(FILLER_ID))
	for card_id: String in MACHINE_ROW_IDS:
		run.place(run.debug_add_to_hand(_card(card_id)), run.row.size())
	run.checkout()
	if options.has("bonus"):
		run.history[-1].inspection = load("res://data/inspections/%s.tres" % BONUS_INSPECTION)
		run.machine.begin_after_checkout(run)
	if run.phase != RunState.Phase.MACHINE_CHOOSE:
		_report("The machine's shift didn't pass")
		return false
	if options.has("bonus") or options.has("stampday"):
		var first: int = RewardMachine.Chute.NEW_ITEMS
		if options.has("bonus") and run.machine.is_boosted():
			first = RewardMachine.Chute.REGISTER
		run.machine.choose(run, first)
		if options.has("bonus"):
			var replaced: CardInstance = run.deck.cards[0] if run.deck_is_full() else null
			run.machine.pick(run, 0, replaced)
		else:
			run.machine.bin(run)
	var wanted: int = MachineVisit.Kind.TICKET
	if options.has("bonus"):
		wanted = MachineVisit.Kind.BONUS
	elif options.has("stampday"):
		wanted = MachineVisit.Kind.STAMP_DAY
	var visit: MachineVisit = run.machine.current_visit()
	if visit == null or visit.kind != wanted:
		_report("No %s visit to show" % MachineVisit.KIND_NAMES[wanted])
		return false
	return true


## Starts a new run (the same seed) whose shift 1 announces a PREMIUM visit (v0.50: its machine
## BOOSTED after shift 1), then waits `seconds` of its planning; capture() then names its file
## shift_screen_announce_<tenths>_<w>x<h>.png. With `shift_number` (> 0) the run jumps to that
## shift of the real schedule instead (shift_screen_announce_shift<n>_<tenths>_<w>x<h>.png).
func announce(seconds: float, shift_number: int = 0) -> void:
	_screen.start_new_run(SEED)
	if shift_number > 0:
		_screen._debug.skip_to_shift(shift_number)
		_machine_part = ANNOUNCE_SHIFT_PREFIX % [shift_number, roundi(seconds * 10.0)]
	else:
		var run: RunState = _screen.run
		run.machine.machine = run.machine.machine.duplicate() as MachineDefinition
		run.machine.machine.boosted_shifts = PackedInt32Array([run.shift_index + 1])
		_machine_part = ANNOUNCE_PREFIX % roundi(seconds * 10.0)
	await get_tree().create_timer(seconds).timeout


## Waits (at most ARM_LIMIT_MS, real time) for the machine to reach its wait point and arm.
func _machine_armed(view: RewardMachineView) -> void:
	view.fast_forward()
	var start: int = Time.get_ticks_msec()
	while not view.is_armed() and Time.get_ticks_msec() - start < ARM_LIMIT_MS:
		await get_tree().process_frame


## At a wait point, waits (at most ARM_LIMIT_MS, real time) for the machine to arm, so a capture
## there shows the armed state (BIN IT enabled) as a player sees it; mid-animation, no wait.
func _machine_settled(view: RewardMachineView) -> void:
	var start: int = Time.get_ticks_msec()
	while (
		view.is_waiting() and not view.is_armed() and Time.get_ticks_msec() - start < ARM_LIMIT_MS
	):
		await get_tree().process_frame


## The waiting draw's prizes relabelled with `letters`' rarities (c, r, l), in reveal order.
static func _rig_draw(run: RunState, letters: String) -> void:
	var visit: MachineVisit = run.machine.current_visit()
	var drawn: Array[MachinePrize] = visit.prizes.duplicate()
	for index: int in range(mini(drawn.size(), letters.length())):
		drawn[index].rarity = maxi(0, RARITY_LETTERS.find(letters[index].to_lower()))
	visit.set_drawn(drawn)


## The chute named in `options`, or -1.
static func _machine_chute(options: PackedStringArray) -> int:
	for chute: int in RewardMachine.CHUTES:
		if options.has(MachineVisit.CHUTE_NAMES[chute]):
			return chute
	return -1


## The value of the option `prefix` (e.g. "pick=") in `options`, or "".
static func _option_value(options: PackedStringArray, prefix: String) -> String:
	for option: String in options:
		if option.begins_with(prefix):
			return option.trim_prefix(prefix)
	return ""


func _report(message: String) -> void:
	if report_error.is_valid():
		report_error.call(message)
	else:
		push_error(message)


## The value of the command-line user argument `prefix` (e.g. "--capture="), or "".
static func _argument(prefix: String) -> String:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with(prefix):
			return argument.trim_prefix(prefix)
	return ""


static func _card(card_id: String) -> CardDefinition:
	return load("res://data/cards/%s.tres" % card_id) as CardDefinition


static func _upgrade(upgrade_id: String) -> UpgradeDefinition:
	return load("res://data/upgrades/%s.tres" % upgrade_id) as UpgradeDefinition


static func _remove_folder(folder: String) -> void:
	if folder == "" or not DirAccess.dir_exists_absolute(folder):
		return
	for sub: String in DirAccess.get_directories_at(folder):
		_remove_folder(folder.path_join(sub))
	for file_name: String in DirAccess.get_files_at(folder):
		DirAccess.remove_absolute(folder.path_join(file_name))
	DirAccess.remove_absolute(folder)


static func _event_log() -> EventLogService:
	return (Engine.get_main_loop() as SceneTree).root.get_node("/root/EventLog")
