class_name TipCard
extends Control
## The game's one hover tip (the hover tips revamp, design B "paper card", mock-up
## docs/art/mockups/hover_tips.html; approved 2026-11-13), grown from the badge pin's card (PinTip,
## approved 2026-11-02): the pin_card 9-slice (an ink outline, a cream shade foot) with its hard ink
## drop shadow and its tail (pin_card_tail) pointing at the hovered thing. It draws a TipSpec:
##
## - a header band in the kind's colour (KIND_BANDS: mustard keyword, the family's own face, teal
##   perk, slate status, brass pin, cream shade coupon, cream price and item, tomato for something
##   not working, paper for a plain word with a dotted rule under it) holding the thing's icon in a
##   paper box, its title in the chunky capitals (TipTitle) and its tag on a darker chip;
## - its rule (TipText, BODY_SIZE px), a muted fine-print line (COND_SIZE px) and a live line with
##   a dot (teal OK and INFO, a tomato cross BAD, grey OFF);
## - a footer of key caps when the tip does something: SHIFT KEPT (a kept tip), CLICK <action>,
##   RIGHT-CLICK HANDBOOK.
##
## A box (`sub`, a keyword's or a word's, TipWords) is SUB_WIDTH wide, with no tail and no footer.
## place() and place_boxes() are the pure placement rules (GlyphTips): the card opens on a side of
## its target (Opens), GAP off it, kept MARGIN inside the screen (its shadow too), its tail sliding
## along the edge to keep pointing at the target; boxes stack beside it on the side away from the
## nearest edge, or under (over) it when neither side has room. Display only: it takes no clicks
## (a kept tip's GlyphTips takes them).

enum Opens { BELOW, ABOVE, RIGHT, LEFT }

const WIDTH := 256.0
const SUB_WIDTH := 172.0
## The frame's border (pin_card's 3 art px), the room inside it and the header's padding.
const FRAME_MARGIN := 3
const BORDER := 6.0
const PAD_X := 10.0
const HEAD_PAD := 4.0
const ICON_BOX := 26.0
const SUB_ICON_BOX := 22.0
const ICON_BORDER := 2.0
const RULE_LINE := 2.0
const HEAD_GAP := 6.0
const TAG_PAD := Vector2(4, 3)
const BODY_SIZE := 14
const BODY_WEIGHT := 800
const SUB_BODY_SIZE := 12
const COND_SIZE := 12
const COND_WEIGHT := 700
const LIVE_SIZE := 12
const LIVE_WEIGHT := 800
const BODY_TOP := 6.0
const LINE_GAP := 3.0
const DOT := 8.0
const DOT_GAP := 5.0
const FOOT_GAP := 4.0
const FOOT_PAD := 4.0
const KEY_GAP := 8.0
const KEY_BORDER := 2.0
const KEY_PAD := Vector2(3, 2)
const DOT_DASH := 2.0
const BOTTOM := 6.0
const SHADOW := Vector2(4, 4)
const SHADOW_ALPHA := 0.42
const TAIL_SIZE := Vector2(14, 8)
## The tail's reach past the card's edge (its last rows lie on the outline) and its inset.
const TAIL_OUT := 6.0
const TAIL_INSET := 8.0
## Placement: the gap to the target, the least room from the screen's edges, the boxes' gap.
const GAP := 14.0
const MARGIN := 16.0
const BOX_GAP := 8.0
const PX := 2.0
## The footer's words.
const KEY_SHIFT := "SHIFT"
const KEPT_WORD := "KEPT"
const KEY_CLICK := "CLICK"
const KEY_RIGHT_CLICK := "RIGHT-CLICK"
const GUIDE_WORD := "HANDBOOK"
const FRAME := preload("res://art/frames/pin_card.png")
const TAIL := preload("res://art/frames/pin_card_tail.png")
const FIZZLE := preload("res://art/icons/fizzle.png")
const PAIR_CLASP := preload("res://art/icons/pair_clasp.png")
## Each kind's band and title colours, [band, ink].
const KIND_BANDS: Dictionary[TipSpec.Kind, Array] = {
	TipSpec.Kind.WORD: [Palette.PAPER, Palette.INK_LIGHT],
	TipSpec.Kind.KEYWORD: [Palette.MUSTARD, Palette.INK],
	TipSpec.Kind.FAMILY: [Palette.CREAM_SHADE, Palette.INK],
	TipSpec.Kind.PERK: [Palette.TEAL, Palette.PAPER],
	TipSpec.Kind.STATUS: [Palette.SLATE, Palette.GOLD],
	TipSpec.Kind.PIN: [Palette.BRASS, Palette.INK],
	TipSpec.Kind.COUPON: [Palette.CREAM_SHADE, Palette.INK],
	TipSpec.Kind.PRICE: [Palette.CREAM, Palette.INK],
	TipSpec.Kind.ITEM: [Palette.CREAM, Palette.INK],
	TipSpec.Kind.BROKEN: [Palette.TOMATO, Palette.PAPER],
}
const LIVE_COLOURS: Dictionary[TipSpec.Live, Color] = {
	TipSpec.Live.INFO: Palette.TEAL_SHADE,
	TipSpec.Live.OK: Palette.TEAL_SHADE,
	TipSpec.Live.BAD: Palette.TOMATO_DARK,
	TipSpec.Live.OFF: Palette.MUTED_INK,
}

