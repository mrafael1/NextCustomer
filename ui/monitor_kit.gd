class_name MonitorKit
extends RefCounted
## The single monitor screen's small parts (#105 piece 2, mock-up readability_v3.html, monitor b):
## its bold Atkinson labels, the gold boxes (the gain box, the "+N€" tab) and the SPEND MET stamp,
## made the same way by the checkout column and the climax. Pure makers: no state.

const BOX_BORDER := 2
const STAMP_BORDER := 2
const STAMP_TEXT := "MET!"
const STAMP_INK := Palette.GREEN_DARK


## A label in the body font at `weight`, `font_size` px on a `line` px line, in `colour`.
static func bold(text: String, font_size: int, weight: int, colour: Color, line: float) -> Label:
	var label: Label = UiKit.body_label(text, font_size, colour)
	label.add_theme_font_override("font", ArtStyle.bold_font(weight))
	label.add_theme_constant_override("outline_size", 0)
	label.add_theme_constant_override("line_spacing", 0)
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.custom_minimum_size.y = line
	return label


## A gold box with an ink edge BOX_BORDER px outside its face (the mock-up's box-shadow): `text` in
## the body font at 800, `font_size` px, `line` px tall inside, `padding` px either side.
static func gold_box(text: String, font_size: int, line: float, padding: float) -> Label:
	var label: Label = bold(text, font_size, 800, Palette.INK, line)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var face: StyleBoxFlat = StyleBoxFlat.new()
	face.bg_color = Palette.GOLD
	face.border_color = Palette.INK
	face.set_border_width_all(BOX_BORDER)
	face.set_expand_margin_all(BOX_BORDER)
	face.content_margin_left = padding
	face.content_margin_right = padding
	face.content_margin_top = 0
	face.content_margin_bottom = 0
	label.add_theme_stylebox_override("normal", face)
	return label


## The SPEND MET stamp: Pixelify `font_size` px on a font_size + 6 px line, dark green in a
## STAMP_BORDER px dark green border on paper, `width` px wide, turned `tilt` degrees about its
## centre.
static func stamp(width: float, font_size: int, tilt: float) -> Label:
	var label: Label = UiKit.display_label(STAMP_TEXT, font_size, false)
	label.name = "SpendStamp"
	var spacing: int = 0 if font_size < 15 else 1
	label.add_theme_font_override("font", ArtStyle.spaced_display_font(spacing))
	label.add_theme_color_override("font_color", STAMP_INK)
	label.add_theme_constant_override("outline_size", 0)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	var face: StyleBoxFlat = StyleBoxFlat.new()
	face.bg_color = Palette.PAPER
	face.border_color = STAMP_INK
	face.set_border_width_all(STAMP_BORDER)
	face.content_margin_top = 0
	face.content_margin_bottom = 0
	label.add_theme_stylebox_override("normal", face)
	label.size = Vector2(width, font_size + 6 + 2 * STAMP_BORDER)
	label.custom_minimum_size = label.size
	label.pivot_offset = label.size / 2.0
	label.rotation_degrees = tilt
	return label


## `control`'s rect as drawn (global), its rotation about its pivot taken into account (the
## axis-aligned rect round it), with `grow` px round its own rect first.
static func drawn_rect(control: Control, grow: float = 0.0) -> Rect2:
	var rect: Rect2 = Rect2(Vector2.ZERO, control.size).grow(grow)
	var corners: Array[Vector2] = [
		rect.position,
		Vector2(rect.end.x, rect.position.y),
		rect.end,
		Vector2(rect.position.x, rect.end.y),
	]
	var transform: Transform2D = control.get_global_transform()
	var bounds: Rect2 = Rect2(transform * corners[0], Vector2.ZERO)
	for corner: Vector2 in corners:
		bounds = bounds.expand(transform * corner)
	return bounds


## The width of a name's text (ItemName.make's control).
static func name_width(shown_name: Control) -> float:
	if shown_name is MixedLabel:
		return shown_name.get_combined_minimum_size().x
	var label: Label = shown_name as Label
	var font: Font = label.get_theme_font("font")
	var font_size: int = label.get_theme_font_size("font_size")
	return font.get_string_size(label.text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x


## The item column's (MonitorItemColumn) frame, header tint and foot and description band's foot,
## as [rect, colour] pairs in a `size` column: its families' `faces` and their `lights` (a split
## ticket's halves left and right); `panel` the description's band (empty: none). The band adds
## only its foot line: its ground stays the paper (round 7).
static func column_fills(
	size: Vector2, faces: PackedColorArray, lights: PackedColorArray, panel: Rect2
) -> Array[Array]:
	var found: Array[Array] = []
	var frame: float = MonitorItemColumn.FRAME
	var header: Rect2 = MonitorItemColumn.HEADER_RECT
	var halves: Array[Rect2] = [Rect2(Vector2.ZERO, size)]
	if faces.size() > 1:
		var half: float = floorf(size.x / 2.0)
		halves = [Rect2(0, 0, half, size.y), Rect2(half, 0, size.x - half, size.y)]
	var inside: Rect2 = Rect2(Vector2.ONE * frame, size - Vector2.ONE * 2.0 * frame)
	for index: int in range(halves.size()):
		var side: int = mini(index, faces.size() - 1)
		var area: Rect2 = halves[index]
		var tint: Color = Color(lights[side], MonitorItemColumn.HEADER_TINT_ALPHA)
		found.append([area.intersection(header), tint])
		var ink: Color = faces[side]
		found.append([Rect2(area.position.x, 0, area.size.x, frame), ink])
		found.append([Rect2(area.position.x, size.y - frame, area.size.x, frame), ink])
		var header_foot: Rect2 = Rect2(
			area.position.x, header.end.y, area.size.x, MonitorItemColumn.HEADER_FOOT
		)
		found.append([header_foot.intersection(inside), ink])
		if index == 0:
			found.append([Rect2(0, 0, frame, size.y), ink])
		if index == halves.size() - 1:
			found.append([Rect2(size.x - frame, 0, frame, size.y), ink])
		if panel.has_area():
			var line: float = MonitorItemColumn.PANEL_LINE
			var foot: Rect2 = Rect2(panel.position.x, panel.end.y - line, panel.size.x, line)
			found.append([foot.intersection(area), ink])
	return found
