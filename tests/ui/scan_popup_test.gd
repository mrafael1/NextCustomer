extends GdUnitTestSuite
## The scan popup (#75): every card in data/cards, with the worst footer a belt item can carry,
## keeps its text inside the popup, its rule text whole and its height within MAX_HEIGHT (the
## footer lines that don't fit fold into "+N more"), and opens inside the 1280x720 stage, off the
## hovered item's sprite and sticker (and chips), wherever the item is: each belt cell and each
## hand position of style frame v2's geometry, which the shift screen takes on in #75. A belt
## item's popup flips below its chips; a hand item's opens beside it over the tray, never over the
## belt. It is placed from global rects, so an item in a scaled row is pointed at where it is
## drawn.

const CARDS := "res://data/cards"
const BALANCE := "res://data/balance/balance.tres"
const STAGE := Rect2(0, 0, 1280, 720)
## Style frame v2's stage (the layout the shift screen adopts in #75): the belt, its cells, the
## counter line, the top bar's foot and the tray with its cells.
const BELT_RECT := Rect2(16, 68, 896, 254)
const CELL_ORIGIN := Vector2(32, 76)
const CELL_PITCH := 124.0
const CELL_COUNT := 7
const COUNTER_TOP := 322.0
const TOP_BAR_BOTTOM := 64.0
const TRAY_RECT := Rect2(12, 410, 916, 184)
const TRAY_CELL_ORIGIN := Vector2(22, 416)
const TRAY_PITCH := 112.0
const TRAY_COUNT := 8
## In a cell: the lifted sprite, and the sticker with the chips under it.
const BELT_SPRITE := Rect2(12, 22, 96, 96)
const BELT_BELOW := Rect2(2, 130, 116, 108)
const TRAY_SPRITE := Rect2(6, 0, 96, 96)
const TRAY_BELOW := Rect2(0, 104, 108, 64)
## More step lines than any belt item carries, every other one a fizzle whose reason wraps.
const WORST_FOOTER_LINES := 12
const LONG_LINE := "Coupon engine: needs a coupon two slots earlier and finds none there"
const SHORT_LINE := "×3 Multipack"


func test_every_card_with_the_worst_footer_fits_the_stage() -> void:
	var popup: ScanPopup = _popup()
	var balance: BalanceDefinition = load(BALANCE) as BalanceDefinition
	var layout: ScanLayout = _layout()
	var lines: PackedStringArray = PackedStringArray()
	var fizzles: Array[bool] = []
	for index: int in range(WORST_FOOTER_LINES):
		lines.append(LONG_LINE if index % 2 == 0 else SHORT_LINE)
		fizzles.append(index % 2 == 0)
	var cards: Array[CardDefinition] = _cards()
	assert_int(cards.size()).is_equal(59)
	for definition: CardDefinition in cards:
		var aisle: AisleDefinition = balance.aisle_of(definition)
		for on_belt: bool in [false, true]:
			var payout: int = definition.base if on_belt else -1
			var footer: PackedStringArray = lines if on_belt else PackedStringArray()
			var footer_fizzles: Array[bool] = fizzles if on_belt else ([] as Array[bool])
			popup.show_card(definition, aisle, definition.tags, payout, footer, footer_fizzles)
			await get_tree().process_frame
			var message: String = "%s (%s)" % [definition.id, "belt" if on_belt else "hand"]
			_assert_holds_its_text(popup, definition, message)
			if on_belt:
				_assert_folded(popup, payout, message)
			for index: int in range(CELL_COUNT if on_belt else TRAY_COUNT):
				var sprite: Rect2 = _sprite(on_belt, index)
				var below: Rect2 = _below(on_belt, index)
				popup.place_at(sprite, below, layout)
				_assert_placed(popup, sprite, below, on_belt, "%s at %d" % [message, index])


