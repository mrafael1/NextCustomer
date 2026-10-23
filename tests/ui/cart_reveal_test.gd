extends GdUnitTestSuite
## The start-of-run cart reveal (v0.51, variant A of mock-up cart_reveal_v1.html): its timeline
## (the staples' padlocks, each pick leaving the dispenser and landing in its slot, the counts,
## SOLD OUT and the summary), the skip and the fold into the Cart button, reduced motion, and its
## on-screen geometry at the 1280x720 stage: everything inside the panel, no text past its box,
## no overlaps. The reveal is driven through its timeline (freeze_at, advance, tap): headless runs
## deliver no input events and no real time is waited.

const RECIPE := "res://data/decks/random_starter.tres"
const STARTER := "res://data/decks/starter.tres"
const BALANCE := "res://data/balance/balance.tres"
const DECKS := "res://data/decks"
## The screen capture's seed: its deal holds a 2nd Milk and a 2nd Eggs (staples' 2nd copies).
const SEED := 20261014

var _host: Control
var _cart: Control
var _finished: int = 0


func before_test() -> void:
	_finished = 0
	_host = auto_free(Control.new())
	_host.size = ShiftStage.SIZE
	add_child(_host)
	# The Cart button stands in the top bar's place (mock-up: 1078, 10, 128, 36).
	_cart = Control.new()
	_cart.position = Vector2(1078, 10)
	_cart.size = Vector2(128, 36)
	_host.add_child(_cart)


func test_it_shows_the_dealt_deck_as_staples_and_picks() -> void:
	var run: RunState = _run(SEED)
	var reveal: CartReveal = _reveal(run)
	var panel: RevealPanel = reveal.panel()
	assert_array(panel.staples).is_equal(run.starter.core_cards)
	assert_array(panel.picks).is_equal(StartingDeck.picks(run.starter))
	assert_int(panel.staple_tiles.size()).is_equal(4)
	assert_int(panel.pick_tiles.size()).is_equal(9)
	for tile: RevealTile in panel.staple_tiles:
		assert_int(tile.kind).is_equal(RevealTile.Kind.STAPLE)
		assert_object(tile.lock_badge).is_not_null()
	var coupon: RevealTile = panel.pick_tiles[0]
	assert_int(coupon.kind).is_equal(RevealTile.Kind.COUPON)
	assert_object(coupon.tab).is_not_null()
	assert_str(coupon.tab.text_label().text).is_equal("COUPON")
	var seconds: Array[String] = []
	for tile: RevealTile in panel.pick_tiles.slice(1):
		assert_int(tile.kind).is_equal(RevealTile.Kind.PICK)
		assert_object(tile.spark_badge).is_not_null()
		if tile.dup_badge != null:
			assert_str(tile.dup_badge.text_label().text).is_equal("×2")
			seconds.append(String(tile.card.id))
	# A pick that repeats a staple carries the padlock ×2.
	assert_array(seconds).contains_exactly(["milk", "eggs"])
	# The coupon's slot is tomato, the products' teal.
	assert_bool(panel.slots[0].color == Palette.TOMATO).is_true()
	assert_bool(panel.slots[1].color == Palette.TEAL_SHADE).is_true()


