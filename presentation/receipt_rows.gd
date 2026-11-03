class_name ReceiptRows
extends RefCounted
## The planning receipt at full length (mock-up docs/art/mockups/shift_scene_polish_v4.html, B2 at
## D's sizes, picked on 2026-11-03): one row per belt slot between the header and the foot, every
## row the same pitch, so the rows fill the paper and nothing scrolls or moves as items are placed.
## The pitch is what the paper leaves the rows, MAX_PITCH at most (30 px at 1920x1080: 6 slots),
## 18 for 7 slots; when that would be under MIN_PITCH (24 px at 1920x1080) the header lines are
## dropped to make room (9 slots: 16). A row's labels keep their font but get its pitch as their
## line height (a FontVariation's top and bottom spacing), so the text sits centred in it, and its
## mark is centred again. Display only: ReceiptView builds the rows and says when to fit them.

const MAX_PITCH := 20.0
const MIN_PITCH := 16.0
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
## ReceiptInk.NAME_MIN_FONT_SIZE), so its height is one row's even while it is hidden.
static func one_row(label: Label) -> void:
	label.autowrap_mode = TextServer.AUTOWRAP_OFF
	label.clip_text = true
	label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	label.custom_minimum_size.x = 1.0


## Fits `rows` (children of `lines`) into `room` px of lines: the header lines (`header`) show
## when the rows' pitch with them is at least MIN_PITCH, else they hide; every row then takes the
## pitch (less the lines' separation). Every other visible child of `lines` keeps its own height.
## Returns the pitch (0 for no rows).
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
	var with_header: bool = pitch >= MIN_PITCH
	if not with_header:
		pitch = pitch_for(room - fixed, rows.size())
	for line: Control in header:
		line.visible = with_header
	for row: Control in rows:
		set_height(row, pitch - separation)
	return pitch


## Gives the row `line` (an HBoxContainer of labels) `height` px: each label's line height becomes
## `height` (its font's spacing), the row's minimum too, and its mark (ReceiptDecor.mark) is
## centred on it again.
static func set_height(line: Control, height: float) -> void:
	line.custom_minimum_size.y = height
	for child: Node in line.get_children():
		var label: Label = child as Label
		if label == null:
			continue
		var base: Font = label.get_meta(BASE_FONT_META, label.get_theme_font("font")) as Font
		label.set_meta(BASE_FONT_META, base)
		var natural: float = base.get_height(label.get_theme_font_size("font_size"))
		var spare: float = height - natural
		var spaced: FontVariation = FontVariation.new()
		spaced.base_font = base
		spaced.spacing_top = floori(spare / 2.0)
		spaced.spacing_bottom = int(spare) - floori(spare / 2.0)
		label.add_theme_font_override("font", spaced)
		var icon: Control = label.get_node_or_null(ReceiptInk.ICON_NAME) as Control
		if icon != null:
			icon.position.y = roundf((height - ReceiptInk.ICON_SIZE.y) / 2.0)
		var mark: Control = label.get_node_or_null("Mark") as Control
		if mark != null:
			var middle: float = roundf(height / 2.0)
			mark.offset_top = middle + ReceiptDecor.MARK_RECT.position.y
			mark.offset_bottom = middle + ReceiptDecor.MARK_RECT.end.y
