extends GdUnitTestSuite
## The RECEIPT REWARDS machine's layout on the 1280x720 stage (#77, look F; build spec 4.1-4.2, 9;
## v0.50 front-on redraw, mock-up premium_machine_v1.html; memory: UI tests check layout,
## on-screen geometry): on the real shift screen, with the camera at the machine (#77 machine v2),
## the machine sits at MACHINE_RECT wholly inside the stage, right of the register column; the
## head sits over the cabinet and every other part (slot, display, stock window, key bay, tray)
## inside it. The prize row stands at PrizeRow.card_rect on the stage, its tickets apart, their
## rarity tabs above them under the top bar; the back effects draw behind every ticket. The stock
## window fits on every kind of visit. The cart drawer sits below the top bar, left of the machine.
## Every label fits its box, and Pixelify is only ever 12 or 24 px (full build plan 6.1). The views
## are driven directly (no input events).

const Rush := preload("res://tests/ui/count_up_rush.gd")
const SCREEN := "res://ui/shift_screen.tscn"
const BALANCE := "res://data/balance/balance.tres"
const STARTER := "res://data/decks/starter.tres"
const SPOT_CHECK := "res://data/inspections/spot_check.tres"
const MILK := "res://data/cards/milk.tres"
## Milk, Multipack, then five Milks (109): passes shift 1.
const PASSING_ROW: Array[String] = ["milk", "multipack", "milk", "milk", "milk", "milk", "milk"]
## The only Pixelify sizes (full build plan 6.1).
const PIXELIFY_SIZES: Array[int] = [12, 24]
## Room for a tilted or wrapped line's rounding.
const SLACK := 4.0

var _folder: String = ""


func before_test() -> void:
	_folder = "user://test_machine_layout_%d" % Time.get_ticks_usec()
	_event_log().use_folder(_folder)
	ProjectSettings.set_setting(SaveService.FOLDER_SETTING, _folder)


func after_test() -> void:
	ProjectSettings.set_setting(SaveService.FOLDER_SETTING, null)
	if DirAccess.dir_exists_absolute(_folder):
		for file_name: String in DirAccess.get_files_at(_folder):
			DirAccess.remove_absolute(_folder.path_join(file_name))
		DirAccess.remove_absolute(_folder)


## On the real screen (v0.50 front-on redraw): the machine at MACHINE_RECT, wholly inside the stage
## (its tray no longer cropped by the view's foot) and right of the register column and the
## receipt; the marquee over the cabinet, below the top bar; the display, the slot plate, the stock
## window, the key bay and the tray inside the cabinet.
func test_the_machine_sits_beside_the_register_inside_the_stage() -> void:
	var runner: GdUnitSceneRunner = scene_runner(SCREEN)
	var screen: ShiftScreen = runner.scene()
	for id: String in PASSING_ROW:
		screen._debug.add_card(id)
		screen._on_hand_card_clicked(_view_for(screen, screen.run.hand()[-1]))
		screen._on_slot_input(_left_click(), screen.run.row.size())
	await Rush.checkout(screen)
	assert_int(screen.run.phase).is_equal(RunState.Phase.MACHINE_CHOOSE)
	var view: RewardMachineView = screen._machine.view
	view.fast_forward()
	await _frames(3)
	var xform: Transform2D = screen._stage.get_global_transform()
	var stage: Rect2 = xform * Rect2(Vector2.ZERO, ShiftStage.SIZE)
	var machine: Rect2 = view.get_global_rect()
	_assert_rect(machine, xform * ShiftStage.MACHINE_RECT, "machine")
	assert_bool(stage.encloses(machine)).override_failure_message(str(machine)).is_true()
	assert_float(machine.position.x).is_greater_equal((xform * ShiftStage.REGISTER_RECT).end.x)
	assert_float(machine.position.x).is_greater_equal(screen._receipt.get_global_rect().end.x)
	var head: Rect2 = view.head.get_global_rect()
	assert_bool(stage.encloses(head)).is_true()
	assert_float(head.position.y).is_greater_equal(
		(xform * Vector2(0, ShiftStage.TOP_BAR_BOTTOM)).y
	)
	assert_float(head.get_center().x).is_equal_approx(machine.get_center().x, 1.0)
	var parts: Array[Control] = [view.slot_plate, view.display, view.stock, view.key_bay, view.tray]
	for part: Control in parts:
		(
			assert_bool(machine.encloses(part.get_global_rect()))
			. override_failure_message("%s %s" % [part.name, part.get_global_rect()])
			. is_true()
		)