## A footer that fits shows every line; one too long for MAX_HEIGHT folds the rest into its last
## line, "+N more", with N the lines not shown.
func test_the_footer_folds_what_does_not_fit() -> void:
	var popup: ScanPopup = _popup()
	var milk: CardDefinition = load("%s/milk.tres" % CARDS) as CardDefinition
	var two: PackedStringArray = PackedStringArray([SHORT_LINE, "+15 Category engine"])
	popup.show_card(milk, null, milk.tags, 4, two, [false, false] as Array[bool])
	var expected: PackedStringArray = PackedStringArray(["Pays €4"])
	expected.append_array(two)
	(
		assert_bool(popup.footer_texts() == expected)
		. override_failure_message(str(popup.footer_texts()))
		. is_true()
	)
	var many: PackedStringArray = PackedStringArray()
	var fizzles: Array[bool] = []
	for index: int in range(20):
		many.append("+%d Line %d" % [index, index])
		fizzles.append(false)
	popup.show_card(milk, null, milk.tags, 4, many, fizzles)
	var shown: PackedStringArray = popup.footer_texts()
	var last: String = shown[shown.size() - 1]
	var folded: int = many.size() - (shown.size() - 2)
	assert_int(folded).is_greater(1)
	assert_str(last).is_equal(ScanPopup.MORE_TEXT % folded)
	for index: int in range(1, shown.size() - 1):
		assert_str(shown[index]).is_equal(many[index - 1])
	# Folded: the next footer row would have passed the cap.
	assert_float(popup.size.y).is_less_equal(ScanPopup.MAX_HEIGHT)
	assert_float(popup.size.y).is_greater(ScanPopup.MAX_HEIGHT - 2.0 * ScanPopup.PADDING)
	_assert_holds_its_text(popup, milk, "milk")
	await get_tree().process_frame


## The tag line shows the tags passed in (on the belt the scored ones, a granted tag included),
## then a product's aisle or Staple, never twice (Batteries' Household tag in the Household
## aisle); a coupon's shows only its tags.
## A step line's amount (or "fizzle") sits at the popup's right edge on its text's last row, clear
## of the text, as on the receipt: a short line keeps one row, a long one wraps its text only.
func test_a_step_lines_amount_sits_on_its_last_row_at_the_right() -> void:
	var popup: ScanPopup = _popup()
	var milk: CardDefinition = load("%s/milk.tres" % CARDS) as CardDefinition
	var lines: PackedStringArray = PackedStringArray(
		[
			ReceiptView.joined_line(SHORT_LINE, "+8"),
			ReceiptView.joined_line(LONG_LINE, "fizzle"),
		]
	)
	popup.show_card(milk, null, milk.tags, 4, lines, [false, true] as Array[bool])
	var expected: PackedStringArray = PackedStringArray(["Pays €4"])
	expected.append_array(lines)
	assert_bool(popup.footer_texts() == expected).is_true()
	var labels: Dictionary[String, Label] = {}
	for label: Label in popup.text_labels():
		labels[label.text] = label
	var right_edge: float = ScanPopup.PADDING + ScanPopup.CONTENT_WIDTH
	for pair: Array in [[SHORT_LINE, "+8", 1], [LONG_LINE, "fizzle", 2]]:
		var text: Label = labels[pair[0]]
		var amount: Label = labels[pair[1]]
		assert_int(text.get_line_count()).is_equal(pair[2])
		assert_float(amount.position.x + amount.size.x).is_equal_approx(right_edge, 0.01)
		assert_float(amount.position.y + amount.size.y).is_equal_approx(text.get_rect().end.y, 0.01)
		var drawn: float = amount.position.x + amount.size.x - amount.get_minimum_size().x
		assert_float(text.get_rect().end.x).is_less(drawn)
	_assert_holds_its_text(popup, milk, "milk")
	await get_tree().process_frame


