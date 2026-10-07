extends GdUnitTestSuite
## The profile save and the run save (full build plan section 4): JSON with a format version,
## written through a temporary file, and an unreadable save reported and kept as <file>.bad.
## Every test uses its own folder and a recording error reporter, so nothing reaches Godot's
## output.

const STARTER := "res://data/decks/starter.tres"
const BALANCE := "res://data/balance/balance.tres"

var _folder: String = ""
var _errors: Array[String] = []


func before_test() -> void:
	_folder = "user://test_saves_%d" % Time.get_ticks_usec()
	_errors.clear()


func after_test() -> void:
	if DirAccess.dir_exists_absolute(_folder):
		for file_name: String in DirAccess.get_files_at(_folder):
			DirAccess.remove_absolute(_folder.path_join(file_name))
		DirAccess.remove_absolute(_folder)


func test_no_save_yet_gives_a_fresh_profile_without_an_error() -> void:
	var profile: ProfileState = _service().load_profile()
	assert_int(profile.run_count).is_equal(0)
	assert_array(_errors).is_empty()
	assert_bool(DirAccess.dir_exists_absolute(_folder)).is_false()


func test_a_saved_profile_loads_back_and_a_second_save_replaces_it() -> void:
	var service: SaveService = _service()
	var profile: ProfileState = ProfileState.new()
	profile.run_count = 2
	profile.unlocked_items[&"melon"] = 1
	assert_bool(service.save_profile(profile)).is_true()
	profile.run_count = 3
	profile.coupon_uses[&"repeat"] = 5
	assert_bool(service.save_profile(profile)).is_true()
	var read: ProfileState = service.load_profile()
	assert_dict(read.to_dictionary()).is_equal(profile.to_dictionary())
	assert_array(_errors).is_empty()
	# Only the save is left: no temporary file.
	assert_array(Array(DirAccess.get_files_at(_folder))).is_equal([SaveService.PROFILE_FILE])


func test_a_save_interrupted_before_the_move_is_read_from_the_temporary_file() -> void:
	var profile: ProfileState = ProfileState.new()
	profile.run_count = 6
	_service().save_profile(profile)
	var path: String = _service().profile_path()
	DirAccess.rename_absolute(path, path + SaveService.TEMP_SUFFIX)
	assert_int(_service().load_profile().run_count).is_equal(6)
	assert_array(_errors).is_empty()
	# The next save replaces both with one complete file.
	assert_bool(_service().save_profile(profile)).is_true()
	assert_array(Array(DirAccess.get_files_at(_folder))).is_equal([SaveService.PROFILE_FILE])


func test_the_file_is_json_with_the_format_version() -> void:
	_service().save_profile(ProfileState.new())
	var text: String = FileAccess.get_file_as_string(_service().profile_path())
	var data: Variant = JSON.parse_string(text)
	assert_bool(data is Dictionary).is_true()
	assert_int(int(data["format_version"])).is_equal(ProfileState.FORMAT_VERSION)


func test_an_unreadable_save_is_reported_kept_and_replaced_by_a_fresh_profile() -> void:
	var newer: String = JSON.stringify({"format_version": ProfileState.FORMAT_VERSION + 1})
	var names: Array[String] = [".bad", ".bad.2", ".bad.3", ".bad.4"]
	var texts: Array[String] = ["{not json", "[1, 2]", "", newer]
	for index: int in range(texts.size()):
		var text: String = texts[index]
		_errors.clear()
		_write(text)
		var profile: ProfileState = _service().load_profile()
		assert_int(profile.run_count).override_failure_message(text).is_equal(0)
		assert_int(_errors.size()).override_failure_message(text).is_equal(1)
		var backup: String = _service().profile_path() + names[index]
		assert_str(_errors[0]).contains(backup)
		assert_str(FileAccess.get_file_as_string(backup)).is_equal(text)
	# The next save writes a good profile; the backup stays.
	assert_bool(_service().save_profile(ProfileState.new())).is_true()
	assert_object(ProfileState.from_dictionary(JSON.parse_string(_read()))).is_not_null()


