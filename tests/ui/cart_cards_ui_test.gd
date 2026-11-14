extends GdUnitTestSuite
## The deck view's cart as cards and slim Run info on the real shift screen (mock-up
## docs/art/mockups/cart_cards.html, "2x8 cart face", approved by the user on 2026-11-13): the
## cards' layout (CartLayout), a 15-card cart of the longest rules in two rows at 1280x720 and
## 1920x1080, every card's rarity and rule fit, and the Run info's stock icon grid (its in-cart
## badges, its fit and its hover tips with the card face), the copies' stack and count clear of
## the tab and of the next column, and the rule's "…" cut. The rest of the view is
## deck_view_ui_test's.

const Cart := preload("res://tests/ui/deck_view_ui_test.gd")
const SCREEN := "res://ui/shift_screen.tscn"
const BALANCE := "res://data/balance/balance.tres"
const WINDOWS: Array[Vector2] = [Vector2(1280, 720), Vector2(1920, 1080)]
## A 15-card cart with the longest rules (12 products, 3 coupons; mock-up cart_cards.html).
const LONG_PRODUCTS: Array[String] = [
	"eggs_golden",
	"tea_bags_golden",
	"milk_big",
	"banana_golden",
	"bread",
	"coffee",
	"soup",
	"cheese",
	"butter",
	"cereal",
	"yogurt",
	"croissant",
]
const LONG_COUPONS: Array[String] = ["multipack", "two_for_one", "shelf_swap"]

var _folder: String = ""


func before_test() -> void:
	_folder = "user://test_logs_%d" % Time.get_ticks_usec()
	_event_log().use_folder(_folder)
	# The profile save goes there too, never to the real user:// profile.
	ProjectSettings.set_setting(SaveService.FOLDER_SETTING, _folder)


func after_test() -> void:
	ProjectSettings.set_setting(SaveService.FOLDER_SETTING, null)
	if DirAccess.dir_exists_absolute(_folder):
		for file_name: String in DirAccess.get_files_at(_folder):
			DirAccess.remove_absolute(_folder.path_join(file_name))
		DirAccess.remove_absolute(_folder)


## The cart's layout (CartLayout.of): at least two rows of up to 8 columns, the coupons in a group
## of their own after the products (ceil(coupons / rows) columns), the products in the columns
## left, a row more while the products don't fit; the columns at most GAP_MAX apart.
func test_the_cart_layout_keeps_the_coupons_in_their_own_group() -> void:
	var width: float = DeckView._line_width()
	var cases: Array[Array] = [
		# [products, coupons, rows, product columns, coupon columns]
		[12, 1, 2, 7, 1],
		[12, 3, 2, 6, 2],
		[15, 0, 2, 8, 0],
		[13, 2, 2, 7, 1],
		[3, 1, 2, 3, 1],
		[0, 2, 2, 0, 1],
		[14, 3, 3, 7, 1],
		[20, 0, 3, 8, 0],
	]
	for case: Array in cases:
		var layout: CartLayout = CartLayout.of(case[0], case[1], width)
		var where: String = str(case)
		assert_int(layout.rows).override_failure_message(where).is_equal(case[2])
		assert_int(layout.product_columns).override_failure_message(where).is_equal(case[3])
		assert_int(layout.coupon_columns).override_failure_message(where).is_equal(case[4])
		assert_int(layout.positions.size()).is_equal(case[0] + case[1])
		assert_float(layout.gap).override_failure_message(where).is_less_equal(CartLayout.GAP_MAX)
		assert_float(layout.gap).override_failure_message(where).is_greater_equal(0.0)
		for index: int in layout.positions.size():
			var at: Vector2 = layout.positions[index]
			assert_float(at.x + DeckCell.SIZE.x).override_failure_message(where).is_less_equal(
				width - CartLayout.GRID_PAD + 0.5
			)
			if index >= case[0]:
				assert_float(at.x).override_failure_message(where).is_greater_equal(
					layout.coupon_x - 0.5
				)
			elif case[1] > 0:
				assert_float(at.x + DeckCell.SIZE.x).is_less(layout.coupon_x - CartLayout.GROUP_GAP)


