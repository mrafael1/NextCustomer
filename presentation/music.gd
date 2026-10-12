class_name MusicService
extends Node
## Autoload "Music" (#62, Q2, Q6, Q8): the background music. A genuinely global service: it
## holds playback state only (the current track, its crossfade and the duck), never run state,
## and outlives the scene changes (the title screen is freed when the shift screen loads).
##
## Two players on the Music bus crossfade over CROSSFADE_S with equal power. Asking for the
## track that is already playing changes nothing, so the music carries on across screens. The
## tracks are the files in TRACKS, imported with loop on and loop offset 0 (the web build only
## loops a stream imported that way, godot#101111, and ignores the offset, godot#100955): a
## track is swapped by replacing its file and keeping its .import.
##
## Ducking lowers the Music bus by `depth_db` below its level in default_bus_layout.tres, tweened
## with AudioServer.set_bus_volume_db, and unduck() brings it back. Without that bus (reported
## once), the same calls duck the players' own volume_db instead.
##
## Browsers block audio until the first click or key press, so the title screen starts the music
## on its first input, never in _ready. Without `streaming` (headless runs, or set by a test
## before adding the node) nothing is loaded or played, but the track, fades and duck change the
## same.

const BUS := &"Music"
## The music files, by track name.
const TRACKS: Dictionary[StringName, String] = {
	&"shift": "res://audio/music/shift.ogg",
	&"front": "res://audio/music/front.ogg",
}
const CROSSFADE_S := 0.8
## A player's volume at a fade gain of 0 (linear_to_db(0) is -inf).
const SILENT_DB := -80.0

## False loads and plays no stream (the track, fades and duck still change). Off by default in
## headless runs (tests, tools): they have no audio output, and a loop still playing when they
## quit can leak its stream, since Godot frees a stopped playback on its audio thread, which may
## not run again before exit. Tests set it before the node enters the tree.
var streaming: bool = DisplayServer.get_name() != "headless"
## Tests only, set before the node enters the tree: the bus to play on and duck.
var bus_name: StringName = BUS
## Where errors go (push_error by default), so tests never print errors.
var report_error: Callable = Callable()
## How many times a track has started (a crossfade to it began).
var track_starts: int = 0
var _current: StringName = &""
var _players: Array[AudioStreamPlayer] = []
## The track each player holds (&"" for none) and its fade gain (linear, 0..1).
var _player_tracks: Array[StringName] = [&"", &""]
var _gains: PackedFloat32Array = PackedFloat32Array([0.0, 0.0])
## The player holding the current track.
var _active: int = 0
var _fade: Tween
## The gains when the running crossfade started.
var _fade_from: PackedFloat32Array = PackedFloat32Array([0.0, 0.0])
var _streams: Dictionary[StringName, AudioStream] = {}
## The bus index, or -1 (the players' volume_db carry the duck instead).
var _bus: int = -1
## The bus volume with no duck.
var _base_db: float = 0.0
## The duck now (0 for none, negative when ducked), and where its tween is going.
var _duck_db: float = 0.0
var _duck_target_db: float = 0.0
var _duck: Tween
## The running duck tween's length in seconds.
var _duck_fade_s: float = 0.0
## A delayed unduck waiting to start (the duck before it carries on meanwhile).
var _release: Tween


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_bus = AudioServer.get_bus_index(bus_name)
	if _bus >= 0:
		_base_db = AudioServer.get_bus_volume_db(_bus)
	else:
		_report("Music: no audio bus '%s'; ducking the music players instead." % bus_name)
	for index: int in range(2):
		var player: AudioStreamPlayer = AudioStreamPlayer.new()
		if _bus >= 0:
			player.bus = bus_name
		player.volume_db = SILENT_DB
		add_child(player)
		_players.append(player)


## On quitting: the players stop and let go of their streams, so no playback outlives them.
func _exit_tree() -> void:
	stop()
	_streams.clear()


## Crossfades to `track` (a TRACKS key) over CROSSFADE_S. The track already playing goes on
## untouched, and a track still fading out fades back up from where it is.
func play(track: StringName) -> void:
	if track == _current:
		return
	if not TRACKS.has(track):
		_report("Music: no track '%s'." % track)
		return
	if _player_tracks[1 - _active] == track:
		_current = track
		_active = 1 - _active
		_start_crossfade()
		return
	var stream: AudioStream = null
	if streaming:
		stream = _stream(track)
		if stream == null:
			return
	_current = track
	track_starts += 1
	_active = 1 - _active
	var incoming: AudioStreamPlayer = _players[_active]
	incoming.stop()
	incoming.stream = stream
	_player_tracks[_active] = track
	_gains[_active] = 0.0
	_apply_volumes()
	if stream != null:
		incoming.play()
	_start_crossfade()