func test_the_tag_line_shows_the_given_tags() -> void:
	var balance: BalanceDefinition = load(BALANCE) as BalanceDefinition
	var milk: CardDefinition = load("%s/milk.tres" % CARDS) as CardDefinition
	var granted: PackedStringArray = milk.tags.duplicate()
	granted.append("Clearance")
	var aisle: AisleDefinition = balance.aisle_of(milk)
	var expected: PackedStringArray = granted.duplicate()
	expected.append(aisle.display_name if aisle != null else ScanPopup.STAPLE)
	assert_str(ScanPopup.tag_line(granted, milk, aisle)).is_equal(
		ScanPopup.TAG_SEPARATOR.join(expected)
	)
	var bread: CardDefinition = load("%s/bread.tres" % CARDS) as CardDefinition
	assert_str(ScanPopup.tag_line(PackedStringArray(), bread, null)).is_equal(ScanPopup.STAPLE)
	var batteries: CardDefinition = load("%s/batteries.tres" % CARDS) as CardDefinition
	var household: AisleDefinition = balance.aisle_of(batteries)
	assert_str(household.display_name).is_equal("Household")
	assert_bool(batteries.tags.has("Household")).is_true()
	assert_str(ScanPopup.tag_line(batteries.tags, batteries, household)).is_equal(
		ScanPopup.TAG_SEPARATOR.join(batteries.tags)
	)
	var coupon: CardDefinition = load("%s/multipack.tres" % CARDS) as CardDefinition
	assert_str(ScanPopup.tag_line(PackedStringArray(["Food"]), coupon, null)).is_equal("Food")
	var popup: ScanPopup = _popup()
	popup.show_card(milk, aisle, granted, -1, PackedStringArray(), [] as Array[bool])
	var texts: Array[String] = []
	for label: Label in popup.text_labels():
		texts.append(label.text)
	assert_array(texts).contains([ScanPopup.tag_line(granted, milk, aisle)])


## An item in a scaled, moved row (RowStrip shrinks 8 and 9 slots) is pointed at where it is
## drawn: place_at takes global rects and the popup sits in its own, unscaled layer.
func test_a_scaled_row_is_placed_from_global_rects() -> void:
	var row: Control = auto_free(Control.new())
	row.position = Vector2(40, 10)
	row.scale = Vector2(0.8, 0.8)
	add_child(row)
	var sprite: Control = Control.new()
	sprite.position = CELL_ORIGIN + BELT_SPRITE.position + Vector2(3 * CELL_PITCH, 0)
	sprite.size = BELT_SPRITE.size
	row.add_child(sprite)
	var layer: Control = auto_free(Control.new())
	layer.position = Vector2(5, 7)
	add_child(layer)
	var popup: ScanPopup = ScanPopup.new()
	layer.add_child(popup)
	var cheese: CardDefinition = load("%s/cheese.tres" % CARDS) as CardDefinition
	popup.show_card(cheese, null, cheese.tags, 5, PackedStringArray(), [] as Array[bool])
	var global_sprite: Rect2 = sprite.get_global_rect()
	var below: Rect2 = Rect2(global_sprite.position + Vector2(0, 110), Vector2(96, 90))
	var layout: ScanLayout = _layout().transformed(Transform2D(0.0, Vector2(5, 7)))
	popup.place_at(global_sprite, below, layout)
	var tip: Vector2 = layer.get_global_transform() * popup.tail_tip()
	assert_float(tip.x).is_equal_approx(global_sprite.get_center().x, 0.01)
	assert_int(popup.placement).is_equal(ScanPopup.Placement.BELOW)
	var rect: Rect2 = popup.get_global_rect()
	assert_float(rect.position.y).is_equal_approx(below.end.y + ScanPopup.FLIP_GAP, 0.01)
	assert_bool(layout.stage.encloses(rect)).override_failure_message(str(rect)).is_true()


func _popup() -> ScanPopup:
	var popup: ScanPopup = auto_free(ScanPopup.new())
	add_child(popup)
	return popup


## Every label inside the popup; the rule text whole (no line hidden) and verbatim; the name the
## card's; the height within MIN_HEIGHT and MAX_HEIGHT.
func _assert_holds_its_text(popup: ScanPopup, definition: CardDefinition, message: String) -> void:
	var rect: Rect2 = Rect2(Vector2.ZERO, popup.size)
	for label: Label in popup.text_labels():
		var inner: Rect2 = popup.get_global_transform().affine_inverse() * label.get_global_rect()
		(
			assert_bool(rect.encloses(inner))
			. override_failure_message(
				"%s: '%s' %s outside %s" % [message, label.text, inner, rect]
			)
			. is_true()
		)
	var rule: Label = popup.rule_label()
	assert_str(rule.text).override_failure_message(message).is_equal(definition.rule_text)
	assert_int(rule.get_visible_line_count()).override_failure_message(message).is_equal(
		rule.get_line_count()
	)
	assert_str(popup.name_label().text).is_equal(definition.display_name)
	assert_float(popup.size.y).override_failure_message(message).is_between(
		ScanPopup.MIN_HEIGHT, ScanPopup.MAX_HEIGHT
	)