## The prize row (3, 2 and 1 tickets) at PrizeRow.card_rect on the machine: every ticket inside the
## stage, none overlapping another; its rarity tab, once landed, above it, inside the stage and
## below the top bar; the display's short draw prompt fits.
func test_the_prize_row_sits_on_the_stage() -> void:
	var on_stage: Rect2 = Rect2(Vector2.ZERO, ShiftStage.SIZE)
	for count: int in [3, 2, 1]:
		var run: RunState = _passed_run(12)
		var view: RewardMachineView = await _open(run)
		assert_bool(run.machine.choose(run, RewardMachine.Chute.NEW_ITEMS)).is_true()
		var visit: MachineVisit = run.machine.current_visit()
		visit.set_drawn(visit.in_drop_order().slice(0, count))
		view.show_draw(run)
		view.show_at(view.plan.pick_at)
		await _frames(2)
		assert_int(view.tickets.size()).is_equal(count)
		var shown: Array[Rect2] = []
		for index: int in range(count):
			var ticket: PrizeTicket = view.tickets[index]
			var rect: Rect2 = ticket.get_global_rect()
			var expected: Rect2 = PrizeRow.card_rect(index, count)
			expected.position += ShiftStage.MACHINE_RECT.position
			_assert_rect(rect, expected, "ticket %d of %d" % [index, count])
			assert_bool(on_stage.encloses(rect)).override_failure_message(str(rect)).is_true()
			for other: Rect2 in shown:
				assert_bool(rect.intersects(other)).is_false()
			shown.append(rect)
			assert_bool(ticket.tab.is_visible_in_tree()).is_true()
			var tab: Rect2 = ticket.tab.get_global_rect()
			assert_float(tab.position.y).is_less(rect.position.y)
			assert_float(tab.position.y).is_greater_equal(ShiftStage.TOP_BAR_BOTTOM)
			assert_bool(on_stage.encloses(tab)).is_true()
		var prompt: String = RewardMachineView.pick_prompt(count, run)
		assert_str(view.display.texts()[0]).is_equal(prompt)
		if count < 3:
			assert_str(prompt).is_equal("PICK 1 · ONLY %d IN STOCK" % count)
		for label: Label in view.display.labels():
			_assert_fits(label)
		await _close(view)


## The RARE glow and the LEGENDARY sunburst stand behind every ticket of the row (each ticket a z
## step up, its back effects a step down again), so a neighbour's burst never covers a card; on
## L L L, the widest case.
func test_the_back_effects_draw_behind_every_ticket() -> void:
	var legend: int = MachinePrize.Rarity.LEGENDARY
	var run: RunState = _passed_run(13)
	var view: RewardMachineView = await _open(run)
	assert_bool(run.machine.choose(run, RewardMachine.Chute.NEW_ITEMS)).is_true()
	var visit: MachineVisit = run.machine.current_visit()
	for prize: MachinePrize in visit.prizes:
		prize.rarity = legend
	visit.set_drawn(visit.in_drop_order())
	view.show_draw(run)
	view.show_at(view.plan.pick_at)
	await _frames(2)
	for ticket: PrizeTicket in view.tickets:
		var back: Control = ticket.get_node("FxBack")
		assert_int(ticket.z_index).is_equal(1)
		assert_bool(back.z_as_relative).is_true()
		assert_int(ticket.z_index + back.z_index).is_less(ticket.z_index)
		assert_float(ticket.burst_radius()).is_greater(0.0)
	await _close(view)


