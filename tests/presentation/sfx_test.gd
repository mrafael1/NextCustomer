extends GdUnitTestSuite
## Sfx (presentation/sfx.gd, #62): every sound and bonus note in audio/sfx/ loads; round-robin
## sounds play their takes in a fixed order; the note ladder plays one file per note (bonus_00
## G4 to bonus_10 G6, clamped) on one monophonic note player; every player is on the SFX bus, or
## Master without one; warm_up plays every sound silently; a scene's controls find its Sfx; and
## bonuses on several cards play rising notes across the row.

const RecordingSfx := preload("res://tests/presentation/recording_sfx.gd")
const SCREEN := "res://ui/shift_screen.tscn"
## The agreed sound names (#62), written out here so the test pins the contract with the audio
## files, not the code's own list.
const AGREED_SOUNDS: Array[String] = [
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
]
## Several cards that each step the ladder (plain cards and a multiplier).
const LADDER_ROW: Array[String] = ["milk", "bread", "multipack", "milk", "milk", "milk"]

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


## SOUNDS is the agreed names plus the 11 bonus notes; each is a WAV that loads (a missing one
## would print a Godot error and fail the run), and every WAV in the folder is in SOUNDS.
func test_every_sound_and_note_loads() -> void:
	var expected: Array[String] = AGREED_SOUNDS.duplicate()
	for index: int in range(11):
		expected.append("bonus_%02d" % index)
	assert_array(Sfx.SOUNDS).contains_exactly_in_any_order(expected)
	var wavs: Array[String] = []
	for file_name: String in DirAccess.get_files_at(Sfx.FOLDER):
		if file_name.get_extension() == "wav":
			wavs.append(file_name.get_basename())
	assert_array(wavs).contains_exactly_in_any_order(Sfx.SOUNDS)
	for sound: String in Sfx.SOUNDS:
		var path: String = "%s/%s.wav" % [Sfx.FOLDER, sound]
		assert_bool(ResourceLoader.exists(path)).override_failure_message(path).is_true()
		assert_object(load(path)).override_failure_message(path).is_instanceof(AudioStreamWAV)
	# Every take of every round-robin sound is a file.
	for base: String in Sfx.ROUND_ROBIN:
		for take: int in range(1, Sfx.ROUND_ROBIN[base] + 1):
			assert_array(Sfx.SOUNDS).contains(["%s_%d" % [base, take]])


## A round-robin sound plays its takes in a fixed order, one counter per sound; a take played by
## its own name doesn't move the counter; a sound without takes plays its own file.
func test_round_robin_sounds_cycle_their_takes_in_order() -> void:
	var agreed: Dictionary[String, int] = {
		"stamp": 3, "card_place": 4, "card_pickup": 3, "card_return": 2, "ui_click": 3, "coin": 3
	}
	assert_dict(Sfx.ROUND_ROBIN).is_equal(agreed)
	var sfx: RecordingSfx = await _recording()
	for base: String in agreed:
		var expected: Array[String] = []
		for turn: int in range(agreed[base] * 2 + 1):
			expected.append("%s_%d" % [base, turn % agreed[base] + 1])
			sfx.play(base)
			assert_object(_last_stream(sfx)).is_same(_stream(expected[-1]))
		assert_array(_takes(sfx, base)).is_equal(expected)
	# The counters are per sound: stamp is on its 2nd take after 7 plays, card_place on its 2nd
	# after 9, and a take named in full plays that file without moving the counter.
	assert_str(sfx.next_take("stamp")).is_equal("stamp_2")
	sfx.play("stamp_3")
	assert_object(_last_stream(sfx)).is_same(_stream("stamp_3"))
	assert_str(sfx.next_take("stamp")).is_equal("stamp_2")
	assert_str(sfx.next_take("card_place")).is_equal("card_place_2")
	assert_str(sfx.next_take("scan")).is_equal("scan")
	sfx.play("scan")
	assert_object(_last_stream(sfx)).is_same(_stream("scan"))