## Lowers the music by `depth_db` (negative; 0 or more undoes the duck) below its normal level
## over `fade_s` seconds, from wherever it is. It cancels a delayed unduck. Here and in
## unduck(), a fade already heading to that level that ends sooner carries on instead.
func duck(depth_db: float, fade_s: float) -> void:
	_cancel_release()
	_tween_duck(minf(depth_db, 0.0), fade_s)


## Brings the music back to its normal level over `fade_s` seconds. With `delay_s`, the duck
## (and its fade) carries on until then.
func unduck(fade_s: float, delay_s: float = 0.0) -> void:
	_cancel_release()
	if delay_s <= 0.0:
		_tween_duck(0.0, fade_s)
		return
	_release = create_tween()
	_release.tween_interval(delay_s)
	_release.tween_callback(_tween_duck.bind(0.0, fade_s))


## Stops the music at once and forgets the track. The duck stays as it is.
func stop() -> void:
	if _fade != null:
		_fade.kill()
	_fade = null
	_current = &""
	for index: int in range(_players.size()):
		_players[index].stop()
		_players[index].stream = null
		_player_tracks[index] = &""
		_gains[index] = 0.0
	_apply_volumes()


## The track playing (or fading in), &"" for none.
func current_track() -> StringName:
	return _current


## `track`'s fade gain (linear, 0..1): 0 when no player holds it.
func track_gain(track: StringName) -> float:
	var gain: float = 0.0
	for index: int in range(_players.size()):
		if _player_tracks[index] == track and track != &"":
			gain = maxf(gain, _gains[index])
	return gain


## The player holding `track` (for tests), or null.
func player_for(track: StringName) -> AudioStreamPlayer:
	for index: int in range(_players.size()):
		if _player_tracks[index] == track and track != &"":
			return _players[index]
	return null


## True while a crossfade runs.
func is_fading() -> bool:
	return _fade != null and _fade.is_valid() and _fade.is_running()


## The duck now in dB below the normal level (0 for none).
func duck_db() -> float:
	return _duck_db


## True when the music is ducked or ducking (an unduck without delay makes this false at once).
func is_ducked() -> bool:
	return _duck_target_db < 0.0


## The Music bus volume with no duck (from default_bus_layout.tres).
func base_db() -> float:
	return _base_db


## True when the duck moves the bus, false when it moves the players (no bus).
func ducks_bus() -> bool:
	return _bus >= 0


func _stream(track: StringName) -> AudioStream:
	if not _streams.has(track):
		var stream: AudioStream = load(TRACKS[track]) as AudioStream
		if stream == null:
			_report("Music: can't load '%s'." % TRACKS[track])
			return null
		_streams[track] = stream
	return _streams[track]


func _start_crossfade() -> void:
	if _fade != null:
		_fade.kill()
	_fade_from = _gains.duplicate()
	_fade = create_tween()
	_fade.tween_method(_set_crossfade, 0.0, 1.0, CROSSFADE_S)
	_fade.tween_callback(_stop_silent)


## Equal power: the incoming player rises on a sine from its gain to 1, the other falls on a
## cosine from its gain to 0.
func _set_crossfade(progress: float) -> void:
	var rise: float = sin(progress * PI / 2.0)
	var fall: float = cos(progress * PI / 2.0)
	var other: int = 1 - _active
	_gains[_active] = lerpf(_fade_from[_active], 1.0, rise)
	_gains[other] = _fade_from[other] * fall
	_apply_volumes()


## After a crossfade: the faded-out player stops.
func _stop_silent() -> void:
	var other: int = 1 - _active
	_gains[_active] = 1.0
	_gains[other] = 0.0
	_players[other].stop()
	_players[other].stream = null
	_player_tracks[other] = &""
	_apply_volumes()


func _tween_duck(to_db: float, fade_s: float) -> void:
	var running: bool = _duck != null and _duck.is_valid() and _duck.is_running()
	if running and is_equal_approx(to_db, _duck_target_db):
		if _duck_fade_s - _duck.get_total_elapsed_time() <= fade_s:
			return
	if _duck != null:
		_duck.kill()
	_duck = null
	_duck_target_db = to_db
	if fade_s <= 0.0:
		_set_duck(to_db)
		return
	_duck_fade_s = fade_s
	_duck = create_tween()
	_duck.tween_method(_set_duck, _duck_db, to_db, fade_s)


func _cancel_release() -> void:
	if _release != null:
		_release.kill()
	_release = null


func _set_duck(db: float) -> void:
	_duck_db = db
	if _bus >= 0:
		AudioServer.set_bus_volume_db(_bus, _base_db + db)
	else:
		_apply_volumes()


## Each player's volume_db from its fade gain, plus the duck when there is no bus to carry it.
func _apply_volumes() -> void:
	var duck_offset: float = 0.0 if _bus >= 0 else _duck_db
	for index: int in range(_players.size()):
		_players[index].volume_db = maxf(linear_to_db(_gains[index]), SILENT_DB) + duck_offset


func _report(message: String) -> void:
	if report_error.is_valid():
		report_error.call(message)
	else:
		push_error(message)
