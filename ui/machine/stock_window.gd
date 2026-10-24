class_name StockWindow
extends Control
## The machine's stock window (v0.50, mock-up premium_machine_v1.html; M4): a steel-framed glass
## window over the keys, split in two columns, each right above its key. It shows no real prizes,
## so nothing in it reads as a promise: a lit chute's column holds three SEALED tickets (COMMON,
## RARE, LEGENDARY: art/machine/sealed_ticket_*.png, their pips on them) on pedestals, each over
## its chute's current odds (MachineChuteInfo.odds.rarity_share: MachineOdds at the shift's odds
## level) and its rarity's word. The tickets are drawn on the pixel grid through the sharp-pixel
## material (a layer of their own, integer 2x, snapped), never filtered soft (v0.53). Each odds
## sits on an odds plate in the machine's own language (v0.53): a small LED window like the
## display's (charcoal, scanlines, a backlight in its rarity's colour) with the share in the
## number font (Atkinson 750) in that colour, over a tab in the rarity's colours and word, as the
## prize tickets' RarityTab. A column whose chute isn't lit is shut (dark, its shutter down);
## the idle machine's are both shut. Each column has a spot lamp; a hovered key's column glows
## brighter. Once a chute is chosen only its column stays lit, through the draw.
##
## On a BOOSTED visit the columns restock one by one as the machine turns PREMIUM (MachineLook:
## the classic tickets drop out, the loyalty pair's rise onto gold pedestals); a STAMP DAY visit
## shows the loyalty pair's columns from its start.

const SIZE := Vector2(408, 208)
const COLUMNS := 2
const TICKETS := [
	preload("res://art/machine/sealed_ticket_common.png"),
	preload("res://art/machine/sealed_ticket_rare.png"),
	preload("res://art/machine/sealed_ticket_legendary.png"),
]
const TICKET_SIZE := Vector2(48, 64)
const TICKET_STEP := 62.0
const TICKET_TOP := 44.0
const PEDESTAL_SIZE := Vector2(56, 18)
## The odds plate under each pedestal: its LED window (the share) over its rarity tab (the word).
const PLATE_TOP := 132.0
const PLATE_SIZE := Vector2(56, 44)
const LED_HEIGHT := 26.0
const ODDS_SIZE := 17
const WORD_SIZE := 9
## The word's smaller size when it doesn't fit its tab.
const WORD_SMALL := 8
const BOLD_WEIGHT := 800
const RARITY_WORDS: Array[String] = ["COMMON", "RARE", "LEGENDARY"]
## The share's colour, lit in its LED window, per rarity.
const RARITY_INK: Array[Color] = [Palette.PAPER, Palette.TEAL_BRIGHT, Palette.GOLD]
## The LED window's backlight (its rarity's colour) and its scanlines; brighter on a hovered key's
## column.
const BACKLIGHT_ALPHA := 0.14
const BACKLIGHT_HOVER_ALPHA := 0.26
const SCANLINE_ALPHA := 0.22
## The divider between the two columns and the shutter's slats.
const DIVIDER := 8.0
const SLAT := 8.0
## The window's glints (two stepped bands), quiet.
const GLINT_X: Array[float] = [44.0, 256.0]
const GLINT_ALPHA := 0.1
const CONE_ALPHA := 0.07
const CONE_HOVER_ALPHA := 0.16

