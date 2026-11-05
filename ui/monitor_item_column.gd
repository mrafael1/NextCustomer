class_name MonitorItemColumn
extends Control
## The monitor's item column (PR #138 monitor, mock-up docs/art/mockups/monitor_codex.png), right
## of the scanner bay across the rest of the paper (MonitorView.ITEM_RECT): the item in the bay,
## read in full, top to bottom in four parts inside a FRAME px frame in its ticket's family
## colour (FamilyPalette.ticket_families: a split ticket's two families left and right, the plain
## coupon's teal), on the monitor's paper:
## 1. The header (HEADER_RECT, a restrained tint of the family's light colour; its glyphs inside
##    it with their rims, PR #138 round 2): the item's family glyphs as its ticket shows them
##    (FamilyPalette.shelf_families of its card's tags, a coupon's coupon mark; each with its
##    tip), then its name (ItemName: Pixelify, or the bold body font
##    when too long). No family glyph shows anywhere else on the monitor.
## 2. The description in its closed band (PR #138 round 4): a keyword chip, then the rule in plain
##    language (CardText.monitor_text, else the sticker summary, else the rule text; families as
##    chips) at the first of EFFECT_TIERS that leaves room for the rows; else an ellipsis and the
##    MORE chip with the whole text in its tip.
## 3. The equation section (PR #138 round 5: one look; round 6: open, no box round it, the user's
##    "remove dash around price section"), under the band's foot (under the header with no
##    description), across the content's width (INSET, CONTENT_WIDTH, as the header and the
##    description): the base price line (MonitorBaseLine, a product's only, over at least one
##    effect row; a row's height), then the applied effects in scoring order, then the unused ones
##    (MonitorStepRow: icon, name, a dotted leader (MonitorLeader), amount right-aligned; a bonus
##    green, a factor in its strength's ink, a harmful or unused one tomato, a bonus's or a harmful
##    row's name in its amount's colour). A hand item's muted note stands alone.
## 4. Under the rows, clear of them and of the frame's foot, the payout zone (PAYOUT_RECT): only
##    "= 16€" (MonitorPayout), right-aligned under the amounts, in the ticket's payout ink (a
##    coupon's "+N€" in teal, what its "gives" rows add, PR #138 round 7); it never moves.
##
## In planning (show_item) rows that don't fit their room go on pages of whole rows
## (MonitorStepPages, `pages`), turning by themselves, their marker at the header's right end. In
## the count (start_item, set_value, show_step) the item comes in at its base price with no row;
## each landing moves the payout (punching it) and adds its row, the newest highlighted, earlier
## overflow folding into "+N earlier". The last item stays at the count's end. When the item
## changes its parts fade in one after another (CountTotalTuning's part_delays and part_fade_s; at
## once under reduced motion). Display only: the prices and lines are the caller's (the score's).

