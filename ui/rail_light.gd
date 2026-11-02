class_name RailLight
extends Control
## #86's rail light, kept by #105 piece 2 (mock-up readability_v3.html's railLightHTML): as a
## giver's effect pays in the count, the price rail's top strip (RAIL_Y, RAIL_HEIGHT px, between
## its ink lines) lights gold from the giver's ticket to the target's over rail_run_s (its head a
## paper tip with a spark), the giver's ticket gets a gold edge at once and the target's once
## the light reaches it; the light holds to rail_hold_s and fades over rail_fade_s
## (CountTotalTuning). A giver already in the bag lights from the rail's left end. It runs on
## `make_tween` (the count's clock). Under reduced motion it shows no run: the light and both edges
## show at once and fade the same. Stage coordinates (the layer covers the stage). Decor only.
## The light fills the belt's apron band exactly (BeltPanel.APRON, inside the rail's ends): its top
## SHADE rows a darker gold under the lip, as the steel band is, and the belt's bolts and chevrons
## drawn back over it, so it reads as the band lighting up.
## Over the quota light's lit band (QuotaLight, mustard or gold: `under` says LIT, or LIT_CHASE
## while BonusLights chase over it) a gold run would vanish, so it draws an ink-brown frame round
## a paper core instead (OVER_FRAME, OVER_CORE); over the chase it keeps to the band's upper rows,
## so the bulbs below still show through.

## What a column of the band shows under a run: bare steel (or the short tomato band), the lit
## mustard or gold band, or that band with the bonus lights' bulbs on its lower rows.
enum Under { STEEL, LIT, LIT_CHASE }

const RAIL_Y := ShiftStage.BELT_RECT.position.y + BeltPanel.APRON.position.y
const RAIL_HEIGHT := BeltPanel.APRON.size.y
const RAIL_LEFT := ShiftStage.BELT_RECT.position.x + BeltPanel.APRON.position.x
const RAIL_RIGHT := RAIL_LEFT + BeltPanel.APRON.size.x
const SHADE := 2.0
const SHADE_COLOR := Palette.MUSTARD_DARK
const HIGHLIGHT := 2.0
const HEAD_WIDTH := 6.0
const HEAD_TIP := 2.0
const EDGE := 2.0
const GRID := 2.0
const FROM_COLOR := Palette.MUSTARD
const TO_COLOR := Palette.GOLD
const HIGHLIGHT_COLOR := Palette.MUSTARD_PALE
const EDGE_COLOR := Palette.GOLD
const OVER_FRAME := Palette.MUSTARD_DARKEST
const OVER_CORE := Palette.PAPER
## The band's upper rows over the chase, which BonusLights' bulbs (BULB_SIZE, on its lower rows)
## leave free.
const CHASE_ROWS := 4.0

## Returns a new Tween on the count's clock; none: the layer's own.
var make_tween: Callable = Callable()
## Returns true when the player asked for reduced motion. None means false.
var reduced_motion: Callable = Callable()
## Returns what the band shows at a stage x (an Under). None means STEEL.
var under: Callable = Callable()

var _tuning: CountTotalTuning
## The live runs: each with its from and to x, its tickets' rects and its age.
var _runs: Array[Dictionary] = []


func _init(tuning: CountTotalTuning = null) -> void:
	name = "RailLight"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_tuning = tuning if tuning != null else load(CountUpPlan.TOTAL_TUNING_PATH) as CountTotalTuning


## A giver's effect pays: the light runs from `from_x` to `to_x` (this layer's coordinates) with
## the giver's ticket `giver` (an empty rect for a bagged giver) and the target's `target` edged.
func run(from_x: float, to_x: float, giver: Rect2, target: Rect2) -> void:
	var lit: Dictionary = {"from": from_x, "to": to_x, "giver": giver, "target": target, "q": 0.0}
	if _reduced():
		lit["q"] = _tuning.rail_run_s
	_runs.append(lit)
	queue_redraw()
	if not is_inside_tree():
		return
	var life: float = _tuning.rail_hold_s + _tuning.rail_fade_s
	var tween: Tween = _new_tween()
	var start: float = lit["q"]
	tween.tween_method(_age.bind(lit), start, life, maxf(0.01, life - start))
	tween.tween_callback(_end.bind(lit))


