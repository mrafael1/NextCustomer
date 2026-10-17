class_name MonitorView
extends Control
## The hung monitor (#80, mock-up B2; ShiftStage.MONITOR_RECT): two rods from the ceiling, the
## shade under it, a rubber bezel with a little bevel and the paper screen, drawn flat in code
## (its art lands in a later step). Its screen shows one of three things (mode()):
## - IDLE (planning with nothing scanned, the impulse rack): the LED (LedDisplay, compact) with
##   the projected total and the quota line, and the notices (NoticeLabel) under it;
## - SCAN (a belt or hand item fully scanned: ScanController calls show_scan): the item's art
##   (ItemView's item_art), its kind under it (COUPON, or its base price), and beside it its
##   name, "pays €N" for a belt item, its tag line, its rule text and, for a belt item, its step
##   lines as the caller words them (ScanFooter), in the largest of the TIERS sizes that shows
##   every line; on the smallest, lines that don't fit fold into "+N more";
## - COUNT (the count-up: the LED shows SUBTOTAL or TOTAL in its count layout, mock-up B2's
##   count-up screen: no glass, the big ink digits straight on the paper): the item the count-up
##   is on at the left (its art, name and "n / m"; show_beat, or follow_beat on CountUp's
##   beat_started), the LED's column beside it (LED_COUNT_RECT) with the SUBTOTAL caption and the
##   beat's step line on its row, the digits with the beat's gain chip beside them, and the quota
##   row (LedBeat). A payout beat on the item of the beat before it keeps that beat's step line
##   (the bonus that made the payout stays on screen through it). At the TOTAL the LED's column
##   stands alone, near the paper's centre (LED_TOTAL_RECT).
## A notice shows on the idle screen while it lasts, over a scan too (the scan comes back once it
## has faded), never over the count. The monitor follows the LED's mode (mode_changed) and the
## notice (showing_changed) itself; ScanController and the shift screen fill it. Display only:
## every amount and line is the caller's (or the LED's, from core's ShiftMargin).
##
## Text never carries the pixel material; the art does. Reduced motion (`reduced_motion`) leaves
## the gain chip's pop out (which runs on the count-up's tweens, LedBeat.make_tween).

enum Mode { IDLE, SCAN, COUNT }

## The parts' rects, in stage coordinates (the view stands at MONITOR_RECT's position): the
## screen's content inside its ink border and padding, the art and the kind under it, and the
## text column beside the art.
const CONTENT_RECT := Rect2(393, 85, 382, 138)
const ART_RECT := Rect2(393, 85, 96, 96)
const KIND_RECT := Rect2(393, 185, 96, 18)
const TEXT_RECT := Rect2(499, 85, 276, 138)
## The count-up's art column: the item's name (up to COUNT_NAME_LINES lines) and "n / m" under
## its art, in B2's caption voice (COUNT_NAME_SIZES); the LED's count layout beside it, 10 px
## right of the art and level with it (B2's column), or alone at the TOTAL: as near the paper's
## centre (TOTAL_OFF_CENTRE px right of it) as the widest digits at the largest punch allow, as
## they punch about their centre at the column's left.
const COUNT_NAME_RECT := Rect2(393, 182, 96, 26)
const COUNT_ITEM_RECT := Rect2(393, 208, 96, 15)
const COUNT_NAME_LINES := 2
const LED_COUNT_RECT := Rect2(499, 85, 276, 138)
const LED_TOTAL_RECT := Rect2(464, 85, 276, 138)
const TOTAL_OFF_CENTRE := 18.0
## Every part the monitor draws, rods and shade included (stage coordinates).
const DRAWN_RECT := Rect2(372, 56, 424, 192)
const OUTLINE := 2
## The bezel's bevel: a light edge on its top and left, a dark one on its bottom and right.
const BEVEL := 2
const BEVEL_LIGHT := Palette.STEEL_DARKEST
const BEVEL_DARK := Palette.RUBBER_DARK
## The screen's inner shadow under its top border.
const SCREEN_SHADOW := 2
const SCREEN_SHADOW_ALPHA := 0.12
## Two lines of the notice's font run 47 px with its own leading; this pulls them into 44.
const NOTICE_LINE_SPACING := -4
## The notice's ink: plain, as tomato is only for fizzles, CHECKOUT and CLOSED (#80).
const NOTICE_COLOR := Palette.INK
## The scan's text: the name row (with "pays €N" at its right), the tag row, the gaps.
const NAME_HEIGHT := 26.0
const NAME_SIZES: Array[int] = [20, 16]
const PAYS_WORD := "pays"
const PAYS_WORD_SIZE := 13
const PAYS_AMOUNT_SIZE := 18
const PAYS_GAP := 4.0
const NAME_GAP := 8.0
const TAG_HEIGHT := 16.0
const TAG_SIZE := 12
const KIND_SIZE := 13
const RULE_GAP := 2.0
const RULE_LINE_SPACING := 0
const FOOTER_GAP := 4.0
const COUPON_TEXT := "COUPON"
const BASE_TEXT := "BASE €%d"
## The rule text's and the step lines' sizes, largest first: the scan takes the first that shows
## every step line.
const TIERS: Array[Vector2i] = [Vector2i(13, 12), Vector2i(12, 11), Vector2i(11, 10)]
## The count's item name and "n / m" as B2's: uppercase in the display font, its glyphs
## COUNT_NAME_SPACING px apart, in light ink. The name takes B2's 13 px when it fits the column on
## one line, else the smaller size on up to COUNT_NAME_LINES lines, as tight as the item's
## printed name (ItemView's).
const COUNT_NAME_SIZES: Array[int] = [13, 11]
const COUNT_NAME_SPACING := 1
const COUNT_NAME_LINE_SPACING := ItemView.NAME_LINE_SPACING
const COUNT_ITEM_SIZE := 12
const ITEM_TEXT := "%d / %d"

