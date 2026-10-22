extends GdUnitTestSuite
## The RECEIPT REWARDS machine's stockroom and belt (#77, look F; build spec 4.2-4.3, U2): every
## rarity's reveal has signals besides its colour (the tab's text and tilt, the shape behind the
## ticket, the pips, a longer reveal and its own sounds), also under reduced motion (issue #77's
## test 5); a ticket arrives as its box, opens lid frame by lid frame and flips to its front; the
## order slip's "?" lines, ticks and PACKED stamp; the belt, the boxes riding, the gates (an unused
## cell's stays down), the hood's lamp and curtain and the YOUR ORDER plate follow the plan; reduced
## motion renders the continuous effects static; the rarity tabs stay inside the tray, above their
## tickets; an upgrade's hover card highlights the fields CardText says changed. Parts are framed
## directly on a machine view with a hand-made plan (the clock is the root's, U0).

const BALANCE := "res://data/balance/balance.tres"
const STARTER := "res://data/decks/starter.tres"
const MILK := "res://data/cards/milk.tres"
const MILK_BIG := "res://data/cards/milk_big.tres"
const MILK_GOLDEN := "res://data/cards/milk_golden.tres"
const MACHINE := "res://data/balance/machine.tres"
const RARITIES: Array[int] = [
	MachinePrize.Rarity.COMMON, MachinePrize.Rarity.RARE, MachinePrize.Rarity.LEGENDARY
]

var _folder: String = ""
var _balance: BalanceDefinition
var _starter: DeckDefinition


func before_test() -> void:
	_folder = "user://test_machine_reveal_%d" % Time.get_ticks_usec()
	_event_log().use_folder(_folder)
	ProjectSettings.set_setting(SaveService.FOLDER_SETTING, _folder)
	_balance = load(BALANCE)
	_starter = load(STARTER)


func after_test() -> void:
	ProjectSettings.set_setting(SaveService.FOLDER_SETTING, null)
	if DirAccess.dir_exists_absolute(_folder):
		for file_name: String in DirAccess.get_files_at(_folder):
			DirAccess.remove_absolute(_folder.path_join(file_name))
		DirAccess.remove_absolute(_folder)


## Issue #77's test 5: each rarity's revealed ticket differs from the others in its tab's text,
## its tilt, the shape behind it (none, the burst, the sunburst with sparkles), its pips, the
## reveal's length and its sounds; reduced motion keeps every one of them.
func test_every_rarity_has_a_non_colour_signal_on_its_reveal() -> void:
	for rm: bool in [false, true]:
		var view: RewardMachineView = _view(MachineVisit.Kind.TICKET, rm, RARITIES)
		var tickets: Array[PrizeTicket] = _tickets(view, RARITIES)
		var texts: Dictionary = {}
		var tilts: Dictionary = {}
		var shapes: Dictionary = {}
		var pips: Dictionary = {}
		var sounds: Dictionary = {}
		var lengths: Array[float] = []
		for index: int in range(tickets.size()):
			var ticket: PrizeTicket = tickets[index]
			ticket.frame(_revealed(view.plan, index))
			assert_bool(ticket.tab.visible).is_true()
			texts[ticket.tab.text()] = true
			tilts[ticket.tab.tilt()] = true
			shapes[ticket.shape_name()] = true
			pips[ticket.pips_text()] = true
			# The sounds the machine really plays at this reveal (U3's MachineSounds).
			sounds[" ".join(MachineSounds.reveal_sounds(ticket.prize.rarity))] = true
			lengths.append(view.plan.reveal_length[index])
			assert_bool(ticket.shows_box()).is_false()
			assert_str(ticket.pips_text()).is_not_empty()
			assert_array(MachineSounds.reveal_sounds(ticket.prize.rarity)).is_not_empty()
		assert_array(texts.keys()).is_equal(["COMMON", "RARE!", "LEGENDARY!!"])
		assert_int(tilts.size()).is_equal(3)
		assert_array(shapes.keys()).is_equal(["", "Burst", "Sunburst"])
		assert_array(pips.keys()).is_equal(["●", "◆◆", "★★★"])
		assert_int(sounds.size()).is_equal(3)
		assert_float(lengths[1]).is_greater(lengths[0])
		assert_float(lengths[2]).is_greater(lengths[1])
		# The shape nodes: none for COMMON, the burst for RARE, the sunburst and six sparkles
		# for LEGENDARY, each showing once revealed.
		assert_object(tickets[0].shape()).is_null()
		assert_object(tickets[1].shape()).is_instanceof(TextureRect)
		assert_bool(tickets[1].shape().visible).is_true()
		assert_object(tickets[2].shape()).is_instanceof(Sunburst)
		assert_bool(tickets[2].shape().visible).is_true()
		assert_bool((tickets[2].shape() as Sunburst).is_met()).is_true()
		assert_int(tickets[0].sparkles().size()).is_equal(0)
		assert_int(tickets[1].sparkles().size()).is_equal(0)
		assert_int(tickets[2].sparkles().size()).is_equal(6)
		# The tabs' fonts: COMMON bold Atkinson 10, the others Pixelify 24.
		assert_int(tickets[0].tab.font_size()).is_equal(10)
		assert_int(tickets[1].tab.font_size()).is_equal(24)
		assert_int(tickets[2].tab.font_size()).is_equal(24)


