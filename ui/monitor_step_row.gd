class_name MonitorStepRow
extends RefCounted
## One row of the monitor item column's applied effects (PR #138 monitor, mock-up
## monitor_codex.png; MonitorItemColumn): its source's icon (the giver's or its own mini, an
## upgrade's icon, an event's badge; the fizzle icon), its readable name and its amount (said
## once, MonitorText.row_parts) right-aligned in one column (AMOUNT_MIN wide): a bonus ("+6€")
## name and amount in green (PR #138 round 2; round 6: its name too), a factor ("×2") in its
## strength's ink (factor_step, PR #138 round 3: the higher, the hotter) under a teal name, its
## digits ending where the euro amounts' digits end (round 6: the "€" column left to the euros), a
## harmful row's (a factor under ×1 or a minus amount too) name and amount in tomato with its sign
## kept and a "!" when it has no icon, a fizzle's reason in tomato with WASTED, a "gives" row (what
## it gives another item, not its own payout; PR #138 round 7: "to Banana  ×2", under the
## target's mini) its name teal and its amount in its effect's ink (a factor's, a bonus's green),
## unbracketed, its equation ("5€ × 2 = 10€", v1.11) on a line of its own under its name,
## indented as part of that effect (EQUATION_INDENT, muted). A row cut past its lines shows its
## whole line in a tip. A count row whose giver is already in the bag (v1.11) shows the bag glyph
## (BAG_ICON) beside the giver's icon, the words in its tip, so its line keeps its room for the
## name and the amount. Pure makers: no state.

## A row's look: a FIZZLE's and a HARM's (CountUpPlan.is_harmful) text and amount are tomato, a
## HARM's amount keeping its sign ("−2€") so the meaning never rests on colour alone.
enum Tone { PLAIN, FIZZLE, HARM }

## A row's line: ROW_PITCH px, its text at the first of ROW_SIZES that fits on one line, at most
## MAX_LINES lines.
const ROW_PITCH := 16.0
const ROW_SIZES: Array[int] = [13, 12]
const ROW_WEIGHT := 800
const MAX_LINES := 2
const AMOUNT_SIZE := 14
const AMOUNT_WEIGHT := 800
const AMOUNT_MIN := 40.0
const AMOUNT_PAD := 6.0
## The amount's top against its row's (its size is a px bigger than the text's).
const AMOUNT_RISE := -1.0
const MARK_SIZE := Vector2(14, 14)
const MARK_GAP := 5.0
const HARM_MARK := "!"
const GIVE_MARK := "✦"
const GIVE_FALLBACK := "›"
const TEXT_COLOR := Palette.TEAL_DARK
const NOTE_COLOR := Palette.INK_LIGHT
## A bonus's amount (PR #138 round 2: the user's green, GREEN_DARK reads 4.8:1 on the paper), and
## a harmful or unused row's.
const BONUS_COLOR := Palette.GREEN_DARK
const HARM_COLOR := Palette.TOMATO_DARK
## A factor's strength (PR #138 round 3, the user's "higher multiplier, stronger colour"; round 4:
## colour only, never a box): its step is how many of FACTOR_STEPS it reaches (×1.5: 0, ×2: 1, ×3
## and ×4: 2, ×5 and up: 3), its ink FACTOR_INKS[step] = [ink, shadow], a heat ramp on the text
## itself (art palette inks only), every ink at least 4.5:1 on the monitor's paper: mustard
## darkest (5.9:1), orange dark (5.1:1), orange dark again but heavier on a mustard light shadow,
## then velvet on a gold shadow (8.4:1, the strongest). A transparent shadow draws none. None is
## the bonuses' green; a factor under ×1 (it lowers the pay) is harmful: HARM_COLOR text with no
## shadow, so the strong factors (shadowed, darker) and the harmful ones (flat tomato) differ in
## form, not only in hue.
const FACTOR_STEPS: Array[float] = [2.0, 3.0, 5.0]
const FACTOR_INKS: Array[Array] = [
	[Palette.MUSTARD_DARKEST, Color.TRANSPARENT],
	[Palette.ORANGE_DARK, Color.TRANSPARENT],
	[Palette.ORANGE_DARK, Palette.MUSTARD_LIGHT],
	[Palette.VELVET, Palette.GOLD],
]
const FACTOR_SIGN := "×"
## The shadow's offset (px).
const FACTOR_SHADOW := Vector2i(1, 1)
const FIZZLE_ICON := preload("res://art/icons/fizzle.png")
## The euro sign every euro amount ends with: a factor's digits end its width short of the amount
## column's right edge (PR #138 round 6, the user's "multiplier should be aligned with other
## number"), so every number's digits share one right edge.
const EURO := "€"
## A "gives" row's equation line under its name (v1.11): indented EQUATION_INDENT past the name's
## left edge, at EQUATION_SIZE and EQUATION_WEIGHT in NOTE_COLOR.
const EQUATION_INDENT := 10.0
const EQUATION_SIZE := 12
const EQUATION_WEIGHT := 700
## The bag glyph (v1.11, the user's "a small bag glyph beside the giver and put the wording in its
## tooltip"): BAG_SIZE, BAG_GAP after the giver's icon, the name moving that much right; its tip
## BAG_TIP with the giver's name, else BAG_TIP_UNNAMED.
const BAG_ICON := preload("res://art/icons/from_bag.png")
const BAG_SIZE := Vector2(14, 14)
const BAG_GAP := 2.0
const BAG_TIP := "From the bag: %s is already bagged and still gives this"
const BAG_TIP_UNNAMED := "From the bag: its giver is already bagged and still gives this"