## The column's size (MonitorView.ITEM_RECT's; PR #138 round 2: its frame 2 px from the paper's
## edge), its frame (family colour) and the content's inset from its edge (frame + padding).
const SIZE := Vector2(280, 150)
const FRAME := 2.0
const INSET := 8.0
const CONTENT_WIDTH := 264.0
## The header: its band (tinted HEADER_TINT_ALPHA of the family's light colour, tall enough for a
## glyph and its rim inside it), its foot (HEADER_FOOT px), the glyphs' gap and the name's gap
## after them.
const HEADER_RECT := Rect2(2, 2, 276, 24)
const HEADER_FOOT := 1.0
const HEADER_TINT_ALPHA := 0.55
const GLYPH_GAP := 4.0
const NAME_GLYPH_GAP := 6.0
const NAME_HEIGHT := 26.0
const MEMBER_TIP := "%s · %s is a %s item"
const COUPON_FAMILY := "Coupon"
## The description: its top (inside its panel) and its tiers (size, pitch, lines), the first that
## fits and leaves room for the rows; the MORE chip MORE_GAP after a text that still doesn't fit.
const EFFECT_TOP := 29.0
const EFFECT_WEIGHT := 800
const EFFECT_TIERS: Array[Vector3i] = [
	Vector3i(14, 17, 2), Vector3i(13, 16, 2), Vector3i(13, 16, 3), Vector3i(12, 15, 3)
]
## The description leaves room for the tallest row at least: when no tier does, it takes CUT_TIER
## (its MORE chip carrying the rest).
const CUT_TIER := Vector3i(13, 16, 2)
## Over a base line the tiers are tried first leaving TIER_SPARE px more under the rows (round 4's
## full base strip over its compact one), then without: the band keeps round 4's size and lines
## (the user approved that top section after round 4), never growing on the room the slim base
## line frees; that room stays the rows'.
const TIER_SPARE := 4.0
const MORE_WORD := "MORE"
const MORE_GAP := 4.0
## The keyword chips' room in the description (PR #138 round 2): their margin each side and their
## word's padding inside the box (a ticket's: GlyphLabel.CHIP_MARGIN, KeywordChip.PADDING_X).
const CHIP_MARGIN := 3.0
const CHIP_PADDING := 5.0
## The ellipsis that ends a cut description before its MORE chip, so the chip reads as "the rest",
## not as the sentence's last word (ELLIPSIS_FALLBACK when the font lacks it).
const ELLIPSIS := "…"
const ELLIPSIS_FALLBACK := "..."
## The description's band (PR #138 round 4): under the header's foot, frame to frame, closed
## PANEL_PAD under the text by a PANEL_LINE px foot in the family's colour (on the 2 px grid); its
## ground the monitor's paper, as the equation section's (round 7, the user's "remove bg color and
## keep same white as in operation section": no family tint).
const PANEL_PAD := 1.0
const PANEL_LINE := 2.0
## The equation section (PR #138 round 6: open): from ROWS_X (ROWS_WIDTH wide, the content's),
## SECTION_PAD under the band's foot (BARE_TOP with no description), the base line and the rows
## down to ROWS_BOTTOM, ROW_PITCH a line (MonitorStepRow's), then the payout's zone.
const SECTION_PAD := 2.0
const BARE_TOP := 32.0
const ROWS_X := INSET
const ROWS_WIDTH := CONTENT_WIDTH
const ROWS_BOTTOM := 114.0
const ROW_PITCH := MonitorStepRow.ROW_PITCH
const ROW_MAX_LINES := MonitorStepRow.MAX_LINES
const HARM_MARK := MonitorStepRow.HARM_MARK
const NOTE_COLOR := MonitorStepRow.NOTE_COLOR
const FOLDED_TEXT := "+%d earlier"
## The count's note after a row whose giver is in the bag: its words, size and weight (teal).
const FROM_BAG_TEXT := " · from the bag"
const FROM_BAG_SIZE := 11
const FROM_BAG_WEIGHT := 700
## The payout's zone, the same for every item: the payout on its right, under the rows' amounts
## (round 6: with the box gone, PAYOUT_DROP px under the rows' area so "= N€" breathes, and its
## digits' shadow 5 px clear of the frame's inside foot).
const PAYOUT_DROP := 2.0
const PAYOUT_RECT := Rect2(ROWS_X, ROWS_BOTTOM + PAYOUT_DROP, ROWS_WIDTH, 27)
## The pages' marker, at the header's right end, MARKER_GAP clear of the name.
const MARKER_SIZE := 12
const MARKER_COLOR := Palette.TEAL_DARK
const MARKER_GAP := 6.0
## The empty belt's hint: its size, weight and colour, centred in the column.
const HINT_SIZE := 15
const HINT_WEIGHT := 800
const HINT_COLOR := Palette.INK_LIGHT

## Returns a new Tween on the count's clock (the count's parts); none: the column's own.
var make_tween: Callable = Callable()
## Returns true when the player asked for reduced motion. None means false.
var reduced_motion: Callable = Callable()
## The shift's redraws left, for a live factor in the description (-1: the rule's own).
var redraws_left: int = -1
## Planning's pages of rows (null with none): one page when they fit.
var pages: MonitorStepPages:
	get:
		return _pages

var _tuning: CountTotalTuning
var _definition: CardDefinition
## The frame's colours (its families' faces; a split ticket's halves) and the header tint's (their
## light colours), from the item's ticket families.
var _faces: PackedColorArray = PackedColorArray()
var _lights: PackedColorArray = PackedColorArray()
var _name: Control
## The name's left (after the glyphs).
var _name_x: float = INSET
var _glyphs: Array[FamilyGlyph] = []
var _effect: GlyphLabel
var _more: KeywordChip
var _ellipsis: Label
## The description's band (the column's coordinates; empty: none).
var _panel: Rect2 = Rect2()
## The base price line (MonitorBaseLine; null with none).
var _base: Control
## How many effect rows sit under the base line (bonus, factor, harmful, unused; a hand item's note
## is none): the base line shows only over at least one (PR #138 round 4).
var _effect_rows: int = 0
var _steps: Control
var _payout: MonitorPayout
var _rows: Array[Control] = []
var _shown_value: int = -1
var _fades: Array[Tween] = []
var _punch: Tween
var _counting: bool = false
var _count_fizzled: bool = false
var _count_lines: Array[Dictionary] = []
var _pages: MonitorStepPages
## What planning shows now (show_item's arguments): the same again keeps the page and its wait.
var _shown_key: Array = []


func _init(tuning: CountTotalTuning = null) -> void:
	name = "ItemColumn"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	size = SIZE
	_tuning = tuning if tuning != null else load(CountUpPlan.TOTAL_TUNING_PATH) as CountTotalTuning
	_steps = Control.new()
	_steps.name = "Steps"
	_steps.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_steps)
	_payout = MonitorPayout.new(PAYOUT_RECT.size)
	_payout.position = PAYOUT_RECT.position
	_payout.visible = false
	add_child(_payout)