## The stock window (v0.50, M4) on every kind of visit (shift 1's lit chutes, the bonus ticket's,
## STAMP DAY's LOYALTY column), with the starting stock and with a full collection's, also on a
## full cart: inside the machine, above the key bay, its lit columns' odds and words fitting inside
## it; the display keeps the wait's lines while a key is hovered.
func test_the_stock_window_fits_on_every_visit() -> void:
	var runs: Array[RunState] = [
		_passed_run(14),
		_bonus_run(15),
		_stamp_day_run(16),
		_passed_run(31, Callable(), true),
		_bonus_run(32, true),
		_stamp_day_run(33, true),
		_bonus_run(34, true, true),
		_passed_run(35, _with_full_cart, true),
	]
	for run: RunState in runs:
		var view: RewardMachineView = await _open(run)
		var stamp_day: bool = run.phase == RunState.Phase.MACHINE_PICK
		view.show_at(view.plan.pick_at if stamp_day else view.plan.choose_at)
		view._armed = true  # Headless: no mouse release arms it.
		var machine: Rect2 = view.get_global_rect()
		var window: Rect2 = view.stock.get_global_rect()
		assert_bool(machine.encloses(window)).is_true()
		assert_float(window.end.y).is_less_equal(view.key_bay.get_global_rect().position.y)
		var lines: PackedStringArray = view.display.texts()
		var lit: int = 0
		for chute: int in RewardMachine.CHUTES:
			if not view.stock.column_lit(chute):
				continue
			lit += 1
			view._on_key_hovered(chute)
			assert_array(Array(view.display.texts())).is_equal(Array(lines))
		var where: String = "stock %d, phase %d" % [run.stock.card_ids().size(), run.phase]
		assert_int(lit).override_failure_message(where).is_greater(0)
		for label: Label in view.stock.labels():
			if not label.visible:
				continue
			assert_bool(window.encloses(label.get_global_rect())).is_true()
			_assert_fits(label)
		await _close(view)


## The cart drawer at its widest (a landing product with more copies than it shows) rests below
## the top bar, left of the machine, and above the floor; its labels fit.
func test_the_cart_drawer_sits_left_of_the_machine() -> void:
	var run: RunState = _passed_run(18, _with_milks)
	var view: RewardMachineView = await _open(run)
	assert_bool(run.machine.choose(run, RewardMachine.Chute.NEW_ITEMS)).is_true()
	var visit: MachineVisit = run.machine.current_visit()
	visit.prizes[0].card = load(MILK)
	view.show_draw(run)
	view.show_at(view.plan.pick_at)
	view.land(run.machine.pick(run, 0, null))
	view.show_at(view.plan.land + 0.1)
	await _frames(2)
	var drawer: CartDrawer = view.cart_drawer
	assert_bool(drawer.is_visible_in_tree()).is_true()
	assert_int(drawer.slots.size()).is_equal(CartDrawer.MAX_SLOTS)
	var rest: Rect2 = drawer.rest_rect()
	assert_float(rest.position.y).is_greater_equal(ShiftStage.TOP_BAR_BOTTOM)
	assert_float(rest.position.x).is_greater_equal(ShiftStage.CART_DRAWER_LEFT)
	assert_float(rest.end.x).is_less_equal(ShiftStage.CART_DRAWER_REACH)
	assert_float(rest.end.y).is_less_equal(ShiftStage.FLOOR_TOP)
	for label: Label in _labels(drawer):
		_assert_fits(label)
	await _close(view)


## Pixelify only at 12 or 24 px on every machine text, in every state: the chute wait, a hovered
## key, a pressed key, the landed row, a landing, the bonus ticket's and STAMP DAY's visits, and
## a PREMIUM visit; every rarity tab; and every plain label fits its box.
func test_pixelify_is_only_12_or_24_and_every_label_fits() -> void:
	var seen: int = 0
	var runs: Array[RunState] = [
		_passed_run(20), _bonus_run(21), _stamp_day_run(22), _passed_run(23, _boosted)
	]
	for run: RunState in runs:
		var view: RewardMachineView = await _open(run)
		seen += _audit(view, "wait")
		if run.phase == RunState.Phase.MACHINE_CHOOSE:
			view._armed = true
			var chute: int = MachineSteps.first_lit(run, RewardMachine.Chute.NEW_ITEMS)
			view.hover_key(chute)
			await _frames(2)
			seen += _audit(view, "hover")
			view.press_key(chute)  # The title mode with CONFIRM › (#77 machine v2).
			view.show_at(view.clock)
			await _frames(2)
			seen += _audit(view, "pressed")
			assert_bool(run.machine.choose(run, chute)).is_true()
			view.show_draw(run)
		view.show_at(view.plan.pick_at)
		await _frames(2)
		seen += _audit(view, "pick")
		view.land(MachineSteps.take(run, 0))
		view.show_at(view.plan.land + 0.1)
		await _frames(2)
		seen += _audit(view, "landing")
		await _close(view)
	for rarity: int in range(RarityTab.TEXTS.size()):
		var tab: RarityTab = auto_free(RarityTab.new(rarity))
		var label: Label = tab.label()
		_assert_pixelify_size(
			label.get_theme_font("font"), label.get_theme_font_size("font_size"), tab.text()
		)
		_assert_fits(label)
	assert_int(seen).is_greater(100)


