class_name TitleScreen
extends Control
## The title screen (plan section 7; #56, mock-up title_premium_directions.html, direction C+
## "Storefront at night"): the store seen from the street at night (Storefront), its neon sign
## NEXT CUSTOMER over the doors, the menu's plates on the brick left of them (TitleMenu) and the
## REWARDS bay on the right, everything pixel art on the 2 px grid.
##
## The sign is dark when the title opens. After INTRO_DARK seconds it lights letter by letter,
## then the plates step in; the first click or key before that lights it and shows the plates at
## once (skip_intro), and does nothing else. The profile's reduced motion lights it at once and
## holds every loop and slide (Storefront, TitleMenu and the popups take `still`).
##
## The menu: without a run save, START RUN (the run's length under it, from balance data) and
## REWARDS (the profile's coins on it, read without reporting or backing anything up); with one
## (full build plan section 4), CONTINUE (the saved shift under it: the shift screen resumes the
## save), NEW RUN and REWARDS. The mouse on a plate, Up and Down, or the mouse on the doors or
## the bay mark an entry (the doors stand ajar for the primary entry, the bay lights for
## REWARDS); Enter or Space press the marked entry, or the primary one when none is marked.
## Clicking the doors is the primary entry, clicking the bay is REWARDS, and clicking the sign
## scans it (its hidden toy). NEW RUN asks first (AbandonConfirm): on ABANDON the saved run is
## deleted, logged as run_abandon under its run id, and a new run starts. An abandoned run
## records nothing in the profile, like a restart before the end.
##
## REWARDS (RewardsMenu): the bay's glass slides aside and the menu opens over the dimmed
## storefront. TOY MACHINES opens the machines (#63) over it on the peeked profile (an unreadable
## one opens them switched off, left for the shift screen to report and back up); a draw while a
## run is saved gets that run's index (its item rides the runs after it). Done closes them and
## refreshes the coins. LOYALTY is locked (SOON) and only says no. BACK or Esc close REWARDS.
## While a popup or the machines are open, nothing on the title starts a run.
##
## A start opens the doors (the leaves slide apart, the light floods out) before the shift screen
## replaces the title. Browsers play audio only after a click or key press: the title's first one
## starts its music, the front loop (#62, Q2), unless that press starts the run. The title has its
## own Sfx (#62), warmed up when it opens; it outlives the title for a moment, so the start is
## heard in full. The Export log icon (bottom left) works here too, so testers can send their
## log at any time; the build label stands in the bottom right corner.

## What a click on the storefront lands on: nothing, the doors, the REWARDS bay or the sign.
enum Target { NONE, DOORS, BAY, SIGN }

const SHIFT_SCREEN := "res://ui/shift_screen.tscn"
const BALANCE := "res://data/balance/balance.tres"
const MUSIC := &"front"
## The sign stays dark this long before it lights by itself (the mock-up's 2.5 s).
const INTRO_DARK := 2.5
## The start: the click, then the register's bell as the doors open.
const START_SOUND := "register_bell"
const EXPORT_SOUND := "ui_confirm"
## The Export log icon (icons/export_log, 12x12 art at 2x) and the build label on the stage, in
## canvas px (the mock-up's art px at 2x): the icon in the bottom left corner, the label's right
## edge at BUILD_RIGHT on the same line.
const EXPORT_ICON := preload("res://art/icons/export_log.png")
const EXPORT_ICON_HOT := preload("res://art/icons/export_log_hot.png")
const EXPORT_RECT := Rect2(16, 680, 24, 24)
const EXPORT_TIP := "Export log"
const BUILD_RIGHT := 1264.0
const BUILD_WIDTH := 240.0
const BUILD_FONT_SIZE := 14