## Planning: `definition` (with its scored `tags`) and its `shown` lines (ScanController.ItemLines:
## its payout, -1 for a hand item, its base price; its step lines, fizzles, harms and minis; its
## first `gives` "gives" rows; `given`, a coupon's "+N€" in the payout's zone, PR #138 round 7).
## The "gives" rows go one per target only when the whole scan fits on one page, else as its
## `collapsed` row (round 7 review). `animate`: its parts fade in. Call it in the tree: the text is
## measured with the real font.
func show_item(
	definition: CardDefinition,
	tags: PackedStringArray,
	shown: ScanController.ItemLines,
	animate: bool = false
) -> void:
	var key: Array = [definition, tags, redraws_left, shown.payout, shown.lines, shown.fizzles]
	key.append_array([shown.gives, shown.minis, shown.harms, shown.given, shown.collapsed])
	if not _counting and _definition == definition and key == _shown_key:
		return
	_counting = false
	var built: Array[Control] = _planning_rows(definition, shown, false)
	if (
		shown.gives > 1
		and not shown.collapsed.is_empty()
		and _paged(built, _steps.size.y).size() > 1
	):
		for row: Control in built:
			row.free()
		built = _planning_rows(definition, shown, true)
	# A coupon that gave something keeps its coupon window: only one that gave nothing is wasted
	# (its fizzle rows say what went unused).
	var fizzled: bool = shown.fizzles.has(true) and not (definition.is_coupon() and shown.gives > 0)
	var hand: bool = shown.payout < 0
	_set_payout(shown.payout if not hand else _base_of(definition), fizzled, false, shown.given)
	_fill_pages(built)
	_place_marker()
	_shown_key = key
	_fade_in(animate)


## Planning's rows for `shown` (see show_item; its "gives" rows as its one `collapsed` row when
## `collapse`), and the frame built for them (_build): the description leaves room for all their
## lines, or for the tallest. The rows that make the payout first, in scoring order, then the
## unused effects' (fizzles, which change no amount), so the first page explains the payout (#138
## review).
func _planning_rows(
	definition: CardDefinition, shown: ScanController.ItemLines, collapse: bool
) -> Array[Control]:
	var lines: PackedStringArray = shown.lines
	var hand: bool = shown.payout < 0
	var built: Array[Control] = []
	if hand and lines.is_empty():
		built.append(MonitorStepRow.note(MonitorText.HAND_NOTE, ROWS_WIDTH))
	var many: Control = (
		_make_row(shown.collapsed, MonitorStepRow.Tone.PLAIN, true, shown.collapsed_mini)
		if collapse
		else null
	)
	if many != null:
		built.append(many)
	var unused: Array[Control] = []
	for index: int in range(lines.size()):
		var gives: bool = index < shown.gives
		if collapse and gives:
			continue
		var fizzle: bool = shown.fizzles[index] if index < shown.fizzles.size() else false
		var tone: MonitorStepRow.Tone = MonitorStepRow.tone_of(
			fizzle, index < shown.harms.size() and shown.harms[index]
		)
		var giver_mini: Texture2D = shown.minis[index] if index < shown.minis.size() else null
		var row: Control = _make_row(lines[index], tone, gives, giver_mini)
		if row == null:
			continue
		if fizzle:
			unused.append(row)
		else:
			built.append(row)
	built.append_array(unused)
	var needed: int = 0
	var tallest: int = 0
	for row: Control in built:
		var row_lines: int = roundi(row.size.y / ROW_PITCH)
		needed += row_lines
		tallest = maxi(tallest, row_lines)
	_build(definition, needed, tallest, built.size() - (1 if hand and lines.is_empty() else 0))
	return built


## The count: `definition` comes into the bay at its base price, with no row yet (so no base line:
## it joins with the first step, show_step); its parts fade in (`animate`) or show at once.
func start_item(definition: CardDefinition, _tags: PackedStringArray, animate: bool = true) -> void:
	_counting = true
	# Laid as with its rows (the description's size leaves them room), shown with none yet.
	_build(definition, 2, ROW_MAX_LINES, 1)
	_effect_rows = 0
	_place_body(_effect_end())
	_set_payout(_base_of(definition), false, false)
	_fade_in(animate)


## Planning's empty belt: `text` (MonitorText.EMPTY_BELT), muted and centred, and nothing else.
func show_empty(text: String) -> void:
	var shown: Label = _hint()
	if shown != null and shown.text == text and _definition == null:
		return
	clear()
	_counting = false
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


func _hint() -> Label:
	return get_node_or_null("Hint") as Label


## The count: the item's payout is now `value` (a landing on it), punching when it changed.
func set_value(value: int, fizzled: bool = false) -> void:
	if _definition == null:
		return
	_count_fizzled = _count_fizzled or fizzled
	_set_payout(value, _count_fizzled, value != _shown_value)


