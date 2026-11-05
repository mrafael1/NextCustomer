extends GdUnitTestSuite
## The prize cards' rarity looks (v0.97, the user's picks of 2026-11-04 on
## docs/art/mockups/card_rarity.html; CardFoil): every kind of prize at every rarity wears its own
## card (COMMON look C's shelf label, RARE and LEGENDARY look B's foil) with V3's name band, family
## chips, price window, rule and win sticker inside the card and clear of each other; the foil
## slides, cycles and sweeps on the machine's clock and holds still under reduced motion; a
## LEGENDARY card's art breaks out over its plate (an outline, a clamped climb; a GOLDEN item
## outlined all round); the card's icons are whole art px at an integer scale on the 2 px grid with
## nearest filtering (the user's 2026-11-05 note: the card icons were blurry); and the display's
## message and the prize bay's header print in the chunky capitals (PICK 1, YOUR PRIZES · KEEP 1).

const BALANCE := "res://data/balance/balance.tres"
const STARTER := "res://data/decks/starter.tres"
const MACHINE := "res://data/balance/machine.tres"
const MILK := "res://data/cards/milk.tres"
const MILK_GOLDEN := "res://data/cards/milk_golden.tres"
const CROISSANT := "res://data/cards/croissant.tres"
const CARRIER_BAG_BIG := "res://data/cards/carrier_bag_big.tres"
const CARDS := "res://data/cards"
const DAIRY_REGULARS := "res://data/upgrades/dairy_regulars.tres"
const RARITIES: Array[int] = [
	MachinePrize.Rarity.COMMON, MachinePrize.Rarity.RARE, MachinePrize.Rarity.LEGENDARY
]

var _folder: String = ""
var _balance: BalanceDefinition
var _starter: DeckDefinition


func before_test() -> void:
	_folder = "user://test_card_rarity_%d" % Time.get_ticks_usec()
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


## Each kind at each rarity: its look is its rarity (the foil shows on RARE and LEGENDARY only);
## the band stands inside the card's frame (2 art px on COMMON, 3 on the foil) and holds the name;
## the family chips and the price window sit inside the art window (under a LEGENDARY card's
## plate), clear of each other; the rule sits under the band inside the face; the tab and the pips
## take the rarity's look; a LOYALTY prize's win sticker hangs off the foot, clear of the band.
func test_each_rarity_wears_its_own_card() -> void:
	var view: RewardMachineView = _view()
	var face: Rect2 = Rect2(Vector2.ZERO, PrizeTicket.SIZE)
	for prize_of: Callable in _prize_makers():
		for rarity: int in RARITIES:
			var prize: MachinePrize = prize_of.call(rarity)
			var ticket: PrizeTicket = _ticket(view, prize, _run_with_rows())
			await get_tree().process_frame
			var what: String = "%s at %d" % [ticket.face_texts()[0], rarity]
			assert_int(ticket.look).override_failure_message(what).is_equal(rarity)
			assert_bool(ticket.foil.visible).override_failure_message(what).is_equal(rarity > 0)
			var frame_px: float = (2.0 if rarity == 0 else 3.0) * MachineArt.PIXEL
			var band: Rect2 = PrizeTicket.band_rect(ticket.name_line_count(), rarity)
			(
				assert_bool(face.grow(-frame_px).encloses(band))
				. override_failure_message(what)
				. is_true()
			)
			var name_rect: Rect2 = ticket.name_control().get_rect()
			assert_bool(band.grow(0.5).encloses(name_rect)).override_failure_message(what).is_true()
			var window: Rect2 = CardFoil.window_rect(rarity)
			var chips: Array[Rect2] = ticket.family_rects()
			for index: int in chips.size():
				var chip: Rect2 = chips[index]
				assert_bool(window.encloses(chip)).override_failure_message(what).is_true()
				(
					assert_bool(chip.intersects(ticket.price_rect()))
					. override_failure_message(what)
					. is_false()
				)
				for other: int in range(index + 1, chips.size()):
					assert_bool(chip.intersects(chips[other])).is_false()
			if ticket.price_line() != null:
				var price: Rect2 = ticket.price_rect()
				# In the window, or at the top right as on every card (a LEGENDARY card's over
				# its plate's corner, corner_tops).
				var placed: bool = (
					window.encloses(price)
					or is_equal_approx(price.position.y, PrizeTicket.PRICE_TOP)
				)
				assert_bool(placed).override_failure_message(what).is_true()
				(
					assert_bool(PrizeTicket.ART_RECT.encloses(price))
					. override_failure_message(what)
					. is_true()
				)
				var art_chip: Rect2 = ticket.art.chip_rect()
				art_chip.position += PrizeTicket.ART_RECT.position
				(
					assert_bool(art_chip.has_area() and art_chip.intersects(price))
					. override_failure_message(what)
					. is_false()
				)
			var rule: Rect2 = ticket.rule_label().get_rect()
			assert_float(rule.position.y).override_failure_message(what).is_greater_equal(
				band.end.y
			)
			assert_bool(face.encloses(rule)).override_failure_message(what).is_true()
			assert_int(ticket.tab.rarity).override_failure_message(what).is_equal(rarity)
			assert_str(ticket.pips_text()).is_equal(["●", "◆◆", "★★★"][rarity])
			assert_that(RarityTab.FILLS[rarity]).is_equal(
				[Palette.CREAM_SHADE, Palette.TEAL, Palette.GOLD][rarity]
			)
			assert_that(PrizeTicket.PIP_INKS[rarity]).is_equal(
				[Palette.GREY, Palette.TEAL, Palette.BRASS_DARKEST][rarity]
			)
			var sticker: WinSticker = ticket.win_sticker()
			if sticker != null:
				var hung: Rect2 = sticker.get_global_transform() * Rect2(Vector2.ZERO, sticker.size)
				var card: Rect2 = ticket.get_global_rect()
				assert_float(hung.end.y).override_failure_message(what).is_greater(card.end.y)
				var global_band: Rect2 = ticket.get_global_transform() * band
				assert_bool(hung.intersects(global_band)).override_failure_message(what).is_false()
			ticket.free()


