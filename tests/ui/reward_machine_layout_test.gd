extends GdUnitTestSuite
## The RECEIPT REWARDS machine's layout on the 1280x720 stage (#77, look F; build spec 4.1-4.2, 9;
## memory: UI tests check layout, on-screen geometry): on the real shift screen, with the camera at
## the machine (#77 machine v2), the machine and its RESTOCK hood sit at MACHINE_RECT and
## MACHINE_HOOD_RECT inside the stage, right of the register column; the head sits over the
## cabinet and every other part (slot, display, keys, meters, stockroom window, order slip, YOUR
## ORDER plate, belt, box lane) inside it. The prize tickets sit in the tray cells (a short draw
## uses the centre cell for one prize, the left and centre cells for two), their rarity tabs above
## them inside the tray's x range, clear of the hood. Each chute's odds card (and the bonus
## ticket's, and STAMP DAY's REGISTER card) sits above its key inside the machine (#77 machine
## v2). The cart drawer (at its widest) sits below the top bar, right of x 8 and left of the
## first prize cell. The standalone views stand where the camera puts the machine. Every label
## fits its box, and Pixelify is only ever 12 or 24 px (full build plan 6.1). The views are driven
## directly (no input events).

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


## On the real screen: the machine at MACHINE_RECT and its hood at MACHINE_HOOD_RECT, both inside
## the stage and right of the register column and the receipt; the head over the cabinet, below
## the top bar; every other part inside the cabinet.
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
	_assert_rect(view.hood.get_global_rect(), xform * ShiftStage.MACHINE_HOOD_RECT, "hood")
	for rect: Rect2 in [machine, view.hood.get_global_rect()]:
		assert_bool(stage.encloses(rect)).override_failure_message(str(rect)).is_true()
		assert_float(rect.position.x).is_greater_equal((xform * ShiftStage.REGISTER_RECT).end.x)
		assert_float(rect.position.x).is_greater_equal(screen._receipt.get_global_rect().end.x)
	var head: Rect2 = view.head.get_global_rect()
	assert_bool(stage.encloses(head)).is_true()
	assert_float(head.position.y).is_greater_equal(
		(xform * Vector2(0, ShiftStage.TOP_BAR_BOTTOM)).y
	)
	assert_float(head.get_center().x).is_equal_approx(machine.get_center().x, 1.0)
	var parts: Array[Control] = [
		view.slot_plate,
		view.display,
		view.stockroom,
		view.slip,
		view.order_plate,
		view.belt,
		view.box_lane
	]
	parts.append_array(view.keys)
	parts.append_array(view.meters)
	for part: Control in parts:
		(
			assert_bool(machine.encloses(part.get_global_rect()))
			. override_failure_message("%s %s" % [part.name, part.get_global_rect()])
			. is_true()
		)


## The prize tickets in the tray cells (3: left, centre, right; 2: left and centre; 1: the
## centre), at the stage's MACHINE_CELL_X and MACHINE_CELL_Y, on the belt; their rarity tabs,
## once revealed, above them inside the tray's x range, clear of the hood; the display's short
## draw prompt fits.
func test_the_prizes_sit_in_the_tray_cells() -> void:
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
		var belt: Rect2 = view.belt.get_global_rect()
		for index: int in range(count):
			var ticket: PrizeTicket = view.tickets[index]
			var rect: Rect2 = ticket.get_global_rect()
			var cell: int = MachinePlan.cell_of(index, count)
			if count == 1:
				assert_int(cell).is_equal(1)
			elif count == 2:
				assert_int(cell).is_equal(index)
			assert_vector(rect.position).is_equal(
				Vector2(ShiftStage.MACHINE_CELL_X[cell], ShiftStage.MACHINE_CELL_Y)
			)
			assert_bool(belt.encloses(rect)).override_failure_message(str(rect)).is_true()
			assert_bool(ticket.tab.is_visible_in_tree()).is_true()
			var tab: Rect2 = ticket.tab.get_global_rect()
			var tray_left: float = view.global_position.x + PrizeTicket.TRAY_LEFT
			assert_float(tab.position.x).is_greater_equal(tray_left - SLACK)
			assert_float(tab.end.x).is_less_equal(view.hood.get_global_rect().position.x)
			assert_float(tab.position.y).is_less(rect.position.y)
		var prompt: String = RewardMachineView.pick_prompt(count, run)
		assert_str(view.display.texts()[0]).is_equal(prompt)
		if count < 3:
			assert_str(prompt).is_equal("PICK 1 · ONLY %d IN STOCK" % count)
		for label: Label in view.display.labels():
			_assert_fits(label)
		await _close(view)


