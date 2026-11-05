extends RefCounted
## The item column's layout checks (PR #138 monitor), shared by the monitor suites: problems()
## lists what is wrong with the column shown now, empty when its layout is right.
##
## - Every part (MonitorItemColumn.part_rects) and every visible label inside the column's frame.
## - No two parts over each other (the containers left out: the frame, the header band, the rows'
##   area and the payout's own parts, which share the payout's place).
## - The parts in reading order, top to bottom: the header, the description (and its MORE chip),
##   the base line, the rows and the payout.
## - PR #138 round 5: the base line the rows' width and exactly a row's pitch tall, above the rows'
##   area, its tag, caption and amount inside it and apart.
## - PR #138 round 4: the description (and its MORE chip) inside its band. Round 6 (no box round
##   the equation): the base line, the rows' area and the payout's zone under the band, inside the
##   content's width (the header's and the description's), the payout's zone at least
##   PAYOUT_CLEARANCE px under the rows' area and its digits (with their shadow) at least
##   FOOT_CLEARANCE px over the frame's inside foot.
## - The header's family glyphs, with their rims, and the pages' marker inside the header band.
## - The payout's digits (none for a coupon that adds nothing, v1.00) right-aligned at the same
##   place for every item (PAYOUT_RECT).
## - No text cut silently: the description fits or carries the MORE chip; a row's text shows all
##   its lines (no ellipsis).
## - The rows' amounts and the base line's: every euro amount's and WASTED's visible ink ends on
##   one right edge, every factor's digits end where the euro amounts' digits end (PR #138 round 6,
##   the user's "multiplier should be aligned with other number"; within DIGIT_TOLERANCE), all at
##   one size on one baseline (amount_ink); each dotted leader runs between its line's name and its
##   amount, clear of both.

const CONTAINERS: Array[String] = [
	"frame",
	"header",
	"footer",
	"rows",
	"panel",
	"payout_digits",
	"payout_shadow",
]
## A Latin font's cap height and descender depth, as fractions of its size.
const CAP_HEIGHT := 0.72
const DESCENDER := 0.22
## Parts that share a box by design: the MORE chip ends the description's last line (checked
## against that line's end below).
const PAIRED: Array[Array] = [["effect", "more"], ["more", "effect"]]
## PR #138 round 6 (the user's "allow final price to breathe"): the payout's zone at least
## PAYOUT_CLEARANCE px under the rows' area, its digits' shadow at least FOOT_CLEARANCE px over the
## frame's inside foot.
const PAYOUT_CLEARANCE := 2.0
const FOOT_CLEARANCE := 4.0
## How far two numbers' last digits' visible ink right edges may differ (each digit's own shape
## and its kerning with the "€" after it move its ink by about a pixel), and two amounts' (the
## last letters' own side bearings and the text's pixel rounding: WASTED's D against the €, at
## most a 1080p pixel apart on the screen).
const DIGIT_TOLERANCE := 1.5
const EDGE_TOLERANCE := 1.0
const ORDER: Array[String] = ["header", "effect", "base", "step0", "payout"]


