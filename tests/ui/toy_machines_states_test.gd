extends GdUnitTestSuite
## The TOY MACHINES' states (#121, mock-up toy_machines_121_v2.html), each shown by more than
## colour and checked by node, never by modulate: OK (lit art, the lamp on, the coin and price
## on the LED, a pointing hand; hover lifts it, lights its sign, heats its lamp and ticks its
## floor plate), EMPTY (dim art, the tick tag, no price, no click, the figurine kept in colour,
## COLLECTED in a green stripe), BROKE (dim art, the lid shut, a padlock, every lamp off, the
## figurines dimmed, a tomato 0 and the notice), OFF (grey art, the OUT OF ORDER tape, COINS ?,
## the notice), the full collection (no tags, COLLECTION COMPLETE) and a fresh profile. The
## cabinets come from data: each aisle's file names its art set, its slots and its figurine, and
## an aisle with no cabinet falls back to the plain base. Saves and logs go to a temporary folder.

const Kit := preload("res://tests/ui/toy_test_kit.gd")

var _folder: String = ""
var _window_size: Vector2i


func before_test() -> void:
	_folder = "user://test_toys_states_%d" % Time.get_ticks_usec()
	Kit.event_log().use_folder(_folder)
	ProjectSettings.set_setting(SaveService.FOLDER_SETTING, _folder)
	_window_size = get_tree().root.size
	get_tree().root.size = Vector2i(Kit.SCREEN_RECT.size)


func after_test() -> void:
	get_tree().root.size = _window_size
	ProjectSettings.set_setting(SaveService.FOLDER_SETTING, null)
	Kit.remove(_folder)


func test_ok_and_empty_machines() -> void:
	var screen: ToyMachinesScreen = await _open(Kit.profile(3, 2, {&"pantry": 2}))
	var ok: ToyMachineView = _machine(screen, &"cold_cases")
	assert_int(ok.state()).is_equal(CapsuleCounter.State.OK)
	assert_int(ok.tone()).is_equal(ToyCabinet.Tone.LIT)
	assert_bool(ok.part("coin").visible).is_true()
	assert_bool(ok.part("padlock").visible).is_false()
	assert_str((ok.part("price_number") as PixelLine).text()).is_equal("1")
	assert_int(ok.mouse_default_cursor_shape).is_equal(Control.CURSOR_POINTING_HAND)
	assert_bool(ok.part("lid").visible).is_false()
	assert_object(_lamp(screen, ok).texture).is_same(ToyExitArt.lamp("on"))
	var cabinet: ToyCabinet = ok.cabinet()
	assert_object((ok.part("cabinet") as TextureRect).texture).is_same(
		cabinet.art("cabinet", ToyCabinet.Tone.LIT)
	)
	assert_bool(ok.part("sold_out").visible).is_false()
	var machine_rect: Rect2 = Rect2(ok.global_position, ToyMachineView.SIZE)
	assert_bool(machine_rect.encloses(ok.price_label().get_global_rect())).is_true()
	var empty: ToyMachineView = _machine(screen, &"pantry")
	assert_int(empty.state()).is_equal(CapsuleCounter.State.EMPTY)
	assert_int(empty.tone()).is_equal(ToyCabinet.Tone.DIM)
	assert_bool(empty.part("sold_out").visible).is_true()
	var empty_rect: Rect2 = Rect2(empty.global_position, ToyMachineView.SIZE)
	assert_bool(empty_rect.encloses(empty.part("sold_out").get_global_rect())).is_true()
	assert_bool(empty.price_label().visible).is_false()
	assert_int(empty.capsule_count()).is_equal(0)
	assert_int(empty.mouse_default_cursor_shape).is_equal(Control.CURSOR_ARROW)
	assert_object(_lamp(screen, empty).texture).is_same(ToyExitArt.lamp("off"))
	assert_str(empty.floor_text()).is_equal(ToyMachineView.SOLD_OUT_TEXT)
	assert_int((empty.part("floor") as ToyPlate).mode()).is_equal(ToyPlate.Mode.OFF)
	assert_int((empty.part("sign") as ToyPlate).mode()).is_equal(ToyPlate.Mode.OFF)
	var picks: Array[int] = [0]
	empty.picked.connect(func(_aisle: AisleDefinition) -> void: picks[0] += 1)
	empty._gui_input(Kit.left_click())
	assert_int(picks[0]).is_equal(0)
	assert_int(screen.counter().profile.coins).is_equal(3)
	# Hover lifts an OK machine only: its sign lights, its lamp heats, its floor plate ticks.
	ok._on_hover(true)
	assert_bool(ok.is_lifted()).is_true()
	assert_bool(ok.is_hot()).is_true()
	assert_int((ok.part("sign") as ToyPlate).mode()).is_equal(ToyPlate.Mode.LIT)
	assert_bool((ok.part("floor") as ToyPlate).tick().visible).is_true()
	assert_object(_lamp(screen, ok).texture).is_same(ToyExitArt.lamp("hot"))
	# The sign never moves.
	assert_float(ok.sign_rect().position.y).is_equal(ToyMachinesScreen.MACHINE_TOP)
	ok._on_hover(false)
	assert_bool(ok.is_lifted()).is_false()
	empty._on_hover(true)
	assert_bool(empty.is_lifted()).is_false()
	assert_bool((empty.part("floor") as ToyPlate).tick().visible).is_false()


