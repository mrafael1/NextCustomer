extends GdUnitTestSuite
## The RECEIPT REWARDS machine's layout on the 1280x720 stage (#77, look F; build spec 4.1-4.2, 9;
## v0.50 front-on redraw, mock-up premium_machine_v1.html; memory: UI tests check layout, on-screen
## geometry): on the real shift screen, with the camera at the machine (#77 machine v2), the machine
## sits at MACHINE_RECT wholly inside the stage, right of the register column; the head sits over
## the cabinet and every other part (slot, display, stock window, key bay, tray) inside it. The
## prize row stands at PrizeRow.card_rect on the stage, its tickets apart, their rarity tabs above
## them under the top bar; the back effects draw behind every ticket. The stock window fits on every
## kind of visit, its sealed tickets crisp and its odds on plates (v0.53); a lit key's glow hugs its
## shape (v0.53). The cart drawer sits below the top bar, left of the machine. Every label fits its
## box, and Pixelify is only ever 12 or 24 px (full build plan 6.1). The views are driven directly
## (no input events).

const Rush := preload("res://tests/ui/count_up_rush.gd")
const SCREEN := "res://ui/shift_screen.tscn"
const BALANCE := "res://data/balance/balance.tres"
const STARTER := "res://data/decks/starter.tres"
const SPOT_CHECK := "res://data/inspections/spot_check.tres"
const MILK := "res://data/cards/milk.tres"
const COUPON_ENGINE := "res://data/upgrades/coupon_engine.tres"
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


## The stock window (v0.50, M4) on every kind of visit (shift 1's two lit chutes, the bonus
## ticket's, a PREMIUM visit's gold columns), with the starting stock and with a full collection's,
## also on a full cart: inside the machine, above the key bay, each column over its key, its lit
## columns' odds and words fitting inside it; the display keeps the wait's lines while a key is
## hovered.
func test_the_stock_window_fits_on_every_visit() -> void:
	var runs: Array[RunState] = [
		_passed_run(14),
		_bonus_run(15),
		_passed_run(16, _premium),
		_passed_run(31, Callable(), true),
		_bonus_run(32, true),
		_passed_run(33, _premium, true),
		_bonus_run(34, true, true),
		_passed_run(35, _with_full_cart, true),
	]
	for run: RunState in runs:
		var view: RewardMachineView = await _open(run)
		view.show_at(view.plan.choose_at)
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
			# The column stands over its key (NEW ITEMS left, UPGRADE right).
			var middle: float = window.position.x + window.size.x / 4.0 * (2 * chute + 1)
			var key: Rect2 = view.keys[chute].get_global_rect()
			assert_float(absf(middle - key.get_center().x)).is_less(24.0)
			assert_bool(view.stock.column_gold(chute)).is_equal(run.machine.is_premium())
			view._on_key_hovered(chute)
			assert_array(Array(view.display.texts())).is_equal(Array(lines))
		var where: String = "stock %d, phase %d" % [run.stock.card_ids().size(), run.phase]
		assert_int(lit).override_failure_message(where).is_greater(0)
		for label: Label in view.stock.labels():
			if not label.visible:
				continue
			assert_bool(window.encloses(label.get_global_rect())).is_true()
			_assert_fits(label)
		_assert_odds_plates(view.stock)
		await _close(view)


## The BONUS visit after a PREMIUM ticket visit (v0.53, decided with the user on 2026-10-23) is
## PREMIUM from its first frame (no snap back to classic, no second transform): the night sign,
## the trim, the gold tray, both keys up and gold over gold pedestals (v0.61: the same two
## chutes); the display names the bonus ticket.
func test_a_bonus_visit_after_a_premium_one_stays_premium() -> void:
	for rm: bool in [false, true]:
		var run: RunState = _bonus_run(36, false, false, true)
		var visit: MachineVisit = run.machine.current_visit()
		assert_int(visit.kind).is_equal(MachineVisit.Kind.BONUS)
		assert_bool(visit.premium).is_true()
		var view: RewardMachineView = await _open(run, rm)
		assert_bool(view.plan.premium_held).is_true()
		for t: float in [0.0, view.plan.feed_end, view.plan.choose_at]:
			view.show_at(t)
			var when: String = "rm %s at %.2f" % [rm, t]
			assert_bool(view.head.premium_face()).override_failure_message(when).is_true()
			assert_float(view.cabinet.trim_shown()).override_failure_message(when).is_equal(1.0)
			assert_bool(view.tray.is_gold()).override_failure_message(when).is_true()
			for chute: int in RewardMachine.CHUTES:
				assert_bool(view.keys[chute].visible).override_failure_message(when).is_true()
				assert_bool(view.keys[chute].gold).override_failure_message(when).is_true()
		for chute: int in RewardMachine.CHUTES:
			assert_bool(view.stock.column_lit(chute)).is_true()
			assert_bool(view.stock.column_gold(chute)).is_true()
		assert_str(view.display.texts()[0]).is_equal(RewardMachineView.BONUS_TITLE)
		await _close(view)


