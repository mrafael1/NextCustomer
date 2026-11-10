class_name TitleMenu
extends Control
## The title's menu (#56, mock-up title_premium_directions.html, direction C+): plates on the
## storefront's brick, left of the doors, under the sconce's light (MenuPlate). With a run saved:
## CONTINUE (the tomato primary plate, the saved shift under it: SHIFT 3/16), NEW RUN and
## REWARDS; without one: START RUN (the run's length under it: 16 SHIFTS · 4 WEEKS) and
## REWARDS. REWARDS carries a coin and the profile's coins.
##
## One marker lights an entry (its plate moves right onto its lit frame, the price-gun tick
## shows): the mouse on a plate, the keys (Up and Down; from no marker Down starts on the first
## entry and Up on the last), or the storefront (the title marks the primary entry while the
## doors are under the mouse, REWARDS while the bay is). The marked entry is the hot one; the
## storefront follows it (hot_changed: the doors stand ajar, the bay lights). Enter or Space
## press the marked entry, or the primary entry when none is marked. The menu plays no sound:
## the title wires the entries' sounds with their actions.
##
## Hidden at first, the plates step in once the sign is lit (step_in): each STEP_DELAY after the
## one above, sliding in SLIDE art px from the left in SLIDE_STEP px steps over SLIDE_TIME. `still`
## (reduced motion) shows them at once.

## The primary entry was pressed (CONTINUE resumes the save, START RUN starts a run).
signal start_pressed
## NEW RUN was pressed (with a run saved: the title asks first).
signal new_run_pressed
## REWARDS was pressed.
signal rewards_pressed
## GUIDE was pressed (v1.06): the staff handbook opens.
signal guide_pressed
## OPTIONS was pressed: the options popup opens.
signal options_pressed
## The marked entry changed (NONE: none).
signal hot_changed(entry: Entry)

## NONE: no entry; PRIMARY: CONTINUE or START RUN; NEW_RUN (only with a run saved); REWARDS;
## GUIDE (v1.06, the staff handbook, under REWARDS); OPTIONS (the options popup), GUIDE's half
## plate's neighbour on the last shelf.
enum Entry { NONE, PRIMARY, NEW_RUN, REWARDS, GUIDE, OPTIONS }

## Where the menu stands on the storefront's stage, in canvas px (36,160 art at 2x): the
## primary plate's top left.
const STAGE_AT := Vector2(72, 320)
## Each plate's top, in canvas px from the menu's: the primary plate, then a shelf label
## PLATE_TOPS[1] down and the next PLATE_TOPS[2] (the mock-up's 8 art px gaps, the second one
## 2 more for the ledge).
const PLATE_TOPS: Array[float] = [0.0, 96.0, 152.0, 208.0]
## The step in: each plate STEP_DELAY after the one above, sliding SLIDE canvas px in SLIDE_STEP
## steps over SLIDE_TIME (the mock-up's 70 ms, 24 art px in 4 art px steps over 160 ms).
const STEP_DELAY := 0.07
const SLIDE := 48.0
const SLIDE_STEP := 8.0
const SLIDE_TIME := 0.16
const CONTINUE_TEXT := "CONTINUE"
const START_TEXT := "START RUN"
const NEW_RUN_TEXT := "NEW RUN"
const REWARDS_TEXT := "REWARDS"
const GUIDE_TEXT := "GUIDE"
const OPTIONS_TEXT := "OPTIONS"
## GUIDE and OPTIONS share the last shelf as two half plates, HALF_GAP apart, so the column keeps
## its height (mock-up options_pause.html: 116x42 each, 8 px apart).
const HALF_SIZE := Vector2(116, 42)
const HALF_GAP := 8.0

## Shows the plates at once when they step in (the profile's reduced motion).
var still: bool = false
## A run is starting: the marker stays where it is (mark does nothing), so neither the mouse
## leaving or crossing a plate nor a key changes the plates or the storefront.
var frozen: bool = false

var _entries: Array[Entry] = []
var _plates: Dictionary[Entry, MenuPlate] = {}
var _marked: Entry = Entry.NONE
var _shown: bool = false
var _stepping: Tween