## Whether a light shows now, its lit span (from, head x) and its alpha, for checks.
func is_lit() -> bool:
	return not _runs.is_empty()


func lit_span() -> Vector2:
	if _runs.is_empty():
		return Vector2.ZERO
	var lit: Dictionary = _runs[-1]
	return Vector2(lit["from"], _head(lit))


func alpha() -> float:
	return _alpha(_runs[-1]) if not _runs.is_empty() else 0.0


func clear() -> void:
	_runs.clear()
	queue_redraw()


func _draw() -> void:
	for lit: Dictionary in _runs:
		_draw_run(lit)


func _draw_run(lit: Dictionary) -> void:
	var alpha_now: float = _alpha(lit)
	if alpha_now <= 0.0:
		return
	var span: Vector2 = _span(lit)
	var left: float = span.x
	var width: float = span.y
	var column: float = 0.0
	while column < width:
		var x: float = left + column
		var cells: Array[Color] = run_cells(_under_at(x), column / maxf(1.0, width))
		for row: int in range(cells.size()):
			var colour: Color = cells[row]
			if colour.a > 0.0:
				colour.a *= alpha_now
				var cell := Rect2(x, RAIL_Y + row * GRID, minf(GRID, width - column), GRID)
				draw_rect(cell, colour)
		column += GRID
	if width > 0.0:
		draw_hardware(self, left, left + width, alpha_now)
	var arrived: bool = float(lit["q"]) >= _tuning.rail_run_s
	if not arrived and width > 0.0:
		_draw_head(lit)
	var giver: Rect2 = lit["giver"]
	if giver.has_area():
		_edge(giver, alpha_now)
	var target: Rect2 = lit["target"]
	if arrived and target.has_area():
		_edge(target, alpha_now)


## A column's cells (GRID rows each, top down) for a run over `below` (an Under), `share` of the
## way from its giver end: the gold run on steel, the ink-brown frame and paper core on the lit
## band, only the upper rows over the chase (the rest clear, the bulbs showing).
static func run_cells(below: Under, share: float) -> Array[Color]:
	var rows: int = roundi(RAIL_HEIGHT / GRID)
	var cells: Array[Color] = []
	cells.resize(rows)
	if below == Under.STEEL:
		var body: Color = FROM_COLOR.lerp(TO_COLOR, share)
		for row: int in range(rows):
			cells[row] = body
		cells[0] = SHADE_COLOR
		cells[1] = HIGHLIGHT_COLOR
		return cells
	var drawn: int = rows if below == Under.LIT else roundi(CHASE_ROWS / GRID)
	for row: int in range(rows):
		if row >= drawn:
			cells[row] = Color.TRANSPARENT
		elif row == 0 or (row == drawn - 1 and below == Under.LIT):
			cells[row] = OVER_FRAME
		else:
			cells[row] = OVER_CORE
	return cells


## The colour the latest run's body draws at stage `at` (transparent off it), for checks.
func colour_at(at: Vector2) -> Color:
	if _runs.is_empty():
		return Color.TRANSPARENT
	var lit: Dictionary = _runs[-1]
	var span: Vector2 = _span(lit)
	if at.x < span.x or at.x >= span.x + span.y or at.y < RAIL_Y or at.y >= RAIL_Y + RAIL_HEIGHT:
		return Color.TRANSPARENT
	var column: float = floorf((at.x - span.x) / GRID) * GRID
	var cells: Array[Color] = run_cells(_under_at(span.x + column), column / maxf(1.0, span.y))
	var colour: Color = cells[clampi(floori((at.y - RAIL_Y) / GRID), 0, cells.size() - 1)]
	if colour.a > 0.0:
		colour.a *= _alpha(lit)
	return colour


