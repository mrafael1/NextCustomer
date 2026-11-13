class_name ReceiptTarget
extends Control
## The receipt's header (main scene v2, the user's pick H2 of 2026-11-08: mock-up
## docs/art/mockups/main_scene_v2.html, drawH2): it always says what to do, "BEAT" in the chunky
## capitals before "TODAY'S TARGET", over the shift's quota in the pixel digits in tomato dark and
## a double tomato rule; under them the number that grows, PROJECTED in planning and TOTAL from the
## count on (its caption at the left, the line against the target at the right: "+N€ over" in
## green dark, "N€ short" in tomato dark), then the hero: that number big in ink, right under the
## target so the two read at a glance, and a dashed rule. The hero stays at least 1.5x the target:
## a long total steps both down together (CELLS: 6/4, 5/3, 4/2), decided from the shift's projected
## total, so the size never jumps during a count. At the quota crossing (show_met) the target turns
## green dark with the lap lamp's check after it, the rule goes green, and the BEATEN! stamp slams
## onto the header's words (BeatenStamp; settled at once on a resume or a Double checkout's row 1).
## Planning never shows BEATEN!. It is pinned at the receipt's top (ReceiptView keeps it out of the
## scroll area). Hidden until show_quota; the lower part (caption, hero) only shows once
## show_planned or begin_count has been called (a receipt's copy keeps the target alone). Display
## only: the numbers are the planning result's and the count's (ReceiptView.show_running). In
## planning a new projection rolls the hero to it (`roll`, ReceiptRoll); the count stops the roll.
## While planning's projection would spend a week medal still free this week (ReceiptGold's
## pending metal, WeekMedals.pending_of; gold over silver) the PROJECTED digits take that metal in
## its darker shades with a darker shadow, so they read on the cream paper (the user's play test
## of 2026-11-09); plain ink otherwise, and the count's TOTAL always ink (the paper's metal says
## it).

## BEAT, then the caption after it: the receipt's mono font at CAPTION_SIZE, letter-spaced, in ink.
const BEAT_TEXT := "MEET"
const BEAT_CELL := 2.0
const BEAT_GAP := 10.0
const CAPTION_TEXT := "THE QUOTA"
const CAPTION_SIZE := 13
const CAPTION_SPACING := 1
const CAPTION_COLOR := Palette.INK
## The quota and the hero as they print: whole euros and the € after them ("80€").
const AMOUNT_TEXT := "%d€"
const COLOR := Palette.TOMATO_DARK
const MET_COLOR := Palette.GREEN_DARK
const HERO_COLOR := Palette.INK
## The PROJECTED hero's body and shadow while a medal is pending (show_pending_metal).
const SILVER_HERO_COLOR := Palette.STEEL_SHADE
const SILVER_HERO_SHADOW := Palette.STEEL_DARKEST
const GOLD_HERO_COLOR := Palette.MUSTARD_DARK
const GOLD_HERO_SHADOW := Palette.BRASS_DARKEST
const NO_SHADOW := Color(0, 0, 0, 0)
## The hero's and the target's font cells, the first whose hero fits the head's width (less its
## insets): the hero always 1.5x the target or more.
const CELLS: Array[Vector2] = [Vector2(6, 4), Vector2(5, 3), Vector2(4, 2)]
## The lap lamp's check (LapLamp.CHECK) after the met target: at CHECK_CELL, CHECK_GAP px past it.
const CHECK_CELL := 4.0
const CHECK_GAP := 8.0
## The head's rows (px from its top) and the text's side insets (the mock-up's: the captions a
## little in from the rows' minis, the hero and the line against the target near the paper's edge).
const INSET := 10.0
const INSET_RIGHT := 2.0
const BEAT_TOP := 4.0
const TARGET_TOP := 26.0
const TARGET_BOX := 32.0
const RULE_TOP := 62.0
const ROW_TOP := 72.0
const HERO_TOP := 94.0
const HERO_BOX := 48.0
const DASH_TOP := 148.0
const HEIGHT := 152.0
## The head without its lower part (the target alone): to the rule's foot.
const TARGET_HEIGHT := 70.0
## The head's width before it is laid out (the shift screen's paper less its padding).
const DEFAULT_WIDTH := 236.0
## The BEATEN! stamp's middle, over the header's words.
const STAMP_MIDDLE_Y := 12.0
const ROW_SIZE := 16
## The double rule under the number: two RULE_WIDTH px lines RULE_GAP px apart, inset RULE_INSET
## px from the block's sides; tomato, green once met.
const RULE_COLOR := Palette.TOMATO
const RULE_MET_COLOR := Palette.GOOD
const RULE_WIDTH := 2.0
const RULE_GAP := 2.0
const RULE_INSET := 2.0
## The hero lifts BUMP px for BUMP_SECONDS as a row lands (bump()).
const BUMP := 2.0
const BUMP_SECONDS := 0.16
## The line against the target and the dessert's margin words (margin_text) share these words.
const OVER_TEXT := "+%s over"
const SHORT_TEXT := "%s to go"
const ON_TEXT := "on quota"
const PROJECTED_TEXT := "PROJECTED"
const TOTAL_TEXT := "TOTAL"
## The dessert's PAID or SLIP stamp lands on the over row after the margin words (stamp, the row's
## child 1: ReceiptStamps.stamp_paid; the user's play test of 2026-11-09: no paper line under the
## rows), at STAMP_SIZE; the words are sized to leave it the room of its text (a pass's PAID, a
## miss's longest slip STAMP_ROOM_TEXT), down to WORDS_MIN_SIZE, and again as it lands.
const STAMP_SIZE := 14
const STAMP_ROOM_TEXT := "MISS 0/0"
const WORDS_MIN_SIZE := ReceiptView.VERDICT_MIN_FONT_SIZE

