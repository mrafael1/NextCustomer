class_name MedalCase
extends Control
## The register's medal case (v1.17, the user's pick of 2026-11-08: mock-up
## docs/art/mockups/main_scene_v2.html, drawRegA's MED 'case'), on the cash drawer's front in
## place of the top bar's medal sockets: this week's two medals (WeekMedals) hang from the coin
## rail on striped ribbons, SILVER then GOLD (MedalArt), each named with the total that wins it
## ("at 258€": WeekMedals.threshold_of, show_thresholds). A medal still to win is plain, a
## twinkle hopping round it; while the plan would win it (PENDING) a paper sweep crosses its face
## and its twinkle hops faster; won (USED) it leaves its engraved socket under the ribbon and
## "WON ✓" for the rest of the week (launch: the count's flight takes it onto the receipt's target,
## MedalFlight). A medal back from USED (a new week) pops back in. An OFF medal is not shown.
## Reduced motion: no sweep motion (a still one), no twinkle, no pop. It rides the drawer's front
## (its kick), drawn at 2 stage px per art px. Hovering a medal or its words shows its tip (a
## TipTarget over each, tip_target(): the STATUS card with its rule and its state as the live
## line); it takes no clicks anywhere else.

## Stage px per art px.
const CELL := 2.0
## The medals' top lefts (the front's coordinates), [SILVER, GOLD], MedalArt.SIZE cells across.
const MEDAL_AT: Array[Vector2] = [Vector2(36, 30), Vector2(164, 30)]
## The ribbons' ink frames, from the coin rail down behind the medals' tops.
const RIBBON_RECTS: Array[Rect2] = [Rect2(44, 14, 18, 18), Rect2(172, 14, 18, 18)]
## The words' left, the name's top (CAPS at WORD_CELL), the threshold's and WON's tops.
const WORDS_X: Array[float] = [78.0, 206.0]
const NAME_TOP := 32.0
const LINE_TOP := 48.0
const WORD_CELL := 2.0
const NAMES: Array[String] = ["SILVER", "GOLD"]
const THRESHOLD_TEXT := "at %d€"
const WON_TEXT := "WON"
const LINE_SIZE := 11
const LINE_WEIGHT := 800
## The check after WON (the mock-up's 7x5 lamp check) and its gap.
const CHECK_PIXELS: Array[String] = ["......#", ".....#.", "#...#..", ".#.#...", "..#...."]
const CHECK_GAP := 6.0
## The twinkle: its four spots on the medal (shares of TWINKLE_REACH art px from the centre; v1.36,
## polish audit: from 10.5, so its arms stay inside the medal's sprite and never land on the
## words: the "+" read "+GOLD"), its hop every TWINKLE_STEP s (shown TWINKLE_SHOWN of it), every
## PENDING_STEP s while PENDING; TWINKLE_ARM art px its longest arm.
const TWINKLE_SPOTS: Array[Vector2] = [
	Vector2(-1, -1), Vector2(1, -0.6), Vector2(0.8, 1), Vector2(-1, 0.7)
]
const TWINKLE_REACH := 5.5
const TWINKLE_ARM := 2
const TWINKLE_STEP := 0.7
const PENDING_STEP := 0.26
const TWINKLE_SHOWN := 0.8
## A medal back in its socket pops from POP_FROM of its size past POP_OVER and back.
const POP_SECONDS := 0.35
const POP_FROM := 0.2
const POP_OVER := 1.25
const POP_PEAK := 0.7

var reduced_motion: bool = false
var _states: Array[int] = [WeekMedals.State.OFF, WeekMedals.State.OFF]
var _tips: PackedStringArray = PackedStringArray(["", ""])
var _time: float = 0.0
var _pops: Array[float] = [-1.0, -1.0]
var _names: Array[PixelWords] = []
var _lines: Array[Label] = []
var _won: Array[PixelWords] = []
var _targets: Array[TipTarget] = []
var _tags: PackedStringArray = PackedStringArray([OvertimeWords.ONCE_TAG, OvertimeWords.ONCE_TAG])