## The cart as cards (mock-up cart_cards.html, "2x8 cart face"): a 15-card cart with the longest
## rules (Golden Eggs, Golden Tea bags, Multipack, 2 for 1, Shelf swap) fits two rows of the Cart
## page unscrolled at 1280x720 and 1920x1080: every card inside the scroll area, no two
## overlapping, each rule whole inside its card's rule box at RULE_SIZES' smallest size or bigger
## (cut short with "…" only when even that size can't hold it), the rarity on its tab by tier,
## each hover tip (with its keyword boxes) inside the window and beside its card.
func test_fifteen_long_rule_cards_fit_two_rows() -> void:
	for window: Vector2 in WINDOWS:
		var screen: ShiftScreen = await _screen_at(window)
		screen.start_new_run(20261014, false)
		screen._week.skip()
		var run: RunState = screen.run
		for card: CardInstance in run.deck.cards.duplicate():
			run.deck.remove_card(card)
		for id: String in LONG_PRODUCTS + LONG_COUPONS:
			run.deck.add_card(load("res://data/cards/%s.tres" % id))
		assert_int(run.deck.size()).is_equal(15)
		screen._on_deck_button_pressed()
		var view: DeckView = screen._deck_view
		await get_tree().create_timer(0.4).timeout
		var where: String = str(window)
		var area: Rect2 = view._scroll.get_global_rect().grow(0.5)
		var content: Control = view._scroll.get_child(0)
		assert_float(content.size.y).override_failure_message(where).is_less_equal(
			view._scroll.size.y
		)
		var cells: Array[DeckCell] = view.cells()
		assert_int(cells.size()).is_equal(15)
		_assert_cards_laid_out(cells, area, where)
		var tops: Array[float] = []
		for cell: DeckCell in cells:
			var top: float = roundf(cell.get_global_rect().position.y)
			if not tops.has(top):
				tops.append(top)
		assert_int(tops.size()).override_failure_message(where).is_equal(2)
		var machine: MachineDefinition = run.balance.machine
		for cell: DeckCell in cells:
			var message: String = "%s %s" % [where, cell.card.id]
			_assert_rule_fits(cell, message)
			assert_int(cell.look).override_failure_message(message).is_equal(
				CartCardDraw.look_of(cell.card, machine)
			)
			view.hover(cell)
			assert_bool(view.tip().visible).is_true()
			# The test's viewport may be smaller than its 1920x1080 screen: only an item with room
			# for the tip beside it in the viewport is checked.
			if not _has_room(view, cell.get_global_rect()):
				continue
			_assert_tip_beside(view, cell.get_global_rect(), message)
		for id: String in ["eggs_golden", "tea_bags_golden"]:
			var golden: DeckCell = Cart._cell_of(view, StringName(id))
			assert_int(golden.look).is_equal(BoosterArt.Look.LEGENDARY)
		assert_int(Cart._cell_of(view, &"milk_big").look).is_equal(BoosterArt.Look.RARE)
		assert_int(Cart._cell_of(view, &"bread").look).is_equal(BoosterArt.Look.COMMON)
		# Bread's two family glyphs (Bakery, Breakfast) stand one under the other on its card.
		var bread: DeckCell = Cart._cell_of(view, &"bread")
		var glyphs: Array[FamilyGlyph] = bread.family_glyphs()
		assert_int(glyphs.size()).override_failure_message(where).is_equal(2)
		for glyph: FamilyGlyph in glyphs:
			assert_bool(glyph.is_visible_in_tree()).is_true()
			(
				assert_bool(bread.get_global_rect().encloses(glyph.get_global_rect()))
				. override_failure_message(where)
				. is_true()
			)
		assert_float(glyphs[1].global_position.x).is_equal(glyphs[0].global_position.x)
		assert_float(glyphs[1].global_position.y).is_greater(glyphs[0].get_global_rect().end.y)
		view._close()
		await get_tree().process_frame


## Every card's rarity look: a plain product COMMON, a BIG one RARE, a GOLDEN one LEGENDARY; a
## coupon by the machine's rare and legendary lists (COMMON otherwise).
func test_each_card_shows_its_rarity() -> void:
	var balance: BalanceDefinition = load(BALANCE)
	var machine: MachineDefinition = balance.machine
	var looks: Dictionary[BoosterArt.Look, int] = {}
	for file_name: String in DirAccess.get_files_at("res://data/cards"):
		if not file_name.ends_with(".tres"):
			continue
		var card: CardDefinition = load("res://data/cards/" + file_name)
		var expected: BoosterArt.Look = BoosterArt.Look.COMMON
		if card.is_coupon():
			if machine.legendary_coupons.has(card):
				expected = BoosterArt.Look.LEGENDARY
			elif machine.rare_coupons.has(card):
				expected = BoosterArt.Look.RARE
		elif card.tier == CardDefinition.Tier.GOLDEN:
			expected = BoosterArt.Look.LEGENDARY
		elif card.tier == CardDefinition.Tier.BIG:
			expected = BoosterArt.Look.RARE
		var look: BoosterArt.Look = CartCardDraw.look_of(card, machine)
		assert_int(look).override_failure_message(file_name).is_equal(expected)
		looks[look] = looks.get(look, 0) + 1
	assert_int(looks.size()).is_equal(3)