## play_note(0..10) plays bonus_00..bonus_10 at its own pitch; below 0 plays bonus_00 and past
## the top plays bonus_10 (decided: clamp).
func test_play_note_plays_one_file_per_note_and_clamps() -> void:
	var sfx: Sfx = await _sfx()
	assert_int(sfx.note_count()).is_equal(11)
	for index: int in range(11):
		sfx.play_note(index, -6.0)
		var player: AudioStreamPlayer = _note_player(sfx)
		assert_object(player.stream).is_same(_stream("bonus_%02d" % index))
		assert_float(player.pitch_scale).is_equal(1.0)
		assert_float(player.volume_db).is_equal(-6.0)
	for index: int in [-1, -40]:
		sfx.play_note(index)
		assert_object(_note_player(sfx).stream).is_same(_stream("bonus_00"))
	for index: int in [11, 99]:
		sfx.play_note(index)
		assert_object(_note_player(sfx).stream).is_same(_stream("bonus_10"))
	assert_str(Sfx.note_sound(-1)).is_equal("bonus_00")
	assert_str(Sfx.note_sound(4)).is_equal("bonus_04")
	assert_str(Sfx.note_sound(11)).is_equal("bonus_10")


## Notes are monophonic: however many play, they all go to the one note player (the newest
## replaces the last), and none of them takes a player from the pool. A bonus file played
## through play() uses the pool, so it doesn't cut the note.
func test_notes_play_on_one_player_outside_the_pool() -> void:
	var sfx: Sfx = await _sfx()
	assert_int(_players(sfx).size()).is_equal(Sfx.POOL_SIZE + 1)
	sfx.play("scan")
	for index: int in [0, 4, 7, 2]:
		sfx.play_note(index, -6.0)
	assert_object(_note_player(sfx).stream).is_same(_stream("bonus_02"))
	var used: int = 0
	for player: AudioStreamPlayer in _players(sfx):
		if player.stream != null:
			used += 1
	assert_int(used).is_equal(2)
	sfx.play("bonus_05")
	assert_object(_note_player(sfx).stream).is_same(_stream("bonus_02"))
	assert_object(_last_stream(sfx)).is_same(_stream("bonus_05"))


## A long sound keeps its player while another one is idle: the quota ding (1.2 s) plays on
## through a beat's worth of short sounds after it (a full pool's), and with every player busy
## the next sound takes the one nearest its end, never the ding.
func test_a_long_sound_is_not_cut_by_the_sounds_after_it() -> void:
	var sfx: Sfx = await _sfx()
	assert_float(sfx.sound_length("ding")).is_greater(1.0)
	assert_float(sfx.sound_length("tick")).is_less(sfx.sound_length("ding"))
	assert_float(sfx.sound_length("stamp")).is_equal(_stream("stamp_1").get_length())
	assert_float(sfx.sound_length("no_such_sound")).is_equal(0.0)
	sfx.play("ding")
	var ding: AudioStreamPlayer = _players(sfx)[0]
	assert_object(ding.stream).is_same(_stream("ding"))
	for index: int in range(Sfx.POOL_SIZE - 1):
		sfx.play("tick")
	for player: AudioStreamPlayer in _players(sfx).slice(0, Sfx.POOL_SIZE):
		assert_bool(player.playing).is_true()
	sfx.play("scan")
	sfx.play("print")
	await _frames(2)
	assert_bool(ding.playing).is_true()
	assert_object(ding.stream).is_same(_stream("ding"))
	assert_object(_last_stream(sfx)).is_same(_stream("print"))
	var scans: int = 0
	for player: AudioStreamPlayer in _players(sfx).slice(0, Sfx.POOL_SIZE):
		if player.stream == _stream("scan"):
			scans += 1
		player.stop()
	assert_int(scans).is_equal(1)


## Every player plays on the SFX bus; without one in the layout, on Master (and nothing is
## reported).
func test_players_use_the_sfx_bus_or_master_without_one() -> void:
	var had_bus: bool = AudioServer.get_bus_index(Sfx.BUS) >= 0
	if not had_bus:
		assert_str(String(Sfx.bus_name())).is_equal("Master")
		var without: Sfx = await _sfx()
		for player: AudioStreamPlayer in _players(without):
			assert_str(String(player.bus)).is_equal("Master")
		AudioServer.add_bus()
		AudioServer.set_bus_name(AudioServer.bus_count - 1, Sfx.BUS)
	var on_bus: Sfx = await _sfx()
	assert_str(String(Sfx.bus_name())).is_equal("SFX")
	for player: AudioStreamPlayer in _players(on_bus):
		assert_str(String(player.bus)).is_equal("SFX")
	if not had_bus:
		AudioServer.remove_bus(AudioServer.get_bus_index(Sfx.BUS))


