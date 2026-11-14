class_name OptionsCard
extends TitlePopup
## The OPTIONS popup (mock-up options_pause.html, direction A), used by the title and the pause:
## a TitlePopup 352 art px wide whose height grows with TEXT SIZE, heading OPTIONS, a tagline,
## six rows (DISPLAY, MUSIC, SOUND, TEXT SIZE, REDUCED MOTION, COUNT-UP SPEED), a hint line with
## the marked row's description, and DONE.
##
## One marker for the mouse and the keys: Up / Down walk the rows and DONE, Left / Right change the
## marked row, Enter toggles or presses, Esc closes. Changes go to the profile and apply at once
## (GameSettings); the owner saves the profile once when the popup closes (`closed`), and
## changes() lists what changed since it opened (telemetry's settings_change).
##
## The polish audit (v1.36): the TEXT SIZE preview fits the rules' width, the hint line shows
## DEFAULT_HINT until a row is marked (no blank band above DONE), REDUCED MOTION is a chip pair
## (OFF / ON) like its neighbours, FAST's x1.5 is in hard pixel digits, ESC is centred on DONE's
## face, and the rows start ROWS_TOP clear of the tagline.

enum Row { DISPLAY, MUSIC, SOUND, TEXT, MOTION, SPEED, DONE }

const WIDTH_ART := 352
const SHEET_WIDTH := 704.0
## The rows' columns and first row, in canvas px from the sheet's top left (the mock-up's).
const TICK_LEFT := 18.0
const LABEL_LEFT := 36.0
const WIDGET_LEFT := 232.0
const ROWS_TOP := 100.0
const ROW_GAP := 16.0
const CHIP_GAP := 8.0
const LABELS: Array[String] = [
	"DISPLAY", "MUSIC", "SOUND", "TEXT SIZE", "REDUCED MOTION", "COUNT-UP SPEED"
]
const HINTS: Array[String] = [
	"Alt+Enter switches it anywhere. In the web build this is the browser's own full screen.",
	"The shift music, 0 to 10.",
	"The sound effects, 0 to 10. Each step plays the scanner's beep.",
	"Makes rules, tips and receipt lines bigger. Pixel-art titles keep their size.",
	"No shakes, no flying chips, no rolling numbers. Every result stays.",
	"How fast the checkout counts: FAST is ×1.5. Hold Space during a count to fast-forward it.",
]
const DONE_HINT := "Saves your settings and closes. Esc does the same."
## The hint before any row is marked.
const DEFAULT_HINT := "Up / Down pick a row, Left / Right change it. Changes apply at once."
const PREVIEW := "Later items that share a family with the item right before it pay ×3."
## The preview runs from the widgets' column to the dashed rules' right end.
const PREVIEW_WIDTH := SHEET_WIDTH - 24.0 - WIDGET_LEFT
const PREVIEW_FONT := 15
const HINT_FONT := 13
const HINT_LEFT := 40.0
const DONE_SIZE := Vector2(128, 42)
## ESC's left edge beside DONE.
const ESC_LEFT := 168.0
const RECEIPT_FRAME := preload("res://art/frames/receipt_paper.png")

## The profile the rows show and change, and how the changes apply (set by open).
var profile: ProfileState
var settings: GameSettings
var music: MusicService

var _before: Dictionary = {}
var _content: Control
var _hint: Label
var _ticks: Array[TextureRect] = []
var _chips: Dictionary[int, Array] = {}
var _volumes: Dictionary[int, VolumePips] = {}
var _motion_note: Label
var _done: MenuPlate
var _esc: Label
## The dashed rules between the rows, by their top (canvas px on the sheet), and the hint's.
var _rules: Array[float] = []
var _hint_rule: float = 0.0


func _init() -> void:
	super(Vector2i(WIDTH_ART, 290))


## Opens the popup on `shown_profile`, applying changes with `applier` (and `music_service`).
func open(shown_profile: ProfileState, applier: GameSettings, music_service: MusicService) -> Tween:
	profile = shown_profile
	settings = applier
	music = music_service
	_before = profile.settings.duplicate(true)
	_build_content()
	return _show_popup()


