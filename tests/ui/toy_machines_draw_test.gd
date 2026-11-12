extends GdUnitTestSuite
## A draw at the TOY MACHINES (#63): a click on an OK machine draws its key item first, saves it,
## the coins drop by the price (the floor label, the window and FIGURINES count it once the
## figurine has joined its lineup card, v1.05: held until then), and the reveal shows only the
## item's icon (its sprite, or the art-pending box with its name; 2026-11-11: no medallion, NEW!,
## name, aisle, stock line or OK) inside the window. Nothing closes it: no click or key, and the
## machines and DONE take no clicks while it is up; after ToyReveal.HOLD_S the icon flies into
## the lineup card by itself, on the 2 px grid every frame, and the screen is playable again once
## it lands. The stock line stays the counter's (the results' and the title's without a saved
## run: "In stock from your next run"; with one: "In stock after your saved run"). A failed save
## switches every machine OFF with the notice and shows no reveal. Saves and logs go to a
## temporary folder.

const Kit := preload("res://tests/ui/toy_test_kit.gd")

var _folder: String = ""
var _window_size: Vector2i
var _errors: Array[String] = []


func before_test() -> void:
	_folder = "user://test_toys_draw_%d" % Time.get_ticks_usec()
	_errors.clear()
	Kit.event_log().use_folder(_folder)
	ProjectSettings.set_setting(SaveService.FOLDER_SETTING, _folder)
	_window_size = get_tree().root.size
	get_tree().root.size = Vector2i(Kit.SCREEN_RECT.size)


func after_test() -> void:
	get_tree().root.size = _window_size
	ProjectSettings.set_setting(SaveService.FOLDER_SETTING, null)
	Kit.remove(_folder)


func test_a_click_draws_the_key_item_and_reveals_it() -> void:
	var profile: ProfileState = Kit.profile(2, 3)
	var screen: ToyMachinesScreen = await _open(profile, false)
	var bakery: ToyMachineView = _machine(screen, &"bakery")
	bakery._gui_input(Kit.left_click())
	await _frames(3)
	assert_bool(profile.unlocked_items.has(&"baguette")).is_true()
	assert_int(profile.unlocked_items[&"baguette"]).is_equal(2)
	assert_int(profile.coins).is_equal(1)
	assert_str(screen.coins_text()).is_equal("1")
	# Held under the reveal: only COINS changes at the draw.
	assert_str(screen.machines()[4].floor_text()).is_equal("8 OF 8 LEFT")
	assert_str(screen.figurines_text()).is_equal("0/30")
	assert_int(bakery.capsule_count()).is_equal(8)
	# Saved at once.
	var saved: ProfileState = SaveService.new(_folder).load_profile()
	assert_int(saved.unlocked_items[&"baguette"]).is_equal(2)
	assert_int(saved.coins).is_equal(1)
	assert_int(Kit.events(_folder, "capsule").size()).is_equal(1)
	var reveal: ToyReveal = screen.reveal()
	assert_bool(reveal.visible).is_true()
	assert_int(screen.counter().run_index()).is_equal(2)
	var card: CardDefinition = Kit.aisle(Kit.balance(), &"bakery").capsule_cards[0]
	assert_object(reveal.figurine().texture).is_same(ArtStyle.item_sprite(card))
	if reveal.figurine().texture == ArtStyle.ITEM_PENDING:
		var printed: Label = reveal.figurine().get_node(ItemView.PRINTED_NAME) as Label
		assert_str(printed.text).is_equal("Baguette")
	await _frames(20)
	_assert_reveal_on_screen(reveal)
	reveal.finish_hold()
	assert_bool(screen.lineup_join().is_active()).is_true()
	screen.lineup_join().finish()
	assert_str(screen.machines()[4].floor_text()).is_equal("7 OF 8 LEFT")
	assert_str(screen.figurines_text()).is_equal("1/30")
	assert_int(bakery.capsule_count()).is_equal(7)
	assert_bool(reveal.visible).is_false()


