class_name MonitorItemColumn
extends Control
## The monitor's item column (#105 piece 2, mock-up readability_v3.html, monitor b), right of
## the scanner bay across the rest of the paper (MonitorView.ITEM_RECT; the spend objective is
## the register's and the top bar's since Checkout Rhythm v3): the item in the bay, read in full.
## From the top: its name (ItemName: Pixelify at 22 px, or the bold body font when too long)
## with its family glyphs after it (FamilyPalette.shelf_families, their names on hover); its price
## top right in the monitor's "€N" tag style (PayTag: a gold burst over the struck old price once
## the price differs from the base, a cream tag at the base, a tomato €0 tag); its effect text
## (the sticker summary, or the rule text: GlyphLabel, bold at EFFECT_SIZE on EFFECT_PITCH, kept
## clear of the price); a dashed rule; and its step lines (STEPS_TOP down), each with its mark (the
## fizzle icon, a giver's mini, ✦ for a "gives" line, ✓ for its own), its text, and its amount in
## one right-aligned column (AMOUNT_MIN wide) level with the text's first line; lines that don't
## fit fold into "+N more".
##
## In planning (show_item) it shows belt slot 1's item or the held one with every step line; on an
## empty belt a muted hint (show_empty). In the count (start_item, set_value, show_step) the item
## comes in at its base price with no line; each of its landings moves the price (punching it) and
## retains its bonus lines in the wider column, folding only earlier overflow. The last item
## stays at the count's end.
## When the item changes its parts fade in one after another (CountTotalTuning's part_delays and
## part_fade_s; at once under reduced motion). Display only: the prices and lines are the
## caller's (the score's).

const SIZE := Vector2(270, 146)
const COUNT_SIZE := Vector2(270, 146)
const COUNT_RULE_TOP := 48.0
const COUNT_STEPS_TOP := 54.0
const COUNT_LINE_HEIGHT := 18.0
const COUNT_ROWS := 5
const NAME_HEIGHT := 26.0
const NAME_GLYPH_GAP := 4.0
const GLYPH_GAP := 3.0
## The price: a burst's or tag's right edge and its middle's height (a 32 px burst's top at 30),
## and the struck old price's right edge and top under it.
const PRICE_RIGHT := 270.0
const PRICE_MIDDLE := 46.0
const STRUCK_RIGHT := 264.0
const STRUCK_TOP := 64.0
## The effect text, kept EFFECT_GAP clear of the price, on at most EFFECT_LINES lines at the first
## of EFFECT_TIERS (size, pitch) that fits.
const EFFECT_TOP := 32.0
const EFFECT_GAP := 4.0
const EFFECT_WEIGHT := 800
const EFFECT_TIERS: Array[Vector2i] = [Vector2i(16, 19), Vector2i(14, 17), Vector2i(13, 15)]
const EFFECT_BOTTOM := 82.0
## The dashed rule (DASH on, DASH off) and the step lines under it.
const RULE_TOP := 84.0
const RULE_WIDTH := 268.0
const RULE_HEIGHT := 2.0
const DASH := 4.0
const RULE_COLOR := Palette.CREAM_SHADE
const STEPS_TOP := 90.0
const STEPS_WIDTH := 268.0
const STEP_GAP := 2.0
const STEP_SIZE := 14
const STEP_WEIGHT := 700
const COUNT_STEP_SIZE := 15
const COUNT_STEP_WEIGHT := 800
## A count line too long for 2 lines at COUNT_STEP_SIZE: this size, on up to this many lines (the
## step area's 56 px).
const COUNT_STEP_SMALL_SIZE := 13
const COUNT_STEP_SMALL_LINES := 3
const AMOUNT_WEIGHT := 800
const AMOUNT_MIN := 40.0
const AMOUNT_PAD := 6.0
const MARK_SIZE := Vector2(14, 14)
const MARK_GAP := 4.0
const CHECK_MARK := "✓"
const GIVE_MARK := "✦"
const GIVE_FALLBACK := "›"
const MORE_TEXT := "+%d more"
const MORE_HEIGHT := 18.0
## A step line wraps to at most this many lines; the rest ends in an ellipsis (its whole line stays
## its meta "line").
const STEP_MAX_LINES := 2
const FIZZLE_ICON := preload("res://art/icons/fizzle.png")
## The empty belt's hint: its size, weight and colour, centred in the column.
const HINT_SIZE := 15
const HINT_WEIGHT := 800
const HINT_COLOR := Palette.INK_LIGHT

