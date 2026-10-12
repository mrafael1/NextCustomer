extends GdUnitTestSuite
## The Music autoload (#62, Q2, Q6, Q8): the bus layout (Master, Music about 9 dB under SFX),
## the autoload loading without errors, both tracks imported to loop from 0, the crossfade and
## no restart on the same track, ducking the Music bus over frames and back, and the fallback on
## the players' volume_db without the bus. Each test plays on its own MusicService with streaming
## off (except the one that plays the real files) and puts the Music bus back as it found it.

const MUSIC_SCRIPT := preload("res://presentation/music.gd")
## Slack for frame timing in the headless runner, in seconds.
const SLACK_S := 0.1

var _errors: Array[String] = []
var _bus_db: float = 0.0


func before_test() -> void:
	_errors = []
	# A screen test may have left the autoload ducked or mid-tween.
	_autoload().unduck(0.0)
	_bus_db = AudioServer.get_bus_volume_db(_music_bus())


func after_test() -> void:
	AudioServer.set_bus_volume_db(_music_bus(), _bus_db)


func test_the_bus_layout_has_master_music_and_sfx() -> void:
	assert_int(AudioServer.get_bus_index(&"Master")).is_equal(0)
	assert_int(_music_bus()).is_greater(0)
	var sfx: int = AudioServer.get_bus_index(&"SFX")
	assert_int(sfx).is_greater(0)
	var under_sfx: float = AudioServer.get_bus_volume_db(sfx) - _bus_db
	assert_float(under_sfx).is_between(8.0, 10.0)
	assert_str(AudioServer.get_bus_send(_music_bus())).is_equal("Master")
	assert_str(AudioServer.get_bus_send(sfx)).is_equal("Master")
	var layout: AudioBusLayout = load("res://default_bus_layout.tres")
	assert_object(layout).is_not_null()


func test_the_autoload_loads_on_the_music_bus() -> void:
	var music: MusicService = _autoload()
	assert_object(music).is_not_null()
	assert_bool(music.ducks_bus()).is_true()
	assert_float(music.base_db()).is_equal_approx(_bus_db, 0.01)
	# Headless runs have no audio output: the autoload plays no stream there (none leaks at exit).
	assert_bool(music.streaming).is_equal(DisplayServer.get_name() != "headless")
	for player: Node in music.get_children():
		assert_str(str((player as AudioStreamPlayer).bus)).is_equal("Music")


## The swap contract: any track that replaces a file keeps its .import (loop on, offset 0);
## its length is free (the loops are still being auditioned).
func test_both_tracks_loop_from_the_start() -> void:
	for track: StringName in MusicService.TRACKS:
		var stream: AudioStreamOggVorbis = load(MusicService.TRACKS[track]) as AudioStreamOggVorbis
		assert_bool(stream != null).override_failure_message(str(track)).is_true()
		assert_bool(stream.loop).override_failure_message(str(track)).is_true()
		assert_float(stream.loop_offset).is_equal(0.0)
		assert_float(stream.get_length()).is_greater(0.0)


## The real files: the track loads and its player plays on the Music bus; stop() stops it.
func test_play_streams_the_track_on_the_music_bus() -> void:
	var music: MusicService = await _music(true)
	music.play(&"front")
	var player: AudioStreamPlayer = music.player_for(&"front")
	assert_object(player).is_not_null()
	assert_bool(player.stream is AudioStreamOggVorbis).is_true()
	assert_bool(player.playing).is_true()
	assert_str(str(player.bus)).is_equal("Music")
	music.stop()
	assert_bool(player.playing).is_false()
	assert_str(str(music.current_track())).is_equal("")
	assert_array(_errors).is_empty()


