class_name StartBoard
extends Control
## Opening-time board (full build plan 7.2): page 1 YOUR STORE, the store at dawn with its aisle
## boosters (BoosterPage), and page 2 YOUR BUILD, the staff room with the order sheet, the BADGE
## PINS step and OPEN STORE (BuildPage), both v1.32 (mock-up
## start_boosters_v3.html). Root owns navigation and routes keys; each page draws its own top bar
## and floor row and plays its own motion. Game choices go through StartChoice
## (StartBoardActions), so this class only displays them and routes input.

signal clocked_in
## ‹ TITLE (or Esc with nothing listening to options_requested), and the options' BACK TO TITLE
## (leave): the screen owns the scene change and its teardown.
signal back_to_title
## Esc on the store page with nothing of its own to close (polish batch 2): the screen opens the
## options with BACK TO TITLE (PauseFlow.open_start_options).
signal options_requested
## The tutorial's hooks (TutorialEvents' start-screen events, with their args), sent always,
## guided or not: listening changes nothing. The pages send theirs through StartBoardActions.
signal guide_event(event: StringName, args: Dictionary)

## The keys the board answers; any other key goes on (F1's debug panel, global shortcuts).
const KEYS: Array[Key] = [
	KEY_ESCAPE,
	KEY_ENTER,
	KEY_KP_ENTER,
	KEY_SPACE,
	KEY_1,
	KEY_2,
	KEY_3,
	KEY_4,
	KEY_5,
	KEY_6,
	KEY_7,
	KEY_8,
	KEY_9,
	KEY_A,
	KEY_P,
	KEY_R,
	KEY_S,
]
## The most one frame advances the page slide (s), so a slow frame never jumps it.
const SLIDE_MAX_STEP := 1.0 / 30.0

var page: int = 1
var run: RunState
var profile: ProfileState
var store: BoosterPage
var staff: BuildPage
var busy: bool = false
## The board's hover tips (StartTips' targets on both pages; v1.33 hover tips B).
var tips: GlyphTips
## The page slide's length (s): CartRevealTuning.page_slide_s, set by the reveal before it adds
## the board.
var slide_s: float = 0.3
## A board key pressed during the page slide, acted on when it ends (KEY_NONE: none).
var _queued_key: Key = KEY_NONE
## The running page slide: the leaving and the arriving page (null: no slide), its direction
## (1: to page 2), its clock (s), the frame that built it and the wall clock (µs) of its last
## frame (-1: not started).
var _slide_old: Control
var _slide_fresh: Control
var _slide_direction: float = 1.0
var _slide_time: float = 0.0
var _slide_frame: int = 0
var _slide_usec: int = -1
var _choice: StartBoardActions
var _stage: Control
var _pages: Control


func _init(shown_run: RunState, shown_profile: ProfileState, choice: StartBoardActions) -> void:
	run = shown_run
	profile = shown_profile
	_choice = choice
	if _choice != null:
		_choice.guide_event = _send_guide
	name = "StartBoard"
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	_stage = Control.new()
	_stage.size = ShiftStage.SIZE
	_stage.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_stage)
	_pages = Control.new()
	_pages.size = ShiftStage.SIZE
	_pages.clip_contents = true
	_pages.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_stage.add_child(_pages)
	StartBoardKit.panel(_pages, Rect2(Vector2.ZERO, ShiftStage.SIZE), Palette.BACKGROUND)
	store = BoosterPage.new()
	_pages.add_child(store)
	store.title_pressed.connect(_back_pressed)
	store.next_pressed.connect(_next_pressed)
	store.swap_closed.connect(_swap_closed)
	staff = BuildPage.new()
	_pages.add_child(staff)
	staff.store_pressed.connect(func() -> void: show_page(1, "click"))
	staff.store_opened.connect(_store_opened)
	staff.swap_pressed.connect(open_swap)
	staff.visible = false
	# A run saved at BUILD with a sealed booster (RESTOCK after page 2) opens on page 1: the
	# fresh booster must be opened before the clock-in.
	if run.start_setup.stage == StartSetup.Stage.BUILD and run.start_setup.all_open():
		page = 2
		staff.visible = true
		store.visible = false
	# The pages' hover tips, over both pages (added last, so they draw on top).
	tips = GlyphTips.new()
	tips.blocked = tips_blocked
	tips.reduced_motion = func() -> bool: return profile.reduced_motion()
	_stage.add_child(tips)
	resized.connect(_resize)
	refresh()
	if page == 2:
		staff.enter()