## Returns a new Tween on the count's clock (the count's parts); none: the column's own.
var make_tween: Callable = Callable()
## Returns true when the player asked for reduced motion. None means false.
var reduced_motion: Callable = Callable()

var _tuning: CountTotalTuning
var _definition: CardDefinition
var _name: Control
var _glyphs: Array[FamilyGlyph] = []
var _price: PayTag
var _price_holder: Control
var _struck: PriceSticker.StruckPrice
var _effect: GlyphLabel
var _rule: Control
var _steps: Control
var _rows: Array[Control] = []
var _shown_value: int = -1
var _fades: Array[Tween] = []
var _punch: Tween
var _counting: bool = false
var _count_lines: Array[Dictionary] = []


func _init(tuning: CountTotalTuning = null) -> void:
	name = "ItemColumn"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	size = SIZE
	_tuning = tuning if tuning != null else load(CountUpPlan.TOTAL_TUNING_PATH) as CountTotalTuning
	_price_holder = _part("Price")
	_rule = _part("Rule")
	_rule.position = Vector2(0, RULE_TOP)
	_rule.size = Vector2(RULE_WIDTH, RULE_HEIGHT)
	_rule.draw.connect(_draw_rule)
	_steps = _part("Steps")
	_steps.position = Vector2(0, STEPS_TOP)
	_steps.size = Vector2(STEPS_WIDTH, SIZE.y - STEPS_TOP)


## Planning: `definition` (with its `tags`) at `payout` (-1 for a hand item: its base price) and
## its step `lines` (each with whether it is a fizzle, `fizzles`; the first `gives` are "gives"
## lines; `minis` the giver's mini for each, or null). `animate`: its parts fade in. Call it in
## the tree: the text is measured with the real font.
func show_item(
	definition: CardDefinition,
	tags: PackedStringArray,
	payout: int,
	lines: PackedStringArray,
	fizzles: Array[bool],
	gives: int = 0,
	minis: Array[Texture2D] = [],
	animate: bool = false
) -> void:
	_counting = false
	_layout_mode()
	_build_head(definition, tags)
	var base: int = _base_of(definition)
	_set_price(payout if payout >= 0 else base, base, fizzles.has(true), false)
	_fill_steps(lines, fizzles, gives, minis)
	_fade_in(animate)


## The count: `definition` comes into the bay at its base price, with no step line yet; its parts
## fade in (`animate`) or show at once.
func start_item(definition: CardDefinition, tags: PackedStringArray, animate: bool = true) -> void:
	_counting = true
	_layout_mode()
	_build_head(definition, tags)
	_set_price(_base_of(definition), _base_of(definition), false, false)
	_clear_steps()
	_fade_in(animate)


## Planning's empty belt: `text` (MonitorText.EMPTY_BELT), muted and centred, and nothing else.
func show_empty(text: String) -> void:
	var shown: Label = _hint()
	if shown != null and shown.text == text and _definition == null:
		return
	clear()
	_counting = false
	_layout_mode()
	var label: Label = MonitorKit.bold(text, HINT_SIZE, HINT_WEIGHT, HINT_COLOR, SIZE.y)
	label.name = "Hint"
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.size = SIZE
	add_child(label)
	label.position = Vector2.ZERO
	# Twice: the first sizes its wrap width, the second its height at that width.
	label.size = SIZE
	label.size = SIZE


## The empty belt's hint shown now, or null.
func _hint() -> Label:
	return get_node_or_null("Hint") as Label


## The step lines whose bottom runs past `bottom` (global) go (the end state's INSPECTION PASSED
## line under them).
func drop_steps_past(bottom: float) -> void:
	for row: Control in _rows.duplicate():
		if row.get_global_rect().end.y > bottom + 0.5:
			_rows.erase(row)
			_steps.remove_child(row)
			row.queue_free()


