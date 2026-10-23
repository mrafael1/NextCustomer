class_name TitleScreen
extends Control
## The title screen (plan section 7): a click starts the game, which also lets browsers play
## audio: the title's first click or key press (on a button too) starts its music, the front
## loop (#62, Q2), unless that press starts the run; the shift screen crossfades it away. The
## Export log button works here too, so testers can send their log at any time. It shows the
## run's length from balance data and the profile's coins (full build plan 7.1).
##
## When a run save can be read (full build plan section 4), the title offers Continue (the
## shift screen resumes the save) and New run instead, and a background click starts nothing.
## Enter or Space continues. New run asks first; on yes the saved run is abandoned (deleted,
## and logged as run_abandon under its run id) and a new run starts. An abandoned run records
## nothing in the profile, like a restart before the end.
##
## The title has its own Sfx (#62), warmed up when it opens: its buttons click (UiKit), the
## start click too, the New run confirmation opens and closes (ui_open, ui_close) and the log
## export confirms. The Sfx outlives the title for a moment when the shift screen replaces it,
## so the start click is heard in full.
##
## The TOY MACHINES (#63): a toy machine prop and a "Toy machines ›" button stand in the free
## space on the right, anchored centre-right (title B of #56, whose right-hand space they were
## decided for, isn't built yet). The button opens the machines over the title on the peeked
## profile (an unreadable one opens them switched off, left for the shift screen to report and
## back up). A draw while a run is saved gets that run's index (its item rides the runs after it,
## "In stock after your saved run"). While they are open, nothing on the title starts a run; Done
## closes them and refreshes the coin line.

const SHIFT_SCREEN := "res://ui/shift_screen.tscn"
const BALANCE := "res://data/balance/balance.tres"
const ABANDON_QUESTION := "Abandon the run in progress? It won't count."
const MUSIC := &"front"
## The subtitle wraps at this width, so the centred column stays clear of the toy machines.
const SUBTITLE_WIDTH := 720.0
## The toy machines' group: the prop (the first aisle's machine at 2x) over the button, this far
## from the window's right edge, vertically centred.
const TOYS_PROP_PATH := "res://art/scenery/toy_machine_%s.png"
const TOYS_PROP_SIZE := Vector2(144, 280)
const TOYS_BUTTON_SIZE := Vector2(200, 56)
const TOYS_RIGHT := 40.0
const TOYS_GAP := 12

## Tests turn this off so starting doesn't replace the test runner's scene.
var changes_scene: bool = true
var _starting: bool = false
var _subtitle: Label
var _coins: Label
## The run save found at start, or null. Read without reporting or backing up anything: the
## shift screen does that when it loads the save.
var _saved_run: RunSave
var _continue_button: Button
var _new_run_button: Button
## The New run confirmation, over a shade that blocks clicks behind it.
var _confirm_shade: ColorRect
var _confirm: PanelContainer
var _abandon_button: Button
var _keep_button: Button
var _sfx: Sfx
## The first click or key press started the music.
var _music_started: bool = false
var _balance: BalanceDefinition
var _toys_group: VBoxContainer
var _toys_button: Button
var _toys_prop: TextureRect
## The TOY MACHINES over the title, made the first time they open.
var _toys: ToyMachinesScreen
@onready var _log: EventLogService = get_node("/root/EventLog")
@onready var _music: MusicService = get_node("/root/Music")


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	var background: ColorRect = ColorRect.new()
	background.color = Palette.BACKGROUND
	background.set_anchors_preset(Control.PRESET_FULL_RECT)
	background.gui_input.connect(_on_background_input)
	add_child(background)
	_sfx = Sfx.new()
	add_child(_sfx)
	_sfx.warm_up()

	var column: VBoxContainer = VBoxContainer.new()
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.alignment = BoxContainer.ALIGNMENT_CENTER
	column.set_anchors_preset(Control.PRESET_FULL_RECT)
	column.add_theme_constant_override("separation", 18)
	add_child(column)
	var title: Label = UiKit.label("NEXT CUSTOMER", 84, Palette.MUSTARD)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_constant_override("outline_size", 14)
	title.add_theme_color_override("font_outline_color", Palette.INK)
	column.add_child(title)
	var balance: BalanceDefinition = load(BALANCE)
	_balance = balance
	_subtitle = UiKit.label(
		(
			"Scan groceries and coupons in the best order. Meet the quota on all %d shifts."
			% balance.quotas.size()
		),
		22,
		Palette.LIGHT_TEXT
	)
	_subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_subtitle.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_subtitle.custom_minimum_size.x = SUBTITLE_WIDTH
	_subtitle.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	column.add_child(_subtitle)
	var saves: SaveService = SaveService.new(SaveService.default_folder())
	_coins = UiKit.label(coins_text(saves), 22, Palette.MUSTARD)
	_coins.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(_coins)
	_saved_run = saves.peek_run(ContentLookup.new(balance))
	if _saved_run == null:
		_add_prompt(column)
	else:
		_add_run_buttons(column)

	var corner: HBoxContainer = HBoxContainer.new()
	corner.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	corner.offset_top = -56
	corner.offset_left = 20
	corner.offset_right = -20
	corner.offset_bottom = -16
	add_child(corner)
	UiKit.button(corner, "Export log", _on_export_pressed, 16, "")
	var build: Label = UiKit.label(
		str(ProjectSettings.get_setting("next_customer/build_label", "")), 14, Palette.LIGHT_TEXT
	)
	build.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	build.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	corner.add_child(build)
	_add_toy_machines()
	if _saved_run != null:
		_add_confirmation()