## The foil's numbers on the machine's clock: a RARE card's stripes slide (three times as fast
## while hovered) and cycle, its sweep crosses on landing; under reduced motion the phase holds
## STILL_PHASE, the colours stand at cycle 0 and no sweep crosses. A LEGENDARY card shows its
## sunburst, turning a step every RAY_STEP_S (still under reduced motion).
func test_the_foil_moves_and_holds_still_under_reduced_motion() -> void:
	var view: RewardMachineView = _view()
	var rare: PrizeTicket = _ticket(view, _product(MILK, MachinePrize.Rarity.RARE), null)
	var foil: CardFoil = rare.foil
	assert_int(foil.parameter(&"ring_n")).is_equal(CardFoil.RARE_RING.size())
	assert_int(foil.parameter(&"window_n")).is_equal(3)
	assert_int(foil.parameter(&"band_n")).is_equal(2)
	foil.frame(1.0, 0.1, 0, false, false)
	foil.frame(2.0, 1.1, 0, false, false)
	var slid: float = float(foil.parameter(&"phase"))
	assert_float(slid).is_equal_approx(CardFoil.STRIPE_RATE[MachinePrize.Rarity.RARE], 0.001)
	assert_int(foil.parameter(&"cycle")).is_equal(int(floorf(2.0 / CardFoil.CYCLE_S)))
	foil.frame(3.0, 2.1, 0, true, false)
	var hovered_step: float = float(foil.parameter(&"phase")) - slid
	assert_float(hovered_step).is_equal_approx(
		CardFoil.STRIPE_RATE[MachinePrize.Rarity.RARE] * CardFoil.HOVER_RATE, 0.001
	)
	assert_that(foil.parameter(&"window_cols")[0]).is_equal(Palette.PAPER)
	foil.frame(3.1, TicketRim.SHEEN_LAND_S / 2.0, 0, false, false)
	assert_float(float(foil.parameter(&"sweep_k"))).is_equal_approx(0.5, 0.001)
	foil.frame(4.0, 0.1, 0, false, true)
	assert_float(float(foil.parameter(&"phase"))).is_equal(CardFoil.STILL_PHASE)
	assert_int(foil.parameter(&"cycle")).is_equal(0)
	assert_float(float(foil.parameter(&"sweep_k"))).is_equal(-1.0)
	var common: PrizeTicket = _ticket(view, _product(MILK, MachinePrize.Rarity.COMMON), null)
	assert_bool(common.foil.visible).is_false()
	var legendary: PrizeTicket = _ticket(view, _product(MILK, MachinePrize.Rarity.LEGENDARY), null)
	var gold: CardFoil = legendary.foil
	assert_bool(gold.parameter(&"rays")).is_true()
	assert_int(gold.parameter(&"ring_n")).is_equal(CardFoil.GILT.size())
	gold.frame(CardFoil.RAY_STEP_S * 3.0 + 0.01, 1.0, 0, false, false)
	assert_float(float(gold.parameter(&"ray_turn"))).is_equal_approx(CardFoil.RAY_STEP * 3.0, 0.001)
	gold.frame(CardFoil.RAY_STEP_S * 5.0 + 0.01, 1.0, 0, false, true)
	assert_float(float(gold.parameter(&"ray_turn"))).is_equal(0.0)


