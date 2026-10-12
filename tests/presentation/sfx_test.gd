extends GdUnitTestSuite
## Sfx (presentation/sfx.gd): every sound in audio/sfx/ loads, and the count-up's note ladder
## (#60, D1) climbs G4 to G6 in strictly rising pitches on one monophonic note player.

const RecordingSfx := preload("res://tests/presentation/recording_sfx.gd")

var _folder: String = ""


func before_test() -> void:
	# Sfx writes nothing, but no test may touch the real log or saves.
	_folder = "user://test_logs_%d" % Time.get_ticks_usec()
	_event_log().use_folder(_folder)
	ProjectSettings.set_setting(SaveService.FOLDER_SETTING, _folder)


func after_test() -> void:
	ProjectSettings.set_setting(SaveService.FOLDER_SETTING, null)
	if DirAccess.dir_exists_absolute(_folder):
		for file_name: String in DirAccess.get_files_at(_folder):
			DirAccess.remove_absolute(_folder.path_join(file_name))
		DirAccess.remove_absolute(_folder)


## Every name in SOUNDS is a WAV that loads (a missing one would print a Godot error and fail
## the run), and every WAV in the folder is in SOUNDS.
func test_every_sound_loads() -> void:
	var wavs: Array[String] = []
	for file_name: String in DirAccess.get_files_at(Sfx.FOLDER):
		if file_name.get_extension() == "wav":
			wavs.append(file_name.get_basename())
	assert_array(wavs).contains_exactly_in_any_order(Sfx.SOUNDS)
	assert_array(Sfx.SOUNDS).contains(["ding", Sfx.NOTE_SOUND])
	for sound: String in Sfx.SOUNDS:
		var path: String = "%s/%s.wav" % [Sfx.FOLDER, sound]
		assert_bool(ResourceLoader.exists(path)).override_failure_message(path).is_true()
		assert_object(load(path)).override_failure_message(path).is_instanceof(AudioStreamWAV)


## The ladder is the agreed G4 A4 C5 D5 E5 G5 A5 C6 D6 E6 G6 (D1), and play_note 0..10 sets
## strictly rising pitches from 0.5 (G4) to 2.0 (G6), each the equal-tempered ratio of its note.
func test_notes_climb_from_g4_to_g6() -> void:
	# Semitones above G4, written out here so the test pins the agreed notes, not the code's own.
	var agreed: Array[int] = [0, 2, 5, 7, 9, 12, 14, 17, 19, 21, 24]
	assert_array(Sfx.LADDER_SEMITONES).is_equal(agreed)
	var sfx: Sfx = await _sfx()
	assert_int(sfx.note_count()).is_equal(agreed.size())
	var last: float = 0.0
	for index: int in range(sfx.note_count()):
		sfx.play_note(index)
		var pitch: float = _note_player(sfx).pitch_scale
		assert_float(pitch).is_greater(last)
		var expected: float = pow(2.0, (agreed[index] - 12) / 12.0)
		assert_float(pitch).is_equal_approx(expected, 0.0001)
		assert_float(sfx.note_pitch(index)).is_equal_approx(pitch, 0.0001)
		last = pitch
	sfx.play_note(0)
	assert_float(_note_player(sfx).pitch_scale).is_equal_approx(0.5, 0.0001)
	sfx.play_note(sfx.note_count() - 1)
	assert_float(_note_player(sfx).pitch_scale).is_equal_approx(2.0, 0.0001)


## An index outside the ladder plays its nearest end: never below G4, never above G6.
func test_out_of_range_notes_clamp_to_the_ladder() -> void:
	var sfx: Sfx = await _sfx()
	sfx.play_note(-3)
	assert_float(_note_player(sfx).pitch_scale).is_equal_approx(0.5, 0.0001)
	sfx.play_note(sfx.note_count())
	assert_float(_note_player(sfx).pitch_scale).is_equal_approx(2.0, 0.0001)
	sfx.play_note(99)
	assert_float(_note_player(sfx).pitch_scale).is_equal_approx(2.0, 0.0001)


