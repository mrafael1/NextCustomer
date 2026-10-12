class_name Sfx
extends Node
## Plays the sound effects in audio/sfx/ (#62: CC0 recordings and two synthesised sounds, built
## by tools/make_sfx.py), each a mono 16-bit 44100 Hz WAV named after its sound. A small pool of
## players, so overlapping sounds don't cut each other off: play() takes an idle player, and only
## when all are busy the one nearest its end. Every player plays on the SFX bus
## (default_bus_layout.tres), or on Master when there is no SFX bus.
##
## A sound with several takes (ROUND_ROBIN) is played by its base name: play("stamp") plays
## stamp_1, stamp_2, stamp_3, stamp_1 ... in a fixed order, one counter per sound, so a run sounds
## the same every time. A take can also be played by its own name (play("stamp_2")).
##
## The count-up's note ladder (#60, D1) plays through play_note on one dedicated player outside
## the pool: notes are monophonic, so a new note cuts the last one and skipped beats can't stack
## notes. Each note is its own file, bonus_00 (G4) to bonus_10 (G6), played at its own pitch.
##
## Each scene that makes sounds has its own Sfx (no autoload: sound effects stay in the scene).
## The Sfx registers itself on its parent, so the scene's controls find it with Sfx.find (the
## UiKit buttons, panels and the coin receipt do).
##
## warm_up() plays every sound once, silently: the web build registers a sample the first time it
## plays, which can hitch, so the title and the shift screen warm up when they open, never in the
## middle of a count.

## The folder of the sound files: <sound>.wav for every name in SOUNDS.
const FOLDER := "res://audio/sfx"
## Every sound file, without its extension.
const SOUNDS: Array[String] = [
	"scan",
	"print",
	"tick",
	"stamp_1",
	"stamp_2",
	"stamp_3",
	"stamp_paid",
	"stamp_loyalty",
	"stamp_notice",
	"rattle_s",
	"rattle_m",
	"rattle_l",
	"register_bell",
	"ding",
	"tag",
	"link",
	"copy",
	"fizzle",
	"denied",
	"total",
	"miss",
	"pass",
	"fail",
	"rip",
	"armed",
	"card_place_1",
	"card_place_2",
	"card_place_3",
	"card_place_4",
	"card_pickup_1",
	"card_pickup_2",
	"card_pickup_3",
	"card_return_1",
	"card_return_2",
	"slot_tick",
	"shuffle",
	"fan",
	"checkout",
	"ui_click_1",
	"ui_click_2",
	"ui_click_3",
	"ui_open",
	"ui_close",
	"ui_back",
	"ui_confirm",
	"ui_switch",
	"coin_1",
	"coin_2",
	"coin_3",
	"bonus_00",
	"bonus_01",
	"bonus_02",
	"bonus_03",
	"bonus_04",
	"bonus_05",
	"bonus_06",
	"bonus_07",
	"bonus_08",
	"bonus_09",
	"bonus_10",
]
## The sounds played by a base name, and how many takes each has (<base>_1 to <base>_N).
const ROUND_ROBIN: Dictionary[String, int] = {
	"stamp": 3,
	"card_place": 4,
	"card_pickup": 3,
	"card_return": 2,
	"ui_click": 3,
	"coin": 3,
}
## The note ladder's files: NOTE_PREFIX + two digits, G4 A4 C5 D5 E5 G5 A5 C6 D6 E6 G6.
const NOTE_PREFIX := "bonus_"
const NOTE_COUNT := 11
const POOL_SIZE := 12
## The bus every player plays on, and the one used when the layout has no such bus.
const BUS := &"SFX"
const FALLBACK_BUS := &"Master"
## warm_up() plays every sound this quietly.
const WARM_UP_DB := -80.0
## The meta an Sfx sets on its parent, so Sfx.find sees it from the parent's descendants.
const META := &"sfx"

var _streams: Dictionary[String, AudioStream] = {}
var _players: Array[AudioStreamPlayer] = []
var _next: int = 0
var _note_player: AudioStreamPlayer
## Each round-robin sound's next take, 0-based.
var _takes: Dictionary[String, int] = {}
## True once the Sfx has left its scene to finish its sounds (outlive_scene): it no longer
## registers on a parent.
var _detached: bool = false


func _ready() -> void:
	for sound: String in SOUNDS:
		_streams[sound] = load("%s/%s.wav" % [FOLDER, sound]) as AudioStream
	var bus: StringName = bus_name()
	for i: int in range(POOL_SIZE):
		var player: AudioStreamPlayer = AudioStreamPlayer.new()
		player.bus = bus
		add_child(player)
		_players.append(player)
	_note_player = AudioStreamPlayer.new()
	_note_player.bus = bus
	add_child(_note_player)


func _enter_tree() -> void:
	if not _detached:
		get_parent().set_meta(META, self)


func _exit_tree() -> void:
	var parent: Node = get_parent()
	if parent != null and parent.has_meta(META) and parent.get_meta(META) == self:
		parent.remove_meta(META)