## The count: the item's newest step `line` (a fizzle's, a `harmful` one's, a "gives" line, with its
## source's `giver_mini`; `from_bag`: its giver is already in the bag, said after it in teal) joins
## the rows, the newest highlighted; only earlier overflow folds into "+N earlier".
func show_step(
	line: String,
	fizzle: bool,
	gives: bool = false,
	giver_mini: Texture2D = null,
	from_bag: bool = false,
	harmful: bool = false
) -> void:
	if line.is_empty():
		return
	var tone: MonitorStepRow.Tone = MonitorStepRow.tone_of(fizzle, harmful)
	_count_lines.append(
		{"line": line, "tone": tone, "gives": gives, "mini": giver_mini, "bag": from_bag}
	)
	if _effect_rows == 0 and _definition != null:
		_effect_rows = 1
		_relay_description()
	_show_count_lines()
	if fizzle and _definition != null and not _count_fizzled:
		_count_fizzled = true
		_set_payout(_shown_value, true, false)


## The count's rows: the newest that fit (each on up to ROW_MAX_LINES lines, the earlier ones
## folding into "+N earlier"), the newest highlighted and its icon pulsing.
func _show_count_lines() -> void:
	_clear_steps()
	var room: float = maxf(_steps.size.y, ROW_PITCH)
	var built: Array[Control] = []
	var used: float = 0.0
	var first: int = _count_lines.size()
	for index: int in range(_count_lines.size() - 1, -1, -1):
		var entry: Dictionary = _count_lines[index]
		var row: Control = _make_row(
			entry["line"], entry["tone"], entry["gives"], entry["mini"] as Texture2D
		)
		if row == null:
			first = index
			continue
		# Room for the row, and for the fold's row when earlier ones are left out.
		var fold: float = ROW_PITCH if index > 0 else 0.0
		if not built.is_empty() and used + row.size.y + fold > room + 0.5:
			row.free()
			break
		if bool(entry["bag"]):
			_add_from_bag(row)
		row.set_meta(&"from_bag", bool(entry["bag"]))
		built.push_front(row)
		used += row.size.y
		first = index
	var top: float = 0.0
	if first > 0:
		var folded: Label = MonitorKit.bold(FOLDED_TEXT % first, 12, 700, NOTE_COLOR, ROW_PITCH)
		folded.name = "Folded"
		folded.set_meta(&"line", folded.text)
		folded.size = Vector2(_steps.size.x, ROW_PITCH)
		_steps.add_child(folded)
		_rows.append(folded)
		top += ROW_PITCH
	for row: Control in built:
		row.position = Vector2(0, top)
		_steps.add_child(row)
		_rows.append(row)
		top += row.size.y
	if _rows.is_empty():
		return
	var newest: Control = _rows[-1]
	var highlight: ColorRect = ColorRect.new()
	highlight.name = "Highlight"
	highlight.color = Palette.MUSTARD_PALE
	highlight.mouse_filter = Control.MOUSE_FILTER_IGNORE
	highlight.size = newest.size
	newest.add_child(highlight)
	newest.move_child(highlight, 0)
	var giver_mini: Texture2D = _count_lines[-1]["mini"] as Texture2D
	var mark: Control = newest.get_node_or_null("Mark") as Control
	if mark != null and giver_mini != null and not _reduced() and is_inside_tree():
		mark.pivot_offset = mark.size / 2.0
		var pulse: Tween = _new_tween(true)
		pulse.tween_property(mark, "scale", Vector2.ONE * 1.35, 0.08)
		pulse.tween_property(mark, "scale", Vector2.ONE, 0.16)
		_fades.append(pulse)


## FROM_BAG_TEXT after `row`'s text, smaller and teal, the text making room.
func _add_from_bag(row: Control) -> void:
	var text: Label = row.get_node("Text") as Label
	var note: Label = MonitorKit.bold(
		FROM_BAG_TEXT, FROM_BAG_SIZE, FROM_BAG_WEIGHT, Palette.TEAL_DARK, ROW_PITCH
	)
	note.name = "FromBag"
	row.add_child(note)
	var note_width: float = MonitorStepRow.text_width(note)
	text.size.x = minf(MonitorStepRow.text_width(text), maxf(0.0, text.size.x - note_width))
	note.position = Vector2(text.position.x + text.size.x, text.position.y)
	note.size = Vector2(note_width, ROW_PITCH)


## Nothing shown (the bay between items, or empty).
func clear() -> void:
	_definition = null
	_faces.clear()
	_lights.clear()
	_shown_key = []
	_count_lines.clear()
	_count_fizzled = false
	_shown_value = -1
	_panel = Rect2()
	_effect_rows = 0
	_stop_fades()
	_stop(_punch)
	for child: Node in get_children():
		if child == _steps or child == _payout:
			continue
		remove_child(child)
		child.queue_free()
	_name = null
	_name_x = INSET
	_effect = null
	_more = null
	_ellipsis = null
	_glyphs.clear()
	_base = null
	_clear_steps()
	_payout.visible = false
	_payout.group().scale = Vector2.ONE
	queue_redraw()


## The item shown (null for none), its payout shown and its parts, for checks and the chips.
func shown_definition() -> CardDefinition:
	return _definition


func shown_value() -> int:
	return _shown_value


func name_control() -> Control:
	return _name


func glyphs() -> Array[FamilyGlyph]:
	return _glyphs