## A backup is never overwritten: a second unreadable save gets the next free name.
func test_backups_are_numbered_and_never_overwritten() -> void:
	for text: String in ["first", "second", "third"]:
		_write(text)
		_service().load_profile()
	var backup: String = _service().profile_path() + SaveService.BACKUP_SUFFIX
	assert_str(FileAccess.get_file_as_string(backup)).is_equal("first")
	assert_str(FileAccess.get_file_as_string(backup + ".2")).is_equal("second")
	assert_str(FileAccess.get_file_as_string(backup + ".3")).is_equal("third")
	assert_int(_errors.size()).is_equal(3)


## A write that can't happen is reported and leaves the save as it was.
func test_a_failed_write_keeps_the_save() -> void:
	var profile: ProfileState = ProfileState.new()
	profile.run_count = 4
	_service().save_profile(profile)
	# A folder where the temporary file would go: it can't be opened for writing.
	DirAccess.make_dir_recursive_absolute(_service().profile_path() + SaveService.TEMP_SUFFIX)
	profile.run_count = 5
	assert_bool(_service().save_profile(profile)).is_false()
	assert_int(_errors.size()).is_equal(1)
	assert_int(_service().load_profile().run_count).is_equal(4)
	DirAccess.remove_absolute(_service().profile_path() + SaveService.TEMP_SUFFIX)


func test_the_game_folder_is_user_unless_the_setting_names_another() -> void:
	assert_str(SaveService.default_folder()).is_equal("user://")
	ProjectSettings.set_setting(SaveService.FOLDER_SETTING, _folder)
	assert_str(SaveService.default_folder()).is_equal(_folder)
	ProjectSettings.set_setting(SaveService.FOLDER_SETTING, null)
	assert_str(SaveService.default_folder()).is_equal("user://")


# --- The run save ---------------------------------------------------------------------------


func test_no_run_save_reads_as_none_without_an_error() -> void:
	assert_object(_service().load_run(_lookup())).is_null()
	assert_object(_service().peek_run(_lookup())).is_null()
	assert_array(_errors).is_empty()


func test_a_saved_run_loads_back_and_a_second_save_replaces_it() -> void:
	var service: SaveService = _service()
	var run: RunState = _run(3)
	assert_bool(service.save_run(run, "first", 100)).is_true()
	run.skip_reward()
	run.start_shift()
	run.place(run.hand()[0], 0)
	assert_bool(service.save_run(run, "first", 250)).is_true()
	var save: RunSave = service.load_run(_lookup())
	assert_object(save).is_not_null()
	assert_int(save.run.phase).is_equal(RunState.Phase.PLANNING)
	assert_int(save.run_ms).is_equal(250)
	assert_str(JSON.stringify(RunSave.to_dictionary(save.run, save.run_id, save.run_ms))).is_equal(
		JSON.stringify(RunSave.to_dictionary(run, "first", 250))
	)
	assert_array(_errors).is_empty()
	assert_array(Array(DirAccess.get_files_at(_folder))).is_equal([SaveService.RUN_FILE])
	# The run file is JSON with the run's format version, next to the profile.
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(service.run_path()))
	assert_int(int(data["format_version"])).is_equal(RunSave.FORMAT_VERSION)
	assert_str(service.run_path().get_base_dir()).is_equal(service.profile_path().get_base_dir())


func test_a_run_save_interrupted_before_the_move_is_read_from_the_temporary_file() -> void:
	_service().save_run(_run(4), "id", 0)
	var path: String = _service().run_path()
	DirAccess.rename_absolute(path, path + SaveService.TEMP_SUFFIX)
	assert_object(_service().load_run(_lookup())).is_not_null()
	assert_object(_service().peek_run(_lookup())).is_not_null()
	assert_array(_errors).is_empty()
	assert_bool(_service().save_run(_run(4), "id", 0)).is_true()
	assert_array(Array(DirAccess.get_files_at(_folder))).is_equal([SaveService.RUN_FILE])


func test_deleting_the_run_save_also_removes_a_leftover_temporary_file() -> void:
	var service: SaveService = _service()
	service.save_run(_run(5), "id", 0)
	_write_file(service.run_path() + SaveService.TEMP_SUFFIX, "partial")
	service.save_profile(ProfileState.new())
	assert_bool(service.delete_run()).is_true()
	assert_array(Array(DirAccess.get_files_at(_folder))).is_equal([SaveService.PROFILE_FILE])
	assert_object(service.load_run(_lookup())).is_null()
	# Nothing to delete is not an error.
	assert_bool(service.delete_run()).is_true()
	assert_array(_errors).is_empty()


