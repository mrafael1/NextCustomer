class_name PinUnlockCard
extends Control
## A badge pin's unlock card (the achievement unlock mock-up of 2026-11-05, look A "Pin card",
## docs/art/mockups/achievement_unlock.html): the pin on a shop backing card, as pins sold on a
## hook by the till, drawn on the 2 px art grid. A cream top with a hang slot, a header band in the
## pin's dark colour (NEW BADGE PIN), the pin's face (PinFace, 1.25 times the badge screen's) in a
## clear blister, its name, its rule (at most 3 lines), a green strip with the milestone met and
## the check mark, and a foot line with the profile's pin count. An UNLOCKED stamp sits in the
## empty top-right corner beside the hang slot, clear of the pin. Its back (show_back) is the
## face-down card the spotlight reveal flips over (PinReveal). PinReveal drives the pop of the pin
## and the stamp's landing (set_pop, set_stamp); a card left alone shows both landed. Display only:
## the reveal takes the clicks.

const CARD_SIZE := Vector2(200, 288)
const PX := 2.0
const HEADER_TEXT := "NEW BADGE PIN"
const FOOT_TEXT := "WEAR IT ON YOUR BUILD"
const UNIT_TEXT := "PINS"
const STAMP_TEXT := "UNLOCKED"
const BACK_TITLE := "NEXT CUSTOMER"
const BACK_MARK := "?"
## The pin's face: 30 art px across, centred in the blister.
const FACE_SIZE := 60.0
const FACE_CENTRE := Vector2(100, 104)
## The pin grows to this much of its size, then back, in whole art px (set_pop).
const POP_PEAK := 1.25
const POP_RISE := 0.6
## The stamp lands from this much of its size (set_stamp).
const STAMP_FROM := 2.2
const STAMP_CENTRE := Vector2(158, 15)
const STAMP_SIZE := 11
## The card's drop shadow, under it to the bottom right.
const SHADOW_OFFSET := Vector2(6, 6)
const SHADOW_ALPHA := 0.35
const BLISTER := Rect2(48, 60, 104, 90)
const BLISTER_ALPHA := 0.35
const GLINT_ALPHA := 0.75
## The idle glint (set_glint): a band GLINT_BAND art px wide crossing the face inside its rim
## (GLINT_RIM art px in), at GLINT_SWEEP_ALPHA.
const GLINT_BAND := 3
const GLINT_RIM := 3
const GLINT_SWEEP_ALPHA := 0.55
const NAME_RECT := Rect2(8, 158, 184, 26)
const NAME_SIZE := 22
const RULE_RECT := Rect2(12, 184, 176, 46)
const RULE_SIZE := 12
const RULE_LINES := 3
const STRIP := Rect2(12, 228, 176, 30)
const STRIP_SIZE := 13
## The foot line: its words left of the count, shrunk to fit.
const FOOT_RECT := Rect2(14, 266, 104, 20)
const FOOT_SIZE := 11
const CHECK := preload("res://art/icons/mark_check.png")
## A darkened card's overlay a step (set_depth: older cards peeking above the top one).
const DEPTH_ALPHA := 0.25
## The back's dotted pattern: a dot every DOT_STEP canvas px.
const DOT_STEP := 8

var _face: PinFace
var _stamp: Label
var _header: Label
var _name: Label
var _rule: Label
var _milestone: Label
var _count: Label
var _back: Control
var _glints: Control
var _depth: ColorRect
## The idle glint's progress across the face (0 to 1; outside: none).
var _glint: float = -1.0
## The header band's colour: the pin's dark band.
var _band: Color = Palette.TEAL_DARK