## A ticket shows nothing until its box meets its gate, then the box; its reveal splits the tape,
## lifts the flaps half, opens them, then the card shows its front with its pips and tab.
func test_a_ticket_arrives_as_its_box_and_opens_lid_by_lid() -> void:
	var view: RewardMachineView = _view(MachineVisit.Kind.TICKET, false, RARITIES)
	var tickets: Array[PrizeTicket] = _tickets(view, RARITIES)
	var plan: MachinePlan = view.plan
	var rare: PrizeTicket = tickets[1]
	rare.frame(plan.run_to[1] - 0.05)
	assert_bool(rare.visible).is_false()
	rare.frame(plan.run_to[1] + 0.01)
	assert_bool(rare.visible).is_true()
	assert_bool(rare.shows_box()).is_true()
	assert_int(rare.lid_frame()).is_equal(-1)
	assert_bool(rare.tab.visible).is_false()
	assert_str(rare.pips_text()).is_empty()
	var frames: Array[int] = []
	var t: float = plan.reveal_at[1]
	while t < plan.reveal_at[1] + plan.reveal_length[1]:
		rare.frame(t)
		if rare.shows_box() and (frames.is_empty() or frames[-1] != rare.lid_frame()):
			frames.append(rare.lid_frame())
		t += 0.01
	assert_array(frames).is_equal([0, 1, 2])
	rare.frame(_revealed(plan, 1))
	assert_bool(rare.shows_box()).is_false()
	assert_float(rare.open_amount()).is_equal(1.0)
	assert_str(rare.rarity_texts()[0]).is_equal("RARE!")
	assert_str(rare.pips_text()).is_equal("◆◆")


## The order slip: "?" lines until a chute is chosen, one line per prize after (1 to 3), each
## ticking at its bay pick, PACKED once the last box is picked; it slides down with the feed.
func test_the_order_slip_ticks_its_lines_and_packs() -> void:
	for count: int in [1, 2, 3]:
		var rarities: Array[int] = []
		for index: int in range(count):
			rarities.append(MachinePrize.Rarity.COMMON)
		var view: RewardMachineView = _view(MachineVisit.Kind.TICKET, false, [])
		var slip: OrderSlip = view.slip
		slip.show_order("ORDER #107", "SPEND €40 ✓", 3, -1, false)
		# The check line's ✓ is in no body font: the display's marked font draws it.
		assert_object(slip.check_font()).is_same(MachineDisplay.marked_font(OrderSlip.BOLD_WEIGHT))
		slip.frame(0.0)
		assert_float(slip.slide_offset()).is_greater(0.0)
		slip.frame(view.plan.choose_at)
		assert_float(slip.slide_offset()).is_equal(0.0)
		assert_array(slip.texts()).is_equal(
			["ORDER #107", "SPEND €40 ✓", "1 · ?", "2 · ?", "3 · ?"]
		)
		view.plan.set_draw(rarities)
		slip.show_order("ORDER #117", "SPEND €40 ✓", count, MachinePrize.Kind.PRODUCT, true)
		var plan: MachinePlan = view.plan
		assert_int(slip.texts().size()).is_equal(2 + count)
		assert_str(slip.texts()[2]).is_equal("1 · NEW ITEM")
		slip.frame(plan.draw)
		assert_bool(slip.is_ticked(0)).is_false()
		assert_bool(slip.is_packed()).is_false()
		for index: int in range(count):
			slip.frame(plan.picks[index] + 0.2)
			assert_bool(slip.is_ticked(index)).is_true()
		slip.frame(plan.packed + 0.01)
		assert_bool(slip.is_packed()).is_true()


