extends GdUnitTestSuite
## The RECEIPT REWARDS machine's prize tickets (v0.50, mock-up premium_machine_v1.html; R1 "drop",
## M5): every rarity's reveal has signals besides its colour (the tab's text, the pips, its effect,
## a longer reveal and its own sounds), also under reduced motion (issue #77's test 5); a ticket
## flies out of the tray and lands face up in its row; the LEGENDARY sunburst grows, then shrinks
## to a small glow within about a second, with a short shake; the row, its tabs and KEEP ONE stay
## on the 1280x720 view without overlapping; each ticket shows its prize in full (the real sprite,
## the coupon slip, a LOYALTY punch card with its perk's badge, an upgrade's new tier or the SHELF
## plank) and every face's lines fit; the veil darkens the store for the row; after the pick the
## picked ticket lifts and goes, the others fall away (a bin: all of them). Parts are framed
## directly on a machine view with a hand-made plan (the clock is the root's, U0).

const BALANCE := "res://data/balance/balance.tres"
const STARTER := "res://data/decks/starter.tres"
const CARDS := "res://data/cards/"
const MILK := "res://data/cards/milk.tres"
const MILK_BIG := "res://data/cards/milk_big.tres"
const MILK_GOLDEN := "res://data/cards/milk_golden.tres"
const MACHINE := "res://data/balance/machine.tres"
const BIG_BASKET := "res://data/upgrades/big_basket.tres"
const PLUS_SLOT := "res://art/icons/plus_slot.png"
const RARITIES: Array[int] = [
	MachinePrize.Rarity.COMMON, MachinePrize.Rarity.RARE, MachinePrize.Rarity.LEGENDARY
]
const VIEW := Rect2(0, 0, 1280, 720)

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


## Issue #77's test 5: each rarity's landed ticket differs from the others in its tab's text, its
## pips, its effect (none, the RARE ring, the LEGENDARY sunburst), the reveal's length and its
## sounds; reduced motion keeps every one of them (the sunburst at its glow).
func test_every_rarity_has_a_non_colour_signal_on_its_reveal() -> void:
	for rm: bool in [false, true]:
		var view: RewardMachineView = _view(MachineVisit.Kind.TICKET, rm, RARITIES)
		var tickets: Array[PrizeTicket] = _tickets(view, RARITIES)
		var texts: Dictionary = {}
		var pips: Dictionary = {}
		var sounds: Dictionary = {}
		var lengths: Array[float] = []
		for index: int in range(tickets.size()):
			var ticket: PrizeTicket = tickets[index]
			ticket.frame(_revealed(view.plan, index))
			assert_bool(ticket.visible).is_true()
			assert_bool(ticket.tab.visible).is_true()
			texts[ticket.tab.text()] = true
			pips[ticket.pips_text()] = true
			sounds[" ".join(MachineSounds.reveal_sounds(ticket.prize.rarity))] = true
			lengths.append(view.plan.reveal_length[index])
		assert_array(texts.keys()).is_equal(["COMMON", "RARE!", "LEGENDARY!!"])
		assert_array(pips.keys()).is_equal(["●", "◆◆", "★★★"])
		assert_int(sounds.size()).is_equal(3)
		assert_float(lengths[1]).is_greater(lengths[0])
		assert_float(lengths[2]).is_greater(lengths[1])
		assert_float(tickets[0].burst_radius()).is_equal(0.0)
		assert_float(tickets[1].burst_radius()).is_equal(0.0)
		assert_float(tickets[2].burst_radius()).is_greater(0.0)
		for ticket: PrizeTicket in tickets:
			var tab_size: int = ticket.tab.label().get_theme_font_size("font_size")
			assert_int(tab_size).is_equal(RarityTab.FONT_SIZE)
			_assert_fits(ticket.tab.label())