## One row `width` px wide (see the class comment), in no parent yet, at most `max_lines` lines
## (each ROW_PITCH) and its `equation`'s line under them ("" for none), with the bag glyph and its
## `bag_tip` beside the mark ("" for none; bag_tip_of), or null for an empty line.
static func make(
	line: String,
	tone: Tone,
	gives: bool,
	giver_mini: Texture2D,
	max_lines: int,
	width: float,
	equation: String = "",
	bag_tip: String = ""
) -> Control:
	if line.is_empty():
		return null
	var parts: PackedStringArray = MonitorText.row_parts(line)
	var colour: Color = name_colour_of(parts[1], tone, gives)
	var row: Control = Control.new()
	row.name = "Step"
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.set_meta(&"line", line)
	var mark: Control = _mark(tone, gives, giver_mini)
	mark.name = "Mark"
	row.add_child(mark)
	var indent: float = MARK_SIZE.x + MARK_GAP
	if not bag_tip.is_empty():
		var bag: TipTarget = _bag(bag_tip)
		bag.position = Vector2(MARK_SIZE.x + BAG_GAP, roundf((ROW_PITCH - BAG_SIZE.y) / 2.0))
		row.add_child(bag)
		indent += BAG_SIZE.x + BAG_GAP
	var amount_width: float = 0.0
	var inset: float = 0.0
	var amount: Label = null
	if not parts[1].is_empty():
		var amount_colour: Color = amount_colour_of(parts[1], tone)
		amount = MonitorKit.bold(parts[1], AMOUNT_SIZE, AMOUNT_WEIGHT, amount_colour, ROW_PITCH)
		amount.name = "Amount"
		amount.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		# Level with a text line (from its top; placed on the last line below).
		amount.custom_minimum_size = Vector2.ZERO
		amount.vertical_alignment = VERTICAL_ALIGNMENT_TOP
		row.add_child(amount)
		if not gives and tone == Tone.PLAIN:
			_ink_factor(amount, factor_step(parts[1]))
		var least: float = 0.0 if tone == Tone.FIZZLE else AMOUNT_MIN
		var shown_width: float = maxf(text_width(amount), amount.get_minimum_size().x)
		inset = amount_inset(parts[1])
		amount_width = maxf(least, ceilf(shown_width) + inset) + AMOUNT_PAD
	var room: float = width - indent - amount_width
	var text: Label = row_text(parts[0], colour, room, max_lines)
	row.add_child(text)
	text.position = Vector2(indent, 0)
	var wrapped: int = lines_of(text, room)
	var lines: int = clampi(wrapped, 1, max_lines)
	var height: float = lines * ROW_PITCH
	text.size = Vector2(room, height)
	if not equation.is_empty():
		row.add_child(_equation(equation, indent, width, height))
		height += ROW_PITCH
	if wrapped > max_lines:
		# Cut with an ellipsis: resting the pointer on the text shows the whole line (#138 review).
		var whole: TipTarget = TipTarget.new()
		whole.name = "WholeLine"
		whole.tip_text = line
		whole.tip_below = true
		whole.position = text.position
		whole.size = text.size
		row.add_child(whole)
	mark.position = Vector2(0, roundf((ROW_PITCH - mark.size.y) / 2.0))
	if amount != null:
		# On the text's last line (PR #138 round 5), so the dotted leader runs from the name to it.
		amount.position = Vector2(
			width - amount_width + AMOUNT_PAD, (lines - 1) * ROW_PITCH + AMOUNT_RISE
		)
		amount.size = Vector2(amount_width - AMOUNT_PAD - inset, ROW_PITCH)
	row.size = Vector2(width, height)
	return row


