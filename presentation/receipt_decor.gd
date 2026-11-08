class_name ReceiptDecor
extends RefCounted
## What ReceiptView draws beside its text (#75, #80, #71): the hanging indent of a step line, the
## combo band and diamond, the planning receipt's item marks (the fizzle icon, the inspection's
## warning), a hovered item's targets' fill and token chip, the dashed rules and
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
## The styles whose indented lines are step lines (line_label: ReceiptView.STEP_FONT_SIZE).
const STEP_STYLES: Array[ReceiptView.LineStyle] = [
	ReceiptView.LineStyle.DETAIL, ReceiptView.LineStyle.CONTEXT, ReceiptView.LineStyle.COMBO
]
## The smallest a PROJECTED amount shrinks to (fit_amount).
const AMOUNT_MIN_FONT_SIZE := 18

const FIZZLE_ICON := preload("res://art/icons/fizzle.png")
const WARNING_ICON := preload("res://art/icons/warning.png")

## The PROJECTED amount's bold font trimmed for each size (_size_amount).
static var _trimmed: Dictionary[int, FontVariation] = {}


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
## reason's start): the fizzle icon (FIZZLED) or the warning icon (DENIED, at its own aspect);
## nothing for NONE. Its "mark" meta holds `kind`.
static func mark(line: HBoxContainer, kind: ReceiptView.Mark) -> void:
	if kind == ReceiptView.Mark.NONE:
		return
	var icon: TextureRect
	if kind == ReceiptView.Mark.FIZZLED:
		icon = _icon(FIZZLE_ICON)
	else:
		icon = _icon(WARNING_ICON)
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
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
	line.get_child(1).add_child(icon)


## Prints how far the PROJECTED `line`'s `total` is from `quota` on the `against` line under it, at
## the foot's size (FOOT_FONT_SIZE), right-aligned under the amount (the PR #138 left UI: the
## amount stands at the paper's right, so the words end where it ends, inside the paper): "+67.00€
## over" in green dark, "56.00€ short" in tomato (ReceiptTarget.against_text), so the status never
## relies on colour alone. The amount itself stays ink (the PR #138 review: only the words under
## it are coloured).
static func against_quota(
	line: HBoxContainer, against: HBoxContainer, total: int, quota: int
) -> void:
	var amount: Label = line.get_child(1) as Label
	amount.add_theme_color_override("font_color", Palette.INK)
	against.name = "Against"
	var empty: Label = against.get_child(0) as Label
	empty.add_theme_font_size_override("font_size", ReceiptView.FOOT_FONT_SIZE)
	var words: Label = against.get_child(1) as Label
	words.text = ReceiptTarget.against_text(total, quota)
	words.add_theme_font_size_override("font_size", ReceiptView.FOOT_FONT_SIZE)
	words.add_theme_color_override("font_color", ReceiptTarget.against_color(total, quota))
	words.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	words.add_theme_stylebox_override("normal", StyleBoxEmpty.new())
	against.add_theme_constant_override("separation", 0)


## Lays out the PROJECTED `line` (the PR #138 left UI): the caption at the left of the lines, the
## amount at their right (PROJECTED never carries a mark, so it drops the mark column), both in
## ink. The amount prints bold at PROJECTED_FONT_SIZE (the PR #138 round 2: it stands out), its
## digits' middle on the caption's capitals' middle (_size_amount): half the number above the
## caption's line, half below.
static func spread_projected(line: HBoxContainer) -> void:
	var caption: Label = line.get_child(0) as Label
	var amount: Label = line.get_child(1) as Label
	caption.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	amount.size_flags_horizontal = Control.SIZE_SHRINK_END
	amount.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	for label: Label in [caption, amount]:
		label.size_flags_vertical = Control.SIZE_FILL
		label.vertical_alignment = VERTICAL_ALIGNMENT_TOP
		label.add_theme_color_override("font_color", Palette.INK)
	amount.add_theme_stylebox_override("normal", StyleBoxEmpty.new())
	_size_amount(line, ReceiptView.PROJECTED_FONT_SIZE)


## Shrinks the PROJECTED `line`'s amount (PROJECTED_FONT_SIZE) to fit beside its caption (the
## pair has no mark column: spread_projected) in `width` px of lines, down to
## AMOUNT_MIN_FONT_SIZE (a four-digit total). Nothing for a width not laid out yet, or no line
## (null: the lines' width changed with no PROJECTED line).
static func fit_amount(line: HBoxContainer, width: float) -> void:
	if width <= 0.0 or not is_instance_valid(line):
		return
	var caption: Label = line.get_child(0) as Label
	var amount: Label = line.get_child(1) as Label
	var room: float = (
		width
		- ReceiptView.text_width(caption.text, ReceiptView.MONO_FONT, ReceiptView.CAPTION_FONT_SIZE)
		- line.get_theme_constant("separation")
	)
	var font_size: int = ReceiptInk.fit_font_size(
		amount.text, room, ReceiptView.PROJECTED_FONT_SIZE, AMOUNT_MIN_FONT_SIZE
	)
	_size_amount(line, font_size)