## A track fades in over CROSSFADE_S; asking for it again changes nothing; another track
## crossfades with equal power and the old one stops at the end.
func test_play_crossfades_and_never_restarts_the_same_track() -> void:
	var music: MusicService = await _music()
	assert_str(str(music.current_track())).is_equal("")
	music.play(&"front")
	assert_str(str(music.current_track())).is_equal("front")
	assert_int(music.track_starts).is_equal(1)
	assert_float(music.track_gain(&"front")).is_equal(0.0)
	await _seconds(MusicService.CROSSFADE_S / 2.0)
	assert_float(music.track_gain(&"front")).is_between(0.2, 0.99)
	await _seconds(MusicService.CROSSFADE_S / 2.0 + SLACK_S)
	assert_float(music.track_gain(&"front")).is_equal(1.0)
	assert_bool(music.is_fading()).is_false()

	music.play(&"front")
	assert_int(music.track_starts).is_equal(1)
	assert_bool(music.is_fading()).is_false()
	assert_float(music.track_gain(&"front")).is_equal(1.0)

	music.play(&"shift")
	assert_int(music.track_starts).is_equal(2)
	assert_str(str(music.current_track())).is_equal("shift")
	var mid_seen: bool = false
	var took: float = 0.0
	while music.is_fading():
		var rise: float = music.track_gain(&"shift")
		var fall: float = music.track_gain(&"front")
		if rise > 0.3 and fall > 0.3:
			mid_seen = true
			# Equal power: the two gains' squares add up to about 1 all the way.
			assert_float(rise * rise + fall * fall).is_between(0.9, 1.1)
		await get_tree().process_frame
		took += get_process_delta_time()
	assert_bool(mid_seen).is_true()
	assert_float(took).is_between(
		MusicService.CROSSFADE_S - SLACK_S, MusicService.CROSSFADE_S + SLACK_S
	)
	assert_float(music.track_gain(&"shift")).is_equal(1.0)
	assert_float(music.track_gain(&"front")).is_equal(0.0)
	assert_object(music.player_for(&"front")).is_null()
	assert_array(_errors).is_empty()


## A New run click inside the results crossfade asks for the shift loop while it still fades
## out: it fades back up from its gain on the same player instead of restarting from silence.
func test_a_track_still_fading_out_fades_back_up() -> void:
	var music: MusicService = await _music()
	music.play(&"shift")
	await _seconds(MusicService.CROSSFADE_S + SLACK_S)
	var shift_player: AudioStreamPlayer = music.player_for(&"shift")
	music.play(&"front")
	await _seconds(MusicService.CROSSFADE_S / 3.0)
	var faded_to: float = music.track_gain(&"shift")
	assert_float(faded_to).is_between(0.2, 0.99)
	music.play(&"shift")
	assert_str(str(music.current_track())).is_equal("shift")
	assert_int(music.track_starts).is_equal(2)
	assert_object(music.player_for(&"shift")).is_same(shift_player)
	assert_float(music.track_gain(&"shift")).is_greater_equal(faded_to - 0.01)
	await _seconds(MusicService.CROSSFADE_S + SLACK_S)
	assert_float(music.track_gain(&"shift")).is_equal(1.0)
	assert_object(music.player_for(&"front")).is_null()
	assert_array(_errors).is_empty()


func test_an_unknown_track_is_reported_and_changes_nothing() -> void:
	var music: MusicService = await _music()
	music.play(&"front")
	music.play(&"polka")
	assert_array(_errors).has_size(1)
	assert_str(_errors[0]).contains("polka")
	assert_str(str(music.current_track())).is_equal("front")


## duck() lowers the Music bus over its fade, frame by frame, to its depth under the normal
## level; unduck() brings it back to exactly the normal level.
func test_duck_then_unduck_moves_the_music_bus_over_frames_and_restores_it() -> void:
	var music: MusicService = await _music()
	music.play(&"shift")
	var base: float = music.base_db()
	music.duck(-24.0, 0.12)
	assert_bool(music.is_ducked()).is_true()
	var frames: Array[float] = await _bus_over(0.12 + SLACK_S)
	_assert_monotonic(frames, -1.0)
	assert_float(frames[0]).is_greater(base - 24.0)
	assert_float(_bus_now()).is_equal_approx(base - 24.0, 0.01)
	assert_float(music.duck_db()).is_equal_approx(-24.0, 0.01)
	music.unduck(0.6)
	assert_bool(music.is_ducked()).is_false()
	frames = await _bus_over(0.3)
	_assert_monotonic(frames, 1.0)
	# Halfway back, not there yet.
	assert_float(_bus_now()).is_between(base - 20.0, base - 4.0)
	await _seconds(0.3 + SLACK_S)
	assert_float(_bus_now()).is_equal_approx(base, 0.01)
	assert_float(music.duck_db()).is_equal(0.0)
	# The track's own volume never moved: the bus carries the duck.
	assert_float(music.player_for(&"shift").volume_db).is_equal_approx(0.0, 0.01)


