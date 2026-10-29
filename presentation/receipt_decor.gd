class_name ReceiptDecor
extends RefCounted
## What ReceiptView draws beside its text (#75, #80, #71): the hanging indent of a step line, the
## combo band and diamond, the planning receipt's item marks (the raised check, the fizzle icon,
## the inspection's warning), a hovered item's targets' fill and token chip, the dashed rules and
## the framed line's mustard frame. Display only: what gets marked is the receipt's call.

## A combo line's band behind it, at this alpha (ReceiptView.COMBO_* place its bar and diamond).
const COMBO_BAND_ALPHA := 0.25
## A loyalty perk's combo line (perk()): its band is pale teal, not gold.
const PERK_META := "perk"
## A step line's marker after its leading spaces (hang_parts()): it is printed beside the first
## row, and the wrapped rows hang under the text after it.
const HANG_MARKERS: Array[String] = ["+ ", "× "]
## A mark, from the line's right end (the end of its mark column, ReceiptView.MARK_COLUMN),
## centred on the line's first row.
const MARK_RECT := Rect2(-14, -7, 14, 14)
## The raised mark's check (B2's small thin tick, 8 x 7 px): one 1 px square per "#", centred in
## the mark.
const CHECK_ROWS: Array[String] = [
	".......#",
	"......##",
	".....##.",
	"#...##..",
	"##.##...",
	".###....",
	"..#.....",
]
## The framed line: a mustard-pale fill and a FRAME_WIDTH mustard frame.
const FRAME_WIDTH := 2.0
## A hovered item's target line (relate): a mustard-pale fill and, before its amount, the token
## it gets in a mustard chip with a CHIP_BORDER ink border, bold CHIP_SIZE text, CHIP_PADDING on
## each side.
const CHIP_NAME := "RelationChip"
const CHIP_BORDER := 2
const CHIP_SIZE := 11
const CHIP_WEIGHT := 700
const CHIP_PADDING := 3.0

const FIZZLE_ICON := preload("res://art/icons/fizzle.png")
const WARNING_ICON := preload("res://art/icons/warning.png")
const CHECK_DISC := preload("res://art/icons/mark_check.png")


## Hangs an indented line's left `label`: its text starts past its lead and marker on every
## wrapped row (an empty "normal" style's left margin), the marker printed beside the first row
## (a "Marker" label inside it). The lead is its leading spaces' width, or `lead_width` when
## that is set (a combo line's COMBO_INDENT, whose diamond takes the marker's place: without
## `with_marker` the marker is dropped). A line without leading spaces is left as it is.
static func hang(label: Label, lead_width: float = -1.0, with_marker: bool = true) -> void:
	var parts: PackedStringArray = hang_parts(label.text)
	if parts[0].is_empty():
		return
	if not with_marker:
		parts[1] = ""
	var font: Font = label.get_theme_font("font")
	var font_size: int = label.get_theme_font_size("font_size")
	var lead: float = (
		lead_width if lead_width >= 0.0 else ReceiptView.text_width(parts[0], font, font_size)
	)
	var indent: StyleBoxEmpty = StyleBoxEmpty.new()
	indent.content_margin_left = lead + ReceiptView.text_width(parts[1], font, font_size)
	label.add_theme_stylebox_override("normal", indent)
	label.text = parts[2]
	if parts[1].is_empty():
		return
	var marker: Label = Label.new()
	marker.name = "Marker"
	marker.text = parts[1].strip_edges()
	marker.add_theme_font_override("font", font)
	marker.add_theme_font_size_override("font_size", font_size)
	marker.add_theme_color_override("font_color", label.get_theme_color("font_color"))
	marker.mouse_filter = Control.MOUSE_FILTER_IGNORE
	marker.position = Vector2(lead, 0)
	label.add_child(marker)


## Marks a combo `line` (its hung `left` label): the band and bar drawn behind the whole line
## (both sides and every wrapped row), and the diamond (a "ComboDiamond" inside `left`) beside the
## bar, so it is marked by shape, not colour alone.
static func combo(line: HBoxContainer, left: Label) -> void:
	line.draw.connect(_draw_combo_band.bind(line))
	var diamond: TextureRect = _icon(ReceiptView.COMBO_DIAMOND)
	diamond.name = "ComboDiamond"
	diamond.position = ReceiptView.COMBO_ICON_RECT.position
	diamond.size = ReceiptView.COMBO_ICON_RECT.size
	left.add_child(diamond)


## Marks a combo `line` as a loyalty perk's (an upgrade's): its band turns pale teal (#116 v3.1).
static func perk(line: Control) -> void:
	line.set_meta(PERK_META, true)
	line.queue_redraw()