func _init() -> void:
	name = "MedalCase"
	mouse_filter = Control.MOUSE_FILTER_PASS
	for index: int in range(2):
		var ink: Color = Palette.MUSTARD_LIGHT if index == 1 else Palette.STEEL_HIGHLIGHT
		var title: PixelWords = PixelWords.new(NAMES[index], PixelWords.Sheet.CAPS, WORD_CELL, ink)
		title.position = Vector2(WORDS_X[index], NAME_TOP)
		add_child(title)
		_names.append(title)
		var line: Label = UiKit.body_label("", LINE_SIZE, Palette.STEEL_LIGHT)
		line.add_theme_font_override("font", ArtStyle.bold_font(LINE_WEIGHT))
		line.position = Vector2(WORDS_X[index], LINE_TOP - 4.0)
		line.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(line)
		_lines.append(line)
		var won: PixelWords = PixelWords.new(
			WON_TEXT, PixelWords.Sheet.CAPS, WORD_CELL, Palette.GREEN_LIGHT
		)
		won.position = Vector2(WORDS_X[index], LINE_TOP)
		add_child(won)
		_won.append(won)
		var target: TipTarget = TipTarget.new()
		target.name = "%sTip" % NAMES[index].capitalize()
		add_child(target)
		_targets.append(target)
	set_process(false)
	_refresh_parts()


## Shows `shown` ([SILVER, GOLD], WeekMedals.State) with their tooltips `tips`. A medal back from
## USED pops back in (not under reduced motion).
func show_states(shown: Array[int], tips: PackedStringArray) -> void:
	for index: int in range(2):
		var back: bool = _states[index] == WeekMedals.State.USED and _is_medal(shown[index])
		if back and not reduced_motion:
			_pops[index] = 0.0
	_states = shown.duplicate()
	_tips = tips
	_refresh_tips()
	_refresh_parts()


## The medals' tip tags ([SILVER, GOLD]: OvertimeWords.cap_tag).
func show_tags(silver: String, gold: String) -> void:
	_tags = PackedStringArray([silver, gold])
	_refresh_tips()


## Medal `gold`'s tip target (over its medal and its words).
func tip_target(gold: bool) -> TipTarget:
	return _targets[1 if gold else 0]


## The totals that win the medals ("at 258€"; WeekMedals.threshold_of), [SILVER, GOLD].
func show_thresholds(silver: int, gold: int) -> void:
	_lines[0].text = THRESHOLD_TEXT % silver
	_lines[1].text = THRESHOLD_TEXT % gold
	for line: Label in _lines:
		line.reset_size()
	_refresh_parts()


## The states shown, [SILVER, GOLD].
func states() -> Array[int]:
	return _states.duplicate()


func state_of(gold: bool) -> int:
	return _states[1 if gold else 0]


## Medal `gold` leaves the case (MedalFlight carries it): its socket and WON show from now on.
func launch(gold: bool) -> void:
	_states[1 if gold else 0] = WeekMedals.State.USED
	_pops[1 if gold else 0] = -1.0
	_refresh_parts()


## Medal `gold`'s rect in this control (empty while OFF).
func medal_rect(gold: bool) -> Rect2:
	var index: int = 1 if gold else 0
	if _states[index] == WeekMedals.State.OFF:
		return Rect2()
	return Rect2(MEDAL_AT[index], Vector2.ONE * MedalArt.SIZE * CELL)


## Medal `gold`'s rect on the canvas (with its canvas layer's transform: where a flight from it
## starts), empty while OFF or not shown.
func medal_canvas_rect(gold: bool) -> Rect2:
	var rect: Rect2 = medal_rect(gold)
	if not rect.has_area() or not is_visible_in_tree():
		return Rect2()
	return get_global_transform_with_canvas() * rect


## Whether medal `gold`'s sweep runs now (PENDING, with motion).
func shimmering(gold: bool) -> bool:
	return _states[1 if gold else 0] == WeekMedals.State.PENDING and not reduced_motion


## Whether medal `gold` is popping back in.
func popping(gold: bool) -> bool:
	return _pops[1 if gold else 0] >= 0.0


