class_name StockWindow
extends Control
## The machine's stock window (v0.50, M4; the relook's vitrine in v0.86, mock-up
## docs/art/mockups/machine_relook.html V2): the glass inside the cabinet's riveted steel frame
## (MachineCabinet.WINDOW_FRAME_RECT) over the keys, split in two columns by a steel mullion, each
## right above its key, with a sill along its foot. It shows no real prizes, so nothing in it reads
## as a promise: a lit chute's column holds three SEALED tickets (COMMON, RARE, LEGENDARY:
## art/machine/sealed_ticket_*.png, their pips on them) on steel pedestals, each over its chute's
## current odds (MachineChuteInfo.odds.rarity_share: MachineOdds at the shift's odds level) on an
## LED odds plate (charcoal, scanlines, a backlight in its rarity's colour) with the share in hard
## pixel digits in that colour (a 0% share grey, its sealed ticket faded). One legend along the
## sill names the rarities by their pips ("● COMMON ◆◆ RARE ★★★ LEGENDARY"), so the plates carry
## only their shares. The tickets are drawn on the pixel grid through the sharp-pixel material (a
## layer of their own, integer 2x, snapped), never filtered soft (v0.53). A column whose chute
## isn't lit is shut (dark, its shutter down); the idle machine's are both shut. Each column has a
## spot lamp; a hovered key's column glows brighter. Once a chute is chosen only its column stays
## lit, through the draw.
##
## On a PREMIUM visit the columns restock one by one as the machine turns PREMIUM (MachineLook:
## the classic tickets drop out and the same chutes' rise onto gold pedestals, with the premium
## odds).
##
## A week event that raises the odds (v0.70: Holiday rush's +1 level, MachineChuteInfo.week_odds)
## shows as a gold line along the window's top while a lit chute's odds include it: "WEEK ODDS +1".

const SIZE := Vector2(476, 204)
## The glass (the columns) over the sill.
const GLASS_HEIGHT := 184.0
const COLUMNS := 2
const TICKETS := [
	preload("res://art/machine/sealed_ticket_common.png"),
	preload("res://art/machine/sealed_ticket_rare.png"),
	preload("res://art/machine/sealed_ticket_legendary.png"),
]
const TICKET_SIZE := Vector2(48, 64)
const TICKET_STEP := 68.0
const TICKET_TOP := 20.0
const PEDESTAL_SIZE := Vector2(56, 6)
## The odds plate under each pedestal: an LED window holding the share.
const PLATE_TOP := 94.0
const PLATE_SIZE := Vector2(60, 28)
const RARITY_WORDS: Array[String] = ["COMMON", "RARE", "LEGENDARY"]
## The share's colour, lit in its LED window, per rarity (a 0% share: GREY).
const RARITY_INK: Array[Color] = [Palette.PAPER, Palette.TEAL_BRIGHT, Palette.GOLD]
## The sill legend's pips and words, per rarity.
const LEGEND_PIP_INK: Array[Color] = [Palette.STEEL_HIGHLIGHT, Palette.TEAL_LIGHT, Palette.GOLD]
const LEGEND_INK: Array[Color] = [Palette.STEEL_HIGHLIGHT, Palette.TEAL_PALE, Palette.GOLD]
const LEGEND_PIPS: Array[Array] = [
	[".#.", "###", ".#."],
	[".#...#.", "###.###", ".#...#."],
	["..#.....#.....#..", "#####.#####.#####", ".###...###...###.", ".#.#...#.#...#.#."],
]
## Art px between a pip and its word, and between one rarity's word and the next pip.
const LEGEND_PIP_GAP := 2
const LEGEND_GAP := 8
## The LED window's backlight (its rarity's colour) and its scanlines; brighter on a hovered key's
## column; a 0% share's sealed ticket fades to ZERO_ALPHA.
const BACKLIGHT_ALPHA := 0.25
const BACKLIGHT_HOVER_ALPHA := 0.45
const SCANLINE_ALPHA := 0.3
const ZERO_ALPHA := 0.4
## The mullion between the two columns and the shutter's slats.
const DIVIDER := 8.0
const SLAT := 8.0
## The window's glints (stepped bands, quiet) and the spot lamps' cones.
const GLINT_X: Array[float] = [40.0, 200.0, 360.0]
const GLINT_ALPHA := 0.35
const CONE_ALPHA := 0.07
const CONE_HOVER_ALPHA := 0.16
## The week event's odds line (v0.70): its text, and its capitals' top.
const WEEK_ODDS_TEXT := "WEEK ODDS +%d"
const WEEK_ODDS_TOP := 8.0