func test_the_picks_drop_out_one_by_one_and_end_sold_out() -> void:
	var reveal: CartReveal = _reveal(_run(SEED))
	var panel: RevealPanel = reveal.panel()
	var timing: CartRevealTuning = reveal.tuning
	reveal.freeze_at(0.0)
	assert_str(panel.dispenser.led_text()).is_equal("8 PICKS + 1 COUPON")
	assert_int(panel.dispenser.heap_left()).is_equal(9)
	assert_str(panel.picks_count.text).is_equal("0/9")
	assert_str(panel.chip.text_label().text).is_equal("CART 4/15")
	for index: int in 9:
		assert_bool(panel.pick_tiles[index].visible).is_false()
		assert_bool(panel.slots[index].visible).is_true()
	for index: int in 9:
		# Just out of the chute: its art flies, its slot still waits.
		var flying: float = timing.pick_start(index) + timing.exit_s / 2.0
		reveal.freeze_at(flying)
		assert_bool(panel.flyer_of(index).visible).is_true()
		assert_bool(panel.pick_tiles[index].visible).is_false()
		assert_str(panel.dispenser.led_text()).is_equal("DISPENSING %d/9" % (index + 1))
		assert_int(panel.dispenser.heap_left()).is_equal(8 - index)
		# Landed: the tile covers the slot, flashing; the counts go up.
		reveal.freeze_at(timing.pick_land(index))
		assert_bool(panel.pick_tiles[index].visible).is_true()
		assert_bool(panel.slots[index].visible).is_false()
		assert_bool(panel.flyer_of(index).visible).is_false()
		assert_float(panel.pick_tiles[index].flash_strength()).is_greater(0.5)
		assert_str(panel.picks_count.text).is_equal("%d/9" % (index + 1))
		assert_str(panel.chip.text_label().text).is_equal("CART %d/15" % (5 + index))
	reveal.freeze_at(reveal.end_time())
	assert_bool(panel.dispenser.is_sold_out()).is_true()
	assert_str(panel.dispenser.led_text()).is_equal("CART READY ✓")
	assert_float(panel.summary.modulate.a).is_equal_approx(1.0, 0.001)
	assert_float(panel.chip.modulate.a).is_equal_approx(0.0, 0.001)
	assert_str(panel.hint.text).is_equal("TAP TO START SHIFT 1 ›")
	assert_array(_summary_texts(panel)).is_equal(
		["CART 13/15", "=", "4 staples", "+", "1 coupon", "+", "8 from today’s stock"]
	)
	# About 3 s from the panel to the summary.
	assert_float(reveal.end_time()).is_between(2.6, 3.4)


func test_a_tap_skips_to_the_summary_then_folds_into_the_cart() -> void:
	var reveal: CartReveal = _reveal(_run(SEED))
	reveal.advance(0.5)
	reveal.tap()
	assert_float(reveal.time()).is_equal_approx(reveal.end_time(), 0.001)
	assert_bool(reveal.panel().pick_tiles[8].visible).is_true()
	assert_bool(reveal.is_folding()).is_false()
	reveal.tap()
	assert_bool(reveal.is_folding()).is_true()
	reveal.advance(reveal.tuning.fold_s)
	# Folded into the Cart button: shrunk and faded, the ring flashing round the button.
	assert_float(reveal.panel().scale.x).is_less(0.2)
	assert_float(reveal.panel().modulate.a).is_less(0.05)
	assert_int(_finished).is_equal(0)
	reveal.advance(reveal.tuning.outro_s)
	assert_bool(reveal.is_open()).is_false()
	assert_object(reveal.panel()).is_null()
	assert_int(_finished).is_equal(1)


func test_space_enter_and_a_click_tap() -> void:
	var reveal: CartReveal = _reveal(_run(SEED))
	var space: InputEventKey = InputEventKey.new()
	space.keycode = KEY_SPACE
	space.pressed = true
	reveal._input(space)
	assert_float(reveal.time()).is_equal_approx(reveal.end_time(), 0.001)
	var click: InputEventMouseButton = InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	reveal._gui_input(click)
	assert_bool(reveal.is_folding()).is_true()
	# It takes every click while open.
	assert_int(reveal.mouse_filter).is_equal(Control.MOUSE_FILTER_STOP)


func test_reduced_motion_opens_on_the_summary_and_closes_at_the_tap() -> void:
	var reveal: CartReveal = _reveal(_run(SEED), true)
	assert_float(reveal.time()).is_equal_approx(reveal.end_time(), 0.001)
	assert_bool(reveal.panel().dispenser.is_sold_out()).is_true()
	reveal.tap()
	assert_bool(reveal.is_open()).is_false()
	assert_int(_finished).is_equal(1)


func test_a_fixed_deck_shows_nothing() -> void:
	var balance: BalanceDefinition = load(BALANCE)
	var run: RunState = RunState.new(5, load(STARTER), balance, RunStock.starting(balance))
	var reveal: CartReveal = CartReveal.new()
	_host.add_child(reveal)
	assert_bool(reveal.play(run, _cart, false)).is_false()
	assert_bool(reveal.is_open()).is_false()