func _init() -> void:
	name = "PinUnlockCard"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	size = CARD_SIZE
	custom_minimum_size = CARD_SIZE
	pivot_offset = CARD_SIZE / 2.0
	_face = PinFace.new(FACE_SIZE)
	_face.position = FACE_CENTRE - Vector2.ONE * FACE_SIZE / 2.0
	_face.pivot_offset = Vector2.ONE * FACE_SIZE / 2.0
	add_child(_face)
	_glints = Control.new()
	_glints.name = "Glints"
	_glints.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_glints.size = CARD_SIZE
	_glints.draw.connect(_draw_glints.bind(_glints))
	add_child(_glints)
	_header = UiKit.display_label(HEADER_TEXT, 15, true)
	_header.add_theme_constant_override("outline_size", 0)
	_place(_header, Rect2(2, 28, 196, 22))
	_name = UiKit.display_label("", NAME_SIZE, false)
	_place(_name, NAME_RECT)
	_rule = UiKit.body_label("", RULE_SIZE, Palette.INK_LIGHT)
	_rule.add_theme_font_override("font", ArtStyle.bold_font(600))
	_rule.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_rule.max_lines_visible = RULE_LINES
	_rule.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	_rule.add_theme_constant_override("line_spacing", -1)
	_place(_rule, RULE_RECT)
	_milestone = UiKit.body_label("", STRIP_SIZE, Palette.INK)
	_milestone.add_theme_font_override("font", ArtStyle.bold_font(700))
	var strip_text: Rect2 = Rect2(
		STRIP.position.x + 36, STRIP.position.y + 4, STRIP.size.x - 40, STRIP.size.y - 4
	)
	_place(_milestone, strip_text, HORIZONTAL_ALIGNMENT_LEFT)
	var foot: Label = UiKit.display_label(FOOT_TEXT, FOOT_SIZE, false)
	foot.add_theme_color_override("font_color", Palette.MUTED_INK)
	_place(foot, FOOT_RECT, HORIZONTAL_ALIGNMENT_LEFT)
	_fit(foot, FOOT_SIZE, FOOT_RECT.size.x)
	_count = UiKit.number_label("", 15, false)
	_place(_count, Rect2(122, 265, 34, 20), HORIZONTAL_ALIGNMENT_RIGHT)
	var unit: Label = UiKit.display_label(UNIT_TEXT, 10, false)
	unit.add_theme_color_override("font_color", Palette.MUTED_INK)
	_place(unit, Rect2(158, 267, 30, 20), HORIZONTAL_ALIGNMENT_RIGHT)
	_stamp = _make_stamp()
	add_child(_stamp)
	_depth = ColorRect.new()
	_depth.name = "Depth"
	_depth.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_depth.size = CARD_SIZE
	_depth.visible = false
	add_child(_depth)
	_back = _make_back()
	add_child(_back)
	set_stamp(1.0)


## Shows `card`'s pin: its face, name, rule, milestone and the profile's count once it is owned.
func show_unlock(card: PinUnlockNews.Card) -> void:
	_face.show_pin(card.pin, card.index)
	_band = PinFace.COLOURS[PinFace.colour_index(card.pin, card.index)][1]
	_name.text = card.pin.display_name.to_upper()
	_fit(_name, NAME_SIZE, NAME_RECT.size.x)
	_rule.text = card.pin.rule_text
	_milestone.text = card.milestone()
	_fit(_milestone, STRIP_SIZE, _milestone.size.x)
	_count.text = "%d/%d" % [card.owned, card.total]
	queue_redraw()


## The idle glint at `progress` across the pin's face (0 to 1; outside: none).
func set_glint(progress: float) -> void:
	var shown: bool = progress >= 0.0 and progress < 1.0
	if not shown and _glint < 0.0:
		return
	_glint = progress if shown else -1.0
	_glints.queue_redraw()


func glint_progress() -> float:
	return _glint


## The pin's pop at `progress` (0: not in the blister yet, 1: landed): it grows to POP_PEAK of
## its size and back, its diameter in whole art px (4 canvas px steps); its icon keeps the art's
## whole scale (PinFace.set_pop_scale).
func set_pop(progress: float) -> void:
	var factor: float = 1.0
	if progress <= 0.0:
		factor = 0.0
	elif progress < POP_RISE:
		factor = progress / POP_RISE * POP_PEAK
	elif progress < 1.0:
		factor = POP_PEAK - (progress - POP_RISE) / (1.0 - POP_RISE) * (POP_PEAK - 1.0)
	var diameter: float = maxf(roundf(FACE_SIZE * factor / 4.0) * 4.0, 4.0)
	_face.visible = factor > 0.0
	_face.set_pop_scale(diameter / FACE_SIZE)


## The stamp's landing at `progress` (0: not yet, 1: landed), from STAMP_FROM of its size in
## whole art px steps, fading in; `shake` canvas px sideways.
func set_stamp(progress: float, shake: float = 0.0) -> void:
	_stamp.visible = progress > 0.0
	var factor: float = 1.0 if progress >= 1.0 else STAMP_FROM - (STAMP_FROM - 1.0) * progress
	var height: float = _stamp.size.y
	var stepped: float = roundf(height * factor / 4.0) * 4.0
	_stamp.scale = Vector2.ONE * (1.0 if progress >= 1.0 else maxf(stepped / height, 1.0))
	_stamp.modulate.a = minf(progress * 1.6, 1.0)
	_stamp.position = (STAMP_CENTRE - _stamp.size / 2.0 + Vector2(shake, 0)).snapped(
		Vector2.ONE * PX
	)