## Every card's rule fits its card face at one of the rule's sizes, or is cut short at a word with
## "…" at the smallest (the full text in the tip); the longest rules of the mock-up fit whole.
func test_every_rule_fits_its_card() -> void:
	var balance: BalanceDefinition = load(BALANCE)
	var whole: Array[String] = LONG_PRODUCTS + LONG_COUPONS
	for file_name: String in DirAccess.get_files_at("res://data/cards"):
		if not file_name.ends_with(".tres"):
			continue
		var card: CardDefinition = load("res://data/cards/" + file_name)
		var cell: DeckCell = DeckCell.new(CardInstance.new(card, 0), balance.machine, 1)
		add_child(cell)
		_assert_rule_fits(cell, file_name)
		if whole.has(file_name.get_basename()):
			assert_bool(cell.rule_clipped()).override_failure_message(file_name).is_false()
		cell.free()


## The family chips stand like the FIGURINE BOOK's glyphs (the user: "card should have second
## family icon like in toy book"): a product's main family, then its other printed families,
## Food only on a Food-only card (soup) and never beside another family; a coupon's its ticket's.
## Each chip's glyph is a FamilyGlyph naming its family, the next one CHIP_PITCH art px under it,
## all inside the art window's left half, clear of the START chip, the tier sticker (BIG,
## GOLDEN) and the rarity tab, on every card in the data.
func test_a_card_stacks_its_family_glyphs() -> void:
	var balance: BalanceDefinition = load(BALANCE)
	var palette: FamilyPalette = FamilyPalette.shared()
	var expected: Dictionary[String, Array] = {
		"bread": ["Bakery", "Breakfast"],
		"day_old_buns": ["Bakery", "Clearance"],
		"cheese": ["Dairy"],
		"soup": ["Food"],
		"coffee": ["Breakfast"],
	}
	var found: Array[String] = []
	var stacked: int = 0
	for file_name: String in DirAccess.get_files_at("res://data/cards"):
		if not file_name.ends_with(".tres"):
			continue
		var card: CardDefinition = load("res://data/cards/" + file_name)
		var cell: DeckCell = DeckCell.new(CardInstance.new(card, 0), balance.machine, 1)
		add_child(cell)
		cell.add_start_mark("test")
		var ids: Array = []
		for look: FamilyStyle in CartCardDraw.chip_families(card):
			ids.append(look.id)
		var glyphs: Array[FamilyGlyph] = cell.family_glyphs()
		assert_int(glyphs.size()).override_failure_message(file_name).is_equal(ids.size())
		if card.is_product():
			assert_array(ids).override_failure_message(file_name).is_equal(
				Array(palette.card_glyph_families(card))
			)
			if ids.size() > 1:
				assert_array(ids).override_failure_message(file_name).not_contains(["Food"])
		var id: String = file_name.get_basename()
		if expected.has(id):
			assert_array(ids).override_failure_message(id).is_equal(expected[id])
			found.append(id)
		var win: Rect2i = CartCardDraw.window(cell.look)
		var window: Rect2 = _scaled(Rect2(win))
		var left: Rect2 = Rect2(window.position, Vector2(window.size.x / 2.0, window.size.y))
		var start: RevealChip = cell.marks()[0]
		var chip: Rect2 = start.get_transform() * Rect2(Vector2.ZERO, start.size)
		var avoid: Array[Rect2] = [chip, _scaled(CartCardDraw.tab_rect(cell.look))]
		var tier: String = PriceSticker.tier_text(card) if card.is_product() else ""
		if not tier.is_empty():
			avoid.append(_scaled(Rect2(CartCardDraw.tier_rect(tier, win))))
		if glyphs.size() > 1:
			stacked += 1
		for index: int in glyphs.size():
			var glyph: FamilyGlyph = glyphs[index]
			var message: String = "%s glyph %d" % [file_name, index]
			assert_str(glyph.family).override_failure_message(message).is_equal(ids[index])
			assert_str(glyph.tip_text).override_failure_message(message).is_equal(
				palette.display_name(ids[index])
			)
			assert_object(glyph.get_parent()).is_same(cell.face())
			var tile: Rect2 = _scaled(Rect2(CartCardDraw.chip_rect(cell.look, index)))
			var drawn: Rect2 = Rect2(glyph.position, glyph.size)
			assert_bool(tile.grow(0.01).encloses(drawn)).override_failure_message(message).is_true()
			assert_bool(left.encloses(tile)).override_failure_message(message).is_true()
			for rect: Rect2 in avoid:
				assert_bool(tile.intersects(rect)).override_failure_message(message).is_false()
			if index > 0:
				var above: FamilyGlyph = glyphs[index - 1]
				assert_float(glyph.position.x).is_equal(above.position.x)
				assert_float(glyph.position.y - above.position.y).is_equal_approx(
					CartCardDraw.CHIP_PITCH * DeckCell.UNIT, 0.01
				)
		cell.free()
	assert_int(found.size()).is_equal(expected.size())
	assert_int(stacked).is_greater(0)