## The window shows one capsule per item left, on the cabinet's slots, as many as it has.
func test_the_window_shows_the_capsules_left() -> void:
	var screen: ToyMachinesScreen = await _open(Kit.profile(1, 1, {&"bakery": 1}))
	var by_id: Dictionary = {}
	for machine: ToyMachineView in screen.machines():
		by_id[machine.aisle().id] = machine.capsule_count()
		var slots: Array[Vector2i] = machine.cabinet().slots
		var capsules: Array[TextureRect] = machine.capsules()
		for index: int in capsules.size():
			var at: Vector2 = capsules[index].position / ArtStyle.ART_SCALE
			assert_bool(Vector2i(at) == slots[index]).is_true()
	assert_int(by_id[&"cold_cases"]).is_equal(2)
	assert_int(by_id[&"household"]).is_equal(3)
	assert_int(by_id[&"bakery"]).is_equal(7)
	assert_int(by_id[&"fruit_and_veg"]).is_equal(8)
	assert_int(by_id[&"snacks"]).is_equal(7)


func test_zero_coins_shuts_the_slots_and_shows_the_notice() -> void:
	var screen: ToyMachinesScreen = await _open(Kit.profile(0, 3, {&"snacks": 1, &"pantry": 2}))
	for machine: ToyMachineView in screen.machines():
		assert_object(_lamp(screen, machine).texture).is_same(ToyExitArt.lamp("off"))
		assert_int(machine.mouse_default_cursor_shape).is_equal(Control.CURSOR_ARROW)
		assert_int(machine.tone()).is_equal(ToyCabinet.Tone.DIM)
		if machine.state() == CapsuleCounter.State.EMPTY:
			continue
		assert_int(machine.state()).is_equal(CapsuleCounter.State.BROKE)
		assert_bool(machine.part("lid").visible).is_true()
		assert_bool(machine.part("padlock").visible).is_true()
		assert_bool(machine.part("coin").visible).is_false()
		assert_bool(machine.price_label().visible).is_true()
	assert_int(screen.strip_kind()).is_equal(ToyMachinesScreen.Strip.BROKE)
	assert_str(screen.strip().text()).is_equal(
		" ".join(PixelLine.split(ToyMachinesScreen.BROKE_NOTICE))
	)
	assert_str(screen.coins_text()).is_equal("0")


func test_cant_save_switches_every_machine_off() -> void:
	var profile: ProfileState = Kit.profile(4, 3, {&"cold_cases": 2})
	var counter: CapsuleCounter = CapsuleCounter.new(
		profile, SaveService.new(_folder), Kit.balance(), Kit.event_log(), false, false
	)
	var screen: ToyMachinesScreen = await _open_counter(counter, Kit.balance())
	for machine: ToyMachineView in screen.machines():
		assert_int(machine.state()).is_equal(CapsuleCounter.State.OFF)
		assert_int(machine.tone()).is_equal(ToyCabinet.Tone.OFF)
		assert_bool(machine.paper().visible).is_true()
		assert_bool(machine.part("lid").visible).is_true()
		assert_bool(machine.price_label().visible).is_false()
		var tape: Rect2 = machine.paper().get_global_rect()
		assert_bool(Kit.SCREEN_RECT.encloses(tape)).is_true()
		assert_bool(machine.hit_rect().encloses(tape)).is_true()
		# Its tape crosses the window's middle.
		var window: Rect2i = machine.cabinet().window
		var middle: float = machine.global_position.y + (window.get_center().y) * 2.0
		assert_float(absf(tape.get_center().y - middle)).is_less_equal(4.0)
		# No lineup over an OUT OF ORDER machine.
		machine._on_hover(true)
		assert_bool(screen.lineup().visible).is_false()
		machine._on_hover(false)
	assert_str(screen.coins_text()).is_equal(ToyMachinesScreen.UNKNOWN_COINS)
	assert_int(screen.strip_kind()).is_equal(ToyMachinesScreen.Strip.OFF)
	assert_str(screen.figurines_text()).is_equal("2/30")


