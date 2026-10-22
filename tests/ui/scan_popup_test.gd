extends GdUnitTestSuite
## The scan popup (#75; offers only since #80): every card in data/cards keeps its text inside
## the popup, its rule text whole and its height within MAX_HEIGHT, and opens inside the 1280x720
## stage, beside the scanned item over the offers' panel, off the item's sprite and sticker, with
## its tail at the sprite's middle, wherever the item stands in the panel. It is placed from
## global rects, so an item in a scaled panel is pointed at where it is drawn.

const LiveCardCount := preload("res://tests/data/live_card_count.gd")
const CARDS := "res://data/cards"
const BALANCE := "res://data/balance/balance.tres"
const STAGE := Rect2(0, 0, 1280, 720)
## A panel holding a row of tray cells (ItemView's TRAY form, the old offer panel's pitch).
const PANEL_RECT := Rect2(0, 494, 944, 226)
const PANEL_CELL_ORIGIN := Vector2(16, 520)
const PANEL_PITCH := 112.0
const PANEL_COUNT := 8
## In a tray cell: the lifted sprite, and the sticker under it.
const TRAY_SPRITE := Rect2(6, 0, 96, 96)
const TRAY_BELOW := Rect2(0, 104, 108, 64)


func test_every_card_fits_and_opens_beside_its_item() -> void:
	var popup: ScanPopup = _popup()
	var balance: BalanceDefinition = load(BALANCE) as BalanceDefinition
	var cards: Array[CardDefinition] = _cards()
	assert_int(cards.size()).is_equal(LiveCardCount.CARDS)
	for definition: CardDefinition in cards:
		popup.show_card(definition, balance.aisle_of(definition), definition.tags)
		await get_tree().process_frame
		_assert_holds_its_text(popup, definition, definition.id)
		for index: int in range(PANEL_COUNT):
			var sprite: Rect2 = Rect2(_cell(index) + TRAY_SPRITE.position, TRAY_SPRITE.size)
			var below: Rect2 = Rect2(_cell(index) + TRAY_BELOW.position, TRAY_BELOW.size)
			popup.place_at(sprite, below, STAGE, PANEL_RECT)
			_assert_placed(popup, sprite, below, "%s at %d" % [definition.id, index])


## Every popup height, up to MAX_HEIGHT, at every cell stays on the stage and off the item's
## sprite and sticker (a tall one rises above the panel's top to stay on the stage).
func test_a_popup_of_any_height_opens_beside_the_item() -> void:
	for index: int in range(PANEL_COUNT):
		var sprite: Rect2 = Rect2(_cell(index) + TRAY_SPRITE.position, TRAY_SPRITE.size)
		var below: Rect2 = Rect2(_cell(index) + TRAY_BELOW.position, TRAY_BELOW.size)
		var height: float = ScanPopup.MIN_HEIGHT
		while height <= ScanPopup.MAX_HEIGHT:
			var popup_size: Vector2 = Vector2(ScanPopup.WIDTH, height)
			var rect: Rect2 = ScanPopup.place(sprite, below, popup_size, STAGE, PANEL_RECT)
			var message: String = "cell %d, height %d: %s" % [index, height, rect]
			assert_bool(STAGE.encloses(rect)).override_failure_message(message).is_true()
			(
				assert_bool(rect.intersects(sprite.merge(below)))
				. override_failure_message(message)
				. is_false()
			)
			height += 10.0


## The tag line shows the tags passed in (a granted tag included), then a product's aisle or
## Staple, never twice (Batteries' Household tag in the Household aisle); a coupon's shows only
## its tags.
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
	popup.show_card(milk, aisle, granted)
	var texts: Array[String] = []
	for label: Label in popup.text_labels():
		texts.append(label.text)
	assert_array(texts).contains([ScanPopup.tag_line(granted, milk, aisle)])


## An item in a scaled, moved panel is pointed at where it is drawn: place_at takes global rects
## and the popup sits in its own, unscaled layer.
func test_a_scaled_panel_is_placed_from_global_rects() -> void:
	var panel: Control = auto_free(Control.new())
	panel.position = Vector2(40, 10)
	panel.scale = Vector2(0.8, 0.8)
	add_child(panel)
	var sprite: Control = Control.new()
	sprite.position = _cell(3) + TRAY_SPRITE.position
	sprite.size = TRAY_SPRITE.size
	panel.add_child(sprite)
	var layer: Control = auto_free(Control.new())
	layer.position = Vector2(5, 7)
	add_child(layer)
	var popup: ScanPopup = ScanPopup.new()
	layer.add_child(popup)
	var cheese: CardDefinition = load("%s/cheese.tres" % CARDS) as CardDefinition
	popup.show_card(cheese, null, cheese.tags)
	var global_sprite: Rect2 = sprite.get_global_rect()
	var below: Rect2 = Rect2(global_sprite.position + Vector2(0, 84), Vector2(86, 51))
	var area: Rect2 = panel.get_global_transform() * PANEL_RECT
	popup.place_at(global_sprite, below, STAGE, area)
	var tip: Vector2 = layer.get_global_transform() * popup.tail_tip()
	assert_float(tip.y).is_equal_approx(global_sprite.get_center().y, 0.01)
	assert_int(popup.placement).is_equal(ScanPopup.Placement.RIGHT)
	var rect: Rect2 = popup.get_global_rect()
	assert_float(rect.position.x).is_equal_approx(
		global_sprite.merge(below).end.x + ScanPopup.SIDE_GAP, 0.01
	)
	assert_bool(STAGE.encloses(rect)).override_failure_message(str(rect)).is_true()


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


## Inside the stage and the panel's span, never above the panel's top, off the item's sprite and
## sticker, its tail off the sprite with its tip at the sprite's middle.
func _assert_placed(popup: ScanPopup, sprite: Rect2, below: Rect2, message: String) -> void:
	var rect: Rect2 = popup.get_global_rect()
	message += ": %s" % rect
	assert_bool(STAGE.encloses(rect)).override_failure_message(message).is_true()
	assert_bool(rect.intersects(below)).override_failure_message(message).is_false()
	assert_bool(rect.intersects(sprite)).override_failure_message(message).is_false()
	var tail: Rect2 = popup.tail().get_global_rect()
	assert_bool(tail.intersects(sprite)).override_failure_message(message).is_false()
	assert_float(rect.position.y).override_failure_message(message).is_greater_equal(
		PANEL_RECT.position.y
	)
	assert_float(rect.position.x).override_failure_message(message).is_greater_equal(
		PANEL_RECT.position.x
	)
	assert_float(rect.end.x).override_failure_message(message).is_less_equal(PANEL_RECT.end.x)
	assert_float(popup.tail_tip().y).override_failure_message(message).is_equal(
		sprite.get_center().y
	)


static func _cell(index: int) -> Vector2:
	return PANEL_CELL_ORIGIN + Vector2(index * PANEL_PITCH, 0)


static func _cards() -> Array[CardDefinition]:
	var cards: Array[CardDefinition] = []
	for file: String in DirAccess.get_files_at(CARDS):
		if file.ends_with(".tres"):
			cards.append(load("%s/%s" % [CARDS, file]) as CardDefinition)
	return cards