## Resting the pointer on a revealed prize (v0.53, the user's "user can't see effect of them")
## opens the scan popup with its whole effect, beside its ticket and never over it, on the view,
## its lines inside it: NEW ITEMS (the product's or the coupon's rule), and UPGRADE, classic and
## PREMIUM (a loyalty perk's effect, an item upgrade's card at its new tier). Not before the ticket
## lands face up; gone after the pick.
func test_a_revealed_prize_shows_its_effect_beside_it() -> void:
	var cases: Array[Array] = [
		[_passed_run(37), RewardMachine.Chute.NEW_ITEMS],
		[_passed_run(38), RewardMachine.Chute.UPGRADE],
		[_passed_run(39, _premium), RewardMachine.Chute.UPGRADE],
	]
	var screen: Rect2 = Rect2(Vector2.ZERO, ShiftStage.SIZE)
	for case: Array in cases:
		var run: RunState = case[0]
		var chute: int = case[1]
		var view: RewardMachineView = await _open(run)
		assert_bool(MachineSteps.choose(run, chute)).is_true()
		view.show_draw(run)
		var popup: PrizePopup = view.popup
		view.show_at(view.plan.choose_at)
		assert_bool(popup.open_for(view.tickets[0])).is_false()  # Not landed yet.
		view.show_at(view.plan.pick_at)
		await _frames(1)
		var prizes: Array[MachinePrize] = run.machine.prizes()
		for index: int in range(view.tickets.size()):
			var ticket: PrizeTicket = view.tickets[index]
			var where: String = "chute %d ticket %d" % [chute, index]
			view._on_ticket_hovered(index)
			assert_bool(popup.visible).override_failure_message(where).is_true()
			assert_int(popup.ticket_index).is_equal(index)
			var shown: Rect2 = popup.get_global_rect()
			var card: Rect2 = ticket.get_global_rect()
			assert_bool(shown.intersects(card)).override_failure_message(where).is_false()
			assert_bool(screen.encloses(shown)).override_failure_message(where).is_true()
			for label: Label in popup.text_labels():
				assert_bool(shown.grow(SLACK).encloses(label.get_global_rect())).is_true()
			var rule: String = popup.rule_label().text
			match prizes[index].kind:
				MachinePrize.Kind.REGISTER:
					assert_str(rule).contains(prizes[index].upgrade.effect_text)
				MachinePrize.Kind.UPGRADE:
					var preview: MachinePreview = run.machine.preview(run, index)
					assert_str(popup.name_text()).is_equal(preview.to_cards[0].display_name)
					assert_str(rule).is_equal(preview.to_cards[0].rule_text)
				_:
					assert_str(rule).is_equal(prizes[index].card.rule_text)
			view._on_ticket_unhovered(index)
			assert_bool(popup.visible).is_false()
		view._on_ticket_hovered(0)
		view.land(MachineSteps.take(run, 0))
		assert_bool(popup.visible).is_false()
		await _close(view)