## The LEGENDARY sunburst grows to its full radius, holds, then shrinks to a small glow (a share
## of it) within about a second of the landing; the stage shakes just after it lands (never under
## reduced motion), on the 2 px grid. Under reduced motion it shows at its glow at once.
func test_the_legendary_burst_shrinks_to_a_glow_within_a_second() -> void:
	var view: RewardMachineView = _view(MachineVisit.Kind.TICKET, false, RARITIES)
	var ticket: PrizeTicket = _tickets(view, RARITIES)[2]
	var plan: MachinePlan = view.plan
	var landed: float = plan.reveal_at[2]
	ticket.frame(landed - 0.01)
	assert_float(ticket.burst_radius()).is_equal(0.0)
	ticket.frame(landed + PrizeTicket.BURST_GROW + 0.01)
	assert_float(ticket.burst_radius()).is_equal(PrizeTicket.BURST_RADIUS)
	assert_float(PrizeTicket.BURST_SHRINK).is_less_equal(1.2)
	ticket.frame(landed + PrizeTicket.BURST_SHRINK + 0.01)
	var glow: float = MachineArt.snap(PrizeTicket.BURST_RADIUS * PrizeTicket.GLOW_SHARE)
	assert_float(ticket.burst_radius()).is_equal(glow)
	var shake: Vector2 = MachineLayers.legendary_shake(plan, landed + 0.01)
	assert_bool(shake != Vector2.ZERO).is_true()
	assert_float(fmod(absf(shake.x), 2.0)).is_equal(0.0)
	var settled: float = landed + MachineLayers.SHAKE_S + 0.01
	assert_vector(MachineLayers.legendary_shake(plan, settled)).is_equal(Vector2.ZERO)
	var still: RewardMachineView = _view(MachineVisit.Kind.TICKET, true, RARITIES)
	var held: PrizeTicket = _tickets(still, RARITIES)[2]
	held.frame(still.plan.reveal_at[2] + 0.01)
	assert_float(held.burst_radius()).is_equal(glow)
	var calm: Vector2 = MachineLayers.legendary_shake(still.plan, still.plan.reveal_at[2] + 0.01)
	assert_vector(calm).is_equal(Vector2.ZERO)


## A ticket is hidden until it leaves the tray, flies from LAUNCH at FLY_SCALE to its place in the
## row, lands there at its reveal (a 2 px bump for COMMON); reduced motion: no flight, it shows in
## place at its reveal.
func test_a_ticket_flies_out_of_the_tray_to_its_place() -> void:
	for rm: bool in [false, true]:
		var view: RewardMachineView = _view(MachineVisit.Kind.TICKET, rm, RARITIES)
		var tickets: Array[PrizeTicket] = _tickets(view, RARITIES)
		var plan: MachinePlan = view.plan
		for index: int in range(tickets.size()):
			var ticket: PrizeTicket = tickets[index]
			var rest: Vector2 = PrizeRow.card_rect(index, tickets.size()).position
			ticket.frame(plan.drop_at[index] - 0.01)
			assert_bool(ticket.visible).is_false()
			if not rm:
				ticket.frame(plan.drop_at[index] + plan.drop_length[index] * 0.3)
				assert_bool(ticket.visible).is_true()
				assert_float(ticket.scale.x).is_less(1.0)
			ticket.frame(_revealed(view.plan, index))
			assert_bool(ticket.visible).is_true()
			assert_vector(ticket.position).is_equal(rest)
			assert_vector(ticket.scale).is_equal(Vector2.ONE)
		if not rm:
			tickets[0].frame(plan.reveal_at[0] + PrizeTicket.BUMP_S / 2.0)
			var rest_0: Vector2 = PrizeRow.card_rect(0, tickets.size()).position
			assert_float(tickets[0].position.y).is_equal(rest_0.y + PrizeTicket.BUMP)


