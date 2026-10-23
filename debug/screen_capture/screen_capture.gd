extends Control
## The screen capture (#55, #75; full build plan section 6.1): the real shift screen on fixed
## data, to review the look and to record it in docs/art/. It replaces the style frames, whose
## captures (docs/art/style_frame_*.png and style_frame_v2_*.png) stay as the record of the
## approved frames. #56 adds the other screens.
##
## The shift: shift 5 of 8 on a fixed seed, under Short belt (5 product slots and a CLOSED one),
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
## and Coupon engine fizzles on it, Slot engine stamps the 6th product), and the file is
## shift_screen_effects_<width>x<height>.png. `--effects=<card id>` also hovers that card's belt
## item (the first), highlighting its causes and targets, and lets its scan finish so the monitor
## explains it (its "gives" line, as in mock-up h1's hover); the file is
## shift_screen_effects_focus_<width>x<height>.png.
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
	if effects_on or focus_id != "":
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


## Sets up the fixed shift under the inspection `inspection_id` with the cards `row_ids` on the
## belt.
func _set_up_shift(inspection_id: String, row_ids: Array[String]) -> void:
	_screen.start_new_run(SEED)
	var run: RunState = _screen.run
	var starter: DeckDefinition = run.starter.duplicate()
	starter.starting_upgrade = _upgrade(UPGRADE_IDS[0])
	run.starter = starter
	var upgrades: Array[UpgradeDefinition] = []
	for upgrade_id: String in UPGRADE_IDS:
		upgrades.append(_upgrade(upgrade_id))
	run.upgrades = upgrades
	run.debug_skip_to_shift(SHIFT - 1)
	# The same shift again: it keeps the inspection set here.
	var inspection: InspectionDefinition = load("res://data/inspections/%s.tres" % inspection_id)
	run.inspections = [inspection]
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
## under the Spot check) and, for a `card_id`, hovers the first belt item of that card once the
## items are laid out and scans it, as the player's resting pointer would; capture() then names
## its file shift_screen_effects_[focus_]<w>x<h>.png. A card that isn't on the belt goes to
## report_error.
func effects(card_id: String = "") -> void:
	_set_up_shift(EFFECTS_INSPECTION, EFFECTS_ROW_IDS)
	_effects = true
	_focused = false
	if card_id == "":
		return
	for _frame: int in range(SCAN_SETTLE_FRAMES):
		await get_tree().process_frame
	for found: Node in _screen.find_children("*", "ItemView", true, false):
		var item: ItemView = found as ItemView
		var on_belt: bool = item.form == ItemView.Form.BELT and not item.is_queued_for_deletion()
		if on_belt and item.card.definition.id == card_id:
			item.hovered.emit(item)
			# The pointer rests on it past the scan's delay: the monitor explains it (mock-up h1).
			_screen.debug_scan(item.card)
			_focused = true
			return
	_report("No %s on the belt to hover" % card_id)


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
	prefix += _machine_part
	var path: String = folder.path_join(FILE_NAME % [prefix, window.x, window.y])
	var image: Image = (
		grab_image.call() as Image
		if grab_image.is_valid()
		else get_viewport().get_texture().get_image()
	)
	var error: Error = ERR_UNAVAILABLE if image == null else image.save_png(path)
	if error != OK:
		_report("Can't save %s (error %d)" % [path, error])


## Opens the RECEIPT REWARDS machine (#77) on a new run (the same seed) whose shift 1 checked out
## its passing row, as the dessert's printer feed would, then waits `spec`'s seconds; capture()
## then names its file shift_screen_machine_<options>_<tenths>_<w>x<h>.png. `spec` is
## "<seconds>[,<option>...]", the options (in any order):
## - new_items, coupons, register or upgrades: that chute is chosen at the keys (its draw plays);
## - odds: that chute's odds card is shown above its key instead (as on hover); press: that
##   chute's key is pressed instead (the display's title with CONFIRM ›);
## - bonus: the shift passed a Spot check; its ticket picks a NEW ITEMS prize, and the bonus
##   ticket's visit is shown; stampday: the shift is a STAMP DAY's; its ticket bins a NEW ITEMS
##   draw, and STAMP DAY's draw is shown (pick=<i> picks a stamp);
## - cartfull: the cart is at the deck limit before the checkout;
## - draw=<letters>: the draw's rarities, c, r or l per prize (a debug draw: the prizes drawn,
##   relabelled), shown rarest last;
## - pick=<i>: once the prizes are armed, prize i is picked (its landing plays);
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
		run.machine.choose(run, RewardMachine.Chute.NEW_ITEMS)
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
