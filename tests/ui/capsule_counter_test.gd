extends GdUnitTestSuite
## The TOY MACHINES' counter (#63, CapsuleCounter): a draw saves the profile at once and logs the
## `capsule` event; the first draw seeds the profile; a save that fails rolls the draw back,
## switches the machines off and leaves one reported error (the save service's); the machine
## states; the same seed and draws give the same capsule. Saves and logs go to a temporary
## folder, never the real ones.

const BALANCE := "res://data/balance/balance.tres"

var _folder: String = ""
var _errors: Array[String] = []


func before_test() -> void:
	_folder = "user://test_capsules_%d" % Time.get_ticks_usec()
	_errors.clear()
	_event_log().use_folder(_folder)
	ProjectSettings.set_setting(SaveService.FOLDER_SETTING, _folder)


func after_test() -> void:
	ProjectSettings.set_setting(SaveService.FOLDER_SETTING, null)
	_remove(_folder)


func test_a_draw_saves_the_profile_and_logs_the_capsule() -> void:
	var balance: BalanceDefinition = load(BALANCE)
	var profile: ProfileState = ProfileState.new()
	profile.coins = 2
	profile.run_count = 3
	var counter: CapsuleCounter = _counter(profile, _saves(_folder), false)
	var bakery: AisleDefinition = _aisle(balance, &"bakery")
	assert_int(counter.machine_state(bakery)).is_equal(CapsuleCounter.State.OK)
	var card: CardDefinition = counter.draw(bakery)
	assert_str(String(card.id)).is_equal("baguette")
	assert_bool(profile.has_capsule_seed).is_true()
	assert_int(profile.capsule_draws).is_equal(1)
	assert_int(profile.coins).is_equal(2 - balance.capsule_price)
	assert_int(profile.unlocked_items[&"baguette"]).is_equal(2)
	assert_int(counter.items_left(bakery)).is_equal(7)
	# The file holds the draw.
	var saved: ProfileState = _saves(_folder).load_profile()
	assert_dict(saved.to_dictionary()).is_equal(profile.to_dictionary())
	assert_str(saved.to_dictionary()["capsule_seed"]).is_equal(str(profile.capsule_seed))
	# The capsule event, with the seed that was just made.
	var event: Dictionary = _last_event("capsule")
	assert_str(event["machine"]).is_equal("bakery")
	assert_str(event["item"]).is_equal("baguette")
	assert_int(int(event["run_index"])).is_equal(2)
	assert_int(int(event["coins_left"])).is_equal(profile.coins)
	assert_int(int(event["draw"])).is_equal(0)
	assert_str(event["capsule_seed"]).is_equal(str(profile.capsule_seed))
	assert_array(_errors).is_empty()


## A later draw uses the profile's seed and the next stream, never a new seed.
func test_later_draws_keep_the_seed_and_use_the_next_stream() -> void:
	var balance: BalanceDefinition = load(BALANCE)
	var profile: ProfileState = ProfileState.new()
	profile.coins = 3
	profile.set_capsule_seed(123456)
	profile.unlocked_items[&"baguette"] = 0
	profile.capsule_draws = 4
	var counter: CapsuleCounter = _counter(profile, _saves(_folder), true)
	var bakery: AisleDefinition = _aisle(balance, &"bakery")
	var expected: CardDefinition = CapsuleDraw.draw(
		bakery, profile.unlocked_items.duplicate(), EventLogService.capsule_stream(123456, 4)
	)
	var card: CardDefinition = counter.draw(bakery)
	assert_object(card).is_same(expected)
	assert_int(profile.capsule_seed).is_equal(123456)
	assert_int(int(_last_event("capsule")["draw"])).is_equal(4)
	assert_str(_last_event("capsule")["capsule_seed"]).is_equal("123456")
	# A title draw while a run is saved: the saved run's index and its stock line.
	assert_int(profile.unlocked_items[card.id]).is_equal(0)
	assert_str(counter.stock_line()).is_equal(CapsuleCounter.AFTER_SAVED_RUN_LINE)


## The same seed and draw count on a fresh copy of the profile give the same capsule.
func test_the_same_seed_and_draws_give_the_same_capsule() -> void:
	var balance: BalanceDefinition = load(BALANCE)
	var snacks: AisleDefinition = _aisle(balance, &"snacks")
	var items: Array[String] = []
	for attempt: int in range(2):
		var profile: ProfileState = ProfileState.new()
		profile.coins = 2
		profile.set_capsule_seed(99)
		var counter: CapsuleCounter = _counter(
			profile, _saves(_folder.path_join(str(attempt))), false
		)
		counter.draw(snacks)
		items.append(String(counter.draw(snacks).id))
	assert_str(items[0]).is_equal(items[1])
	assert_str(items[0]).is_not_equal("crisps")