## An unduck after a delay holds the duck first, and a new duck cancels a pending unduck.
func test_a_delayed_unduck_holds_the_duck_first() -> void:
	var music: MusicService = await _music()
	var base: float = music.base_db()
	music.duck(-18.0, 0.0)
	assert_float(_bus_now()).is_equal_approx(base - 18.0, 0.01)
	music.unduck(0.2, 0.3)
	await _seconds(0.2)
	assert_float(_bus_now()).is_equal_approx(base - 18.0, 0.01)
	await _seconds(0.3 + SLACK_S)
	assert_float(_bus_now()).is_equal_approx(base, 0.01)
	music.unduck(0.2, 0.3)
	music.duck(-24.0, 0.0)
	await _seconds(0.5 + SLACK_S)
	assert_float(_bus_now()).is_equal_approx(base - 24.0, 0.01)
	music.unduck(0.0)
	assert_float(_bus_now()).is_equal_approx(base, 0.01)


## Without its bus (reported once), the same calls duck the players' own volume_db and leave
## the Music bus alone.
func test_without_the_bus_the_players_carry_the_duck() -> void:
	var music: MusicService = await _music(false, &"NoSuchBus")
	assert_array(_errors).has_size(1)
	assert_str(_errors[0]).contains("NoSuchBus")
	assert_bool(music.ducks_bus()).is_false()
	music.play(&"front")
	await _seconds(MusicService.CROSSFADE_S + SLACK_S)
	var player: AudioStreamPlayer = music.player_for(&"front")
	assert_float(player.volume_db).is_equal_approx(0.0, 0.01)
	music.duck(-24.0, 0.12)
	await _seconds(0.12 + SLACK_S)
	assert_float(player.volume_db).is_equal_approx(-24.0, 0.01)
	assert_float(_bus_now()).is_equal_approx(_bus_db, 0.01)
	music.unduck(0.0)
	assert_float(player.volume_db).is_equal_approx(0.0, 0.01)
	assert_array(_errors).has_size(1)


## A fresh MusicService in the tree, reporting into _errors, after two frames (so a slow frame
## before the test doesn't count as tween time).
func _music(streaming: bool = false, bus_name: StringName = MusicService.BUS) -> MusicService:
	var music: MusicService = MUSIC_SCRIPT.new()
	music.streaming = streaming
	music.bus_name = bus_name
	music.report_error = func(message: String) -> void: _errors.append(message)
	add_child(music)
	auto_free(music)
	await get_tree().process_frame
	await get_tree().process_frame
	return music


## The Music bus volume on every frame for `seconds` of process time (the tweens' time).
func _bus_over(seconds: float) -> Array[float]:
	var frames: Array[float] = []
	var elapsed: float = 0.0
	while elapsed < seconds:
		frames.append(_bus_now())
		await get_tree().process_frame
		elapsed += get_process_delta_time()
	frames.append(_bus_now())
	return frames


## Every frame moves in `direction` (-1 down, 1 up) or stays.
func _assert_monotonic(frames: Array[float], direction: float) -> void:
	assert_int(frames.size()).is_greater(2)
	for index: int in range(1, frames.size()):
		var step: float = (frames[index] - frames[index - 1]) * direction
		assert_float(step).override_failure_message(str(frames)).is_greater_equal(-0.001)


## Waits `seconds` of process time (the tweens' time, not the wall clock's).
func _seconds(seconds: float) -> void:
	var elapsed: float = 0.0
	while elapsed < seconds:
		await get_tree().process_frame
		elapsed += get_process_delta_time()


static func _bus_now() -> float:
	return AudioServer.get_bus_volume_db(_music_bus())


static func _music_bus() -> int:
	return AudioServer.get_bus_index(MusicService.BUS)


static func _autoload() -> MusicService:
	return (Engine.get_main_loop() as SceneTree).root.get_node("/root/Music")