## The count: the item's price is now `value` (a landing on it), punching when it changed.
func set_value(value: int, fizzled: bool = false) -> void:
	if _definition == null:
		return
	_set_price(value, _base_of(_definition), fizzled, value != _shown_value)


## The count: the item's newest step `line` (a fizzle's, a "gives" line, with its giver's
## `giver_mini`) replaces the last, bigger, fading in.
func show_step(
	line: String,
	fizzle: bool,
	gives: bool = false,
	giver_mini: Texture2D = null,
	from_bag: bool = false
) -> void:
	if line.is_empty():
		return
	_count_lines.append(
		{"line": line, "fizzle": fizzle, "gives": gives, "mini": giver_mini, "bag": from_bag}
	)
	_clear_steps()
	var first: int = (
		maxi(0, _count_lines.size() - COUNT_ROWS + 1) if _count_lines.size() > COUNT_ROWS else 0
	)
	var top: float = 0.0
	if first > 0:
		var folded: Label = MonitorKit.bold(
			"+%d earlier" % first, 12, 700, Palette.INK_LIGHT, COUNT_LINE_HEIGHT
		)
		folded.set_meta(&"line", folded.text)
		folded.size = Vector2(_steps.size.x, COUNT_LINE_HEIGHT)
		_steps.add_child(folded)
		_rows.append(folded)
		top += COUNT_LINE_HEIGHT
	for index: int in range(first, _count_lines.size()):
		var entry: Dictionary = _count_lines[index]
		var row: Control = _add_row(
			entry["line"],
			entry["fizzle"],
			entry["gives"],
			entry["mini"] as Texture2D,
			12 if bool(entry["fizzle"]) else 13,
			800,
			top,
			1
		)
		if row == null:
			continue
		if bool(entry["bag"]):
			var text: Label = row.get_node("Text") as Label
			text.text += " · from the bag"
		row.set_meta(&"from_bag", bool(entry["bag"]))
		row.size.y = COUNT_LINE_HEIGHT
		for child: Node in row.get_children():
			var part: Control = child as Control
			if part != null:
				part.size.y = minf(part.size.y, COUNT_LINE_HEIGHT)
		top += COUNT_LINE_HEIGHT
	if _rows.is_empty():
		return
	var newest: Control = _rows[-1]
	var highlight: ColorRect = ColorRect.new()
	highlight.color = Palette.MUSTARD_PALE
	highlight.mouse_filter = Control.MOUSE_FILTER_IGNORE
	highlight.size = newest.size
	newest.add_child(highlight)
	newest.move_child(highlight, 0)
	var mark: Control = newest.get_node_or_null("Mark") as Control
	if mark != null and giver_mini != null and not _reduced() and is_inside_tree():
		mark.pivot_offset = mark.size / 2.0
		var pulse: Tween = _new_tween(true)
		pulse.tween_property(mark, "scale", Vector2.ONE * 1.35, 0.08)
		pulse.tween_property(mark, "scale", Vector2.ONE, 0.16)
		_fades.append(pulse)


func _layout_mode() -> void:
	size = COUNT_SIZE if _counting else SIZE
	_rule.position.y = COUNT_RULE_TOP if _counting else RULE_TOP
	_rule.size.x = size.x - 2.0
	_steps.position.y = COUNT_STEPS_TOP if _counting else STEPS_TOP
	_steps.size = Vector2(size.x - 2.0, size.y - _steps.position.y)


## Nothing shown (the bay between items, or empty).
func clear() -> void:
	_definition = null
	_count_lines.clear()
	_shown_value = -1
	_stop_fades()
	for child: Node in get_children():
		if child == _price_holder or child == _rule or child == _steps:
			continue
		remove_child(child)
		child.queue_free()
	_name = null
	_effect = null
	_glyphs.clear()
	_clear_price()
	_clear_steps()
	_rule.visible = false


## The item shown (null for none), its price shown and its parts, for checks and the chips.
func shown_definition() -> CardDefinition:
	return _definition


func shown_value() -> int:
	return _shown_value


func name_control() -> Control:
	return _name


func glyphs() -> Array[FamilyGlyph]:
	return _glyphs


func price_tag() -> PayTag:
	return _price


