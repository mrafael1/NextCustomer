extends GdUnitTestSuite
## The RECEIPT REWARDS machine's prize tickets (v0.50, mock-up premium_machine_v1.html; R1 "drop",
## M5): every rarity's reveal has signals besides its colour (the tab's text, the pips, its effect,
## a longer reveal and its own sounds), also under reduced motion (issue #77's test 5); a ticket
## flies out of the tray and lands face up in its row; the LEGENDARY sunburst grows, then shrinks
## to a small glow within about a second, with a short shake; the row, its tabs and KEEP ONE stay
## on the 1280x720 view without overlapping; each ticket shows its prize in full (the real sprite,
## the coupon slip, a LOYALTY punch card with its perk in its first stamp slot, an upgrade's new
## tier or the SHELF plank) and every face's lines fit (V3, v0.98: the name in the band, the rule
## under it); a ticket wears its family chips and its rarity sheen (CardFoil's sweep), and a
## LOYALTY ticket its S1 win sticker; after the pick the picked ticket lifts and goes, the others
## fall away (a bin: all of them). Parts are framed directly on a machine view with a hand-made
## plan (the clock is the root's, U0).

const BALANCE := "res://data/balance/balance.tres"
const STARTER := "res://data/decks/starter.tres"
const CARDS := "res://data/cards/"
const MILK := "res://data/cards/milk.tres"
const MILK_BIG := "res://data/cards/milk_big.tres"
const MILK_GOLDEN := "res://data/cards/milk_golden.tres"
const MACHINE := "res://data/balance/machine.tres"
const BIG_BASKET := "res://data/upgrades/big_basket.tres"
const DAIRY_REGULARS := "res://data/upgrades/dairy_regulars.tres"
const BREAD := "res://data/cards/bread.tres"
const PLUS_SLOT := "res://art/icons/perk_big_basket.png"
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
## pips, its effect (none, the RARE rim, the LEGENDARY sunburst), the reveal's length and its
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
			# The relook (v0.98): the tab's word in hard pixel capitals, inside its box.
			var tab_line: MachineLine = ticket.tab.word_line()
			assert_str(tab_line.text()).is_equal(ticket.tab.text())
			(
				assert_bool(Rect2(Vector2.ZERO, ticket.tab.size).encloses(tab_line.get_rect()))
				. is_true()
			)


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
	var keep: MachineLine = row.keep_label()
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
	# The relook (v0.98): KEEP ONE stands on the tray's push bar, which lights for it.
	var bar: Rect2 = MachineTray.BAR_RECT
	bar.position += view.tray.get_global_rect().position
	assert_bool(bar.encloses(keep_rect)).override_failure_message(str(keep_rect)).is_true()
	view.tray.frame(t)
	assert_bool(view.tray.keeps()).is_true()
	assert_object(view.tray.bar_line()).is_null()
	for ticket: PrizeTicket in tickets:
		var rect: Rect2 = ticket.get_global_rect()
		assert_bool(keep_rect.intersects(rect)).is_false()
		var tab: Rect2 = ticket.tab.get_global_rect()
		assert_float(tab.position.y).is_less(rect.position.y)
		assert_bool(VIEW.encloses(tab)).is_true()


## The KEEP ONE label hides once the pick is pressed (V3, v0.98: no veil; the prize bay frames
## the row).
func test_keep_one_hides_after_the_press() -> void:
	var view: RewardMachineView = _view(MachineVisit.Kind.TICKET, false, RARITIES)
	var plan: MachinePlan = view.plan
	var row: PrizeRow = view.prize_row
	plan.set_landing(MachinePlan.Landing.NEW_CARD, 1, MachinePlan.NO_VISIT)
	row.frame(plan.press + 0.5)
	assert_bool(row.keep_label().visible).is_false()


