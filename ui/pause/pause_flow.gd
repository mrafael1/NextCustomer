class_name PauseFlow
extends RefCounted
## The shift screen's pause and options (mock-up options_pause.html, direction A). Esc first
## closes the topmost thing as before (a drag snaps back; the picker, a popup, the day slip and
## the handbook take their own Esc first, as their nodes see it before the pause's layer); with
## nothing open Esc opens the pause, as do P and the ☰ button. It can't open on the results,
## during the cart reveal's first REVEAL_GUARD_MS, or without a run.
##
## The pause sets get_tree().paused: its layer runs PROCESS_MODE_ALWAYS, so the count-up's
## tweens, the machine and the belt freeze and resume where they stopped. The music ducks; the
## run's played time and the shift's planning time leave the paused time out. SAVE & QUIT adds
## no save point: the run was saved at its last wait (the CHECKOUT click saves MACHINE_CHOOSE,
## so a quit during the count-up resumes at the machine with the checkout's end state); a drag
## snaps back, then the title opens and CONTINUE resumes. Alt+Enter flips DISPLAY anywhere.
##
## Polish batch 2: opening time's Esc (the start board's page 1, nothing else open there) opens the
## options alone over the paused board, with BACK TO TITLE (open_start_options); Esc or DONE
## closes them and the board runs on.
##
## The tutorial (2026-11-14): the run's handbook (the top bar's or the pause's) offers PLAY THE
## GUIDED SHIFT on its first tab, except in a guided run; a click asks for the next new run to be
## guided (TutorialFlags.GUIDE_REPLAY on the screen's profile, saved at once, logged as
## tutorial_replay from "run"). The saved run is never touched. The options' RESET TIPS is logged
## as tips_reset under the run (the profile is saved when the options close).

## The cart reveal's first moments, when the pause can't open.
const REVEAL_GUARD_MS := 300
## The music's duck under the pause.
const DUCK_DB := -9.0
const DUCK_FADE := 0.15
## How long the SAVED sign shows before the title opens.
const SAVED_SECONDS := 0.35
## The pause's layer, over every other layer of the screen.
const LAYER := 90

var pause: PauseMenu
var options: OptionsCard
var settings: GameSettings = GameSettings.new()
## When the cart reveal started playing (Time ms), or -1.
var reveal_started_ms: int = -1
## The WELCOME BACK slip of a resumed run.
var welcome: WelcomeSlip

var _screen: ShiftScreen
var _log: EventLogService
var _paused_at: int = 0
var _ducked: bool = false
var _guide: HandbookPage
## The start board's leave while open_start_options shows the options (else not valid).
var _leave: Callable = Callable()


func _init(screen: ShiftScreen, log_service: EventLogService) -> void:
	_screen = screen
	_log = log_service
	var layer: CanvasLayer = CanvasLayer.new()
	layer.layer = LAYER
	layer.process_mode = Node.PROCESS_MODE_ALWAYS
	pause = PauseMenu.new()
	pause.still = screen.profile.reduced_motion()
	layer.add_child(pause)
	options = OptionsCard.new()
	options.still = pause.still
	layer.add_child(options)
	welcome = WelcomeSlip.new()
	layer.add_child(welcome)
	# First in the tree: unhandled keys reach the screen's other nodes (the picker) first.
	screen.add_child(layer)
	screen.move_child(layer, 0)
	pause.key_event.connect(_on_key)
	pause.resume_pressed.connect(close)
	pause.options_pressed.connect(_open_options)
	pause.guide_pressed.connect(_open_guide)
	pause.quit_pressed.connect(save_and_quit)
	pause.export_pressed.connect(func() -> void: screen._on_export_pressed())
	options.closed.connect(_on_options_closed)
	options.leave_pressed.connect(_on_leave_pressed)
	options.tips_reset.connect(_on_tips_reset)
	(screen._top_bar as TopBar).menu_pressed.connect(toggle)
	for child: Node in screen.get_children():
		if child is HandbookPage:
			_guide = child
			_guide.closed.connect(_on_guide_closed)
			_guide.replay_offer = _replay_offer
			_guide.discovered = _found_coupon
			_guide.replay_requested.connect(_on_replay_requested)
			_guide.offer_collection(func() -> ProfileState: return _screen.profile, screen._balance)
	settings.apply(screen.profile, screen._music, true)


func is_open() -> bool:
	return pause.is_open()


## Whether the handbook shows coupon `card_id` (CouponFinds): found on the profile, or in the run's
## cart under way.
func _found_coupon(card_id: StringName) -> bool:
	if CouponFinds.found(_screen.profile, card_id):
		return true
	var run: RunState = _screen.run
	return run != null and run.deck != null and CouponFinds.owns(run.deck.cards, card_id)