## The machine this part belongs to (setup(), build spec 4.2).
var view: RewardMachineView
## Each chute's info for this visit (RewardMachine.chute_info), null while idle.
var _infos: Array[MachineChuteInfo] = [null, null, null, null]
## The chosen chute (-1: none yet): only its column stays lit.
var _chosen: int = -1
var _hovered: int = -1
## Each column now: its chute, lit, its offset (px) and whether its pedestals are gold.
var _column_chute: Array[int] = [0, 1]
var _column_lit: Array[bool] = [false, false]
var _column_offset: Array[float] = [0.0, 0.0]
var _column_gold: Array[bool] = [false, false]
var _odds: Array[Label] = []
var _words: Array[Label] = []
## The sealed tickets' layer, drawn through the sharp-pixel material.
var _tickets: Control


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
			var odds: Label = UiKit.number_label("", ODDS_SIZE, false)
			odds.add_theme_color_override("font_color", RARITY_INK[rarity])
			_place_label(odds, Vector2(PLATE_SIZE.x, LED_HEIGHT))
			odds.name = "Odds%d%d" % [column, rarity]
			_odds.append(odds)
			var word: Label = UiKit.body_label(
				RARITY_WORDS[rarity], _word_size(rarity), RarityTab.INKS[rarity]
			)
			word.add_theme_font_override("font", ArtStyle.bold_font(BOLD_WEIGHT))
			_place_label(word, Vector2(PLATE_SIZE.x, PLATE_SIZE.y - LED_HEIGHT))
			word.name = "Word%d%d" % [column, rarity]
			_words.append(word)


## Hooks this part to the machine: RewardMachineView calls it once, when it builds the part
## (build spec 4.2).
func setup(machine: RewardMachineView) -> void:
	view = machine


## The visit's chutes (RewardMachine.chute_info for each, by chute) and its chosen chute (-1:
## none yet); empty `infos`: the idle machine, both columns shut.
func show_chutes(infos: Array[MachineChuteInfo], chosen: int) -> void:
	_infos = [null, null, null, null]
	for chute: int in range(mini(infos.size(), 4)):
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


## The odds texts `chute`'s column shows now (COMMON, RARE, LEGENDARY), empty when it is shut.
func odds_texts(chute: int) -> PackedStringArray:
	for column: int in range(COLUMNS):
		if _column_chute[column] == chute and _column_lit[column]:
			return PackedStringArray(
				[_odds[column * 3].text, _odds[column * 3 + 1].text, _odds[column * 3 + 2].text]
			)
	return PackedStringArray()


## The sealed tickets' layer (pixel art through the sharp-pixel material), for tests.
func tickets_layer() -> Control:
	return _tickets


## Where rarity `rarity`'s odds plate stands in `column` (window coordinates, on the 2 px grid,
## before a restock's offset).
static func plate_rect(column: int, rarity: int) -> Rect2:
	var x: float = _ticket_x(column, rarity) - (PLATE_SIZE.x - TICKET_SIZE.x) / 2.0
	return Rect2(Vector2(x, PLATE_TOP), PLATE_SIZE)


## The odds and rarity labels, for layout tests.
func labels() -> Array[Label]:
	var found: Array[Label] = []
	found.append_array(_odds)
	found.append_array(_words)
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
	for column: int in range(COLUMNS):
		var shape: Array = look.column(column)
		var loyalty: bool = shape[1]
		var chute: int = column + (2 if loyalty else 0)
		var info: MachineChuteInfo = _infos[chute]
		var lit: bool = info != null and info.state == RewardMachine.ChuteState.OPEN
		# A PREMIUM visit's classic columns keep their stock until they drop out in the restock.
		lit = lit or (info != null and look.premium_visit and not loyalty and not look.stamp_day)
		lit = lit and (_chosen < 0 or _chosen == chute)
		_column_chute[column] = chute
		_column_lit[column] = lit
		_column_offset[column] = shape[0]
		_column_gold[column] = loyalty and look.premium()
		var texts: PackedStringArray = _column_texts(info) if lit else PackedStringArray()
		for rarity: int in range(3):
			var odds: Label = _odds[column * 3 + rarity]
			var word: Label = _words[column * 3 + rarity]
			odds.visible = lit
			word.visible = lit
			if not lit:
				continue
			odds.text = texts[rarity]
			var plate: Rect2 = plate_rect(column, rarity)
			odds.position = plate.position + Vector2(0, shape[0])
			word.position = plate.position + Vector2(0, LED_HEIGHT + shape[0])
	queue_redraw()
	_tickets.queue_redraw()