## warm_up plays every sound once, silently, then leaves the pool empty and the round-robin
## turns where they were; a recording Sfx records none of it.
func test_warm_up_plays_every_sound_silently() -> void:
	var sfx: RecordingSfx = await _recording()
	sfx.play("stamp")
	assert_int(sfx.warm_up()).is_equal(Sfx.SOUNDS.size())
	assert_int(sfx.sounds.size()).is_equal(1)
	assert_str(sfx.next_take("stamp")).is_equal("stamp_2")
	for player: AudioStreamPlayer in _players(sfx):
		assert_object(player.stream).is_null()
		assert_float(player.volume_db).is_equal(0.0)
		assert_bool(player.playing).is_false()


## An Sfx registers on its parent: the parent's descendants find it (the newest one wins), a
## node outside finds none, and play_at plays on it. Once it leaves, it is no longer found.
func test_a_scene_finds_its_sfx() -> void:
	var scene: Control = auto_free(Control.new())
	add_child(scene)
	var panel: Control = Control.new()
	scene.add_child(panel)
	var button: Button = Button.new()
	panel.add_child(button)
	var stranger: Node = auto_free(Node.new())
	add_child(stranger)
	assert_object(Sfx.find(button)).is_null()
	var first: Sfx = Sfx.new()
	scene.add_child(first)
	assert_object(Sfx.find(button)).is_same(first)
	var second: RecordingSfx = RecordingSfx.new()
	scene.add_child(second)
	assert_object(Sfx.find(button)).is_same(second)
	assert_object(Sfx.find(scene)).is_same(second)
	assert_object(Sfx.find(stranger)).is_null()
	Sfx.play_at(button, "ui_open", -3.0)
	assert_array(second.sound_names()).is_equal(["ui_open"])
	assert_float(float(second.sounds[0]["volume_db"])).is_equal(-3.0)
	Sfx.play_at(stranger, "ui_open")
	scene.remove_child(second)
	second.free()
	assert_object(Sfx.find(button)).is_null()


## outlive_scene moves the Sfx out of its scene, still playing, and frees it later: the title's
## start click is heard over the shift screen.
func test_an_sfx_outlives_its_scene() -> void:
	var scene: Control = Control.new()
	add_child(scene)
	var sfx: Sfx = Sfx.new()
	scene.add_child(sfx)
	sfx.play("ui_click")
	var player: AudioStreamPlayer = _players(sfx)[0]
	assert_bool(player.playing).is_true()
	sfx.outlive_scene(0.1)
	assert_object(sfx.get_parent()).is_same(get_tree().root)
	assert_bool(scene.has_meta(Sfx.META)).is_false()
	assert_bool(get_tree().root.has_meta(Sfx.META)).is_false()
	scene.free()
	assert_bool(is_instance_valid(sfx)).is_true()
	assert_bool(player.playing).is_true()
	var start: int = Time.get_ticks_msec()
	while is_instance_valid(sfx) and Time.get_ticks_msec() - start < 2000:
		await get_tree().process_frame
	assert_bool(is_instance_valid(sfx)).is_false()


## play_series plays a sound that many times, in turn, none of them at once (the tween's own
## timing is Godot's).
func test_a_series_plays_in_turn() -> void:
	var sfx: RecordingSfx = await _recording()
	sfx.play_series("coin", 4, 0.03, 0.05)
	sfx.play_series("coin", 0, 0.03)
	assert_int(sfx.sounds.size()).is_equal(0)
	var start: int = Time.get_ticks_msec()
	while sfx.sounds.size() < 4 and Time.get_ticks_msec() - start < 2000:
		await get_tree().process_frame
	assert_array(_takes(sfx, "coin")).is_equal(["coin_1", "coin_2", "coin_3", "coin_1"])