## The menu with a run saved (`saved`: CONTINUE, NEW RUN, REWARDS) or not (START RUN, REWARDS);
## `sub_line` goes under the primary entry (continue_line or length_line), `coins` on REWARDS.
func _init(saved: bool, sub_line: String, coins: int) -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	position = STAGE_AT
	_entries = [Entry.PRIMARY, Entry.REWARDS, Entry.GUIDE, Entry.OPTIONS]
	if saved:
		_entries.insert(1, Entry.NEW_RUN)
	for i: int in _entries.size():
		var entry: Entry = _entries[i]
		var entry_plate: MenuPlate
		var at: Vector2 = Vector2(0.0, PLATE_TOPS[mini(i, _entries.find(Entry.GUIDE))])
		if entry == Entry.PRIMARY:
			entry_plate = MenuPlate.new(
				CONTINUE_TEXT if saved else START_TEXT, MenuPlate.Kind.PRIMARY
			)
			entry_plate.sub_line = sub_line
		elif entry == Entry.GUIDE or entry == Entry.OPTIONS:
			entry_plate = MenuPlate.new(_plate_text(entry), MenuPlate.Kind.PLATE, HALF_SIZE)
			entry_plate.centre_caption()
			if entry == Entry.OPTIONS:
				at.x = HALF_SIZE.x + HALF_GAP
				# Its tick points back at it from the right, clear of GUIDE (the mock-up's).
				entry_plate.tick().flip_h = true
				entry_plate.tick().position.x = (
					HALF_SIZE.x + MenuPlate.HOT_SHIFT + MenuPlate.TICK_LEFT - MenuPlate.TICK_SIZE.x
				)
		else:
			entry_plate = MenuPlate.new(_plate_text(entry))
		entry_plate.position = at
		entry_plate.visible = false
		entry_plate.mouse_entered.connect(mark.bind(entry))
		entry_plate.mouse_exited.connect(unmark.bind(entry))
		entry_plate.pressed.connect(activate.bind(entry))
		add_child(entry_plate)
		_plates[entry] = entry_plate
	set_coins(coins)
	var last: MenuPlate = _plates[_last_entry()]
	size = Vector2(MenuPlate.PRIMARY_SIZE.x, last.position.y + last.size.y)


## The primary entry's sub-line for a saved run: its shift out of the run's shifts.
static func continue_line(saved: RunSave) -> String:
	return "SHIFT %d/%d" % [saved.run.shift_index + 1, saved.run.shift_count()]


## The primary entry's sub-line without a save: the run's length from balance data (its shifts
## and, when the run has weeks, how many).
static func length_line(balance: BalanceDefinition) -> String:
	var shifts: int = balance.quotas.size()
	var line: String = "%d SHIFT%s" % [shifts, "" if shifts == 1 else "S"]
	if balance.week_length <= 0:
		return line
	var weeks: int = ceili(float(shifts) / balance.week_length)
	return "%s · %d WEEK%s" % [line, weeks, "" if weeks == 1 else "S"]


## Shows `count` coins on REWARDS.
func set_coins(count: int) -> void:
	_plates[Entry.REWARDS].show_coins(count)


## The entries, top to bottom.
func entries() -> Array[Entry]:
	return _entries.duplicate()


## The entry's plate, or null when the menu doesn't offer it.
func plate(entry: Entry) -> MenuPlate:
	return _plates[entry] if _plates.has(entry) else null


func marked_entry() -> Entry:
	return _marked


## The plates have stepped in (or are stepping in).
func is_shown() -> bool:
	return _shown


## Steps the plates in (at once when `still`). Returns the step in (null when still or shown).
func step_in() -> Tween:
	if _shown:
		return null
	_shown = true
	if still:
		for entry: Entry in _entries:
			_plates[entry].visible = true
		return null
	_stepping = create_tween().set_parallel()
	for i: int in _entries.size():
		var shown_plate: MenuPlate = _plates[_entries[i]]
		var delay_index: int = mini(i, _entries.find(Entry.OPTIONS))
		_slide(0.0, shown_plate)
		_stepping.tween_method(_slide.bind(shown_plate), 0.0, 1.0, SLIDE_TIME).set_delay(
			delay_index * STEP_DELAY
		)
	return _stepping