func effect() -> GlyphLabel:
	return _effect


## The base price line (MonitorBaseLine), or null with none.
func base_line() -> Control:
	return _base


func payout_view() -> MonitorPayout:
	return _payout


## The rows shown (each: its mark, text and amount; on pages, the page shown's), and every row's
## text (on pages, every page's).
func step_rows() -> Array[Control]:
	return _rows


func step_texts() -> PackedStringArray:
	var texts: PackedStringArray = PackedStringArray()
	for row: Control in _pages.all_rows() if _pages != null else _rows:
		texts.append(String(row.get_meta(&"line", "")))
	return texts


## Where the base's chip takes off (global): the payout's middle.
func price_point() -> Vector2:
	if _payout.visible:
		return _payout.shown_rect().get_center()
	return get_global_transform() * PAYOUT_RECT.get_center()


## Where WASTED's grey 0€ drops from (global): just under the newest row's amount, or the rows.
func waste_point() -> Vector2:
	if not _rows.is_empty():
		var amount: Control = _rows[-1].get_node_or_null("Amount") as Control
		if amount != null:
			var rect: Rect2 = amount.get_global_rect()
			return Vector2(rect.get_center().x, rect.end.y + CountChips.CHIP_HEIGHT / 2.0)
	return step_point()


## Where a step's chip takes off (global): the newest row's amount, or the rows' top.
func step_point() -> Vector2:
	if not _rows.is_empty():
		var amount: Control = _rows[-1].get_node_or_null("Amount") as Control
		if amount != null:
			return amount.get_global_rect().get_center()
	return _steps.get_global_transform() * Vector2(_steps.size.x / 2.0, ROW_PITCH / 2.0)


## Every part shown, with its rect (global, at rest), for layout checks: the frame, the header, the
## name and its glyphs, the description and its MORE chip, the band, the base line, the rows, the
## pages' marker, the rows' area and the payout (its shown digits or window, and its parts).
func part_rects() -> Dictionary[String, Rect2]:
	var rects: Dictionary[String, Rect2] = {}
	var transform: Transform2D = get_global_transform()
	if _definition != null:
		rects["frame"] = Rect2(transform * Vector2.ZERO, size)
		rects["header"] = Rect2(transform * HEADER_RECT.position, HEADER_RECT.size)
		rects["footer"] = Rect2(transform * PAYOUT_RECT.position, PAYOUT_RECT.size)
		if _panel.has_area():
			rects["panel"] = Rect2(transform * _panel.position, _panel.size)
	if _name != null:
		var name_rect: Rect2 = _name.get_global_rect()
		name_rect.size.x = minf(name_rect.size.x, _name_width(_name))
		rects["name"] = name_rect
	for index: int in range(_glyphs.size()):
		rects["glyph%d" % index] = _glyphs[index].get_global_rect()
	if _effect != null:
		var effect_rect: Rect2 = _effect.text_rect()
		rects["effect"] = Rect2(
			_effect.get_global_transform() * effect_rect.position, effect_rect.size
		)
	if _more != null:
		rects["more"] = _more.get_global_rect()
	if _base != null:
		rects["base"] = _base.get_global_rect()
	if _definition != null:
		rects["rows"] = _steps.get_global_rect()
	for index: int in range(_rows.size()):
		rects["step%d" % index] = _rows[index].get_global_rect()
	if _pages != null and _pages.marker() != null:
		rects["pager"] = _pages.marker().get_global_rect()
	if _payout.visible:
		rects["payout"] = _payout.shown_rect()
		var parts: Dictionary[String, Rect2] = _payout.part_rects()
		for part: String in parts:
			rects["payout_" + part.to_lower()] = parts[part]
	return rects


## Builds the frame, header, description, section and the rows' room for `definition`, the
## description leaving room for `needed` lines of rows, at least `least` (_lay_description), over
## `effect_rows` effect rows (none: no base line).
func _build(definition: CardDefinition, needed: int, least: int, effect_rows: int) -> void:
	clear()
	_definition = definition
	_effect_rows = effect_rows
	var palette: FamilyPalette = FamilyPalette.shared()
	for style: FamilyStyle in palette.styles(palette.ticket_families(definition)):
		if style.has_ticket_colours():
			_faces.append(style.face)
			_lights.append(style.light)
	if _faces.is_empty():
		var fallback: FamilyStyle = PriceSticker.fallback_style(definition)
		_faces.append(fallback.face)
		_lights.append(fallback.light)
	_build_header(definition, palette)
	_lay_description(needed, least)
	_payout.visible = true
	queue_redraw()