## After the key item, a draw is random among the items left; the reveal shows the drawn item's
## own art (a sprite such as Strawberries', or the art-pending box).
func test_a_later_draw_shows_the_drawn_items_art() -> void:
	var profile: ProfileState = Kit.profile(1, 1, {&"fruit_and_veg": 1})
	var screen: ToyMachinesScreen = await _open(profile, false)
	_machine(screen, &"fruit_and_veg")._gui_input(Kit.left_click())
	assert_int(profile.unlocked_items.size()).is_equal(2)
	var drawn: CardDefinition = null
	for card: CardDefinition in Kit.aisle(Kit.balance(), &"fruit_and_veg").capsule_cards:
		if card.id != &"fruit_salad" and profile.unlocked_items.has(card.id):
			drawn = card
	assert_object(drawn).is_not_null()
	assert_object(screen.reveal().figurine().texture).is_same(ArtStyle.item_sprite(drawn))


## Nothing dismisses the reveal: the draw click, another click, Enter and Space leave it up, and
## the machines and DONE take no clicks under it. After HOLD_S the join starts by itself; the
## machines stay blocked until the icon has landed, then the next draw works.
func test_the_reveal_holds_then_the_icon_flies_by_itself() -> void:
	var profile: ProfileState = Kit.profile(3, 2)
	var screen: ToyMachinesScreen = await _open(profile, false)
	_machine(screen, &"cold_cases")._gui_input(Kit.left_click())
	var reveal: ToyReveal = screen.reveal()
	assert_bool(reveal.is_holding()).is_true()
	assert_int(reveal.mouse_filter).is_equal(Control.MOUSE_FILTER_STOP)
	await _frames(2)
	# A real click on a machine lands on the reveal's shade: no second pull.
	var machine_at: Vector2 = _machine(screen, &"pantry").get_global_rect().get_center()
	for pressed: bool in [true, false]:
		var click: InputEventMouseButton = Kit.left_click()
		click.pressed = pressed
		click.position = machine_at
		click.global_position = machine_at
		get_tree().root.push_input(click, true)
	await _frames(2)
	assert_int(profile.coins).is_equal(2)
	screen._unhandled_key_input(Kit.key(KEY_ENTER))
	screen._unhandled_key_input(Kit.key(KEY_SPACE))
	screen._unhandled_key_input(Kit.key(KEY_ESCAPE))
	assert_bool(reveal.is_holding()).is_true()
	assert_bool(screen.visible).is_true()
	assert_bool(screen.lineup_join().is_active()).is_false()
	# The machines take no clicks while it is up (no double pull).
	_machine(screen, &"pantry")._gui_input(Kit.left_click())
	_machine(screen, &"cold_cases")._gui_input(Kit.left_click())
	assert_int(profile.coins).is_equal(2)
	assert_bool(profile.unlocked_items.has(&"sugar_cubes")).is_false()
	# DONE sits under the reveal's shade: the shade is what the pointer hits there.
	await _frames(2)
	var done_at: Vector2 = screen.done_button().get_global_rect().get_center()
	assert_int(reveal.get_index()).is_greater(screen.done_button().get_parent().get_index())
	assert_bool(reveal.get_global_rect().has_point(done_at)).is_true()
	await await_millis(roundi(ToyReveal.HOLD_S * 1000.0) + 150)
	await _frames(2)
	assert_bool(reveal.is_open()).is_false()
	var join: ToyLineupJoin = screen.lineup_join()
	assert_bool(join.is_active()).is_true()
	# The figurine joins its lineup card; the machines take no clicks until it is done.
	_machine(screen, &"pantry")._gui_input(Kit.left_click())
	assert_int(profile.coins).is_equal(2)
	join.finish()
	assert_bool(reveal.visible).is_false()
	_machine(screen, &"pantry")._gui_input(Kit.left_click())
	assert_int(profile.coins).is_equal(1)
	assert_bool(reveal.is_holding()).is_true()