## The RARE burst and the LEGENDARY sunburst and sparkles sit in the machine's TicketFx layer:
## drawn under every ticket (never over a neighbour's card) and clipped to the tray, which ends
## at the RESTOCK hood's left edge; on a C R L draw and on L L L (the widest shapes in the right
## cell).
func test_the_reveal_shapes_stay_in_the_tray() -> void:
	var legend: int = MachinePrize.Rarity.LEGENDARY
	var draws: Array = [[MachinePrize.Rarity.COMMON, MachinePrize.Rarity.RARE, legend]]
	draws.append([legend, legend, legend])
	draws.append([MachinePrize.Rarity.COMMON, MachinePrize.Rarity.RARE, MachinePrize.Rarity.RARE])
	for rarities: Array in draws:
		var run: RunState = _passed_run(13)
		var view: RewardMachineView = await _open(run)
		assert_bool(run.machine.choose(run, RewardMachine.Chute.NEW_ITEMS)).is_true()
		var visit: MachineVisit = run.machine.current_visit()
		for index: int in range(visit.prizes.size()):
			visit.prizes[index].rarity = int(rarities[index])
		visit.set_drawn(visit.in_drop_order())
		view.show_draw(run)
		view.show_at(view.plan.pick_at)
		await _frames(2)
		var fx: Control = view.ticket_fx
		var clip: Rect2 = fx.get_global_rect()
		var hood: Rect2 = view.hood.get_global_rect()
		assert_bool(fx.clip_contents).is_true()
		assert_float(clip.end.x).is_less_equal(hood.position.x)
		assert_float(clip.position.x).is_greater_equal(
			view.global_position.x + PrizeTicket.TRAY_LEFT
		)
		for ticket: PrizeTicket in view.tickets:
			assert_int(fx.get_index()).is_less(ticket.get_index())
			var shape: Control = ticket.shape()
			if shape == null:
				continue
			assert_bool(fx.is_ancestor_of(shape)).is_true()
			assert_bool(shape.is_visible_in_tree()).is_true()
			# What shows of it (clipped by the layer) ends at the hood's left edge at most.
			var shown: Rect2 = shape.get_global_rect().intersection(clip)
			assert_float(shown.end.x).override_failure_message(str(shown)).is_less_equal(
				hood.position.x
			)
			for spark: TextureRect in ticket.sparkles():
				assert_bool(fx.is_ancestor_of(spark)).is_true()
		await _close(view)
		# The closed machine's tickets took their shapes with them.
		assert_int(fx.get_child_count()).is_equal(0)


## The YOUR ORDER plate stays hidden while a rarity tab sits over it: through a pick's landing
## while the other prizes keep their tabs; it shows again after a bin drops the tickets, or once
## a lone prize has flown.
func test_the_order_plate_stays_under_the_tabs_through_the_landing() -> void:
	var tuning: MachineTuning = load(RewardMachineView.TUNING_PATH)
	var common: int = MachinePrize.Rarity.COMMON
	var plan: MachinePlan = MachinePlan.new(tuning, MachineVisit.Kind.TICKET, false)
	plan.set_draw([common, MachinePrize.Rarity.RARE, MachinePrize.Rarity.LEGENDARY])
	plan.set_landing(MachinePlan.Landing.NEW_CARD, 0, true, MachinePlan.NO_VISIT)
	for t: float in [plan.press, plan.land, plan.punch, plan.end_at]:
		assert_bool(OrderPlate.hidden_at(plan, t)).override_failure_message(str(t)).is_true()
	var lone: MachinePlan = MachinePlan.new(tuning, MachineVisit.Kind.TICKET, false)
	lone.set_draw([common])
	lone.set_landing(MachinePlan.Landing.NEW_CARD, 0, true, MachinePlan.NO_VISIT)
	assert_bool(OrderPlate.hidden_at(lone, lone.press)).is_true()
	assert_bool(OrderPlate.hidden_at(lone, lone.fly_out + OrderPlate.HIDE_TAIL_S + 0.01)).is_false()
	var binned: MachinePlan = MachinePlan.new(tuning, MachineVisit.Kind.TICKET, false)
	binned.set_draw([common, common, common])
	binned.set_landing(MachinePlan.Landing.BIN, 1, false, MachinePlan.NO_VISIT)
	(
		assert_bool(OrderPlate.hidden_at(binned, binned.press + OrderPlate.HIDE_TAIL_S + 0.01))
		. is_false()
	)