## The machine this part belongs to (setup(), build spec 4.2).
var view: RewardMachineView
## Each chute's info for this visit (RewardMachine.chute_info), null while idle.
var _infos: Array[MachineChuteInfo] = [null, null]
## The chosen chute (-1: none yet): only its column stays lit.
var _chosen: int = -1
var _hovered: int = -1
## Each column now: its chute, lit, its offset (px) and whether its pedestals are gold.
var _column_chute: Array[int] = [0, 1]
var _column_lit: Array[bool] = [false, false]
var _column_offset: Array[float] = [0.0, 0.0]
var _column_gold: Array[bool] = [false, false]
## Each column's shares as printed, and their odds lines (column * 3 + rarity).
var _texts: Array[PackedStringArray] = [PackedStringArray(), PackedStringArray()]
var _odds: Array[MachineLine] = []
var _legend: Array[MachineLine] = []
## The sealed tickets' layer, drawn through the sharp-pixel material.
var _tickets: Control
## The week event's odds line (v0.70).
var _week_odds: MachineLine


func _init() -> void:
	name = "StockWindow"
	size = SIZE
	clip_contents = true
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_tickets = Control.new()
	_tickets.name = "SealedTickets"
	_tickets.size = SIZE
	_tickets.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ArtStyle.use_pixel_material(_tickets)
	_tickets.draw.connect(_draw_tickets)
	add_child(_tickets)
	for column: int in range(COLUMNS):
		for rarity: int in range(3):
			var odds: MachineLine = MachineLine.new()
			odds.name = "Odds%d%d" % [column, rarity]
			odds.visible = false
			add_child(odds)
			_odds.append(odds)
	_week_odds = MachineLine.new()
	_week_odds.name = "WeekOdds"
	_week_odds.visible = false
	add_child(_week_odds)
	_add_legend()


## Hooks this part to the machine: RewardMachineView calls it once, when it builds the part
## (build spec 4.2).
func setup(machine: RewardMachineView) -> void:
	view = machine


## The visit's chutes (RewardMachine.chute_info for each, by chute) and its chosen chute (-1:
## none yet); empty `infos`: the idle machine, both columns shut.
func show_chutes(infos: Array[MachineChuteInfo], chosen: int) -> void:
	_infos = [null, null]
	for chute: int in range(mini(infos.size(), COLUMNS)):
		_infos[chute] = infos[chute]
	_chosen = chosen
	queue_redraw()


## The hovered key's chute (-1: none): its column glows brighter.
func set_hovered(chute: int) -> void:
	if chute != _hovered:
		_hovered = chute
		queue_redraw()


## Whether `chute`'s column is lit now (it shows its sealed tickets and odds).
func column_lit(chute: int) -> bool:
	for column: int in range(COLUMNS):
		if _column_chute[column] == chute:
			return _column_lit[column]
	return false


## Whether `chute`'s column stands lit on gold pedestals now (a PREMIUM visit, restocked).
func column_gold(chute: int) -> bool:
	for column: int in range(COLUMNS):
		if _column_chute[column] == chute:
			return _column_lit[column] and _column_gold[column]
	return false


## The odds texts `chute`'s column shows now (COMMON, RARE, LEGENDARY), empty when it is shut.
func odds_texts(chute: int) -> PackedStringArray:
	for column: int in range(COLUMNS):
		if _column_chute[column] == chute and _column_lit[column]:
			return _texts[column]
	return PackedStringArray()


## The sealed tickets' layer (pixel art through the sharp-pixel material), for tests.
func tickets_layer() -> Control:
	return _tickets


## Where rarity `rarity`'s odds plate stands in `column` (window coordinates, on the 2 px grid,
## before a restock's offset).
static func plate_rect(column: int, rarity: int) -> Rect2:
	var x: float = _ticket_x(column, rarity) - (PLATE_SIZE.x - TICKET_SIZE.x) / 2.0
	return Rect2(Vector2(x, PLATE_TOP), PLATE_SIZE)