func struck() -> PriceSticker.StruckPrice:
	return _struck


func effect() -> GlyphLabel:
	return _effect


## The step lines shown (each row: its mark, text and amount), and their texts.
func step_rows() -> Array[Control]:
	return _rows


func step_texts() -> PackedStringArray:
	var texts: PackedStringArray = PackedStringArray()
	for row: Control in _rows:
		texts.append(String(row.get_meta(&"line", "")))
	return texts


## Where the base's chip takes off (global): the price's middle.
func price_point() -> Vector2:
	if _price != null:
		return _price.get_global_rect().get_center()
	return get_global_transform() * Vector2(PRICE_RIGHT - 26.0, PRICE_MIDDLE)


## Where WASTED's grey €0 drops from (global): just under the newest line's amount (the mock-up's
## chip, its top at the word's foot), or under the rule.
func waste_point() -> Vector2:
	if not _rows.is_empty():
		var amount: Control = _rows[-1].get_node_or_null("Amount") as Control
		if amount != null:
			var rect: Rect2 = amount.get_global_rect()
			return Vector2(rect.get_center().x, rect.end.y + CountChips.CHIP_HEIGHT / 2.0)
	return step_point()


## Where a step's chip takes off (global): the newest line's amount, or under the rule.
func step_point() -> Vector2:
	if not _rows.is_empty():
		var amount: Control = _rows[-1].get_node_or_null("Amount") as Control
		if amount != null:
			return amount.get_global_rect().get_center()
	return get_global_transform() * Vector2(156.0, STEPS_TOP + 10.0)


## The name, its glyphs, the price (burst and struck), the effect, the rule and the lines: every
## part shown, with its rect (global), for layout checks.
func part_rects() -> Dictionary[String, Rect2]:
	var rects: Dictionary[String, Rect2] = {}
	if _name != null:
		var name_rect: Rect2 = _name.get_global_rect()
		name_rect.size.x = minf(name_rect.size.x, _name_width(_name))
		rects["name"] = name_rect
	for index: int in range(_glyphs.size()):
		rects["glyph%d" % index] = _glyphs[index].get_global_rect()
	if _price != null:
		# At rest: a landing's punch scales it for item_price_punch_s.
		rects["price"] = Rect2(_price_holder.get_global_transform() * _price.position, _price.size)
	if _struck != null and _struck.visible:
		rects["struck"] = _struck.get_global_rect()
	if _effect != null:
		var effect_rect: Rect2 = _effect.text_rect()
		rects["effect"] = Rect2(
			_effect.get_global_transform() * effect_rect.position, effect_rect.size
		)
	for index: int in range(_rows.size()):
		rects["step%d" % index] = _rows[index].get_global_rect()
	return rects


func _build_head(definition: CardDefinition, tags: PackedStringArray) -> void:
	clear()
	_definition = definition
	_rule.visible = true
	var palette: FamilyPalette = FamilyPalette.shared()
	var shown: PackedStringArray = (
		palette.shelf_families(tags) if definition.is_product() else PackedStringArray()
	)
	for family: String in shown:
		var style: FamilyStyle = palette.style(family)
		if style != null and style.glyph != null:
			_glyphs.append(FamilyGlyph.new(style))
	var glyphs_width: float = 0.0
	if not _glyphs.is_empty():
		glyphs_width = (
			NAME_GLYPH_GAP
			+ _glyphs.size() * ArtStyle.FAMILY_GLYPH_SIZE
			+ (_glyphs.size() - 1) * GLYPH_GAP
		)
	var room: float = size.x - glyphs_width - (86.0 if _counting else 0.0)
	_name = ItemName.make(definition.display_name, room, NAME_HEIGHT, Palette.INK)
	add_child(_name)
	_name.position = Vector2.ZERO
	var x: float = ceilf(minf(_name_width(_name), room)) + NAME_GLYPH_GAP
	for glyph: FamilyGlyph in _glyphs:
		glyph.position = Vector2(x, (NAME_HEIGHT - glyph.size.y) / 2.0)
		add_child(glyph)
		x += glyph.size.x + GLYPH_GAP