## The spec shown, whether it is a box, whether it is kept (Shift) and the side it opened on.
var spec: TipSpec
var sub: bool = false
var kept: bool = false
var side: Opens = Opens.BELOW
## A card narrower than WIDTH where its room is tight (the badge pin's, PinTip); 0: WIDTH.
var width_override: float = 0.0
## A node drawn in the icon box in place of the spec's icon (the badge pin's face, PinTip).
var icon_node: Control
var _shadow: ColorRect
var _frame: Panel
var _tail: TextureRect
## The header band and the marks over the frame (the rules, the live dot).
var _band: ColorRect
var _marks: Control
## The parts rebuilt for each spec.
var _parts: Array[Node] = []
var _title: TipTitle
var _body: TipText
var _cond: TipText
var _live: TipText
var _keys: Array[String] = []
var _head_height: float = 0.0
var _band_colour: Color = Palette.PAPER
var _band_ink: Color = Palette.INK
var _foot_top: float = -1.0
var _live_dot: Rect2 = Rect2()


func _init(is_sub: bool = false) -> void:
	name = "TipCard"
	sub = is_sub
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_shadow = ColorRect.new()
	_shadow.name = "Shadow"
	_shadow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_shadow.position = SHADOW
	_shadow.color = Color(Palette.INK, SHADOW_ALPHA)
	add_child(_shadow)
	_frame = Panel.new()
	_frame.name = "Frame"
	_frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_frame.add_theme_stylebox_override("panel", ArtStyle.frame_style(FRAME, FRAME_MARGIN))
	ArtStyle.use_pixel_material(_frame)
	add_child(_frame)
	_band = ColorRect.new()
	_band.name = "Band"
	_band.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_band)
	_marks = Control.new()
	_marks.name = "Marks"
	_marks.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_marks.draw.connect(_draw_marks)
	add_child(_marks)
	_tail = UiKit.sprite(TAIL)
	_tail.name = "Tail"
	_tail.size = TAIL_SIZE
	_tail.pivot_offset = TAIL_SIZE / 2.0
	_tail.visible = not is_sub
	add_child(_tail)


## The card's width (a box's narrower).
func card_width() -> float:
	if width_override > 0.0:
		return width_override
	return SUB_WIDTH if sub else WIDTH