## The Run info stock shows every stocked card once, with its price (a coupon: its rarity) and an
## in-cart badge only when the cart holds copies of it (their count; teal for a BIG copy, gold for
## a GOLDEN one).
func test_run_info_stock_counts_the_cart() -> void:
	var screen: ShiftScreen = await _screen()
	var run: RunState = screen.run
	for card: CardInstance in run.deck.cards:
		if card.definition.id == &"banana":
			run.deck.upgrade(card, load("res://data/cards/banana_golden.tres"))
			break
	screen._on_deck_button_pressed()
	var view: DeckView = screen._deck_view
	view.show_page(true)
	var counts: Dictionary[StringName, Vector2i] = StockGrid.cart_counts(run)
	var shown: Array[CardDefinition] = []
	var badges: int = 0
	for icon: StockIcon in view.stock_grid().icons():
		shown.append(icon.card)
		var held: Vector2i = counts.get(icon.card.id, Vector2i.ZERO)
		var badge: StockIcon.Badge = icon.badge()
		assert_bool(badge != null).override_failure_message(icon.name).is_equal(held.x > 0)
		if icon.card.is_coupon():
			assert_str(icon.price_label().text).is_equal(StockIcon.COUPON_WORDS[icon.look])
		else:
			assert_str(icon.price_label().text).is_equal(PriceSticker.price_text(icon.card.base))
		if badge == null:
			continue
		badges += 1
		assert_str(badge.text()).is_equal("×%d" % held.x)
		assert_int(badge.tier).is_equal(held.y)
		var box: Rect2 = icon.get_global_rect().grow(8.0)
		assert_bool(box.encloses(badge.get_global_rect())).is_true()
	assert_int(badges).is_greater(0)
	assert_array(shown).contains_exactly_in_any_order(run.stock.cards)
	var banana: StockIcon = null
	for icon: StockIcon in view.stock_grid().icons():
		if icon.card.id == &"banana":
			banana = icon
	assert_object(banana).is_not_null()
	assert_int(banana.badge().tier).is_equal(CardDefinition.Tier.GOLDEN)
	assert_that(banana.badge().fill()).is_equal(Palette.GOLD)


