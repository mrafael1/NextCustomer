class_name OddsCard
extends PanelContainer
## A chute's odds card (#77, look F; build spec 4.2), left of the machine at ODDS_CARD_RECT:
## paper with a mustard-light inner rim over a 6 px shadow, its tail pointing at the keys. At the
## top the bonus ticket's red band (why it was given, the odds after the first pick); then the
## chute (Pixelify 24) with its REGULAR level and holes, what it does, "3 prizes, you keep 1 ·
## next visit here: a / b / c" (or REGULAR max, or no later visit uses REGULAR); one row per
## rarity (its % per drop, each prize's chance to be in the draw grouped by equal odds, the
## guarantee's items bold; an empty rarity reads "none in your stock"); the guarantee, the
## fallback notes, the chance of a RARE or better and of a LEGENDARY; CONFIRM › and BACK when the
## chute can be chosen. Every number is read from the MachineChuteInfo and its exact
## MachineOddsCard (RewardMachine); the card computes none. It pops in (0.18 s from 85 %, on
## view.idle_time; reduced motion: at once).

signal confirmed(chute: int)
signal backed

const WIDTH := 300.0
const PAD := 12.0
const TITLE_SIZE := 24
const ROW_SIZE := 12
const PERCENT_SIZE := 20
const LINE_SIZE := 11
const SUB_SIZE := 10
const BAND_SIZE := 12
const BUTTON_SIZE := 24
const BUTTON_HEIGHT := 42.0
const CONFIRM_WIDTH := 150.0
const BOLD_WEIGHT := 800
const LINE_WEIGHT := 600
const RARITY_NAMES: Array[String] = ["COMMON", "RARE", "LEGENDARY"]
const RARITY_WORDS: Array[String] = ["COMMON", "RARE!", "LEGENDARY!!"]
## Each chute's guarantee (its names bold in the rows), finished by ALWAYS or HOLDS_IN.
const GUARANTEES: Array[String] = [
	"one useful item (bold)",
	"one first-visit coupon (bold)",
	"one register that fits your cart (bold)",
	"",
]
const ALWAYS := "%s is always in the draw"
const HOLDS_IN := "%s is in the draw: holds in %s of draws"
const SHORT_LINE := "%s of draws hold fewer than %d"
## At a level with a first-drop floor, the rows cover the other drops (look F's level-3 line).
const FLOOR_LINE := (
	"REGULAR %d: drop 1 is at least %s (RARE %s · LEGENDARY %s);"
	+ " the rows are the other %d drops."
)
## A guarantee that holds in at least this share of draws reads "always".
const ALWAYS_FROM := 0.999999
## The fallback notes' texts, by MachineOddsCard note key (short_draw: SHORT_LINE).
const NOTE_TEXTS: Dictionary[StringName, String] = {
	&"legendary_empty_falls": "LEGENDARY: none left · rolls fall to RARE",
	&"legendary_none_in_stock": "LEGENDARY: none in your stock · rolls fall to RARE",
	&"new_arrival_held": "your newest arrival is held in this draw",
	&"cart_full": "CART FULL: SWAP 1 OUT",
	&"floor_falls": "no RARE or better in stock: the first drop falls back",
}
const CART_FULL_TEXT := "CART FULL: SWAP 1 OUT"
const EXPLAIN := "Tier % is per drop. A prize's % is its chance to be in the draw."
## A rarity's row names at most MAX_NAMES prizes (the guarantee's first, then the likeliest),
## then "+k more", so the card stays above the floor with a full collection's stock.
const MAX_NAMES := 6
const MORE := "+%d more"
## Below this share a chance prints as "<0.1%".
const SMALLEST := 0.0005
## Where the tail points: the keys' row (stage y), and the tail's size.
const TAIL_AT := 267.0
const TAIL_LENGTH := 16.0
const TAIL_HALF := 10.0
const SHADOW := 6.0
## The card's top (stage y): at ODDS_CARD_RECT's top, moved up as far as TOP_LIMIT (the cart
## drawer's top, below the top bar) while it is too tall to end, with its shadow, above
## ShiftStage.FLOOR_TOP.
const TOP_LIMIT := ShiftStage.CART_DRAWER_TOP
const BORDER := 2.0
const HOLE := 10.0
const HOLE_GAP := 4.0
## The pop: from POP_FROM of its size, over MachineTuning.odds_open_ms.
const POP_FROM := 0.85