## Builds the card for `tip` (kept: its footer shows SHIFT KEPT); its size follows.
func show_spec(tip: TipSpec, is_kept: bool = false) -> void:
	spec = tip
	kept = is_kept
	for part: Node in _parts:
		remove_child(part)
		part.queue_free()
	_parts.clear()
	_title = null
	_body = null
	_cond = null
	_live = null
	var width: float = card_width()
	var colours: Array = band_of(tip)
	_band_colour = colours[0]
	_band_ink = colours[1]
	var y: float = _build_head(tip, width)
	var inner: float = width - (BORDER + PAD_X) * 2.0
	var left: float = BORDER + PAD_X
	y += BODY_TOP
	if not tip.body.is_empty():
		_body = _text(
			"Body", tip.body, SUB_BODY_SIZE if sub else BODY_SIZE, BODY_WEIGHT, Palette.INK
		)
		_body = _put(_body, left, y, inner)
		y += _body.size.y
	if not tip.cond.is_empty():
		y += LINE_GAP
		_cond = _put(
			_text("Cond", tip.cond, COND_SIZE, COND_WEIGHT, Palette.GREY_DARK), left, y, inner
		)
		y += _cond.size.y
	_live_dot = Rect2()
	if not tip.live.is_empty():
		y += LINE_GAP
		var room: float = DOT + DOT_GAP
		var colour: Color = LIVE_COLOURS[tip.live_kind]
		_live = _put(
			_text("Live", tip.live, LIVE_SIZE, LIVE_WEIGHT, colour, inner - room),
			left + room,
			y,
			inner - room
		)
		var dot_top: float = y + roundf((TipText.pitch_for(LIVE_SIZE) - DOT) / 2.0)
		_live_dot = Rect2(left, dot_top, DOT, DOT)
		y += _live.size.y
	_keys = [] as Array[String]
	if not sub:
		_keys = footer_keys(tip, kept)
	_foot_top = -1.0
	if not _keys.is_empty():
		y += FOOT_GAP
		_foot_top = y
		y += RULE_LINE + FOOT_PAD
		y = _build_keys(width, y)
	y += BOTTOM + BORDER
	size = Vector2(width, ceilf(y / PX) * PX)
	_shadow.size = size
	_frame.size = size
	_band.position = Vector2(BORDER, BORDER)
	_band.size = Vector2(width - BORDER * 2.0, _head_height)
	_band.color = _band_colour
	_marks.size = size
	_marks.queue_redraw()


## The footer's keys, [key, word] pairs flattened: SHIFT KEPT when kept, CLICK <action>,
## RIGHT-CLICK HANDBOOK.
static func footer_keys(tip: TipSpec, is_kept: bool) -> Array[String]:
	var found: Array[String] = []
	if is_kept:
		found.append_array([KEY_SHIFT, KEPT_WORD])
	if not tip.click.is_empty():
		found.append_array([KEY_CLICK, tip.click])
	if tip.guide:
		found.append_array([KEY_RIGHT_CLICK, GUIDE_WORD])
	return found


## A spec's band and title colours, [band, ink]: a family tip's own when set, else its kind's.
static func band_of(tip: TipSpec) -> Array:
	if tip.band.a > 0.0:
		return [tip.band, tip.band_ink if tip.band_ink.a > 0.0 else Palette.INK]
	return KIND_BANDS[tip.kind]


## A keyword's icon (its family's glyph; PAIR's clasp, WASTED's fizzle), or null.
static func keyword_icon(word: String) -> Texture2D:
	if word == CardText.PAIR_WORD:
		return PAIR_CLASP
	if word == CardText.WASTED_WORD:
		return FIZZLE
	var family: Resource = KeywordChip.dot_family(word)
	return family.get("glyph") as Texture2D if family != null else null


func title_text() -> String:
	return _title.text if _title != null else ""


func body() -> TipText:
	return _body


func cond() -> TipText:
	return _cond


func live() -> TipText:
	return _live


func tail() -> TextureRect:
	return _tail


func band_colour() -> Color:
	return _band_colour


func keys() -> Array[String]:
	return _keys


## Its words (the spec's plain words), for checks.
func tip_text() -> String:
	return spec.source if spec != null else ""


## Puts the tail on the card's edge facing `target` (this card's parent's coordinates) for `on`.
func point_tail(on: Opens, target: Rect2) -> void:
	side = on
	_tail.visible = not sub
	_tail.flip_v = false
	_tail.rotation = 0.0
	var centre: Vector2 = target.get_center() - position
	if on == Opens.BELOW or on == Opens.ABOVE:
		var x: float = clampf(
			roundf((centre.x - TAIL_SIZE.x / 2.0) / PX) * PX,
			TAIL_INSET,
			size.x - TAIL_INSET - TAIL_SIZE.x
		)
		if on == Opens.BELOW:
			_tail.position = Vector2(x, -TAIL_OUT)
			pivot_offset = Vector2(x + TAIL_SIZE.x / 2.0, -TAIL_OUT)
		else:
			_tail.flip_v = true
			_tail.position = Vector2(x, size.y - TAIL_SIZE.y + TAIL_OUT)
			pivot_offset = Vector2(x + TAIL_SIZE.x / 2.0, size.y + TAIL_OUT)
		return
	var y: float = clampf(
		roundf((centre.y - TAIL_SIZE.x / 2.0) / PX) * PX,
		TAIL_INSET,
		size.y - TAIL_INSET - TAIL_SIZE.x
	)
	# Turned a quarter: its centre TAIL_SIZE.y / 2 outside the edge, less the overlap.
	var reach: float = TAIL_OUT - TAIL_SIZE.y / 2.0
	var middle: Vector2
	if on == Opens.RIGHT:
		_tail.rotation = -PI / 2.0
		middle = Vector2(-reach, y + TAIL_SIZE.x / 2.0)
		pivot_offset = Vector2(-TAIL_OUT, middle.y)
	else:
		_tail.rotation = PI / 2.0
		middle = Vector2(size.x + reach, y + TAIL_SIZE.x / 2.0)
		pivot_offset = Vector2(size.x + TAIL_OUT, middle.y)
	_tail.position = middle - TAIL_SIZE / 2.0