## Puts `kind` on `line`: a "Mark" inside its right label, at MARK_RECT in the line's mark
## column, centred on its left label's first row (a wrapped fizzle's mark sits beside the
## reason's start): the check (RAISED, drawn), the fizzle icon (FIZZLED) or the warning icon
## (DENIED, at its own aspect); the PROJECTED line's met mark (MET: the belt's mark_check disc,
## unscaled, centred on the amount's height); nothing for NONE. Its "mark" meta holds `kind`.
static func mark(line: HBoxContainer, kind: ReceiptView.Mark) -> void:
	if kind == ReceiptView.Mark.NONE:
		return
	var icon: Control
	if kind == ReceiptView.Mark.FIZZLED:
		icon = _icon(FIZZLE_ICON)
	elif kind == ReceiptView.Mark.DENIED:
		icon = _icon(WARNING_ICON)
		(icon as TextureRect).stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	elif kind == ReceiptView.Mark.MET:
		icon = _icon(CHECK_DISC)
		(icon as TextureRect).stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
	else:
		icon = Control.new()
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		icon.draw.connect(_draw_check.bind(icon))
	icon.name = "Mark"
	icon.set_meta("mark", kind)
	icon.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	var left: Label = line.get_child(0) as Label
	var row: float = left.get_theme_font("font").get_height(left.get_theme_font_size("font_size"))
	var middle: float = roundf(row / 2.0)
	icon.offset_left = MARK_RECT.position.x
	icon.offset_right = MARK_RECT.end.x
	icon.offset_top = middle + MARK_RECT.position.y
	icon.offset_bottom = middle + MARK_RECT.end.y
	if kind == ReceiptView.Mark.MET:
		icon.anchor_top = 0.5
		icon.anchor_bottom = 0.5
		icon.offset_top = MARK_RECT.position.y
		icon.offset_bottom = MARK_RECT.end.y
	line.get_child(1).add_child(icon)


## Colours the PROJECTED `line`'s amount by the shown `total` against `quota` (a display difference,
## as QuotaMeter's delta): GOOD with the met mark at or over it, TOMATO under it, so it never
## relies on colour alone. Returns the shortfall's row ("short €12.00"), empty when met.
static func against_quota(line: HBoxContainer, total: int, quota: int) -> String:
	var margin: ShiftMargin = ShiftMargin.of(total, quota)
	var amount: Label = line.get_child(1) as Label
	amount.add_theme_color_override(
		"font_color", Palette.GOOD if margin.passed() else Palette.TOMATO
	)
	if margin.passed():
		mark(line, ReceiptView.Mark.MET)
		return ""
	return ReceiptView.SHORT_TEXT % ReceiptView.money(margin.amount())


## Marks `line` as a hovered item's target getting `token` (a mustard-pale fill behind it and the
## token's chip before its amount), or unmarks it for an empty `token`.
static func relate(line: HBoxContainer, token: String) -> void:
	var old: Node = line.get_node_or_null(CHIP_NAME)
	if old != null:
		line.remove_child(old)
		old.queue_free()
	if not line.has_meta("relation_drawn"):
		line.set_meta("relation_drawn", true)
		line.draw.connect(_draw_relation.bind(line))
	line.set_meta("related", not token.is_empty())
	line.queue_redraw()
	if token.is_empty():
		return
	var chip: Label = Label.new()
	chip.name = CHIP_NAME
	chip.text = token
	chip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	chip.size_flags_vertical = Control.SIZE_SHRINK_END
	chip.add_theme_font_override("font", ArtStyle.bold_font(CHIP_WEIGHT))
	chip.add_theme_font_size_override("font_size", CHIP_SIZE)
	chip.add_theme_color_override("font_color", Palette.INK)
	var face: StyleBoxFlat = StyleBoxFlat.new()
	face.bg_color = Palette.MUSTARD
	face.border_color = Palette.INK
	face.set_border_width_all(CHIP_BORDER)
	face.content_margin_left = CHIP_PADDING
	face.content_margin_right = CHIP_PADDING
	chip.add_theme_stylebox_override("normal", face)
	line.add_child(chip)
	line.move_child(chip, line.get_child_count() - 2)


## The token chip on a hovered item's target `line`, or null (for tests).
static func relation_chip(line: HBoxContainer) -> Label:
	return line.get_node_or_null(CHIP_NAME) as Label


## The dashed rules (under the header, above PROJECTED and the count-up's TOTAL): B2's cream-shade
## dashes in place of the solid rule, across the lines' width and their mark column.
static func dashed_rule() -> HSeparator:
	var rule: HSeparator = HSeparator.new()
	rule.name = "StubRule"
	rule.add_theme_stylebox_override("separator", StyleBoxEmpty.new())
	rule.draw.connect(_draw_dashes.bind(rule))
	return rule