## The face-down back (true) or the front.
func show_back(on: bool) -> void:
	_back.visible = on


func is_back() -> bool:
	return _back.visible


## Darkens the card `depth` steps (0: none), as an older card under the top one.
func set_depth(depth: int) -> void:
	_depth.visible = depth > 0
	_depth.color = Color(Palette.TEAL_BLACK, DEPTH_ALPHA * depth)


## The pin's face (for tests).
func face() -> PinFace:
	return _face


## The UNLOCKED stamp (for tests).
func stamp() -> Label:
	return _stamp


## The card's words, top to bottom (for tests).
func texts() -> PackedStringArray:
	return PackedStringArray([_header.text, _name.text, _rule.text, _milestone.text, _count.text])


func _draw() -> void:
	var card: Rect2 = Rect2(Vector2.ZERO, CARD_SIZE)
	draw_rect(Rect2(SHADOW_OFFSET, CARD_SIZE), Color(Palette.INK, SHADOW_ALPHA))
	draw_rect(card, Palette.INK)
	draw_rect(card.grow(-PX), Palette.PAPER)
	draw_rect(Rect2(2, 2, 196, 26), Palette.CREAM)
	draw_rect(Rect2(2, 26, 196, 2), Palette.CREAM_SHADE)
	draw_rect(Rect2(82, 10, 36, 8), Palette.INK)  # The hang slot.
	draw_rect(Rect2(84, 12, 32, 4), Palette.TEAL_BLACK)
	draw_rect(Rect2(2, 28, 196, 24), _band)
	draw_rect(Rect2(2, 50, 196, 2), Palette.INK)
	_draw_blister()
	draw_rect(STRIP, Palette.GREEN_DARK)
	draw_rect(STRIP.grow(-PX), Palette.PAPER)
	draw_texture_rect(CHECK, Rect2(STRIP.position + Vector2(6, 2), CHECK.get_size() * PX), false)
	draw_rect(Rect2(12, 264, 176, 2), Palette.CREAM_SHADE)


## The clear blister the pin sits in: its back drop shadow, its pale fill and glass rim with
## stepped corners.
func _draw_blister() -> void:
	draw_rect(Rect2(52, 152, 104, 2), Palette.CREAM_SHADE)
	draw_rect(Rect2(154, 64, 2, 90), Palette.CREAM_SHADE)
	draw_rect(BLISTER, Color(Palette.GLASS_GLOW, BLISTER_ALPHA))
	for rect: Rect2 in [
		Rect2(52, 58, 96, 2),
		Rect2(52, 148, 96, 2),
		Rect2(46, 64, 2, 82),
		Rect2(152, 64, 2, 82),
		Rect2(48, 60, 4, 2),
		Rect2(148, 60, 4, 2),
		Rect2(48, 146, 4, 2),
		Rect2(148, 146, 4, 2),
		Rect2(48, 62, 2, 2),
		Rect2(150, 62, 2, 2),
		Rect2(48, 144, 2, 2),
		Rect2(150, 144, 2, 2),
	]:
		draw_rect(rect, Palette.GLASS)


## The blister's glints, over the pin.
func _draw_glints(on: Control) -> void:
	var glint: Color = Color(Palette.GLASS_GLOW, GLINT_ALPHA)
	on.draw_rect(Rect2(54, 66, 4, 30), glint)
	on.draw_rect(Rect2(54, 100, 4, 6), glint)
	on.draw_rect(Rect2(60, 66, 2, 10), glint)
	if _glint < 0.0:
		return
	# The idle glint: a band of whole art px rows, each clipped to the face inside its rim.
	var radius: int = roundi(FACE_SIZE / PX / 2.0) - GLINT_RIM
	var band: float = GLINT_BAND * PX
	var left: float = FACE_CENTRE.x - radius * PX - band
	var x: float = snappedf(lerpf(left, FACE_CENTRE.x + radius * PX, _glint), PX)
	var sweep: Color = Color(Palette.PAPER, GLINT_SWEEP_ALPHA)
	for row: int in range(-radius, radius):
		var dy: float = row + 0.5
		var half: float = roundf(sqrt(maxf(0.0, radius * radius - dy * dy))) * PX
		var from: float = maxf(x, FACE_CENTRE.x - half)
		var to: float = minf(x + band, FACE_CENTRE.x + half)
		if to > from:
			on.draw_rect(Rect2(from, FACE_CENTRE.y + row * PX, to - from, PX), sweep)