## The card's box for a target at `target` (its ticket at `anchor`: a card opening below opens
## under the anchor) opening on `want`, `card_size` big, inside `screen` (all in one set of
## coordinates): [Rect2, Opens]. A side with no room flips to its opposite; the box is then kept
## MARGIN inside the screen (its shadow too), on the 2 px grid.
static func place(
	target: Rect2, anchor: Rect2, want: Opens, card_size: Vector2, screen: Rect2
) -> Array:
	var on: Opens = want
	var top: float = screen.position.y + MARGIN
	var bottom: float = screen.end.y - MARGIN - SHADOW.y
	var left_edge: float = screen.position.x + MARGIN
	var right_edge: float = screen.end.x - MARGIN - SHADOW.x
	var foot: float = maxf(target.end.y, anchor.end.y)
	if (
		on == Opens.BELOW
		and foot + GAP + card_size.y > bottom
		and target.position.y - GAP - card_size.y >= top
	):
		on = Opens.ABOVE
	elif (
		on == Opens.ABOVE
		and target.position.y - GAP - card_size.y < top
		and foot + GAP + card_size.y <= bottom
	):
		on = Opens.BELOW
	elif (
		on == Opens.RIGHT
		and target.end.x + GAP + card_size.x > right_edge
		and target.position.x - GAP - card_size.x >= left_edge
	):
		on = Opens.LEFT
	elif (
		on == Opens.LEFT
		and target.position.x - GAP - card_size.x < left_edge
		and target.end.x + GAP + card_size.x <= right_edge
	):
		on = Opens.RIGHT
	var centre: Vector2 = target.get_center()
	var at: Vector2
	match on:
		Opens.BELOW:
			at = Vector2(centre.x - card_size.x / 2.0, foot + GAP)
		Opens.ABOVE:
			at = Vector2(centre.x - card_size.x / 2.0, target.position.y - GAP - card_size.y)
		Opens.RIGHT:
			at = Vector2(target.end.x + GAP, centre.y - card_size.y / 2.0)
		_:
			at = Vector2(target.position.x - GAP - card_size.x, centre.y - card_size.y / 2.0)
	at.x = clampf(at.x, left_edge, maxf(left_edge, right_edge - card_size.x))
	at.y = clampf(at.y, top, maxf(top, bottom - card_size.y))
	at = (at / PX).floor() * PX
	return [Rect2(at, card_size), on]