func _ready() -> void:
	_resize()
	# The page it opens on (deferred: whoever opened the board connects first).
	_send_guide.call_deferred(TutorialEvents.PAGE_SHOWN, {TutorialEvents.ARG_PAGE: page - 1})


func _send_guide(event: StringName, args: Dictionary) -> void:
	guide_event.emit(event, args)


func _resize() -> void:
	var factor: float = minf(size.x / ShiftStage.SIZE.x, size.y / ShiftStage.SIZE.y)
	_stage.scale = Vector2.ONE * factor
	_stage.position = ((size - ShiftStage.SIZE * factor) / 2.0).floor()


func refresh() -> void:
	store.show_store(run, profile, _choice)
	staff.show_build(run, profile, _choice)


## A short message on the shown page's hint LED (a refused or unsaved action).
func say(text: String) -> void:
	if text == "":
		return
	if page == 1:
		store.flash(text.to_upper())
	else:
		staff.flash(text.to_upper())


func _next_pressed() -> void:
	if store.page_done() and not store.swap.active:
		show_page(2, "click")


## Whether the regulars' swap window shows (over page 2: BoosterPage.overlay).
func swap_showing() -> bool:
	return store.overlay or store.swap.visible()


## Page 2's SWAP key (S): the swap window opens over the page. It is page 1's (BoosterPage draws
## and plays it), shown in front of page 2 with nothing else of page 1. False when it can't open.
func open_swap() -> bool:
	if busy or page != 2 or staff.pins_open or staff.flight != null or swap_showing():
		return false
	if not BuildRegulars.swap_shown(staff):
		return false
	if not store.open_swap_over():
		say("COULD NOT OPEN THE SWAP")
		return false
	_pages.move_child(store, -1)
	store.visible = true
	return true


## The swap window shut: page 2 shows the regulars' changes (its CART count, its order sheet).
func _swap_closed() -> void:
	_pages.move_child(store, staff.get_index())
	store.visible = page == 1
	refresh()


func show_page(next_page: int, key: String = "click") -> void:
	if busy or staff.pins_open or staff.flight != null or swap_showing():
		return
	if next_page == page or next_page not in [1, 2]:
		return
	store.restock_armed = false
	if next_page == 2 and run.start_setup.stage == StartSetup.Stage.DEALT:
		_choice.mark_build.call()
	var before: int = page
	_choice.page_changed.call(next_page, before, key)
	page = next_page
	refresh()
	if page == 2:
		staff.enter()
	if profile.reduced_motion():
		store.visible = page == 1
		staff.visible = page == 2
		_send_guide(TutorialEvents.PAGE_SHOWN, {TutorialEvents.ARG_PAGE: page - 1})
		return
	busy = true
	store.visible = true
	staff.visible = true
	_slide_direction = 1.0 if page == 2 else -1.0
	_slide_old = (store as Control) if before == 1 else (staff as Control)
	_slide_fresh = (store as Control) if page == 1 else (staff as Control)
	# Both pages were just built (refresh, above) in this frame, and the engine's frame deltas
	# catch up on that build for a few frames: the slide's clock starts from the wall clock on the
	# next frame and counts real time from there (each frame capped), so the build is never a jump
	# in the motion and no frame of the slide builds anything.
	_slide_frame = Engine.get_process_frames()
	_slide_time = 0.0
	_slide_usec = -1
	_place_slide(0.0)


## The slide's offset (stage px, 0 to the stage's width) at `elapsed` seconds: eased out, every
## frame (never stepped to the art grid, which made it judder at ~10 steps a second), snapped to
## whole stage pixels.
func _slide_offset(elapsed: float) -> float:
	var fraction: float = clampf(elapsed / maxf(slide_s, 0.001), 0.0, 1.0)
	var eased: float = sin(fraction * PI / 2.0)
	return roundf(eased * ShiftStage.SIZE.x)


func _process(_delta: float) -> void:
	if _slide_old == null:
		return
	if Engine.get_process_frames() > _slide_frame:
		# Real time since the last frame, not the engine's delta (which still holds the build);
		# a slow frame moves the slide one capped step, not a jump.
		var now: int = Time.get_ticks_usec()
		if _slide_usec >= 0:
			_slide_time += minf((now - _slide_usec) / 1000000.0, SLIDE_MAX_STEP)
		_slide_usec = now
	_place_slide(_slide_time)
	if _slide_time >= slide_s:
		_end_slide()


func _place_slide(elapsed: float) -> void:
	var offset: float = _slide_offset(elapsed)
	_slide_old.position.x = -_slide_direction * offset
	_slide_fresh.position.x = _slide_direction * (ShiftStage.SIZE.x - offset)


