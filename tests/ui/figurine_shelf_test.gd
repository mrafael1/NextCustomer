extends GdUnitTestSuite
## The FIGURINE SHELF (#63, mock-up capsule_63_shelf.html; locked items hidden, decided with the
## user): with 0, 3, 9 and 30 figurines the cabinet is one layout inside the 1280x720 window;
## every figurine stands inside its aisle's section above its plank, packed from the left at a
## 70 px pitch in data order; a locked item has no node; "None yet" shows on empty aisles only,
## ALL COLLECTED on full ones only; each aisle counts "n / m"; the fresh line shows at 0 only and
## the hover hint whenever a figurine stands; the hover tag stays inside the cabinet, clear of
## the aisle sign, and flips left of a figurine near the right edge.

const Kit := preload("res://tests/ui/toy_test_kit.gd")
## The mock-up's collections: early (3: a key item in three aisles) and partial (9).
const EARLY := {&"cold_cases": 1, &"fruit_and_veg": 1, &"snacks": 1}
const PARTIAL := {
	&"cold_cases": 1, &"pantry": 2, &"household": 1, &"fruit_and_veg": 3, &"bakery": 2
}

var _window_size: Vector2i


func before_test() -> void:
	_window_size = get_tree().root.size
	get_tree().root.size = Vector2i(Kit.SCREEN_RECT.size)


func after_test() -> void:
	get_tree().root.size = _window_size


func test_a_fresh_shelf() -> void:
	var shelf: FigurineShelf = await _shelf({})
	_assert_layout(shelf, {})
	assert_bool(shelf.fresh_label().visible).is_true()
	assert_bool(shelf.hint_label().visible).is_false()


func test_an_early_shelf() -> void:
	var shelf: FigurineShelf = await _shelf(EARLY)
	_assert_layout(shelf, EARLY)
	assert_bool(shelf.fresh_label().visible).is_false()
	assert_bool(shelf.hint_label().visible).is_true()


func test_a_partial_shelf_packs_from_the_left_in_data_order() -> void:
	var shelf: FigurineShelf = await _shelf(PARTIAL)
	_assert_layout(shelf, PARTIAL)
	# Fruit & veg holds its first three items: packed, no gap.
	var fruit: Array[TextureRect] = shelf.figurines(3)
	assert_int(fruit.size()).is_equal(3)
	# Bakery with its 1st and 3rd items (the 2nd locked): two figurines side by side.
	var profile: ProfileState = Kit.profile(0, 0)
	var bakery: AisleDefinition = Kit.aisle(Kit.balance(), &"bakery")
	profile.unlocked_items[bakery.capsule_cards[0].id] = 0
	profile.unlocked_items[bakery.capsule_cards[2].id] = 1
	shelf.show_collection(Kit.balance(), profile.unlocked_items)
	await _frames(2)
	var two: Array[TextureRect] = shelf.figurines(4)
	assert_int(two.size()).is_equal(2)
	var section: Rect2 = shelf.section_rect(4)
	assert_float(two[1].position.x - two[0].position.x).is_equal(FigurineShelf.FIGURINE_PITCH)
	assert_float(two[0].position.x).is_equal(section.position.x + FigurineShelf.FIGURINE_FIRST.x)
	assert_object(two[1].get_meta(&"card")).is_same(bakery.capsule_cards[2])
	assert_str(shelf.count_label(4).text).is_equal("2 / 8")


func test_a_full_shelf() -> void:
	var shelf: FigurineShelf = await _shelf(Kit.full_counts())
	_assert_layout(shelf, Kit.full_counts())
	assert_bool(shelf.fresh_label().visible).is_false()
	assert_bool(shelf.hint_label().visible).is_true()