## The belt scrolls while the boxes ride left from the hatch to their cells; each cell's gate
## goes up once the box before has passed (an unused cell's gate stays down in a short draw);
## the hood's lamp is lit while the belt moves and its curtain swings as a box comes through; the
## YOUR ORDER plate hides during the reveals; a bay's lamp lights at its pick.
func test_the_belt_carries_the_boxes_to_their_gates() -> void:
	for count: int in [1, 2, 3]:
		var rarities: Array[int] = []
		for index: int in range(count):
			rarities.append(MachinePrize.Rarity.COMMON)
		var view: RewardMachineView = _view(MachineVisit.Kind.TICKET, false, rarities)
		var plan: MachinePlan = view.plan
		var last: int = count - 1
		var moving: float = (plan.run_from[0] + plan.run_to[last]) / 2.0
		view.belt.frame(plan.draw)
		var first_offset: int = view.belt.scroll_offset()
		view.belt.frame(moving)
		assert_int(view.belt.scroll_offset()).is_not_equal(first_offset)
		view.hood.frame(moving)
		assert_int(view.hood.lamp()).is_equal(RestockHood.Lamp.ON)
		view.hood.frame(plan.run_from[0] - 0.1)
		assert_bool(view.hood.swinging()).is_true()
		view.hood.frame(plan.choose_at)
		assert_int(view.hood.lamp()).is_equal(RestockHood.Lamp.OFF)
		# The first box rides left, from the hatch to its cell.
		var early: Array[Vector2] = view.box_lane.riding(plan.run_from[0] + 0.1)
		var later: Array[Vector2] = view.box_lane.riding(plan.run_from[0] + 0.3)
		assert_float(early[0].x).is_equal(0.0)
		assert_float(later[0].y).is_less(early[0].y)
		assert_array(view.box_lane.riding(plan.run_to[last] + 0.01)).is_empty()
		# Gates: up for every used cell once its boxes have passed, down for unused cells.
		var at_rest: float = plan.run_to[last] + 0.01
		var used: Dictionary = {}
		for index: int in range(count):
			used[MachinePlan.cell_of(index, count)] = true
		for cell: int in range(MachinePlan.MAX_PRIZES):
			assert_bool(view.box_lane.gate_up(cell, at_rest)).is_equal(used.has(cell))
		# The plate hides during the reveals; a bay lamp lights at its pick.
		view.order_plate.frame(plan.reveal_at[0] + 0.01)
		assert_bool(view.order_plate.visible).is_false()
		view.order_plate.frame(moving)
		assert_bool(view.order_plate.visible).is_true()
		assert_bool(view.order_plate.lamps().has(OrderPlate.Lamp.ON)).is_true()
		var cell_0: int = MachinePlan.cell_of(0, count)
		assert_bool(view.stockroom.lamp_lit(cell_0, plan.picks[0] - 0.5)).is_false()
		assert_bool(view.stockroom.lamp_lit(cell_0, plan.picks[0] + 0.01)).is_true()
		var rolling: float = (plan.picks[0] + plan.fall + plan.exits[0]) / 2.0
		assert_bool(view.stockroom.rolling(rolling)).is_true()
	# The mini boxes' textures are built at 2x: a box at rest draws the whole texture, and a
	# refill cut 4 art px from the top skips 8 texture px.
	var box_texture: Texture2D = StockroomWindow.MINI
	assert_that(box_texture.get_size()).is_equal(StockroomWindow.MINI_SIZE * 2.0)
	var whole: Rect2 = StockroomWindow.mini_region(box_texture, Vector2(10, 8), -INF)
	assert_that(whole).is_equal(Rect2(Vector2.ZERO, box_texture.get_size()))
	var cut: Rect2 = StockroomWindow.mini_region(box_texture, Vector2(10, 8), 12.0, 28.0)
	assert_that(cut).is_equal(Rect2(0, 8, 36, 52))