var chute: int = 0
## The machine this part belongs to (setup(), build spec 4.2).
var view: RewardMachineView
var _column: VBoxContainer
var _buttons: HBoxContainer
var _confirm: Button
var _lines: PackedStringArray = PackedStringArray()
var _opened_at: float = 0.0
## The next visit's per-drop shares as last shown per chute ("40% / 45% / 15%"), for the
## display's REGULAR line after the pick.
var _next_shares: Dictionary[int, String] = {}


func _init() -> void:
	name = "OddsCard"
	mouse_filter = Control.MOUSE_FILTER_STOP
	custom_minimum_size = Vector2(WIDTH, 0)
	var style: StyleBoxEmpty = StyleBoxEmpty.new()
	style.content_margin_left = PAD
	style.content_margin_right = PAD
	style.content_margin_top = PAD - 4.0
	style.content_margin_bottom = PAD - 2.0
	add_theme_stylebox_override("panel", style)
	var outer: VBoxContainer = VBoxContainer.new()
	outer.add_theme_constant_override("separation", 8)
	outer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(outer)
	_column = VBoxContainer.new()
	_column.add_theme_constant_override("separation", 3)
	_column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	outer.add_child(_column)
	_buttons = HBoxContainer.new()
	_buttons.add_theme_constant_override("separation", 10)
	outer.add_child(_buttons)
	_confirm = _button(
		"CONFIRM ›", func() -> void: confirmed.emit(chute), "", Palette.TOMATO, Palette.TOMATO_DARK
	)
	_confirm.name = "Confirm"
	_confirm.custom_minimum_size = Vector2(CONFIRM_WIDTH, BUTTON_HEIGHT)
	_confirm.add_theme_color_override("font_color", Palette.PAPER)
	_confirm.add_theme_color_override("font_hover_color", Palette.PAPER)
	_confirm.add_theme_color_override("font_pressed_color", Palette.PAPER)
	var back: Button = _button(
		"BACK", func() -> void: backed.emit(), "ui_back", Palette.TEAL_LIGHT, Palette.TEAL
	)
	back.name = "Back"
	back.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	back.custom_minimum_size = Vector2(0, BUTTON_HEIGHT)
	visible = false
	resized.connect(_place)


## Shows `info`'s card for `card_chute`; `names` maps a prize key (MachinePrize.key) to its name;
## `band` is the bonus ticket's band (empty for none); `choosable` shows CONFIRM › and BACK.
func show_card(
	card_chute: int,
	info: MachineChuteInfo,
	names: Dictionary,
	band: PackedStringArray,
	choosable: bool
) -> void:
	chute = card_chute
	_lines = PackedStringArray()
	for child: Node in _column.get_children():
		_column.remove_child(child)
		child.queue_free()
	var odds: MachineOddsCard = info.odds
	if not band.is_empty():
		_add_band(band)
	_add_header(info)
	_add_rule()
	if odds.first_drop_min_rarity > 0:
		var floor_line: String = (
			"1 of %d at least %s" % [_prizes(), RARITY_NAMES[odds.first_drop_min_rarity]]
		)
		_add_line(floor_line, Palette.TEAL_SHADE, LINE_SIZE, BOLD_WEIGHT)
	for rarity: int in range(RARITY_NAMES.size()):
		_add_rarity(odds, rarity, names)
	_add_rule()
	var guarantee: String = guarantee_line(odds)
	if not guarantee.is_empty():
		_add_line(guarantee, Palette.GREEN_DARK, LINE_SIZE, BOLD_WEIGHT)
	for line: String in note_lines(info, _prizes()):
		_add_line(line, Palette.TOMATO_DARK, LINE_SIZE, BOLD_WEIGHT)
	var chances: String = (
		"At least one RARE or better %s · a LEGENDARY %s"
		% [pct(odds.p_rare_plus), pct(odds.p_legendary)]
	)
	_add_line(chances, Palette.INK, LINE_SIZE, BOLD_WEIGHT)
	_add_line(explain_line(odds, _prizes()), Palette.INK_LIGHT, LINE_SIZE, LINE_WEIGHT)
	if odds.meter_rises:
		_next_shares[chute] = _shares_text(odds.next_rarity_share)
	_buttons.visible = choosable
	visible = true
	reset_size()
	_place()
	_opened_at = view.idle_time if view != null else 0.0
	_pop(0.0 if not _instant() else 1.0)
	queue_redraw()