## The boxes' rects beside a card at `card` that opened on `on` from `target`, `sizes` big,
## inside `screen`: stacked BOX_GAP apart beside the card, top-aligned with it (bottom-aligned when
## it opened above). A card that opened RIGHT or LEFT keeps them on its far side, away from the
## target; one that opened BELOW or ABOVE takes the side with more room, then the other. The first
## spot that fits the screen and covers neither the card nor the target wins; with none beside it,
## stacked under the card (over it when it opened above), then on the other end; the last resort
## is clamped inside the screen.
static func place_boxes(
	card: Rect2, on: Opens, sizes: Array[Vector2], screen: Rect2, target: Rect2 = Rect2()
) -> Array[Rect2]:
	var placed: Array[Rect2] = []
	if sizes.is_empty():
		return placed
	var width: float = 0.0
	var total: float = -BOX_GAP
	for box: Vector2 in sizes:
		width = maxf(width, box.x)
		total += box.y + BOX_GAP
	var top: float = screen.position.y + MARGIN
	var bottom: float = screen.end.y - MARGIN - SHADOW.y
	var left_edge: float = screen.position.x + MARGIN
	var right_edge: float = screen.end.x - MARGIN - SHADOW.x
	var shadowed: Rect2 = card.merge(Rect2(card.position + SHADOW, card.size))
	var right_x: float = card.end.x + SHADOW.x + BOX_GAP
	var left_x: float = card.position.x - BOX_GAP - width
	var beside_y: float = card.position.y if on != Opens.ABOVE else card.end.y - total
	beside_y = clampf(beside_y, top, maxf(top, bottom - total))
	var under: float = card.end.y + SHADOW.y + BOX_GAP
	var over: float = card.position.y - BOX_GAP - total
	var stack_x: float = clampf(card.position.x, left_edge, maxf(left_edge, right_edge - width))
	var spots: Array[Vector2] = []
	match on:
		Opens.RIGHT:
			spots.append(Vector2(right_x, beside_y))
		Opens.LEFT:
			spots.append(Vector2(left_x, beside_y))
		_:
			var room_right: float = right_edge - right_x
			var room_left: float = card.position.x - BOX_GAP - left_edge
			if room_right >= room_left:
				spots.append_array([Vector2(right_x, beside_y), Vector2(left_x, beside_y)])
			else:
				spots.append_array([Vector2(left_x, beside_y), Vector2(right_x, beside_y)])
	if on == Opens.ABOVE:
		spots.append_array([Vector2(stack_x, over), Vector2(stack_x, under)])
	else:
		spots.append_array([Vector2(stack_x, under), Vector2(stack_x, over)])
	var inside: Rect2 = Rect2(left_edge, top, right_edge - left_edge, bottom - top)
	var at: Vector2 = Vector2(stack_x, under if on != Opens.ABOVE else over)
	var found: bool = false
	for spot: Vector2 in spots:
		var stack: Rect2 = Rect2((spot / PX).floor() * PX, Vector2(width, total))
		if not inside.encloses(stack) or stack.intersects(shadowed):
			continue
		if target.has_area() and stack.intersects(target):
			continue
		at = spot
		found = true
		break
	if not found:
		at.y = clampf(at.y, top, maxf(top, bottom - total))
	for box: Vector2 in sizes:
		placed.append(Rect2((at / PX).floor() * PX, box))
		at.y += box.y + BOX_GAP
	return placed


func _build_head(tip: TipSpec, width: float) -> float:
	var box_size: float = SUB_ICON_BOX if sub else ICON_BOX
	var x: float = BORDER + HEAD_PAD
	var y: float = BORDER + HEAD_PAD
	var icon: Texture2D = tip.icon
	if icon == null and tip.kind == TipSpec.Kind.KEYWORD:
		icon = keyword_icon(tip.title)
	var has_icon: bool = icon != null or icon_node != null
	if icon_node != null:
		_rect("IconBox", Rect2(x, y, box_size, box_size), Palette.INK)
		_rect("IconFace", Rect2(x, y, box_size, box_size).grow(-ICON_BORDER), Palette.PAPER)
		if icon_node.get_parent() != self:
			add_child(icon_node)
		move_child(icon_node, -1)
		icon_node.position = (
			(Vector2(x, y) + (Vector2.ONE * box_size - icon_node.size) / 2.0).floor()
		)
		x += box_size + HEAD_GAP
	elif has_icon:
		_rect("IconBox", Rect2(x, y, box_size, box_size), Palette.INK)
		var face: Color = Palette.TEAL_DARK if tip.kind == TipSpec.Kind.STATUS else Palette.PAPER
		_rect("IconFace", Rect2(x, y, box_size, box_size).grow(-ICON_BORDER), face)
		var glyph: TextureRect = UiKit.sprite(icon)
		glyph.name = "Icon"
		var scale_by: float = 2.0
		var art: Vector2 = icon.get_size()
		while scale_by > 1.0 and (art * scale_by).x > box_size - ICON_BORDER * 2.0:
			scale_by -= 1.0
		if (art * scale_by).y > box_size - ICON_BORDER * 2.0:
			scale_by = 1.0
		glyph.size = art * scale_by
		glyph.position = (Vector2(x, y) + (Vector2.ONE * box_size - glyph.size) / 2.0).floor()
		_add(glyph)

		x += box_size + HEAD_GAP
	var tag_label: Label = null
	var tag_size: Vector2 = Vector2.ZERO
	if not tip.tag.is_empty():
		tag_label = UiKit.pixel_label(tip.tag.to_upper(), 1, _band_ink)
		tag_label.name = "Tag"
		tag_size = caps_size(tag_label.text) + TAG_PAD * 2.0
		tag_size = (tag_size / PX).ceil() * PX
	var right: float = width - BORDER - HEAD_PAD
	var room: float = right - x - (tag_size.x + HEAD_GAP if tag_label != null else 0.0)
	var cell: float = 2.0
	var wide: float = TipTitle.width_of(tip.title.to_upper(), cell)
	if tag_label != null and wide > room and wide <= right - x:
		# A title that fits the row alone keeps one line: the tag drops under it (below).
		room = wide
	elif wide > room and sub:
		cell = 1.0
	_title = TipTitle.new(tip.title, _band_ink, maxf(room, 40.0), cell)
	var row: float = maxf(box_size if has_icon else 0.0, _title.size.y)
	row = maxf(row, tag_size.y)
	_title.position = Vector2(x, y + roundf((row - _title.size.y) / PX / 2.0) * PX)
	_add(_title)
	if tag_label != null:
		var tag_at: Vector2 = Vector2(
			right - tag_size.x, y + roundf((row - tag_size.y) / PX / 2.0) * PX
		)
		if x + _title.size.x + HEAD_GAP > tag_at.x:
			# No room beside the title: the tag drops under it, at the right.
			tag_at.y = y + row + HEAD_PAD / 2.0
			row += tag_size.y + HEAD_PAD / 2.0
		_rect("TagFace", Rect2(tag_at, tag_size), Color(Palette.INK, 0.16))
		UiKit.place_pixel_label(tag_label, Rect2(tag_at + Vector2(TAG_PAD.x, 0), tag_size), true)
		_add(tag_label)
	_head_height = ceilf((HEAD_PAD * 2.0 + row) / PX) * PX
	return BORDER + _head_height + RULE_LINE