var beat: PixelWords
var caption: Label
## The quota's digits and € (PixelWords), in the "AmountRow".
var amount: PixelWords
var check: Control
## PROJECTED or TOTAL, the line against the target (child 0 of over_row), its PAID or SLIP stamp
## (child 1; hidden until the dessert stamps it), and the hero.
var total_caption: Label
var over_row: HBoxContainer
var over: Label
var stamp: Label
var hero: PixelWords
var beaten: BeatenStamp
## The projected number's roll in planning (show_planned).
var roll: ReceiptRoll
## The hero's and the target's cells (CELLS).
var cells: Vector2 = CELLS[0]
var _row: Control
var _quota: int = -1
var _met: bool = false
var _lower: bool = false
var _lift: float = 0.0
## The margin's words hold the line against the target (show_margin_words): the reading no longer
## rewrites it.
var _margin_shown: bool = false
var _bump: Tween
## The quota the line against the target reads in planning (show_planned's).
var _planned_quota: int = -1
## The margin words' longest form (show_margin_words) and the stamp text they leave room for.
var _margin_words: String = ""
var _stamp_room_text: String = STAMP_ROOM_TEXT
## The medal planning's projection would spend (ReceiptGold.PENDING_*): the PROJECTED hero's metal.
var _pending_metal: int = ReceiptGold.PENDING_NONE