## The fallback notes' texts (a short draw's as the share of draws holding fewer than `prizes`),
## with "CART FULL: SWAP 1 OUT" when the cart is full.
static func note_lines(
	info: MachineChuteInfo, prizes: int = MachinePlan.MAX_PRIZES
) -> PackedStringArray:
	var lines: PackedStringArray = PackedStringArray()
	for note: StringName in info.odds.notes:
		if note == MachineOddsCard.NOTE_SHORT_DRAW:
			lines.append(SHORT_LINE % [pct(info.odds.p_short), prizes])
		else:
			lines.append(NOTE_TEXTS.get(note, String(note)))
	if info.cart_full and not lines.has(CART_FULL_TEXT):
		lines.append(CART_FULL_TEXT)
	return lines


## The guarantee's line: "always" only when it holds in every draw, else the share of draws it
## holds in (MachineOddsCard.p_guarantee_held); "" when the chute has none this draw.
static func guarantee_line(odds: MachineOddsCard) -> String:
	if not odds.guarded or GUARANTEES[odds.chute].is_empty():
		return ""
	if odds.p_guarantee_held >= ALWAYS_FROM:
		return ALWAYS % GUARANTEES[odds.chute]
	return HOLDS_IN % [GUARANTEES[odds.chute], pct(odds.p_guarantee_held)]


## What the rows' numbers cover: per drop, or, at a level with a first-drop floor, drop 1's own
## split and the rows as the other drops (look F's level-3 line).
static func explain_line(odds: MachineOddsCard, prizes: int) -> String:
	if odds.first_drop_min_rarity <= 0 or prizes <= 1:
		return EXPLAIN
	return (
		FLOOR_LINE
		% [
			odds.level,
			RARITY_NAMES[odds.first_drop_min_rarity],
			pct(odds.first_share[MachinePrize.Rarity.RARE]),
			pct(odds.first_share[MachinePrize.Rarity.LEGENDARY]),
			prizes - 1,
		]
	)


## Every line's text, top to bottom, for tests.
func texts() -> PackedStringArray:
	return _lines.duplicate()


func is_choosable() -> bool:
	return visible and _buttons.visible


func confirm_button() -> Button:
	return _confirm


## The next visit's per-drop shares last shown for `card_chute` ("40% / 45% / 15%"), or "".
func next_share_text(card_chute: int) -> String:
	return _next_shares.get(card_chute, "")


## The card's labels (plain and rich), for layout tests.
func shown_labels() -> Array[Control]:
	var found: Array[Control] = []
	_collect_labels(_column, found)
	return found


## The tail's tip (local), pointing at the keys' row.
func tail_tip() -> Vector2:
	return Vector2(size.x + TAIL_LENGTH, _tail_y())


## Hooks this part to the machine: RewardMachineView calls it once, when it builds the part
## (build spec 4.2).
func setup(machine: RewardMachineView) -> void:
	view = machine


## The card's top on the stage (stage y): ODDS_CARD_RECT's, or higher (as far as TOP_LIMIT) for
## a card of `height` that would end, with its shadow, below ShiftStage.FLOOR_TOP.
static func top_for(height: float) -> float:
	var top: float = ShiftStage.FLOOR_TOP - SHADOW - height
	return clampf(top, TOP_LIMIT, ShiftStage.ODDS_CARD_RECT.position.y)


## The card's pop at the machine's free-running time (it holds at a wait point): from 85 % to its
## size over odds_open_ms after it opened, at once under reduced motion.
func frame(_t: float) -> void:
	if not visible:
		return
	if _instant():
		_pop(1.0)
		return
	var length: float = MachineTuning.sec(view.tuning.odds_open_ms)
	var p: float = 1.0 if length <= 0.0 else (view.idle_time - _opened_at) / length
	_pop(clampf(p, 0.0, 1.0))


## Puts the card at its top for its size (its parent is the machine, at MACHINE_RECT) and its
## pop's pivot by the tail.
func _place() -> void:
	var origin: Vector2 = (
		ShiftStage.MACHINE_RECT.position if get_parent() is RewardMachineView else Vector2.ZERO
	)
	position = Vector2(ShiftStage.ODDS_CARD_RECT.position.x, top_for(size.y)) - origin
	pivot_offset = Vector2(size.x, _tail_y())