## A LEGENDARY card's art breaks out over its plate: an ink outline clipped to above the window
## behind the sprite, a climb of at most CLIMB_MAX that ends with the sprite's ink BREAKOUT over
## the window (or less when the climb is clamped) and inside the card; a GOLDEN item's outline is
## unclipped (all round). COMMON and RARE cards keep their sprite in place with no outline.
func test_the_legendary_art_breaks_out_over_its_plate() -> void:
	var view: RewardMachineView = _view()
	var window_top: float = CardFoil.window_rect(MachinePrize.Rarity.LEGENDARY).position.y
	for path: String in [CROISSANT, MILK]:
		var ticket: PrizeTicket = _ticket(view, _product(path, MachinePrize.Rarity.LEGENDARY), null)
		var art: PrizeArt = ticket.art
		var outline: TextureRect = art.breakout_outline()
		assert_object(outline).is_not_null()
		assert_bool(outline.get_parent().clip_contents).is_true()
		assert_int(outline.get_index()).is_less(art.sprite().get_index() + 1)
		assert_float(art.climb_full()).is_between(0.0, PrizeArt.CLIMB_MAX)
		var rest: float = art.sprite().position.y
		art.climb(PrizeArt.CLIMB_TO + 0.1, false)
		var sprite: TextureRect = art.sprite()
		assert_float(sprite.position.y).is_equal(rest - art.climb_full())
		var texel: float = sprite.size.x / sprite.texture.get_size().x
		var ink_top: float = (
			PrizeTicket.ART_RECT.position.y
			+ sprite.position.y
			+ PrizeArt.ink_top_of(sprite.texture) * texel
		)
		assert_float(ink_top).is_greater_equal(0.0)
		if art.climb_full() < PrizeArt.CLIMB_MAX:
			assert_float(ink_top).is_less_equal(window_top - PrizeArt.BREAKOUT + 0.5)
		art.climb(-1.0, false)
		assert_float(art.sprite().position.y).is_equal(rest)
	var croissant: PrizeTicket = _ticket(
		view, _product(CROISSANT, MachinePrize.Rarity.LEGENDARY), null
	)
	assert_float(croissant.art.climb_full()).is_greater(0.0)
	var golden: PrizeTicket = _ticket(
		view, _product(MILK_GOLDEN, MachinePrize.Rarity.LEGENDARY), null
	)
	assert_bool(golden.art.breakout_outline().get_parent().clip_contents).is_false()
	for rarity: int in [MachinePrize.Rarity.COMMON, MachinePrize.Rarity.RARE]:
		var plain: PrizeTicket = _ticket(view, _product(CROISSANT, rarity), null)
		assert_object(plain.art.breakout_outline()).is_null()