## Planning's rows in their order (MonitorItemColumn.show_item): the "gives" rows (`given`) before
## the item's `own` rows, or after them when `gives_last` (v1.11), then the `unused` ones (fizzles,
## which change no amount).
static func in_order(
	own: Array[Control], given: Array[Control], unused: Array[Control], gives_last: bool
) -> Array[Control]:
	var ordered: Array[Control] = []
	ordered.append_array(own if gives_last else given)
	ordered.append_array(given if gives_last else own)
	ordered.append_array(unused)
	return ordered


## How many lines (each ROW_PITCH) `rows` take in all (x) and the tallest one's (y).
static func rows_lines(rows: Array[Control]) -> Vector2i:
	var counted: Vector2i = Vector2i.ZERO
	for row: Control in rows:
		var row_lines: int = roundi(row.size.y / ROW_PITCH)
		counted.x += row_lines
		counted.y = maxi(counted.y, row_lines)
	return counted


## The bag glyph's tip for a giver named `giver` ("" when unknown).
static func bag_tip_of(giver: String) -> String:
	return BAG_TIP % giver if not giver.is_empty() else BAG_TIP_UNNAMED


## The bag glyph (BAG_ICON at BAG_SIZE) with `tip` as its tooltip.
static func _bag(tip: String) -> TipTarget:
	var bag: TipTarget = TipTarget.new()
	bag.name = "FromBag"
	bag.texture = BAG_ICON
	bag.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	bag.stretch_mode = TextureRect.STRETCH_SCALE
	ArtStyle.use_pixel_material(bag)
	bag.size = BAG_SIZE
	bag.tip_text = tip
	bag.tip_below = true
	# Its row shows only during the count, which blocks the other tips (GlyphTips).
	bag.shows_while_blocked = true
	return bag


## A "gives" row's `equation` line (see EQUATION_INDENT) at `top`, under a name that starts at
## `indent` in a row `width` px wide.
static func _equation(equation: String, indent: float, width: float, top: float) -> Label:
	var label: Label = MonitorKit.bold(
		equation, EQUATION_SIZE, EQUATION_WEIGHT, NOTE_COLOR, ROW_PITCH
	)
	label.name = "Equation"
	label.custom_minimum_size = Vector2.ZERO
	label.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	label.clip_text = true
	label.position = Vector2(indent + EQUATION_INDENT, top)
	label.size = Vector2(width - indent - EQUATION_INDENT, ROW_PITCH)
	return label