func _init() -> void:
	name = "Target"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false
	beat = _words(BEAT_TEXT, PixelWords.Sheet.CHUNKY_CAPS, BEAT_CELL, COLOR, self)
	beat.name = "Beat"
	caption = _label(CAPTION_TEXT, CAPTION_SIZE, CAPTION_COLOR, CAPTION_SPACING)
	caption.name = "Caption"
	add_child(caption)
	_row = Control.new()
	_row.name = "AmountRow"
	_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_row)
	amount = _words("", PixelWords.Sheet.DIGITS, cells.y, COLOR, _row)
	amount.name = "Amount"
	check = Control.new()
	check.name = "Check"
	check.mouse_filter = Control.MOUSE_FILTER_IGNORE
	check.visible = false
	check.draw.connect(_draw_check)
	_row.add_child(check)
	_row.child_entered_tree.connect(_queue_layout.unbind(1))
	_row.child_exiting_tree.connect(_queue_layout.unbind(1))
	total_caption = _label(PROJECTED_TEXT, ROW_SIZE, Palette.INK)
	total_caption.name = "TotalCaption"
	add_child(total_caption)
	over_row = HBoxContainer.new()
	over_row.name = "OverRow"
	over_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(over_row)
	over = _label("", ROW_SIZE, Palette.GREEN_DARK)
	over.name = "Over"
	over.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	over.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	over_row.add_child(over)
	stamp = _label("", STAMP_SIZE, Palette.TOMATO)
	stamp.name = "Stamp"
	stamp.visible = false
	stamp.minimum_size_changed.connect(_fit_margin_words)
	over_row.add_child(stamp)
	hero = _words("", PixelWords.Sheet.DIGITS, cells.x, HERO_COLOR, self)
	hero.name = "Hero"
	beaten = BeatenStamp.new()
	add_child(beaten)
	roll = ReceiptRoll.new(self, _show_rolled, _set_lift)
	_show_lower(false)
	resized.connect(_layout)


## Shows `quota` as the target (hides the block for a negative one).
func show_quota(quota: int) -> void:
	_quota = quota
	visible = quota >= 0
	amount.text = AMOUNT_TEXT % maxi(quota, 0)
	if _lower:
		_set_hero(hero.text.to_int(), quota)
	_layout()


## The quota shown, -1 for none.
func shown_quota() -> int:
	return _quota if visible else -1


## Planning: PROJECTED and `total` as the hero, against `quota` (none when negative), the sizes
## from `total`; not met (BEATEN! and the check off). With `animate`, a projection already shown
## rolls to `total` from the number shown (ReceiptRoll); else (a first show, after a count, reduced
## motion) it shows at once.
func show_planned(total: int, quota: int, animate: bool = false) -> void:
	var rolls: bool = animate and _lower and total_caption.text == PROJECTED_TEXT
	_show_lower(true)
	total_caption.text = PROJECTED_TEXT
	_met = false
	_margin_shown = false
	_planned_quota = quota
	beaten.clear()
	_clear_stamp()
	_ink_hero()
	if rolls:
		roll.to(total)
	else:
		roll.snap(total)


## The count starts: TOTAL, and the hero at `start_total` (the sizes stay planning's).
func begin_count(start_total: int) -> void:
	if roll.rolling():
		cells = cells_for(roll.goal, _hero_room())  # The sizes of the projection it rolled to.
	roll.stop()
	_show_lower(true)
	total_caption.text = TOTAL_TEXT
	_margin_shown = false
	_clear_stamp()
	_ink_hero()
	_set_hero(start_total, _quota)


## Planning's projection would spend medal `metal` (ReceiptGold.PENDING_SILVER, PENDING_GOLD), or
## none (PENDING_NONE): the PROJECTED hero takes that metal, or goes back to ink.
func show_pending_metal(metal: int) -> void:
	_pending_metal = metal
	_ink_hero()


## The hero's body colour and shadow as drawn now (for tests).
func hero_ink() -> Array[Color]:
	return [hero.color, hero.shadow]


## The count's reading `value` on the hero and the line against the target.
func show_running(value: int) -> void:
	if not _lower:
		return
	roll.stop()
	_set_hero(value, _quota)


## The quota is met: the target turns green dark with its check, the rule goes green, and BEATEN!
## slams on (`pop`, unless `still`), else shows settled.
func show_met(pop: bool, still: bool = false) -> void:
	_met = true
	_layout()
	beaten.stamp(pop, still)


func is_met() -> bool:
	return _met


## The hero lifts BUMP px for BUMP_SECONDS (a row landing).
func bump() -> void:
	if _bump != null:
		_bump.kill()
	_lift = BUMP
	_layout()
	if not is_inside_tree():
		_lift = 0.0
		return
	_bump = create_tween()
	_bump.tween_interval(BUMP_SECONDS)
	_bump.tween_callback(_drop)