## The recording double that tests use in place of Sfx records what was played (with the take
## and the note's file) and still plays it.
func test_recording_sfx_records_sounds_and_notes() -> void:
	var sfx: RecordingSfx = await _recording()
	sfx.play("tick", 1.0, -8.0)
	sfx.play("stamp")
	sfx.play_note(5)
	sfx.play_note(40, -10.0)
	assert_int(sfx.sounds.size()).is_equal(2)
	var now_usec: int = Time.get_ticks_usec()
	var played: Dictionary = sfx.sounds[0].duplicate()
	assert_int(int(played["usec"])).is_greater(0)
	assert_int(int(played["usec"])).is_less_equal(now_usec)
	played.erase("usec")
	assert_dict(played).is_equal({"sound": "tick", "take": "tick", "pitch": 1.0, "volume_db": -8.0})
	assert_str(String(sfx.sounds[1]["take"])).is_equal("stamp_1")
	assert_array(sfx.note_indices()).is_equal([5, 40])
	assert_str(String(sfx.notes[1]["sound"])).is_equal("bonus_10")
	assert_float(float(sfx.notes[1]["volume_db"])).is_equal(-10.0)
	assert_object(_note_player(sfx).stream).is_same(_stream("bonus_10"))
	assert_int(sfx.count("stamp")).is_equal(1)
	sfx.clear()
	assert_int(sfx.sounds.size() + sfx.notes.size()).is_equal(0)


## Bonuses on several cards of a row play rising notes across the row: the ladder carries on
## from card to card instead of starting again at each scan, and each note plays its own file.
func test_notes_rise_across_the_row() -> void:
	var runner: GdUnitSceneRunner = scene_runner(SCREEN)
	var screen: ShiftScreen = runner.scene()
	screen._on_reward_skipped()  # Past the impulse rack.
	await _frames(2)
	var sfx: RecordingSfx = RecordingSfx.new()
	screen.add_child(sfx)
	screen._count_up._sfx = sfx
	for id: String in LADDER_ROW:
		screen._debug.add_card(id)
		var card: CardInstance = screen.run.hand()[-1]
		screen._on_hand_card_clicked(_hand_view(screen, card))
		screen._on_slot_input(_left_click(), screen.run.row.size())
	assert_int(screen.run.row.size()).is_equal(LADDER_ROW.size())
	await screen._on_checkout_pressed()
	var plan: CountUpPlan = screen._count_up.plan
	var gains: Array[int] = []
	for beat: CountUpBeat in plan.beats:
		if beat.note >= 0 and beat.kind != CountUpBeat.Kind.ARMED:
			gains.append(beat.note)
	var played: Array[int] = []
	for entry: Dictionary in sfx.notes:
		assert_str(String(entry["sound"])).is_equal(Sfx.note_sound(int(entry["index"])))
		if float(entry["volume_db"]) != CountUp.ARMED_NOTE_DB:
			played.append(int(entry["index"]))
	assert_array(played).is_equal(gains)
	# At least five gains on the six cards, within the ladder's 11 notes: each note one step above
	# the last, from G4 up, never back to the bottom at the next card's scan.
	assert_int(played.size()).is_between(5, Sfx.NOTE_COUNT)
	for index: int in range(played.size()):
		assert_int(played[index]).is_equal(index)


func _sfx() -> Sfx:
	var sfx: Sfx = auto_free(Sfx.new())
	add_child(sfx)
	await get_tree().process_frame
	return sfx


func _recording() -> RecordingSfx:
	var sfx: RecordingSfx = auto_free(RecordingSfx.new())
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


## The stream of the pool player that played last.
func _last_stream(sfx: Sfx) -> AudioStream:
	var pool: Array[AudioStreamPlayer] = _players(sfx).slice(0, Sfx.POOL_SIZE)
	return pool[(sfx._next + Sfx.POOL_SIZE - 1) % Sfx.POOL_SIZE].stream


static func _stream(sound: String) -> AudioStream:
	return load("%s/%s.wav" % [Sfx.FOLDER, sound])


## The takes a recording Sfx played for `base`, in order.
static func _takes(sfx: RecordingSfx, base: String) -> Array[String]:
	var takes: Array[String] = []
	for entry: Dictionary in sfx.sounds:
		if entry["sound"] == base:
			takes.append(String(entry["take"]))
	return takes


func _frames(count: int) -> void:
	for frame: int in range(count):
		await get_tree().process_frame


static func _hand_view(screen: ShiftScreen, card: CardInstance) -> CardView:
	for child: Node in screen._hand_box.get_children():
		var view: CardView = child as CardView
		if view and view.card == card and not view.is_queued_for_deletion():
			return view
	return null


static func _left_click() -> InputEventMouseButton:
	var click: InputEventMouseButton = InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	return click


static func _event_log() -> EventLogService:
	return (Engine.get_main_loop() as SceneTree).root.get_node("/root/EventLog")