func test_the_hover_tag_stays_clear_of_the_sign_and_flips_near_the_edge() -> void:
	var shelf: FigurineShelf = await _shelf(Kit.full_counts())
	var cabinet: Rect2 = shelf.cabinet_rect()
	for index: int in range(Kit.balance().aisles.size()):
		var sign_rect: Rect2 = Rect2(
			shelf.section_rect(index).position + FigurineShelf.SIGN_RECT.position,
			FigurineShelf.SIGN_RECT.size
		)
		for figurine: TextureRect in shelf.figurines(index):
			shelf.show_tag(figurine)
			await _frames(1)
			var tag: Rect2 = shelf.tag().get_global_rect()
			assert_bool(cabinet.encloses(tag)).override_failure_message(str(tag)).is_true()
			assert_bool(tag.intersects(sign_rect)).is_false()
			assert_bool(tag.intersects(figurine.get_global_rect())).is_false()
	# Fruit & veg's last figurine (right column, far right): its tag flips to the left.
	var last: TextureRect = shelf.figurines(3)[-1]
	shelf.show_tag(last)
	await _frames(1)
	assert_float(shelf.tag().get_global_rect().end.x).is_less_equal(last.position.x)
	# A hover lifts the figurine and shows its tag; leaving drops it and hides the tag.
	var first: TextureRect = shelf.figurines(0)[0]
	var rest_y: float = first.position.y
	shelf._on_figurine_hover(first, true)
	assert_float(first.position.y).is_equal(rest_y - FigurineShelf.FIGURINE_LIFT)
	assert_bool(shelf.tag().visible).is_true()
	shelf._on_figurine_hover(first, false)
	assert_float(first.position.y).is_equal(rest_y)
	assert_bool(shelf.tag().visible).is_false()


func _assert_layout(shelf: FigurineShelf, counts: Dictionary) -> void:
	var cabinet: Rect2 = shelf.cabinet_rect()
	assert_bool(Kit.SCREEN_RECT.encloses(cabinet)).is_true()
	assert_bool(Kit.SCREEN_RECT.encloses(shelf.back_button().get_global_rect())).is_true()
	assert_bool(shelf.back_button().get_global_rect().intersects(cabinet)).is_false()
	var balance: BalanceDefinition = Kit.balance()
	var owned: int = 0
	var sections: Array[Rect2] = []
	for index: int in range(balance.aisles.size()):
		var aisle: AisleDefinition = balance.aisles[index]
		var held: int = int(counts.get(aisle.id, 0))
		owned += held
		var section: Rect2 = shelf.section_rect(index)
		assert_bool(cabinet.encloses(section)).override_failure_message(str(section)).is_true()
		for other: Rect2 in sections:
			assert_bool(section.intersects(other)).is_false()
		sections.append(section)
		var plank_top: float = section.position.y + FigurineShelf.PLANK_RECT.position.y
		var figurines: Array[TextureRect] = shelf.figurines(index)
		assert_int(figurines.size()).is_equal(held)
		for k: int in range(figurines.size()):
			var rect: Rect2 = figurines[k].get_global_rect()
			assert_bool(section.encloses(rect)).override_failure_message(str(rect)).is_true()
			assert_float(rect.end.y).is_less_equal(plank_top)
			assert_float(rect.position.x).is_equal(
				(
					section.position.x
					+ FigurineShelf.FIGURINE_FIRST.x
					+ k * FigurineShelf.FIGURINE_PITCH
				)
			)
			assert_object(figurines[k].get_meta(&"card")).is_same(aisle.capsule_cards[k])
		# Locked items have no node anywhere.
		for k: int in range(held, aisle.capsule_cards.size()):
			for node: Node in shelf.find_children("*", "TextureRect", true, false):
				if node.has_meta(&"card"):
					assert_object(node.get_meta(&"card")).is_not_same(aisle.capsule_cards[k])
		var total: int = aisle.capsule_cards.size()
		assert_str(shelf.count_label(index).text).is_equal("%d / %d" % [held, total])
		assert_bool(shelf.none_label(index).visible).is_equal(held == 0)
		assert_bool(shelf.done_tag(index) != null).is_equal(held == total)
		if held == total:
			assert_bool(section.grow(8).encloses(shelf.done_tag(index).get_global_rect())).is_true()
	assert_str(shelf._chip_value.text).is_equal("%d / 30" % owned)
	assert_bool(shelf.fresh_label().visible).is_equal(owned == 0)
	if shelf.fresh_label().visible:
		assert_bool(Kit.SCREEN_RECT.encloses(shelf.fresh_label().get_global_rect())).is_true()
		(
			assert_bool(
				shelf.fresh_label().get_global_rect().intersects(shelf._chip.get_global_rect())
			)
			. is_false()
		)


func _shelf(counts: Dictionary) -> FigurineShelf:
	var shelf: FigurineShelf = FigurineShelf.new()
	add_child(shelf)
	auto_free(shelf)
	shelf.show_collection(Kit.balance(), Kit.profile(0, 0, counts).unlocked_items)
	shelf.visible = true
	await _frames(3)
	return shelf


func _frames(count: int) -> void:
	for frame: int in range(count):
		await await_idle_frame()