## Reduced motion: the boxes appear at their gates (no ride, the belt still), the tickets open
## without a flip or a shake, the sunburst stands still, the sparkles hold one frame, the hood's
## lamp glows steady gold on a LEGENDARY (the YOUR ORDER plate is hidden then, under the tabs),
## and the curtain never swings.
func test_reduced_motion_renders_the_effects_static() -> void:
	var view: RewardMachineView = _view(MachineVisit.Kind.TICKET, true, RARITIES)
	var tickets: Array[PrizeTicket] = _tickets(view, RARITIES)
	var plan: MachinePlan = view.plan
	assert_float(plan.belt_travel(plan.run_to[2])).is_equal(0.0)
	assert_array(view.box_lane.riding(plan.run_to[0] - 0.01)).is_empty()
	var legendary: PrizeTicket = tickets[2]
	var t: float = plan.reveal_at[2]
	while t < plan.reveal_at[2] + plan.reveal_length[2]:
		legendary.frame(t)
		var card: Control = legendary.get_node("Card") as Control
		assert_float(card.position.x).is_equal(0.0)
		assert_float(card.scale.x).is_equal(1.0)
		t += 0.02
	legendary.frame(_revealed(plan, 2))
	var sun: Sunburst = legendary.shape() as Sunburst
	assert_float(sun.turn_speed()).is_equal(0.0)
	for spark: TextureRect in legendary.sparkles():
		assert_bool(spark.visible).is_true()
	var height: float = plan.reveal_at[2] + plan.reveal_length[2] * 0.5
	for step: int in range(8):
		view.hood.frame(height + step * 0.01)
		assert_int(view.hood.lamp()).is_equal(RestockHood.Lamp.GOLD)
		assert_bool(view.hood.swinging()).is_false()
		view.order_plate.frame(height + step * 0.01)
		assert_bool(view.order_plate.visible).is_false()
	view.hood.frame(plan.draw_end)
	assert_bool(view.hood.swinging()).is_false()
	# The bays' boxes never ride the runway: picked, they are gone.
	assert_bool(view.stockroom.rolling(plan.picks[0] + 0.01)).is_false()
	assert_object(view.stockroom.box_at(0, plan.picks[0] + 0.01)).is_equal(Vector2.INF)


## On the real machine: each ticket sits in its tray cell, its rarity tab above it and inside
## the tray's x range (clear of the RESTOCK hood), also for the right cell's LEGENDARY; the tabs'
## tilted shapes never overlap each other or their tickets (look F's tabs sit side by side), in
## full (C R L, R R L, a 2-prize L L) and crowded draws (3 prizes with 2 or more LEGENDARY, C L L
## and L L L, go compact: their full-size tabs measure wider than the tray), and each tab's text
## fits its plate.
func test_the_rarity_tabs_stay_in_the_tray_above_their_tickets() -> void:
	var legend: int = MachinePrize.Rarity.LEGENDARY
	var rare: int = MachinePrize.Rarity.RARE
	var common: int = MachinePrize.Rarity.COMMON
	var draws: Array = [
		[common, rare, legend],
		[rare, rare, legend],
		[legend, legend, legend],
		[common, legend, legend],
		[legend, legend],
		[legend],
	]
	for draw: Array in draws:
		var typed: Array[int] = []
		typed.assign(draw)
		var view: RewardMachineView = _view(MachineVisit.Kind.TICKET, false, typed)
		view.visible = true
		var tickets: Array[PrizeTicket] = _tickets(view, typed)
		await get_tree().process_frame
		var shapes: Array[PackedVector2Array] = []
		for index: int in range(tickets.size()):
			var ticket: PrizeTicket = tickets[index]
			ticket.frame(_revealed(view.plan, index))
			var tab: Rect2 = Rect2(ticket.position + ticket.tab.rest, ticket.tab.size)
			assert_float(tab.position.x).is_greater_equal(PrizeTicket.TRAY_LEFT)
			assert_float(tab.end.x).is_less_equal(PrizeTicket.TRAY_RIGHT)
			assert_float(tab.end.x).is_less_equal(RewardMachineView.HOOD_POSITION.x)
			assert_float(tab.end.y).is_less_equal(ticket.position.y)
			var label: Label = ticket.tab.get_node("Text") as Label
			assert_bool(Rect2(Vector2.ZERO, ticket.tab.size).has_point(label.get_minimum_size()))
			var shape: PackedVector2Array = _tab_shape(ticket)
			for corner: Vector2 in shape:
				assert_float(corner.x).is_greater_equal(PrizeTicket.TRAY_LEFT)
				assert_float(corner.x).is_less_equal(RewardMachineView.HOOD_POSITION.x)
				assert_float(corner.y).is_less_equal(ticket.position.y)
			for other: PackedVector2Array in shapes:
				assert_array(Geometry2D.intersect_polygons(shape, other)).is_empty()
			shapes.append(shape)
			var cell: Rect2 = Rect2(ticket.position, PrizeTicket.SIZE)
			assert_float(cell.position.x).is_equal(
				MachinePlan.CELL_X[MachinePlan.cell_of(index, tickets.size())]
			)
			assert_bool(Rect2(Vector2.ZERO, RewardMachineView.SIZE).encloses(cell)).is_true()
		var compact: bool = draw.size() == 3 and draw.count(legend) >= 2
		for ticket: PrizeTicket in tickets:
			assert_bool(ticket.tab.compact).is_equal(compact)