static func problems(column: MonitorItemColumn) -> PackedStringArray:
	var found: PackedStringArray = PackedStringArray()
	var parts: Dictionary[String, Rect2] = column.part_rects()
	if not parts.has("frame"):
		return found
	var frame: Rect2 = parts["frame"].grow(0.5)
	# A label's box may be taller than its text (its minimum size): its text as drawn counts. The
	# name's letters sit on the header (from their cap tops to the baseline); their descenders may
	# hang into the gap under it, as on the ticket.
	if column.name_control() != null:
		var drawn: Rect2 = Rect2()
		for label: Label in ItemName.labels(column.name_control()):
			var letters: Rect2 = _drawn(label, false)
			drawn = drawn.merge(letters) if drawn.has_area() else letters
		parts["name"] = drawn
	if parts.has("payout_equals"):
		parts["payout_equals"] = _drawn(column.payout_view().equals())
	var names: Array[String] = parts.keys()
	for index: int in range(names.size()):
		var name: String = names[index]
		var rect: Rect2 = parts[name]
		if not frame.encloses(rect):
			found.append("%s %s outside the frame %s" % [name, rect, frame])
		if CONTAINERS.has(name):
			continue
		for other: int in range(index + 1, names.size()):
			var other_name: String = names[other]
			if CONTAINERS.has(other_name) or [name, other_name] in PAIRED:
				continue
			if rect.intersects(parts[other_name]):
				found.append("%s %s over %s %s" % [name, rect, other_name, parts[other_name]])
	var bottom: float = -INF
	var last: String = ""
	for name: String in ORDER:
		if not parts.has(name):
			continue
		if parts[name].position.y < bottom - 0.5:
			found.append("%s above %s" % [name, last])
		bottom = parts[name].end.y
		last = name
	found.append_array(_header_and_base(column, parts))
	found.append_array(_sections(parts))
	if parts.has("more"):
		var line_end: float = parts["effect"].position.x + column.effect().last_line_end()
		if parts["more"].position.x < line_end - 0.5:
			found.append(
				"MORE %s over the description's last line (to %s)" % [parts["more"], line_end]
			)
	var origin: Vector2 = column.get_global_rect().position
	var payout: Rect2 = parts["payout"]
	var zone_at: Rect2 = MonitorItemColumn.PAYOUT_RECT
	var zone: Rect2 = Rect2(origin + zone_at.position, zone_at.size)
	if not zone.grow(0.5).encloses(payout):
		found.append("payout %s outside its zone %s" % [payout, zone])
	for label: Label in _labels(column):
		var rect: Rect2 = _drawn(label)
		if not label.is_visible_in_tree() or label.text.strip_edges().is_empty():
			continue
		if not frame.encloses(rect):
			found.append("'%s' %s outside the frame" % [label.text, rect])
	var effect: GlyphLabel = column.effect()
	if effect != null and not effect.fits() and not parts.has("more"):
		found.append("the description is cut with no MORE chip")
	var lines: Array[Control] = []
	if column.base_line() != null:
		lines.append(column.base_line())
	lines.append_array(column.step_rows())
	for row: Control in lines:
		found.append_array(_leader(row))
		var text: Label = row.get_node_or_null("Text") as Label
		if text != null and text.max_lines_visible > 0:
			if text.get_line_count() > text.max_lines_visible:
				found.append("row '%s' cut" % text.text)
	found.append_array(amounts_aligned(lines))
	return found


## The amounts of `lines` (base line and rows; "gives" amounts, in parentheses, left out): every
## euro amount's and WASTED's ink right edge equal, every factor's digits' ink right edge on the
## euro amounts' digits' (amount_ink), all at one font size on one baseline from their line's top.
static func amounts_aligned(lines: Array[Control]) -> PackedStringArray:
	var found: PackedStringArray = PackedStringArray()
	var edge: float = NAN
	var digits: float = NAN
	var baseline: float = NAN
	var font_size: int = -1
	var factors: Array[Vector2] = []
	for row: Control in lines:
		var amount: Label = row.get_node_or_null("Amount") as Label
		if amount == null or amount.text.begins_with("("):
			continue
		var ink: Vector3 = amount_ink(amount)
		if font_size < 0:
			font_size = amount.get_theme_font_size("font_size")
			baseline = ink.z
		elif amount.get_theme_font_size("font_size") != font_size:
			found.append("amount '%s' not at %d px" % [amount.text, font_size])
		if absf(ink.z - baseline) > 0.5:
			found.append("amount '%s' baseline %s, not %s" % [amount.text, ink.z, baseline])
		if amount.text.begins_with(MonitorStepRow.FACTOR_SIGN):
			factors.append(Vector2(ink.y, 0.0))
			continue
		if is_nan(edge):
			edge = ink.x
		elif absf(ink.x - edge) > EDGE_TOLERANCE:
			found.append("amount '%s' ink ends at %s, not %s" % [amount.text, ink.x, edge])
		if amount.text.ends_with(MonitorStepRow.EURO) and is_nan(digits):
			digits = ink.y
	if not is_nan(digits):
		for factor: Vector2 in factors:
			if absf(factor.x - digits) > DIGIT_TOLERANCE:
				found.append("a factor's digits end at %s, the euros' at %s" % [factor.x, digits])
	return found