## The coin line: the saved profile's coins, read without reporting or backing anything up (the
## shift screen does that when it loads the profile).
static func coins_text(saves: SaveService) -> String:
	var profile: ProfileState = saves.peek_profile()
	if profile == null:
		return "Coins: ?"
	return "Coins: %d" % profile.coins


## The Continue button's text: the saved run's shift out of the run's shifts.
static func continue_text(saved: RunSave) -> String:
	return "Continue (shift %d / %d)" % [saved.run.shift_index + 1, saved.run.shift_count()]


func _add_prompt(column: VBoxContainer) -> void:
	var prompt: Label = UiKit.label("Click anywhere to start", 30, Palette.CREAM)
	prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(prompt)
	var pulse: Tween = create_tween().set_loops()
	pulse.tween_property(prompt, "modulate:a", 0.35, 0.7)
	pulse.tween_property(prompt, "modulate:a", 1.0, 0.7)


func _add_run_buttons(column: VBoxContainer) -> void:
	var buttons: HBoxContainer = HBoxContainer.new()
	buttons.mouse_filter = Control.MOUSE_FILTER_IGNORE
	buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	buttons.add_theme_constant_override("separation", 24)
	column.add_child(buttons)
	_continue_button = UiKit.button(buttons, continue_text(_saved_run), _on_continue_pressed, 26)
	_new_run_button = UiKit.button(buttons, "New run", _on_new_run_pressed, 26)
	for button: Button in [_continue_button, _new_run_button]:
		button.custom_minimum_size = Vector2(200, 64)


## The toy machine prop and its button, anchored centre-right.
func _add_toy_machines() -> void:
	_toys_group = VBoxContainer.new()
	# Stops clicks in the gap, so they never reach the background and start a run.
	_toys_group.mouse_filter = Control.MOUSE_FILTER_STOP
	_toys_group.add_theme_constant_override("separation", TOYS_GAP)
	var height: float = TOYS_PROP_SIZE.y + TOYS_GAP + TOYS_BUTTON_SIZE.y
	var width: float = maxf(TOYS_PROP_SIZE.x, TOYS_BUTTON_SIZE.x)
	_toys_group.anchor_left = 1.0
	_toys_group.anchor_right = 1.0
	_toys_group.anchor_top = 0.5
	_toys_group.anchor_bottom = 0.5
	_toys_group.offset_left = -TOYS_RIGHT - width
	_toys_group.offset_right = -TOYS_RIGHT
	_toys_group.offset_top = -height / 2.0
	_toys_group.offset_bottom = height / 2.0
	add_child(_toys_group)
	var path: String = TOYS_PROP_PATH % _balance.aisles[0].id
	var texture: Texture2D = (
		load(path) as Texture2D if ResourceLoader.exists(path) else ToyMachineView.BASE_BODY
	)
	_toys_prop = UiKit.sprite(texture)
	_toys_prop.custom_minimum_size = TOYS_PROP_SIZE
	_toys_prop.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	# The prop invites a click: it opens the machines, as the button does.
	_toys_prop.mouse_filter = Control.MOUSE_FILTER_STOP
	_toys_prop.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	_toys_prop.gui_input.connect(_on_toys_prop_input)
	_toys_group.add_child(_toys_prop)
	_toys_button = UiKit.button(
		_toys_group, ResultsPanel.TOY_MACHINES_TEXT, _on_toy_machines_pressed, 22
	)
	_toys_button.custom_minimum_size = TOYS_BUTTON_SIZE


## Whether the TOY MACHINES are open over the title.
func toy_machines_open() -> bool:
	return _toys != null and _toys.visible


func _on_toys_prop_input(event: InputEvent) -> void:
	var press: InputEventMouseButton = event as InputEventMouseButton
	if press and press.pressed and press.button_index == MOUSE_BUTTON_LEFT:
		_toys_prop.accept_event()
		_on_toy_machines_pressed()


## Opens the TOY MACHINES on the saved profile, read without reporting or backing anything up:
## an unreadable profile opens them switched off. A title draw belongs to no run.
func _on_toy_machines_pressed() -> void:
	if _starting:
		return
	var saves: SaveService = SaveService.new(SaveService.default_folder())
	var peeked: ProfileState = saves.peek_profile()
	var profile: ProfileState = peeked if peeked != null else ProfileState.new()
	if _toys == null:
		_toys = ToyMachinesScreen.new()
		add_child(_toys)
		_toys.closed.connect(_on_toy_machines_closed)
	_log.run_id = ""
	var counter: CapsuleCounter = CapsuleCounter.new(
		profile, saves, _balance, _log, _saved_run != null, peeked != null
	)
	_toys.open(counter, _balance)