## What changed since open: {key, from, to} for each setting whose value differs.
func changes() -> Array[Dictionary]:
	var was: ProfileState = ProfileState.new()
	was.settings = _before
	var result: Array[Dictionary] = []
	var pairs: Array = [
		[ProfileState.DISPLAY_KEY, ProfileSettings.display(was), ProfileSettings.display(profile)],
		[
			ProfileState.MUSIC_VOLUME_KEY,
			ProfileSettings.music_volume(was),
			ProfileSettings.music_volume(profile)
		],
		[
			ProfileState.SOUND_VOLUME_KEY,
			ProfileSettings.sound_volume(was),
			ProfileSettings.sound_volume(profile)
		],
		[
			ProfileState.TEXT_SIZE_KEY,
			ProfileState.TEXT_SIZES[ProfileSettings.text_size(was)],
			ProfileState.TEXT_SIZES[ProfileSettings.text_size(profile)]
		],
		[ProfileState.REDUCED_MOTION_KEY, was.reduced_motion(), profile.reduced_motion()],
		[ProfileState.COUNT_UP_SPEED_KEY, was.count_up_speed(), profile.count_up_speed()],
	]
	for pair: Array in pairs:
		if pair[1] != pair[2]:
			result.append({"key": pair[0], "from": pair[1], "to": pair[2]})
	return result


## The row's entry (its marker area), DONE's plate for Row.DONE.
func row_entry(row: Row) -> Control:
	return _entries[row] if row < _entries.size() else null


## The row's chips (DISPLAY, TEXT SIZE, REDUCED MOTION, COUNT-UP SPEED), in order.
func chips(row: Row) -> Array:
	return _chips.get(row, [])


func volume(row: Row) -> VolumePips:
	return _volumes.get(row)


func done_plate() -> MenuPlate:
	return _done


func hint_label() -> Label:
	return _hint


func esc_label() -> Label:
	return _esc


## The marked row (-1: none).
func marked_row() -> int:
	return _marked


func handle_key(event: InputEvent) -> bool:
	var key: InputEventKey = event as InputEventKey
	if not is_open() or key == null or not key.pressed:
		return false
	match key.keycode:
		KEY_DOWN:
			move_marker(1)
		KEY_UP:
			move_marker(-1)
		KEY_LEFT:
			if _marked >= 0:
				step(_marked as Row, -1)
		KEY_RIGHT:
			if _marked >= 0:
				step(_marked as Row, 1)
		KEY_ENTER, KEY_KP_ENTER, KEY_SPACE:
			if _marked >= 0 and not key.echo:
				_press(_entries[_marked])
		KEY_ESCAPE:
			if not key.echo:
				_cancel()
		_:
			return false
	return true


## Moves `row`'s value `by` steps (Left / Right): a chip row or a volume; REDUCED MOTION turns on
## with Right and off with Left.
func step(row: Row, by: int) -> void:
	match row:
		Row.DISPLAY:
			_set_display(by > 0)
		Row.MUSIC:
			_set_volume(Row.MUSIC, ProfileSettings.music_volume(profile) + by)
		Row.SOUND:
			_set_volume(Row.SOUND, ProfileSettings.sound_volume(profile) + by)
		Row.TEXT:
			_set_text_size(ProfileSettings.text_size(profile) + by)
		Row.MOTION:
			_set_motion(by > 0)
		Row.SPEED:
			_set_speed(by > 0)


func _press(entry: Control) -> void:
	match _entries.find(entry):
		Row.DISPLAY:
			_set_display(ProfileSettings.display(profile) != ProfileState.DISPLAY_FULLSCREEN)
		Row.TEXT:
			_set_text_size(
				(ProfileSettings.text_size(profile) + 1) % ProfileState.TEXT_SIZES.size()
			)
		Row.MOTION:
			_set_motion(not profile.reduced_motion())
		Row.SPEED:
			_set_speed(profile.count_up_speed() != ProfileState.COUNT_UP_FAST)
		Row.DONE:
			close()


func _show_marked(entry: Control, on: bool) -> void:
	var index: int = _entries.find(entry)
	if index < _ticks.size():
		_ticks[index].visible = on
	if entry == _done:
		_done.marked = on
	if on and _hint != null:
		_hint.text = HINTS[index] if index < HINTS.size() else DONE_HINT


func _set_display(full: bool) -> void:
	ProfileSettings.set_display(
		profile, ProfileState.DISPLAY_FULLSCREEN if full else ProfileState.DISPLAY_WINDOWED
	)
	settings.apply_display(profile)
	_refresh()


func _set_volume(row: Row, value: int) -> void:
	if row == Row.MUSIC:
		ProfileSettings.set_music_volume(profile, value)
	else:
		ProfileSettings.set_sound_volume(profile, value)
	settings.apply_volumes(profile, music)
	if row == Row.SOUND:
		var sounds: Sfx = Sfx.find(self)
		if sounds != null:
			sounds.play("scan")
	_refresh()


func _set_text_size(index: int) -> void:
	var clamped: int = clampi(index, 0, ProfileState.TEXT_SIZES.size() - 1)
	if clamped == ProfileSettings.text_size(profile):
		return
	ProfileSettings.set_text_size(profile, clamped)
	GameSettings.apply_text_size(profile)
	var marked_now: int = _marked
	_build_content()
	_set_marked(marked_now)


func _set_motion(on: bool) -> void:
	profile.set_reduced_motion(on)
	_refresh()