## A LEGENDARY landing jolts the stage (6 px across, 4 px down and up, decaying over SHAKE_S); a
## COMMON or RARE landing and reduced motion never do. On the machine the stage moves, then
## settles back.
func test_a_legendary_landing_shakes_the_stage() -> void:
	var run: RunState = _passed_run(24)
	var view: RewardMachineView = await _open(run)
	var legend: int = MachinePrize.Rarity.LEGENDARY
	for rm: bool in [false, true]:
		var plan: MachinePlan = MachinePlan.new(view.tuning, MachineVisit.Kind.TICKET, rm)
		plan.set_draw([MachinePrize.Rarity.COMMON, MachinePrize.Rarity.RARE, legend])
		var shake: Vector2 = MachineLayers.legendary_shake(plan, plan.reveal_at[2] + 0.001)
		if rm:
			assert_vector(shake).is_equal(Vector2.ZERO)
			continue
		assert_float(absf(shake.x)).is_less_equal(MachineLayers.SHAKE_X)
		assert_float(absf(shake.x)).is_greater(0.0)
		assert_float(absf(shake.y)).is_less_equal(MachineLayers.SHAKE_Y)
		var settled: float = plan.reveal_at[2] + MachineLayers.SHAKE_S + 0.01
		assert_vector(MachineLayers.legendary_shake(plan, settled)).is_equal(Vector2.ZERO)
		for index: int in [0, 1]:
			var calm: Vector2 = MachineLayers.legendary_shake(plan, plan.reveal_at[index] + 0.05)
			assert_vector(calm).is_equal(Vector2.ZERO)
	assert_bool(run.machine.choose(run, RewardMachine.Chute.NEW_ITEMS)).is_true()
	var visit: MachineVisit = run.machine.current_visit()
	for prize: MachinePrize in visit.prizes:
		prize.rarity = legend
	visit.set_drawn(visit.in_drop_order())
	view.show_draw(run)
	view.show_at(view.plan.reveal_at[0] + 0.001)
	var stage: Control = view.stage
	assert_float(stage.position.length()).is_greater(1.0)
	assert_vector(view.stage_layer.global_position).is_equal(stage.global_position)
	view.show_at(view.plan.pick_at)
	assert_vector(stage.position).is_equal(Vector2.ZERO)
	await _close(view)


## Checks every shown text under `view` (with its stage layer and odds card): Pixelify at 12 or
## 24, plain labels fitting; returns how many it checked.
func _audit(view: RewardMachineView, where: String) -> int:
	var checked: int = 0
	for found: Node in view.find_children("*", "Control", true, false):
		var text: Control = found as Control
		if not text.is_visible_in_tree():
			continue
		if text is Label:
			var label: Label = text as Label
			if label.text.strip_edges().is_empty():
				continue
			_assert_pixelify_size(
				label.get_theme_font("font"),
				label.get_theme_font_size("font_size"),
				"%s: %s" % [where, label.text]
			)
			if label.autowrap_mode == TextServer.AUTOWRAP_OFF and not _tilted(label):
				_assert_fits(label)
			if not _tilted(label):
				_assert_in_parent(label, where)
			checked += 1
		elif text is Button:
			var button: Button = text as Button
			_assert_pixelify_size(
				button.get_theme_font("font"),
				button.get_theme_font_size("font_size"),
				"%s: %s" % [where, button.text]
			)
			checked += 1
		elif text is RichTextLabel:
			var rich: RichTextLabel = text as RichTextLabel
			for kind: String in ["normal", "bold"]:
				_assert_pixelify_size(
					rich.get_theme_font(kind + "_font"),
					rich.get_theme_font_size(kind + "_font_size"),
					"%s: %s" % [where, rich.get_parsed_text()]
				)
			checked += 1
	return checked