## The price at `value` against `base` (see the class comment), and the effect text clear of it.
func _set_price(value: int, base: int, fizzled: bool, punch: bool) -> void:
	var coupon_free: bool = _definition.is_coupon() and value <= 0 and base <= 0
	var pay: PlanningModel.Pay = _pay_of(value, base)
	var text: String = PriceSticker.price_text(value)
	var same: bool = _price != null and _price.text() == text and _price.pay == pay
	_shown_value = value
	if not same:
		_clear_price()
		if not coupon_free:
			var glyph: PlanningModel.Glyph = PlanningModel.Glyph.NONE
			if pay == PlanningModel.Pay.ZERO:
				glyph = PlanningModel.Glyph.FIZZLE if fizzled else PlanningModel.Glyph.WARNING
			_price = PayTag.new(pay, text, glyph)
			_price.position = Vector2(
				size.x - _price.size.x,
				roundf((16.0 if _counting else PRICE_MIDDLE) - _price.size.y / 2.0)
			)
			# A punch grows it leftward from its right edge: it never leaves the column.
			_price.pivot_offset = Vector2(_price.size.x, _price.size.y / 2.0)
			_price_holder.add_child(_price)
			if value != base and not _counting:
				_struck = PriceSticker.StruckPrice.new(PriceSticker.price_text(base), false)
				_struck.position = Vector2(STRUCK_RIGHT - _struck.size.x, STRUCK_TOP)
				_price_holder.add_child(_struck)
		_lay_effect()
	if punch and _price != null and not _reduced() and is_inside_tree():
		_stop(_punch)
		_price.scale = Vector2.ONE * _tuning.item_price_punch
		_punch = _new_tween(_counting)
		_punch.tween_property(_price, "scale", Vector2.ONE, maxf(0.01, _tuning.item_price_punch_s))


## The effect text, wrapped clear of the price, in the first tier that fits above the rule.
func _lay_effect() -> void:
	if _definition == null:
		return
	if _effect != null:
		remove_child(_effect)
		_effect.queue_free()
		_effect = null
	var text: String = _definition.sticker_summary()
	if text.is_empty():
		text = _definition.rule_text
	if text.is_empty():
		return
	if _counting:
		_effect = GlyphLabel.new(
			text, ArtStyle.bold_font(EFFECT_WEIGHT), 13, Palette.INK, 15, size.x - 2.0, 1
		)
		_effect.name = "Effect"
		_effect.position = Vector2(0, 31)
		add_child(_effect)
		return
	var price_left: float = _price.position.x if _price != null else SIZE.x
	if _struck != null:
		price_left = minf(price_left, _struck.position.x)
	var width: float = maxf(40.0, price_left - EFFECT_GAP)
	for tier: int in range(EFFECT_TIERS.size()):
		var sizes: Vector2i = EFFECT_TIERS[tier]
		var lines: int = floori((EFFECT_BOTTOM - EFFECT_TOP) / sizes.y)
		if _effect != null:
			remove_child(_effect)
			_effect.queue_free()
		_effect = GlyphLabel.new(
			text, ArtStyle.bold_font(EFFECT_WEIGHT), sizes.x, Palette.INK, sizes.y, width, lines
		)
		_effect.name = "Effect"
		_effect.position = Vector2(0, EFFECT_TOP)
		add_child(_effect)
		if _effect.fits():
			return