## Returns true when the player asked for reduced motion. None means false.
var reduced_motion: Callable = Callable()
## The LED and the notices on the screen (the stage hands them to the shift screen).
var led: LedDisplay
var notice_label: NoticeLabel

var _notice_holder: Control
var _scan_view: Control
var _count_view: Control
var _scanning: bool = false
## The count-up has shown a beat since it started (show_beat).
var _beat_shown: bool = false
## The last beat follow_beat showed: its slot (-1 for none since the count started), its step
## line and whether that was a fizzle's.
var _beat_slot: int = -1
var _beat_line: String = ""
var _beat_fizzle: bool = false
var _scan_name: Label
var _scan_rule: Label
var _scan_footer: ScanFooter
var _scan_tier: int = 0
var _count_name: Label
var _count_item: Label
## Each label's rect (local), set again once in the tree (a label never shrinks back by itself).
var _rects: Dictionary[Label, Rect2] = {}


func _init() -> void:
	name = "Monitor"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	position = ShiftStage.MONITOR_RECT.position
	size = ShiftStage.MONITOR_RECT.size
	_notice_holder = _layer("Idle")
	# Plain ink on the paper screen (NOTICE_COLOR, no outline), on up to two lines.
	notice_label = NoticeLabel.new()
	notice_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	notice_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	notice_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	notice_label.add_theme_color_override("font_color", NOTICE_COLOR)
	notice_label.add_theme_constant_override("outline_size", 0)
	notice_label.add_theme_constant_override("line_spacing", NOTICE_LINE_SPACING)
	_notice_holder.add_child(notice_label)
	_place(notice_label, ShiftStage.NOTICE_RECT)
	notice_label.showing_changed.connect(_on_notice_showing)
	led = LedDisplay.new()
	led.position = local(ShiftStage.LED_RECT).position
	add_child(led)
	led.mode_changed.connect(_on_led_mode)
	_scan_view = _layer("Scan")
	_count_view = _layer("Count")
	_count_name = _count_label(COUNT_NAME_SIZES[0])
	_count_name.add_theme_constant_override("line_spacing", COUNT_NAME_LINE_SPACING)
	_count_name.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_count_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_count_name.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_count_view.add_child(_count_name)
	_place(_count_name, COUNT_NAME_RECT)
	_count_item = _count_label(COUNT_ITEM_SIZE)
	_count_item.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_count_item.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_count_view.add_child(_count_item)
	_place(_count_item, COUNT_ITEM_RECT)
	_apply()


func _ready() -> void:
	for label: Label in _rects:
		label.position = _rects[label].position
		label.size = _rects[label].size