## A muted note row `width` px wide (a hand item's), wrapped like a step's text.
static func note(text: String, width: float) -> Control:
	var row: Control = Control.new()
	row.name = "Note"
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.set_meta(&"line", text)
	var label: Label = row_text(text, NOTE_COLOR, width, MAX_LINES)
	row.add_child(label)
	var height: float = clampi(lines_of(label, width), 1, MAX_LINES) * ROW_PITCH
	label.size = Vector2(width, height)
	row.size = Vector2(width, height)
	return row


## A row's text in `room` px: one line at the first of ROW_SIZES that fits, else wrapped on up to
## `max_lines` lines at the smallest (an ellipsis only past them; the row's meta keeps it whole).
static func row_text(text: String, colour: Color, room: float, max_lines: int) -> Label:
	var font: Font = ArtStyle.bold_font(ROW_WEIGHT)
	var font_size: int = ROW_SIZES[-1]
	for size_at: int in ROW_SIZES:
		if font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size_at).x <= room:
			font_size = size_at
			break
	var label: Label = MonitorKit.bold(text, font_size, ROW_WEIGHT, colour, ROW_PITCH)
	label.name = "Text"
	label.custom_minimum_size = Vector2.ZERO
	label.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	label.add_theme_constant_override("line_spacing", int(ROW_PITCH - font.get_height(font_size)))
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.max_lines_visible = max_lines
	label.text_overrun_behavior = TextServer.OVERRUN_TRIM_WORD_ELLIPSIS
	label.size = Vector2(room, ROW_PITCH * max_lines)
	return label