## The hero's and the target's cells for a hero reading `total` in `room` px.
static func cells_for(total: int, room: float) -> Vector2:
	var words: String = AMOUNT_TEXT % total
	for pair: Vector2 in CELLS:
		if PixelWords.text_size(words, PixelWords.Sheet.DIGITS, pair.x).x <= room:
			return pair
	return CELLS[-1]


## The foot's words for `total` against `quota` (whole euros): how far over it ("+67€ over"),
## how far short ("56€ short") or "on target".
static func against_text(total: int, quota: int) -> String:
	var margin: ShiftMargin = ShiftMargin.of(total, quota)
	match margin.kind():
		ShiftMargin.Kind.OVER:
			return OVER_TEXT % ReceiptView.money(margin.amount())
		ShiftMargin.Kind.SHORT:
			return SHORT_TEXT % ReceiptView.money(margin.amount())
	return ON_TEXT


## The colour of the foot's words for `total` against `quota`: green dark once met, tomato dark
## short.
static func against_color(total: int, quota: int) -> Color:
	return Palette.GREEN_DARK if ShiftMargin.of(total, quota).passed() else Palette.TOMATO_DARK


## The dessert's margin words: "+N€ OVER TARGET", "SHORT N€" or "ON TARGET" (#61's line, in the
## words of TODAY'S TARGET).
static func margin_text(kind: ShiftMargin.Kind, euros: int) -> String:
	match kind:
		ShiftMargin.Kind.OVER:
			return "%s OVER QUOTA" % ReceiptView.money(euros, true)
		ShiftMargin.Kind.SHORT:
			return "MISSED BY %s" % ReceiptView.money(euros)
	return "ON QUOTA"


## Shows `euros` on a margin `line` of `kind`, as its count passes them.
static func show_margin(line: Control, kind: ShiftMargin.Kind, euros: int) -> void:
	(line.get_child(0) as Label).text = margin_text(kind, euros)


## The margin words on the over row (the dessert counts them there), green dark or tomato dark,
## at the size their longest form fits beside the caption and the stamp's room; PAID or SLIP lands
## on the row after them (ReceiptStamps.stamp_paid). Returns the over row.
func show_margin_words(margin: ShiftMargin) -> HBoxContainer:
	var words: String = margin_text(margin.kind(), margin.amount())
	_margin_shown = true
	over.text = words
	var short: bool = margin.kind() == ShiftMargin.Kind.SHORT
	over.add_theme_color_override("font_color", COLOR if short else MET_COLOR)
	_margin_words = words
	_stamp_room_text = ReceiptStamps.PAID_TEXT if margin.passed() else STAMP_ROOM_TEXT
	_fit_margin_words()
	return over_row


## The target's digits rect in the block (for tests: inside the paper, over the rule).
func digits_rect() -> Rect2:
	return Rect2(_row.position + amount.position, amount.get_combined_minimum_size())


## The hero's, the check's and the stamp's rects in the block (for tests).
func hero_rect() -> Rect2:
	return Rect2(hero.position, hero.get_combined_minimum_size())


func check_rect() -> Rect2:
	return Rect2(_row.position + check.position, check.size)


func stamp_rect() -> Rect2:
	return Rect2(beaten.position, beaten.size)


## The over row's stamp goes (a new projection or count).
func _clear_stamp() -> void:
	_margin_words = ""
	stamp.text = ""
	stamp.visible = false


## The margin words at the size their longest form fits beside the caption and the stamp (its
## text once landed, else the room kept for it).
func _fit_margin_words() -> void:
	if _margin_words.is_empty():
		return
	var room: float = _width() - INSET - INSET_RIGHT - _text_width(total_caption) - BEAT_GAP
	room -= _stamp_width() + over_row.get_theme_constant("separation")
	over.add_theme_font_size_override(
		"font_size", ReceiptInk.fit_font_size(_margin_words, room, ROW_SIZE, WORDS_MIN_SIZE)
	)