## Moves the sweep, the twinkles and the pops on by `seconds` (tests; _process by the frame's).
func advance(seconds: float) -> void:
	_time += seconds
	for index: int in range(2):
		if _pops[index] >= 0.0:
			_pops[index] += seconds
			if _pops[index] >= POP_SECONDS:
				_pops[index] = -1.0
				_refresh_parts()
	queue_redraw()


## Medal `gold`'s parts in this control, for layout tests: "ribbon", "medal", "name", "line"
## (the threshold, or WON and its check once won); empty rects while OFF.
func parts(gold: bool) -> Dictionary:
	var index: int = 1 if gold else 0
	if _states[index] == WeekMedals.State.OFF:
		return {"ribbon": Rect2(), "medal": Rect2(), "name": Rect2(), "line": Rect2()}
	var line: Rect2 = _lines[index].get_rect()
	if _states[index] == WeekMedals.State.USED:
		line = _won[index].get_rect().merge(_check_rect(index))
	return {
		"ribbon": RIBBON_RECTS[index],
		"medal": medal_rect(gold),
		"name": _names[index].get_rect(),
		"line": line,
	}


## Medal `gold`'s line: "at 258€", or "WON ✓" once won.
func line_text(gold: bool) -> String:
	var index: int = 1 if gold else 0
	return WON_TEXT + " ✓" if _states[index] == WeekMedals.State.USED else _lines[index].text


func _process(delta: float) -> void:
	advance(delta)


func _has_point(point: Vector2) -> bool:
	return _medal_at(point) >= 0


## The tip of the medal at `at_position` ("" for none): its name, rule and state on 3 lines.
func tip_at(at_position: Vector2) -> String:
	var index: int = _medal_at(at_position)
	return _tips[index] if index >= 0 else ""


func _refresh_tips() -> void:
	for index: int in range(2):
		var lines: PackedStringArray = _tips[index].split("\n")
		if lines.size() < 2:
			_targets[index].spec = null
			_targets[index].tip_text = ""
			continue
		var made: TipSpec = TipSpec.make(TipSpec.Kind.STATUS, lines[0], TipMarkup.auto(lines[1]))
		made.tag = _tags[index]
		made.source = _tips[index]
		if lines.size() > 2:
			made.live = lines[2]
			var used: bool = _states[index] == WeekMedals.State.USED
			made.live_kind = TipSpec.Live.OFF if used else TipSpec.Live.OK
		_targets[index].spec = made
		_targets[index].tip_text = _tips[index]


## The medal (0 SILVER, 1 GOLD) whose medal or words are at `point`, -1 for none.
func _medal_at(point: Vector2) -> int:
	for index: int in range(2):
		var shown: Dictionary = parts(index == 1)
		var area: Rect2 = shown["medal"]
		if not area.has_area():
			continue
		area = area.merge(shown["name"]).merge(shown["line"])
		if area.has_point(point):
			return index
	return -1


func _draw() -> void:
	for index: int in range(2):
		var state: int = _states[index]
		if state == WeekMedals.State.OFF:
			continue
		var gold: bool = index == 1
		var at: Vector2 = MEDAL_AT[index]
		MedalArt.draw_ribbon(self, RIBBON_RECTS[index], gold, CELL)
		if state == WeekMedals.State.USED:
			MedalArt.draw_medal(self, at, MedalArt.SIZE, CELL, gold, true)
			_draw_check(index)
			continue
		if _pops[index] >= 0.0:
			MedalArt.draw_medal(self, at, MedalArt.SIZE, CELL, gold, true)
			_draw_pop(index)
			continue
		var sweep: int = -1
		if state == WeekMedals.State.PENDING:
			sweep = MedalArt.SIZE if reduced_motion else MedalArt.sweep_at(_time)
		MedalArt.draw_medal(self, at, MedalArt.SIZE, CELL, gold, false, sweep)
		if not reduced_motion:
			_draw_twinkle(index, state == WeekMedals.State.PENDING)