func _set_speed(fast: bool) -> void:
	profile.set_count_up_speed(ProfileState.COUNT_UP_FAST if fast else ProfileState.COUNT_UP_NORMAL)
	_refresh()


## Shows the profile's values on the rows.
func _refresh() -> void:
	var values: Dictionary[int, int] = {
		Row.DISPLAY:
		1 if ProfileSettings.display(profile) == ProfileState.DISPLAY_FULLSCREEN else 0,
		Row.TEXT: ProfileSettings.text_size(profile),
		Row.MOTION: 1 if profile.reduced_motion() else 0,
		Row.SPEED: 1 if profile.count_up_speed() == ProfileState.COUNT_UP_FAST else 0,
	}
	for row: int in _chips:
		var row_chips: Array = _chips[row]
		for i: int in row_chips.size():
			(row_chips[i] as OptionChip).chosen = i == values[row]
	_volumes[Row.MUSIC].value = ProfileSettings.music_volume(profile)
	_volumes[Row.SOUND].value = ProfileSettings.sound_volume(profile)
	_motion_note.visible = profile.reduced_motion()


## Lays the rows out at the current TEXT SIZE and sizes the sheet to them.
func _build_content() -> void:
	if _content != null:
		_content.queue_free()
		sheet().remove_child(_content)
	_entries.clear()
	_ticks.clear()
	_chips.clear()
	_volumes.clear()
	_rules.clear()
	_marked = -1
	_content = Control.new()
	_content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_content.draw.connect(_draw_rules)
	sheet().add_child(_content)
	var heading: Label = UiKit.pixel_label("OPTIONS", 4, Palette.INK)
	UiKit.place_pixel_label(heading, Rect2(24, 20, 0, 0))
	_content.add_child(heading)
	var tagline: Label = UiKit.pixel_label(
		"SAVED TO YOUR PROFILE · CHANGES APPLY AT ONCE", 2, Palette.GREY
	)
	UiKit.place_pixel_label(tagline, Rect2(26, 62, 0, 0))
	_content.add_child(tagline)
	var y: float = ROWS_TOP
	for row: int in LABELS.size():
		var height: float = _add_row(row as Row, y)
		y += height
		if row < LABELS.size() - 1:
			_rules.append(y - 10.0)
	y += 2.0
	_hint_rule = y
	y += 10.0
	_hint = UiKit.body_label("", UiKit.text_size(HINT_FONT), Palette.INK_LIGHT)
	_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_hint.position = Vector2(HINT_LEFT, y)
	_hint.size = Vector2(SHEET_WIDTH - 2.0 * HINT_LEFT, 0)
	_hint.text = DEFAULT_HINT
	_content.add_child(_hint)
	y += _hint_height() + 14.0
	_done = MenuPlate.new("DONE", MenuPlate.Kind.PLATE, DONE_SIZE)
	_done.centre_caption()
	_done.position = Vector2(24, y)
	_done.pressed.connect(close)
	_content.add_child(_done)
	_add_entry(_done)
	# Centred on DONE's face, between its top row and its shade row and ledge (as its caption).
	_esc = UiKit.pixel_label("ESC", 2, Palette.GREY)
	var face_top: float = y + MenuPlate.PLATE_FACE_TOP
	var face_height: float = DONE_SIZE.y - MenuPlate.PLATE_FACE_TOP - MenuPlate.PLATE_FACE_BOTTOM
	UiKit.place_pixel_label(_esc, Rect2(ESC_LEFT, face_top, 0, face_height), true)
	_content.add_child(_esc)
	y += DONE_SIZE.y + 18.0
	_resize_sheet(Vector2i(WIDTH_ART, ceili(y / ArtStyle.ART_SCALE)))
	_refresh()