## The size of `words` in the chips' pixel capitals: their width by the capitals' height.
static func caps_size(words: String) -> Vector2:
	var font: Font = ArtStyle.pixel_display_font()
	var width: float = (
		font.get_string_size(words, HORIZONTAL_ALIGNMENT_LEFT, -1, ArtStyle.PIXEL_TEXT_SIZE).x
	)
	return Vector2(ceilf(width), ArtStyle.PIXEL_CAP_HEIGHT)


## The footer's key pairs, right-aligned in rows from `y`: a pair that would run past the card's
## left padding starts a new row under the last (a kept tip with a CLICK and the handbook key needs
## more than one 256 px row). Returns the foot's bottom.
func _build_keys(width: float, y: float) -> float:
	var room: float = width - 2.0 * (BORDER + PAD_X)
	var pairs: int = int(_keys.size() / 2.0)
	var widths: Array[float] = []
	for index: int in range(pairs):
		var cap_width: float = caps_size(_keys[index * 2]).x + KEY_PAD.x * 2.0 + KEY_BORDER * 2.0
		widths.append(cap_width + 4.0 + caps_size(_keys[index * 2 + 1]).x)
	var rows: Array[Array] = []
	var row: Array[int] = []
	var used: float = 0.0
	for index: int in range(pairs):
		var need: float = widths[index] + (KEY_GAP if not row.is_empty() else 0.0)
		if not row.is_empty() and used + need > room:
			rows.append(row)
			row = []
			used = 0.0
			need = widths[index]
		row.append(index)
		used += need
	if not row.is_empty():
		rows.append(row)
	var top: float = y
	for line: Array in rows:
		var x: float = width - BORDER - PAD_X
		var height: float = 0.0
		for at: int in range(line.size() - 1, -1, -1):
			var index: int = line[at]
			height = maxf(height, _build_key(index, x, top))
			x -= widths[index] + KEY_GAP
		top += height + LINE_GAP
	return top - (LINE_GAP if not rows.is_empty() else 0.0)