## Sets the PROJECTED `line`'s amount at `font_size` in bold, its line box trimmed above the
## capitals to TOTAL_FONT_SIZE's height (the bigger number never takes the rows' room:
## ReceiptRows), and drops the caption (both top-aligned on the line) so its capitals' middle is
## the amount's digits' (cap_middle, on whole px): the number stands half above the caption's line
## and half below it (the PR #138 left UI).
static func _size_amount(line: HBoxContainer, font_size: int) -> void:
	var caption: Label = line.get_child(0) as Label
	var amount: Label = line.get_child(1) as Label
	amount.add_theme_font_size_override("font_size", font_size)
	var bold: FontVariation = ReceiptInk.bold_font()
	var extra: float = bold.get_height(font_size) - bold.get_height(ReceiptView.TOTAL_FONT_SIZE)
	if not _trimmed.has(font_size):
		var trimmed: FontVariation = FontVariation.new()
		trimmed.base_font = bold
		trimmed.spacing_top = -maxi(roundi(extra), 0)
		_trimmed[font_size] = trimmed
	amount.add_theme_font_override("font", _trimmed[font_size])
	amount.set_meta(ReceiptRows.BASE_FONT_META, bold)
	var drop: StyleBoxEmpty = StyleBoxEmpty.new()
	drop.content_margin_top = maxf(roundf(cap_middle(amount) - cap_middle(caption, false)), 0.0)
	caption.add_theme_stylebox_override("normal", drop)


## How far below `label`'s top the middle of its first character's ink sits (a capital or a
## digit: from its top to the baseline), as the label prints it top-aligned: its style's top
## margin (when `with_style`), its line's ascent, then half the glyph's height above the baseline.
static func cap_middle(label: Label, with_style: bool = true) -> float:
	var font: Font = label.get_theme_font("font")
	var font_size: int = label.get_theme_font_size("font_size")
	var shaped: TextLine = TextLine.new()
	shaped.add_string(label.text, font, font_size)
	var top: float = label.get_theme_stylebox("normal").get_margin(SIDE_TOP) if with_style else 0.0
	return top + shaped.get_line_ascent() + glyph_top(font, font_size, label.text) / 2.0


## The top of `text`'s first glyph in `font` at `font_size`, from the baseline (negative: above
## it).
static func glyph_top(font: Font, font_size: int, text: String) -> float:
	var server: TextServer = TextServerManager.get_primary_interface()
	var rid: RID = font.get_rids()[0]
	var size: Vector2i = Vector2i(font_size, 0)
	var glyph: int = server.font_get_glyph_index(rid, font_size, text.unicode_at(0), 0)
	server.font_render_glyph(rid, size, glyph)
	return server.font_get_glyph_offset(rid, size, glyph).y


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


## A receipt line's label of `style` holding `text`: the mono font at the style's size and colour
## (ReceiptView.add_line).
static func line_label(text: String, style: ReceiptView.LineStyle) -> Label:
	var label: Label = Label.new()
	label.text = text
	var font_size: int = ReceiptView.LINE_FONT_SIZE
	# An indented step line keeps the step size (it hangs and wraps under its item's line).
	if text.begins_with(" ") and style in STEP_STYLES:
		font_size = ReceiptView.STEP_FONT_SIZE
	var color: Color = Palette.INK
	match style:
		ReceiptView.LineStyle.CONTEXT:
			color = Palette.TEAL
		ReceiptView.LineStyle.FIZZLE:
			# A fizzle's reason at B2's step-line size, so a long one keeps to two rows.
			color = Palette.TOMATO_DARK
			font_size = ReceiptView.FOOTER_FONT_SIZE
		ReceiptView.LineStyle.TOTAL, ReceiptView.LineStyle.PROJECTED:
			font_size = ReceiptView.TOTAL_FONT_SIZE
		ReceiptView.LineStyle.NOTICE:
			font_size = 15
			color = (
				Palette.GREEN_DARK
				if text.begins_with(ReceiptView.BOON_NOTICE_PREFIX)
				else Palette.TOMATO
			)
		ReceiptView.LineStyle.MARGIN:
			font_size = 15
		ReceiptView.LineStyle.TEAR, ReceiptView.LineStyle.WAITING:
			color = Palette.MUTED_INK
		ReceiptView.LineStyle.CLOSING:
			font_size = ReceiptView.FOOTER_FONT_SIZE
	label.add_theme_font_override("font", ReceiptView.MONO_FONT)
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	return label


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


static func _draw_dashes(rule: HSeparator) -> void:
	# At its foot when the rule is stretched (planning's rule over the foot at full length).
	var natural: float = rule.get_combined_minimum_size().y
	var y: float = rule.size.y - natural + roundf((natural - ArtStyle.ART_SCALE) / 2.0)
	# Amber on a gold paper, steel on a silver one (ReceiptGold).
	var ink: Color = ReceiptGold.rule_ink(rule, Palette.CREAM_SHADE)
	var x: float = 0.0
	while x < rule.size.x:
		var dash: float = minf(ReceiptView.RULE_DASH, rule.size.x - x)
		rule.draw_rect(Rect2(x, y, dash, ArtStyle.ART_SCALE), ink)
		x += 2.0 * ReceiptView.RULE_DASH


## Whether a line of `style` keeps the mark column (ReceiptView.MARK_COLUMN) at its right end: all
## but the margin, the notice and the tear, which run across it.
static func has_mark_column(style: ReceiptView.LineStyle) -> bool:
	return (
		style
		not in [
			ReceiptView.LineStyle.MARGIN,
			ReceiptView.LineStyle.NOTICE,
			ReceiptView.LineStyle.TEAR,
		]
	)