func _instant() -> bool:
	return view == null or view.plan == null or view.plan.reduced_motion


func _pop(p: float) -> void:
	var eased: float = 1.0 - (1.0 - p) * (1.0 - p)
	scale = Vector2.ONE * lerpf(POP_FROM, 1.0, eased)
	modulate.a = eased


func _prizes() -> int:
	if view == null or view.run == null:
		return MachinePlan.MAX_PRIZES
	return view.run.machine.machine.prizes_per_visit


## The bonus ticket's red band: its first line in Pixelify, the rest in small bold Atkinson.
func _add_band(band: PackedStringArray) -> void:
	var panel: PanelContainer = PanelContainer.new()
	panel.name = "BonusBand"
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = Palette.TOMATO_DARK
	style.border_color = Palette.INK
	style.set_border_width_all(2)
	style.content_margin_left = 8.0
	style.content_margin_right = 8.0
	style.content_margin_top = 3.0
	style.content_margin_bottom = 4.0
	panel.add_theme_stylebox_override("panel", style)
	var lines: VBoxContainer = VBoxContainer.new()
	lines.add_theme_constant_override("separation", 0)
	lines.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(lines)
	for index: int in range(band.size()):
		var label: Label = (
			UiKit.display_label(band[index], BAND_SIZE, false)
			if index == 0
			else _plain(band[index], Palette.MUSTARD_PALE, SUB_SIZE, BOLD_WEIGHT)
		)
		var colour: Color = Palette.PAPER if index == 0 else Palette.MUSTARD_PALE
		label.add_theme_color_override("font_color", colour)
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		label.custom_minimum_size = Vector2(WIDTH - 2.0 * PAD - 16.0, 0)
		lines.add_child(label)
		_lines.append(band[index])
	_column.add_child(panel)


## The chute and its REGULAR level with holes, what it does, and its next visit.
func _add_header(info: MachineChuteInfo) -> void:
	var row: HBoxContainer = HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var title: Label = UiKit.display_label(ChuteKey.NAMES[chute], TITLE_SIZE, false)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(title)
	_lines.append(title.text)
	var level_text: String = "REGULAR %d/%d" % [info.level, info.max_level]
	var level: Label = _plain(level_text, Palette.INK_LIGHT, SUB_SIZE, BOLD_WEIGHT)
	level.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(level)
	_lines.append(level_text)
	var holes: Control = Control.new()
	holes.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holes.custom_minimum_size = Vector2(info.max_level * (HOLE + HOLE_GAP), HOLE)
	holes.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var punched: int = info.level
	holes.draw.connect(func() -> void: _draw_holes(holes, punched, info.max_level))
	row.add_child(holes)
	_column.add_child(row)
	_add_line(ChuteKey.SUBS[chute], Palette.TEAL_SHADE, SUB_SIZE, BOLD_WEIGHT)
	_add_line(_next_text(info), Palette.INK_LIGHT, LINE_SIZE, BOLD_WEIGHT)


## A rarity's row: its name and % per drop, then its prizes with their chance to be in the draw.
func _add_rarity(odds: MachineOddsCard, rarity: int, names: Dictionary) -> void:
	var row: HBoxContainer = HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var rarity_label: Label = UiKit.display_label(RARITY_WORDS[rarity], ROW_SIZE, false)
	rarity_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rarity_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	if rarity == MachinePrize.Rarity.RARE:
		rarity_label.add_theme_color_override("font_color", Palette.TEAL_SHADE)
	elif rarity == MachinePrize.Rarity.LEGENDARY:
		rarity_label.add_theme_color_override("font_color", Palette.MUSTARD_DARKEST)
	row.add_child(rarity_label)
	var share: String = pct(odds.rarity_share[rarity])
	var percent: Label = UiKit.number_label(share, PERCENT_SIZE, false)
	row.add_child(percent)
	_column.add_child(row)
	_lines.append("%s  %s per drop" % [RARITY_NAMES[rarity], share])
	var prizes: RichTextLabel = RichTextLabel.new()
	prizes.bbcode_enabled = true
	prizes.fit_content = true
	prizes.scroll_active = false
	prizes.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	prizes.mouse_filter = Control.MOUSE_FILTER_IGNORE
	prizes.custom_minimum_size = Vector2(WIDTH - 2.0 * PAD, 0)
	prizes.add_theme_font_override("normal_font", ArtStyle.bold_font(LINE_WEIGHT))
	prizes.add_theme_font_override("bold_font", ArtStyle.bold_font(BOLD_WEIGHT))
	prizes.add_theme_font_size_override("normal_font_size", LINE_SIZE)
	prizes.add_theme_font_size_override("bold_font_size", LINE_SIZE)
	prizes.add_theme_color_override("default_color", Palette.INK_LIGHT)
	prizes.text = _prize_line(odds, rarity, names)
	_column.add_child(prizes)
	_lines.append(prizes.get_parsed_text())