## Every chute's odds card (#77 machine v2's B2: shift 1's lit chutes, the bonus ticket's, and
## STAMP DAY's REGISTER card), with the starting stock and with a full collection's, also on a
## full cart: on hover, above its key inside the machine (so inside the stage, below the top bar),
## its tail's tip just above the key's centre, over every part (OddsCard.Z), three rows inside it
## and its lines fitting; the display keeps the wait's lines.
func test_every_odds_card_sits_above_its_key() -> void:
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
		var lines: PackedStringArray = view.display.texts()
		for chute: int in RewardMachine.CHUTES:
			var info: MachineChuteInfo = run.machine.chute_info(run, chute)
			if stamp_day and chute != RewardMachine.Chute.REGISTER:
				continue
			if not stamp_day and info.state != RewardMachine.ChuteState.OPEN:
				continue
			view._hide_odds()
			view._on_key_hovered(chute)
			var card: OddsCard = view.odds_card
			assert_bool(card.visible).override_failure_message(str(chute)).is_true()
			view.idle_time += 1.0
			card.frame(view.clock)
			await _frames(2)
			var rect: Rect2 = card.get_global_rect()
			var where: String = (
				"chute %d (stock %d): %s" % [chute, run.stock.card_ids().size(), rect]
			)
			assert_bool(machine.encloses(rect)).override_failure_message(where).is_true()
			assert_float(rect.position.y).override_failure_message(where).is_greater_equal(
				ShiftStage.TOP_BAR_BOTTOM
			)
			var key: Rect2 = view.keys[chute].get_global_rect()
			var tip: Vector2 = card.global_position + card.tail_tip()
			assert_float(rect.end.y).override_failure_message(where).is_less(key.position.y)
			assert_float(tip.y).override_failure_message(where).is_less_equal(key.position.y)
			assert_float(tip.x).override_failure_message(where).is_between(
				key.position.x, key.end.x
			)
			assert_int(card.z_index).is_equal(OddsCard.Z)
			assert_int(card.rows().size()).is_equal(3)
			for row: Panel in card.rows():
				assert_bool(rect.encloses(row.get_global_rect())).is_true()
			for label: Label in card.shown_labels():
				_assert_fits(label)
			assert_array(Array(view.display.texts())).is_equal(Array(lines))
		await _close(view)


## The cart drawer at its widest (a landing product with more copies than it shows) rests below
## the top bar, its right edge at CART_DRAWER_RIGHT (left of the machine), clear of the receipt,
## and above the floor; its labels fit.
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
	# At its widest it can't keep its right edge at CART_DRAWER_RIGHT: it starts at CART_DRAWER_LEFT
	# and reaches the cabinet's edge, short of the first prize cell (#77 machine v2).
	assert_float(rest.position.x).is_greater_equal(ShiftStage.CART_DRAWER_LEFT)
	assert_float(rest.end.x).is_less_equal(ShiftStage.MACHINE_CELL_X[0])
	assert_float(rest.end.y).is_less_equal(ShiftStage.FLOOR_TOP)
	for label: Label in _labels(drawer):
		_assert_fits(label)
	await _close(view)


## Pixelify only at 12 or 24 px on every machine text, in every state: the chute wait, an odds
## card, the revealed draw, a landing, the bonus ticket's and STAMP DAY's visits, every rarity
## tab at full and compact size; and every plain label fits its box.
func test_pixelify_is_only_12_or_24_and_every_label_fits() -> void:
	var seen: int = 0
	for run: RunState in [_passed_run(20), _bonus_run(21), _stamp_day_run(22)]:
		var view: RewardMachineView = await _open(run)
		seen += _audit(view, "wait")
		if run.phase == RunState.Phase.MACHINE_CHOOSE:
			view._armed = true
			var chute: int = MachineSteps.first_lit(run, RewardMachine.Chute.NEW_ITEMS)
			view.hover_key(chute)
			view.idle_time += 1.0
			view.odds_card.frame(view.clock)
			await _frames(2)
			seen += _audit(view, "odds")
			view._hide_odds()
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
		for compact: bool in [false, true]:
			var tab: RarityTab = auto_free(RarityTab.new(rarity))
			tab.set_compact(compact)
			var label: Label = tab.get_node("Text") as Label
			_assert_pixelify_size(label.get_theme_font("font"), tab.font_size(), tab.text())
	assert_int(seen).is_greater(100)