## `amount`'s ink as drawn (global, from its glyphs' own bitmaps, TextServer): x its last glyph's
## ink right edge, y its last digit's ink right edge (NAN with none), z its baseline's offset under
## its line's last text line's top (its row's height less a pitch). Its text is one line,
## right-aligned and top-aligned in its box.
static func amount_ink(amount: Label) -> Vector3:
	var font: Font = amount.get_theme_font("font")
	var font_size: int = amount.get_theme_font_size("font_size")
	var line: TextLine = TextLine.new()
	line.add_string(amount.text, font, font_size)
	var server: TextServer = TextServerManager.get_primary_interface()
	var glyphs: Array[Dictionary] = server.shaped_text_get_glyphs(line.get_rid())
	var rect: Rect2 = amount.get_global_rect()
	var pen: float = rect.end.x - line.get_line_width()
	var ink_right: float = NAN
	var digit_right: float = NAN
	for glyph: Dictionary in glyphs:
		var face: RID = glyph["font_rid"]
		var key: Vector2i = Vector2i(int(glyph["font_size"]), 0)
		var index: int = int(glyph["index"])
		var offset: Vector2 = server.font_get_glyph_offset(face, key, index)
		var shown: Vector2 = server.font_get_glyph_size(face, key, index)
		var right: float = pen + (glyph["offset"] as Vector2).x + offset.x + shown.x
		ink_right = right
		var letter: String = amount.text.substr(int(glyph["start"]), 1)
		if letter >= "0" and letter <= "9":
			digit_right = right
		pen += float(glyph["advance"])
	var row: Control = amount.get_parent() as Control
	var line_top: float = row.size.y - MonitorStepRow.ROW_PITCH
	return Vector3(
		ink_right, digit_right, amount.position.y - line_top + font.get_ascent(font_size)
	)


## The header's glyphs (their rims too) and the pages' marker inside the header band; the base
## line the rows' width and a row's pitch tall, its foot on or above the rows' area's top, its tag,
## caption and amount inside it and apart.
static func _header_and_base(
	column: MonitorItemColumn, parts: Dictionary[String, Rect2]
) -> PackedStringArray:
	var found: PackedStringArray = PackedStringArray()
	var header: Rect2 = parts["header"].grow(0.5)
	for glyph: FamilyGlyph in column.glyphs():
		var rim: Rect2 = glyph.rim_rect()
		var drawn: Rect2 = Rect2(column.get_global_transform() * rim.position, rim.size)
		if not header.encloses(drawn):
			found.append("glyph %s %s outside the header %s" % [glyph.family, drawn, header])
	if parts.has("pager") and not header.encloses(parts["pager"]):
		found.append("the pages' marker %s outside the header %s" % [parts["pager"], header])
	if not parts.has("base"):
		return found
	var base: Rect2 = parts["base"]
	if absf(base.size.x - MonitorItemColumn.ROWS_WIDTH) > 0.5:
		found.append("base line %s not the rows' width" % base)
	if absf(base.size.y - MonitorItemColumn.ROW_PITCH) > 0.5:
		found.append("base line %s not a row's pitch tall" % base)
	if base.end.y > parts["rows"].position.y + 0.5:
		found.append("base line %s over the rows' area %s" % [base, parts["rows"]])
	var line: Control = column.base_line()
	var pieces: Array[Rect2] = []
	for piece: String in ["Mark", "Text", "Amount"]:
		var node: Control = line.get_node_or_null(piece) as Control
		if node == null:
			found.append("base line with no %s" % piece)
			continue
		var rect: Rect2 = node.get_global_rect()
		if node is Label:
			rect = _drawn(node as Label)
		if not base.grow(0.5).encloses(rect):
			found.append("base line %s %s outside it %s" % [piece, rect, base])
		for other: Rect2 in pieces:
			if rect.intersects(other):
				found.append("base line parts over each other: %s %s" % [rect, other])
		pieces.append(rect)
	return found