## A LEGENDARY NEW ITEM's price window and family chips stay off its climbed art (the reviewer's
## Big Carrier bag: the window under the plate covered its handle): of their spots (under the
## plate, the window's foot, and the price's top right as on every card) each takes the one that
## covers the fewest of the art's ink texels at its full climb, never over the art's tier chip,
## the foot first when the art climbs out (mock-up card_rarity_B.html). Checked on every product
## sprite the machine can draw at LEGENDARY.
func test_the_legendary_price_and_chips_keep_off_the_climbed_art() -> void:
	var view: RewardMachineView = _view()
	var placed: int = 0
	for path: String in _product_paths():
		var ticket: PrizeTicket = _ticket(view, _product(path, MachinePrize.Rarity.LEGENDARY), null)
		var art: PrizeArt = ticket.art
		var art_chip: Rect2 = art.chip_rect()
		art_chip.position += PrizeTicket.ART_RECT.position
		var price: Rect2 = ticket.price_rect()
		var price_ink: int = _ink(ticket, price)
		for top: float in [
			PrizeTicket.PRICE_TOP, PrizeTicket.LEGENDARY_CHIP_TOP, PrizeTicket.PRICE_FOOT
		]:
			var spot: Rect2 = Rect2(price.position.x, top, price.size.x, price.size.y)
			if art_chip.has_area() and spot.intersects(art_chip):
				continue
			assert_int(price_ink).override_failure_message(path).is_less_equal(_ink(ticket, spot))
		var chips: Array[Rect2] = ticket.family_rects()
		if not chips.is_empty():
			var row: Rect2 = chips[0].merge(chips[chips.size() - 1])
			var chip_ink: int = _ink(ticket, row)
			for top: float in [PrizeTicket.LEGENDARY_CHIP_TOP, PrizeTicket.CHIP_FOOT]:
				var spot: Rect2 = Rect2(row.position.x, top, row.size.x, row.size.y)
				if art_chip.has_area() and spot.intersects(art_chip):
					continue
				assert_int(chip_ink).override_failure_message(path).is_less_equal(
					_ink(ticket, spot)
				)
			assert_bool(art_chip.has_area() and art_chip.intersects(row)).is_false()
			assert_bool(row.intersects(price)).override_failure_message(path).is_false()
		placed += 1
		ticket.free()
	assert_int(placed).is_greater(10)
	var bag: PrizeTicket = _ticket(
		view, _product(CARRIER_BAG_BIG, MachinePrize.Rarity.LEGENDARY), null
	)
	var under_plate: Rect2 = bag.price_rect()
	under_plate.position.y = PrizeTicket.LEGENDARY_CHIP_TOP
	assert_int(_ink(bag, bag.price_rect())).is_less(_ink(bag, under_plate))
	var croissant: PrizeTicket = _ticket(
		view, _product(CROISSANT, MachinePrize.Rarity.LEGENDARY), null
	)
	assert_float(croissant.art.climb_full()).is_greater(0.0)
	assert_int(_ink(croissant, croissant.price_rect())).is_equal(0)


## The pedestals' light strips light in their ticket's rarity (mock-up card_rarity.html, taken from
## look A): cream shade, teal pale, gold; unlit before the reveal.
func test_the_pedestal_strips_light_in_the_rarity() -> void:
	var view: RewardMachineView = _view()
	view.plan.set_draw(RARITIES)
	view.bay.frame(-1.0)
	for colour: Color in view.bay.strip_colours():
		assert_float(colour.a).is_equal(0.0)
	view.bay.frame(view.plan.reveal_at[2] + 1.0)
	assert_array(view.bay.strip_colours()).is_equal(
		[Palette.CREAM_SHADE, Palette.TEAL_PALE, Palette.GOLD]
	)