func _make_stamp() -> Label:
	var label: Label = UiKit.display_label(STAMP_TEXT, STAMP_SIZE, false)
	label.name = "Stamp"
	label.add_theme_color_override("font_color", Palette.GREEN_DARK)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	var box: StyleBoxFlat = StyleBoxFlat.new()
	box.bg_color = Palette.PAPER
	box.border_color = Palette.GREEN_DARK
	box.set_border_width_all(int(PX))
	box.content_margin_left = 5
	box.content_margin_right = 5
	box.content_margin_top = 0
	box.content_margin_bottom = 0
	label.add_theme_stylebox_override("normal", box)
	# Measured on the font: the label's own minimum size isn't up to date before it is in the tree.
	var font: Font = ArtStyle.DISPLAY_FONT
	var text: Vector2 = font.get_string_size(STAMP_TEXT, HORIZONTAL_ALIGNMENT_LEFT, -1, STAMP_SIZE)
	var wide: Vector2 = Vector2(text.x + 14.0, font.get_height(STAMP_SIZE) + 4.0)
	label.clip_text = true
	label.size = (wide / PX).ceil() * PX
	label.pivot_offset = label.size / 2.0
	return label


## The face-down back: the teal card with its dotted pattern, a grey "?" disc and the game's
## name.
func _make_back() -> Control:
	var back: Control = Control.new()
	back.name = "Back"
	back.mouse_filter = Control.MOUSE_FILTER_IGNORE
	back.size = CARD_SIZE
	back.visible = false
	back.draw.connect(_draw_back.bind(back))
	var mark: Label = UiKit.number_label(BACK_MARK, 30, false)
	mark.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	mark.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	mark.position = Vector2(76, 106)
	mark.size = Vector2(48, 48)
	back.add_child(mark)
	var title: Label = UiKit.display_label(BACK_TITLE, 15, false)
	title.add_theme_color_override("font_color", Palette.TEAL_PALE)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.position = Vector2(0, 188)
	title.size = Vector2(CARD_SIZE.x, 24)
	back.add_child(title)
	return back


func _draw_back(on: Control) -> void:
	var card: Rect2 = Rect2(Vector2.ZERO, CARD_SIZE)
	on.draw_rect(card, Palette.INK)
	on.draw_rect(card.grow(-PX), Palette.TEAL_DARK)
	on.draw_rect(card.grow(-8), Palette.TEAL_SHADE)
	for y: int in range(12, int(CARD_SIZE.y) - 12, DOT_STEP):
		var from: int = 12 + (4 if y % 16 != 0 else 0)
		for x: int in range(from, int(CARD_SIZE.x) - 12, DOT_STEP):
			on.draw_rect(Rect2(x, y, 2, 2), Palette.TEAL_DARK)
	_disc(on, Vector2(100, 130), 22, Palette.INK)
	_disc(on, Vector2(100, 130), 21, Palette.GREY)
	_disc(on, Vector2(100, 130), 19, Palette.GREY_LIGHT)


## A disc `radius` art px round `centre`, on the art grid.
static func _disc(on: CanvasItem, centre: Vector2, radius: int, colour: Color) -> void:
	for row: int in range(-radius, radius):
		var dy: float = row + 0.5
		var half: int = roundi(sqrt(maxf(radius * radius - dy * dy, 0.0)))
		if half > 0:
			on.draw_rect(
				Rect2(centre.x - half * PX, centre.y + row * PX, half * 2 * PX, PX), colour
			)


func _place(
	label: Label, rect: Rect2, align: HorizontalAlignment = HORIZONTAL_ALIGNMENT_CENTER
) -> void:
	label.horizontal_alignment = align
	if label.vertical_alignment != VERTICAL_ALIGNMENT_TOP:
		label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.position = rect.position
	label.size = rect.size
	label.clip_text = label.autowrap_mode == TextServer.AUTOWRAP_OFF
	add_child(label)


## Shrinks `label`'s font from `font_size` until its text fits `width`.
static func _fit(label: Label, font_size: int, width: float) -> void:
	var font: Font = label.get_theme_font("font")
	var fitted: int = font_size
	var align: HorizontalAlignment = HORIZONTAL_ALIGNMENT_LEFT
	while fitted > 8 and font.get_string_size(label.text, align, -1, fitted).x > width:
		fitted -= 1
	label.add_theme_font_size_override("font_size", fitted)