## The row (1 to 3 tickets) on the machine at MACHINE_RECT stays on the view, its tabs under the
## top bar, with no overlaps; each tab sits above its ticket on the view; KEEP ONE shows under the
## row once every ticket has landed, fitting, clear of the tickets.
func test_the_row_and_keep_one_stay_on_the_view() -> void:
	for count: int in [1, 2, 3]:
		var rects: Array[Rect2] = []
		for index: int in range(count):
			var rect: Rect2 = PrizeRow.card_rect(index, count)
			rect.position += ShiftStage.MACHINE_RECT.position
			assert_bool(VIEW.encloses(rect)).override_failure_message(str(rect)).is_true()
			var tab_top: float = rect.position.y + PrizeTicket.TAB_MIDDLE.y - RarityTab.HEIGHT / 2.0
			assert_float(tab_top).is_greater_equal(ShiftStage.PANEL_TOP)
			for other: Rect2 in rects:
				assert_bool(rect.intersects(other)).is_false()
			rects.append(rect)
	var view: RewardMachineView = _view(MachineVisit.Kind.TICKET, false, RARITIES)
	view.position = ShiftStage.MACHINE_RECT.position
	var tickets: Array[PrizeTicket] = _tickets(view, RARITIES)
	var plan: MachinePlan = view.plan
	var row: PrizeRow = view.prize_row
	var keep: Label = row.keep_label()
	row.frame(plan.reveal_at[2] - 0.01)
	assert_bool(keep.visible).is_false()
	var t: float = minf(plan.pick_at, plan.reveal_at[2] + PrizeRow.KEEP_AFTER)
	view._place()  # The card layer follows the machine (as each frame does).
	row.place_keep()
	row.frame(t)
	for ticket: PrizeTicket in tickets:
		ticket.frame(t)
	assert_bool(keep.visible).is_true()
	var keep_rect: Rect2 = keep.get_global_rect()
	assert_bool(VIEW.encloses(keep_rect)).is_true()
	_assert_fits(keep)
	for ticket: PrizeTicket in tickets:
		var rect: Rect2 = ticket.get_global_rect()
		assert_bool(keep_rect.intersects(rect)).is_false()
		var tab: Rect2 = ticket.tab.get_global_rect()
		assert_float(tab.position.y).is_less(rect.position.y)
		assert_bool(VIEW.encloses(tab)).is_true()


## The veil darkens the store as the first ticket leaves the tray, holds through the row, and
## lifts after the press.
func test_the_veil_frames_the_row() -> void:
	var view: RewardMachineView = _view(MachineVisit.Kind.TICKET, false, RARITIES)
	var plan: MachinePlan = view.plan
	var row: PrizeRow = view.prize_row
	row.frame(plan.drop_at[0] - PrizeRow.VEIL_LEAD - 0.01)
	assert_float(row.veil_alpha()).is_equal(0.0)
	row.frame(plan.pick_at)
	assert_float(row.veil_alpha()).is_equal_approx(PrizeRow.VEIL_ALPHA, 0.0001)
	plan.set_landing(MachinePlan.Landing.NEW_CARD, 1, MachinePlan.NO_VISIT)
	row.frame(plan.press + PrizeRow.VEIL_OUT + 0.01)
	assert_float(row.veil_alpha()).is_equal(0.0)
	assert_bool(row.keep_label().visible).is_false()