## The slim Run info fits each window unscrolled when it can (the hero and the stock's grid with
## its legend inside the scroll area), its stock grid inside the page's width; hovering a stock
## icon opens the tip with the card's face inside the window, beside the icon.
func test_the_run_info_fits_and_its_stock_shows_cards() -> void:
	for window: Vector2 in WINDOWS:
		var screen: ShiftScreen = await _screen_at(window)
		screen.start_new_run(20261014, false)
		screen._week.skip()
		screen._on_deck_button_pressed()
		var view: DeckView = screen._deck_view
		view.show_page(true)
		await get_tree().create_timer(0.4).timeout
		var where: String = str(window)
		var area: Rect2 = view._scroll.get_global_rect().grow(0.5)
		var content: Control = view._scroll.get_child(0)
		assert_float(content.size.y).override_failure_message(where).is_less_equal(
			view._scroll.size.y
		)
		var grid: StockGrid = view.stock_grid()
		assert_bool(area.encloses(grid.get_global_rect())).override_failure_message(where).is_true()
		for icon: StockIcon in grid.icons():
			(
				assert_bool(area.encloses(icon.get_global_rect()))
				. override_failure_message("%s %s" % [where, icon.name])
				. is_true()
			)
		for icon: StockIcon in grid.icons():
			view.hover_stock(icon)
			var tip: CardTip = view.tip()
			assert_bool(tip.visible).is_true()
			assert_bool(icon.lit).is_true()
			var face: DeckCell = tip.face()
			assert_object(face).is_not_null()
			assert_object(face.card).is_same(icon.card)
			assert_float(tip.main_card().size.x).is_equal(CardTip.FACE_WIDTH)
			var in_cart: String = (
				CardTip.IN_CART % icon.in_cart if icon.in_cart > 0 else CardTip.NOT_IN_CART
			)
			assert_str(tip.lines()[-1]).is_equal(in_cart)
			if not _has_room(view, icon.get_global_rect()):
				continue
			_assert_tip_beside(view, icon.get_global_rect(), "%s %s" % [where, icon.name])
		view.hover_stock(grid.icons()[0])
		grid.icons()[0].unhovered.emit(grid.icons()[0])
		assert_bool(view.tip().visible).is_false()
		assert_bool(grid.icons()[0].lit).is_false()
		view._close()
		await get_tree().process_frame


## The copies' count label sits over the card's top right corner clear of the rarity tab, for
## each tab word (COMMON, RARE, LEGENDARY).
func test_the_count_clears_the_rarity_tab() -> void:
	var balance: BalanceDefinition = load(BALANCE)
	for id: String in ["bread", "milk_big", "eggs_golden"]:
		var card: CardDefinition = load("res://data/cards/%s.tres" % id)
		var cell: DeckCell = DeckCell.new(CardInstance.new(card, 0), balance.machine, 3)
		add_child(cell)
		var tab: Rect2 = CartCardDraw.tab_rect(cell.look)
		tab = Rect2(tab.position * DeckCell.UNIT, tab.size * DeckCell.UNIT)
		var count: EffectSticker = cell.count_label()
		var label: Rect2 = Rect2(count.position, count.size * count.scale)
		assert_bool(label.intersects(tab)).override_failure_message(id).is_false()
		assert_bool(label.intersects(cell.column_rect())).override_failure_message(id).is_true()
		assert_float(label.position.x).override_failure_message(id).is_greater(
			DeckCell.SIZE.x / 2.0
		)
		cell.free()


## A full cart of 7 product columns, its coupons' group and copies (the narrowest column gap):
## each card's stacked copies stay in the gap before the next column, so the next card never
## covers them; the card draws over the next card (its count label whole) and its count never
## covers that card's rarity tab.
func test_copies_stay_in_the_column_gap() -> void:
	for window: Vector2 in WINDOWS:
		var screen: ShiftScreen = await _screen_at(window)
		screen.start_new_run(20261014, false)
		screen._week.skip()
		var run: RunState = screen.run
		for card: CardInstance in run.deck.cards.duplicate():
			run.deck.remove_card(card)
		var ids: Array[String] = LONG_PRODUCTS.duplicate()
		ids.append_array(["multipack", "two_for_one", "bread", "bread", "eggs_golden"])
		for id: String in ids:
			run.deck.add_card(load("res://data/cards/%s.tres" % id))
		screen._on_deck_button_pressed()
		var view: DeckView = screen._deck_view
		await get_tree().create_timer(0.4).timeout
		var cells: Array[DeckCell] = view.cells()
		assert_int(cells.size()).is_equal(14)
		var stacked: int = 0
		for cell: DeckCell in cells:
			if cell.copies < 2:
				continue
			stacked += 1
			var rect: Rect2 = cell.get_global_rect()
			var next: DeckCell = null
			for other: DeckCell in cells:
				var at: Rect2 = other.get_global_rect()
				if (
					is_equal_approx(at.position.y, rect.position.y)
					and at.position.x > rect.position.x
					and (next == null or at.position.x < next.get_global_rect().position.x)
				):
					next = other
			if next == null:
				continue
			var next_x: float = next.get_global_rect().position.x
			var message: String = "%s %s" % [window, cell.card.id]
			(
				assert_float(rect.end.x + cell.stack_reach())
				. override_failure_message(message)
				. is_less_equal(next_x)
			)
			var count: EffectSticker = cell.count_label()
			assert_int(cell.get_index()).override_failure_message(message).is_greater(
				next.get_index()
			)
			var tab: Rect2 = CartCardDraw.tab_rect(next.look)
			tab = Rect2(
				next.get_global_rect().position + tab.position * DeckCell.UNIT,
				tab.size * DeckCell.UNIT
			)
			var label: Rect2 = Rect2(count.global_position, count.size * count.scale)
			assert_bool(label.intersects(tab)).override_failure_message(message).is_false()
		assert_int(stacked).is_equal(2)
		view._close()
		await get_tree().process_frame