## Ticket `rarity`'s left edge in `column`.
## `info`'s three rarity shares as the window prints them (percent_texts).
static func _column_texts(info: MachineChuteInfo) -> PackedStringArray:
	var shares: Array[float] = [0.0, 0.0, 0.0]
	if info.odds != null:
		for rarity: int in range(3):
			shares[rarity] = info.odds.rarity_share[rarity]
	return percent_texts(shares)


static func _ticket_x(column: int, rarity: int) -> float:
	var middle: float = SIZE.x / 4.0 * (2 * column + 1)
	var row: float = TICKET_STEP * 2.0 + TICKET_SIZE.x
	return MachineArt.snap(middle - row / 2.0 + rarity * TICKET_STEP)


func _place_label(label: Label, box: Vector2) -> void:
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.clip_text = true
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	RewardMachineView.fit(label, Rect2(Vector2.ZERO, box))
	label.visible = false
	add_child(label)


## The word's size on its tab: WORD_SIZE, or WORD_SMALL when it doesn't fit inside the tab's
## outline.
static func _word_size(rarity: int) -> int:
	var font: Font = ArtStyle.bold_font(BOLD_WEIGHT)
	var room: float = PLATE_SIZE.x - 4.0 * MachineArt.PIXEL
	if MachineArt.text_width(RARITY_WORDS[rarity], font, WORD_SIZE) <= room:
		return WORD_SIZE
	return WORD_SMALL


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, SIZE), Palette.TEAL_BLACK)
	var width: float = SIZE.x / COLUMNS
	for column: int in range(COLUMNS):
		var cell: Rect2 = Rect2(column * width + 2, 2, width - 4, SIZE.y - 4)
		if _column_lit[column]:
			_draw_column(column, cell)
		else:
			_draw_shutter(cell)
	var divider: Rect2 = Rect2(SIZE.x / 2.0 - DIVIDER / 2.0, 0, DIVIDER, SIZE.y)
	draw_rect(divider, Palette.STEEL)
	draw_rect(Rect2(divider.position, Vector2(2, SIZE.y)), Palette.STEEL_HIGHLIGHT)
	draw_rect(Rect2(divider.end.x - 2, 0, 2, SIZE.y), Palette.STEEL_DARK)
	_draw_glints()


## A lit column: its back, its spot lamp and light cone, its three sealed tickets on pedestals.
func _draw_column(column: int, cell: Rect2) -> void:
	draw_rect(cell, Palette.BACKGROUND)
	var middle: float = cell.get_center().x
	draw_rect(Rect2(middle - 12, cell.position.y, 24, 4), Palette.STEEL_DARK)
	draw_rect(Rect2(middle - 8, cell.position.y + 4, 16, 2), Palette.MUSTARD_PALE)
	var hover: bool = _hovered == _column_chute[column]
	var cone: PackedVector2Array = PackedVector2Array(
		[
			Vector2(middle - 8, 8),
			Vector2(middle + 8, 8),
			Vector2(middle + 92, cell.end.y - 24),
			Vector2(middle - 92, cell.end.y - 24),
		]
	)
	draw_colored_polygon(
		cone, Color(Palette.MUSTARD_PALE, CONE_HOVER_ALPHA if hover else CONE_ALPHA)
	)
	var dy: float = _column_offset[column]
	var gold: bool = _column_gold[column]
	for rarity: int in range(3):
		var x: float = _ticket_x(column, rarity)
		var base: float = TICKET_TOP + TICKET_SIZE.y + dy
		var pedestal: Rect2 = Rect2(
			Vector2(x - (PEDESTAL_SIZE.x - TICKET_SIZE.x) / 2.0, base), PEDESTAL_SIZE
		)
		MachineArt.box(self, pedestal, Palette.GOLD if gold else Palette.STEEL_LIGHT, Palette.INK)
		var top: Color = Palette.MUSTARD_PALE if gold else Palette.STEEL_HIGHLIGHT
		draw_rect(Rect2(pedestal.position + Vector2(2, 2), Vector2(PEDESTAL_SIZE.x - 4, 2)), top)
		var side: Color = Palette.BRASS if gold else Palette.STEEL
		draw_rect(Rect2(pedestal.position + Vector2(2, 8), Vector2(PEDESTAL_SIZE.x - 4, 6)), side)
		var foot: Color = Palette.BRASS_DARK if gold else Palette.STEEL_DARK
		draw_rect(Rect2(pedestal.position + Vector2(2, 14), Vector2(PEDESTAL_SIZE.x - 4, 2)), foot)
		_draw_plate(column, rarity, dy, hover)