## Whether the pause may open now.
func can_open() -> bool:
	var screen: ShiftScreen = _screen
	if screen.run == null or screen._results.visible or pause.is_open():
		return false
	var since_reveal: int = Time.get_ticks_msec() - reveal_started_ms
	return reveal_started_ms < 0 or since_reveal >= REVEAL_GUARD_MS


func toggle() -> void:
	if pause.is_open():
		close()
	else:
		open()


## Opens the pause (a drag snaps back first) and pauses the tree.
func open() -> void:
	if not can_open():
		return
	if _screen._drag.is_dragging():
		_screen._drag.cancel()
	var now: int = Time.get_ticks_msec()
	_paused_at = now
	_screen.tracker.on_focus_lost(now)
	pause.quit_note = _quit_note()
	pause.open(_sub_line(), _menu_rect())
	_screen.get_tree().paused = true
	var music: MusicService = _screen._music
	_ducked = not music.is_ducked()
	if _ducked:
		music.duck(DUCK_DB, DUCK_FADE)
	var sounds: Sfx = Sfx.find(_screen)
	if sounds != null:
		sounds.play(UiKit.OPEN_SOUND)
	_log.log_event("pause_open", _where())


## Closes the pause and the tree runs on; the paused time leaves the played time.
func close() -> void:
	if not pause.is_open():
		return
	pause.close()
	if options.is_open():
		options.close()
	_screen.get_tree().paused = false
	var now: int = Time.get_ticks_msec()
	var paused_ms: int = now - _paused_at
	_screen._run_started_ms += paused_ms
	_screen.tracker.on_focus_gained(now)
	if _ducked:
		_screen._music.unduck(DUCK_FADE)
		_ducked = false
	var data: Dictionary = _where()
	data["paused_ms"] = paused_ms
	_log.log_event("pause_close", data)


## SAVE & QUIT: no new save point (the run is saved at its last wait); a drag snaps back, the
## sign flips to SAVED, and the title opens with its sign lit.
func save_and_quit() -> void:
	if _screen._drag.is_dragging():
		_screen._drag.cancel()
	_log.log_event("run_quit", _where())
	pause.lane_sign().show_saved()
	TitleScreen.request_lit()
	if _ducked:
		_screen._music.unduck(0.0)
		_ducked = false
	if not _screen.changes_scene:
		pause.close()
		_screen.get_tree().paused = false
		return
	var sounds: Sfx = Sfx.find(_screen)
	if sounds != null:
		sounds.play("ui_confirm")
		sounds.outlive_scene()
	await _screen.get_tree().create_timer(SAVED_SECONDS).timeout
	_screen.get_tree().paused = false
	_screen.get_tree().change_scene_to_file(ShiftScreen.TITLE_SCREEN)


## A saved run resumed: the WELCOME BACK slip under the top bar (not on a run's first start); at
## the machine low over its cabinet, centred on the screen, clear of the marquee (polish batch 2).
func welcome_back() -> void:
	var run: RunState = _screen.run
	var centre: float = (pause.size.x + PauseMenu.REGISTER_COLUMN) / 2.0
	var top: float = WelcomeSlip.TOP
	if RunState.MACHINE_PHASES.has(run.phase):
		var stage: Rect2 = _screen._stage.get_global_rect()
		centre = stage.get_center().x
		top = stage.position.y + WelcomeSlip.MACHINE_TOP * stage.size.y / ShiftStage.SIZE.y
	welcome.show_for("Shift %d/%d" % [run.shift_index + 1, run.shift_count()], centre, top)


## Keys while the screen runs (opening) and while paused (the pause's, the options').
func _on_key(event: InputEvent) -> void:
	var key: InputEventKey = event as InputEventKey
	if key == null or not key.pressed:
		return
	if _take_key(event):
		pause.get_viewport().set_input_as_handled()


## Whether the key was taken: Alt+Enter, a key for an open layer, or an opening key.
func _take_key(event: InputEvent) -> bool:
	var key: InputEventKey = event as InputEventKey
	if settings.toggle_on_key(event, _screen.profile):
		_screen._saves.save_profile(_screen.profile)
		return true
	if options.is_open():
		return options.handle_key(event)
	if _guide != null and _guide.is_open():
		return false
	if pause.is_open():
		return pause.handle_key(event)
	return _opening_key(key)