## `row`'s dotted leader (MonitorLeader), when it draws one: from after its name's end to before
## its amount's digits, on the 2 px grid.
static func _leader(row: Control) -> PackedStringArray:
	var found: PackedStringArray = PackedStringArray()
	var leader: MonitorLeader = row.get_node_or_null("Leader") as MonitorLeader
	var text: Label = row.get_node_or_null("Text") as Label
	var amount: Label = row.get_node_or_null("Amount") as Label
	if leader == null or text == null or amount == null:
		return found
	var span: Vector3 = leader.span()
	if span.y <= span.x:
		return found
	var lines: int = maxi(roundi(text.size.y / MonitorStepRow.ROW_PITCH), 1)
	var name_end: float = text.position.x + MonitorLeader.last_line_width(text, lines)
	var note: Label = row.get_node_or_null("FromBag") as Label
	if note != null:
		name_end = note.position.x + MonitorStepRow.text_width(note)
	var digits: float = amount.position.x + amount.size.x - MonitorStepRow.text_width(amount)
	if span.x <= name_end or span.y >= digits or fmod(span.x, 2.0) != 0.0:
		found.append(
			(
				"'%s' leader %s over its name (to %s) or amount (from %s)"
				% [text.text, span, name_end, digits]
			)
		)
	return found


## The description's panel round the description and its MORE chip; the base line, the rows' area,
## the payout's zone and the payout under the band and inside the content's width (PR #138 round
## 6: no box round them), the payout's zone PAYOUT_CLEARANCE px under the rows' area, its digits'
## shadow FOOT_CLEARANCE px over the frame's inside foot.
static func _sections(parts: Dictionary[String, Rect2]) -> PackedStringArray:
	var found: PackedStringArray = PackedStringArray()
	if parts.has("effect") != parts.has("panel"):
		found.append("a description with no panel, or a panel with none")
	if parts.has("panel"):
		var panel: Rect2 = parts["panel"].grow(0.5)
		for name: String in ["effect", "more"]:
			if parts.has(name) and not panel.encloses(parts[name]):
				found.append("%s %s outside the panel %s" % [name, parts[name], parts["panel"]])
	var frame: Rect2 = parts["frame"]
	var inset: float = MonitorItemColumn.INSET
	var top: float = parts["panel"].end.y if parts.has("panel") else parts["header"].end.y
	var content: Rect2 = Rect2(
		frame.position.x + inset, top, MonitorItemColumn.CONTENT_WIDTH, frame.end.y - top
	)
	for name: String in ["base", "rows", "footer", "payout"]:
		if parts.has(name) and not content.grow(0.5).encloses(parts[name]):
			found.append("%s %s outside the section %s" % [name, parts[name], content])
	if parts.has("footer") and parts.has("rows"):
		var gap: float = parts["footer"].position.y - parts["rows"].end.y
		if gap < PAYOUT_CLEARANCE - 0.5:
			found.append("payout zone %s %s px under the rows' area" % [parts["footer"], gap])
	var foot: float = frame.end.y - MonitorItemColumn.FRAME - FOOT_CLEARANCE
	for name: String in ["payout", "payout_shadow"]:
		if parts.has(name) and parts[name].end.y > foot + 0.5:
			found.append(
				"%s %s within %s px of the frame's foot" % [name, parts[name], FOOT_CLEARANCE]
			)
	return found


## Every Label under `node`.
static func _labels(node: Node) -> Array[Label]:
	var found: Array[Label] = []
	for child: Node in node.get_children():
		if child is Label:
			found.append(child as Label)
		found.append_array(_labels(child))
	return found


## `label`'s text as drawn (global): its lines' width from its alignment's side; its height from
## the first line's cap top (CAP_HEIGHT of its size over the baseline) to the last line's
## descenders (DESCENDER of its size under the baseline; `descenders` false: the baseline), a
## line's box being taller than its ink
## (the font's leading and accent room).
static func _drawn(label: Label, descenders: bool = true) -> Rect2:
	var rect: Rect2 = label.get_global_rect()
	var font: Font = label.get_theme_font("font")
	var size_px: int = label.get_theme_font_size("font_size")
	var lines: int = maxi(label.get_visible_line_count(), 1)
	var spacing: int = label.get_theme_constant("line_spacing")
	var line_height: float = font.get_height(size_px) + spacing
	var box: float = font.get_height(size_px) * lines + spacing * (lines - 1)
	var width: float = minf(
		rect.size.x, font.get_string_size(label.text, HORIZONTAL_ALIGNMENT_LEFT, -1, size_px).x
	)
	var x: float = rect.position.x
	if label.horizontal_alignment == HORIZONTAL_ALIGNMENT_RIGHT:
		x = rect.end.x - width
	elif label.horizontal_alignment == HORIZONTAL_ALIGNMENT_CENTER:
		x = rect.get_center().x - width / 2.0
	var y: float = rect.position.y
	if label.vertical_alignment == VERTICAL_ALIGNMENT_CENTER:
		y = rect.get_center().y - box / 2.0
	elif label.vertical_alignment == VERTICAL_ALIGNMENT_BOTTOM:
		y = rect.end.y - box
	var baseline: float = y + font.get_ascent(size_px)
	var top: float = baseline - CAP_HEIGHT * size_px
	var bottom: float = baseline + (lines - 1) * line_height
	if descenders:
		bottom += DESCENDER * size_px
	return Rect2(x, top, width, bottom - top)