## "3 prizes, you keep 1 · next visit here: a / b / c", "· REGULAR max", or "· no later visit uses
## REGULAR".
func _next_text(info: MachineChuteInfo) -> String:
	var lead: String = "%d prizes, you keep 1" % _prizes()
	if info.odds.meter_rises:
		return "%s · next visit here: %s" % [lead, _shares_text(info.odds.next_rarity_share)]
	if info.level >= info.max_level:
		return "%s · REGULAR max" % lead
	return "%s · no later visit uses REGULAR" % lead


static func _shares_text(shares: PackedFloat64Array) -> String:
	var parts: PackedStringArray = PackedStringArray()
	for share: float in shares:
		parts.append(pct(share))
	return " / ".join(parts)


## A rarity's prizes with their chance to be in the draw, grouped by equal odds (likeliest
## first); the guarantee's prizes bold (MachineOddsCard.guaranteed, every chute). At most
## MAX_NAMES are named (shown_of), the rest counted as "+k more".
func _prize_line(odds: MachineOddsCard, rarity: int, names: Dictionary) -> String:
	var groups: Dictionary[String, PackedStringArray] = {}
	var chances: Dictionary[String, float] = {}
	var keys: Array[String] = rarity_keys(odds, rarity)
	var named: Array[String] = shown_of(odds, keys)
	for key: String in named:
		var chance: String = pct(float(odds.in_draw[key]))
		if not groups.has(chance):
			groups[chance] = PackedStringArray()
			chances[chance] = float(odds.in_draw[key])
		var shown: String = String(names.get(key, key.get_slice(":", 1))).replace("[", "(")
		if odds.guaranteed.has(key):
			shown = "[b]%s[/b]" % shown
		groups[chance].append(shown)
	if groups.is_empty():
		return "none in your stock"
	var order: Array[String] = []
	order.assign(groups.keys())
	order.sort_custom(func(a: String, b: String) -> bool: return chances[a] > chances[b])
	var parts: PackedStringArray = PackedStringArray()
	for chance: String in order:
		var each: String = " each" if groups[chance].size() > 1 else ""
		parts.append("%s [b]%s[/b]%s" % [", ".join(groups[chance]), chance, each])
	if keys.size() > named.size():
		parts.append(MORE % (keys.size() - named.size()))
	return " · ".join(parts)


## `rarity`'s prize keys in the draw, likeliest first (ties by key, so the order is stable).
static func rarity_keys(odds: MachineOddsCard, rarity: int) -> Array[String]:
	var keys: Array[String] = []
	for key: String in odds.in_draw:
		if int(key.get_slice(":", 2)) == rarity:
			keys.append(key)
	keys.sort_custom(
		func(a: String, b: String) -> bool:
			var chance_a: float = float(odds.in_draw[a])
			var chance_b: float = float(odds.in_draw[b])
			return chance_a > chance_b if chance_a != chance_b else a < b
	)
	return keys


## The keys a row names (MAX_NAMES at most): the guarantee's first, then the likeliest, in
## `keys`' order.
static func shown_of(odds: MachineOddsCard, keys: Array[String]) -> Array[String]:
	if keys.size() <= MAX_NAMES:
		return keys.duplicate()
	var picked: Dictionary[String, bool] = {}
	for key: String in keys:
		if picked.size() < MAX_NAMES and odds.guaranteed.has(key):
			picked[key] = true
	for key: String in keys:
		if picked.size() < MAX_NAMES:
			picked[key] = true
	var shown: Array[String] = []
	for key: String in keys:
		if picked.has(key):
			shown.append(key)
	return shown