## Esc or P with nothing open: a drag snaps back first (Esc), else the pause opens.
func _opening_key(key: InputEventKey) -> bool:
	if key.echo or (key.keycode != KEY_ESCAPE and key.keycode != KEY_P):
		return false
	if key.keycode == KEY_ESCAPE and _screen._drag.is_dragging():
		_screen._drag.cancel()  # The topmost thing: the drag snaps back.
		return true
	var opens: bool = can_open()
	open()
	return opens


func _open_options() -> void:
	options.leave_caption = ""
	options.open(_screen.profile, settings, _screen._music)


## Opening time's Esc: the options over the start board with BACK TO TITLE (`leave` goes to the
## title); the tree pauses while they show, so the board takes no key. False when something
## else is open.
func open_start_options(leave: Callable) -> bool:
	if options.is_open() or pause.is_open():
		return false
	_leave = leave
	options.leave_caption = OptionsCard.LEAVE_CAPTION
	options.open(_screen.profile, settings, _screen._music)
	_screen.get_tree().paused = true
	var sounds: Sfx = Sfx.find(_screen)
	if sounds != null:
		sounds.play(UiKit.OPEN_SOUND)
	return true


## BACK TO TITLE: the options close (the board's tree runs again), then the board leaves.
func _on_leave_pressed() -> void:
	var leave: Callable = _leave
	options.close()
	if leave.is_valid():
		leave.call()


func _on_options_closed() -> void:
	for change: Dictionary in options.changes():
		_log.log_event("settings_change", change)
	_screen._saves.save_profile(_screen.profile)
	pause.still = _screen.profile.reduced_motion()
	if _leave.is_valid():
		_leave = Callable()
		options.leave_caption = ""
		if not pause.is_open():
			_screen.get_tree().paused = false


## HOW TO PLAY: the staff handbook over the paused shift (the pause hides under it).
func _open_guide() -> void:
	if _guide == null:
		return
	_guide.process_mode = Node.PROCESS_MODE_ALWAYS
	pause.visible = false
	_guide.open_at()


func _on_guide_closed() -> void:
	_guide.process_mode = Node.PROCESS_MODE_INHERIT
	if _screen.get_tree().paused:
		pause.visible = true


## What the run's handbook offers on its first tab: nothing in a guided run (or before a run),
## the line once the next new run is guided, else PLAY THE GUIDED SHIFT.
func _replay_offer() -> HandbookPage.ReplayOffer:
	var run: RunState = _screen.run
	if run == null or run.guided:
		return HandbookPage.ReplayOffer.HIDDEN
	if TutorialFlags.has_seen(_screen.profile, TutorialFlags.GUIDE_REPLAY):
		return HandbookPage.ReplayOffer.SET
	return HandbookPage.ReplayOffer.OFFERED


## PLAY THE GUIDED SHIFT in a run: the profile asks for the next new run to be guided and is
## saved at once (the run's save is never touched); logged under the run.
func _on_replay_requested() -> void:
	if _replay_offer() != HandbookPage.ReplayOffer.OFFERED:
		return
	if TutorialFlags.request_replay(_screen.profile):
		_screen.save_profile()
	_log.log_event("tutorial_replay", RunEvents.tutorial_replay("run"))


## RESET TIPS in a run: logged under the run (the options' close saves the profile).
func _on_tips_reset(cleared: int) -> void:
	_log.log_event("tips_reset", RunEvents.tips_reset(cleared))


## The phase the pause opened in, for RESUME's sub-line and the telemetry.
func _phase() -> String:
	if _screen._counting:
		return "count_up"
	if RunState.MACHINE_PHASES.has(_screen.run.phase):
		return "machine"
	return "planning"


func _where() -> Dictionary:
	return {"phase": _phase(), "shift": _screen.run.shift_index + 1}


func _sub_line() -> String:
	var words: Dictionary = {
		"count_up": "COUNT-UP", "machine": "PRIZE PICK", "planning": "PLANNING"
	}
	var run: RunState = _screen.run
	return "SHIFT %d/%d · %s" % [run.shift_index + 1, run.shift_count(), words[_phase()]]


func _quit_note() -> String:
	match _phase():
		"count_up":
			return "The checkout is already paid. CONTINUE opens the machine."
		"machine":
			return "The same prizes wait when you come back."
	return "Saved after your last move. CONTINUE brings back this hand and row."


## The ☰ button's rect on the screen's canvas (the shade's hole).
func _menu_rect() -> Rect2:
	var button: Control = (_screen._top_bar as TopBar).menu_button
	return button.get_global_transform_with_canvas() * Rect2(Vector2.ZERO, button.size)