## The sill's legend rect (window coordinates).
static func sill_rect() -> Rect2:
	return Rect2(0, GLASS_HEIGHT, SIZE.x, SIZE.y - GLASS_HEIGHT)


## The week event's odds line (v0.70; for tests).
func week_odds_label() -> MachineLine:
	return _week_odds


## The odds lines (column * 3 + rarity) and the sill legend's words, for layout tests.
func lines() -> Array[MachineLine]:
	var found: Array[MachineLine] = []
	found.append_array(_odds)
	found.append_array(_legend)
	return found


## The words the window prints (its odds and its legend), for tests.
func labels() -> Array[Label]:
	var found: Array[Label] = []
	for line: MachineLine in lines():
		for child: Node in line.get_children():
			if child is Label:
				found.append(child as Label)
	return found


## A share (0 .. 1) as the window prints it: a whole percent, "<1%" for a sliver.
static func percent_text(share: float) -> String:
	if share > 0.0 and share < 0.005:
		return "<1%"
	return "%d%%" % int(roundf(share * 100.0))


## A column's shares (COMMON, RARE, LEGENDARY) as the window prints them, whole percents by
## largest remainder so a column always adds up to its total (100 for a full odds card), and
## "<1%" for a share that gets none.
static func percent_texts(shares: Array[float]) -> PackedStringArray:
	var total: float = 0.0
	for share: float in shares:
		total += share
	var whole: Array[int] = []
	var given: int = 0
	for share: float in shares:
		whole.append(floori(share * 100.0 + 0.000001))
		given += whole[-1]
	var order: Array[int] = []
	order.assign(range(shares.size()))
	order.sort_custom(
		func(a: int, b: int) -> bool:
			return shares[a] * 100.0 - whole[a] > shares[b] * 100.0 - whole[b]
	)
	var left: int = roundi(total * 100.0) - given
	for index: int in order:
		if left <= 0:
			break
		whole[index] += 1
		left -= 1
	var texts: PackedStringArray = []
	for index: int in range(shares.size()):
		var sliver: bool = whole[index] == 0 and shares[index] > 0.0
		texts.append("<1%" if sliver else "%d%%" % whole[index])
	return texts


## The columns at time `t` (seconds) of view.plan (MachineLook: the restock during the premium
## transform).
func frame(t: float) -> void:
	var plan: MachinePlan = view.plan if view != null else null
	var look: MachineLook = MachineLook.at(plan, t)
	var week_odds: int = 0
	for column: int in range(COLUMNS):
		var shape: Array = look.column(column)
		var gold: bool = shape[1]
		var chute: int = column
		var info: MachineChuteInfo = _infos[chute]
		var lit: bool = info != null and info.state == RewardMachine.ChuteState.OPEN
		lit = lit and (_chosen < 0 or _chosen == chute)
		_column_chute[column] = chute
		_column_lit[column] = lit
		_column_offset[column] = shape[0]
		_column_gold[column] = gold and look.premium()
		if lit and info.week_odds > 0:
			week_odds = info.week_odds
		var texts: PackedStringArray = _column_texts(info) if lit else PackedStringArray()
		for rarity: int in range(3):
			var odds: MachineLine = _odds[column * 3 + rarity]
			odds.visible = lit
			if not lit:
				continue
			if texts != _texts[column]:
				var zero: bool = texts[rarity] == "0%"
				var ink: Color = Palette.GREY if zero else RARITY_INK[rarity]
				odds.show_text(texts[rarity], ink, ink)
			var plate: Rect2 = plate_rect(column, rarity)
			plate.position.y += shape[0]
			odds.centre_in(plate)
			odds.position.y += MachineArt.PIXEL  # The digits stand an art px over the capitals.
		_texts[column] = texts
	_week_odds.visible = week_odds > 0
	if _week_odds.visible and _week_odds.text() != WEEK_ODDS_TEXT % week_odds:
		_week_odds.show_text(WEEK_ODDS_TEXT % week_odds, Palette.GOLD)
		_week_odds.centre_in(Rect2(0, WEEK_ODDS_TOP, SIZE.x, _week_odds.size.y))
	queue_redraw()
	_tickets.queue_redraw()