## Every line of `lines` from the top of the steps, folding what doesn't fit into "+N more".
func _fill_steps(
	lines: PackedStringArray, fizzles: Array[bool], gives: int, minis: Array[Texture2D]
) -> void:
	_clear_steps()
	var room: float = _steps.size.y
	var top: float = 0.0
	for index: int in range(lines.size()):
		var giver_mini: Texture2D = minis[index] if index < minis.size() else null
		var fizzle: bool = fizzles[index] if index < fizzles.size() else false
		var row: Control = _add_row(
			lines[index], fizzle, index < gives, giver_mini, STEP_SIZE, STEP_WEIGHT, top
		)
		if row == null:
			continue
		# A row stays when the "+N more" row would still fit under it (or it is the last).
		var reserve: float = 0.0 if index == lines.size() - 1 else MORE_HEIGHT + STEP_GAP
		if row.position.y + row.size.y + reserve > room and _rows.size() == 1:
			# The first line is never folded away: it shows on one line, cut with an ellipsis.
			_rows.erase(row)
			_steps.remove_child(row)
			row.queue_free()
			row = _add_row(
				lines[index], fizzle, index < gives, giver_mini, STEP_SIZE, STEP_WEIGHT, top, 1
			)
		if row.position.y + row.size.y + reserve > room:
			_rows.erase(row)
			_steps.remove_child(row)
			row.queue_free()
			var more: Label = MonitorKit.bold(
				MORE_TEXT % (lines.size() - index),
				STEP_SIZE,
				STEP_WEIGHT,
				Palette.INK_LIGHT,
				MORE_HEIGHT
			)
			more.name = "More"
			more.set_meta(&"line", more.text)
			_steps.add_child(more)
			more.position = Vector2(0, top)
			more.size = Vector2(STEPS_WIDTH, MORE_HEIGHT)
			_rows.append(more)
			return
		top = row.position.y + row.size.y + STEP_GAP


## One step line at `top` (see the class comment). Returns it, or null for an empty line.
func _add_row(
	line: String,
	fizzle: bool,
	gives: bool,
	giver_mini: Texture2D,
	font_size: int,
	weight: int,
	top: float,
	max_lines: int = STEP_MAX_LINES
) -> Control:
	if line.is_empty():
		return null
	var parts: PackedStringArray = MonitorText.step_parts(line)
	if _counting and parts[0].begins_with("×"):
		var gap: int = parts[0].find(" ")
		if gap > 0:
			parts[0] = parts[0].substr(gap + 1)

	var colour: Color = Palette.INK
	if fizzle:
		colour = Palette.TOMATO_DARK
	elif gives:
		colour = Palette.MUSTARD_DARKEST
	var row: Control = Control.new()
	row.name = "Step%d" % _rows.size()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.set_meta(&"line", line)
	_steps.add_child(row)
	var line_height: float = roundf(font_size * 1.3)
	var mark: Control = _mark(fizzle, gives, giver_mini, font_size)
	mark.name = "Mark"
	row.add_child(mark)
	var indent: float = MARK_SIZE.x + MARK_GAP
	var amount_width: float = 0.0
	var amount: Label = null
	if not parts[1].is_empty():
		amount = MonitorKit.bold(
			parts[1],
			font_size + (0 if fizzle else 1),
			AMOUNT_WEIGHT,
			Palette.TOMATO_DARK if fizzle else Palette.MUSTARD_DARKEST,
			line_height
		)
		amount.name = "Amount"
		amount.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		row.add_child(amount)
		var least: float = 0.0 if fizzle else AMOUNT_MIN
		amount_width = maxf(least, amount.get_minimum_size().x) + AMOUNT_PAD
	var text: Label = MonitorKit.bold(parts[0], font_size, weight, colour, line_height)
	text.name = "Text"
	text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	text.max_lines_visible = max_lines
	text.text_overrun_behavior = TextServer.OVERRUN_TRIM_WORD_ELLIPSIS
	text.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	row.add_child(text)
	text.position = Vector2(indent, 0)
	text.size = Vector2(_steps.size.x - indent - amount_width, line_height)
	var height: float = maxf(line_height, text.get_minimum_size().y)
	text.size.y = height
	mark.position = Vector2(0, roundf((line_height - mark.size.y) / 2.0))
	if amount != null:
		# On the line's first row, as the mock-up's baseline-aligned amounts stand.
		amount.position = Vector2(_steps.size.x - amount_width + AMOUNT_PAD, 0.0)
		amount.size = Vector2(amount_width - AMOUNT_PAD, line_height)
	row.position = Vector2(0, top)
	row.size = Vector2(_steps.size.x, height)
	_rows.append(row)
	return row


## Whether `row`'s text needs more lines than it shows (it ends in an ellipsis).
static func _overruns(row: Control) -> bool:
	var text: Label = row.get_node_or_null("Text") as Label
	return text != null and text.get_line_count() > text.max_lines_visible