## A ticket's tab as drawn (tilted about its centre), in machine px.
static func _tab_shape(ticket: PrizeTicket) -> PackedVector2Array:
	var turn: Transform2D = ticket.get_transform() * ticket.tab.get_transform()
	var size: Vector2 = ticket.tab.size
	return PackedVector2Array(
		[turn * Vector2.ZERO, turn * Vector2(size.x, 0), turn * size, turn * Vector2(0, size.y)]
	)


## An UPGRADES ticket shows the item at its new tier with its tag and what the pick does; its
## hover card (only once open) highlights the values CardText says changed from the copy now.
func test_an_upgrade_ticket_highlights_what_changes() -> void:
	var view: RewardMachineView = _view(MachineVisit.Kind.TICKET, false, [0])
	var big: CardDefinition = load(MILK_BIG)
	var golden: CardDefinition = load(MILK_GOLDEN)
	var preview: MachinePreview = MachinePreview.new()
	preview.targets = [CardInstance.new(big, 3)]
	preview.to_cards = [golden]
	preview.copies = 1
	var prize: MachinePrize = MachinePrize.new(
		MachinePrize.Kind.UPGRADE, MachinePrize.Rarity.COMMON, load(MILK)
	)
	var ticket: PrizeTicket = _ticket(view, 0, prize, preview, 1)
	assert_str(ticket.note_text()).is_equal("1 copy: BIG › GOLDEN")
	# Look F's name line says which item the pick improves; the tag shows its new tier.
	assert_str(ticket.note_name()).is_equal("Milk +1 step")
	assert_str(ticket.tier_tag_text()).is_equal("GOLDEN")
	assert_object(ticket.item.card.definition).is_same(golden)
	assert_object(ticket.get_node("Card/Face/TierTag")).is_not_null()
	assert_object(ticket.get_node("Card/Face/UpArrow")).is_not_null()
	var changed: PackedStringArray = CardText.changed_fields(big, golden)
	assert_array(changed).is_not_empty()
	assert_array(ticket.highlighted_fields()).is_equal(changed)
	ticket.frame(view.plan.reveal_at[0])
	ticket.show_hover(true)
	assert_bool(ticket.hover_card().visible).is_false()
	ticket.frame(_revealed(view.plan, 0))
	assert_bool(ticket.hover_card().visible).is_true()
	assert_bool(ticket.hover_texts().has("1 copy: BIG › GOLDEN")).is_true()
	var rich: RichTextLabel = ticket.hover_card().find_child("Changed", true, false)
	assert_str(rich.text).contains("[bgcolor=")
	ticket.show_hover(false)
	assert_bool(ticket.hover_card().visible).is_false()
	# A SHELF upgrade (LEGENDARY) names itself and tags "SHELF ×n", as look F.
	var shelf_preview: MachinePreview = MachinePreview.new()
	shelf_preview.targets = [CardInstance.new(load(MILK), 1), CardInstance.new(load(MILK), 2)]
	shelf_preview.to_cards = [big, big]
	shelf_preview.copies = 2
	var shelf: MachinePrize = MachinePrize.new(
		MachinePrize.Kind.UPGRADE, MachinePrize.Rarity.LEGENDARY, load(MILK)
	)
	var shelf_ticket: PrizeTicket = _ticket(view, 0, shelf, shelf_preview, 1)
	assert_str(shelf_ticket.note_name()).is_equal("Shelf upgrade")
	assert_str(shelf_ticket.tier_tag_text()).is_equal("SHELF ×2")
	assert_str(shelf_ticket.note_text()).is_equal("SHELF ×2 · every Milk +1 step")