## Adds row `row` at `y`; returns its height with the gap under it.
func _add_row(row: Row, y: float) -> float:
	var chip_row: bool = row != Row.MUSIC and row != Row.SOUND
	var height: float = OptionChip.HEIGHT if chip_row else VolumePips.KEY_SIZE.y
	var preview: Control = null
	if row == Row.TEXT:
		preview = _preview(y + 38.0)
		height += 8.0 + preview.size.y
	height += ROW_GAP
	var area: Control = Control.new()
	area.mouse_filter = Control.MOUSE_FILTER_PASS
	area.position = Vector2(8, y - 6)
	area.size = Vector2(SHEET_WIDTH - 16.0, height)
	_content.add_child(area)
	_add_entry(area)
	var tick: TextureRect = UiKit.sprite(MenuPlate.TICK)
	tick.size = MenuPlate.TICK_SIZE
	tick.position = Vector2(TICK_LEFT, y + (8.0 if chip_row else 12.0))
	tick.visible = false
	_content.add_child(tick)
	_ticks.append(tick)
	var caption: Label = UiKit.pixel_label(LABELS[row], 2, Palette.INK)
	UiKit.place_pixel_label(caption, Rect2(LABEL_LEFT, y + (8.0 if chip_row else 14.0), 0, 0))
	_content.add_child(caption)
	var at: Vector2 = Vector2(WIDGET_LEFT, y)
	match row:
		Row.DISPLAY:
			_add_chips(row, at, ["WINDOWED", "FULLSCREEN"])
		Row.TEXT:
			_add_chips(row, at, ["NORMAL", "LARGE", "LARGER"])
			_content.add_child(preview)
		Row.SPEED:
			_add_chips(row, at, ["NORMAL", "FAST"], ["", "×1.5"])
		Row.MUSIC, Row.SOUND:
			var pips: VolumePips = VolumePips.new()
			pips.position = at
			pips.value_picked.connect(func(picked: int) -> void: _set_volume(row, picked))
			_content.add_child(pips)
			_volumes[row] = pips
		Row.MOTION:
			_add_chips(row, at, ["OFF", "ON"])
			var last: OptionChip = _chips[row][-1]
			_motion_note = UiKit.pixel_label("THE STORE STANDS STILL", 2, Palette.GREY)
			UiKit.place_pixel_label(
				_motion_note,
				Rect2(last.position.x + last.size.x + 2.0 * CHIP_GAP, y, 0, OptionChip.HEIGHT),
				true
			)
			_content.add_child(_motion_note)
	return height


## Adds `row`'s chips at `at`: `captions` in words, each followed by its `numbers` entry (if any)
## in the number font.
func _add_chips(
	row: Row, at: Vector2, captions: Array[String], numbers: Array[String] = []
) -> void:
	var row_chips: Array = []
	var x: float = at.x
	for i: int in captions.size():
		var chip: OptionChip = OptionChip.new(captions[i], numbers[i] if i < numbers.size() else "")
		chip.position = Vector2(x, at.y)
		chip.pressed.connect(_pick_chip.bind(row, i))
		_content.add_child(chip)
		row_chips.append(chip)
		x += chip.size.x + CHIP_GAP
	_chips[row] = row_chips


func _pick_chip(row: Row, index: int) -> void:
	match row:
		Row.DISPLAY:
			_set_display(index == 1)
		Row.TEXT:
			_set_text_size(index)
		Row.MOTION:
			_set_motion(index == 1)
		Row.SPEED:
			_set_speed(index == 1)


## TEXT SIZE's preview: a rule's line on receipt paper at the chosen size.
func _preview(top: float) -> Control:
	var font_size: int = UiKit.text_size(PREVIEW_FONT)
	var text_width: float = PREVIEW_WIDTH - 20.0
	var lines: Vector2 = ArtStyle.BODY_FONT.get_multiline_string_size(
		PREVIEW, HORIZONTAL_ALIGNMENT_LEFT, text_width, font_size
	)
	var paper: PanelContainer = UiKit.frame_panel(RECEIPT_FRAME, 2)
	paper.mouse_filter = Control.MOUSE_FILTER_IGNORE
	paper.position = Vector2(WIDGET_LEFT, top)
	paper.size = Vector2(PREVIEW_WIDTH, ceilf((lines.y + 14.0) / 2.0) * 2.0)
	var text: Label = UiKit.body_label(PREVIEW, font_size, Palette.INK)
	text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	text.position = Vector2(10, 7)
	text.size = Vector2(text_width, lines.y)
	var holder: Control = Control.new()
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.position = paper.position
	holder.size = paper.size
	paper.position = Vector2.ZERO
	holder.add_child(paper)
	holder.add_child(text)
	return holder


## The tallest hint at the current TEXT SIZE, so the sheet never jumps as the marker moves.
func _hint_height() -> float:
	var tallest: float = 0.0
	var all_hints: Array[String] = HINTS.duplicate()
	all_hints.append(DONE_HINT)
	for hint: String in all_hints:
		var measured: Vector2 = ArtStyle.BODY_FONT.get_multiline_string_size(
			hint,
			HORIZONTAL_ALIGNMENT_LEFT,
			SHEET_WIDTH - 2.0 * HINT_LEFT,
			UiKit.text_size(HINT_FONT)
		)
		tallest = maxf(tallest, measured.y)
	return ceilf(tallest)


func _draw_rules() -> void:
	for top: float in _rules:
		_dash(top, Palette.CREAM_SHADE)
	_dash(_hint_rule, Palette.CREAM_DARKEST)


func _dash(top: float, color: Color) -> void:
	var x: float = 24.0
	while x < SHEET_WIDTH - 24.0:
		_content.draw_rect(Rect2(x, top, 4, 2), color)
		x += 8.0