## A LEGENDARY reveal jolts the machine (look F's shake: 3 px across, 2 px down and up, at 60-70 %
## of the reveal) after a gold flash over the whole stage (35-45 %, fading from 0.28); a COMMON or
## RARE reveal and reduced motion never do.
func test_a_legendary_reveal_shakes_and_flashes() -> void:
	var run: RunState = _passed_run(24)
	var view: RewardMachineView = await _open(run)
	var legend: int = MachinePrize.Rarity.LEGENDARY
	for rm: bool in [false, true]:
		var plan: MachinePlan = MachinePlan.new(view.tuning, MachineVisit.Kind.TICKET, rm)
		plan.set_draw([MachinePrize.Rarity.COMMON, MachinePrize.Rarity.RARE, legend])
		var at: Callable = func(index: int, p: float) -> float:
			return plan.reveal_at[index] + plan.reveal_length[index] * p
		var shake: Vector2 = MachineLayers.legendary_shake(plan, at.call(2, 0.65))
		var flash: float = MachineLayers.legendary_flash(plan, at.call(2, 0.36))
		if rm:
			assert_vector(shake).is_equal(Vector2.ZERO)
			assert_float(flash).is_equal(0.0)
			continue
		assert_float(absf(shake.x)).is_equal(MachineLayers.SHAKE_X)
		assert_float(absf(shake.y)).is_equal(MachineLayers.SHAKE_Y)
		assert_float(flash).is_between(0.2, MachineLayers.FLASH_ALPHA)
		for p: float in [0.2, 0.5, 0.8, 1.0]:
			assert_vector(MachineLayers.legendary_shake(plan, at.call(2, p))).is_equal(Vector2.ZERO)
		assert_float(MachineLayers.legendary_flash(plan, at.call(2, 0.5))).is_equal(0.0)
		for index: int in [0, 1]:
			assert_vector(MachineLayers.legendary_shake(plan, at.call(index, 0.65))).is_equal(
				Vector2.ZERO
			)
	# On the machine: the flash covers the stage; the shake moves the machine, then it settles.
	assert_bool(run.machine.choose(run, RewardMachine.Chute.NEW_ITEMS)).is_true()
	var visit: MachineVisit = run.machine.current_visit()
	for prize: MachinePrize in visit.prizes:
		prize.rarity = legend
	visit.set_drawn(visit.in_drop_order())
	view.show_draw(run)
	var reveal: Callable = func(p: float) -> float:
		return view.plan.reveal_at[0] + view.plan.reveal_length[0] * p
	view.show_at(reveal.call(0.36))
	assert_bool(view.flash.visible).is_true()
	assert_vector(view.flash.get_global_rect().size).is_equal(ShiftStage.SIZE)
	view.show_at(reveal.call(0.65))
	# The whole stage shakes (look F's #shakeWrap): its stage layer and its flash move with the
	# stage, so the flash still covers it (the machine shakes with the camera's world: #77
	# machine v2, checked in store_camera_test).
	var stage: Control = view.stage
	assert_float(stage.position.length()).is_greater(1.0)
	assert_vector(view.stage_layer.global_position).is_equal(stage.global_position)
	view.show_at(reveal.call(0.9))
	assert_bool(view.flash.visible).is_false()
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
	# A key's SEE ODDS tab sticks out above its key on purpose (look F): its box is ChuteKey's.
	if parent == null or parent.size == Vector2.ZERO or parent is ChuteKey:
		if parent is ChuteKey:
			_assert_rect(label.get_rect(), ChuteKey.TAB_RECT, "%s: %s" % [where, label.text])
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
	var stock: RunStock = RunStock.starting(deck, balance)
	if full:
		var unlocked: Dictionary[StringName, int] = {}
		var listed: Array[StringName] = []
		for aisle: AisleDefinition in balance.aisles:
			listed.append(aisle.id)
			for card: CardDefinition in aisle.capsule_cards:
				unlocked[card.id] = 0
		stock = RunStock.build(deck, balance, listed, unlocked, balance.end_cap_window_runs + 1)
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