## The width the over row keeps for the stamp: its text in its font, or the text it waits for.
func _stamp_width() -> float:
	var words: String = stamp.text if stamp.visible and not stamp.text.is_empty() else ""
	if words.is_empty():
		words = _stamp_room_text
	var font: Font = stamp.get_theme_font("font")
	var font_size: int = stamp.get_theme_font_size("font_size")
	return font.get_string_size(words, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x


## The hero's ink: the pending medal's metal while it reads PROJECTED, plain ink otherwise.
func _ink_hero() -> void:
	var projected: bool = total_caption.text == PROJECTED_TEXT
	var metal: int = _pending_metal if projected else ReceiptGold.PENDING_NONE
	match metal:
		ReceiptGold.PENDING_GOLD:
			hero.color = GOLD_HERO_COLOR
			hero.shadow = GOLD_HERO_SHADOW
		ReceiptGold.PENDING_SILVER:
			hero.color = SILVER_HERO_COLOR
			hero.shadow = SILVER_HERO_SHADOW
		_:
			hero.color = HERO_COLOR
			hero.shadow = NO_SHADOW
	_queue_layout()  # A metal's shadow takes one font px more on the right (_shadow_reach).


## How far the hero's shadow reaches past its words (one font px while it has one, else none),
## kept on the paper.
func _shadow_reach() -> float:
	return hero.cell if hero.shadow.a > 0.0 else 0.0


func _set_hero(value: int, quota: int) -> void:
	hero.text = AMOUNT_TEXT % value
	if not _margin_shown:
		over.text = against_text(value, quota) if quota >= 0 else ""
		if quota >= 0:
			over.add_theme_color_override("font_color", against_color(value, quota))
			over.remove_theme_font_size_override("font_size")
	_layout()


## The roll's number `value` on the hero, against planning's quota, at the sizes for it (they step
## as the number gains or loses a digit, never all at once on landing).
func _show_rolled(value: int, _landed: bool) -> void:
	cells = cells_for(value, _hero_room())
	_set_hero(value, _planned_quota)


func _set_lift(px: float) -> void:
	if is_equal_approx(_lift, px):
		return
	_lift = px
	_layout()


func _show_lower(on: bool) -> void:
	_lower = on
	for part: Control in [total_caption, over_row, hero]:
		part.visible = on
	custom_minimum_size.y = HEIGHT if on else TARGET_HEIGHT
	queue_redraw()


func _drop() -> void:
	_lift = 0.0
	_layout()


func _width() -> float:
	return size.x if size.x > 0.0 else DEFAULT_WIDTH


func _hero_room() -> float:
	return _width() - INSET - INSET_RIGHT


func _queue_layout() -> void:
	_layout.call_deferred()


## Every part where it stands, on even px: BEAT and the caption centred as a pair; the target (and
## its check; left of a gold stamp in its row) centred in its box; the caption and the line against
## the target on one row; the hero right-aligned in its box; BEATEN! over the header's words.
func _layout() -> void:
	if not is_instance_valid(hero):
		return
	var width: float = _width()
	var beat_size: Vector2 = beat.get_combined_minimum_size()
	var caption_size: Vector2 = caption.get_combined_minimum_size()
	var left: float = _even((width - beat_size.x - BEAT_GAP - caption_size.x) / 2.0)
	beat.size = beat_size
	beat.position = Vector2(left, BEAT_TOP)
	caption.size = caption_size
	caption.position = Vector2(
		left + beat_size.x + BEAT_GAP, _even(BEAT_TOP + (beat_size.y - caption_size.y) / 2.0)
	)
	_row.position = Vector2(0.0, TARGET_TOP)
	_row.size = Vector2(width, TARGET_BOX)
	# A reading wider than the projected total the sizes came from steps both down together, so
	# the hero stays 1.5x the target (no caller reaches it: planning sizes every count).
	hero.cell = cells.x
	if hero.get_combined_minimum_size().x + _shadow_reach() > _hero_room():
		cells = cells_for(hero.text.to_int(), _hero_room() - _shadow_reach())
		hero.cell = cells.x
	amount.cell = cells.y
	amount.color = MET_COLOR if _met else COLOR
	amount.size = amount.get_combined_minimum_size()
	check.visible = _met
	check.size = Vector2(_check_width(), _check_height())
	var group: float = amount.size.x + (CHECK_GAP + check.size.x if _met else 0.0)
	var target_left: float = _even(maxf((width - group) / 2.0, INSET))
	amount.position = Vector2(target_left, _even((TARGET_BOX - amount.size.y) / 2.0))
	check.position = Vector2(
		target_left + amount.size.x + CHECK_GAP, _even((TARGET_BOX - check.size.y) / 2.0)
	)
	total_caption.size = total_caption.get_combined_minimum_size()
	total_caption.position = Vector2(INSET, ROW_TOP)
	var over_left: float = INSET + total_caption.size.x + BEAT_GAP
	over_row.position = Vector2(over_left, ROW_TOP)
	over_row.size = Vector2(width - INSET_RIGHT - over_left, total_caption.size.y)
	hero.size = hero.get_combined_minimum_size()
	hero.position = Vector2(
		_even(width - INSET_RIGHT - _shadow_reach() - hero.size.x),
		HERO_TOP + _even((HERO_BOX - hero.size.y) / 2.0) - _lift
	)
	beaten.centre = Vector2(width / 2.0, STAMP_MIDDLE_Y)
	if beaten.settled():
		beaten.stamp(false, true)
	queue_redraw()


func _draw() -> void:
	var width: float = _width() - RULE_INSET * 2.0
	var ink: Color = RULE_MET_COLOR if _met else RULE_COLOR
	for row: int in range(2):
		var y: float = RULE_TOP + row * (RULE_WIDTH + RULE_GAP)
		draw_rect(Rect2(RULE_INSET, y, width, RULE_WIDTH), ink)
	if not _lower:
		return
	var x: float = INSET
	while x < _width() - INSET:
		var dash: float = minf(ReceiptView.RULE_DASH, _width() - INSET - x)
		draw_rect(Rect2(x, DASH_TOP, dash, ArtStyle.ART_SCALE), ReceiptGold.RULE_INK)
		x += 2.0 * ReceiptView.RULE_DASH


## The lap lamp's check, cell by cell.
func _draw_check() -> void:
	var rows: PackedStringArray = LapLamp.CHECK.split(",")
	for row: int in range(rows.size()):
		for column: int in range(rows[row].length()):
			if rows[row][column] == "#":
				var at: Vector2 = Vector2(column, row) * CHECK_CELL
				check.draw_rect(Rect2(at, Vector2.ONE * CHECK_CELL), MET_COLOR)


static func _check_width() -> float:
	return LapLamp.CHECK.split(",")[0].length() * CHECK_CELL


static func _check_height() -> float:
	return LapLamp.CHECK.split(",").size() * CHECK_CELL


static func _label(text: String, font_size: int, ink: Color, spacing: int = 0) -> Label:
	var label: Label = Label.new()
	label.text = text
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var font: Font = ReceiptView.MONO_FONT
	if spacing != 0:
		var spaced: FontVariation = FontVariation.new()
		spaced.base_font = ReceiptView.MONO_FONT
		spaced.spacing_glyph = spacing
		font = spaced
	label.add_theme_font_override("font", font)
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", ink)
	return label


static func _words(
	words: String, sheet: PixelWords.Sheet, cell: float, ink: Color, parent: Node
) -> PixelWords:
	var made: PixelWords = PixelWords.new(words, sheet, cell, ink)
	parent.add_child(made)
	return made


static func _text_width(label: Label) -> float:
	return (
		label
		. get_theme_font("font")
		. get_string_size(
			label.text, HORIZONTAL_ALIGNMENT_LEFT, -1, label.get_theme_font_size("font_size")
		)
		. x
	)


static func _even(x: float) -> float:
	return roundf(x / 2.0) * 2.0