## A lit key's glow (v0.53, the user's "light around buttons aren't even nicely put"): the ring
## hugs the key's whole silhouette, its face over its base (the key's bottom face), GLOW_GAP off
## it, so it never crosses either, at rest and pressed (the face sunk); the fainter outer ring
## stays inside the key bay.
func test_a_lit_key_glow_follows_its_shape() -> void:
	var run: RunState = _passed_run(31)
	var view: RewardMachineView = await _open(run)
	view._armed = true  # Headless: no mouse release arms it.
	var key: ChuteKey = view.keys[RewardMachine.Chute.NEW_ITEMS]
	var bay: Rect2 = Rect2(Vector2.ZERO, RewardMachineView.KEY_BAY_RECT.size)
	for pressed: bool in [false, true]:
		if pressed:
			view.press_key(RewardMachine.Chute.NEW_ITEMS)
			view.show_at(view.clock)
		assert_float(key.glow_level()).is_greater(0.0)
		var ring: Rect2 = key.glow_rect()
		var inside: Rect2 = ring.grow(-MachineArt.PIXEL)
		var face: Rect2 = Rect2(key.face().position, key.face().size)
		var silhouette: Rect2 = face.merge(ChuteKey.BASE_RECT)
		var where: String = "pressed %s" % pressed
		assert_bool(inside.encloses(face)).override_failure_message(where).is_true()
		assert_bool(inside.encloses(ChuteKey.BASE_RECT)).override_failure_message(where).is_true()
		assert_bool(inside.is_equal_approx(silhouette.grow(ChuteKey.GLOW_GAP))).is_true()
		var outer: Rect2 = ring.grow(MachineArt.PIXEL)
		var in_bay: Rect2 = Rect2(key.position + outer.position, outer.size)
		assert_bool(bay.encloses(in_bay)).override_failure_message(where).is_true()
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
## key, a pressed key, the landed row, a landing, the bonus ticket's visit, an UPGRADE visit and a
## PREMIUM visit; every rarity tab; and every plain label fits its box.
func test_pixelify_is_only_12_or_24_and_every_label_fits() -> void:
	var seen: int = 0
	var runs: Array[RunState] = [
		_passed_run(20), _bonus_run(21), _passed_run(22), _passed_run(23, _premium)
	]
	var chutes: Array[int] = [
		RewardMachine.Chute.NEW_ITEMS,
		RewardMachine.Chute.NEW_ITEMS,
		RewardMachine.Chute.UPGRADE,
		RewardMachine.Chute.UPGRADE,
	]
	for run_index: int in range(runs.size()):
		var run: RunState = runs[run_index]
		var view: RewardMachineView = await _open(run)
		seen += _audit(view, "wait")
		if run.phase == RunState.Phase.MACHINE_CHOOSE:
			view._armed = true
			var chute: int = MachineSteps.first_lit(run, chutes[run_index])
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


## The prize tickets of a NEW ITEMS draw holding its coupon and an item that arrived BIG or GOLDEN
## (v0.61, #108), and of an UPGRADE draw holding a perk's level-up and an item upgrade: every
## ticket inside the stage and apart; its chip (the item's tier, the level-up's "LV 2") inside its
## ticket and its art box, clear of the face's labels; the band says what the prize is; every
## label fits.
func test_new_items_and_upgrade_tickets_fit_with_their_marks() -> void:
	var on_stage: Rect2 = Rect2(Vector2.ZERO, ShiftStage.SIZE)
	var engine: UpgradeDefinition = load(COUPON_ENGINE)
	for chute: int in RewardMachine.CHUTES:
		var run: RunState = _passed_run(40, _with_coupon_engine)
		var view: RewardMachineView = await _open(run)
		assert_bool(run.machine.choose(run, chute)).is_true()
		var visit: MachineVisit = run.machine.current_visit()
		var kinds: Array = visit.prizes.map(func(p: MachinePrize) -> int: return p.kind)
		var marked: int = -1
		if chute == RewardMachine.Chute.NEW_ITEMS:
			assert_int(kinds.count(MachinePrize.Kind.COUPON)).is_equal(1)
			for index: int in range(visit.prizes.size()):
				var prize: MachinePrize = visit.prizes[index]
				if prize.kind == MachinePrize.Kind.PRODUCT and marked < 0:
					prize.card = load("res://data/cards/banana_golden.tres")
					marked = index
		else:
			# A level-up of the owned Coupon engine in the first perk's place.
			for index: int in range(visit.prizes.size()):
				if visit.prizes[index].kind == MachinePrize.Kind.REGISTER and marked < 0:
					visit.prizes[index].upgrade = engine.next_level
					marked = index
			assert_bool(kinds.has(MachinePrize.Kind.UPGRADE)).is_true()
		assert_int(marked).override_failure_message(str(kinds)).is_greater_equal(0)
		view.show_draw(run)
		view.show_at(view.plan.pick_at)
		await _frames(2)
		var shown: Array[Rect2] = []
		for ticket: PrizeTicket in view.tickets:
			var rect: Rect2 = ticket.get_global_rect()
			assert_bool(on_stage.encloses(rect)).override_failure_message(str(rect)).is_true()
			for other: Rect2 in shown:
				assert_bool(rect.intersects(other)).is_false()
			shown.append(rect)
			for label: Label in ticket.face_labels():
				if label.is_visible_in_tree():
					_assert_whole(label)
		var marked_ticket: PrizeTicket = null
		for ticket: PrizeTicket in view.tickets:
			if ticket.prize == visit.prizes[marked]:
				marked_ticket = ticket
		assert_object(marked_ticket).is_not_null()
		var chip: Rect2 = marked_ticket.chip_rect()
		assert_bool(chip.has_area()).is_true()
		var ticket_box: Rect2 = Rect2(Vector2.ZERO, PrizeTicket.SIZE)
		assert_bool(ticket_box.encloses(chip)).override_failure_message(str(chip)).is_true()
		(
			assert_bool(PrizeTicket.ART_RECT.encloses(chip))
			. override_failure_message(str(chip))
			. is_true()
		)
		for label: Label in marked_ticket.face_labels():
			assert_bool(label.get_rect().intersects(chip)).is_false()
		var band: String = marked_ticket.face_texts()[0]
		if chute == RewardMachine.Chute.NEW_ITEMS:
			assert_str(marked_ticket.art.chip_text()).is_equal("GOLDEN")
			assert_str(band).is_equal("NEW ITEM · €%d" % visit.prizes[marked].card.base)
		else:
			assert_str(marked_ticket.art.chip_text()).is_equal("LV 2")
			assert_str(band).is_equal("LEVEL UP · LV 2")
			# The perk's badge stays clear of the chip.
			var badge: Rect2 = PrizeArt.BADGE_RECT
			badge.position += PrizeTicket.ART_RECT.position
			assert_bool(badge.intersects(chip)).is_false()
		await _close(view)