func test_a_run_that_isnt_at_a_save_point_is_not_saved() -> void:
	var run: RunState = _run(6)
	for phase: RunState.Phase in [RunState.Phase.SCORED, RunState.Phase.WON, RunState.Phase.LOST]:
		run.phase = phase
		assert_bool(_service().save_run(run, "id", 0)).is_false()
	assert_int(_errors.size()).is_equal(3)
	assert_bool(FileAccess.file_exists(_service().run_path())).is_false()


func test_an_unreadable_run_save_is_reported_and_kept_as_numbered_backups() -> void:
	var bad_state: Dictionary = RunSave.to_dictionary(_run(7), "id", 0)
	bad_state["shift_index"] = 99
	var texts: Array[String] = ["{not json", "[1]", JSON.stringify(bad_state)]
	var names: Array[String] = [".bad", ".bad.2", ".bad.3"]
	# A bad profile's backups are numbered on their own.
	_write("bad profile")
	_service().load_profile()
	for index: int in range(texts.size()):
		_errors.clear()
		var backup: String = _service().run_path() + names[index]
		_write_file(_service().run_path(), texts[index])
		# Peeking never reports or backs up.
		assert_object(_service().peek_run(_lookup())).is_null()
		assert_array(_errors).is_empty()
		assert_bool(FileAccess.file_exists(backup)).is_false()
		assert_object(_service().load_run(_lookup())).is_null()
		assert_int(_errors.size()).is_equal(1)
		assert_str(_errors[0]).contains(backup)
		assert_str(FileAccess.get_file_as_string(backup)).is_equal(texts[index])
	assert_bool(FileAccess.file_exists(_service().profile_path() + ".bad.2")).is_false()
	# The new run's first save point writes over it.
	_errors.clear()
	assert_bool(_service().save_run(_run(7), "id", 0)).is_true()
	assert_object(_service().load_run(_lookup())).is_not_null()
	assert_array(_errors).is_empty()


## A run save that can't be backed up is kept: not saved over, not deleted, for the session.
func test_a_run_save_that_cant_be_backed_up_is_never_saved_over() -> void:
	_write_file(_service().run_path(), "{not json")
	var service: SaveService = SaveService.new(
		_folder,
		func(message: String) -> void: _errors.append(message),
		func(_from: String, _to: String) -> Error: return ERR_CANT_CREATE
	)
	assert_object(service.load_run(_lookup())).is_null()
	assert_int(_errors.size()).is_equal(1)
	assert_str(_errors[0]).contains("back it up")
	# Refused at every save point, reported once.
	assert_bool(service.save_run(_run(8), "id", 0)).is_false()
	assert_bool(service.save_run(_run(8), "id", 0)).is_false()
	assert_bool(service.delete_run()).is_false()
	assert_int(_errors.size()).is_equal(2)
	assert_str(FileAccess.get_file_as_string(service.run_path())).is_equal("{not json")
	assert_bool(FileAccess.file_exists(service.run_path() + SaveService.BACKUP_SUFFIX)).is_false()
	# The profile is protected on its own.
	assert_bool(service.save_profile(ProfileState.new())).is_true()
	assert_int(_errors.size()).is_equal(2)


func _service() -> SaveService:
	return SaveService.new(_folder, func(message: String) -> void: _errors.append(message))


func _write(text: String) -> void:
	_write_file(_service().profile_path(), text)


func _write_file(path: String, text: String) -> void:
	DirAccess.make_dir_recursive_absolute(_folder)
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	file.store_string(text)
	file.close()


## A run on its impulse rack.
static func _run(seed_value: int) -> RunState:
	var deck: DeckDefinition = load(STARTER)
	var balance: BalanceDefinition = load(BALANCE)
	var stream: RandomNumberGenerator = EventLogService.derived_stream(
		seed_value, EventLogService.IMPULSE_RACK_STREAM
	)
	return RunState.new(seed_value, deck, balance, RunStock.starting(deck, balance), stream)


static func _lookup() -> ContentLookup:
	return ContentLookup.new(load(BALANCE))


func _read() -> String:
	return FileAccess.get_file_as_string(_service().profile_path())
