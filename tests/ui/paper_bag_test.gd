extends GdUnitTestSuite
## The paper bag (#86 v6, mock-up count_up_86_v6_scan.html): its back wall, contents and front
## are pixel-art layers at the bag's size, taking no click and printing no text; a bagged item
## peeks out of its mouth at 1x art, at its place in bagging order, inside the bag's width and
## partly behind the front; a hop copy is handed over into the contents; the bag squashes about
## its foot on a landing and settles, never under reduced motion, on the tween it is given;
## show_items shows a resumed checkout's items at once, and clear() empties it. The real saves
## and logs are never touched.

const CARDS := "res://data/cards/%s.tres"
const PRODUCTS: Array[String] = [
	"milk", "eggs", "coffee", "cheese", "banana", "croissant", "crisps", "tea_bags", "batteries"
]
## Where the bag stands in the test's stage (ShiftStage.BAG_RECT's place).
const BAG_AT := Vector2(284, 246)

var _folder: String = ""
var _stage: Control
var _bag: PaperBag


func before_test() -> void:
	_folder = "user://test_paper_bag_%d" % Time.get_ticks_usec()
	_event_log().use_folder(_folder)
	ProjectSettings.set_setting(SaveService.FOLDER_SETTING, _folder)
	_stage = auto_free(Control.new())
	_stage.size = ShiftStage.SIZE
	add_child(_stage)
	_bag = PaperBag.new()
	_bag.position = BAG_AT
	_stage.add_child(_bag)


func after_test() -> void:
	ProjectSettings.set_setting(SaveService.FOLDER_SETTING, null)
	if DirAccess.dir_exists_absolute(_folder):
		for file_name: String in DirAccess.get_files_at(_folder):
			DirAccess.remove_absolute(_folder.path_join(file_name))
		DirAccess.remove_absolute(_folder)


## Back to front: the back wall, the contents, the front, each at the bag's size; the two sprites
## are the bag's art at its size with the sharp-pixel material. The bag pivots on its foot's
## middle and takes no click; it prints no text.
func test_the_layers_stack_back_to_front() -> void:
	assert_vector(_bag.size).is_equal(PaperBag.SIZE)
	assert_vector(_bag.size).is_equal(ShiftStage.BAG_RECT.size)
	assert_vector(_bag.pivot_offset).is_equal(Vector2(PaperBag.SIZE.x / 2.0, PaperBag.SIZE.y))
	var names: Array[StringName] = [PaperBag.BACK_NAME, PaperBag.CONTENTS_NAME, PaperBag.FRONT_NAME]
	assert_int(_bag.get_child_count()).is_equal(names.size())
	for index: int in range(names.size()):
		var layer: Control = _bag.get_child(index) as Control
		assert_str(String(layer.name)).is_equal(String(names[index]))
		assert_that(layer.get_global_rect()).is_equal(Rect2(BAG_AT, PaperBag.SIZE))
		assert_int(layer.mouse_filter).is_equal(Control.MOUSE_FILTER_IGNORE)
	assert_object(_bag.get_child(1)).is_same(_bag.contents)
	var textures: Dictionary[int, Texture2D] = {0: PaperBag.BACK, 2: PaperBag.FRONT}
	for index: int in textures:
		var sprite: TextureRect = _bag.get_child(index) as TextureRect
		assert_object(sprite.texture).is_same(textures[index])
		assert_vector(Vector2(sprite.texture.get_size())).is_equal(PaperBag.SIZE)
		assert_bool(sprite.has_meta(ArtStyle.PIXEL_ART_META)).is_true()
	assert_int(_bag.mouse_filter).is_equal(Control.MOUSE_FILTER_IGNORE)
	_bag.show_items(_definitions(3))
	assert_array(_bag.find_children("*", "Label", true, false)).is_empty()
	for node: Node in _bag.find_children("*", "Control", true, false):
		assert_int((node as Control).mouse_filter).is_equal(Control.MOUSE_FILTER_IGNORE)


## Every place an item peeks out is on the art grid, inside the bag's width, its art's top over
## the front's top edge and its foot behind the front; the mouth is the bag's top, over the front.
func test_the_peeks_stay_in_the_bag() -> void:
	var front_top: float = PaperBag.MOUTH_RECT.end.y
	for place: Vector2 in PaperBag.PEEKS:
		var rect: Rect2 = Rect2(place, PaperBag.ITEM_SIZE)
		assert_float(fmod(place.x, ArtStyle.ART_SCALE)).is_equal(0.0)
		assert_float(fmod(absf(place.y), ArtStyle.ART_SCALE)).is_equal(0.0)
		assert_float(rect.position.x).is_greater_equal(0.0)
		assert_float(rect.end.x).is_less_equal(PaperBag.SIZE.x)
		assert_float(rect.position.y).is_less(front_top)
		assert_float(rect.end.y).is_greater(front_top)
	assert_int(PaperBag.PEEKS.size()).is_greater_equal(9)
	assert_vector(PaperBag.ITEM_SIZE).is_equal(ItemView.SPRITE_SIZE / ArtStyle.ART_SCALE)
	var mouth: Rect2 = _bag.mouth_rect()
	assert_bool(Rect2(BAG_AT, PaperBag.SIZE).encloses(mouth)).is_true()
	assert_float(mouth.position.y).is_equal(BAG_AT.y)