## Resumed at the pick wait (TICKET and STAMP DAY, spec 4.3's resume frames): the prizes sit in
## their cells already open with their tabs, the slip's lines are ticked and PACKED, no box rides
## the belt and the used bays are empty; the gates are up until the landing's punch. A bin (a
## ticket's draw) then drops every ticket and shows the YOUR ORDER plate again after it.
func test_a_resume_at_the_pick_shows_the_draw_at_rest() -> void:
	for kind: int in [MachineVisit.Kind.TICKET, MachineVisit.Kind.STAMP_DAY]:
		var view: RewardMachineView = _view(kind, false, RARITIES)
		view.plan = view.plan.resume_at(MachinePlan.WaitPoint.PICK)
		var plan: MachinePlan = view.plan
		var t: float = plan.start
		assert_bool(plan.resumed).is_true()
		assert_float(t).is_equal(plan.pick_at)
		var tickets: Array[PrizeTicket] = _tickets(view, RARITIES)
		view.slip.show_order("ORDER #117", "SPEND €40 ✓", 3, MachinePrize.Kind.PRODUCT, true)
		view.slip.frame(t)
		view.order_plate.frame(t)
		for index: int in range(tickets.size()):
			tickets[index].frame(t)
			assert_bool(tickets[index].visible).is_true()
			assert_bool(tickets[index].shows_box()).is_false()
			assert_bool(tickets[index].tab.visible).is_true()
			assert_bool(view.slip.is_ticked(index)).is_true()
		assert_bool(view.slip.is_packed()).is_true()
		assert_float(view.slip.slide_offset()).is_equal(0.0)
		assert_array(view.box_lane.riding(t)).is_empty()
		assert_bool(view.order_plate.visible).is_false()
		for cell: int in range(MachinePlan.MAX_PRIZES):
			assert_object(view.stockroom.box_at(cell, t)).is_equal(Vector2.INF)
			assert_bool(view.box_lane.gate_up(cell, t)).is_true()
		if kind == MachineVisit.Kind.STAMP_DAY:
			continue  # A stamp can't be binned.
		plan.set_landing(MachinePlan.Landing.BIN, 1, MachinePlan.NO_VISIT)
		var dropped: float = plan.press + PrizeTicket.BIN_S + 0.01
		for ticket: PrizeTicket in tickets:
			ticket.frame(dropped)
			assert_float(ticket.modulate.a).is_equal(0.0)
		view.order_plate.frame(plan.press + OrderPlate.HIDE_TAIL_S + 0.01)
		assert_bool(view.order_plate.visible).is_true()