## Plays `sound`: a file's name, or a round-robin sound's base name (its next take).
func play(sound: String, pitch: float = 1.0, volume_db: float = 0.0) -> void:
	var take: String = next_take(sound)
	if ROUND_ROBIN.has(sound):
		var taken: int = _takes.get(sound, 0)
		_takes[sound] = (taken + 1) % ROUND_ROBIN[sound]
	var stream: AudioStream = _streams.get(take) as AudioStream
	if stream == null or _players.is_empty():
		return
	var index: int = _free_player()
	var player: AudioStreamPlayer = _players[index]
	_next = (index + 1) % _players.size()
	player.stream = stream
	player.pitch_scale = clampf(pitch, 0.5, 2.0)
	player.volume_db = volume_db
	player.play()


## The file play(sound) plays next: the next take of a round-robin sound, else `sound` itself.
func next_take(sound: String) -> String:
	if not ROUND_ROBIN.has(sound):
		return sound
	var taken: int = _takes.get(sound, 0)
	return "%s_%d" % [sound, taken + 1]


## How long the file play(sound) plays next lasts, in seconds at pitch 1 (0 for no such sound).
func sound_length(sound: String) -> float:
	var stream: AudioStream = _streams.get(next_take(sound)) as AudioStream
	return stream.get_length() if stream != null else 0.0


## Plays `sound` `count` times, `gap` seconds apart, the first after `delay` (a redraw's deal,
## the coins on the final receipt).
func play_series(sound: String, count: int, gap: float, delay: float = 0.0) -> void:
	if count <= 0 or not is_inside_tree():
		return
	var series: Tween = create_tween()
	series.tween_interval(delay)
	for index: int in range(count):
		if index > 0:
			series.tween_interval(gap)
		series.tween_callback(play.bind(sound))


## Plays note `index` of the ladder (clamped to 0..NOTE_COUNT - 1) on the note player, cutting
## the note before it.
func play_note(index: int, volume_db: float = 0.0) -> void:
	var stream: AudioStream = _streams.get(note_sound(index)) as AudioStream
	if stream == null or _note_player == null:
		return
	_note_player.stream = stream
	_note_player.pitch_scale = 1.0
	_note_player.volume_db = volume_db
	_note_player.play()


## How many notes the ladder has (G4 to G6).
func note_count() -> int:
	return NOTE_COUNT


## The file of note `index`, clamped to the ladder: bonus_00 to bonus_10.
static func note_sound(index: int) -> String:
	return "%s%02d" % [NOTE_PREFIX, clampi(index, 0, NOTE_COUNT - 1)]


## Plays every sound once at WARM_UP_DB and stops it, so the web build registers every sample
## now rather than on its first real play, and returns how many it played. Nothing counts as
## played: play()'s round-robin turns don't move.
func warm_up() -> int:
	if _players.is_empty():
		return 0
	var index: int = 0
	for sound: String in SOUNDS:
		var stream: AudioStream = _streams.get(sound) as AudioStream
		if stream == null:
			continue
		var player: AudioStreamPlayer = _players[index % _players.size()]
		player.stream = stream
		player.pitch_scale = 1.0
		player.volume_db = WARM_UP_DB
		player.play()
		player.stop()
		index += 1
	for player: AudioStreamPlayer in _players:
		player.stream = null
		player.volume_db = 0.0
	return index


## Leaves the scene so the sounds playing now finish after it is freed (the title's click as the
## shift screen loads), then frees itself after `seconds`.
func outlive_scene(seconds: float = 1.5) -> void:
	if not is_inside_tree():
		return
	var tree: SceneTree = get_tree()
	_detached = true
	reparent(tree.root, false)
	tree.create_timer(seconds).timeout.connect(queue_free)


## The pool player play() uses: the first idle one from _next on, so a long sound (the quota
## ding, a rattle) is never cut while a player is free; with none idle, the one closest to its
## end.
func _free_player() -> int:
	var best: int = _next
	var best_left: float = INF
	for offset: int in range(_players.size()):
		var index: int = (_next + offset) % _players.size()
		var player: AudioStreamPlayer = _players[index]
		if not player.playing or player.stream == null:
			return index
		var left: float = (
			(player.stream.get_length() - player.get_playback_position())
			/ maxf(player.pitch_scale, 0.01)
		)
		if left < best_left:
			best = index
			best_left = left
	return best


## The bus the players use: SFX, or Master when the bus layout has no SFX bus.
static func bus_name() -> StringName:
	return BUS if AudioServer.get_bus_index(BUS) >= 0 else FALLBACK_BUS


## The Sfx of `node`'s scene: the one registered on `node` or its nearest ancestor, or null.
static func find(node: Node) -> Sfx:
	var current: Node = node
	while current != null:
		if current.has_meta(META):
			var found: Object = current.get_meta(META)
			if is_instance_valid(found) and found is Sfx:
				return found as Sfx
		current = current.get_parent()
	return null


## Plays `sound` on the Sfx of `node`'s scene; nothing when it has none (a panel built alone in
## a test).
static func play_at(node: Node, sound: String, volume_db: float = 0.0) -> void:
	var sfx: Sfx = find(node)
	if sfx != null:
		sfx.play(sound, 1.0, volume_db)
