class_name ReceiptRows
extends RefCounted
## The count's printed rows at one pitch (mock-up docs/art/mockups/shift_scene_polish_v4.html, B2
## at D's sizes, picked on 2026-11-03; since main scene v2's H2 the rows print at checkout under
## the header, ReceiptPrintRows): every row the same pitch, what the paper leaves under the header
## shared by the belt's slots, MAX_PITCH at most and MIN_PITCH at least (ReceiptView._row_pitch).
## A row's labels keep their font but get its pitch as their line height (a FontVariation's top
## and bottom spacing), so the text sits centred in it, and its mark is centred again. Display
## only: ReceiptView builds the rows.

const MAX_PITCH := 20.0
const MIN_PITCH := 15.0
## A row label's own font (before its pitch's spacing), kept in its meta.
const BASE_FONT_META := "row_base_font"


## The rows' pitch for `slots` rows in `room` px: MAX_PITCH at most, whole px.
static func pitch_for(room: float, slots: int) -> float:
	return minf(MAX_PITCH, floorf(room / float(maxi(slots, 1))))


## Keeps a row's name `label` (or a header line's) to one row: it never wraps, and is cut with an
## ellipsis past its width (ReceiptInk's name fit shrinks an item's name first, down to
## ReceiptInk.NAME_MIN_FONT_SIZE), so its height is one row's even while it is hidden. It is not
## clipped: at the tightest pitches a descender may reach a pixel past its row's box.
static func one_row(label: Label) -> void:
	label.autowrap_mode = TextServer.AUTOWRAP_OFF
	label.clip_text = false
	label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	label.custom_minimum_size.x = 1.0


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