## UI geometry at the end (every tile, badge, text and the dispenser shown) and mid-way, over
## several deals: inside the panel, inside the stage, no text past its box, no overlaps.
func test_the_layout_fits_the_panel_with_no_overlaps() -> void:
	for seed_value: int in [SEED, 1, 2, 3, 4]:
		var reveal: CartReveal = _reveal(_run(seed_value))
		var panel: RevealPanel = reveal.panel()
		reveal.freeze_at(reveal.end_time())
		await get_tree().process_frame
		var where: String = "seed %d" % seed_value
		var stage: Rect2 = Rect2(Vector2.ZERO, ShiftStage.SIZE)
		var box: Rect2 = panel.get_global_rect()
		(
			assert_bool(stage.encloses(box.grow(RevealPanel.RIM + 2.0)))
			. override_failure_message(where)
			. is_true()
		)
		# The panel starts under the top bar.
		assert_float(box.position.y).is_greater_equal(ShiftStage.TOP_BAR_BOTTOM)
		var tiles: Array[Control] = []
		tiles.append_array(panel.staple_tiles)
		tiles.append_array(panel.pick_tiles)
		for tile: Control in tiles:
			assert_bool(box.encloses(_outer(tile))).override_failure_message(where).is_true()
			for chip: Node in tile.find_children("*", "RevealChip", true, false):
				var badge: RevealChip = chip as RevealChip
				var badge_rect: Rect2 = badge.get_global_rect().grow(RevealChip.OUTLINE)
				assert_bool(box.encloses(badge_rect)).override_failure_message(where).is_true()
		_assert_apart(tiles, where)
		# The summary sits under the picks, inside the panel, centred on it.
		var line: Rect2 = _content_rect(panel.summary)
		assert_bool(box.encloses(line)).override_failure_message(where).is_true()
		for tile: Control in panel.pick_tiles:
			assert_bool(line.intersects(_outer(tile))).override_failure_message(where).is_false()
		var centre: float = box.get_center().x
		assert_float(line.get_center().x).is_between(centre - 4.0, centre + 4.0)
		# The dispenser: inside the panel, clear of the staples, the CART chip and the slots.
		var origin: Vector2 = panel.global_position - RevealPanel.RECT.position
		# From the top bulbs to the chute's ring, the marquee's width.
		var top: float = StockDispenser.BULB_TOP_Y - 1.0
		var bottom: float = StockDispenser.CHUTE_RECT.end.y + StockDispenser.RING + 2.0
		var cabinet: Rect2 = Rect2(
			origin + Vector2(StockDispenser.MARQUEE_RECT.position.x - 2.0, top),
			Vector2(StockDispenser.MARQUEE_RECT.size.x + 4.0, bottom - top)
		)
		assert_bool(box.encloses(cabinet)).override_failure_message(where).is_true()
		for tile: Control in tiles:
			assert_bool(cabinet.intersects(_outer(tile))).override_failure_message(where).is_false()
		var chip_rect: Rect2 = _chip_rect(panel.chip)
		assert_bool(chip_rect.intersects(cabinet)).override_failure_message(where).is_false()
		for slot: RevealSlot in panel.slots:
			assert_bool(chip_rect.intersects(slot.get_global_rect())).is_false()
		# SOLD OUT sits on the window.
		var window: Rect2 = Rect2(
			StockDispenser.WINDOW_RECT.position + origin, StockDispenser.WINDOW_RECT.size
		)
		var stamp: Rect2 = panel.dispenser.sold_out_rect()
		stamp.position += origin
		assert_bool(window.encloses(stamp)).override_failure_message(where).is_true()
		# Every text fits its box, inside the panel; the heading counts follow their headings.
		for found: Node in panel.find_children("*", "Label", true, false):
			var label: Label = found as Label
			# A wrapped name printed on a coupon's slip is the item art's (ItemView).
			var wrapped: bool = label.autowrap_mode != TextServer.AUTOWRAP_OFF
			if not label.is_visible_in_tree() or label.text.is_empty() or wrapped:
				continue
			var what: String = "%s: %s" % [where, label.text]
			var rect: Rect2 = label.get_global_rect()
			assert_float(_text_width(label)).override_failure_message(what).is_less_equal(
				rect.size.x + 0.5
			)
			assert_bool(box.encloses(rect)).override_failure_message(what).is_true()
		for heading: Label in [panel.staples_heading, panel.picks_heading]:
			var count: Label = heading.get_parent().get_child(1)
			var heading_end: float = heading.get_global_rect().end.x
			assert_float(count.get_global_rect().position.x).is_greater_equal(heading_end + 13.0)
		reveal.close()