func _draw() -> void:
	for rod: Rect2 in ShiftStage.ROD_RECTS:
		_draw_hung(local(rod), Palette.RUBBER)
	_draw_hung(local(ShiftStage.MONITOR_UNDER_RECT), Palette.CHARCOAL)
	var bezel: Rect2 = local(ShiftStage.MONITOR_RECT)
	draw_rect(bezel, Palette.INK)
	var face: Rect2 = bezel.grow(-OUTLINE)
	draw_rect(face, BEVEL_DARK)
	draw_rect(Rect2(face.position, face.size - Vector2(BEVEL, BEVEL)), BEVEL_LIGHT)
	draw_rect(face.grow(-BEVEL), Palette.RUBBER)
	var screen: Rect2 = local(ShiftStage.MONITOR_SCREEN_RECT)
	draw_rect(screen, Palette.INK)
	var paper: Rect2 = screen.grow(-OUTLINE)
	draw_rect(paper, Palette.PAPER)
	draw_rect(
		Rect2(paper.position, Vector2(paper.size.x, SCREEN_SHADOW)),
		Color(Palette.INK, SCREEN_SHADOW_ALPHA)
	)


## What the screen shows now.
func mode() -> Mode:
	if _counting():
		return Mode.COUNT
	return Mode.SCAN if _scan_view.visible else Mode.IDLE


## Shows a scanned item (ScanController): `definition` (its `aisle`, or null) with its `tags`
## (on the belt the scored ones). A belt item passes its `payout` and step lines (each with
## whether it is a fizzle); a hand item passes payout -1. Call it once the monitor is in the
## tree: the text is measured with the real font. A notice showing, or the count-up, keeps the
## scan off the screen until it ends.
func show_scan(
	definition: CardDefinition,
	aisle: AisleDefinition,
	tags: PackedStringArray,
	payout: int,
	lines: PackedStringArray,
	fizzles: Array[bool]
) -> void:
	_scanning = true
	_fill_scan(definition, aisle, tags, payout, lines, fizzles)
	_apply()


## The scan ended: the idle screen comes back.
func end_scan() -> void:
	_scanning = false
	_apply()


## A count-up beat starts on item `item` of `items` (1-based), `definition`: its art, name and
## "n / m" beside the LED, and on the LED the beat's `gain` (negative for none) and step `line`
## (a `fizzle`'s in dark tomato), as the count-up words them.
func show_beat(
	definition: CardDefinition, item: int, items: int, gain: int, line: String, fizzle: bool
) -> void:
	for child: Node in _count_view.get_children():
		if child is TextureRect:
			_count_view.remove_child(child)
			child.queue_free()
	var art: TextureRect = ItemView.item_art(definition)
	art.position = local(ART_RECT).position
	_count_view.add_child(art)
	_count_name.text = definition.display_name.to_upper()
	_count_name.add_theme_font_size_override("font_size", count_name_size(_count_name.text))
	_count_item.text = ITEM_TEXT % [item, items]
	_beat_shown = true
	led.beat().show_beat(gain, line, fizzle, not _wants_reduced_motion())
	_apply()


## CountUp.beat_started: shows the beat on its item `view` (1-based among the row's `items`), with
## a payout's gain (none for the other beats) and its step line, in dark tomato for a fizzle. A
## PAYOUT beat on the slot of the beat before it keeps that beat's line (B2: "+€15 Category
## engine" beside the "+€17" it made), so the bonus stays on screen through the payout.
func follow_beat(
	beat: CountUpBeat, step: ScoreStep, line: String, view: CardView, items: int
) -> void:
	var pays: bool = (
		beat.kind == CountUpBeat.Kind.PAYOUT or beat.kind == CountUpBeat.Kind.MERGED_PLAIN
	)
	var fizzle: bool = step.step_type == ScoreStep.StepType.WASTED
	if beat.kind == CountUpBeat.Kind.PAYOUT and beat.slot == _beat_slot:
		line = _beat_line
		fizzle = _beat_fizzle
	show_beat(view.card.definition, beat.slot + 1, items, beat.payout if pays else -1, line, fizzle)
	_beat_slot = beat.slot
	_beat_line = line
	_beat_fizzle = fizzle


## The scan's name label, rule label and step lines (while a scan was shown), and the size tier
## it took (an index into TIERS).
func scan_name_label() -> Label:
	return _scan_name


func scan_rule_label() -> Label:
	return _scan_rule


func scan_footer() -> ScanFooter:
	return _scan_footer


func scan_tier() -> int:
	return _scan_tier


## The count-up's item name and "n / m" labels.
func count_name_label() -> Label:
	return _count_name


func count_item_label() -> Label:
	return _count_item


## The art shown for the scan or the count-up's beat, or null.
func scan_art() -> TextureRect:
	return _art_in(_scan_view)


func count_art() -> TextureRect:
	return _art_in(_count_view)