## Draws the framed `line` (one of `lines`, inside `inset`; none for null): a mustard-pale fill and
## a mustard frame across the inset's width, ReceiptView.FRAME_GROW taller than the line on each
## side, behind the lines.
static func draw_frame(inset: Control, lines: Control, line: Control) -> void:
	if line == null or line.get_parent() != lines:
		return
	var grow: float = ReceiptView.FRAME_GROW
	var top: float = lines.position.y + line.position.y - grow
	var rect: Rect2 = Rect2(0.0, top, inset.size.x, line.size.y + 2.0 * grow)
	inset.draw_rect(rect, Palette.MUSTARD_PALE)
	var width: float = FRAME_WIDTH
	inset.draw_rect(Rect2(rect.position, Vector2(rect.size.x, width)), Palette.MUSTARD)
	inset.draw_rect(Rect2(rect.position.x, rect.end.y - width, rect.size.x, width), Palette.MUSTARD)
	inset.draw_rect(Rect2(rect.position, Vector2(width, rect.size.y)), Palette.MUSTARD)
	inset.draw_rect(Rect2(rect.end.x - width, rect.position.y, width, rect.size.y), Palette.MUSTARD)


## A step line's text split for a hanging indent: its leading spaces, its marker ("+ " or "× ",
## only after leading spaces) and the rest.
static func hang_parts(text: String) -> PackedStringArray:
	var rest: String = text.lstrip(" ")
	var lead: String = text.substr(0, text.length() - rest.length())
	var marker: String = ""
	for candidate: String in HANG_MARKERS:
		if not lead.is_empty() and rest.begins_with(candidate):
			marker = candidate
			rest = rest.substr(candidate.length())
			break
	return PackedStringArray([lead, marker, rest])


## The receipt's scroll (`scroll`, over `lines`) that shows the framed `line` whole (with its
## frame), the least move from where it is, or its end when no line is framed.
static func scroll_target(scroll: ScrollContainer, lines: Control, line: Control) -> int:
	var end: int = int(scroll.get_v_scroll_bar().max_value)
	if line == null or line.get_parent() != lines:
		return end
	# In the scroll's content: the inset's own position moves with the scroll.
	var top: float = lines.position.y + line.position.y - ReceiptView.FRAME_GROW
	var bottom: float = top + line.size.y + 2.0 * ReceiptView.FRAME_GROW
	var view: float = scroll.size.y
	var at: float = clampf(float(scroll.scroll_vertical), bottom - view, top)
	return clampi(roundi(at), 0, maxi(end, 0))


static func _icon(texture: Texture2D) -> TextureRect:
	var icon: TextureRect = TextureRect.new()
	icon.texture = texture
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_SCALE
	ArtStyle.use_pixel_material(icon)
	return icon


## The band and bar, unless the line is framed (ReceiptView: its "framed" meta): gold, or a
## loyalty perk's pale teal band and teal bar (its "perk" meta, perk()).
static func _draw_combo_band(line: HBoxContainer) -> void:
	if line.get_meta("framed", false):
		return
	var band: Color = Color(Palette.GOLD, COMBO_BAND_ALPHA)
	var bar: Color = Palette.GOLD
	if line.get_meta(PERK_META, false):
		band = Color(Palette.TEAL_PALE, ReceiptInk.PERK_BAND_ALPHA)
		bar = Palette.TEAL
	line.draw_rect(Rect2(Vector2.ZERO, line.size), band)
	line.draw_rect(Rect2(0, 0, ReceiptView.COMBO_BAR, line.size.y), bar)


## A related line's mustard-pale fill (relate), behind its text.
static func _draw_relation(line: HBoxContainer) -> void:
	if line.get_meta("related", false):
		line.draw_rect(Rect2(Vector2.ZERO, line.size), Palette.MUSTARD_PALE)


## The raised mark's green check, centred in `icon`.
static func _draw_check(icon: Control) -> void:
	var origin: Vector2 = ((icon.size - check_size()) / 2.0).round()
	for row: int in range(CHECK_ROWS.size()):
		for column: int in range(CHECK_ROWS[row].length()):
			if CHECK_ROWS[row][column] == "#":
				icon.draw_rect(Rect2(origin + Vector2(column, row), Vector2.ONE), Palette.GOOD)


## The check's size in pixels (CHECK_ROWS).
static func check_size() -> Vector2:
	return Vector2(CHECK_ROWS[0].length(), CHECK_ROWS.size())


static func _draw_dashes(rule: HSeparator) -> void:
	var y: float = roundf((rule.size.y - ArtStyle.ART_SCALE) / 2.0)
	var x: float = 0.0
	while x < rule.size.x:
		var dash: float = minf(ReceiptView.RULE_DASH, rule.size.x - x)
		rule.draw_rect(Rect2(x, y, dash, ArtStyle.ART_SCALE), Palette.CREAM_SHADE)
		x += 2.0 * ReceiptView.RULE_DASH