## The worst footer: "Pays €N" first, then the lines that fit in order, then "+N more" for the
## rest.
func _assert_folded(popup: ScanPopup, payout: int, message: String) -> void:
	var shown: PackedStringArray = popup.footer_texts()
	assert_str(shown[0]).override_failure_message(message).is_equal(ScanPopup.PAYS_TEXT % payout)
	var steps: int = shown.size() - 2
	assert_int(steps).override_failure_message(message).is_greater_equal(1)
	for index: int in range(steps):
		var expected: String = LONG_LINE if index % 2 == 0 else SHORT_LINE
		assert_str(shown[index + 1]).override_failure_message(message).is_equal(expected)
	assert_str(shown[shown.size() - 1]).override_failure_message(message).is_equal(
		ScanPopup.MORE_TEXT % (WORST_FOOTER_LINES - steps)
	)


## Inside the stage, under the top bar, off the item's sprite and sticker (and chips); a belt
## item's below its chips, a hand item's beside it over the tray and never over the belt; the
## tail's tip at the sprite's middle, on the popup's edge facing it.
func _assert_placed(
	popup: ScanPopup, sprite: Rect2, below: Rect2, on_belt: bool, message: String
) -> void:
	var rect: Rect2 = popup.get_global_rect()
	message += ": %s" % rect
	assert_bool(STAGE.encloses(rect)).override_failure_message(message).is_true()
	assert_float(rect.position.y).override_failure_message(message).is_greater_equal(TOP_BAR_BOTTOM)
	assert_bool(rect.intersects(sprite)).override_failure_message(message).is_false()
	assert_bool(rect.intersects(below)).override_failure_message(message).is_false()
	var tail: Rect2 = popup.tail().get_global_rect()
	assert_bool(tail.intersects(sprite)).override_failure_message(message).is_false()
	if on_belt:
		assert_int(popup.placement).override_failure_message(message).is_equal(
			ScanPopup.Placement.BELOW
		)
		assert_float(popup.tail_tip().x).override_failure_message(message).is_equal(
			sprite.get_center().x
		)
		return
	assert_bool(popup.placement in [ScanPopup.Placement.RIGHT, ScanPopup.Placement.LEFT]).is_true()
	assert_bool(rect.intersects(BELT_RECT)).override_failure_message(message).is_false()
	assert_float(rect.position.y).override_failure_message(message).is_greater_equal(COUNTER_TOP)
	assert_float(rect.position.x).override_failure_message(message).is_greater_equal(
		TRAY_RECT.position.x
	)
	assert_float(rect.end.x).override_failure_message(message).is_less_equal(TRAY_RECT.end.x)
	assert_float(popup.tail_tip().y).override_failure_message(message).is_equal(
		sprite.get_center().y
	)


static func _layout() -> ScanLayout:
	return ScanLayout.new(STAGE, TRAY_RECT, COUNTER_TOP, TOP_BAR_BOTTOM)


static func _sprite(on_belt: bool, index: int) -> Rect2:
	if on_belt:
		return Rect2(_cell(index) + BELT_SPRITE.position, BELT_SPRITE.size)
	return Rect2(_tray_cell(index) + TRAY_SPRITE.position, TRAY_SPRITE.size)


static func _below(on_belt: bool, index: int) -> Rect2:
	if on_belt:
		return Rect2(_cell(index) + BELT_BELOW.position, BELT_BELOW.size)
	return Rect2(_tray_cell(index) + TRAY_BELOW.position, TRAY_BELOW.size)


static func _cell(index: int) -> Vector2:
	return CELL_ORIGIN + Vector2(index * CELL_PITCH, 0)


static func _tray_cell(index: int) -> Vector2:
	return TRAY_CELL_ORIGIN + Vector2(index * TRAY_PITCH, 0)


static func _cards() -> Array[CardDefinition]:
	var cards: Array[CardDefinition] = []
	for file: String in DirAccess.get_files_at(CARDS):
		if file.ends_with(".tres"):
			cards.append(load("%s/%s" % [CARDS, file]) as CardDefinition)
	return cards