## The dim veil follows the machine's silhouette: its pieces cover the marquee with every bulb,
## the cabinet and the plinth, and reach no further than they do, so the wall and the floor round
## the machine keep their colour while it is dim.
func test_the_dim_veil_follows_the_silhouette() -> void:
	var dim: MachineDim = auto_free(MachineDim.new())
	var pieces: Array[Rect2] = dim.piece_rects()
	assert_int(pieces.size()).is_equal(MachineDim.VEIL_RECTS.size())
	var head: Rect2 = Rect2(RewardMachineView.HEAD_POSITION, MachineHead.SIZE)
	var parts: Array[Rect2] = [
		head,
		Rect2(Vector2.ZERO, MachineCabinet.SIZE),
		MachineCabinet.PLINTH_RECT,
	]
	for index: int in range(MachineHead.bulb_count()):
		var at: Vector2 = RewardMachineView.HEAD_POSITION + MachineHead.bulb_point(index)
		parts.append(Rect2(at - Vector2(2, 2), Vector2(6, 6)))
	var outline: Rect2 = parts[0]
	for part: Rect2 in parts:
		outline = outline.merge(part)
		var covered: bool = false
		var rest: Rect2 = part
		for piece: Rect2 in pieces:
			if piece.encloses(rest):
				covered = true
		if not covered:  # The cabinet's top rows sit under the marquee's piece.
			covered = pieces[0].merge(pieces[1]).encloses(part)
		assert_bool(covered).override_failure_message(str(part)).is_true()
	for piece: Rect2 in pieces:
		assert_bool(outline.encloses(piece)).override_failure_message(str(piece)).is_true()
	# No piece reaches past its part's own width: the floor beside the plinth stays clear.
	assert_float(pieces[2].size.x).is_equal(MachineCabinet.PLINTH_RECT.size.x)
	assert_float(pieces[1].size.x).is_equal(MachineCabinet.SIZE.x)