## Ends the step in at once, every plate in place (a click or key during the title's intro);
## shows the plates if they hadn't stepped in yet.
func finish_step_in() -> void:
	_shown = true
	if _stepping != null:
		_stepping.kill()
		_stepping = null
	for entry: Entry in _entries:
		_plates[entry].visible = true
		_plates[entry].position.x = _home_x(entry)


## The plates are still sliding in.
func is_stepping() -> bool:
	return _stepping != null and _stepping.is_running()


## Puts the marker on `entry` (NONE: off), lighting its plate; hot_changed when it moves.
func mark(entry: Entry) -> void:
	if frozen or (entry != Entry.NONE and not _plates.has(entry)):
		return
	if entry == _marked:
		return
	_marked = entry
	for each: Entry in _entries:
		_plates[each].marked = each == entry
	hot_changed.emit(entry)


## Takes the marker off `entry` if it is there (the mouse left its plate or its scene object).
func unmark(entry: Entry) -> void:
	if _marked == entry:
		mark(Entry.NONE)


## Moves the marker `step` entries on, wrapping; from no marker Down starts on the first entry
## and Up on the last.
func move_marker(step: int) -> void:
	var index: int = _entries.find(_marked)
	if index < 0:
		mark(_entries[0] if step > 0 else _last_entry())
	else:
		mark(_entries[posmod(index + step, _entries.size())])


## Presses `entry`: its signal.
func activate(entry: Entry) -> void:
	match entry:
		Entry.PRIMARY:
			start_pressed.emit()
		Entry.NEW_RUN:
			new_run_pressed.emit()
		Entry.REWARDS:
			rewards_pressed.emit()
		Entry.GUIDE:
			guide_pressed.emit()
		Entry.OPTIONS:
			options_pressed.emit()


## A key for the menu: Up and Down move the marker, Enter or Space press the marked entry (the
## primary one when none is marked). True when the key was the menu's. The title calls it once
## the menu is shown and nothing is open over it.
func handle_key(event: InputEvent) -> bool:
	var key: InputEventKey = event as InputEventKey
	if key == null or not key.pressed:
		return false
	match key.keycode:
		KEY_DOWN:
			move_marker(1)
		KEY_UP:
			move_marker(-1)
		KEY_LEFT, KEY_RIGHT:
			# Across the last shelf's half plates.
			if _marked == Entry.GUIDE or _marked == Entry.OPTIONS:
				mark(Entry.OPTIONS if _marked == Entry.GUIDE else Entry.GUIDE)
		KEY_ENTER, KEY_KP_ENTER, KEY_SPACE:
			if not key.echo:
				activate(_marked if _marked != Entry.NONE else Entry.PRIMARY)
		_:
			return false
	return true


static func _plate_text(entry: Entry) -> String:
	match entry:
		Entry.NEW_RUN:
			return NEW_RUN_TEXT
		Entry.GUIDE:
			return GUIDE_TEXT
		Entry.OPTIONS:
			return OPTIONS_TEXT
	return REWARDS_TEXT


## Where `entry`'s plate rests: OPTIONS beside GUIDE, the rest at the column's left.
func _home_x(entry: Entry) -> float:
	return HALF_SIZE.x + HALF_GAP if entry == Entry.OPTIONS else 0.0


func _last_entry() -> Entry:
	return _entries[_entries.size() - 1]


## `slid_plate` `share` (0 to 1) of the way through its slide, in SLIDE_STEP px steps; hidden
## until its delay has passed (the tween calls each plate's method only after its delay).
func _slide(share: float, slid_plate: MenuPlate) -> void:
	slid_plate.visible = share > 0.0
	var left: float = SLIDE * (1.0 - share)
	var home: float = _home_x(_plates.find_key(slid_plate))
	slid_plate.position.x = home - SLIDE_STEP * roundf(left / SLIDE_STEP)