## The card's icons are crisp: the sprite, a coupon's icon, a perk's icon and every texture the card
## draws (the family glyphs, the stamp rings, the sparkles) are filtered nearest, at a whole number
## of canvas px per texel that is a multiple of the art's 2 px (so a whole number of screen px at
## 1280x720's 1x and 1920x1080's 1.5x), placed on the 2 px grid of the ticket; the chips' glyphs
## too. The art's words keep linear filtering.
func test_the_card_icons_are_whole_art_pixels() -> void:
	var view: RewardMachineView = _view()
	var p: float = MachineArt.PIXEL
	for prize_of: Callable in _prize_makers():
		for rarity: int in RARITIES:
			var ticket: PrizeTicket = _ticket(view, prize_of.call(rarity), _run_with_rows())
			ticket.view.idle_time = 1.0
			ticket.frame(9.0)
			var what: String = "%s at %d" % [ticket.face_texts()[0], rarity]
			assert_int(_filter_of(ticket.art)).override_failure_message(what).is_equal(
				CanvasItem.TEXTURE_FILTER_NEAREST
			)
			for layer_name: String in ["Card/Chip", "FxBack", "FxFront"]:
				var layer: CanvasItem = ticket.get_node(layer_name)
				assert_int(_filter_of(layer)).override_failure_message(what).is_equal(
					CanvasItem.TEXTURE_FILTER_NEAREST
				)
			var icons: Array[Node] = ticket.art.find_children("*", "TextureRect", true, false)
			for found: Node in icons:
				var icon: TextureRect = found as TextureRect
				if icon.texture == null or icon.name == "BreakoutOutline":
					continue
				var texels: Vector2 = icon.texture.get_size()
				var per: Vector2 = icon.size / texels
				var at: Vector2 = icon.get_global_position() - ticket.get_global_position()
				var name_of: String = "%s: %s" % [what, icon.name]
				assert_int(_filter_of(icon)).override_failure_message(name_of).is_equal(
					CanvasItem.TEXTURE_FILTER_NEAREST
				)
				assert_float(per.x).override_failure_message(name_of).is_equal(per.y)
				assert_float(fposmod(per.x, p)).override_failure_message(name_of).is_equal(0.0)
				assert_float(fposmod(at.x, p)).override_failure_message(name_of).is_equal(0.0)
				assert_float(fposmod(at.y, p)).override_failure_message(name_of).is_equal(0.0)
			for chip: Rect2 in ticket.family_rects():
				assert_float(fposmod(chip.position.x, p)).is_equal(0.0)
				assert_float(fposmod(chip.position.y, p)).is_equal(0.0)
			for family: FamilyStyle in ticket.family_chips():
				if family.glyph != null:
					var glyph: Vector2 = family.glyph.get_size() * p
					assert_float(glyph.x + 4.0 * p).is_less_equal(PrizeTicket.CHIP_SIZE)
			for label: Node in ticket.art.find_children("*", "Label", true, false):
				assert_int((label as Label).texture_filter).is_equal(
					CanvasItem.TEXTURE_FILTER_LINEAR
				)
			assert_float(fposmod(ticket.position.x, p)).is_equal(0.0)
			assert_float(fposmod(ticket.position.y, p)).is_equal(0.0)
			ticket.free()


## PICK 1 and YOUR PRIZES · KEEP 1 (the user's 2026-11-05 note): the display's message lines and
## the prize bay's header print their words in the chunky capitals (2 px stems) at one art px per
## font px, CHUNKY_ROWS art px tall, every letter of them in the sheet; the short-stock prompt fits
## the glass on one or two lines.
func test_pick_1_and_your_prizes_print_in_chunky_capitals() -> void:
	var view: RewardMachineView = _view()
	var glyphs: Dictionary[String, Array] = PixelWords.chunky_caps_glyphs()
	for line_text: String in [
		PrizeBay.HEADER_DRAWN, PrizeBay.HEADER_WAIT, "PICK 1 · ONLY 2 IN STOCK"
	]:
		for character: String in line_text:
			if character != " " and not character.is_valid_int():
				assert_bool(glyphs.has(character)).override_failure_message(character).is_true()
	view.display.show_message("PICK 1", "or skip the draw")
	var line: MachineLine = view.display.message_lines()[0]
	assert_bool(line.chunky).is_true()
	assert_float(line.size.y).is_equal(float(MachineLine.CHUNKY_ROWS * ArtStyle.ART_SCALE))
	var words: Array[PixelWords] = line.caps_words()
	assert_int(words.size()).is_equal(1)
	assert_float(words[0].cell).is_equal(float(ArtStyle.ART_SCALE))
	assert_float(words[0].position.y).is_equal(0.0)
	assert_int(line.number_words().size()).is_equal(1)
	assert_bool(MachineDisplay.GLASS_RECT.encloses(line.get_rect())).is_true()
	var room: float = MachineDisplay.GLASS_RECT.size.x - 2.0 * MachineDisplay.PAD
	for part: String in MachineDisplay.wrap_message("PICK 1 · ONLY 2 IN STOCK", room):
		assert_float(MachineLine.width_of(part, 1, true)).is_less_equal(room)
	var header: MachineLine = view.bay.header()
	assert_bool(header.chunky).is_true()
	header.show_text(PrizeBay.HEADER_DRAWN, Palette.GOLD)
	header.centre_in(PrizeBay.HEADER_RECT)
	assert_int(header.caps_words().size()).is_greater(0)
	assert_float(header.size.y).is_equal(float(MachineLine.CHUNKY_ROWS * ArtStyle.ART_SCALE))
	assert_bool(PrizeBay.HEADER_RECT.encloses(header.get_rect())).is_true()
	assert_float(header.width()).is_equal(MachineLine.width_of(PrizeBay.HEADER_DRAWN, 1, true))


## How many of `ticket`'s climbed art's ink texels `rect` (ticket coordinates) covers.
static func _ink(ticket: PrizeTicket, rect: Rect2) -> int:
	return ticket.art.ink_texels(Rect2(rect.position - PrizeTicket.ART_RECT.position, rect.size))