## The marquee's title is letter-spaced bold Atkinson: its width is the bold font's plus the
## spacing between its glyphs, not the regular weight's (a wrapped FontVariation drops the weight).
func test_the_marquee_title_is_bold() -> void:
	var head: MachineHead = auto_free(MachineHead.new())
	var title: Label = head.title_labels()[0]
	var font: Font = title.get_theme_font("font")
	var font_size: int = title.get_theme_font_size("font_size")
	var bold: Font = ArtStyle.bold_font(MachineHead.BOLD_WEIGHT)
	for text: String in [MachineHead.TITLE, MachineHead.PREMIUM_TITLE]:
		var spaced: float = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
		var heavy: float = bold.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
		var gaps: float = MachineHead.TITLE_SPACING * (text.length() - 1)
		assert_float(spaced).override_failure_message(text).is_between(
			heavy + gaps - 0.5, heavy + gaps + MachineHead.TITLE_SPACING + 0.5
		)


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
## The odds plates (v0.53): the sealed tickets drawn through the sharp-pixel material; each
## plate on the 2 px grid, inside the window, under its pedestal and apart from its neighbours,
## holding its share (in the number font) and its word.
func _assert_odds_plates(stock: StockWindow) -> void:
	assert_object(stock.tickets_layer().material).is_same(ArtStyle.pixel_material())
	var labels: Array[Label] = stock.labels()
	var pedestal_foot: float = (
		StockWindow.TICKET_TOP + StockWindow.TICKET_SIZE.y + StockWindow.PEDESTAL_SIZE.y
	)
	for column: int in range(StockWindow.COLUMNS):
		for rarity: int in range(3):
			var plate: Rect2 = StockWindow.plate_rect(column, rarity)
			assert_float(fposmod(plate.position.x, MachineArt.PIXEL)).is_equal(0.0)
			assert_float(fposmod(plate.position.y, MachineArt.PIXEL)).is_equal(0.0)
			assert_bool(Rect2(Vector2.ZERO, StockWindow.SIZE).encloses(plate)).is_true()
			assert_float(plate.position.y).is_greater_equal(pedestal_foot)
			if rarity > 0:
				var left: Rect2 = StockWindow.plate_rect(column, rarity - 1)
				assert_bool(left.intersects(plate)).is_false()
			var odds: Label = labels[column * 3 + rarity]
			var word: Label = labels[StockWindow.COLUMNS * 3 + column * 3 + rarity]
			if not odds.visible:
				continue
			assert_object(odds.get_theme_font("font")).is_same(ArtStyle.number_font())
			for label: Label in [odds, word]:
				assert_bool(plate.encloses(Rect2(label.position, label.size))).is_true()


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
	var wanted: int = label.get_line_count()
	if label.max_lines_visible >= 0:
		wanted = mini(wanted, label.max_lines_visible)
	assert_int(label.get_visible_line_count()).override_failure_message(failure).is_equal(wanted)


## A ticket face's label shows all its lines, uncut. Its lines are pitched closer than the font's
## height, so _assert_fits's height check does not apply (machine_reveal_test checks the pitch).
func _assert_whole(label: Label) -> void:
	var failure: String = "%s: '%s' in %s" % [label.name, label.text, label.size]
	var lines: int = label.get_line_count()
	assert_int(lines).override_failure_message(failure).is_greater(0)
	if label.max_lines_visible >= 0:
		assert_int(lines).override_failure_message(failure).is_less_equal(label.max_lines_visible)
	assert_int(label.get_visible_line_count()).override_failure_message(failure).is_equal(lines)


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
func _open(run: RunState, rm: bool = false) -> RewardMachineView:
	var stage: Control = auto_free(Control.new())
	stage.size = ShiftStage.SIZE
	add_child(stage)
	var view: RewardMachineView = auto_free(RewardMachineView.new())
	view.reduced_motion = func() -> bool: return rm
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
## a NEW ITEMS prize); `full`: a full collection's stock; `full_cart`: the cart at its limit;
## `premium`: shift 1 is a premium shift, so its ticket took an UPGRADE prize and the bonus visit
## is PREMIUM too (v0.53).
static func _bonus_run(
	seed_value: int, full: bool = false, full_cart: bool = false, premium: bool = false
) -> RunState:
	var prepare: Callable = _with_full_cart if full_cart else Callable()
	if premium:
		prepare = _premium
	var run: RunState = _passed_run(seed_value, prepare, full)
	run.history[-1].inspection = load(SPOT_CHECK)
	MachineSteps.bonus_after_inspection(run)
	run.machine.begin_after_checkout(run)
	var first: int = RewardMachine.Chute.NEW_ITEMS
	if premium:
		first = RewardMachine.Chute.UPGRADE
	MachineSteps.choose(run, first)
	MachineSteps.take(run, 0)
	return run


## The run owns the Coupon engine (LV 1), so UPGRADE can draw its level-up.
static func _with_coupon_engine(run: RunState) -> void:
	run.upgrades.append(load(COUPON_ENGINE) as UpgradeDefinition)


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


## Shift 1's ticket visit PREMIUM: the machine turns PREMIUM (v0.50; a rarity boost, v0.61).
static func _premium(run: RunState) -> void:
	MachineSteps.premium_run(run, [1] as Array[int])


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