## The header's glyphs (the ticket's, left) and the name after them.
func _build_header(definition: CardDefinition, palette: FamilyPalette) -> void:
	var shown: PackedStringArray = PackedStringArray([COUPON_FAMILY])
	if not definition.is_coupon():
		shown = palette.shelf_families(definition.tags)
	var x: float = INSET
	for family: String in shown:
		var style: FamilyStyle = palette.style(family)
		if style == null or style.glyph == null:
			continue
		var glyph: FamilyGlyph = FamilyGlyph.new(style, true)
		var family_name: String = style.display_name
		glyph.tip_text = MEMBER_TIP % [family_name, definition.display_name, family_name]
		glyph.tip_below = true
		var top: float = HEADER_RECT.position.y + floorf((HEADER_RECT.size.y - glyph.size.y) / 2.0)
		glyph.position = Vector2(x, top)
		add_child(glyph)
		_glyphs.append(glyph)
		x += glyph.size.x + GLYPH_GAP
	if not _glyphs.is_empty():
		x += NAME_GLYPH_GAP - GLYPH_GAP
	_name_x = x
	_make_name(INSET + CONTENT_WIDTH - x)


## The item's name `room` px wide after the glyphs, centred on the header (made again narrower
## when the pages' marker joins the header).
func _make_name(room: float) -> void:
	if _name != null:
		remove_child(_name)
		_name.queue_free()
	_name = ItemName.make(_definition.display_name, room, NAME_HEIGHT, Palette.INK)
	add_child(_name)
	_name.position = Vector2(_name_x, roundf(HEADER_RECT.get_center().y - NAME_HEIGHT / 2.0))


## The pages' marker at the header's right end, centred on it, the name making room for it.
func _place_marker() -> void:
	var marker: Label = _pages.marker() if _pages != null else null
	if marker == null:
		return
	var shown: Vector2 = marker.get_combined_minimum_size()
	var right: float = INSET + CONTENT_WIDTH
	var left: float = right - ceilf(shown.x)
	var foot: float = roundf(HEADER_RECT.get_center().y + shown.y / 2.0)
	_pages.marker_right = true
	_pages.marker_foot = Vector2(right, foot) - _steps.position
	var room: float = left - MARKER_GAP - _name_x
	if _name_width(_name) > room:
		_make_name(room)


## The count's first step: a product's base line joins the section, the rows moving under it.
func _relay_description() -> void:
	_place_body(_effect_end())
	queue_redraw()


## The description, its band and the section (see _build): the first tier that fits and leaves room
## for `needed` lines of rows (with TIER_SPARE kept first over a base line), else the fitting one
## that leaves the most room; when that leaves no room for `least` lines (the tallest row's),
## CUT_TIER with the MORE chip.
func _lay_description(needed: int, least: int) -> void:
	var text: String = _description(_definition, redraws_left)
	var bottom: float = -1.0
	if not text.is_empty():
		var ends: Array[float] = []
		for fit: Vector3i in EFFECT_TIERS:
			var label: GlyphLabel = _effect_label(text, fit)
			ends.append(
				EFFECT_TOP + maxi(label.line_count(), 1) * label.pitch() if label.fits() else -1.0
			)
			label.free()
		var spares: Array[float] = [0.0]
		if _has_base():
			spares.push_front(TIER_SPARE)
		var chosen: int = -1
		var roomiest: int = -1
		var most: int = -1
		for spare: float in spares:
			for tier: int in range(EFFECT_TIERS.size()):
				if ends[tier] < 0.0:
					continue
				var room: int = _rows_room(_rows_top(ends[tier]) + spare)
				if room > most:
					most = room
					roomiest = tier
				if room >= needed:
					chosen = tier
					break
			if chosen >= 0:
				break
		if chosen < 0:
			chosen = roomiest if roomiest >= 0 else EFFECT_TIERS.size() - 1
		var fit: Vector3i = EFFECT_TIERS[chosen]
		if roomiest < 0 or _rows_room(_rows_top(_ends(text, fit))) < least:
			fit = CUT_TIER
		_effect = _effect_label(text, fit)
		_effect.name = "Effect"
		_effect.position = Vector2(INSET, EFFECT_TOP)
		add_child(_effect)
		if not _effect.fits():
			_add_more(text)
		bottom = EFFECT_TOP + maxi(_effect.line_count(), 1) * _effect.pitch()
	_place_body(bottom)


## The band, the base line and the rows' room under a description ending at `bottom` (-1: none).
func _place_body(bottom: float) -> void:
	_panel = Rect2()
	if bottom >= 0.0:
		var top: float = HEADER_RECT.end.y + HEADER_FOOT
		_panel = Rect2(FRAME, top, size.x - 2.0 * FRAME, panel_foot(bottom) - top)
	if _base != null:
		remove_child(_base)
		_base.queue_free()
		_base = null
	if _has_base():
		_base = MonitorBaseLine.make(_base_of(_definition), ROWS_WIDTH)
		_base.position = Vector2(ROWS_X, content_top(bottom))
		add_child(_base)
	var rows_top: float = _rows_top(bottom)
	_steps.position = Vector2(ROWS_X, rows_top)
	_steps.size = Vector2(ROWS_WIDTH, maxf(ROWS_BOTTOM - rows_top, ROW_PITCH))


## Where `text`'s description ends (the column's y) at `fit`.
func _ends(text: String, fit: Vector3i) -> float:
	var label: GlyphLabel = _effect_label(text, fit)
	var ends: float = EFFECT_TOP + maxi(label.line_count(), 1) * label.pitch()
	label.free()
	return ends