## `info`'s three rarity shares as the window prints them (percent_texts).
static func _column_texts(info: MachineChuteInfo) -> PackedStringArray:
	var shares: Array[float] = [0.0, 0.0, 0.0]
	if info.odds != null:
		for rarity: int in range(3):
			shares[rarity] = info.odds.rarity_share[rarity]
	return percent_texts(shares)


## Ticket `rarity`'s left edge in `column`.
static func _ticket_x(column: int, rarity: int) -> float:
	var width: float = (SIZE.x - DIVIDER) / COLUMNS
	var middle: float = width / 2.0 + column * (width + DIVIDER)
	var row: float = TICKET_STEP * 2.0 + TICKET_SIZE.x
	return MachineArt.snap(middle - row / 2.0 + rarity * TICKET_STEP)


## The sill's legend words, laid out with room for their pips before each.
func _add_legend() -> void:
	var art: float = ArtStyle.ART_SCALE
	var widths: Array[float] = []
	var total: float = 0.0
	for rarity: int in range(3):
		var line: MachineLine = MachineLine.make(
			"Legend%d" % rarity, RARITY_WORDS[rarity], LEGEND_INK[rarity]
		)
		_legend.append(line)
		add_child(line)
		var pip: float = (LEGEND_PIPS[rarity][0] as String).length() * art
		widths.append(pip + LEGEND_PIP_GAP * art + line.width())
		total += widths[-1] + (LEGEND_GAP * art if rarity > 0 else 0.0)
	var sill: Rect2 = sill_rect()
	var x: float = MachineArt.snap((SIZE.x - total) / 2.0)
	var top: float = MachineArt.snap(sill.get_center().y - _legend[0].size.y / 2.0)
	for rarity: int in range(3):
		var pip: float = (LEGEND_PIPS[rarity][0] as String).length() * art
		_legend[rarity].position = Vector2(x + pip + LEGEND_PIP_GAP * art, top)
		x += widths[rarity] + LEGEND_GAP * art


func _draw() -> void:
	draw_rect(Rect2(0, 0, SIZE.x, GLASS_HEIGHT), Palette.BACKGROUND)
	var width: float = (SIZE.x - DIVIDER) / COLUMNS
	for column: int in range(COLUMNS):
		var cell: Rect2 = Rect2(column * (width + DIVIDER), 0, width, GLASS_HEIGHT)
		if _column_lit[column]:
			_draw_column(column, cell)
		else:
			_draw_shutter(cell)
	_draw_glints()
	var p: float = MachineArt.PIXEL
	var divider: Rect2 = Rect2(width, 0, DIVIDER, GLASS_HEIGHT)
	draw_rect(divider, Palette.INK)
	draw_rect(divider.grow_individual(-p, 0, -p, 0), Palette.STEEL_PALE)
	_draw_sill()


## The sill: steel dark with a shaded top row, and the legend's pips before their words.
func _draw_sill() -> void:
	var sill: Rect2 = sill_rect()
	var p: float = MachineArt.PIXEL
	draw_rect(sill, Palette.STEEL_DARK)
	draw_rect(Rect2(sill.position, Vector2(sill.size.x, p)), Palette.STEEL_SHADE)
	for rarity: int in range(3):
		var rows: Array = LEGEND_PIPS[rarity]
		var line: MachineLine = _legend[rarity]
		var pip_width: float = (rows[0] as String).length() * p
		var left: float = line.position.x - LEGEND_PIP_GAP * p - pip_width
		var top: float = (
			line.position.y + floorf((ArtStyle.PIXEL_CAP_HEIGHT - rows.size()) / 2.0) * p
		)
		_pattern(rows, Vector2(left, top), LEGEND_PIP_INK[rarity])


func _pattern(rows: Array, at: Vector2, colour: Color) -> void:
	var p: float = MachineArt.PIXEL
	for y: int in rows.size():
		var row: String = rows[y]
		for x: int in row.length():
			if row[x] == "#":
				draw_rect(Rect2(at + Vector2(x, y) * p, Vector2(p, p)), colour)