## Key pair `index` (its cap and word) with its right end at `right`, from row `y`: its height.
func _build_key(index: int, right: float, y: float) -> float:
	var word: Label = UiKit.pixel_label(_keys[index * 2 + 1], 1, Palette.MUTED_INK)
	word.name = "KeyWord%d" % index
	var word_size: Vector2 = caps_size(word.text)
	var cap: Label = UiKit.pixel_label(_keys[index * 2], 1, Palette.MUTED_INK)
	cap.name = "Key%d" % index
	var cap_size: Vector2 = (
		caps_size(cap.text) + KEY_PAD * 2.0 + Vector2(KEY_BORDER * 2.0, KEY_BORDER * 3.0)
	)
	var x: float = right - word_size.x
	UiKit.place_pixel_label(word, Rect2(x, y, word_size.x + 2.0, cap_size.y - 1.0), true)
	_add(word)
	x -= 4.0 + cap_size.x
	var cap_rect: Rect2 = Rect2(Vector2(x, y), cap_size)
	_rect("KeyCap%d" % index, cap_rect, Palette.MUTED_INK)
	_rect(
		"KeyFace%d" % index,
		Rect2(
			cap_rect.position + Vector2.ONE * KEY_BORDER,
			cap_size - Vector2(KEY_BORDER * 2.0, KEY_BORDER * 3.0)
		),
		Palette.PAPER
	)
	var face: Rect2 = Rect2(
		cap_rect.position + Vector2(KEY_BORDER + KEY_PAD.x, KEY_BORDER),
		Vector2(cap_size.x, cap_size.y - KEY_BORDER * 3.0)
	)
	UiKit.place_pixel_label(cap, face, true)
	_add(cap)
	return cap_size.y


func _text(
	part: String, markup: String, font_size: int, weight: int, colour: Color, width: float = -1.0
) -> TipText:
	var room: float = width if width > 0.0 else card_width() - (BORDER + PAD_X) * 2.0
	var text: TipText = TipText.new(markup, font_size, weight, colour, room)
	text.name = part
	return text


func _put(text: TipText, x: float, y: float, _width: float) -> TipText:
	text.position = Vector2(x, y)
	_add(text)
	return text


func _rect(part: String, rect: Rect2, colour: Color) -> ColorRect:
	var shape: ColorRect = ColorRect.new()
	shape.name = part
	shape.mouse_filter = Control.MOUSE_FILTER_IGNORE
	shape.position = rect.position
	shape.size = rect.size
	shape.color = colour
	_add(shape)
	return shape


func _add(node: Node) -> void:
	add_child(node)
	# The icon node and the tail draw over everything (the tail's rows lie on the outline).
	if icon_node != null and icon_node.get_parent() == self:
		move_child(icon_node, -1)
	move_child(_tail, -1)
	_parts.append(node)


func _draw_marks() -> void:
	# The rule under the header band (dotted on a word's box), the live dot, the footer's dots.
	var rule: Rect2 = Rect2(BORDER, BORDER + _head_height, size.x - BORDER * 2.0, RULE_LINE)
	if spec != null and spec.kind == TipSpec.Kind.WORD:
		_dots(rule, Palette.MUTED_INK)
	else:
		_marks.draw_rect(rule, Palette.INK)
	if _live_dot.has_area():
		_draw_dot()
	if _foot_top >= 0.0:
		var foot: Rect2 = Rect2(
			BORDER + PAD_X, _foot_top, size.x - (BORDER + PAD_X) * 2.0, RULE_LINE
		)
		_dots(foot, Palette.CREAM_SHADE)


func _dots(rect: Rect2, colour: Color) -> void:
	var x: float = rect.position.x
	while x < rect.end.x:
		var dash: Vector2 = Vector2(minf(DOT_DASH, rect.end.x - x), rect.size.y)
		_marks.draw_rect(Rect2(Vector2(x, rect.position.y), dash), colour)
		x += DOT_DASH * 2.0


func _draw_dot() -> void:
	var colour: Color = LIVE_COLOURS[spec.live_kind]
	var rect: Rect2 = _live_dot
	match spec.live_kind:
		TipSpec.Live.BAD:
			# A crisp cross, 2 px strokes.
			for step: int in range(4):
				var a: float = step * 2.0
				_marks.draw_rect(Rect2(rect.position + Vector2(a, a), Vector2(2, 2)), colour)
				var back: Vector2 = Vector2(rect.size.x - 2.0 - a, a)
				_marks.draw_rect(Rect2(rect.position + back, Vector2(2, 2)), colour)
		TipSpec.Live.OFF:
			_marks.draw_rect(rect, colour)
		_:
			# A round dot on the 2 px grid: a square with its corners cut.
			var wide: Vector2 = Vector2(rect.size.x - 4.0, rect.size.y)
			_marks.draw_rect(Rect2(rect.position + Vector2(2, 0), wide), colour)
			var tall: Vector2 = Vector2(rect.size.x, rect.size.y - 4.0)
			_marks.draw_rect(Rect2(rect.position + Vector2(0, 2), tall), colour)