## A rule too long for its box is cut at a word with "…" at the smallest size, and the cut fits;
## a single word too wide is cut at a character, and fits too.
func test_a_rule_too_long_is_cut_to_fit() -> void:
	var balance: BalanceDefinition = load(BALANCE)
	var bread: CardDefinition = load("res://data/cards/bread.tres")
	var cell: DeckCell = DeckCell.new(CardInstance.new(bread, 0), balance.machine, 1)
	var box: Vector2 = cell.rule_rect().size
	cell.free()
	var long: String = "Next Breakfast item pays double its price, ".repeat(6).strip_edges()
	var word: String = "Supercalifragilistic".repeat(4)
	for text: String in [long, word]:
		var fit: Array = DeckCell.fit_rule(text, box.x, box.y)
		assert_int(fit[0]).is_equal(DeckCell.RULE_SIZES[-1])
		assert_bool(fit[2]).is_true()
		var shown: String = fit[1]
		assert_str(shown).ends_with(DeckCell.ELLIPSIS)
		assert_int(shown.length()).is_greater(1)
		var text_size: int = fit[0]
		var label: GlyphLabel = GlyphLabel.new(
			shown,
			DeckCell.rule_font(),
			text_size,
			Palette.INK,
			text_size + DeckCell.RULE_LEADING,
			box.x,
			0,
			false,
			null,
			true
		)
		assert_bool(label.fits()).override_failure_message(shown).is_true()
		assert_float(label.size.y).override_failure_message(shown).is_less_equal(box.y + 0.5)
		label.free()


## Every card's tip (and each keyword's box) shows its title whole beside its rarity tag, and a
## card's KEYWORD boxes are one per keyword of its rule.
func test_every_tip_title_fits() -> void:
	var balance: BalanceDefinition = load(BALANCE)
	var tip: CardTip = CardTip.new()
	add_child(tip)
	for file_name: String in DirAccess.get_files_at("res://data/cards"):
		if not file_name.ends_with(".tres"):
			continue
		var card: CardDefinition = load("res://data/cards/" + file_name)
		for stock: bool in [false, true]:
			if stock:
				tip.show_stock(card, balance.machine, 0)
			else:
				tip.show_card(card, balance.machine, "")
			var main: CardTip.CardTipBox = tip.main_card()
			assert_bool(main.title_fits()).override_failure_message(file_name).is_true()
			assert_str(main.tag_text()).is_equal(CardTip.tag_of(card, balance.machine))
			var keywords: PackedStringArray = GlyphText.keywords(
				DeckCell.rule_line(card), FamilyPalette.shared()
			)
			var titles: Array[String] = []
			for box: CardTip.CardTipBox in tip.keyword_cards():
				assert_bool(box.title_fits()).override_failure_message(file_name).is_true()
				titles.append(box.title_text())
			for keyword: String in keywords:
				assert_array(titles).override_failure_message(file_name).contains([keyword])
	tip.free()


## An art px rect at the cart card's UNIT.
static func _scaled(rect: Rect2) -> Rect2:
	return Rect2(rect.position * DeckCell.UNIT, rect.size * DeckCell.UNIT)


func _screen() -> ShiftScreen:
	var runner: GdUnitSceneRunner = scene_runner(SCREEN)
	var screen: ShiftScreen = runner.scene()
	for frame: int in range(2):
		await get_tree().process_frame
	return screen


## The real screen laid out at `window` (the run-start time card skipped).
func _screen_at(window: Vector2) -> ShiftScreen:
	var screen: ShiftScreen = await _screen()
	screen.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	screen.size = window
	screen._week.skip()
	for frame: int in range(3):
		await get_tree().process_frame
	return screen