## The flight is pixel art: the 2x sprite, then the mini, always on the 2 px grid; it starts
## where the reveal's icon stood and moves every frame (2026-11-11 feel pass: no 20 fps steps),
## landing well under a second after the hold, the whole join short.
func test_the_flight_moves_every_frame_on_the_pixel_grid() -> void:
	var profile: ProfileState = Kit.profile(3, 2)
	var screen: ToyMachinesScreen = await _open(profile, false)
	# Bakery's card hangs just above the reveal: the shortest trip, where easing shows most.
	_machine(screen, &"bakery")._gui_input(Kit.left_click())
	await await_millis(250)  # The drop in is over.
	var reveal: ToyReveal = screen.reveal()
	reveal.finish_hold()
	var icon: Rect2 = reveal.figurine().get_global_rect()
	assert_vector(icon.get_center()).is_equal(ToyReveal.ICON_CENTRE)
	var join: ToyLineupJoin = screen.lineup_join()
	join.seek(0.0)
	assert_vector(join.flyer().position).is_equal(icon.position)
	assert_vector(join.flyer().size).is_equal(ItemView.SPRITE_SIZE)
	# Every 60 fps frame of the flight moves it at least a grid step, from the first (review fix:
	# an ease in and out stood still on the grid as it lifted off and crawled as it settled), and
	# a puff of sparkles hides the swap to the mini.
	var sizes: Array[Vector2] = []
	var last: Vector2 = join.flyer().get_rect().get_center()
	var puffed: bool = false
	for frame: int in range(1, ceili(ToyLineupJoin.FLY_S * 60.0)):
		join.seek(frame / 60.0)
		if not join.flyer().visible:
			break
		var at: Vector2 = join.flyer().get_rect().get_center()
		assert_vector(join.flyer().position.posmodv(Vector2(2, 2))).is_equal(Vector2.ZERO)
		# At least one grid step a frame, to the very end (it lands at speed).
		var moved: float = at.distance_to(last)
		assert_float(moved).override_failure_message("frame %d" % frame).is_greater_equal(2.0)
		last = at
		if not sizes.has(join.flyer().size):
			sizes.append(join.flyer().size)
			puffed = puffed or _sparkles_shown(join) > 0
	assert_array(sizes).is_equal([ItemView.SPRITE_SIZE, ToyLineupJoin.MINI_SIZE])
	assert_bool(puffed).is_true()
	# It has landed by FLY_S, well under a second; the whole join is short.
	join.seek(ToyLineupJoin.FLY_S + 0.001)
	assert_bool(join.flyer().visible).is_false()
	assert_float(ToyLineupJoin.FLY_S).is_less_equal(0.5)
	assert_float(ToyLineupJoin.JOIN_S).is_less_equal(1.5)
	join.finish()


## Leaving mid-reveal (the screen closed under it): nothing plays on, and the next open is clean.
func test_closing_during_the_reveal_is_clean() -> void:
	var profile: ProfileState = Kit.profile(3, 2)
	var screen: ToyMachinesScreen = await _open(profile, false)
	_machine(screen, &"pantry")._gui_input(Kit.left_click())
	assert_bool(screen.reveal().is_holding()).is_true()
	screen.close()
	await await_millis(roundi(ToyReveal.HOLD_S * 1000.0) + 150)
	assert_bool(screen.lineup_join().is_active()).is_false()
	assert_bool(screen.reveal().visible).is_false()
	screen.open(screen.counter(), Kit.balance())
	await _frames(2)
	assert_bool(screen.reveal().visible).is_false()
	assert_bool(screen.lineup_join().owns_lineup()).is_false()
	_machine(screen, &"snacks")._gui_input(Kit.left_click())
	assert_int(profile.coins).is_equal(1)
	assert_bool(screen.reveal().is_holding()).is_true()


## A title draw while a run is saved: the saved run's index.
func test_a_title_draw_with_a_saved_run() -> void:
	var profile: ProfileState = Kit.profile(1, 4)
	var screen: ToyMachinesScreen = await _open(profile, true)
	_machine(screen, &"snacks")._gui_input(Kit.left_click())
	assert_int(profile.unlocked_items[&"crisps"]).is_equal(4)
	assert_int(screen.counter().run_index()).is_equal(4)
	# The last coin spent: the machines go dim with the notice under them.
	assert_int(_machine(screen, &"cold_cases").state()).is_equal(CapsuleCounter.State.BROKE)
	assert_int(screen.strip_kind()).is_equal(ToyMachinesScreen.Strip.BROKE)