## The rows' top under a description ending at `bottom` (-1: none): the section's first line, or
## the line under the base line when it shows.
func _rows_top(bottom: float) -> float:
	return content_top(bottom) + (ROW_PITCH if _has_base() else 0.0)


## The section's first line's top (the base line's, else the rows') under a description ending at
## `bottom` (-1: none): SECTION_PAD under the band's foot, else BARE_TOP.
static func content_top(bottom: float) -> float:
	return panel_foot(bottom) + SECTION_PAD if bottom >= 0.0 else BARE_TOP


## The description band's foot (its line's bottom, on the 2 px grid) for a text ending at `bottom`.
static func panel_foot(bottom: float) -> float:
	return 2.0 * ceilf((bottom + PANEL_PAD) / 2.0) + PANEL_LINE


## How many rows of ROW_PITCH fit from `rows_top` to ROWS_BOTTOM.
static func _rows_room(rows_top: float) -> int:
	return floori((ROWS_BOTTOM - rows_top) / ROW_PITCH)


## The text a card's description shows: its monitor text, else its sticker summary, else its rule
## text ("" for a card with no rule).
static func _description(definition: CardDefinition, redraws: int) -> String:
	var text: String = CardText.monitor_text(definition, redraws)
	if text.is_empty():
		text = CardText.sticker_summary(definition, redraws)
	if text.is_empty() and not definition.rules.is_empty():
		text = definition.rule_text
	return text.strip_edges()


func _effect_label(text: String, fit: Vector3i) -> GlyphLabel:
	var label: GlyphLabel = GlyphLabel.new(
		text,
		ArtStyle.bold_font(EFFECT_WEIGHT),
		fit.x,
		Palette.INK,
		fit.y,
		CONTENT_WIDTH,
		fit.z,
		false,
		null,
		true
	)
	label.set_chip_room(CHIP_MARGIN, CHIP_PADDING)
	label.set_tip(true, self)
	label.set_live(text, CardText.live_tips(_definition, redraws_left))
	return label


