class_name StartBoard
extends Control
## Opening-time board (full build plan 7.2): page 1 YOUR STORE, the store at dawn with its aisle
## boosters (BoosterPage), and page 2 YOUR BUILD, the staff room with the starter packs as cards,
## the deck pile's NEW PACKS and the BADGE PINS step (BuildPage), both v1.32 (mock-up
## start_boosters_v3.html). Root owns navigation and routes keys; each page draws its own top bar
## and floor row and plays its own motion. Game choices go through StartChoice
## (StartBoardActions), so this class only displays them and routes input.

signal clocked_in(pack: StarterPackDefinition)
## Esc (or ‹ TITLE) on the store page: the screen owns the scene change and its teardown.
signal back_to_title

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
	KEY_N,
]
## The most one frame advances the page slide (s), so a slow frame never jumps it.
const SLIDE_MAX_STEP := 1.0 / 30.0

var page: int = 1
var run: RunState
var profile: ProfileState
var store: BoosterPage
var staff: BuildPage
var busy: bool = false
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
	staff = BuildPage.new()
	_pages.add_child(staff)
	staff.store_pressed.connect(func() -> void: show_page(1, "click"))
	staff.store_opened.connect(_store_opened)
	staff.visible = false
	# A run saved at BUILD with a sealed booster (RESTOCK after page 2) opens on page 1: the
	# fresh booster must be opened before the clock-in.
	if run.start_setup.stage == StartSetup.Stage.BUILD and run.start_setup.all_open():
		page = 2
		staff.visible = true
		store.visible = false
	resized.connect(_resize)
	refresh()
	if page == 2:
		staff.enter()


func _ready() -> void:
	_resize()


## The picked pack's place in the offer (-1: none picked).
func selected() -> int:
	return staff.picked()


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


## NEW PACKS (saved at once; the deck pile on page 2).
func new_packs() -> bool:
	if busy or page != 2:
		return false
	var used: bool = staff.new_packs()
	if used:
		refresh()
	return used


func show_page(next_page: int, key: String = "click") -> void:
	if busy or staff.pins_open or staff.flight != null:
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
	if _queued_key != KEY_NONE:
		var queued: Key = _queued_key
		_queued_key = KEY_NONE
		_act(queued)


## Picks pack `index` on page 2 (saved at once; a click, 1-3, or the reveal's raise_pack).
func pick(index: int) -> void:
	if busy or page != 2:
		return
	if staff.pick_pack(index, "key"):
		refresh()


## OPEN STORE with the picked pack: the flight to the cart, then the clock-in. False with no pick,
## while the packs wait for the BADGE PINS step, or while a booster is sealed (a RESTOCK).
func clock_in() -> bool:
	if page != 2 or busy or staff.picked() < 0 or staff.pins_open or staff.packs_held():
		return false
	if not run.start_setup.all_open():
		say("OPEN THE BOOSTER FIRST")
		return false
	if not staff.open_store():
		return false
	busy = true
	return true


## The flight landed: the NEW tags shown this run are marked seen, and the board clocks in.
func _store_opened(pack: StarterPackDefinition) -> void:
	busy = true
	for id: StringName in store.fresh:
		_choice.mark_seen.call(id)
	clocked_in.emit(pack)


func _back_pressed() -> void:
	back("click")


func back(key: String = "esc") -> void:
	if busy:
		return
	if page == 2 and staff.pins.close():
		return
	if page == 1 and store.handle_key(KEY_ESCAPE):
		return
	if page == 2:
		show_page(1, key)
	else:
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
		if key.keycode == KEY_SPACE and page == 1:
			store.space(false)
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
	elif page == 2:
		if staff.handle_key(keycode):
			refresh()
	else:
		_act_store(keycode, enter)


func _act_store(keycode: Key, enter: bool) -> void:
	if enter:
		store.primary("key")
	elif keycode == KEY_SPACE:
		store.space(true)
	else:
		store.handle_key(keycode)


## The card tile under the pointer that may show its scan popup (CartReveal's, with its hold):
## a control carrying a "card" meta on the shown page; null while a pop-up, the pins or a slide
## covers the board.
func hovered_card() -> Control:
	if busy or not is_visible_in_tree():
		return null
	if page == 1:
		return store.hovered_card()
	return null


## The scaled stage's global rect (the popup stays on it).
func stage_rect() -> Rect2:
	return _stage.get_global_rect()