## Every belt item's "gives" rows on `screen` for `result` (ScanController.gives_rows) into
## `gives` (slot: lines), each slot's lines put before its `expected` ones; returns each giver's
## summed gain (what a coupon's zone shows).
static func gives_of(
	screen: ShiftScreen,
	result: ScoreResult,
	gives: Dictionary[int, PackedStringArray],
	expected: Dictionary[int, PackedStringArray]
) -> Dictionary[int, int]:
	var given: Dictionary[int, int] = {}
	var names: PackedStringArray = CardInstance.names(screen.run.row)
	for slot: int in range(screen.run.row.size()):
		var rows: Array[ScanController.GivesRow] = ScanController.gives_rows(
			result, slot, names, ScanController.gives_arrow()
		)
		if rows.is_empty():
			continue
		var lines: PackedStringArray = PackedStringArray()
		given[slot] = 0
		for row: ScanController.GivesRow in rows:
			lines.append(row.line)
			given[slot] += row.gain
		gives[slot] = lines.duplicate()
		lines.append_array(expected.get(slot, PackedStringArray()))
		expected[slot] = lines
	return given


## The "gives" row a multiplier from `giver` to `slot` in `result` reads (PR #138 round 7): "to
## <target>  <effect> · <before>€ → <after>€", its before and after the target's running values
## around that step in the steps (the value-carrying steps', EffectGraph.VALUE_STEPS).
static func gives_line(
	target: String, effect: String, result: ScoreResult, giver: int, slot: int
) -> String:
	var running: int = -1
	var was: int = -1
	var now: int = -1
	for step: ScoreStep in result.steps:
		if step.slot != slot or not EffectGraph.VALUE_STEPS.has(step.step_type):
			continue
		var linked: bool = (
			step.step_type == ScoreStep.StepType.MULTIPLIER
			and step.source_kind == ScoreStep.SourceKind.CARD
			and step.card_giver_slot() == giver
		)
		if linked and was < 0:
			was = running
			now = step.value_after
		running = step.value_after
	var amount: String = (
		ScanController.GIVES_EFFECT
		% [effect, MonitorText.euros(was), ScanController.gives_arrow(), MonitorText.euros(now)]
	)
	return ReceiptView.joined_line(ScanController.GIVES_TEXT % target, amount)


## When the scan of the giver at `slot` shows its one collapsed "gives" row (`texts` first; the
## monitor collapses them when one per target would page, PR #138 round 7 review), that row stands
## for its per-target rows in `gives` and `expected` (see gives_of).
static func collapse_gives(
	screen: ShiftScreen,
	result: ScoreResult,
	slot: int,
	texts: PackedStringArray,
	gives: Dictionary[int, PackedStringArray],
	expected: Dictionary[int, PackedStringArray]
) -> void:
	var names: PackedStringArray = CardInstance.names(screen.run.row)
	var many: Array[ScanController.GivesRow] = ScanController.gives_rows(
		result, slot, names, ScanController.gives_arrow(), 0
	)
	var count: int = gives[slot].size()
	if count < 2 or texts.is_empty() or many.is_empty() or texts[0] != many[0].line:
		return
	gives[slot] = PackedStringArray([many[0].line])
	var lines: PackedStringArray = PackedStringArray([many[0].line])
	lines.append_array(expected[slot].slice(count))
	expected[slot] = lines