## A share as look F prints it: to 0.1 %, without a trailing ".0" ("33.3%", "40%", "0.4%"); a
## share above 0 that would print 0 reads "<0.1%".
static func pct(share: float) -> String:
	if share > 0.0 and share < SMALLEST:
		return "<0.1%"
	var text: String = "%.1f" % (roundf(share * 1000.0) / 10.0)
	if text.ends_with(".0"):
		text = text.left(-2)
	return text + "%"


func _add_line(text: String, color: Color, font_size: int, weight: int) -> void:
	var label: Label = _plain(text, color, font_size, weight)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.custom_minimum_size = Vector2(WIDTH - 2.0 * PAD, 0)
	_column.add_child(label)
	_lines.append(text)


func _plain(text: String, color: Color, font_size: int, weight: int) -> Label:
	var label: Label = UiKit.body_label(text, font_size, color)
	label.add_theme_font_override("font", ArtStyle.bold_font(weight))
	return label


## A dashed cream-shade rule between the header, the rows and the notes.
func _add_rule() -> void:
	var rule: Control = Control.new()
	rule.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rule.custom_minimum_size = Vector2(WIDTH - 2.0 * PAD, 4)
	rule.draw.connect(
		func() -> void:
			for x: int in range(0, int(rule.size.x), 8):
				rule.draw_rect(Rect2(x, 1, 4, 2), Palette.CREAM_SHADE)
	)
	_column.add_child(rule)


func _button(
	text: String, action: Callable, sound: String, colour: Color, pressed_colour: Color
) -> Button:
	var button: Button = UiKit.button(_buttons, text, action, BUTTON_SIZE, sound)
	button.add_theme_font_override("font", ArtStyle.DISPLAY_FONT)
	for state: String in ["normal", "hover", "pressed", "focus"]:
		var style: StyleBoxFlat = StyleBoxFlat.new()
		style.bg_color = colour if state != "pressed" else pressed_colour
		if state == "focus":
			style.draw_center = false
		style.border_color = Palette.INK
		style.set_border_width_all(2)
		button.add_theme_stylebox_override(state, style)
	for key: String in ["font_color", "font_hover_color", "font_pressed_color"]:
		button.add_theme_color_override(key, Palette.INK)
	return button


func _collect_labels(node: Node, found: Array[Control]) -> void:
	for child: Node in node.get_children():
		if child is Label or child is RichTextLabel:
			found.append(child as Control)
		_collect_labels(child, found)


func _tail_y() -> float:
	var at: float = TAIL_AT - top_for(size.y)
	return clampf(at, TAIL_HALF + BORDER * 2.0, maxf(TAIL_HALF + BORDER * 2.0, size.y - 24.0))


static func _draw_holes(holes: Control, punched: int, top: int) -> void:
	for index: int in range(top):
		var rect: Rect2 = Rect2(index * (HOLE + HOLE_GAP), 0, HOLE, HOLE)
		if index < punched:
			holes.draw_rect(rect, Palette.STEEL_DARK)
			holes.draw_rect(rect.grow(-1.0), Palette.INK, false, 2.0)
		else:
			holes.draw_rect(rect.grow(-1.0), Palette.GREY, false, 2.0)


## The card: its shadow, the paper with an ink border and a mustard-light rim, and the tail.
func _draw() -> void:
	var rect: Rect2 = Rect2(Vector2.ZERO, size)
	draw_rect(Rect2(Vector2.ONE * SHADOW, size), Palette.TEAL_BLACK)
	draw_rect(rect, Palette.PAPER)
	draw_rect(rect.grow(-BORDER - 1.0), Palette.MUSTARD_LIGHT, false, 2.0)
	draw_rect(rect.grow(-BORDER / 2.0), Palette.INK, false, BORDER)
	var y: float = _tail_y()
	var outer: PackedVector2Array = PackedVector2Array(
		[
			Vector2(size.x - BORDER, y - TAIL_HALF),
			Vector2(size.x + TAIL_LENGTH, y),
			Vector2(size.x - BORDER, y + TAIL_HALF)
		]
	)
	draw_colored_polygon(outer, Palette.INK)
	var inner: PackedVector2Array = PackedVector2Array(
		[
			Vector2(size.x - BORDER, y - TAIL_HALF + 4.0),
			Vector2(size.x + TAIL_LENGTH - 7.0, y),
			Vector2(size.x - BORDER, y + TAIL_HALF - 4.0)
		]
	)
	draw_colored_polygon(inner, Palette.PAPER)