func test_the_full_collection() -> void:
	var screen: ToyMachinesScreen = await _open(Kit.profile(5, 9, Kit.full_counts()))
	for machine: ToyMachineView in screen.machines():
		assert_int(machine.state()).is_equal(CapsuleCounter.State.EMPTY)
		assert_bool(machine.part("sold_out").visible).is_true()
		assert_str(machine.floor_text()).is_equal(ToyMachineView.SOLD_OUT_TEXT)
	assert_int(screen.strip_kind()).is_equal(ToyMachinesScreen.Strip.COMPLETE)
	var rows: Array[PixelLine] = screen.strip().rows()
	assert_str(rows[0].text()).is_equal(ToyMachinesScreen.FULL_BANNER)
	assert_str(rows[1].text()).is_equal(ToyMachinesScreen.FULL_HINT)
	assert_str(screen.figurines_text()).is_equal("30/30")
	assert_bool(screen.shelf_button().visible).is_true()
	assert_bool(screen.done_button().visible).is_true()


func test_a_fresh_profile() -> void:
	var screen: ToyMachinesScreen = await _open(Kit.profile(1, 1))
	for machine: ToyMachineView in screen.machines():
		assert_int(machine.state()).is_equal(CapsuleCounter.State.OK)
		assert_object(_lamp(screen, machine).texture).is_same(ToyExitArt.lamp("on"))
	assert_str(screen.figurines_text()).is_equal("0/30")
	assert_int(screen.strip_kind()).is_equal(ToyMachinesScreen.Strip.HINT)
	assert_str(screen.strip().text()).is_equal("PICK A MACHINE: 1 COIN A CAPSULE.")


## Every aisle has a cabinet in data/toy_cabinets/: its art set in every tone, its slots inside
## the cabinet art.
func test_every_aisle_has_a_cabinet() -> void:
	for aisle: AisleDefinition in Kit.balance().aisles:
		var path: String = ToyCabinet.PATH % aisle.id
		assert_bool(ResourceLoader.exists(path)).override_failure_message(path).is_true()
		var cabinet: ToyCabinet = ToyCabinet.for_aisle(aisle.id)
		assert_str(str(cabinet.art_id)).is_equal(str(aisle.id))
		for part: String in ["cabinet", "base", "capsule_window"]:
			for tone: ToyCabinet.Tone in ToyCabinet.Tone.values():
				assert_object(cabinet.art(part, tone)).override_failure_message(part).is_not_null()
		assert_int(cabinet.slots.size()).is_greater(0)
		var art_rect: Rect2i = ToyMachineView.CABINET_RECT
		for slot: Vector2i in cabinet.slots:
			var capsule: Rect2i = Rect2i(slot, Vector2i.ONE * ToyMachineView.CAPSULE_ART)
			assert_bool(art_rect.encloses(capsule)).override_failure_message(str(slot)).is_true()
		assert_bool(art_rect.encloses(cabinet.window)).is_true()


