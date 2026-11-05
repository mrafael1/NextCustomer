class_name MonitorLeader
extends Control
## A dotted leader on an item column row (PR #138 round 4's DOTTED look; round 5: on every row and
## the base line, MonitorBaseLine): DOT px dots every PITCH px from GAP after the end of the row's
## text (its last line, or its "from the bag" note) to GAP before its amount's digits, like a
## receipt's or a menu's, on the 2 px grid and in columns shared by every row. Measured when drawn,
## from the row's own parts (MonitorStepRow.make's Text, FromBag and Amount), so a page's even text
## size (MonitorStepRow.even_sizes) and the count's note are counted. A row cut past its lines or
## with no amount draws none. Display only.
##
## Each dot is snapped to whole screen pixels (PR #138 round 7, the user's "are dots drawn? at
## 1920*1080, it feel like they have different sizes"): at a fractional screen scale (1.5 at
## 1080p, or a window a few px short of it) a dot DOT px wide on a fractional origin covered 2
## screen px or 3. dots() lays them in screen space instead: every dot round(DOT × scale) px square
## at whole screen px, round(PITCH × scale) px apart from the span's snapped start, mapped back to
## the row, so every dot of every row is the same size on screen (DOT and PITCH exactly at scale
## 1). It draws again when its place on screen changes (the window's size, its transform).

const DOT := 2.0
const PITCH := 4.0
const GAP := 4.0
## The dots' top from their line's top (just over the text's baseline).
const DOT_TOP := 10.0
const COLOR := Palette.CREAM_DARKEST


func _init(row_size: Vector2) -> void:
	name = "Leader"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	size = row_size
	set_notify_transform(true)


func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSFORM_CHANGED:
		queue_redraw()
	elif what == NOTIFICATION_ENTER_TREE:
		var shown: Viewport = get_viewport()
		if shown != null and not shown.size_changed.is_connected(queue_redraw):
			shown.size_changed.connect(queue_redraw)


## The dots' span on the row (x from, x to, the line's top), or an empty one when it draws none.
func span() -> Vector3:
	var row: Control = get_parent() as Control
	if row == null:
		return Vector3.ZERO
	var text: Label = row.get_node_or_null("Text") as Label
	var amount: Label = row.get_node_or_null("Amount") as Label
	if text == null or amount == null or row.get_node_or_null("WholeLine") != null:
		return Vector3.ZERO
	var lines: int = maxi(roundi(text.size.y / MonitorStepRow.ROW_PITCH), 1)
	var end: float = text.position.x + last_line_width(text, lines)
	var note: Label = row.get_node_or_null("FromBag") as Label
	if note != null:
		end = note.position.x + MonitorStepRow.text_width(note)
	var digits: float = amount.position.x + amount.size.x - MonitorStepRow.text_width(amount)
	var from: float = PITCH * ceilf((end + GAP) / PITCH)
	var to: float = digits - GAP
	if to - from < PITCH + DOT:
		return Vector3.ZERO
	return Vector3(from, to, (lines - 1) * MonitorStepRow.ROW_PITCH)


func _draw() -> void:
	for dot: Rect2 in dots():
		draw_rect(dot, COLOR)


## The dots as drawn (this control's coordinates), each on whole screen pixels under its screen
## transform (the canvas's and the viewport's final one, so the window's stretch counts): see the
## class comment.
func dots() -> Array[Rect2]:
	var at: Vector3 = span()
	if at.y <= at.x:
		return []
	if not is_inside_tree():
		return snapped_dots(at, Transform2D.IDENTITY)
	# The viewport's final transform carries the window's stretch (canvas_items: 1.5 at 1080p).
	var screen: Transform2D = (
		get_viewport().get_final_transform() * get_global_transform_with_canvas()
	)
	return snapped_dots(at, screen)


## The dots of a span `at` (span()'s: from, to, the line's top) under `screen` (this control's
## coordinates to screen pixels; only its scale and origin count), each a whole number of screen
## px square at whole screen px, back in this control's coordinates. Pure.
static func snapped_dots(at: Vector3, screen: Transform2D) -> Array[Rect2]:
	var found: Array[Rect2] = []
	var zoom: Vector2 = screen.get_scale()
	if zoom.x <= 0.0 or zoom.y <= 0.0:
		return found
	var side: Vector2 = Vector2(maxf(1.0, roundf(DOT * zoom.x)), maxf(1.0, roundf(DOT * zoom.y)))
	var step: float = maxf(side.x + 1.0, roundf(PITCH * zoom.x))
	var start: Vector2 = (screen * Vector2(at.x, at.z + DOT_TOP)).round()
	var end: float = (screen * Vector2(at.y, 0.0)).x
	var back: Transform2D = screen.affine_inverse()
	var x: float = start.x
	while x + side.x <= end + 0.01:
		var corner: Vector2 = back * Vector2(x, start.y)
		found.append(Rect2(corner, side / zoom))
		x += step
	return found


## The width of `text`'s last line as wrapped in its box on `lines` lines (by its own autowrap
## mode, as the Label wraps it).
static func last_line_width(text: Label, lines: int) -> float:
	if lines <= 1:
		return MonitorStepRow.text_width(text)
	var paragraph: TextParagraph = TextParagraph.new()
	paragraph.add_string(
		text.text, text.get_theme_font("font"), text.get_theme_font_size("font_size")
	)
	paragraph.width = text.size.x
	paragraph.break_flags = TextServer.BREAK_MANDATORY | _wrap_flags(text.autowrap_mode)
	var count: int = paragraph.get_line_count()
	return ceilf(paragraph.get_line_size(count - 1).x)


## The line break flags a Label's `mode` wraps by (Label's own mapping).
static func _wrap_flags(mode: TextServer.AutowrapMode) -> int:
	match mode:
		TextServer.AUTOWRAP_ARBITRARY:
			return TextServer.BREAK_GRAPHEME_BOUND
		TextServer.AUTOWRAP_WORD_SMART:
			return TextServer.BREAK_WORD_BOUND | TextServer.BREAK_ADAPTIVE
	return TextServer.BREAK_WORD_BOUND