## Each prize in full: a product's band and its price, its name and long rule (#105) over its real
## sprite; a coupon's band; a LOYALTY prize's band, the perk's name and effect over a punch card
## and its perk badge (Big basket's "+1 slot" glyph); an upgrade's new tier on its chip; the SHELF
## upgrade's plain item on a gold plank, "SHELF +1".
func test_every_ticket_shows_its_prize_in_full() -> void:
	var view: RewardMachineView = _view(MachineVisit.Kind.TICKET, true, [0])
	var milk: CardDefinition = load(MILK)
	var product: PrizeTicket = _ticket(
		view, 0, MachinePrize.new(MachinePrize.Kind.PRODUCT, 0, milk), null, 1
	)
	assert_array(Array(product.face_texts())).is_equal(
		["NEW ITEM · €%d" % milk.base, milk.display_name, milk.rule_text]
	)
	assert_object(product.art.get_node("Sprite")).is_not_null()
	var coupon_card: CardDefinition = _balance.first_offer_pool[0]
	var coupon: PrizeTicket = _ticket(
		view, 0, MachinePrize.new(MachinePrize.Kind.COUPON, 1, coupon_card), null, 1
	)
	assert_str(coupon.face_texts()[0]).is_equal("COUPON")
	assert_object(coupon.art.get_node("Sprite")).is_not_null()
	var basket: UpgradeDefinition = load(BIG_BASKET)
	var stamp: MachinePrize = MachinePrize.new(MachinePrize.Kind.REGISTER, 0, null, basket)
	var loyalty: PrizeTicket = _ticket(view, 0, stamp, null, 1)
	assert_array(Array(loyalty.face_texts())).is_equal(
		["LOYALTY STAMP", basket.display_name, basket.effect_text]
	)
	assert_object(loyalty.art.perk_icon()).is_same(load(PLUS_SLOT))
	assert_object(loyalty.art.get_node("StampInitials")).is_not_null()
	var preview: MachinePreview = MachinePreview.new()
	preview.targets = [CardInstance.new(load(MILK_BIG), 3)]
	preview.to_cards = [load(MILK_GOLDEN)]
	preview.copies = 1
	var upgrade: PrizeTicket = _ticket(
		view, 0, MachinePrize.new(MachinePrize.Kind.UPGRADE, 0, milk), preview, 1
	)
	assert_array(Array(upgrade.face_texts())).is_equal(
		["UPGRADE", "Milk +1 step", "1 copy: BIG › GOLDEN"]
	)
	assert_str(upgrade.art.chip_text()).is_equal("GOLDEN")
	assert_object(upgrade.art.upgraded_card()).is_same(load(MILK_GOLDEN))
	assert_bool(upgrade.art.has_shelf()).is_false()
	var shelf_preview: MachinePreview = MachinePreview.new()
	shelf_preview.targets = [CardInstance.new(milk, 1), CardInstance.new(milk, 2)]
	shelf_preview.to_cards = [load(MILK_BIG), load(MILK_BIG)]
	shelf_preview.copies = 2
	var shelf: PrizeTicket = _ticket(
		view, 0, MachinePrize.new(MachinePrize.Kind.UPGRADE, 2, milk), shelf_preview, 1
	)
	assert_array(Array(shelf.face_texts())).is_equal(
		["UPGRADE", "Shelf upgrade", "SHELF ×2 · every Milk +1 step"]
	)
	assert_bool(shelf.art.has_shelf()).is_true()
	assert_str(shelf.art.chip_text()).is_equal("SHELF +1")