## An aisle with no cabinet file falls back cleanly: the plain base, no cabinet top, no
## capsules, the tape still across the machine.
func test_an_aisle_without_a_cabinet_falls_back() -> void:
	var aisle: AisleDefinition = Kit.balance().aisles[0].duplicate() as AisleDefinition
	aisle.id = &"no_such_aisle"
	var machine: ToyMachineView = ToyMachineView.new()
	add_child(machine)
	auto_free(machine)
	machine.set_machine(aisle, 2, 2, CapsuleCounter.State.OFF, 1)
	# The plain base in the machine's own tone: only playable machines are lit.
	assert_object((machine.part("base") as TextureRect).texture).is_same(
		ToyMachineView.BASE_FALLBACKS[ToyCabinet.Tone.OFF]
	)
	assert_bool(machine.part("cabinet").visible).is_false()
	assert_bool(machine.part("front").visible).is_false()
	assert_int(machine.capsule_count()).is_equal(0)
	assert_bool(machine.paper().visible).is_true()
	(
		assert_bool(Rect2(Vector2.ZERO, ToyMachineView.SIZE).encloses(machine.paper().get_rect()))
		. is_true()
	)
	# With no cabinet art the tape crosses the base, not the air above it.
	var base_rect: Rect2 = (machine.part("base") as TextureRect).get_rect()
	assert_bool(base_rect.encloses(machine.paper().get_rect())).is_true()
	machine.set_machine(aisle, 2, 2, CapsuleCounter.State.BROKE, 1)
	assert_object((machine.part("base") as TextureRect).texture).is_same(
		ToyMachineView.BASE_FALLBACKS[ToyCabinet.Tone.DIM]
	)
	machine.set_machine(aisle, 2, 2, CapsuleCounter.State.OK, 1)
	assert_object((machine.part("base") as TextureRect).texture).is_same(
		ToyMachineView.BASE_FALLBACK
	)
	# Bakery has no front overlay: none is shown.
	var bakery: AisleDefinition = Kit.aisle(Kit.balance(), &"bakery")
	machine.set_machine(bakery, 8, 8, CapsuleCounter.State.OK, 1)
	assert_bool(machine.part("front").visible).is_false()
	assert_bool(machine.part("cabinet").visible).is_true()


## A machine that can't be played still shows its lineup under the pointer, but neither rises
## nor heats its lamp.
func test_hovering_an_unplayable_machine_shows_only_its_lineup() -> void:
	var screen: ToyMachinesScreen = await _open(Kit.profile(0, 3, {&"pantry": 2}))
	for id: StringName in [&"cold_cases", &"pantry"]:
		var machine: ToyMachineView = _machine(screen, id)
		assert_int(machine.state()).is_not_equal(CapsuleCounter.State.OK)
		machine._on_hover(true)
		assert_bool(screen.lineup().visible).is_true()
		assert_bool(screen.board().visible).is_false()
		assert_bool(machine.is_lifted()).is_false()
		assert_bool(machine.is_hot()).is_false()
		assert_object(_lamp(screen, machine).texture).is_same(ToyExitArt.lamp("off"))
		machine._on_hover(false)
		assert_bool(screen.lineup().visible).is_false()


## Closing and opening again rebuilds the machines and lamps with nothing hovered.
func test_reopening_starts_clean() -> void:
	var screen: ToyMachinesScreen = await _open(Kit.profile(3, 2))
	screen.machines()[2]._on_hover(true)
	assert_bool(screen.lineup().visible).is_true()
	var counter: CapsuleCounter = screen.counter()
	screen.close()
	screen.open(counter, Kit.balance())
	await await_idle_frame()
	assert_int(screen.machines().size()).is_equal(6)
	assert_int(screen.lamps().size()).is_equal(6)
	assert_bool(screen.lineup().visible).is_false()
	assert_bool(screen.board().visible).is_true()
	for machine: ToyMachineView in screen.machines():
		assert_bool(machine.is_hot()).is_false()
		assert_object(_lamp(screen, machine).texture).is_same(ToyExitArt.lamp("on"))


## A draw that leaves the machine playable cools it behind the reveal.
func test_a_draw_cools_the_picked_machine() -> void:
	var screen: ToyMachinesScreen = await _open(Kit.profile(3, 2))
	var machine: ToyMachineView = _machine(screen, &"fruit_and_veg")
	machine._on_hover(true)
	machine._gui_input(Kit.left_click())
	assert_bool(screen.reveal().visible).is_true()
	assert_int(machine.state()).is_equal(CapsuleCounter.State.OK)
	assert_bool(machine.is_hot()).is_false()
	assert_bool(machine.is_lifted()).is_false()
	assert_int((machine.part("sign") as ToyPlate).mode()).is_equal(ToyPlate.Mode.NORMAL)
	assert_object(_lamp(screen, machine).texture).is_same(ToyExitArt.lamp("on"))
	await await_idle_frame()