## Every card of `cells` inside `area`, no two overlapping (their tabs included).
func _assert_cards_laid_out(cells: Array[DeckCell], area: Rect2, where: String) -> void:
	for index: int in cells.size():
		var rect: Rect2 = cells[index].get_global_rect()
		var tabbed: Rect2 = rect.grow_side(SIDE_TOP, DeckCell.TOP_ROOM)
		(
			assert_bool(area.encloses(tabbed))
			. override_failure_message("%s %s" % [where, cells[index].card.id])
			. is_true()
		)
		for other: int in range(index + 1, cells.size()):
			var next: Rect2 = cells[other].get_global_rect().grow_side(SIDE_TOP, DeckCell.TOP_ROOM)
			assert_bool(tabbed.intersects(next)).override_failure_message(where).is_false()


## `cell`'s rule shows whole inside its rule box at one of RULE_SIZES (or cut short with "…" at the
## smallest), its lines centred.
func _assert_rule_fits(cell: DeckCell, message: String) -> void:
	var label: GlyphLabel = cell.rule_label()
	assert_bool(label.fits()).override_failure_message(message).is_true()
	assert_int(cell.rule_size()).override_failure_message(message).is_greater_equal(
		DeckCell.RULE_SIZES[-1]
	)
	var box: Rect2 = cell.rule_rect().grow(0.5)
	var shown: Rect2 = Rect2(label.position, label.size)
	assert_bool(box.encloses(shown)).override_failure_message(message).is_true()
	if cell.rule_clipped():
		assert_str(cell.shown_rule()).override_failure_message(message).ends_with(DeckCell.ELLIPSIS)
		assert_int(cell.rule_size()).is_equal(DeckCell.RULE_SIZES[-1])


## The window the tips open in: the test's viewport inside the screen.
static func _stage(view: DeckView) -> Rect2:
	return view.get_viewport_rect().intersection(view.get_parent_control().get_global_rect())


## Whether the shown tip and its keyword boxes fit beside `item` (global) on one side inside
## _stage.
static func _has_room(view: DeckView, item: Rect2) -> bool:
	var stage: Rect2 = _stage(view)
	var tip: CardTip = view.tip()
	var room: float = tip.main_card().size.x + CardTip.GAP + CardTip.MARGIN
	if not tip.keyword_cards().is_empty():
		room += CardTip.KEYWORD_WIDTH + CardTip.KEYWORD_GAP
	if not stage.encloses(item):
		return false
	return item.end.x + room <= stage.end.x or item.position.x - room >= stage.position.x


## The shown tip's cards (the main one and its keyword boxes) sit inside the window, none over
## `item` (global) or over one another; the keyword boxes on the main card's far side; the
## tail's tip at the item's side, level with it.
func _assert_tip_beside(view: DeckView, item: Rect2, message: String) -> void:
	var tip: CardTip = view.tip()
	var rects: Array[Rect2] = tip.card_rects()
	for index: int in rects.size():
		var rect: Rect2 = rects[index]
		(
			assert_bool(_stage(view).grow(0.5).encloses(rect))
			. override_failure_message(message)
			. is_true()
		)
		assert_bool(rect.intersects(item)).override_failure_message(message).is_false()
		for other: int in range(index + 1, rects.size()):
			assert_bool(rect.intersects(rects[other])).override_failure_message(message).is_false()
	var main: Rect2 = rects[0]
	var right: bool = tip.side == CardTip.Placement.RIGHT
	assert_bool(main.position.x >= item.end.x if right else main.end.x <= item.position.x).is_true()
	for index: int in range(1, rects.size()):
		var box: Rect2 = rects[index]
		(
			assert_bool(box.position.x >= main.end.x if right else box.end.x <= main.position.x)
			. is_true()
		)
	var tail: Vector2 = tip.main_card().get_global_transform() * tip.main_card().tail_tip()
	assert_float(tail.x).override_failure_message(message).is_equal_approx(
		(
			main.position.x - CardTip.CardTipBox.TAIL_SIZE.y + CardTip.CardTipBox.TAIL_OVERLAP
			if right
			else main.end.x + CardTip.CardTipBox.TAIL_SIZE.y - CardTip.CardTipBox.TAIL_OVERLAP
		),
		0.5
	)
	assert_float(tail.y).override_failure_message(message).is_between(main.position.y, main.end.y)


static func _event_log() -> EventLogService:
	return Engine.get_main_loop().root.get_node("/root/EventLog")