## Every product card the machine can draw (data/cards with an items_v2 sprite).
static func _product_paths() -> Array[String]:
	var paths: Array[String] = []
	for file_name: String in DirAccess.get_files_at(CARDS):
		if not file_name.ends_with(".tres"):
			continue
		var card: CardDefinition = load(CARDS.path_join(file_name)) as CardDefinition
		if card != null and not card.is_coupon() and card.art_ref.contains("items_v2"):
			paths.append(CARDS.path_join(file_name))
	return paths


## The filter `item` draws with (its own, or the nearest ancestor's that sets one).
static func _filter_of(item: CanvasItem) -> int:
	var node: Node = item
	while node is CanvasItem:
		var filter: int = (node as CanvasItem).texture_filter
		if filter != CanvasItem.TEXTURE_FILTER_PARENT_NODE:
			return filter
		node = node.get_parent()
	return CanvasItem.TEXTURE_FILTER_LINEAR


## One maker per kind (a product, a coupon, a LOYALTY perk, an item upgrade): rarity -> prize.
func _prize_makers() -> Array[Callable]:
	var machine: MachineDefinition = load(MACHINE)
	var coupon: CardDefinition = machine.rare_coupons[0]
	var chain: ItemUpgradeDefinition = machine.item_upgrades[0]
	var regulars: UpgradeDefinition = load(DAIRY_REGULARS)
	return [
		func(rarity: int) -> MachinePrize: return _product(MILK, rarity),
		func(rarity: int) -> MachinePrize:
			return MachinePrize.new(MachinePrize.Kind.COUPON, rarity, coupon),
		func(rarity: int) -> MachinePrize:
			return MachinePrize.new(MachinePrize.Kind.REGISTER, rarity, null, regulars),
		func(rarity: int) -> MachinePrize:
			return MachinePrize.new(MachinePrize.Kind.UPGRADE, rarity, chain.product),
	]


static func _product(path: String, rarity: int) -> MachinePrize:
	return MachinePrize.new(MachinePrize.Kind.PRODUCT, rarity, load(path) as CardDefinition)


## A machine view (not shown) with a plan of one landed ticket.
func _view() -> RewardMachineView:
	var view: RewardMachineView = auto_free(RewardMachineView.new())
	add_child(view)
	view.plan = MachinePlan.new(view.tuning, MachineVisit.Kind.TICKET, false)
	var rarities: Array[int] = [MachinePrize.Rarity.COMMON]
	view.plan.set_draw(rarities)
	return view


func _ticket(view: RewardMachineView, prize: MachinePrize, run: RunState) -> PrizeTicket:
	if run == null:
		run = RunState.new(1, _starter, _balance, RunStock.starting(_balance))
	var preview: MachinePreview = MachinePreview.new()
	if prize.kind == MachinePrize.Kind.UPGRADE:
		preview = _upgrade_preview(prize)
	preview.prize = prize
	var ticket: PrizeTicket = PrizeTicket.new(0, prize, preview, run)
	ticket.rest = PrizeRow.card_rect(0, 1).position
	ticket.launch = PrizeRow.LAUNCH
	ticket.setup(view)
	view.card_layer.add_child(ticket)
	return ticket


## An UPGRADES prize's preview: one copy of its product to the chain's next tier.
func _upgrade_preview(prize: MachinePrize) -> MachinePreview:
	var machine: MachineDefinition = load(MACHINE)
	var preview: MachinePreview = MachinePreview.new()
	for chain: ItemUpgradeDefinition in machine.item_upgrades:
		if chain.product == prize.card:
			preview.targets.append(CardInstance.new(chain.product, 1))
			preview.to_cards.append(chain.big)
			preview.copies = 1
	return preview


## A new run whose history holds a checked-out shift of Milk (a LOYALTY prize's sticker shows).
func _run_with_rows() -> RunState:
	var run: RunState = RunState.new(1, _starter, _balance, RunStock.starting(_balance))
	var record: ShiftRecord = ShiftRecord.new(1, 0, 0)
	for copy: int in range(3):
		record.played.append(load(MILK) as CardDefinition)
	run.history.append(record)
	return run


static func _event_log() -> EventLogService:
	return (Engine.get_main_loop() as SceneTree).root.get_node("/root/EventLog")