## The running head: a paper tip with a spark (over the lit band: an ink-brown back, the spark's
## arms brown, on the rows the run draws there).
func _draw_head(lit: Dictionary) -> void:
	var head: float = clampf(_head(lit), RAIL_LEFT, RAIL_RIGHT)
	var ahead: float = signf(float(lit["to"]) - float(lit["from"]))
	var tip_x: float = head - HEAD_TIP if ahead > 0.0 else head
	var back_x: float = head - HEAD_WIDTH if ahead > 0.0 else head
	var below: Under = _under_at(head - ahead * GRID)
	var body_y: float = RAIL_Y + SHADE
	var body_height: float = RAIL_HEIGHT - SHADE
	var back: Color = Palette.MUSTARD_PALE
	var arms: Color = Palette.GOLD
	if below != Under.STEEL:
		body_y = RAIL_Y
		body_height = RAIL_HEIGHT if below == Under.LIT else CHASE_ROWS
		back = OVER_FRAME
		arms = OVER_FRAME
	draw_rect(Rect2(back_x, body_y, HEAD_WIDTH, body_height), back)
	draw_rect(Rect2(tip_x, body_y, HEAD_TIP, body_height), Palette.PAPER)
	_spark(Vector2(head - ahead * 4.0, RAIL_Y + RAIL_HEIGHT / 2.0 - 1.0), arms, Palette.PAPER)


## The belt's bolts and chevrons that fall between `left` and `right` (stage x), drawn on
## `canvas` at `alpha_now`, back over a light on the apron band (this one, or BonusLights).
static func draw_hardware(canvas: CanvasItem, left: float, right: float, alpha_now: float) -> void:
	var tint: Color = Color(Color.WHITE, alpha_now)
	for index: int in range(BeltPanel.BOLT_COUNT):
		var step: Vector2 = ShiftStage.BELT_RECT.position + Vector2(index * BeltPanel.BOLT_PITCH, 0)
		for part: Array in [
			[BeltPanel.BELT_BOLT, BeltPanel.BOLT_FIRST],
			[BeltPanel.BELT_CHEVRONS, BeltPanel.CHEVRONS_FIRST]
		]:
			var texture: Texture2D = part[0]
			var at: Vector2 = step + (part[1] as Vector2)
			if at.x + texture.get_width() > left and at.x < right:
				canvas.draw_texture(texture, at, tint)


## A plus of `arms` cells round a centre of `centre_colour`.
func _spark(at: Vector2, arms: Color, centre_colour: Color) -> void:
	var cell: Vector2 = Vector2.ONE * GRID
	var spot: Vector2 = at.snapped(cell)
	for arm: Vector2 in [Vector2(0, -2), Vector2(-2, 0), Vector2(2, 0), Vector2(0, 2)]:
		draw_rect(Rect2(spot + arm, cell), arms)
	draw_rect(Rect2(spot, cell), centre_colour)


func _edge(rect: Rect2, alpha_now: float) -> void:
	draw_rect(rect.grow(EDGE / 2.0), Color(EDGE_COLOR, alpha_now), false, EDGE)


## A run's left x and width on the rail.
func _span(lit: Dictionary) -> Vector2:
	var from_x: float = clampf(lit["from"], RAIL_LEFT, RAIL_RIGHT)
	var head: float = clampf(_head(lit), RAIL_LEFT, RAIL_RIGHT)
	return Vector2(minf(from_x, head), absf(head - from_x))


func _under_at(x: float) -> Under:
	if not under.is_valid():
		return Under.STEEL
	return under.call(x) as Under


func _head(lit: Dictionary) -> float:
	var from_x: float = lit["from"]
	var to_x: float = lit["to"]
	var run_q: float = clampf(float(lit["q"]) / maxf(0.01, _tuning.rail_run_s), 0.0, 1.0)
	var eased: float = run_q * run_q * (3.0 - 2.0 * run_q)
	return snappedf(lerpf(from_x, to_x, eased), GRID)


func _alpha(lit: Dictionary) -> float:
	var q: float = lit["q"]
	if q < _tuning.rail_hold_s:
		return 1.0
	return clampf(1.0 - (q - _tuning.rail_hold_s) / maxf(0.01, _tuning.rail_fade_s), 0.0, 1.0)


func _age(seconds: float, lit: Dictionary) -> void:
	lit["q"] = seconds
	queue_redraw()


func _end(lit: Dictionary) -> void:
	_runs.erase(lit)
	queue_redraw()


func _new_tween() -> Tween:
	if make_tween.is_valid():
		var tween: Tween = make_tween.call() as Tween
		if tween != null:
			return tween
	return create_tween()


func _reduced() -> bool:
	return reduced_motion.is_valid() and bool(reduced_motion.call())