## Rarity `rarity`'s odds plate in `column`, `dy` px down: a charcoal LED window with its
## backlight and scanlines over the rarity's tab (RarityTab's colours), with a soft shadow.
func _draw_plate(column: int, rarity: int, dy: float, hover: bool) -> void:
	var plate: Rect2 = plate_rect(column, rarity)
	plate.position.y += dy
	var p: float = MachineArt.PIXEL
	draw_rect(Rect2(plate.position + Vector2(p, p), plate.size), Color(Palette.INK, 0.35))
	MachineArt.box(self, plate, Palette.CHARCOAL, Palette.INK)
	var led: Rect2 = Rect2(
		plate.position + Vector2(p, p), Vector2(plate.size.x - 2.0 * p, LED_HEIGHT - p)
	)
	var glow: float = BACKLIGHT_HOVER_ALPHA if hover else BACKLIGHT_ALPHA
	draw_rect(led, Color(RARITY_INK[rarity], glow))
	var y: float = led.position.y + p
	while y < led.end.y:
		draw_rect(Rect2(led.position.x, y, led.size.x, p / 2.0), Color(Palette.INK, SCANLINE_ALPHA))
		y += p * 2.0
	var tab: Rect2 = Rect2(
		Vector2(plate.position.x, plate.position.y + LED_HEIGHT),
		Vector2(plate.size.x, plate.size.y - LED_HEIGHT)
	)
	var legendary: bool = rarity == MachinePrize.Rarity.LEGENDARY
	var line: Color = Palette.BRASS_DARKEST if legendary else Palette.INK
	MachineArt.box(self, tab, RarityTab.FILLS[rarity], line)
	if legendary:
		var top: Rect2 = Rect2(tab.position + Vector2(p, p), Vector2(tab.size.x - 2.0 * p, p))
		draw_rect(top, Palette.MUSTARD_PALE)


## The lit columns' sealed tickets, on the 2 px grid (the art at an integer 2x).
func _draw_tickets() -> void:
	for column: int in range(COLUMNS):
		if not _column_lit[column]:
			continue
		for rarity: int in range(3):
			var at: Vector2 = Vector2(
				_ticket_x(column, rarity), TICKET_TOP + _column_offset[column]
			)
			var ticket: Rect2 = Rect2(MachineArt.snap_point(at), TICKET_SIZE)
			_tickets.draw_texture_rect(TICKETS[rarity], ticket, false)


## A shut column: dark, its shutter's slats down.
func _draw_shutter(cell: Rect2) -> void:
	draw_rect(cell, Palette.CHARCOAL)
	var y: float = cell.position.y + SLAT
	while y < cell.end.y:
		draw_rect(Rect2(cell.position.x, y, cell.size.x, 2), Palette.STEEL_DARKEST)
		y += SLAT


func _draw_glints() -> void:
	var colour: Color = Color(Palette.GLASS_GLOW, GLINT_ALPHA)
	for gx: float in GLINT_X:
		var j: float = 0.0
		while j < SIZE.y:
			var x0: float = maxf(0.0, gx - j / 2.0)
			var x1: float = minf(SIZE.x, gx - j / 2.0 + 16.0)
			if x1 > x0:
				draw_rect(Rect2(x0, j, x1 - x0, 4), colour)
			j += 4.0