## Tests turn this off so starting doesn't replace the test runner's scene.
var changes_scene: bool = true
var _starting: bool = false
## The run save found at start, or null. Read without reporting or backing up anything: the
## shift screen does that when it loads the save.
var _saved_run: RunSave
## The profile's coins (peek_coins: -1 when the profile can't be read).
var _coins: int = 0
var _balance: BalanceDefinition
var _sfx: Sfx
## The first click or key press started the music.
var _music_started: bool = false
var _still: bool = false
## Seconds the sign has been dark (it lights at INTRO_DARK).
var _dark_for: float = 0.0
var _storefront: Storefront
## Takes the clicks and the mouse on the storefront (under the menu, on the stage).
var _hit: Control
var _menu: TitleMenu
## The entry the doors or the bay marked (NONE when the mouse is on neither).
var _scene_entry: TitleMenu.Entry = TitleMenu.Entry.NONE
var _rewards: RewardsMenu
## The bay's glass is sliding before REWARDS opens.
var _rewards_pending: bool = false
## The New run question (only with a run saved).
var _confirm: AbandonConfirm
var _export: TextureButton
var _build: Label
## The TOY MACHINES over the title, made the first time they open.
var _toys: ToyMachinesScreen
@onready var _log: EventLogService = get_node("/root/EventLog")
@onready var _music: MusicService = get_node("/root/Music")


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_balance = load(BALANCE)
	_sfx = Sfx.new()
	add_child(_sfx)
	_sfx.warm_up()
	var saves: SaveService = SaveService.new(SaveService.default_folder())
	_saved_run = saves.peek_run(ContentLookup.new(_balance))
	_coins = peek_coins(saves)
	var profile: ProfileState = saves.peek_profile()
	_still = profile != null and profile.reduced_motion()

	_storefront = Storefront.new()
	_storefront.still = _still
	add_child(_storefront)
	var stage: Control = _storefront.stage()
	_hit = Control.new()
	_hit.size = Storefront.STAGE_SIZE
	_hit.mouse_filter = Control.MOUSE_FILTER_STOP
	_hit.gui_input.connect(_on_scene_input)
	_hit.mouse_exited.connect(_mark_from_scene.bind(TitleMenu.Entry.NONE))
	stage.add_child(_hit)
	var sub_line: String = (
		TitleMenu.length_line(_balance)
		if _saved_run == null
		else TitleMenu.continue_line(_saved_run)
	)
	_menu = TitleMenu.new(_saved_run != null, sub_line, _coins)
	_menu.still = _still
	_menu.hot_changed.connect(_on_hot_changed)
	_menu.start_pressed.connect(_on_start_pressed)
	_menu.new_run_pressed.connect(_on_new_run_pressed)
	_menu.rewards_pressed.connect(_on_rewards_pressed)
	stage.add_child(_menu)
	_add_corner(stage)
	_storefront.sign_lit.connect(_on_sign_lit)

	_rewards = RewardsMenu.new(_balance)
	_rewards.still = _still
	_rewards.toy_machines_requested.connect(_on_toy_machines_pressed)
	add_child(_rewards)
	if _saved_run != null:
		_confirm = AbandonConfirm.new()
		_confirm.still = _still
		_confirm.abandon_confirmed.connect(_on_abandon_confirmed)
		add_child(_confirm)
	if _still:
		_storefront.light_now()


## The profile's coins, read without reporting or backing anything up (the shift screen does
## that when it loads the profile): 0 without a profile, -1 when it can't be read.
static func peek_coins(saves: SaveService) -> int:
	var profile: ProfileState = saves.peek_profile()
	return profile.coins if profile != null else -1


## A press that lets browsers play audio: a mouse button, a key or a touch.
static func is_audio_gesture(event: InputEvent) -> bool:
	if event is InputEventMouseButton or event is InputEventKey or event is InputEventScreenTouch:
		return event.is_pressed() and not event.is_echo()
	return false


## The sign is still dark or lighting, or the plates are still stepping in.
func is_intro_playing() -> bool:
	return not _storefront.is_lit() or not _menu.is_shown() or _menu.is_stepping()


## Ends the intro at once (a click or key during it; tests before they look): the sign lit and
## the plates in place. False when it had already ended.
func skip_intro() -> bool:
	if not is_intro_playing():
		return false
	_storefront.light_now()
	_menu.finish_step_in()
	return true


## Whether the TOY MACHINES are open over the title.
func toy_machines_open() -> bool:
	return _toys != null and _toys.visible


## What the storefront shows at `point` (global canvas px) that a click acts on.
func target_at(point: Vector2) -> Target:
	var local: Vector2 = point - _storefront.global_position
	if _storefront.doors_rect().has_point(local):
		return Target.DOORS
	if _storefront.bay_rect().has_point(local):
		return Target.BAY
	if _storefront.sign_rect().has_point(local):
		return Target.SIGN
	return Target.NONE


## The pieces, for tests and captures.
func storefront() -> Storefront:
	return _storefront


func menu() -> TitleMenu:
	return _menu


