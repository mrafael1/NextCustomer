class_name ReceiptRows
extends RefCounted
## The planning receipt at full length (mock-up docs/art/mockups/shift_scene_polish_v4.html, B2 at
## D's sizes, picked on 2026-11-03): one row per belt slot between the header and the foot, every
## row the same pitch, so the rows fill the paper and nothing scrolls or moves as items are placed.
## The pitch is what the paper leaves the rows, MAX_PITCH at most (30 px at 1920x1080: 6 slots),
## 18 for 7 and 15 for 8; the header's SHIFT line drops at HEADER_SLOTS slots (9: 16), or when it
## would leave the rows under MIN_PITCH (a Double checkout's row line taking its room; that line
## always prints). A row's labels keep their font but get its pitch as their line height (a
## FontVariation's top and bottom spacing), so the text sits centred in it, and its mark is
## centred again. Display only: ReceiptView builds the rows and says when to fit them.

const MAX_PITCH := 20.0
const MIN_PITCH := 15.0
## The SHIFT line drops at this many slots (the page's "info line dropped at 9 slots").
const HEADER_SLOTS := 9
## A row label's own font (before its pitch's spacing), kept in its meta.
const BASE_FONT_META := "row_base_font"


## The rows' pitch for `slots` rows in `room` px: MAX_PITCH at most, whole px.
static func pitch_for(room: float, slots: int) -> float:
	return minf(MAX_PITCH, floorf(room / float(maxi(slots, 1))))


## The lines' inset's bottom margin under the foot: ReceiptView.FRAME_GROW, plus a footer line's
## room (FOOT_FONT_SIZE and the lines' separation) when `kept` (no footer printed).
static func foot_margin(lines: VBoxContainer, kept: bool) -> int:
	var room: float = 0.0
	if kept:
		room = (
			ReceiptView.MONO_FONT.get_height(ReceiptView.FOOT_FONT_SIZE)
			+ lines.get_theme_constant("separation")
		)
	return int(ReceiptView.FRAME_GROW + room)


## Keeps a row's name `label` (or a header line's) to one row: it never wraps, and is cut with an
## ellipsis past its width (ReceiptInk's name fit shrinks an item's name first, down to
## ReceiptInk.NAME_MIN_FONT_SIZE), so its height is one row's even while it is hidden. It is not
## clipped: at the tightest pitches a descender may reach a pixel past its row's box.
static func one_row(label: Label) -> void:
	label.autowrap_mode = TextServer.AUTOWRAP_OFF
	label.clip_text = false
	label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	label.custom_minimum_size.x = 1.0


## Fits `rows` (children of `lines`) into `room` px of lines: the header lines (`header`) show
## under HEADER_SLOTS rows when the rows' pitch with them is at least MIN_PITCH, else they hide;
## every row then takes the pitch (less the lines' separation). Every other visible child of
## `lines` keeps its own height. Returns the pitch (0 for no rows).
static func fit(
	lines: VBoxContainer, rows: Array[Control], header: Array[Control], room: float
) -> float:
	if rows.is_empty():
		return 0.0
	var separation: float = float(lines.get_theme_constant("separation"))
	var fixed: float = -separation
	var header_height: float = 0.0
	for child: Node in lines.get_children():
		var control: Control = child as Control
		if control == null or rows.has(control):
			continue
		var height: float = control.get_combined_minimum_size().y + separation
		if header.has(control):
			header_height += height
		elif control.visible:
			fixed += height
	var pitch: float = pitch_for(room - fixed - header_height, rows.size())
	var with_header: bool = rows.size() < HEADER_SLOTS and pitch >= MIN_PITCH
	if not with_header:
		pitch = pitch_for(room - fixed, rows.size())
	for line: Control in header:
		line.visible = with_header
	for row: Control in rows:
		set_height(row, pitch - separation)
	return pitch


## Gives the row `line` (an HBoxContainer of labels) `height` px: each label's line height becomes
## `height` (its font's spacing), with its ink (a capital's top to a descender's foot: ink_span)
## centred on the row, not its line box (whose ascent keeps room above the capitals), so at the
## tightest pitch (8 slots) a descender stays inside the row; the row's minimum is `height` too,
## and its mark (ReceiptDecor.mark) is centred on it again.
static func set_height(line: Control, height: float) -> void:
	line.custom_minimum_size.y = height
	for child: Node in line.get_children():
		var label: Label = child as Label
		if label == null:
			continue
		var base: Font = label.get_meta(BASE_FONT_META, label.get_theme_font("font")) as Font
		label.set_meta(BASE_FONT_META, base)
		var font_size: int = label.get_theme_font_size("font_size")
		var ink: Vector2 = ink_span(base, font_size)
		var spaced: FontVariation = FontVariation.new()
		spaced.base_font = base
		# The baseline where the ink sits centred: (height - ink) / 2 above the capital's top.
		spaced.spacing_top = roundi(
			(height - (ink.y - ink.x)) / 2.0 - ink.x - base.get_ascent(font_size)
		)
		spaced.spacing_bottom = floori(height - base.get_height(font_size)) - spaced.spacing_top
		label.add_theme_font_override("font", spaced)
		var icon: Control = label.get_node_or_null(ReceiptInk.ICON_NAME) as Control
		if icon != null:
			icon.position.y = roundf((height - ReceiptInk.ICON_SIZE.y) / 2.0)
		var mark: Control = label.get_node_or_null("Mark") as Control
		if mark != null:
			var middle: float = roundf(height / 2.0)
			mark.offset_top = middle + ReceiptDecor.MARK_RECT.position.y
			mark.offset_bottom = middle + ReceiptDecor.MARK_RECT.end.y


## `font`'s ink at `font_size` from its baseline (down positive): the top of a capital ("B") and
## the foot of a descender ("g"), as their glyphs render.
static func ink_span(font: Font, font_size: int) -> Vector2:
	var server: TextServer = TextServerManager.get_primary_interface()
	var rid: RID = font.get_rids()[0]
	var size: Vector2i = Vector2i(font_size, 0)
	var span: Vector2 = Vector2(INF, -INF)
	for character: String in ["B", "g"]:
		var glyph: int = server.font_get_glyph_index(rid, font_size, character.unicode_at(0), 0)
		server.font_render_glyph(rid, size, glyph)
		var top: float = server.font_get_glyph_offset(rid, size, glyph).y
		var foot: float = top + server.font_get_glyph_size(rid, size, glyph).y
		span = Vector2(minf(span.x, top), maxf(span.y, foot))
	return span