## Each bagged item peeks out at the next place at 1x art (its texels one screen pixel), in the
## contents between the back and the front; next_peek_rect() says where the next one goes, and the
## places wrap after the last.
func test_bagged_items_peek_out_in_order_at_one_x() -> void:
	var definitions: Array[CardDefinition] = _definitions(PRODUCTS.size())
	for index: int in range(definitions.size()):
		var expected: Rect2 = _bag.next_peek_rect()
		assert_that(expected).is_equal(Rect2(BAG_AT + PaperBag.PEEKS[index], PaperBag.ITEM_SIZE))
		var art: Control = _bag.add_item(definitions[index])
		assert_object(art.get_parent()).is_same(_bag.contents)
		assert_that(art.get_global_rect()).is_equal(expected)
		var texture: Texture2D = (art as TextureRect).texture
		var texel: float = art.get_global_rect().size.x / texture.get_width()
		assert_float(texel).is_equal(1.0)
	assert_int(_bag.items().size()).is_equal(definitions.size())
	assert_int(_bag.contents.get_child_count()).is_equal(definitions.size())
	# After the last place, the first again.
	assert_that(_bag.next_peek_rect()).is_equal(
		Rect2(
			BAG_AT + PaperBag.PEEKS[definitions.size() % PaperBag.PEEKS.size()], PaperBag.ITEM_SIZE
		)
	)


## The ride's hop copy (an item's belt art at 2x, anywhere on the stage) is handed over into the
## contents and peeks out at its place at 1x, upright.
func test_a_hop_copy_is_handed_over() -> void:
	var copy: TextureRect = ItemView.item_art(load(CARDS % "milk") as CardDefinition)
	_stage.add_child(copy)
	copy.position = Vector2(374, 286)
	copy.rotation = 0.3
	copy.scale = Vector2(0.75, 0.75)
	var target: Rect2 = _bag.next_peek_rect()
	_bag.add_art(copy)
	assert_object(copy.get_parent()).is_same(_bag.contents)
	assert_float(copy.rotation).is_equal(0.0)
	assert_that(copy.get_global_rect()).is_equal(target)
	assert_array(_bag.items()).contains_exactly([copy])
	# A copy already hopping inside the contents is handed over in place.
	var inside: TextureRect = ItemView.item_art(load(CARDS % "eggs") as CardDefinition)
	_bag.contents.add_child(inside)
	_bag.add_art(inside)
	assert_int(_bag.contents.get_child_count()).is_equal(2)
	assert_vector(inside.position).is_equal(PaperBag.PEEKS[1])


## A landing squashes the bag about its foot (wider and lower, its foot still on the counter)
## and it settles back; under reduced motion it never moves.
func test_a_landing_squashes_and_settles() -> void:
	var foot: Vector2 = Vector2(_bag.get_global_rect().get_center().x, _bag.get_global_rect().end.y)
	_bag.land()
	assert_bool(_bag.is_squashing()).is_true()
	var squashed: bool = false
	for _frame: int in range(60):
		await get_tree().process_frame
		if _bag.scale.x > 1.0 and _bag.scale.y < 1.0:
			squashed = true
			var rect: Rect2 = _bag.get_global_rect()
			assert_float(rect.end.y).is_equal_approx(foot.y, 0.01)
			assert_float(rect.get_center().x).is_equal_approx(foot.x, 0.01)
		if not _bag.is_squashing():
			break
	assert_bool(squashed).is_true()
	assert_bool(_bag.is_squashing()).is_false()
	assert_vector(_bag.scale).is_equal(Vector2.ONE)
	_bag.land(true)
	assert_bool(_bag.is_squashing()).is_false()
	assert_vector(_bag.scale).is_equal(Vector2.ONE)


## The squash runs on the tween make_tween gives (the count-up's), when one is set.
func test_the_squash_uses_the_given_tween() -> void:
	var made: Array[Tween] = []
	_bag.make_tween = func() -> Tween:
		var tween: Tween = _stage.create_tween()
		made.append(tween)
		return tween
	_bag.land()
	assert_int(made.size()).is_equal(1)
	assert_bool(made[0].is_valid()).is_true()
	made[0].custom_step(PaperBag.SQUASH_S + 0.1)
	assert_bool(_bag.is_squashing()).is_false()
	assert_vector(_bag.scale).is_equal(Vector2.ONE)


## show_items shows a resumed checkout's items at once, replacing what was there; clear()
## empties the bag, a copy still hopping in too, and stops a squash.
func test_show_items_and_clear() -> void:
	_bag.show_items(_definitions(2))
	_bag.show_items(_definitions(4))
	await get_tree().process_frame
	assert_int(_bag.items().size()).is_equal(4)
	assert_int(_bag.contents.get_child_count()).is_equal(4)
	for index: int in range(4):
		assert_vector(_bag.items()[index].position).is_equal(PaperBag.PEEKS[index])
	_bag.contents.add_child(ItemView.item_art(load(CARDS % "milk") as CardDefinition))
	_bag.land()
	_bag.clear()
	await get_tree().process_frame
	assert_int(_bag.items().size()).is_equal(0)
	assert_int(_bag.contents.get_child_count()).is_equal(0)
	assert_bool(_bag.is_squashing()).is_false()
	assert_vector(_bag.scale).is_equal(Vector2.ONE)
	assert_that(_bag.next_peek_rect()).is_equal(
		Rect2(BAG_AT + PaperBag.PEEKS[0], PaperBag.ITEM_SIZE)
	)


func _definitions(count: int) -> Array[CardDefinition]:
	var result: Array[CardDefinition] = []
	for index: int in range(count):
		result.append(load(CARDS % PRODUCTS[index % PRODUCTS.size()]) as CardDefinition)
	return result


static func _event_log() -> EventLogService:
	return (Engine.get_main_loop() as SceneTree).root.get_node("/root/EventLog")