## A lit column: its spot lamp and light cone, its three sealed tickets on pedestals over their
## odds plates.
func _draw_column(column: int, cell: Rect2) -> void:
	var middle: float = cell.get_center().x
	draw_rect(Rect2(middle - 12, 0, 24, 4), Palette.MUSTARD_PALE)
	var hover: bool = _hovered == _column_chute[column]
	var cone: PackedVector2Array = PackedVector2Array(
		[
			Vector2(middle - 12, 4),
			Vector2(middle + 12, 4),
			Vector2(middle + 96, GLASS_HEIGHT - 20),
			Vector2(middle - 96, GLASS_HEIGHT - 20),
		]
	)
	draw_colored_polygon(
		cone, Color(Palette.MUSTARD_PALE, CONE_HOVER_ALPHA if hover else CONE_ALPHA)
	)
	var dy: float = _column_offset[column]
	var gold: bool = _column_gold[column]
	var p: float = MachineArt.PIXEL
	for rarity: int in range(3):
		var x: float = _ticket_x(column, rarity)
		var base: float = TICKET_TOP + TICKET_SIZE.y + dy
		var pedestal: Rect2 = Rect2(
			Vector2(x - (PEDESTAL_SIZE.x - TICKET_SIZE.x) / 2.0, base), PEDESTAL_SIZE
		)
		draw_rect(pedestal, Palette.INK)
		var top: Rect2 = Rect2(
			pedestal.position + Vector2(p, 0), Vector2(pedestal.size.x - 2.0 * p, 2.0 * p)
		)
		draw_rect(top, Palette.MUSTARD if gold else Palette.STEEL_PALE)
		var foot: Rect2 = Rect2(top.position + Vector2(0, 2.0 * p), Vector2(top.size.x, p))
		draw_rect(foot, Palette.BRASS_DARK if gold else Palette.STEEL_SHADE)
		_draw_plate(column, rarity, dy, hover)


## Rarity `rarity`'s odds plate in `column`, `dy` px down: a charcoal LED window with its
## backlight (its rarity's colour) and scanlines.
func _draw_plate(column: int, rarity: int, dy: float, hover: bool) -> void:
	var plate: Rect2 = plate_rect(column, rarity)
	plate.position.y += dy
	var p: float = MachineArt.PIXEL
	draw_rect(plate, Palette.INK)
	var led: Rect2 = plate.grow(-p)
	draw_rect(led, Palette.CHARCOAL)
	var glow: float = BACKLIGHT_HOVER_ALPHA if hover else BACKLIGHT_ALPHA
	var ink: Color = Palette.GREY_LIGHT if rarity == 0 else RARITY_INK[rarity]
	draw_rect(led, Color(ink, glow))
	var y: float = led.position.y + p
	while y < led.end.y:
		draw_rect(Rect2(led.position.x, y, led.size.x, p / 2.0), Color(Palette.INK, SCANLINE_ALPHA))
		y += p * 2.0


## The lit columns' sealed tickets, on the 2 px grid (the art at an integer 2x); a 0% share's
## faded.
func _draw_tickets() -> void:
	for column: int in range(COLUMNS):
		if not _column_lit[column]:
			continue
		var texts: PackedStringArray = _texts[column]
		for rarity: int in range(3):
			var at: Vector2 = Vector2(
				_ticket_x(column, rarity), TICKET_TOP + _column_offset[column]
			)
			var ticket: Rect2 = Rect2(MachineArt.snap_point(at), TICKET_SIZE)
			var zero: bool = texts.size() == 3 and texts[rarity] == "0%"
			var tint: Color = Color(1, 1, 1, ZERO_ALPHA if zero else 1.0)
			_tickets.draw_texture_rect(TICKETS[rarity], ticket, false, tint)


## A shut column: dark, its shutter's slats down.
func _draw_shutter(cell: Rect2) -> void:
	draw_rect(cell, Palette.CHARCOAL)
	var y: float = cell.position.y + SLAT
	while y < cell.end.y:
		draw_rect(Rect2(cell.position.x, y, cell.size.x, 2), Palette.STEEL_DARKEST)
		y += SLAT


func _draw_glints() -> void:
	var colour: Color = Color(Palette.TEAL_DARK, GLINT_ALPHA)
	for gx: float in GLINT_X:
		var j: float = 0.0
		while j < GLASS_HEIGHT:
			var x0: float = maxf(0.0, gx - j / 2.0)
			var x1: float = minf(SIZE.x, gx - j / 2.0 + 20.0)
			if x1 > x0:
				draw_rect(Rect2(x0, j, x1 - x0, 2), colour)
			j += 2.0