## Every text label the screen shows now (the LED's aside), for layout checks.
func shown_labels() -> Array[Label]:
	var labels: Array[Label] = []
	for layer: Control in [_notice_holder, _scan_view, _count_view]:
		if layer.visible:
			_collect_labels(layer, labels)
	return labels


## The count's item name's size for `text` (uppercase): the first of COUNT_NAME_SIZES that shows
## it on one line in COUNT_NAME_RECT's width, else the last (which wraps).
static func count_name_size(text: String) -> int:
	var font: Font = ArtStyle.spaced_display_font(COUNT_NAME_SPACING)
	for font_size: int in COUNT_NAME_SIZES:
		var width: float = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
		if width <= COUNT_NAME_RECT.size.x:
			return font_size
	return COUNT_NAME_SIZES[-1]


## A rect in stage coordinates, in the monitor's own.
static func local(rect: Rect2) -> Rect2:
	return Rect2(rect.position - ShiftStage.MONITOR_RECT.position, rect.size)


## Shows what the state says (see the class comment) and lays the LED out for it.
func _apply() -> void:
	var counting: bool = _counting()
	var scanning: bool = _scanning and not counting and not notice_label.is_showing()
	var led_rect: Rect2 = ShiftStage.LED_RECT
	if counting:
		var total: bool = led.mode() == LedDisplay.Mode.TOTAL
		led_rect = LED_TOTAL_RECT if total else LED_COUNT_RECT
	led.position = local(led_rect).position
	led.visible = not scanning
	_notice_holder.visible = not counting and not scanning
	_scan_view.visible = scanning
	_count_view.visible = counting and _beat_shown and led.mode() == LedDisplay.Mode.SUBTOTAL


func _counting() -> bool:
	return led.mode() == LedDisplay.Mode.SUBTOTAL or led.mode() == LedDisplay.Mode.TOTAL


## A count-up starts over (start_count): no beat yet.
func _on_led_mode(led_mode: LedDisplay.Mode) -> void:
	if led_mode != LedDisplay.Mode.TOTAL:
		_beat_shown = false
		_beat_slot = -1
	_apply()


func _on_notice_showing(_showing: bool) -> void:
	_apply()


## Builds the scan's content (show_scan) in the first of TIERS whose step lines all show.
func _fill_scan(
	definition: CardDefinition,
	aisle: AisleDefinition,
	tags: PackedStringArray,
	payout: int,
	lines: PackedStringArray,
	fizzles: Array[bool]
) -> void:
	for tier: int in range(TIERS.size()):
		_clear(_scan_view)
		_scan_tier = tier
		var fits: bool = _build_scan(definition, aisle, tags, payout, lines, fizzles, TIERS[tier])
		if fits:
			return


## The scan's content at `sizes` (the rule's, the step lines'). Returns whether everything shows
## inside CONTENT_RECT, no step line folded.
func _build_scan(
	definition: CardDefinition,
	aisle: AisleDefinition,
	tags: PackedStringArray,
	payout: int,
	lines: PackedStringArray,
	fizzles: Array[bool],
	sizes: Vector2i
) -> bool:
	var art: TextureRect = ItemView.item_art(definition)
	art.position = local(ART_RECT).position
	_scan_view.add_child(art)
	var kind: Label
	if definition.is_coupon():
		kind = UiKit.display_label(COUPON_TEXT, KIND_SIZE, false)
		kind.add_theme_color_override("font_color", Palette.VELVET)
	else:
		kind = UiKit.number_label(BASE_TEXT % definition.base, KIND_SIZE, false)
		kind.add_theme_color_override("font_color", Palette.INK_LIGHT)
	kind.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	kind.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_add(kind, local(KIND_RECT))
	var column: Rect2 = local(TEXT_RECT)
	var name_width: float = column.size.x
	if payout >= 0:
		name_width -= _add_pays(payout, column) + NAME_GAP
	_scan_name = UiKit.display_label(definition.display_name, NAME_SIZES[0], false)
	_scan_name.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_add(_scan_name, Rect2(column.position, Vector2(name_width, NAME_HEIGHT)))
	for name_size: int in NAME_SIZES:
		_scan_name.add_theme_font_size_override("font_size", name_size)
		if _scan_name.get_minimum_size().x <= name_width:
			break
	var y: float = column.position.y + NAME_HEIGHT
	var tag_text: String = ScanPopup.tag_line(tags, definition, aisle)
	if not tag_text.is_empty():
		var tag: Label = UiKit.body_label(tag_text, TAG_SIZE, Palette.GREY_DARK)
		_add(tag, Rect2(column.position.x, y, column.size.x, TAG_HEIGHT))
		# One TAG_HEIGHT row; a tag line too wide for it wraps.
		if tag.get_minimum_size().x > column.size.x:
			tag.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			tag.size = Vector2(column.size.x, 1.0)
			tag.size.y = tag.get_minimum_size().y
		y += maxf(tag.size.y, TAG_HEIGHT)
	_scan_rule = UiKit.body_label(definition.rule_text, sizes.x, Palette.INK)
	_scan_rule.add_theme_constant_override("line_spacing", RULE_LINE_SPACING)
	_scan_rule.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_add(_scan_rule, Rect2(column.position.x, y + RULE_GAP, column.size.x, 1.0))
	_scan_rule.size.y = _scan_rule.get_minimum_size().y
	y = _scan_rule.position.y + _scan_rule.size.y
	var bottom: float = local(CONTENT_RECT).end.y
	_scan_footer = null
	if payout < 0:
		return y <= bottom
	_scan_footer = ScanFooter.new(column.size.x, sizes.y)
	_scan_view.add_child(_scan_footer)
	_scan_footer.position = Vector2(column.position.x, y + FOOTER_GAP)
	var all_shown: bool = _scan_footer.fill(lines, fizzles, bottom - _scan_footer.position.y)
	return all_shown and y <= bottom