## Each prize in full (V3, v0.98: the band is the name, no kind word): a product's name, its price
## and its long rule (#105) over its real sprite; a coupon's name; a LOYALTY prize's perk name and
## effect over a punch card, its perk's glyph in the first stamp slot (Big basket's "+1 slot"); an
## upgrade's name line and new tier on its chip; the SHELF upgrade's plain item on a gold plank,
## "SHELF +1".
func test_every_ticket_shows_its_prize_in_full() -> void:
	var view: RewardMachineView = _view(MachineVisit.Kind.TICKET, true, [0])
	var milk: CardDefinition = load(MILK)
	var product: PrizeTicket = _ticket(
		view, 0, MachinePrize.new(MachinePrize.Kind.PRODUCT, 0, milk), null, 1
	)
	assert_array(Array(product.face_texts())).is_equal([milk.display_name, milk.rule_text])
	# The relook (v0.98): the price in its window at the art's top right, inside the art box.
	assert_str(product.price_line().text()).is_equal("%d€" % milk.base)
	assert_bool(PrizeTicket.ART_RECT.encloses(product.price_rect())).is_true()
	assert_object(product.art.get_node("Sprite")).is_not_null()
	var coupon_card: CardDefinition = _balance.first_offer_pool[0]
	var coupon: PrizeTicket = _ticket(
		view, 0, MachinePrize.new(MachinePrize.Kind.COUPON, 1, coupon_card), null, 1
	)
	assert_str(coupon.face_texts()[0]).is_equal(coupon_card.display_name)
	assert_object(coupon.price_line()).is_null()
	assert_object(coupon.art.get_node("Sprite")).is_not_null()
	var basket: UpgradeDefinition = load(BIG_BASKET)
	var stamp: MachinePrize = MachinePrize.new(MachinePrize.Kind.REGISTER, 0, null, basket)
	var loyalty: PrizeTicket = _ticket(view, 0, stamp, null, 1)
	assert_array(Array(loyalty.face_texts())).is_equal([basket.display_name, basket.effect_text])
	assert_object(loyalty.art.perk_icon()).is_same(load(PLUS_SLOT))
	assert_object(loyalty.art.find_child("PerkIcon", false, false)).is_not_null()
	assert_object(loyalty.art.find_child("StampInitials", false, false)).is_null()
	var preview: MachinePreview = MachinePreview.new()
	preview.targets = [CardInstance.new(load(MILK_BIG), 3)]
	preview.to_cards = [load(MILK_GOLDEN)]
	preview.copies = 1
	var upgrade: PrizeTicket = _ticket(
		view, 0, MachinePrize.new(MachinePrize.Kind.UPGRADE, 0, milk), preview, 1
	)
	assert_array(Array(upgrade.face_texts())).is_equal(["Milk", "Turns 1 BIG copy GOLDEN"])
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
		["Shelf upgrade", "All your Milk (×2): +1 level"]
	)
	assert_bool(shelf.art.has_shelf()).is_true()
	assert_str(shelf.art.chip_text()).is_equal("SHELF +1")


