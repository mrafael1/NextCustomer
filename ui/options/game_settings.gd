class_name GameSettings
extends RefCounted
## Applies the profile's options settings (the OPTIONS popup, mock-up options_pause.html):
## DISPLAY through the window mode (FULLSCREEN is borderless, not exclusive), MUSIC through the
## Music service's level (so ducking stays relative to it), SOUND on the SFX bus, both as
## linear_to_db(v / 10) on top of the bus layout's levels and muted at 0, and TEXT SIZE as
## UiKit.reading_scale. The window and bus setters are injectable, so tests record the calls.

## TEXT SIZE's scales, by ProfileState.TEXT_SIZES index (NORMAL, LARGE, LARGER).
const TEXT_SCALES: Array[float] = [1.0, 1.2, 1.4]
## The sound effects' bus (default_bus_layout.tres).
const SFX_BUS := &"SFX"

## The bus layout's levels, read once per bus before the first change.
static var _layout_db: Dictionary[StringName, float] = {}

## Sets the window mode: (mode: DisplayServer.WindowMode).
var set_window_mode: Callable = func(mode: DisplayServer.WindowMode) -> void:
	DisplayServer.window_set_mode(mode)
## Sets a bus's level over its layout level and its mute: (bus: StringName, db: float,
## muted: bool).
var set_bus_level: Callable = func(bus: StringName, db: float, muted: bool) -> void:
	_bus_level(bus, db, muted)
## Whether this is the web build (its fullscreen needs a click, so boot never applies it).
var is_web: bool = OS.has_feature("web")


## Applies every setting. `at_boot`: a windowed display is left as the window opened, and the web
## build never goes fullscreen (browsers refuse without a click).
func apply(profile: ProfileState, music: MusicService, at_boot: bool = false) -> void:
	apply_display(profile, at_boot)
	apply_volumes(profile, music)
	apply_text_size(profile)


func apply_display(profile: ProfileState, at_boot: bool = false) -> void:
	var full: bool = ProfileSettings.display(profile) == ProfileState.DISPLAY_FULLSCREEN
	if at_boot and (is_web or not full):
		return
	set_window_mode.call(
		DisplayServer.WINDOW_MODE_FULLSCREEN if full else DisplayServer.WINDOW_MODE_WINDOWED
	)


func apply_volumes(profile: ProfileState, music: MusicService) -> void:
	var music_volume: int = ProfileSettings.music_volume(profile)
	if music != null:
		music.set_level(volume_db(music_volume), music_volume == 0)
	var sound: int = ProfileSettings.sound_volume(profile)
	set_bus_level.call(SFX_BUS, volume_db(sound), sound == 0)


static func apply_text_size(profile: ProfileState) -> void:
	UiKit.reading_scale = TEXT_SCALES[ProfileSettings.text_size(profile)]


## Alt+Enter (anywhere): flips DISPLAY and applies it. True when the event was that key.
func toggle_on_key(event: InputEvent, profile: ProfileState) -> bool:
	if not is_toggle_key(event):
		return false
	var full: bool = ProfileSettings.display(profile) == ProfileState.DISPLAY_FULLSCREEN
	ProfileSettings.set_display(
		profile, ProfileState.DISPLAY_WINDOWED if full else ProfileState.DISPLAY_FULLSCREEN
	)
	apply_display(profile)
	return true


static func is_toggle_key(event: InputEvent) -> bool:
	var key: InputEventKey = event as InputEventKey
	return (
		key != null
		and key.pressed
		and not key.echo
		and key.alt_pressed
		and (key.keycode == KEY_ENTER or key.keycode == KEY_KP_ENTER)
	)


## A volume step's offset in dB over the layout's level (0 at the top; 0 itself mutes instead).
static func volume_db(volume: int) -> float:
	if volume <= 0:
		return 0.0
	return linear_to_db(float(volume) / ProfileState.VOLUME_MAX)


static func _bus_level(bus: StringName, db: float, muted: bool) -> void:
	var index: int = AudioServer.get_bus_index(bus)
	if index < 0:
		return
	if not _layout_db.has(bus):
		_layout_db[bus] = AudioServer.get_bus_volume_db(index)
	AudioServer.set_bus_volume_db(index, _layout_db[bus] + db)
	AudioServer.set_bus_mute(index, muted)