## The MORE chip at the end of the description's last line, the whole text in its tip.
func _add_more(text: String) -> void:
	_more = KeywordChip.new(MORE_WORD, "", text)
	_more.name = "More"
	_more.tip_below = true
	var font: Font = ArtStyle.bold_font(EFFECT_WEIGHT)
	var dots: String = ELLIPSIS if font.has_char(ELLIPSIS.unicode_at(0)) else ELLIPSIS_FALLBACK
	var font_size: int = _effect.font_size()
	var dots_width: float = ceilf(
		font.get_string_size(dots, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	)
	_effect.set_end_inset(dots_width + MORE_GAP + _more.size.x + MORE_GAP)
	add_child(_more)
	var lines: int = maxi(_effect.line_count(), 1)
	var line_top: float = EFFECT_TOP + (lines - 1) * _effect.pitch()
	_ellipsis = MonitorKit.bold(dots, font_size, EFFECT_WEIGHT, Palette.INK, _effect.pitch())
	_ellipsis.name = "Ellipsis"
	_ellipsis.custom_minimum_size = Vector2.ZERO
	_ellipsis.size = Vector2(dots_width, _effect.pitch())
	_ellipsis.position = Vector2(INSET + _effect.last_line_end(), line_top)
	add_child(_ellipsis)
	var left: float = _ellipsis.position.x + dots_width + MORE_GAP
	_more.position = Vector2(
		minf(left, INSET + CONTENT_WIDTH - _more.size.x),
		line_top + floorf((_effect.pitch() - KeywordChip.HEIGHT) / 2.0)
	)


## The payout at `value`, in its state against the base (see MonitorPayout; a coupon's `given`,
## its "+N€"); `punch` grows it from its right edge (the count's landing).
func _set_payout(value: int, fizzled: bool, punch: bool, given: int = 0) -> void:
	var base: int = _base_of(_definition)
	var state: PriceWindow.State = MonitorPayout.state_of(
		value, base, fizzled, _definition.is_coupon()
	)
	var glyph: PlanningModel.Glyph = PlanningModel.Glyph.NONE
	if state == PriceWindow.State.ZERO:
		glyph = PlanningModel.Glyph.FIZZLE if fizzled else PlanningModel.Glyph.WARNING
	_shown_value = value
	_payout.show_pay(state, value, base, glyph, given)
	if punch and not _reduced() and is_inside_tree():
		_stop(_punch)
		var group: Control = _payout.group()
		group.scale = Vector2.ONE * _tuning.item_price_punch
		_punch = _new_tween(_counting)
		_punch.tween_property(group, "scale", Vector2.ONE, maxf(0.01, _tuning.item_price_punch_s))


## Planning's rows on pages of whole rows in the rows' room (one page when they fit), the marker
## in the header (_place_marker).
func _fill_pages(built: Array[Control]) -> void:
	_clear_steps()
	var paged: Array[Array] = _paged(built, _steps.size.y)
	_pages = MonitorStepPages.new(paged, _steps.size, _tuning.page_interval_s, _tuning.page_fade_s)
	_pages.reduced_motion = reduced_motion
	var marker: Label = _pages.marker()
	if marker != null:
		marker.add_theme_font_size_override("font_size", MARKER_SIZE)
		marker.add_theme_color_override("font_color", MARKER_COLOR)
	_pages.turned.connect(_on_page_turned)
	_steps.add_child(_pages)
	_rows = _pages.rows()


## `rows` on pages `room` px tall, each placed under the one before it on its page, each page's
## texts at one size (MonitorStepRow.even_sizes).
static func _paged(rows: Array[Control], room: float) -> Array[Array]:
	var paged: Array[Array] = [[]]
	var top: float = 0.0
	for row: Control in rows:
		if top + row.size.y > room + 0.5 and not paged[-1].is_empty():
			paged.append([])
			top = 0.0
		row.position = Vector2(0, top)
		paged[-1].append(row)
		top += row.size.y
	for page: Array in paged:
		MonitorStepRow.even_sizes(page)
	return paged


func _on_page_turned(_page: int) -> void:
	_rows = _pages.rows()


## One row (MonitorStepRow.make) the content's width, on up to ROW_MAX_LINES lines, or null.
func _make_row(
	line: String, tone: MonitorStepRow.Tone, gives: bool, giver_mini: Texture2D
) -> Control:
	var row: Control = MonitorStepRow.make(line, tone, gives, giver_mini, ROW_MAX_LINES, ROWS_WIDTH)
	if row != null:
		row.add_child(MonitorLeader.new(row.size))
	return row


## The parts fade in one after another (`animate`), else show at once: the header, the
## description, the base line, each row, then the payout.
func _fade_in(animate: bool) -> void:
	_stop_fades()
	var head: Array[Control] = [_name]
	for glyph: FamilyGlyph in _glyphs:
		head.append(glyph)
	var parts: Array[Array] = [head, [_effect, _ellipsis, _more], [_base]]
	for row: Control in _rows:
		parts.append([row])
	parts.append([_payout])
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


func _clear_steps() -> void:
	if _pages != null:
		_pages.stop()
		_pages = null
	for child: Node in _steps.get_children():
		_steps.remove_child(child)
		child.queue_free()
	_rows.clear()


## The frame, the header's tint and its foot and the description's band's foot, in the family's
## colours (a split ticket's halves left and right): fills().
func _draw() -> void:
	for fill: Array in fills():
		draw_rect(fill[0], fill[1])


## What _draw fills, as [rect, colour] pairs in the column's coordinates (none with no item). The
## description's band adds only its foot line: its ground stays the paper (round 7).
func fills() -> Array[Array]:
	var found: Array[Array] = []
	if _definition == null or _faces.is_empty():
		return found
	var halves: Array[Rect2] = [Rect2(Vector2.ZERO, size)]
	if _faces.size() > 1:
		var half: float = floorf(size.x / 2.0)
		halves = [Rect2(0, 0, half, size.y), Rect2(half, 0, size.x - half, size.y)]
	var inside: Rect2 = Rect2(Vector2.ONE * FRAME, size - Vector2.ONE * 2.0 * FRAME)
	for index: int in range(halves.size()):
		var side: int = mini(index, _faces.size() - 1)
		var area: Rect2 = halves[index]
		found.append([area.intersection(HEADER_RECT), Color(_lights[side], HEADER_TINT_ALPHA)])
		var ink: Color = _faces[side]
		found.append([Rect2(area.position.x, 0, area.size.x, FRAME), ink])
		found.append([Rect2(area.position.x, size.y - FRAME, area.size.x, FRAME), ink])
		var header_foot: Rect2 = Rect2(area.position.x, HEADER_RECT.end.y, area.size.x, HEADER_FOOT)
		found.append([header_foot.intersection(inside), ink])
		if index == 0:
			found.append([Rect2(0, 0, FRAME, size.y), ink])
		if index == halves.size() - 1:
			found.append([Rect2(size.x - FRAME, 0, FRAME, size.y), ink])
		if _panel.has_area():
			var foot: Rect2 = Rect2(
				_panel.position.x, _panel.end.y - PANEL_LINE, _panel.size.x, PANEL_LINE
			)
			found.append([foot.intersection(area), ink])
	return found


func _stop_fades() -> void:
	for tween: Tween in _fades:
		_stop(tween)
	_fades.clear()


## Whether the shown item has a base price line: a product's printed price, over at least one
## effect row (PR #138 round 4: with none, "= N€" alone says the price). A coupon prints none (its
## ticket shows the scissors window), so a "Base price 0€" never reads as an item worth nothing;
## its rows start at the section's top.
func _has_base() -> bool:
	return _definition != null and _definition.is_product() and _effect_rows > 0


## Where the description ends (the column's y; -1 with none).
func _effect_end() -> float:
	return EFFECT_TOP + maxi(_effect.line_count(), 1) * _effect.pitch() if _effect != null else -1.0


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