## Every face's lines fit the ticket (the band on one line, the name in Pixelify on one line when
## it fits NAME_WIDTH at NAME_DISPLAY_SIZE (#105), else bold in NAME_LINES, the long rule text
## whole in RULE_LINES, or RULE_LINES_ONE_NAME under a one-line name, at a RULE_SIZES size, under
## the name; all inside the ticket): every product and coupon the machine can draw, every
## LOYALTY perk and every UPGRADES prize of every chain and rarity.
func test_every_face_fits_the_ticket() -> void:
	var view: RewardMachineView = _view(MachineVisit.Kind.TICKET, true, [0])
	var prizes: Array[MachinePrize] = []
	var previews: Array[MachinePreview] = []
	var machine: MachineDefinition = load(MACHINE)
	var cards: Array[CardDefinition] = []
	cards.append_array(machine.rare_products)
	cards.append_array(machine.legendary_products)
	for card: CardDefinition in cards:
		prizes.append(MachinePrize.new(MachinePrize.Kind.PRODUCT, 1, card))
		previews.append(null)
	var coupons: Array[CardDefinition] = []
	coupons.append_array(machine.rare_coupons)
	coupons.append_array(machine.legendary_coupons)
	coupons.append_array(_balance.first_offer_pool)
	for card: CardDefinition in coupons:
		prizes.append(MachinePrize.new(MachinePrize.Kind.COUPON, 1, card))
		previews.append(null)
	for perk: UpgradeDefinition in _balance.upgrade_pool:
		prizes.append(MachinePrize.new(MachinePrize.Kind.REGISTER, 0, null, perk))
		previews.append(null)
	for chain: ItemUpgradeDefinition in machine.item_upgrades:
		for rarity: int in RARITIES:
			prizes.append(MachinePrize.new(MachinePrize.Kind.UPGRADE, rarity, chain.product))
			previews.append(_chain_preview(chain, rarity))
	assert_int(prizes.size()).is_greater(10)
	var bold: Font = ArtStyle.bold_font(PrizeTicket.BOLD_WEIGHT)
	var rule_font: Font = ArtStyle.bold_font(PrizeTicket.RULE_WEIGHT)
	var face: Rect2 = Rect2(Vector2.ZERO, PrizeTicket.SIZE)
	for index: int in range(prizes.size()):
		var ticket: PrizeTicket = _ticket(view, 0, prizes[index], previews[index], 1)
		# The name's row lays out its labels at the frame's end.
		await get_tree().process_frame
		var texts: PackedStringArray = ticket.face_texts()
		var what: String = " / ".join(texts)
		var band: int = PrizeTicket.text_lines(
			bold, texts[0], PrizeTicket.BAND_SIZE, PrizeTicket.BAND_RECT.size.x
		)
		assert_int(band).override_failure_message(what).is_equal(1)
		var display: bool = PrizeTicket.name_is_display(texts[1])
		assert_bool(ticket.name_control() is MixedLabel).override_failure_message(what).is_equal(
			display
		)
		var name_lines: int = (
			1
			if display
			else PrizeTicket.text_lines(
				bold, texts[1], PrizeTicket.NAME_SIZE, PrizeTicket.NAME_WIDTH
			)
		)
		assert_int(ticket.name_line_count()).override_failure_message(what).is_equal(name_lines)
		assert_int(name_lines).override_failure_message(what).is_less_equal(PrizeTicket.NAME_LINES)
		# #105: the long rule text, whole, at the first RULE_SIZES size that shows it.
		var fit: Vector2i = PrizeTicket.rule_fit(texts[2], name_lines)
		var room: int = (
			PrizeTicket.RULE_LINES_ONE_NAME if name_lines <= 1 else PrizeTicket.RULE_LINES
		)
		var rule_lines: int = PrizeTicket.text_lines(
			rule_font, texts[2], PrizeTicket.RULE_SIZES[fit.y], PrizeTicket.RULE_WIDTH
		)
		assert_int(rule_lines).override_failure_message(what).is_less_equal(room)
		assert_int(rule_lines).override_failure_message(what).is_equal(fit.x)
		# The face's own coordinates: the card layer holding the rule.
		var card: Control = ticket.rule_label().get_parent() as Control
		var to_face: Transform2D = card.get_global_transform().affine_inverse()
		for label: Label in ticket.face_labels():
			var rect: Rect2 = (
				to_face * label.get_global_transform() * Rect2(Vector2.ZERO, label.size)
			)
			assert_bool(face.encloses(rect)).override_failure_message(what).is_true()
		var rule: Label = ticket.rule_label()
		var name_box: Control = ticket.name_control()
		var name_rect: Rect2 = (
			to_face * name_box.get_global_transform() * Rect2(Vector2.ZERO, name_box.size)
		)
		assert_float(name_rect.end.y).override_failure_message(what).is_less_equal(
			(
				(to_face * rule.get_global_transform() * Rect2(Vector2.ZERO, rule.size)).position.y
				+ 1.0
			)
		)
		var shown: float = rule_lines * PrizeTicket.RULE_PITCHES[fit.y]
		assert_float(shown).override_failure_message(what).is_less_equal(rule.size.y + 0.01)
		# Godot shows a line only when the box holds the font's full height: every line of the
		# band, the name and the rule must be visible, not merely fit by the pitch.
		for label: Label in ticket.face_labels():
			var wanted: int = label.get_line_count()
			if label.max_lines_visible >= 0:
				wanted = mini(wanted, label.max_lines_visible)
			(
				assert_int(label.get_visible_line_count())
				. override_failure_message("%s: %s" % [label.name, what])
				. is_equal(wanted)
			)
			assert_int(wanted).override_failure_message(what).is_greater(0)
		ticket.free()