## #108 section 4a: a LOYALTY ticket carries the win sticker, one row after shift 1 (the last row
## is the only one) and two from shift 2, a row that wins nothing reading WASTED. A product ticket
## and a perk with no scoring rule carry none. S1 (v0.98): tilted WIN_TILT across the ticket's
## foot, its right edge STICK_OUT past the ticket's and its top OVERLAP over the foot, clear of the
## rule; a won row's amount in green dark chunky digits inside the sticker, a WASTED row stamped.
## Dairy regulars pay +2 a Dairy item since v1.29: three Milks win +6€.
func test_a_loyalty_ticket_shows_its_win_sticker() -> void:
	var view: RewardMachineView = _view(MachineVisit.Kind.TICKET, true, [0])
	var milk: CardDefinition = load(MILK)
	var regulars: UpgradeDefinition = load(DAIRY_REGULARS)
	var stamp: MachinePrize = MachinePrize.new(MachinePrize.Kind.REGISTER, 0, null, regulars)
	var preview: MachinePreview = MachinePreview.new()
	preview.prize = stamp
	var run: RunState = _run_with_rows([[milk, milk, milk]])
	var first: PrizeTicket = _ticket(view, 0, stamp, preview, 1, run)
	assert_array(Array(first.win_texts())).is_equal(["LAST ROW +6€"])
	run = _run_with_rows([[milk, milk, milk], [load(BREAD)]])
	var later: PrizeTicket = _ticket(view, 0, stamp, preview, 1, run)
	assert_array(Array(later.win_texts())).is_equal(["LAST ROW WASTED", "BEST ROW +6€"])
	var strip: WinSticker = later.win_sticker()
	var placed: Rect2 = WinSticker.sticker_rect(2, strip.size.x, PrizeTicket.SIZE)
	# Its unrotated rect (get_rect() is the rotated one's).
	var unrotated: Rect2 = Rect2(strip.position, strip.size)
	(
		assert_bool(unrotated.is_equal_approx(placed))
		. override_failure_message(str(unrotated))
		. is_true()
	)
	assert_float(unrotated.end.x).is_equal(PrizeTicket.SIZE.x + WinSticker.STICK_OUT)
	assert_float(strip.position.y).is_equal(PrizeTicket.SIZE.y - WinSticker.OVERLAP)
	assert_float(strip.rotation_degrees).is_equal_approx(WinSticker.WIN_TILT, 0.001)
	assert_float(later.rule_label().get_rect().end.y).is_less_equal(strip.position.y)
	strip.frame(10.0, false)
	assert_float(strip.sticker_scale()).is_equal(1.0)
	assert_str(strip.shown_amount(0)).is_equal(WinSticker.WASTED)
	assert_float(strip.stamp_scale(0)).is_equal(1.0)
	assert_str(strip.shown_amount(1)).is_equal("+6€")
	var amount: MachineLine = strip.get_node("WinAmount1") as MachineLine
	assert_bool(amount.visible).is_true()
	assert_str(amount.text()).is_equal("+6€")
	assert_object(amount.ink()).is_equal(Palette.GREEN_DARK)
	assert_bool(Rect2(Vector2.ZERO, strip.size).encloses(amount.get_rect())).is_true()
	assert_bool((strip.get_node("WinAmount0") as MachineLine).visible).is_false()
	var product: PrizeTicket = _ticket(
		view, 0, MachinePrize.new(MachinePrize.Kind.PRODUCT, 0, milk), null, 1, run
	)
	assert_object(product.win_sticker()).is_null()
	var basket: MachinePreview = MachinePreview.new()
	basket.prize = MachinePrize.new(MachinePrize.Kind.REGISTER, 0, null, load(BIG_BASKET))
	assert_object(_ticket(view, 0, basket.prize, basket, 1, run).win_sticker()).is_null()


## S1's motion (v0.98): hidden until SLAP_AT, slapped in from SLAP_FROM down to 1x by
## SLAP_S later; each won row rolls from "+0€" to its amount from ROLL_AT + ROLL_STEP x its row
## over ROLL_S; a WASTED row's stamp thumps in from STAMP_FROM as its row would roll; under
## reduced motion it shows whole at the landing.
func test_the_win_sticker_slaps_in_and_rolls() -> void:
	assert_float(WinSticker.scale_at(WinSticker.SLAP_AT - 0.01, false)).is_equal(0.0)
	assert_float(WinSticker.scale_at(WinSticker.SLAP_AT, false)).is_equal_approx(
		WinSticker.SLAP_FROM, 0.001
	)
	var slapped: float = WinSticker.SLAP_AT + WinSticker.SLAP_S
	assert_float(WinSticker.scale_at(slapped, false)).is_equal_approx(1.0, 0.001)
	assert_float(WinSticker.scale_at(0.0, true)).is_equal(1.0)
	assert_float(WinSticker.scale_at(-0.01, true)).is_equal(0.0)
	var second: float = WinSticker.ROLL_AT + WinSticker.ROLL_STEP
	assert_str(WinSticker.rolled_text(40, 1, second - 0.01, false)).is_equal(WinSticker.ZERO)
	var half: String = WinSticker.rolled_text(40, 1, second + WinSticker.ROLL_S / 2.0, false)
	assert_str(half).is_not_equal(WinSticker.ZERO)
	assert_str(half).is_not_equal("+40€")
	assert_str(WinSticker.rolled_text(40, 1, second + WinSticker.ROLL_S, false)).is_equal("+40€")
	assert_str(WinSticker.rolled_text(40, 1, 0.0, true)).is_equal("+40€")
	assert_str(WinSticker.rolled_text(0, 0, 9.0, false)).is_equal(WinSticker.WASTED)
	assert_float(WinSticker.stamp_scale_at(0, WinSticker.ROLL_AT - 0.01, false)).is_equal(0.0)
	assert_float(WinSticker.stamp_scale_at(0, WinSticker.ROLL_AT + 0.001, false)).is_greater(1.5)
	var thumped: float = WinSticker.ROLL_AT + WinSticker.STAMP_S
	assert_float(WinSticker.stamp_scale_at(0, thumped, false)).is_equal_approx(1.0, 0.001)
	assert_float(WinSticker.stamp_scale_at(0, 0.0, true)).is_equal(1.0)