## Notes are monophonic: however many play, they all go to the one note player (the newest
## replaces the last), and none of them takes a player from the pool.
func test_notes_play_on_one_player_outside_the_pool() -> void:
	var sfx: Sfx = await _sfx()
	assert_int(_players(sfx).size()).is_equal(Sfx.POOL_SIZE + 1)
	sfx.play("scan")
	for index: int in [0, 4, 7, 2]:
		sfx.play_note(index, -6.0)
	var note_players: Array[AudioStreamPlayer] = _players_with(sfx, Sfx.NOTE_SOUND)
	assert_int(note_players.size()).is_equal(1)
	assert_object(note_players[0]).is_same(_note_player(sfx))
	assert_float(note_players[0].pitch_scale).is_equal_approx(sfx.note_pitch(2), 0.0001)
	assert_float(note_players[0].volume_db).is_equal(-6.0)
	assert_int(_players_with(sfx, "scan").size()).is_equal(1)
	var used: int = 0
	for player: AudioStreamPlayer in _players(sfx):
		if player.stream != null:
			used += 1
	assert_int(used).is_equal(2)


## `bonus` through play still uses the pool, so it doesn't cut the note.
func test_playing_bonus_does_not_cut_the_note() -> void:
	var sfx: Sfx = await _sfx()
	sfx.play_note(3)
	sfx.play(Sfx.NOTE_SOUND, 1.5)
	assert_int(_players_with(sfx, Sfx.NOTE_SOUND).size()).is_equal(2)
	assert_float(_note_player(sfx).pitch_scale).is_equal_approx(sfx.note_pitch(3), 0.0001)


## The recording double that tests use in place of Sfx records what was played and still plays it.
func test_recording_sfx_records_sounds_and_notes() -> void:
	var sfx: RecordingSfx = auto_free(RecordingSfx.new())
	add_child(sfx)
	await get_tree().process_frame
	sfx.play("tick", 1.0, -8.0)
	sfx.play_note(5)
	sfx.play_note(40, -10.0)
	assert_int(sfx.sounds.size()).is_equal(1)
	var now_usec: int = Time.get_ticks_usec()
	var played: Dictionary = sfx.sounds[0].duplicate()
	assert_int(int(played["usec"])).is_greater(0)
	assert_int(int(played["usec"])).is_less_equal(now_usec)
	played.erase("usec")
	assert_dict(played).is_equal({"sound": "tick", "pitch": 1.0, "volume_db": -8.0})
	assert_array(sfx.note_indices()).is_equal([5, 40])
	assert_float(float(sfx.notes[1]["volume_db"])).is_equal(-10.0)
	assert_float(_note_player(sfx).pitch_scale).is_equal_approx(2.0, 0.0001)


func _sfx() -> Sfx:
	var sfx: Sfx = auto_free(Sfx.new())
	add_child(sfx)
	await get_tree().process_frame
	return sfx


## The players Sfx made, in order: the pool, then the note player.
func _players(sfx: Sfx) -> Array[AudioStreamPlayer]:
	var players: Array[AudioStreamPlayer] = []
	for child: Node in sfx.get_children():
		if child is AudioStreamPlayer:
			players.append(child as AudioStreamPlayer)
	return players


func _note_player(sfx: Sfx) -> AudioStreamPlayer:
	return _players(sfx)[Sfx.POOL_SIZE]


func _players_with(sfx: Sfx, sound: String) -> Array[AudioStreamPlayer]:
	var stream: AudioStream = load("%s/%s.wav" % [Sfx.FOLDER, sound])
	var players: Array[AudioStreamPlayer] = []
	for player: AudioStreamPlayer in _players(sfx):
		if player.stream == stream:
			players.append(player)
	return players


static func _event_log() -> EventLogService:
	return (Engine.get_main_loop() as SceneTree).root.get_node("/root/EventLog")