func rewards() -> RewardsMenu:
	return _rewards


## The New run question, or null without a run save.
func abandon_confirm() -> AbandonConfirm:
	return _confirm


func export_button() -> TextureButton:
	return _export


func build_label() -> Label:
	return _build


## The layer that takes the storefront's clicks (the doors, the bay, the sign).
func scene_hit() -> Control:
	return _hit


func _process(delta: float) -> void:
	if _storefront.is_lit():
		return
	_dark_for += delta
	if _dark_for >= INTRO_DARK:
		_storefront.light_up()


## The Export log icon and the build label, discreet in the stage's bottom corners.
func _add_corner(stage: Control) -> void:
	_export = TextureButton.new()
	_export.texture_normal = EXPORT_ICON
	_export.texture_hover = EXPORT_ICON_HOT
	_export.texture_pressed = EXPORT_ICON_HOT
	_export.ignore_texture_size = true
	_export.stretch_mode = TextureButton.STRETCH_SCALE
	_export.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_export.focus_mode = Control.FOCUS_NONE
	_export.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	_export.tooltip_text = EXPORT_TIP
	_export.accessibility_name = EXPORT_TIP
	_export.position = EXPORT_RECT.position
	_export.size = EXPORT_RECT.size
	_export.pressed.connect(_on_export_pressed)
	stage.add_child(_export)
	_build = UiKit.number_label(
		str(ProjectSettings.get_setting("next_customer/build_label", "")), BUILD_FONT_SIZE, false
	)
	_build.add_theme_color_override("font_color", Palette.GREY)
	_build.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_build.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_build.position = Vector2(BUILD_RIGHT - BUILD_WIDTH, EXPORT_RECT.position.y)
	_build.size = Vector2(BUILD_WIDTH, EXPORT_RECT.size.y)
	stage.add_child(_build)


## The plates step in once the sign is lit (at once when still or skipped).
func _on_sign_lit() -> void:
	_menu.step_in()


## The storefront follows the marked entry: the doors stand ajar for the primary entry, the bay
## lights for REWARDS. Once a run is starting the doors are opening and nothing changes them.
func _on_hot_changed(entry: TitleMenu.Entry) -> void:
	if _starting:
		return
	_storefront.doors_hot = entry == TitleMenu.Entry.PRIMARY
	_storefront.bay_hot = entry == TitleMenu.Entry.REWARDS


## Nothing on the title acts: a run is starting, or a popup or the machines are over it.
func _busy() -> bool:
	return (
		_starting
		or _rewards_pending
		or toy_machines_open()
		or _rewards.is_open()
		or (_confirm != null and _confirm.is_open())
	)


## The storefront under the mouse: the doors and the bay mark their entries (and show the hand
## cursor, as the sign does); a click on them presses their entry, on the sign scans it. A click
## during the intro only ends it.
func _on_scene_input(event: InputEvent) -> void:
	var mouse: InputEventMouse = event as InputEventMouse
	if mouse == null:
		return
	var target: Target = target_at(_hit.get_global_transform() * mouse.position)
	var press: InputEventMouseButton = event as InputEventMouseButton
	if press != null and press.pressed and press.button_index == MOUSE_BUTTON_LEFT:
		_hit.accept_event()
		if _busy() or skip_intro():
			return
		match target:
			Target.DOORS:
				_menu.activate(TitleMenu.Entry.PRIMARY)
			Target.BAY:
				_menu.activate(TitleMenu.Entry.REWARDS)
			Target.SIGN:
				_storefront.scan_sign()
		return
	if event is InputEventMouseMotion:
		var shown: bool = _menu.is_shown() and not _busy()
		_hit.mouse_default_cursor_shape = (
			Control.CURSOR_POINTING_HAND
			if shown and target != Target.NONE
			else Control.CURSOR_ARROW
		)
		var entry: TitleMenu.Entry = TitleMenu.Entry.NONE
		if shown and target == Target.DOORS:
			entry = TitleMenu.Entry.PRIMARY
		elif shown and target == Target.BAY:
			entry = TitleMenu.Entry.REWARDS
		_mark_from_scene(entry)


## Moves the marker the doors or the bay set (NONE: the mouse left them).
func _mark_from_scene(entry: TitleMenu.Entry) -> void:
	if entry == _scene_entry:
		return
	if _scene_entry != TitleMenu.Entry.NONE:
		_menu.unmark(_scene_entry)
	_scene_entry = entry
	if entry != TitleMenu.Entry.NONE:
		_menu.mark(entry)