## C2 (v0.98; the sweep of the card foil since v0.99): COMMON has no sheen; RARE's and
## LEGENDARY's cross on landing and repeat every SHEEN_PERIOD, staggered per ticket, never under
## reduced motion.
func test_the_rarity_sheen_crosses_on_landing_and_repeats() -> void:
	var common: int = MachinePrize.Rarity.COMMON
	var rare: int = MachinePrize.Rarity.RARE
	assert_float(TicketRim.sheen_at(common, 0.1, 0.0, false)).is_equal(-1.0)
	var landing: float = TicketRim.SHEEN_LAND_S / 2.0
	assert_float(TicketRim.sheen_at(rare, landing, 0.0, false)).is_equal_approx(0.5, 0.001)
	assert_float(TicketRim.sheen_at(rare, landing, 0.0, true)).is_equal(-1.0)
	var period: float = TicketRim.SHEEN_PERIOD[rare]
	var crossing: float = TicketRim.SHEEN_S / 2.0
	assert_float(TicketRim.sheen_at(rare, 9.0, period * 3.0 + crossing, false)).is_equal_approx(
		0.5, 0.001
	)
	assert_float(TicketRim.sheen_at(rare, 9.0, period * 3.0 + crossing, false, 1)).is_equal(-1.0)
	assert_float(TicketRim.sheen_at(rare, 9.0, period * 3.0 + 1.0, false)).is_equal(-1.0)


## B2 (v0.98): a ticket wears its family chips in its art's top left corner, inside the art box
## and clear of the price window: a product its family's, a perk the family it boosts, a perk
## that boosts none (Big basket) none.
func test_a_ticket_wears_its_family_chips() -> void:
	var view: RewardMachineView = _view(MachineVisit.Kind.TICKET, true, [0])
	var milk: CardDefinition = load(MILK)
	var product: PrizeTicket = _ticket(
		view, 0, MachinePrize.new(MachinePrize.Kind.PRODUCT, 0, milk), null, 1
	)
	var families: PackedStringArray = PrizeTicket.chip_families(product.prize)
	assert_int(families.size()).is_greater(0)
	assert_int(product.family_chips().size()).is_equal(families.size())
	for chip: Rect2 in PrizeTicket.chip_rects(families.size()):
		assert_bool(PrizeTicket.ART_RECT.encloses(chip)).is_true()
		assert_bool(chip.intersects(product.price_rect())).is_false()
	var regulars: UpgradeDefinition = load(DAIRY_REGULARS)
	var stamp: MachinePrize = MachinePrize.new(MachinePrize.Kind.REGISTER, 0, null, regulars)
	assert_array(Array(PrizeTicket.chip_families(stamp))).is_equal([regulars.boosts_tag])
	var basket: UpgradeDefinition = load(BIG_BASKET)
	var plain: MachinePrize = MachinePrize.new(MachinePrize.Kind.REGISTER, 0, null, basket)
	assert_int(PrizeTicket.chip_families(plain).size()).is_equal(0)