func test_a_failed_save_switches_every_machine_off() -> void:
	var saves: SaveService = SaveService.new(
		_folder, func(message: String) -> void: _errors.append(message)
	)
	DirAccess.make_dir_recursive_absolute(saves.profile_path() + SaveService.TEMP_SUFFIX)
	var profile: ProfileState = Kit.profile(2, 2)
	var before_draw: Dictionary = profile.to_dictionary()
	var counter: CapsuleCounter = CapsuleCounter.new(
		profile, saves, Kit.balance(), Kit.event_log(), false, true
	)
	var screen: ToyMachinesScreen = await _open_counter(counter)
	_machine(screen, &"household")._gui_input(Kit.left_click())
	await _frames(2)
	assert_bool(screen.reveal().visible).is_false()
	assert_dict(profile.to_dictionary()).is_equal(before_draw)
	for machine: ToyMachineView in screen.machines():
		assert_int(machine.state()).is_equal(CapsuleCounter.State.OFF)
		assert_bool(machine.paper().visible).is_true()
	assert_int(screen.strip_kind()).is_equal(ToyMachinesScreen.Strip.OFF)
	assert_str(screen.coins_text()).is_equal("?")
	assert_int(_errors.size()).is_equal(1)
	assert_array(Kit.events(_folder, "capsule")).is_empty()


## The book: FIGURINE BOOK hides the machines and shows the drawn figurine's card in colour;
## BACK returns.
func test_the_shelf_opens_and_comes_back() -> void:
	var profile: ProfileState = Kit.profile(2, 2)
	var screen: ToyMachinesScreen = await _open(profile, false)
	_machine(screen, &"cold_cases")._gui_input(Kit.left_click())
	screen.reveal().finish_hold()
	screen.lineup_join().finish()
	screen.shelf_button().pressed.emit()
	assert_bool(screen.book().visible).is_true()
	# Newest first, the drawn item's card leads the book, in colour with its figurine.
	screen.book().set_sort(BookOrder.Sort.NEWEST)
	var first: BookCard = screen.book().cards()[0]
	assert_bool(profile.unlocked_items.has(first.entry().card.id)).is_true()
	assert_bool(first.entry().owned).is_true()
	assert_object(first.figurine()).is_not_null()
	# Machines can't be picked behind the shelf.
	_machine(screen, &"pantry")._gui_input(Kit.left_click())
	assert_int(profile.coins).is_equal(1)
	screen.book().back_button().pressed.emit()
	assert_bool(screen.book().visible).is_false()
	var closed: Array[int] = [0]
	screen.closed.connect(func() -> void: closed[0] += 1)
	screen.done_button().pressed.emit()
	assert_bool(screen.visible).is_false()
	assert_int(closed[0]).is_equal(1)
	await await_idle_frame()  # Let the book's dropped pages' queued frees run (no orphans).
	await await_idle_frame()


## The reveal stays alive through its hold (review fix: a second with nothing moving read as
## slow): after the drop in, the icon bobs and the sparkles twinkle in turn, so the picture never
## stands still for more than BOB_S; under reduced motion it stands still with no sparkles.
func test_the_reveal_stays_alive_through_the_hold() -> void:
	var profile: ProfileState = Kit.profile(3, 2)
	var screen: ToyMachinesScreen = await _open(profile, false)
	_machine(screen, &"pantry")._gui_input(Kit.left_click())
	var reveal: ToyReveal = screen.reveal()
	var last: String = ""
	var last_change: int = Time.get_ticks_msec()
	var longest: int = 0
	var twinkled: Array[int] = []
	var started: int = Time.get_ticks_msec()
	while Time.get_ticks_msec() - started < 700 and reveal.is_holding():
		await get_tree().process_frame
		var lit: int = -1
		for index: int in reveal.twinkles().size():
			var twinkle: TextureRect = reveal.twinkles()[index]
			if twinkle.visible:
				lit = index
				assert_bool(Kit.SCREEN_RECT.encloses(Kit.rect(twinkle))).is_true()
				(
					assert_bool(twinkle.get_global_rect().intersects(Kit.rect(reveal.figurine())))
					. is_false()
				)
		if lit >= 0 and not twinkled.has(lit):
			twinkled.append(lit)
		var shot: String = "%s %d" % [reveal.figurine().position, lit]
		if shot != last:
			longest = maxi(longest, Time.get_ticks_msec() - last_change)
			last_change = Time.get_ticks_msec()
			last = shot
	assert_int(longest).is_less(roundi(ToyReveal.BOB_S * 1000.0) + 120)
	assert_int(twinkled.size()).is_greater(1)
	reveal.finish_hold()
	for twinkle: TextureRect in reveal.twinkles():
		assert_bool(twinkle.visible).is_false()
	screen.lineup_join().finish()
	# Reduced motion: still.
	profile.set_reduced_motion(true)
	_machine(screen, &"cold_cases")._gui_input(Kit.left_click())
	var at: Vector2 = reveal.figurine().position
	await _frames(20)
	assert_vector(reveal.figurine().position).is_equal(at)
	for twinkle: TextureRect in reveal.twinkles():
		assert_bool(twinkle.visible).is_false()
	reveal.finish_hold()
	screen.lineup_join().finish()