## Browsers play audio only after a click or key press, so the music starts on the first one,
## once the menu and the storefront have handled it: a press that starts the run (a mouse press
## on the primary plate or ABANDON, which act on release; a click on the doors and Enter or Space
## start at once) leaves it to the shift screen's loop, so the front loop isn't loaded only to
## be faded out.
func _input(event: InputEvent) -> void:
	if _music_started or not is_audio_gesture(event) or _presses_start_button(event):
		return
	_music_started = true
	_start_music.call_deferred()


func _start_music() -> void:
	if not _starting:
		_music.play(MUSIC)


## A mouse press on the primary plate or ABANDON: buttons act on release, after the deferred
## music start would already have run.
func _presses_start_button(event: InputEvent) -> bool:
	var press: InputEventMouseButton = event as InputEventMouseButton
	if press == null or toy_machines_open():
		return false
	var buttons: Array[Control] = [_menu.plate(TitleMenu.Entry.PRIMARY)]
	if _confirm != null:
		buttons.append(_confirm.abandon_plate())
	for button: Control in buttons:
		if button.is_visible_in_tree() and button.get_global_rect().has_point(press.position):
			return true
	return false


## The keys: a popup's own while one is open (the arrows, Enter, Space, Esc); during the intro
## any key only ends it; then the menu's (Up, Down, Enter, Space).
func _unhandled_key_input(event: InputEvent) -> void:
	var key: InputEventKey = event as InputEventKey
	if key == null or not key.pressed or _starting or toy_machines_open() or _rewards_pending:
		return
	var handled: bool = false
	if _rewards.is_open():
		handled = _rewards.handle_key(event)
	elif _confirm != null and _confirm.is_open():
		handled = _confirm.handle_key(event)
	elif not key.echo and skip_intro():
		handled = true
	else:
		handled = _menu.handle_key(event)
	if handled:
		get_viewport().set_input_as_handled()


func _on_export_pressed() -> void:
	_log.export_logs("title")
	_sfx.play(EXPORT_SOUND)


## CONTINUE (the shift screen resumes the save) or START RUN.
func _on_start_pressed() -> void:
	if _busy():
		return
	_sfx.play(UiKit.CLICK_SOUND)
	_start()


func _on_new_run_pressed() -> void:
	if _busy() or _confirm == null:
		return
	_sfx.play(UiKit.CLICK_SOUND)
	_confirm.open(AbandonConfirm.lost_line(_saved_run))


## REWARDS: the bay's glass slides aside, then the menu opens over the storefront.
func _on_rewards_pressed() -> void:
	if _busy():
		return
	_sfx.play(UiKit.CLICK_SOUND)
	_rewards_pending = true
	var sliding: Tween = _storefront.slide_bay_glass()
	sliding.finished.connect(_open_rewards)


func _open_rewards() -> void:
	_rewards_pending = false
	if not _starting:
		_rewards.open(_coins)


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


## Done: the coins on REWARDS and its LED follow the draws.
func _on_toy_machines_closed() -> void:
	_coins = peek_coins(SaveService.new(SaveService.default_folder()))
	_menu.set_coins(_coins)
	_rewards.set_coins(_coins)


## Deletes the saved run and starts a new one. If the save can't be deleted (reported), the
## title stays as it is: the shift screen would only resume it.
func _on_abandon_confirmed() -> void:
	if _starting:
		return
	if not SaveService.new(SaveService.default_folder()).delete_run():
		return
	_log.resume_run(_saved_run.run_id)
	_log.log_event("run_abandon", RunEvents.run_abandon(_saved_run.run, _saved_run.run_ms))
	_start()


## The doors open (the light floods out at once when still), then the shift screen replaces the
## title.
func _start() -> void:
	if _starting:
		return
	_starting = true
	_mark_from_scene(TitleMenu.Entry.NONE)
	_menu.frozen = true
	_sfx.play(START_SOUND)
	var opening: Tween = _storefront.open_doors()
	if changes_scene:
		await opening.finished
		# The start's sounds finish over the shift screen.
		_sfx.outlive_scene()
		# A new run there opens on the cart reveal (v0.51); a resumed run ignores it.
		CartReveal.request()
		get_tree().change_scene_to_file(SHIFT_SCREEN)