## A LOYALTY prize's perk glyph stays inside its badge, clear of the punch card above it (Big
## basket's 13x12 "+1" ticket included), with the card's 2 px gap at least.
func test_the_perk_glyph_stays_on_its_badge() -> void:
	var shown: int = 0
	for perk: UpgradeDefinition in _balance.upgrade_pool:
		var art: PrizeArt = auto_free(
			PrizeArt.new(MachinePrize.new(MachinePrize.Kind.REGISTER, 0, null, perk), null)
		)
		var glyph: Control = art.find_child("PerkIcon", false, false) as Control
		if glyph == null:
			continue
		shown += 1
		var rect: Rect2 = Rect2(glyph.position, glyph.size)
		var badge: Rect2 = PrizeArt.BADGE_RECT.grow(-2.0)
		assert_bool(badge.encloses(rect)).override_failure_message(String(perk.id)).is_true()
		var gap: float = rect.position.y - PrizeArt.PUNCH_RECT.end.y
		assert_float(gap).override_failure_message(String(perk.id)).is_greater_equal(2.0)
	assert_int(shown).is_greater(0)


## The art's chip (v0.61, #108): every perk level above 1 reads "LV n", and every BIG or GOLDEN
## item its tier; the chip lies inside the art, and a level's clear of the perk's badge.
func test_the_level_and_tier_chips_stay_inside_the_art() -> void:
	var art_box: Rect2 = Rect2(Vector2.ZERO, PrizeArt.SIZE)
	var levels: int = 0
	for perk: UpgradeDefinition in _balance.upgrade_pool:
		var level: UpgradeDefinition = perk.next_level
		while level != null:
			levels += 1
			var art: PrizeArt = auto_free(
				PrizeArt.new(MachinePrize.new(MachinePrize.Kind.REGISTER, 0, null, level), null)
			)
			var what: String = "%s: %s" % [level.id, art.chip_rect()]
			assert_str(art.chip_text()).is_equal("LV %d" % level.level_number())
			assert_bool(art_box.encloses(art.chip_rect())).override_failure_message(what).is_true()
			(
				assert_bool(art.chip_rect().intersects(PrizeArt.BADGE_RECT))
				. override_failure_message(what)
				. is_false()
			)
			level = level.next_level
	assert_int(levels).is_greater(0)
	var tiers: int = 0
	for file: String in DirAccess.get_files_at(CARDS):
		if not file.ends_with(".tres"):
			continue
		var card: CardDefinition = load(CARDS + file)
		if PriceSticker.tier_text(card).is_empty():
			continue
		tiers += 1
		var art: PrizeArt = auto_free(
			PrizeArt.new(MachinePrize.new(MachinePrize.Kind.PRODUCT, 0, card), null)
		)
		var what: String = "%s: %s" % [file, art.chip_rect()]
		assert_str(art.chip_text()).is_equal(PriceSticker.tier_text(card))
		assert_bool(art_box.encloses(art.chip_rect())).override_failure_message(what).is_true()
	assert_int(tiers).is_greater(0)


