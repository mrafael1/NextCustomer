class_name ReceiptDecor
extends RefCounted
## What ReceiptView draws beside its text (#75, #80): the combo band and diamond, the planning
## receipt's item marks (the raised check, the fizzle icon), the dashed rules and the framed
## line's mustard frame. Display only: what gets marked is the receipt's call.

## A combo line's band behind it, at this alpha (ReceiptView.COMBO_* place its bar and diamond).
const COMBO_BAND_ALPHA := 0.25
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

const FIZZLE_ICON := preload("res://art/icons/fizzle.png")


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


## Puts `kind` on `line`: a "Mark" inside its right label, at MARK_RECT in the line's mark
## column, centred on its left label's first row (a wrapped fizzle's mark sits beside the
## reason's start): the check (RAISED, drawn) or the fizzle icon (FIZZLED); nothing for NONE.
## Its "mark" meta holds `kind`.
static func mark(line: HBoxContainer, kind: ReceiptView.Mark) -> void:
	if kind == ReceiptView.Mark.NONE:
		return
	var icon: Control
	if kind == ReceiptView.Mark.FIZZLED:
		icon = _icon(FIZZLE_ICON)
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
	line.get_child(1).add_child(icon)


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


static func _icon(texture: Texture2D) -> TextureRect:
	var icon: TextureRect = TextureRect.new()
	icon.texture = texture
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_SCALE
	ArtStyle.use_pixel_material(icon)
	return icon


## The band and bar, unless the line is framed (ReceiptView: its "framed" meta).
static func _draw_combo_band(line: HBoxContainer) -> void:
	if line.get_meta("framed", false):
		return
	line.draw_rect(Rect2(Vector2.ZERO, line.size), Color(Palette.GOLD, COMBO_BAND_ALPHA))
	line.draw_rect(Rect2(0, 0, ReceiptView.COMBO_BAR, line.size.y), Palette.GOLD)


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