func _on_toy_machines_closed() -> void:
	_coins.text = coins_text(SaveService.new(SaveService.default_folder()))


## The New run question, hidden until New run is pressed. Added last, so it sits above
## everything else.
func _add_confirmation() -> void:
	_confirm_shade = ColorRect.new()
	_confirm_shade.color = Color(0, 0, 0, 0.5)
	_confirm_shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	_confirm_shade.mouse_filter = Control.MOUSE_FILTER_STOP
	_confirm_shade.visible = false
	add_child(_confirm_shade)
	_confirm = UiKit.paper_panel()
	_confirm.visible = false
	add_child(_confirm)
	var column: VBoxContainer = VBoxContainer.new()
	column.add_theme_constant_override("separation", 18)
	_confirm.add_child(column)
	var question: Label = UiKit.label(ABANDON_QUESTION, 26, Palette.INK)
	question.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(question)
	var buttons: HBoxContainer = HBoxContainer.new()
	buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	buttons.add_theme_constant_override("separation", 16)
	column.add_child(buttons)
	_abandon_button = UiKit.button(buttons, "Yes, start a new run", _on_abandon_confirmed, 20)
	_keep_button = UiKit.button(buttons, "No, keep it", _on_abandon_cancelled, 20, "ui_close")


## Browsers play audio only after a click or key press, so the music starts on the first one,
## once the buttons and the background have handled it: a press that starts the run (a click
## on the background, Enter or Space without a save, or a mouse press on a button that starts
## it on release) leaves it to the shift screen's loop, so the front loop isn't loaded only to
## be faded out.
func _input(event: InputEvent) -> void:
	if _music_started or not is_audio_gesture(event) or _presses_start_button(event):
		return
	_music_started = true
	_start_music.call_deferred()


func _start_music() -> void:
	if not _starting:
		_music.play(MUSIC)


## A mouse press on Continue or "Yes, start a new run": buttons act on release, after the
## deferred music start would already have run.
func _presses_start_button(event: InputEvent) -> bool:
	var press: InputEventMouseButton = event as InputEventMouseButton
	if press == null or toy_machines_open():
		return false
	for button: Button in [_continue_button, _abandon_button]:
		if button != null and button.is_visible_in_tree():
			if button.get_global_rect().has_point(press.position):
				return true
	return false


## A press that lets browsers play audio: a mouse button, a key or a touch.
static func is_audio_gesture(event: InputEvent) -> bool:
	if event is InputEventMouseButton or event is InputEventKey or event is InputEventScreenTouch:
		return event.is_pressed() and not event.is_echo()
	return false


func _unhandled_key_input(event: InputEvent) -> void:
	var key: InputEventKey = event as InputEventKey
	if not (key and key.pressed and (key.keycode == KEY_ENTER or key.keycode == KEY_SPACE)):
		return
	if toy_machines_open():
		return
	if _saved_run == null:
		_click_start()
	elif not _confirm.visible:
		_click_start()  # Continue.


## Without a run save, a click anywhere starts. With one, only the buttons do.
func _on_background_input(event: InputEvent) -> void:
	var press: InputEventMouseButton = event as InputEventMouseButton
	if press and press.pressed and press.button_index == MOUSE_BUTTON_LEFT:
		if _saved_run == null and not toy_machines_open():
			_click_start()


func _on_export_pressed() -> void:
	_log.export_logs("title")
	_sfx.play("ui_confirm")


## The shift screen resumes the save.
func _on_continue_pressed() -> void:
	_start()


func _on_new_run_pressed() -> void:
	if _starting:
		return
	_confirm_shade.visible = true
	UiKit.pop_in(_confirm)


func _on_abandon_cancelled() -> void:
	_confirm_shade.visible = false
	_confirm.visible = false


## Deletes the saved run and starts a new one. If the save can't be deleted (reported), the
## title stays as it is: the shift screen would only resume it.
func _on_abandon_confirmed() -> void:
	if _starting:
		return
	if not SaveService.new(SaveService.default_folder()).delete_run():
		_on_abandon_cancelled()
		return
	_log.resume_run(_saved_run.run_id)
	_log.log_event("run_abandon", RunEvents.run_abandon(_saved_run.run, _saved_run.run_ms))
	_start()


## A start without a button (a background click, Enter or Space) clicks like one.
func _click_start() -> void:
	if not _starting:
		_sfx.play(UiKit.CLICK_SOUND)
	_start()


func _start() -> void:
	if _starting:
		return
	_starting = true
	if changes_scene:
		# The start click finishes over the shift screen.
		_sfx.outlive_scene()
		# A new run there opens on the cart reveal (v0.51); a resumed run ignores it.
		CartReveal.request()
		get_tree().change_scene_to_file(SHIFT_SCREEN)