## How many lines `label`'s text wraps to in `room` px, in its own font and size.
static func lines_of(label: Label, room: float) -> int:
	var font: Font = label.get_theme_font("font")
	var font_size: int = label.get_theme_font_size("font_size")
	var width: float = font.get_string_size(label.text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	if width <= room:
		return 1
	var wrapped: Vector2 = font.get_multiline_string_size(
		label.text, HORIZONTAL_ALIGNMENT_LEFT, room, font_size
	)
	return maxi(roundi(wrapped.y / font.get_height(font_size)), 1)


## An amount's colour: tomato (a fizzle's, a harmful row's, a factor under ×1, a minus amount), a
## factor's strength's ink ("×3", factor_ink), green (a bonus, "+6€"), else ink.
static func amount_colour_of(amount: String, tone: Tone) -> Color:
	if tone != Tone.PLAIN or lowers(amount):
		return HARM_COLOR
	if amount.begins_with(FACTOR_SIGN):
		return factor_ink(factor_step(amount))
	return BONUS_COLOR if amount.begins_with("+") else Palette.INK


## A row's name's colour (PR #138 round 6, the user's "positive bonus ... names in green and
## negative in red"): a "gives" row's teal (its amount is someone else's); a fizzle's, a harmful
## row's and one whose `amount` lowers the pay (lowers) tomato, as their amount; a bonus's ("+6€")
## green, as its amount; else (a factor of ×1 or more, a row with no amount) teal.
static func name_colour_of(amount: String, tone: Tone, gives: bool) -> Color:
	if gives:
		return TEXT_COLOR
	if tone != Tone.PLAIN or lowers(amount):
		return HARM_COLOR
	return BONUS_COLOR if amount.begins_with("+") else TEXT_COLOR


## Whether `amount` lowers the pay: a minus amount ("−2€") or a factor under ×1 ("×0.5").
static func lowers(amount: String) -> bool:
	if amount.begins_with("−") or amount.begins_with("-"):
		return true
	return amount.begins_with(FACTOR_SIGN) and factor_step(amount) < 0


## How far `amount`'s box ends inside the amount column's right edge (PR #138 round 6, the user's
## "multiplier should be aligned with other number"): a factor's (no euro sign) the euro sign's
## width at the amounts' size (whole px, as the text sets it), so its digits end where the euro
## amounts' digits end; any other amount's (a euro amount, WASTED) none: their ink ends on the edge.
static func amount_inset(amount: String) -> float:
	if not amount.begins_with(FACTOR_SIGN):
		return 0.0
	var font: Font = ArtStyle.bold_font(AMOUNT_WEIGHT)
	return roundf(font.get_string_size(EURO, HORIZONTAL_ALIGNMENT_LEFT, -1, AMOUNT_SIZE).x)


## A factor amount's strength step ("×3": how many of FACTOR_STEPS it reaches, 0 to
## FACTOR_INKS.size() - 1); -1 under ×1 (it lowers the pay) or for an amount that is no factor.
static func factor_step(amount: String) -> int:
	if not amount.begins_with(FACTOR_SIGN):
		return -1
	var factor: float = amount.substr(FACTOR_SIGN.length()).strip_edges().to_float()
	if factor < 1.0:
		return -1
	var step: int = 0
	for threshold: float in FACTOR_STEPS:
		if factor >= threshold:
			step += 1
	return mini(step, FACTOR_INKS.size() - 1)


## A factor step's ink and its shadow (transparent: none).
static func factor_ink(step: int) -> Color:
	return FACTOR_INKS[clampi(step, 0, FACTOR_INKS.size() - 1)][0]


static func factor_shadow(step: int) -> Color:
	return FACTOR_INKS[clampi(step, 0, FACTOR_INKS.size() - 1)][1]


## A factor's `amount` label at its strength `step` (none: -1): its shadow.
static func _ink_factor(amount: Label, step: int) -> void:
	if step < 0:
		return
	var shadow: Color = factor_shadow(step)
	if shadow.a > 0.0:
		amount.add_theme_color_override("font_shadow_color", shadow)
		amount.add_theme_constant_override("shadow_offset_x", FACTOR_SHADOW.x)
		amount.add_theme_constant_override("shadow_offset_y", FACTOR_SHADOW.y)
		amount.add_theme_constant_override("shadow_outline_size", 0)


## A row's tone: a fizzle's, else a harmful row's, else plain.
static func tone_of(fizzle: bool, harmful: bool) -> Tone:
	return Tone.FIZZLE if fizzle else (Tone.HARM if harmful else Tone.PLAIN)


## Every row's text in `rows` at one size, the smallest any of them took (row_text), so the rows
## of one page read evenly (PR #138 round 2 review). Only ever shrinks a one-line text, which
## then still fits on its line, so no row's height changes.
static func even_sizes(rows: Array) -> void:
	var texts: Array[Label] = []
	var least: int = ROW_SIZES[0]
	for row: Control in rows:
		var text: Label = row.get_node_or_null("Text") as Label
		if text != null:
			texts.append(text)
			least = mini(least, text.get_theme_font_size("font_size"))
	var font: Font = ArtStyle.bold_font(ROW_WEIGHT)
	for text: Label in texts:
		text.add_theme_font_size_override("font_size", least)
		text.add_theme_constant_override("line_spacing", int(ROW_PITCH - font.get_height(least)))


## `label`'s text width on one line, in its own font and size.
static func text_width(label: Label) -> float:
	var font: Font = label.get_theme_font("font")
	var font_size: int = label.get_theme_font_size("font_size")
	return ceilf(font.get_string_size(label.text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x)


## A row's mark: the fizzle icon, the source's icon, ✦ ("gives"), a tomato ! (harmful), or none.
static func _mark(tone: Tone, gives: bool, giver_mini: Texture2D) -> Control:
	var texture: Texture2D = FIZZLE_ICON if tone == Tone.FIZZLE else giver_mini
	if texture != null:
		var icon: TextureRect = UiKit.sprite(texture)
		icon.size = MARK_SIZE
		return icon
	var font: Font = MachineDisplay.marked_font(800)
	var text: String = ""
	var colour: Color = HARM_COLOR
	if gives:
		text = GIVE_MARK if font.has_char(GIVE_MARK.unicode_at(0)) else GIVE_FALLBACK
		colour = Palette.MUSTARD_DARK
	elif tone == Tone.HARM:
		text = HARM_MARK
	var label: Label = MonitorKit.bold(text, ROW_SIZES[0], 800, colour, MARK_SIZE.y)
	label.add_theme_font_override("font", font)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.size = MARK_SIZE
	return label