## The icon alone, a few frames after the pull: inside the screen, centred at ICON_CENTRE (its
## drop in over), at the sprite's 2x size and on the 2 px grid; no other piece on the reveal.
func _assert_reveal_on_screen(reveal: ToyReveal) -> void:
	var icon: Rect2 = reveal.figurine().get_global_rect()
	assert_bool(Kit.SCREEN_RECT.encloses(icon)).override_failure_message(str(icon)).is_true()
	assert_vector(icon.size).is_equal(ItemView.SPRITE_SIZE)
	# Centred (or one bob up, while it holds).
	assert_float(icon.get_center().x).is_equal(ToyReveal.ICON_CENTRE.x)
	var bob: float = ToyReveal.ICON_CENTRE.y - icon.get_center().y
	assert_bool(bob in [0.0, ToyReveal.BOB_ART * ArtStyle.ART_SCALE]).is_true()
	assert_vector(icon.position.posmodv(Vector2(2, 2))).is_equal(Vector2.ZERO)
	var shown: Array[Node] = []
	for child: Node in reveal.get_children():
		if child is TextureRect and reveal.twinkles().has(child as TextureRect):
			continue  # The hold's sparkles, round the icon.
		if child is CanvasItem and (child as CanvasItem).visible and child is TextureRect:
			shown.append(child)
	assert_array(shown).is_equal([reveal.figurine()])
	assert_int(reveal.find_children("*", "Label", true, false).size()).is_less_equal(
		1 if reveal.figurine().texture == ArtStyle.ITEM_PENDING else 0
	)
	assert_int(reveal.find_children("*", "BaseButton", true, false).size()).is_equal(0)
	# The scene recedes under a strong shade over the whole stage (no backing behind the icon).
	var shade: ColorRect = reveal.get_child(0) as ColorRect
	assert_object(shade).is_not_null()
	assert_bool(Rect2(Vector2.ZERO, ToyReveal.STAGE).encloses(shade.get_rect())).is_true()
	assert_float(shade.color.a).is_greater_equal(0.7)


func _machine(screen: ToyMachinesScreen, id: StringName) -> ToyMachineView:
	for machine: ToyMachineView in screen.machines():
		if machine.aisle().id == id:
			return machine
	return null


func _open(profile: ProfileState, saved_run: bool) -> ToyMachinesScreen:
	var counter: CapsuleCounter = CapsuleCounter.new(
		profile, SaveService.new(_folder), Kit.balance(), Kit.event_log(), saved_run, true
	)
	return await _open_counter(counter)


func _open_counter(counter: CapsuleCounter) -> ToyMachinesScreen:
	var screen: ToyMachinesScreen = ToyMachinesScreen.new()
	add_child(screen)
	auto_free(screen)
	screen.open(counter, Kit.balance())
	await _frames(3)
	return screen


func _frames(count: int) -> void:
	for frame: int in range(count):
		await await_idle_frame()


## How many of the join's sparkles show.
static func _sparkles_shown(join: ToyLineupJoin) -> int:
	var shown: int = 0
	for child: Node in join.get_children():
		var sprite: TextureRect = child as TextureRect
		if sprite != null and sprite.texture == ToyLineupJoin.SPARKLE and sprite.visible:
			shown += 1
	return shown