## Every recipe deck in data/decks fits the panel's layout (its tray and its slot row): a recipe
## with more core cards or dealt cards needs the layout reworked, not tiles past the panel.
func test_every_recipe_fits_the_layout() -> void:
	for file_name: String in DirAccess.get_files_at(DECKS):
		if not file_name.ends_with(".tres"):
			continue
		var deck: DeckDefinition = load(DECKS.path_join(file_name))
		if not deck.is_recipe():
			continue
		var message: String = (
			"%s needs %d staple tiles and %d pick slots; the cart reveal holds %d and %d"
			% [
				file_name,
				deck.core_cards.size(),
				deck.random_count + deck.random_coupon_count,
				RevealPanel.MAX_STAPLES,
				RevealPanel.MAX_PICKS,
			]
		)
		assert_bool(RevealPanel.fits(deck)).override_failure_message(message).is_true()


## Every card a deal can show (every coupon of the pool, every product with an item-tier chain),
## as a pick and as a staple's 2nd copy: its name fits under its art (or its slip's wrapped name
## stays on the slip, inside the tile) and its badges stay in the tile's badge margin.
func test_every_drawable_card_fits_its_tile() -> void:
	var balance: BalanceDefinition = load(BALANCE)
	var cards: Array[CardDefinition] = balance.coupon_pool.duplicate()
	for chain: ItemUpgradeDefinition in balance.machine.item_upgrades:
		if not cards.has(chain.product):
			cards.append(chain.product)
	assert_array(cards).is_not_empty()
	var tiles: Array[RevealTile] = []
	for card: CardDefinition in cards:
		var kind: RevealTile.Kind = (
			RevealTile.Kind.COUPON if card.is_coupon() else RevealTile.Kind.PICK
		)
		for second: bool in [false, true]:
			var tile: RevealTile = RevealTile.new(card, kind, second and card.is_product())
			tile.position = Vector2(400, 300)
			_host.add_child(tile)
			tiles.append(tile)
	await get_tree().process_frame
	for tile: RevealTile in tiles:
		var what: String = tile.card.display_name
		var box: Rect2 = tile.get_global_rect()
		for found: Node in tile.find_children("*", "Label", true, false):
			var label: Label = found as Label
			# A badge's text grows its chip (checked below with the badges).
			var in_chip: bool = label.get_parent() is RevealChip
			if not label.is_visible_in_tree() or label.text.is_empty() or in_chip:
				continue
			var rect: Rect2 = label.get_global_rect()
			if label.autowrap_mode == TextServer.AUTOWRAP_OFF:
				# The name's line (its box may run under the tile's edge; its glyphs don't).
				var line: Rect2 = Rect2(
					rect.position, Vector2(rect.size.x, label.get_line_height())
				)
				assert_bool(box.encloses(line)).override_failure_message(what).is_true()
				assert_float(_text_width(label)).override_failure_message(what).is_less_equal(
					rect.size.x + 0.5
				)
			else:
				var lines: int = label.get_line_count()
				var spacing: int = label.get_theme_constant("line_spacing")
				var height: float = lines * label.get_line_height() + (lines - 1) * spacing
				assert_bool(box.encloses(rect)).override_failure_message(what).is_true()
				assert_float(height).override_failure_message(what).is_less_equal(rect.size.y + 0.5)
				# Each word fits a line: none is cut at the slip's sides.
				for word: String in label.text.split(" ", false):
					var font: Font = label.get_theme_font("font")
					var font_size: int = label.get_theme_font_size("font_size")
					var width: float = (
						font.get_string_size(word, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
					)
					assert_float(width).override_failure_message(what).is_less_equal(rect.size.x)
		# The corner badges overhang the tile by design (the padlock, the "+", the COUPON tab).
		var margin: Rect2 = box.grow_individual(
			-RevealTile.LOCK_RECT.position.x,
			-RevealTile.TAB_RECT.position.y,
			RevealTile.SPARK_RECT.end.x - RevealTile.SIZE.x,
			0.0
		)
		for chip: Node in tile.find_children("*", "RevealChip", true, false):
			var badge: Rect2 = (chip as RevealChip).get_global_rect().grow(RevealChip.OUTLINE)
			(
				assert_bool(margin.grow(RevealChip.OUTLINE).encloses(badge))
				. override_failure_message(what)
				. is_true()
			)


## A coupon in the dispenser's heap sits whole inside the glass (its slip prints its name).
func test_a_coupon_sits_whole_in_the_dispensers_glass() -> void:
	var balance: BalanceDefinition = load(BALANCE)
	var picks: Array[CardDefinition] = [balance.coupon_pool[0]]
	for _index: int in RevealPanel.MAX_PICKS - 1:
		picks.append(balance.staples[0])
	var dispenser: StockDispenser = StockDispenser.new(picks)
	_host.add_child(dispenser)
	var glass: Rect2 = Rect2(Vector2.ZERO, StockDispenser.WINDOW_RECT.size)
	for art: TextureRect in dispenser.heap_art():
		if art.get_child_count() > 0:  # The coupon's slip carries its printed name or icon.
			assert_bool(glass.encloses(Rect2(art.position, art.size))).is_true()
	(
		assert_bool(
			dispenser.heap_art().any(
				func(art: TextureRect) -> bool: return art.get_child_count() > 0
			)
		)
		. is_true()
	)


## Mid-way (picks in flight, the cabinet jolting): the flyers stay inside the panel.
func test_the_flyers_stay_inside_the_panel() -> void:
	var reveal: CartReveal = _reveal(_run(SEED))
	var panel: RevealPanel = reveal.panel()
	var box: Rect2 = panel.get_global_rect()
	var t: float = 0.0
	while t < reveal.end_time():
		reveal.freeze_at(t)
		for index: int in panel.picks.size():
			var flyer: TextureRect = panel.flyer_of(index)
			if flyer.visible:
				var rect: Rect2 = flyer.get_global_rect()
				assert_bool(box.encloses(rect)).override_failure_message("t %.2f" % t).is_true()
		t += 1.0 / 30.0


func _run(seed_value: int) -> RunState:
	var balance: BalanceDefinition = load(BALANCE)
	var stock: RunStock = RunStock.starting(balance)
	var stream: RandomNumberGenerator = EventLogService.derived_stream(
		seed_value, EventLogService.STARTING_DECK_STREAM
	)
	var deck: DeckDefinition = StartingDeck.deal(load(RECIPE), stock, balance, stream)
	var run: RunState = RunState.new(seed_value, deck, balance, stock)
	run.start_shift()
	return run


func _reveal(run: RunState, reduced: bool = false) -> CartReveal:
	var reveal: CartReveal = CartReveal.new()
	_host.add_child(reveal)
	reveal.finished.connect(func() -> void: _finished += 1)
	assert_bool(reveal.play(run, _cart, reduced)).is_true()
	# Driven by hand only.
	reveal.set_process(false)
	return reveal


## A tile's rect with its 2 px ink outline.
static func _outer(tile: Control) -> Rect2:
	return tile.get_global_rect().grow(2.0)


static func _chip_rect(chip: RevealChip) -> Rect2:
	var rect: Rect2 = chip.get_global_rect().grow(RevealChip.OUTLINE)
	rect.size.y += RevealChip.LEDGE
	return rect


## The summary's content (its parts, not its full-width box).
static func _content_rect(line: HBoxContainer) -> Rect2:
	var rect: Rect2 = Rect2()
	for child: Control in line.get_children():
		var part: Rect2 = child.get_global_rect()
		rect = part if not rect.has_area() else rect.merge(part)
	return rect


func _assert_apart(controls: Array[Control], where: String) -> void:
	for first: int in controls.size():
		for second: int in range(first + 1, controls.size()):
			var a: Rect2 = controls[first].get_global_rect()
			var b: Rect2 = controls[second].get_global_rect()
			assert_bool(a.intersects(b)).override_failure_message(where).is_false()


static func _text_width(label: Label) -> float:
	var font: Font = label.get_theme_font("font")
	var font_size: int = label.get_theme_font_size("font_size")
	return font.get_string_size(label.text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x


static func _summary_texts(panel: RevealPanel) -> Array[String]:
	var texts: Array[String] = []
	for found: Node in panel.summary.find_children("*", "Label", true, false):
		texts.append((found as Label).text)
	return texts