## Every UPGRADES ticket's note fits its sticker for every chained product (v0.48's long names
## among them): the name line on one line at one of NOTE_SIZES, else folded to two lines, and the
## text below with every wrapped line shown, both inside NOTE_RECT.
func test_every_upgrade_note_fits_the_ticket() -> void:
	var view: RewardMachineView = _view(MachineVisit.Kind.TICKET, true, [0])
	var machine: MachineDefinition = load(MACHINE)
	assert_array(machine.item_upgrades).is_not_empty()
	var folded: int = 0
	for chain: ItemUpgradeDefinition in machine.item_upgrades:
		for rarity: int in RARITIES:
			var preview: MachinePreview = MachinePreview.new()
			var copies: int = 3 if rarity == MachinePrize.Rarity.LEGENDARY else 1
			var to_card: CardDefinition = chain.big
			if rarity == MachinePrize.Rarity.RARE:
				to_card = chain.golden
			for copy: int in range(copies):
				preview.targets.append(CardInstance.new(chain.product, copy + 1))
				preview.to_cards.append(to_card)
			preview.copies = copies
			var prize: MachinePrize = MachinePrize.new(
				MachinePrize.Kind.UPGRADE, rarity, chain.product
			)
			var ticket: PrizeTicket = _ticket(view, 0, prize, preview, 1)
			var what: String = "%s %d" % [chain.product.id, rarity]
			var name_label: Label = ticket.get_node("Card/Face/NoteName")
			var note: Label = ticket.get_node("Card/Face/Note")
			assert_str(name_label.text).is_equal(PrizeTicket.upgrade_name(prize))
			var name_size: int = name_label.get_theme_font_size("font_size")
			var folded_before: int = folded
			if name_label.autowrap_mode == TextServer.AUTOWRAP_OFF:
				var width: float = PrizeTicket.line_width(name_label, name_label.text, name_size)
				assert_float(width).override_failure_message(what).is_less_equal(name_label.size.x)
			else:
				folded += 1
			var name_height: float = PrizeTicket.text_height(
				name_label, name_label.text, name_size, name_label.size.x
			)
			assert_float(name_height).override_failure_message(what).is_less_equal(
				name_label.size.y + 0.01
			)
			var note_size: int = note.get_theme_font_size("font_size")
			var note_height: float = PrizeTicket.text_height(
				note, note.text, note_size, note.size.x
			)
			assert_float(note_height).override_failure_message(what).is_less_equal(note.size.y)
			# The name's row (NAME_HEIGHT, or its folded lines), not its label, which is at least
			# its font's line tall.
			var name_row: float = (
				PrizeTicket.NAME_HEIGHT if folded_before == folded else name_height
			)
			assert_float(note.position.y).is_greater_equal(name_label.position.y + name_row)
			assert_float(note.position.y + note.size.y).is_less_equal(PrizeTicket.NOTE_RECT.end.y)
			assert_float(name_label.position.x + name_label.size.x).is_less_equal(
				PrizeTicket.NOTE_RECT.end.x
			)
			ticket.free()
	prints("v0.48 upgrade name lines folded to two lines:", folded)


## A machine view (not shown: its own clock stays still) with a plan of `kind` and, unless empty,
## a draw of `rarities`.
func _view(kind: int, rm: bool, rarities: Array) -> RewardMachineView:
	var view: RewardMachineView = auto_free(RewardMachineView.new())
	add_child(view)
	view.plan = MachinePlan.new(view.tuning, kind, rm)
	if not rarities.is_empty():
		var typed: Array[int] = []
		typed.assign(rarities)
		view.plan.set_draw(typed)
	return view


## Product tickets of `rarities` in their cells, hooked to `view`.
func _tickets(view: RewardMachineView, rarities: Array[int]) -> Array[PrizeTicket]:
	var tickets: Array[PrizeTicket] = []
	for index: int in range(rarities.size()):
		var prize: MachinePrize = MachinePrize.new(
			MachinePrize.Kind.PRODUCT, rarities[index], load(MILK)
		)
		tickets.append(_ticket(view, index, prize, null, rarities.size()))
	return tickets


func _ticket(
	view: RewardMachineView, index: int, prize: MachinePrize, preview: MachinePreview, count: int
) -> PrizeTicket:
	var run: RunState = RunState.new(1, _starter, _balance, RunStock.starting(_balance))
	var ticket: PrizeTicket = PrizeTicket.new(index, prize, preview, run)
	ticket.position = Vector2(RewardMachineView.cell_x(index, count), RewardMachineView.CELL_Y)
	ticket.setup(view)
	view.add_child(ticket)
	return ticket


## The time ticket `index`'s reveal is over.
static func _revealed(plan: MachinePlan, index: int) -> float:
	return plan.reveal_at[index] + plan.reveal_length[index] + 0.01


static func _event_log() -> EventLogService:
	return (Engine.get_main_loop() as SceneTree).root.get_node("/root/EventLog")