## Every face's lines fit the ticket (V3, v0.98: the name in the band in hard pixel rows (one, or
## the balanced two-row split) when they fit NAME_WIDTH, else bold in NAME_LINES; the long rule
## text at the first RULE_SIZES size that shows it whole in the room left (rule_room, over a win
## sticker's foot or the plain one), else cut there, under the band; all inside the ticket): every
## product and coupon the machine can draw, every LOYALTY perk and every UPGRADES prize of every
## chain and rarity.
func test_every_face_fits_the_ticket() -> void:
	var view: RewardMachineView = _view(MachineVisit.Kind.TICKET, true, [0])
	var prizes: Array[MachinePrize] = []
	var previews: Array[MachinePreview] = []
	var machine: MachineDefinition = load(MACHINE)
	# Every chain's product at one of its tiers in turn, at that tier's rarity (v1.25).
	for index: int in machine.item_upgrades.size():
		var card: CardDefinition = machine.item_upgrades[index].tiers()[index % 3]
		var rarity: int = MachineDefinition.product_rarity(card)
		prizes.append(MachinePrize.new(MachinePrize.Kind.PRODUCT, rarity, card))
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
	var cut: PackedStringArray = []
	for index: int in range(prizes.size()):
		var ticket: PrizeTicket = _ticket(view, 0, prizes[index], previews[index], 1)
		# The name's row lays out its labels at the frame's end.
		await get_tree().process_frame
		var texts: PackedStringArray = ticket.face_texts()
		var what: String = " / ".join(texts)
		var rows: PackedStringArray = PrizeTicket.name_rows(texts[0])
		var display: bool = not rows.is_empty()
		assert_bool(ticket.name_control() is Label).override_failure_message(what).is_equal(
			not display
		)
		for row: String in rows:
			assert_float(MachineLine.width_of(row)).override_failure_message(what).is_less_equal(
				PrizeTicket.NAME_WIDTH
			)
		var name_lines: int = rows.size() if display else PrizeTicket.NAME_LINES
		if not display:
			var bold_lines: int = PrizeTicket.text_lines(
				bold, texts[0], PrizeTicket.NAME_SIZE, PrizeTicket.NAME_WIDTH
			)
			assert_int(bold_lines).override_failure_message(what).is_less_equal(
				PrizeTicket.NAME_LINES
			)
		assert_int(ticket.name_line_count()).override_failure_message(what).is_equal(name_lines)
		assert_int(name_lines).override_failure_message(what).is_less_equal(PrizeTicket.NAME_LINES)
		# #105: the long rule text, whole, at the first RULE_SIZES size that shows it.
		var fit: Vector2i = PrizeTicket.rule_fit(texts[1], name_lines)
		var rule_lines: int = PrizeTicket.text_lines(
			rule_font, texts[1], PrizeTicket.RULE_SIZES[fit.y], PrizeTicket.RULE_WIDTH
		)
		assert_int(rule_lines).override_failure_message(what).is_equal(fit.x)
		# Whole, never cut: over the face's plain foot and, for a prize that can carry a win
		# sticker (a LOYALTY perk, an UPGRADES prize), over the sticker's.
		var stickers: Array[bool] = [false]
		if prizes[index].kind in [MachinePrize.Kind.REGISTER, MachinePrize.Kind.UPGRADE]:
			stickers = [false, true]
		for sticker: bool in stickers:
			if not PrizeTicket.rule_whole(texts[1], name_lines, sticker):
				cut.append("%s (sticker %s)" % [what, sticker])
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
	# #105: no rule is ever cut on its ticket.
	assert_array(Array(cut)).override_failure_message(", ".join(cut)).is_empty()


## A LOYALTY prize's perk glyph sits in the punch card's first stamp slot (V3, v0.98: no badge),
## inside the card and below its band (Big basket's 13x12 "+1" ticket included).
func test_the_perk_glyph_sits_in_the_first_stamp_slot() -> void:
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
		var card: Rect2 = PrizeArt.PUNCH_RECT
		assert_bool(card.encloses(rect)).override_failure_message(String(perk.id)).is_true()
		var below: float = rect.position.y - (card.position.y + PrizeArt.PUNCH_BAND)
		assert_float(below).override_failure_message(String(perk.id)).is_greater_equal(0.0)
	assert_int(shown).is_greater(0)


## The art's chip (v0.61, #108): every perk level above 1 reads "LV n", and every BIG or GOLDEN
## item its tier; the chip lies inside the art, and a level's clear of the punch card.
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
				assert_bool(art.chip_rect().intersects(PrizeArt.PUNCH_RECT))
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
	view: RewardMachineView,
	index: int,
	prize: MachinePrize,
	preview: MachinePreview,
	count: int,
	run: RunState = null
) -> PrizeTicket:
	if run == null:
		run = RunState.new(1, _starter, _balance, RunStock.starting(_balance))
	var ticket: PrizeTicket = PrizeTicket.new(index, prize, preview, run)
	ticket.rest = PrizeRow.card_rect(index, count).position
	ticket.launch = PrizeRow.LAUNCH
	ticket.setup(view)
	view.card_layer.add_child(ticket)
	return ticket


## A new run whose history holds `rows`, each a checked-out shift.
func _run_with_rows(rows: Array) -> RunState:
	var run: RunState = RunState.new(1, _starter, _balance, RunStock.starting(_balance))
	for index: int in rows.size():
		var record: ShiftRecord = ShiftRecord.new(index + 1, 0, 0)
		for card: CardDefinition in rows[index]:
			record.played.append(card)
		run.history.append(record)
	return run


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