## A line's mark: the fizzle icon, a giver's mini, ✦ (a "gives" line) or ✓.
func _mark(fizzle: bool, gives: bool, giver_mini: Texture2D, font_size: int) -> Control:
	var texture: Texture2D = FIZZLE_ICON if fizzle else giver_mini
	if texture != null:
		var icon: TextureRect = UiKit.sprite(texture)
		icon.size = MARK_SIZE
		return icon
	var font: Font = MachineDisplay.marked_font(800)
	var text: String = CHECK_MARK
	if gives:
		text = GIVE_MARK if font.has_char(GIVE_MARK.unicode_at(0)) else GIVE_FALLBACK
	var label: Label = MonitorKit.bold(
		text, font_size, 800, Palette.MUSTARD_DARK if gives else Palette.GREEN_DARK, MARK_SIZE.y
	)
	label.add_theme_font_override("font", font)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.size = MARK_SIZE
	return label


## The parts fade in one after another (`animate`), else show at once.
func _fade_in(animate: bool) -> void:
	_stop_fades()
	var parts: Array[Array] = [[_name] + _glyphs_as_controls(), [_price_holder], [_effect], [_rule]]
	for index: int in range(_rows.size()):
		parts.append([_rows[index]])
	var delays: PackedFloat32Array = _tuning.part_delays
	for index: int in range(parts.size()):
		var delay: float = 0.0
		if index < delays.size():
			delay = delays[index]
		elif not delays.is_empty():
			delay = delays[-1] + _tuning.part_step_delay * (index - delays.size() + 1)
		for part: Variant in parts[index]:
			var control: Control = part as Control
			if control == null:
				continue
			if not animate or _reduced() or not is_inside_tree():
				control.modulate.a = 1.0
				continue
			control.modulate.a = 0.0
			var tween: Tween = _new_tween(_counting)
			tween.tween_interval(delay)
			tween.tween_property(control, "modulate:a", 1.0, maxf(0.01, _tuning.part_fade_s))
			_fades.append(tween)


func _glyphs_as_controls() -> Array[Control]:
	var controls: Array[Control] = []
	for glyph: FamilyGlyph in _glyphs:
		controls.append(glyph)
	return controls


func _clear_price() -> void:
	_stop(_punch)
	for child: Node in _price_holder.get_children():
		_price_holder.remove_child(child)
		child.queue_free()
	_price = null
	_struck = null


func _clear_steps() -> void:
	for child: Node in _steps.get_children():
		_steps.remove_child(child)
		child.queue_free()
	_rows.clear()


func _draw_rule() -> void:
	var x: float = 0.0
	while x < _rule.size.x:
		_rule.draw_rect(Rect2(x, 0, minf(DASH, _rule.size.x - x), RULE_HEIGHT), RULE_COLOR)
		x += DASH * 2.0


func _part(part_name: String) -> Control:
	var part: Control = Control.new()
	part.name = part_name
	part.mouse_filter = Control.MOUSE_FILTER_IGNORE
	part.size = SIZE
	add_child(part)
	return part


func _stop_fades() -> void:
	for tween: Tween in _fades:
		_stop(tween)
	_fades.clear()


## The price's look for `value` against `base`.
static func _pay_of(value: int, base: int) -> PlanningModel.Pay:
	if value <= 0 and base > 0:
		return PlanningModel.Pay.ZERO
	if value > base:
		return PlanningModel.Pay.BOOSTED
	return PlanningModel.Pay.LOWERED


static func _base_of(definition: CardDefinition) -> int:
	return definition.base if definition.is_product() else 0


## The width of a name's text (ItemName.make's control).
static func _name_width(shown_name: Control) -> float:
	if shown_name is MixedLabel:
		return shown_name.get_combined_minimum_size().x
	var label: Label = shown_name as Label
	var font: Font = label.get_theme_font("font")
	var font_size: int = label.get_theme_font_size("font_size")
	return font.get_string_size(label.text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x


func _new_tween(on_count: bool) -> Tween:
	if on_count and make_tween.is_valid():
		var tween: Tween = make_tween.call() as Tween
		if tween != null:
			return tween
	return create_tween()


static func _stop(tween: Tween) -> void:
	if tween != null and tween.is_valid():
		tween.kill()


func _reduced() -> bool:
	return reduced_motion.is_valid() and bool(reduced_motion.call())