## A save that fails: the draw is rolled back (the profile exactly as before), the machines go
## OFF, switched_off is emitted, and the only error is the save service's.
func test_a_failed_save_rolls_back_and_switches_the_machines_off() -> void:
	var balance: BalanceDefinition = load(BALANCE)
	# A folder where the temporary file would go: it can't be opened for writing.
	var saves: SaveService = _saves(_folder)
	DirAccess.make_dir_recursive_absolute(saves.profile_path() + SaveService.TEMP_SUFFIX)
	var profile: ProfileState = ProfileState.new()
	profile.coins = 1
	profile.run_count = 1
	var before_draw: Dictionary = profile.to_dictionary()
	var counter: CapsuleCounter = _counter(profile, saves, false)
	var switched: Array[int] = [0]
	counter.switched_off.connect(func() -> void: switched[0] += 1)
	var pantry: AisleDefinition = _aisle(balance, &"pantry")
	assert_object(counter.draw(pantry)).is_null()
	assert_dict(profile.to_dictionary()).is_equal(before_draw)
	assert_int(switched[0]).is_equal(1)
	assert_bool(counter.can_save()).is_false()
	assert_int(counter.machine_state(pantry)).is_equal(CapsuleCounter.State.OFF)
	assert_int(_errors.size()).is_equal(1)
	assert_dict(_last_event("capsule")).is_empty()
	# Switched off: no more draws, nothing more reported.
	assert_object(counter.draw(pantry)).is_null()
	assert_int(_errors.size()).is_equal(1)


func test_the_machine_states() -> void:
	var balance: BalanceDefinition = load(BALANCE)
	var profile: ProfileState = ProfileState.new()
	var cold: AisleDefinition = _aisle(balance, &"cold_cases")
	var counter: CapsuleCounter = _counter(profile, _saves(_folder), false)
	assert_int(counter.machine_state(cold)).is_equal(CapsuleCounter.State.BROKE)
	assert_object(counter.draw(cold)).is_null()
	profile.coins = 1
	assert_int(counter.machine_state(cold)).is_equal(CapsuleCounter.State.OK)
	profile.unlocked_items = {&"cream": 0, &"ham_ends": 0}
	assert_int(counter.machine_state(cold)).is_equal(CapsuleCounter.State.EMPTY)
	assert_int(counter.price()).is_equal(balance.capsule_price)
	assert_str(counter.stock_line()).is_equal(CapsuleCounter.NEXT_RUN_LINE)
	var off: CapsuleCounter = CapsuleCounter.new(
		profile, _saves(_folder), balance, _event_log(), false, false
	)
	assert_int(off.machine_state(_aisle(balance, &"pantry"))).is_equal(CapsuleCounter.State.OFF)


## The debug draw (no spend) takes the same path: the coins stay, the debug event is logged.
func test_a_debug_draw_spends_no_coin() -> void:
	var balance: BalanceDefinition = load(BALANCE)
	var profile: ProfileState = ProfileState.new()
	var counter: CapsuleCounter = _counter(profile, _saves(_folder), true)
	var card: CardDefinition = counter.draw(_aisle(balance, &"household"), false)
	assert_str(String(card.id)).is_equal("egg_timer")
	assert_int(profile.coins).is_equal(0)
	assert_int(profile.unlocked_items[&"egg_timer"]).is_equal(0)
	var debug: Dictionary = _last_event("debug")
	assert_str(debug["action"]).is_equal("capsule")
	assert_str(debug["item"]).is_equal("egg_timer")


func _counter(profile: ProfileState, saves: SaveService, saved_run: bool) -> CapsuleCounter:
	return CapsuleCounter.new(profile, saves, load(BALANCE), _event_log(), saved_run, true)


func _saves(folder: String) -> SaveService:
	return SaveService.new(folder, func(message: String) -> void: _errors.append(message))


func _last_event(type: String) -> Dictionary:
	var found: Dictionary = {}
	for line: String in EventLogWriter.join_logs(_folder).split("\n", false):
		var event: Dictionary = JSON.parse_string(line)
		if event["type"] == type:
			found = event
	return found


static func _aisle(balance: BalanceDefinition, id: StringName) -> AisleDefinition:
	for aisle: AisleDefinition in balance.aisles:
		if aisle.id == id:
			return aisle
	return null


static func _remove(folder: String) -> void:
	if not DirAccess.dir_exists_absolute(folder):
		return
	for sub: String in DirAccess.get_directories_at(folder):
		_remove(folder.path_join(sub))
	for file_name: String in DirAccess.get_files_at(folder):
		DirAccess.remove_absolute(folder.path_join(file_name))
	DirAccess.remove_absolute(folder)


static func _event_log() -> EventLogService:
	return (Engine.get_main_loop() as SceneTree).root.get_node("/root/EventLog")