## "pays €N" right-aligned on the name row of `column`. Returns its width.
func _add_pays(payout: int, column: Rect2) -> float:
	var amount: Label = UiKit.number_label("€%d" % payout, PAYS_AMOUNT_SIZE, false)
	amount.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_scan_view.add_child(amount)
	var amount_width: float = amount.get_minimum_size().x
	amount.position = Vector2(column.end.x - amount_width, column.position.y)
	amount.size = Vector2(amount_width, NAME_HEIGHT)
	var word: Label = UiKit.body_label(PAYS_WORD, PAYS_WORD_SIZE, Palette.INK_LIGHT)
	word.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_scan_view.add_child(word)
	var word_width: float = word.get_minimum_size().x
	word.position = Vector2(amount.position.x - PAYS_GAP - word_width, column.position.y)
	word.size = Vector2(word_width, NAME_HEIGHT)
	return amount_width + PAYS_GAP + word_width


## Adds `label` to the scan at `rect` (local), in the tree first: out of it a label measures
## with the default font size.
func _add(label: Label, rect: Rect2) -> void:
	_scan_view.add_child(label)
	label.position = rect.position
	label.size = rect.size


## A layer over the whole monitor, taking no clicks.
func _layer(layer_name: String) -> Control:
	var layer: Control = Control.new()
	layer.name = layer_name
	layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.size = size
	add_child(layer)
	return layer


## A hung part (a rod, the shade): `color` with an ink outline on its sides and foot.
func _draw_hung(rect: Rect2, color: Color) -> void:
	draw_rect(rect, Palette.INK)
	var inside: Vector2 = rect.size - Vector2(2 * OUTLINE, OUTLINE)
	draw_rect(Rect2(rect.position + Vector2(OUTLINE, 0), inside), color)


## A label of the count's art column (B2's .kind): the spaced display font at `font_size`, in light
## ink.
static func _count_label(font_size: int) -> Label:
	var label: Label = UiKit.display_label("", font_size, false)
	label.add_theme_font_override("font", ArtStyle.spaced_display_font(COUNT_NAME_SPACING))
	label.add_theme_color_override("font_color", Palette.INK_LIGHT)
	return label


func _place(label: Label, rect: Rect2) -> void:
	var at: Rect2 = local(rect)
	_rects[label] = at
	label.position = at.position
	label.size = at.size


func _wants_reduced_motion() -> bool:
	return reduced_motion.is_valid() and bool(reduced_motion.call())


static func _art_in(layer: Control) -> TextureRect:
	for child: Node in layer.get_children():
		if child is TextureRect and not child.is_queued_for_deletion():
			return child as TextureRect
	return null


static func _clear(layer: Control) -> void:
	for child: Node in layer.get_children():
		layer.remove_child(child)
		child.queue_free()


static func _collect_labels(node: Node, labels: Array[Label]) -> void:
	for child: Node in node.get_children():
		if child is Label:
			labels.append(child as Label)
		_collect_labels(child, labels)