## The real pointer: a motion over the sign hovers the machine and a click on its floor plate
## picks it.
func test_the_pointer_hovers_and_picks_through_the_viewport() -> void:
	var screen: ToyMachinesScreen = await _open(Kit.profile(3, 2))
	var machine: ToyMachineView = screen.machines()[1]
	var hovers: Array[bool] = []
	machine.hover_changed.connect(
		func(_view: ToyMachineView, inside: bool) -> void: hovers.append(inside)
	)
	var picks: Array[AisleDefinition] = []
	machine.picked.connect(func(aisle: AisleDefinition) -> void: picks.append(aisle))
	var sign_point: Vector2 = machine.sign_rect().get_center()
	assert_bool(machine.hit_rect().has_point(sign_point)).is_true()
	await _move(sign_point)
	assert_array(hovers).contains_exactly([true])
	assert_bool(machine.is_hot()).is_true()
	var floor_point: Vector2 = machine.part("floor").get_global_rect().get_center()
	await _move(floor_point)
	assert_bool(machine.is_hot()).is_true()
	_click(floor_point)
	await await_idle_frame()
	assert_int(picks.size()).is_equal(1)
	assert_object(picks[0]).is_same(machine.aisle())
	# The reveal covers the machine: the pointer leaves it.
	await _move(floor_point + Vector2(2, 0))
	assert_bool(hovers.has(false)).is_true()


## Left and Right pick a machine as the pointer would (wrapping); Escape lets it go.
func test_the_arrow_keys_pick_a_machine() -> void:
	var screen: ToyMachinesScreen = await _open(Kit.profile(3, 2))
	var machines: Array[ToyMachineView] = screen.machines()
	screen._unhandled_key_input(Kit.key(KEY_RIGHT))
	assert_bool(machines[0].is_selected()).is_true()
	assert_bool(machines[0].is_hot()).is_true()
	assert_bool(machines[0].is_lifted()).is_true()
	assert_bool(screen.lineup().visible).is_true()
	assert_object(_lamp(screen, machines[0]).texture).is_same(ToyExitArt.lamp("hot"))
	screen._unhandled_key_input(Kit.key(KEY_LEFT))
	assert_bool(machines[0].is_hot()).is_false()
	assert_bool(machines[-1].is_hot()).is_true()
	screen._unhandled_key_input(Kit.key(KEY_RIGHT))
	assert_bool(machines[0].is_hot()).is_true()
	assert_bool(machines[-1].is_selected()).is_false()
	screen._unhandled_key_input(Kit.key(KEY_ESCAPE))
	for machine: ToyMachineView in machines:
		assert_bool(machine.is_hot()).is_false()
	assert_bool(screen.lineup().visible).is_false()
	assert_bool(screen.board().visible).is_true()


func _move(at: Vector2) -> void:
	var motion: InputEventMouseMotion = InputEventMouseMotion.new()
	motion.position = at
	motion.global_position = at
	get_tree().root.push_input(motion, true)
	for frame: int in range(2):
		await await_idle_frame()


func _click(at: Vector2) -> void:
	for pressed: bool in [true, false]:
		var press: InputEventMouseButton = InputEventMouseButton.new()
		press.button_index = MOUSE_BUTTON_LEFT
		press.pressed = pressed
		press.position = at
		press.global_position = at
		get_tree().root.push_input(press, true)


func _machine(screen: ToyMachinesScreen, id: StringName) -> ToyMachineView:
	for machine: ToyMachineView in screen.machines():
		if machine.aisle().id == id:
			return machine
	return null


func _lamp(screen: ToyMachinesScreen, machine: ToyMachineView) -> TextureRect:
	return screen.lamps()[screen.machines().find(machine)]


func _open(profile: ProfileState) -> ToyMachinesScreen:
	var counter: CapsuleCounter = CapsuleCounter.new(
		profile, SaveService.new(_folder), Kit.balance(), Kit.event_log(), false, true
	)
	return await _open_counter(counter, Kit.balance())


func _open_counter(counter: CapsuleCounter, balance: BalanceDefinition) -> ToyMachinesScreen:
	var screen: ToyMachinesScreen = ToyMachinesScreen.new()
	add_child(screen)
	auto_free(screen)
	screen.open(counter, balance)
	for frame: int in range(3):
		await await_idle_frame()
	return screen