## Whether `control` or a parent up to the machine is turned (a stamp, a tab): its box is
## checked by its owner's tests.
static func _tilted(control: Control) -> bool:
	var node: Node = control
	while node is Control and not node is RewardMachineView:
		if not is_zero_approx((node as Control).rotation):
			return true
		node = node.get_parent()
	return false


func _assert_pixelify_size(font: Font, font_size: int, what: String) -> void:
	if font == null or not _is_pixelify(font):
		return
	(
		assert_bool(PIXELIFY_SIZES.has(font_size))
		. override_failure_message("Pixelify %d px: %s" % [font_size, what])
		. is_true()
	)


## Whether `font` draws with Pixelify Sans (itself, or a variation of it).
static func _is_pixelify(font: Font) -> bool:
	var base: Font = font
	while base is FontVariation and (base as FontVariation).base_font != null:
		base = (base as FontVariation).base_font
	return base == ArtStyle.DISPLAY_FONT or base.get_font_name().begins_with("Pixelify")


## The label's text fits its box: one line within its width, or its wrapped lines within its
## height.
func _assert_fits(label: Label) -> void:
	var font: Font = label.get_theme_font("font")
	var font_size: int = label.get_theme_font_size("font_size")
	var failure: String = "%s: '%s' in %s" % [label.name, label.text, label.size]
	if label.autowrap_mode == TextServer.AUTOWRAP_OFF:
		var widest: float = 0.0
		for line: String in label.text.split("\n"):
			widest = maxf(
				widest, font.get_string_size(line, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
			)
		assert_float(widest).override_failure_message(failure).is_less_equal(label.size.x + 0.5)
		return
	for word: String in label.text.replace(String.chr(10), " ").split(" "):
		var width: float = font.get_string_size(word, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
		assert_float(width).override_failure_message(failure).is_less_equal(label.size.x + 0.5)
	var height: float = label.get_line_count() * font.get_height(font_size)
	assert_float(height).override_failure_message(failure).is_less_equal(label.size.y + SLACK)


## The label keeps the box its part gave it, inside its parent: a part that sizes a label before
## the machine is in the tree must apply the label's theme first (RewardMachineView.fit), or the
## box grows to the default font's size and the centred text slides off centre.
func _assert_in_parent(label: Label, where: String) -> void:
	var parent: Control = label.get_parent() as Control
	if parent == null or parent.size == Vector2.ZERO:
		return
	(
		assert_bool(Rect2(Vector2.ZERO, parent.size).grow(0.5).encloses(label.get_rect()))
		. override_failure_message(
			(
				"%s: '%s' at %s outside its parent %s (%s)"
				% [where, label.text, label.get_rect(), parent.name, parent.size]
			)
		)
		. is_true()
	)


static func _labels(root: Node) -> Array[Label]:
	var found: Array[Label] = []
	for node: Node in root.find_children("*", "Label", true, false):
		var label: Label = node as Label
		if label.is_visible_in_tree() and not label.text.strip_edges().is_empty():
			if label.autowrap_mode == TextServer.AUTOWRAP_OFF and not _tilted(label):
				found.append(label)
	return found


func _assert_rect(rect: Rect2, expected: Rect2, what: String) -> void:
	(
		assert_vector(rect.position)
		. override_failure_message("%s at %s" % [what, rect])
		. is_equal_approx(expected.position, Vector2(0.5, 0.5))
	)
	assert_vector(rect.size).override_failure_message("%s at %s" % [what, rect]).is_equal_approx(
		expected.size, Vector2(0.5, 0.5)
	)


## The machine on a 1280x720 stage at the stage's origin, open on `run`'s visit at its wait point.
func _open(run: RunState) -> RewardMachineView:
	var stage: Control = auto_free(Control.new())
	stage.size = ShiftStage.SIZE
	add_child(stage)
	var view: RewardMachineView = auto_free(RewardMachineView.new())
	add_child(view)
	# Where the camera puts it at the machine (#77 machine v2): MACHINE_RECT at scale 1.
	view.position = ShiftStage.MACHINE_RECT.position
	# The receipt the visit hides (torn off), on the stage like the screen's.
	var receipt: Control = Control.new()
	receipt.position = Vector2(ShiftStage.RECEIPT_X, ShiftStage.RECEIPT_TOP)
	receipt.size = Vector2(
		ShiftStage.RECEIPT_WIDTH, ShiftStage.RECEIPT_BOTTOM - ShiftStage.RECEIPT_TOP
	)
	stage.add_child(receipt)
	view.open_visit(run, receipt, stage, false)
	view.fast_forward()
	await _frames(3)
	return view


## Closes the machine and lets the parts it dropped be freed (auto_free frees it and its stage
## at the test's end).
func _close(view: RewardMachineView) -> void:
	view.close()
	await _frames(2)


## A run that passed shift 1 (`prepare`, when given, edits it first); `full`: with a full
## collection's stock (every aisle listed, every capsule unlocked, as SimCollection.full).
static func _passed_run(
	seed_value: int, prepare: Callable = Callable(), full: bool = false
) -> RunState:
	var balance: BalanceDefinition = load(BALANCE)
	var deck: DeckDefinition = load(STARTER)
	var stock: RunStock = RunStock.starting(balance)
	if full:
		var unlocked: Dictionary[StringName, int] = {}
		var listed: Array[StringName] = []
		for aisle: AisleDefinition in balance.aisles:
			listed.append(aisle.id)
			for card: CardDefinition in aisle.capsule_cards:
				unlocked[card.id] = 0
		stock = RunStock.build(balance, listed, unlocked, balance.end_cap_window_runs + 1)
	var run: RunState = RunState.new(seed_value, deck, balance, stock)
	if prepare.is_valid():
		prepare.call(run)
	run.start_shift()
	for id: String in PASSING_ROW:
		run.place(run.debug_add_to_hand(load("res://data/cards/%s.tres" % id)), run.row.size())
	run.checkout()
	return run


## A run waiting at the bonus ticket's chute wait (shift 1 passed a Spot check; its ticket took
## a NEW ITEMS prize); `full`: a full collection's stock; `full_cart`: the cart at its limit.
static func _bonus_run(seed_value: int, full: bool = false, full_cart: bool = false) -> RunState:
	var prepare: Callable = _with_full_cart if full_cart else Callable()
	var run: RunState = _passed_run(seed_value, prepare, full)
	run.history[-1].inspection = load(SPOT_CHECK)
	run.machine.begin_after_checkout(run)
	MachineSteps.choose(run, RewardMachine.Chute.NEW_ITEMS)
	MachineSteps.take(run, 0)
	return run


## A run waiting at STAMP DAY's pick (after shift 1; its ticket binned a NEW ITEMS draw);
## `full`: a full collection's stock.
static func _stamp_day_run(seed_value: int, full: bool = false) -> RunState:
	var run: RunState = _passed_run(seed_value, _with_stamp_day, full)
	MachineSteps.choose(run, RewardMachine.Chute.NEW_ITEMS)
	run.machine.bin(run)
	return run


static func _with_stamp_day(run: RunState) -> void:
	run.machine.machine = run.machine.machine.duplicate() as MachineDefinition
	run.machine.machine.stamp_day_shifts = PackedInt32Array([1])
	run.machine.machine.stamp_day_floor = PackedInt32Array([1])


## Milk copies up to the deck limit (a full cart: a NEW ITEMS pick swaps a card out).
static func _with_full_cart(run: RunState) -> void:
	var milk: CardDefinition = load(MILK)
	while run.deck.size() < run.balance.deck_limit:
		run.deck.add_card(milk)


## Milk copies up to one under the deck limit, so a Milk prize lands among more copies than the
## drawer shows.
static func _with_milks(run: RunState) -> void:
	var milk: CardDefinition = load(MILK)
	while run.deck.size() < run.balance.deck_limit - 1:
		run.deck.add_card(milk)


## Shift 1's ticket visit BOOSTED: the machine turns PREMIUM (v0.50).
static func _boosted(run: RunState) -> void:
	MachineSteps.boost_run(run, [1] as Array[int])


static func _view_for(screen: ShiftScreen, card: CardInstance) -> CardView:
	for child: Node in screen._hand_box.get_children():
		var view: CardView = child as CardView
		if view and view.card == card and not view.is_queued_for_deletion():
			return view
	return null


static func _left_click() -> InputEventMouseButton:
	var click: InputEventMouseButton = InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	return click


func _frames(count: int) -> void:
	for i: int in range(count):
		await get_tree().process_frame


static func _event_log() -> EventLogService:
	return (Engine.get_main_loop() as SceneTree).root.get_node("/root/EventLog")