func _end_slide() -> void:
	_slide_old = null
	_slide_fresh = null
	store.position = Vector2.ZERO
	staff.position = Vector2.ZERO
	store.visible = page == 1
	staff.visible = page == 2
	busy = false
	_send_guide(TutorialEvents.PAGE_SHOWN, {TutorialEvents.ARG_PAGE: page - 1})
	if _queued_key != KEY_NONE:
		var queued: Key = _queued_key
		_queued_key = KEY_NONE
		_act(queued)


## OPEN STORE: the flight to the cart, then the clock-in. False while the BADGE PINS step waits,
## or while a booster is sealed (a RESTOCK).
func clock_in() -> bool:
	if page != 2 or busy or staff.pins_open or staff.pins_pending():
		return false
	if not StartBoardActions.hit_allowed(_choice, TutorialAnchors.PRIMARY):
		return false
	if not run.start_setup.all_open():
		say("OPEN THE BOOSTER FIRST")
		return false
	if not staff.open_store():
		return false
	busy = true
	return true


## The flight landed: the NEW tags shown this run are marked seen, and the board clocks in.
func _store_opened() -> void:
	busy = true
	for id: StringName in store.fresh:
		_choice.mark_seen.call(id)
	clocked_in.emit()


func _back_pressed() -> void:
	back("click")


func back(key: String = "esc") -> void:
	if busy:
		return
	if swap_showing():
		store.handle_key(KEY_ESCAPE)
		return
	if page == 2 and staff.pins.close():
		return
	if page == 1 and store.handle_key(KEY_ESCAPE):
		return
	if page == 2:
		show_page(1, key)
	elif key == "esc" and options_requested.has_connections():
		options_requested.emit()
	else:
		leave(key)


## Leaves the board for the title (`key` as start_page logs it).
func leave(key: String = "esc") -> void:
	if busy:
		return
	_choice.page_changed.call(0, 1, key)
	back_to_title.emit()


## Opens the BADGE PINS step on page 2 (the corkboard, P).
func open_pins() -> void:
	if busy or page != 2:
		return
	staff.pins.open(staff.now)


func _input(event: InputEvent) -> void:
	var key: InputEventKey = event as InputEventKey
	if not is_visible_in_tree() or key == null or key.echo:
		return
	if not key.pressed:
		return
	if not KEYS.has(key.keycode):
		return
	get_viewport().set_input_as_handled()
	if busy:
		# Held for the end of the page slide (the last key wins), so Esc Esc still reaches the
		# title; nothing is held once the clock-in punch has started.
		_queued_key = key.keycode if page_sliding() else KEY_NONE
		return
	_act(key.keycode)


## Whether the page slide is running (busy for the slide, not for the clock-in punch).
func page_sliding() -> bool:
	return _slide_old != null


func _act(keycode: Key) -> void:
	var enter: bool = keycode in [KEY_ENTER, KEY_KP_ENTER]
	if keycode == KEY_ESCAPE:
		back()
	elif busy:
		return
	elif swap_showing():
		_act_store(keycode, enter)
	elif page == 2:
		if staff.handle_key(keycode):
			refresh()
	else:
		_act_store(keycode, enter)


func _act_store(keycode: Key, enter: bool) -> void:
	if enter or keycode == KEY_SPACE:
		store.primary("key")
	else:
		store.handle_key(keycode)


## Whether no hover tip may show: the page slide, the clock-in, or the shown page's own reasons (an
## opening, a held card, the BADGE PINS step; BoosterPage and BuildPage tips_blocked).
func tips_blocked() -> bool:
	if busy or _slide_old != null or not is_visible_in_tree():
		return true
	if swap_showing():
		return store.tips_blocked()
	return store.tips_blocked() if page == 1 else BuildPageDraw.tips_blocked(staff)


## The scaled stage's global rect (the popup stays on it).
func stage_rect() -> Rect2:
	return _stage.get_global_rect()


## The tutorial anchor `id`'s rect (TutorialAnchors' start ids) in global coordinates, Rect2()
## when the shown page doesn't show it (StartGuide.anchor_of).
func anchor_rect(id: StringName) -> Rect2:
	return StartGuide.anchor_of(self, id)


## The tutorial overlay's mount point: over the whole board, above both pages and their hover
## tips (unscaled: the overlay places itself from anchor_rect's global rects).
func mount_overlay(overlay: Control) -> void:
	if overlay.get_parent() != null:
		overlay.get_parent().remove_child(overlay)
	add_child(overlay)
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