## Medal `index`'s twinkle: one at a time, hopping between four spots (faster while pending).
func _draw_twinkle(index: int, pending: bool) -> void:
	var step: float = PENDING_STEP if pending else TWINKLE_STEP
	var hop: int = floori(_time / step) + index + 2
	var phase: float = fposmod(_time, step) / step
	if not pending and phase >= TWINKLE_SHOWN:
		return
	var arm: int = TWINKLE_ARM if phase >= 0.33 and phase < 0.66 else 1
	MedalArt.draw_twinkle(self, twinkle_at(index, hop), arm, CELL)


## Where medal `index`'s twinkle centre cell sits at hop `hop` (its top left, on the art grid).
static func twinkle_at(index: int, hop: int) -> Vector2:
	var centre: Vector2 = MEDAL_AT[index] + Vector2.ONE * (MedalArt.SIZE * CELL / 2.0)
	var spot: Vector2 = TWINKLE_SPOTS[hop % TWINKLE_SPOTS.size()] * TWINKLE_REACH * CELL
	return ((centre + spot) / CELL).floor() * CELL


## A medal popping back in: drawn from POP_FROM of its size past POP_OVER and back, centred.
func _draw_pop(index: int) -> void:
	var k: float = clampf(_pops[index] / POP_SECONDS, 0.0, 1.0)
	var grow: float = lerpf(POP_OVER, 1.0, (k - POP_PEAK) / (1.0 - POP_PEAK))
	if k < POP_PEAK:
		grow = lerpf(POP_FROM, POP_OVER, k / POP_PEAK)
	var cell: float = CELL * grow
	var centre: Vector2 = MEDAL_AT[index] + Vector2.ONE * (MedalArt.SIZE * CELL / 2.0)
	var corner: Vector2 = (centre - Vector2.ONE * MedalArt.SIZE * cell / 2.0).round()
	MedalArt.draw_medal(self, corner, MedalArt.SIZE, cell, index == 1)


## WON's check after the word.
func _draw_check(index: int) -> void:
	var at: Vector2 = _check_rect(index).position
	for row: int in range(CHECK_PIXELS.size()):
		for column: int in range(CHECK_PIXELS[row].length()):
			if CHECK_PIXELS[row][column] == "#":
				var pixel: Vector2 = at + Vector2(column, row) * WORD_CELL
				draw_rect(Rect2(pixel, Vector2.ONE * WORD_CELL), Palette.GREEN_LIGHT)


func _check_rect(index: int) -> Rect2:
	var won: Rect2 = _won[index].get_rect()
	var size_px: Vector2 = Vector2(CHECK_PIXELS[0].length(), CHECK_PIXELS.size()) * WORD_CELL
	return Rect2(Vector2(won.end.x + CHECK_GAP, won.position.y), size_px)


## The words for the states: each name (steel once won), its threshold or WON; the clock runs
## while a medal twinkles or pops.
func _refresh_parts() -> void:
	for index: int in range(2):
		var state: int = _states[index]
		var shown: bool = state != WeekMedals.State.OFF
		var won: bool = state == WeekMedals.State.USED
		var ink: Color = Palette.MUSTARD_LIGHT if index == 1 else Palette.STEEL_HIGHLIGHT
		_names[index].visible = shown
		_names[index].color = Palette.STEEL if won else ink
		_names[index].size = _names[index].get_combined_minimum_size()
		_lines[index].visible = shown and not won
		_won[index].visible = won
		_won[index].size = _won[index].get_combined_minimum_size()
		var area: Dictionary = parts(index == 1)
		var over: Rect2 = (area["medal"] as Rect2).merge(area["name"]).merge(area["line"])
		_targets[index].visible = shown
		_targets[index].position = over.position
		_targets[index].size = over.size
	var live: bool = _states.any(_is_medal) and not reduced_motion
	set_process(live or _pops[0] >= 0.0 or _pops[1] >= 0.0)
	queue_redraw()


static func _is_medal(state: int) -> bool:
	return state == WeekMedals.State.AVAILABLE or state == WeekMedals.State.PENDING