## Resumed at the pick wait (TICKET and BONUS): every ticket sits face up in its place with its
## tab. A bin drops them all; a pick lifts the picked one, which goes once it flies, while the
## others fall away.
func test_a_resume_at_the_pick_shows_the_row_at_rest() -> void:
	for kind: int in [MachineVisit.Kind.TICKET, MachineVisit.Kind.BONUS]:
		var view: RewardMachineView = _view(kind, false, RARITIES)
		view.plan = view.plan.resume_at(MachinePlan.WaitPoint.PICK)
		var plan: MachinePlan = view.plan
		var t: float = plan.start
		assert_bool(plan.resumed).is_true()
		assert_float(t).is_equal(plan.pick_at)
		var tickets: Array[PrizeTicket] = _tickets(view, RARITIES)
		for index: int in range(tickets.size()):
			tickets[index].frame(t)
			assert_bool(tickets[index].visible).is_true()
			assert_bool(tickets[index].tab.visible).is_true()
			var rest: Vector2 = PrizeRow.card_rect(index, tickets.size()).position
			assert_vector(tickets[index].position).is_equal(rest)
		plan.set_landing(MachinePlan.Landing.BIN, 1, MachinePlan.NO_VISIT)
		for ticket: PrizeTicket in tickets:
			ticket.frame(plan.press + PrizeTicket.FALL_S + 0.01)
			assert_bool(ticket.visible).is_false()
	# A pick: the run's last visit says which ticket was picked.
	var picking: RewardMachineView = _view(MachineVisit.Kind.TICKET, false, RARITIES)
	picking.run = _run_that_picked(1)
	var row: Array[PrizeTicket] = _tickets(picking, RARITIES)
	var landed: MachinePlan = picking.plan
	landed.set_landing(MachinePlan.Landing.NEW_CARD, 1, MachinePlan.NO_VISIT)
	var rest_1: Vector2 = PrizeRow.card_rect(1, 3).position
	row[1].frame(landed.fly_out - 0.001)
	assert_bool(row[1].visible).is_true()
	assert_float(row[1].position.y).is_less(rest_1.y)
	row[1].frame(landed.fly_out + 0.001)
	assert_bool(row[1].visible).is_false()
	row[0].frame(landed.press + PrizeTicket.FALL_S / 2.0)
	assert_float(row[0].modulate.a).is_less(1.0)
	row[0].frame(landed.press + PrizeTicket.FALL_S + 0.01)
	assert_bool(row[0].visible).is_false()


## The preview of an UPGRADES prize of `rarity` on `chain` (SHELF: three copies).
static func _chain_preview(chain: ItemUpgradeDefinition, rarity: int) -> MachinePreview:
	var preview: MachinePreview = MachinePreview.new()
	var copies: int = 3 if rarity == MachinePrize.Rarity.LEGENDARY else 1
	var to_card: CardDefinition = chain.golden if rarity == MachinePrize.Rarity.RARE else chain.big
	for copy: int in range(copies):
		preview.targets.append(CardInstance.new(chain.product, copy + 1))
		preview.to_cards.append(to_card)
	preview.copies = copies
	return preview


## A run whose current shift's last visit picked ticket `picked` (a hand-made record).
func _run_that_picked(picked: int) -> RunState:
	var run: RunState = RunState.new(1, _starter, _balance, RunStock.starting(_balance))
	var record: ShiftRecord = ShiftRecord.new(1, 10, 20)
	var visit: MachineVisit = MachineVisit.new()
	visit.picked = picked
	record.visits.append(visit)
	run.history.append(record)
	return run


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


## Product tickets of `rarities` in their row, hooked to `view`.
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
	ticket.rest = PrizeRow.card_rect(index, count).position
	ticket.launch = PrizeRow.LAUNCH
	ticket.setup(view)
	view.card_layer.add_child(ticket)
	return ticket


## The time ticket `index`'s reveal is over.
static func _revealed(plan: MachinePlan, index: int) -> float:
	return plan.reveal_at[index] + plan.reveal_length[index] + 0.01


## The label's text fits its box on one line.
func _assert_fits(label: Label) -> void:
	var font: Font = label.get_theme_font("font")
	var font_size: int = label.get_theme_font_size("font_size")
	var width: float = font.get_string_size(label.text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	assert_float(width).override_failure_message("%s: %s" % [label.name, label.text]).is_less_equal(
		label.size.x + 0.5
	)


static func _event_log() -> EventLogService:
	return (Engine.get_main_loop() as SceneTree).root.get_node("/root/EventLog")
