class_name GradeCard
extends TitlePopup
## The grade card (#182, decided with the user on 2026-11-23, prep page difficulty_grades.html;
## polished after the user's play test the same day): once a profile has won a run, START RUN
## (or NEW RUN's ABANDON) opens this card over the dimmed storefront before the run starts.
##
## A teal header band reads PICK A GRADE, a grey line under it that a win opens the next grade.
## Then the ladder: one GradeRung per grade on a rail. The picked grade and every grade under it
## are LIT (gold rings, the rail gold up to the pick), as their rules stack; the picked rung
## stands up with a tomato pointer under it. Below, the picked grade's panel: its staff badge
## (GradeBadge), its name in large pixel capitals, a status chip (THE GAME AS IT IS, BEATEN, NOT
## BEATEN YET, or LOCKED with the grade to win first), then RULES: the stacked rules from grade 1
## up, each beside its grade's number chip, the picked grade's own last with the tomato NEW tag.
## In the panel's top right corner what a win pays: its coins and, the first time, the badge pin
## it unlocks (its face and name). BACK (teal) and START (the tomato primary, GRADE n under it)
## close it.
##
## It opens on the best open grade (one above the best won). A click on a rung, or Left and
## Right, picks a grade: the newly lit rungs pop one after another, each on its note of the
## count-up's ladder (Sfx.play_note), and a grade picked lower just clicks. A locked grade shows
## its rules but START stays off (pressing it buzzes, denied). Up and Down walk BACK and START
## (the TitlePopup marker); Enter or Space presses the marked one; Esc or BACK closes it. START
## closes it and reports the grade (`started`); the title then asks the shift screen for it
## (request) and starts the run. `still` (reduced motion) shows everything at once, no pops.

## START was pressed on an open grade.
signal started(grade: int)
## BACK or Esc: the card closed and no run starts.
signal backed

## The sheet: 320x320 art.
const SHEET_ART := Vector2i(320, 320)
const TITLE := "PICK A GRADE"
const SUB_LINE := "WIN A GRADE TO OPEN THE NEXT ONE"
const RULES_HEADING := "RULES"
const WIN_HEADING := "A WIN PAYS"
const NO_BONUS := "NO BONUS"
const NO_RULES := "No extra rules"
const OPEN_SOUND := "ui_open"
const BACK_SOUND := "ui_close"
const DENIED_SOUND := "denied"
const COIN := preload("res://art/icons/coin.png")
const CHECK := preload("res://art/icons/mark_check.png")
const PADLOCK := preload("res://art/icons/padlock.png")
## The header band, in canvas px on the sheet (inside the frame's 8 px), its title centred.
const BAND := Rect2(8, 8, 624, 60)
const TITLE_RECT := Rect2(0, 16, 640, 44)
const SUB_RECT := Rect2(0, 76, 640, 14)
## The ladder: GradeRung.SIZE rungs RUNG_GAP apart, centred, their tops at LADDER_TOP, on a rail
## RAIL_HEIGHT tall through their middles; the pointer POINTER_DROP under the picked rung.
const LADDER_TOP := 108.0
const RUNG_GAP := 24.0
const RAIL_HEIGHT := 12.0
const POINTER_DROP := 8.0
const POINTER_SIZE := Vector2(16, 8)
## The picked grade's panel: an inset box; its badge at 3x, its name, its status chip.
const PANEL := Rect2(24, 184, 592, 332)
const BADGE_AT := Vector2(44, 200)
const BADGE_SCALE := 3
const NAME_RECT := Rect2(110, 200, 300, 32)
const CHIP_AT := Vector2(110, 238)
const CHIP_HEIGHT := 28.0
const CHIP_PAD := 6.0
## What a win pays, in the panel's top right corner beside a dotted upright: the heading, the
## coins, and the pin a first win unlocks (its face PIN_FACE px and its name).
const WIN_AT := Vector2(436, 200)
const WIN_RULE_X := 420.0
const WIN_STEP := 22.0
const PIN_FACE := 24.0
## The rules: a dashed rule, the heading, then one row a grade, RULE_STEP apart.
const DASH_TOP := 276.0
const HEADING_RECT := Rect2(44, 286, 200, 14)
const RULES_LEFT := 44.0
const RULES_TOP := 310.0
const RULE_STEP := 36.0
const NUMBER_CHIP := Vector2(26, 26)
const RULE_TEXT_GAP := 10.0
const RULE_SIZE := 17
const RULE_WEIGHT := 650
## A rule's leading count ("-1 redraw per shift", the Picky regular's "-15 to -30% promo on ..."):
## its pattern (the count or range, a space, the rest), its ink and the rule row's label names.
const LEAD_PATTERN := "^([-+]\\d+%?(?: to [-+]\\d+%?)?) (.+)$"
const LEAD_INK := Palette.TOMATO
const LEAD_NAME := "Lead"
const RULE_NAME := "Rule"
## The plates: BACK (a teal plate) on the left, START (the tomato primary) on the right.
const BACK_AT := Vector2(48, 548)
const BACK_SIZE := Vector2(200, 50)
const START_AT := Vector2(300, 534)
const START_SIZE := Vector2(304, 80)
const WORD_SCALE := 2
const TITLE_SCALE := 4
## START on a locked grade: dimmed (its holder: the plate sets its own modulate), as it can't be
## pressed.
const LOCKED_ALPHA := 0.6
## The ladder lighting up: a rung every LIGHT_STEP s; the notes quieter than the count-up's.
const LIGHT_STEP := 0.045
const NOTE_DB := -6.0
## A press on a locked START shakes it SHAKE px each way, a step every SHAKE_STEP s.
const SHAKE := 4.0
const SHAKE_STEP := 0.04

## The grade the title asked the shift screen to start at (request), or -1 for none.
static var _requested: int = -1

## The grade picked on the ladder.
var picked: int = 0
var _balance: BalanceDefinition
var _profile: ProfileState
var _pins: Array[PinDefinition] = []
## The highest grade the profile can start at (ProfileState.open_grade).
var _open: int = 0
var _rungs: Array[GradeRung] = []
var _rail: Control
var _pointer: Control
var _badge: GradeBadge
var _name: Label
var _chip: Panel
var _chip_line: PixelLine
var _rules: Control
var _win: Control
var _win_text: String = ""
var _back: MenuPlate
var _start: MenuPlate
## START's holder: dimmed on a locked grade, shaken when pressed there.
var _start_holder: Control
var _shaking: Tween


func _init() -> void:
	super(SHEET_ART)
	var page: Control = sheet()
	var decor: Control = Control.new()
	decor.mouse_filter = Control.MOUSE_FILTER_IGNORE
	decor.size = _sheet_size
	decor.draw.connect(_draw_decor.bind(decor))
	page.add_child(decor)
	_add_title(page)
	var sub: Label = UiKit.pixel_label(SUB_LINE, WORD_SCALE, Palette.GREY)
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	UiKit.place_pixel_label(sub, SUB_RECT, true)
	page.add_child(sub)
	_rail = Control.new()
	_rail.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_rail.size = _sheet_size
	_rail.draw.connect(_draw_rail)
	page.add_child(_rail)
	_pointer = Control.new()
	_pointer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_pointer.size = POINTER_SIZE
	_pointer.draw.connect(_draw_pointer)
	page.add_child(_pointer)
	_badge = GradeBadge.new(BADGE_SCALE)
	_badge.position = BADGE_AT
	page.add_child(_badge)
	_name = UiKit.pixel_label("", TITLE_SCALE, Palette.INK)
	UiKit.place_pixel_label(_name, NAME_RECT, true)
	page.add_child(_name)
	_chip = Panel.new()
	_chip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_chip.position = CHIP_AT
	page.add_child(_chip)
	_chip_line = PixelLine.new()
	_chip.add_child(_chip_line)
	var heading: Label = UiKit.pixel_label(RULES_HEADING, WORD_SCALE, Palette.GREY)
	UiKit.place_pixel_label(heading, HEADING_RECT, true)
	page.add_child(heading)
	_rules = Control.new()
	_rules.mouse_filter = Control.MOUSE_FILTER_IGNORE
	page.add_child(_rules)
	_win = Control.new()
	_win.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_win.position = WIN_AT
	page.add_child(_win)
	_back = MenuPlate.new("BACK", MenuPlate.Kind.PLATE, BACK_SIZE)
	_back.centre_caption()
	_back.position = BACK_AT
	page.add_child(_back)
	_start_holder = Control.new()
	_start_holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_start_holder.position = START_AT
	page.add_child(_start_holder)
	_start = MenuPlate.new("START", MenuPlate.Kind.PRIMARY, START_SIZE)
	_start_holder.add_child(_start)
	for plate: MenuPlate in [_back, _start] as Array[MenuPlate]:
		_add_entry(plate)
		plate.pressed.connect(_press.bind(plate))
	_start.gui_input.connect(_on_start_input)


## The title, as it starts a run from the card: the next shift screen's new run plays `grade`.
static func request(grade: int) -> void:
	_requested = grade


## The requested grade, once (0 when none was requested): the shift screen's new run takes it.
static func take_request() -> int:
	var grade: int = maxi(_requested, 0)
	_requested = -1
	return grade


## Whether a new run of `profile` asks for a grade first: a grade above 0 is open (a run was won)
## and the next run isn't the guided one (it plays grade 0).
static func wanted(profile: ProfileState, balance: BalanceDefinition) -> bool:
	if profile == null or TutorialFlags.guided_due(profile):
		return false
	return open_grade_of(profile, balance) > 0


## The highest grade `profile` can start at: every grade when the play-test setting
## `next_customer/all_grades_open` is on, else ProfileState.open_grade.
static func open_grade_of(profile: ProfileState, balance: BalanceDefinition) -> int:
	var count: int = GradeApply.count(balance)
	if bool(ProjectSettings.get_setting("next_customer/all_grades_open", false)):
		return maxi(count - 1, 0)
	return profile.open_grade(count)


## Opens the card for `profile` on `balance`'s ladder (`pins`: the catalogue's, for the pin a win
## unlocks), on the best open grade, the marker on START, with ui_open; steps in unless `still`,
## the ladder lighting up to the pick. Returns the step-in (null when still).
func open(profile: ProfileState, balance: BalanceDefinition, pins: Array[PinDefinition]) -> Tween:
	_profile = profile
	_balance = balance
	_pins = pins
	_open = open_grade_of(profile, balance)
	_build_ladder()
	picked = -1
	Sfx.play_at(self, OPEN_SOUND)
	var opening: Tween = _show_popup()
	pick(_open)
	_set_marked(_entries.find(_start))
	return opening


## Picks grade `grade` (clamped to the ladder): its rung and every one under it light, the rungs
## newly lit pop in turn on rising notes, and the badge, name, status, rules and win line show it;
## START is off (dimmed) for a locked grade.
func pick(grade: int) -> void:
	var before: int = picked
	picked = clampi(grade, 0, _rungs.size() - 1)
	for tile: GradeRung in _rungs:
		tile.set_state(tile.grade <= picked, tile.grade == picked)
	if picked > before:
		var first: int = maxi(before + 1, 0)
		for index: int in range(first, picked + 1):
			var delay: float = (index - first) * LIGHT_STEP
			_rungs[index].pop(delay, still)
			_play_note_after(index, delay)
	elif picked < before:
		_rungs[picked].pop(0.0, still)
		Sfx.play_at(self, UiKit.CLICK_SOUND)
	_rail.queue_redraw()
	var at: Vector2 = _rungs[picked].position
	_pointer.position = Vector2(
		at.x + floorf((GradeRung.SIZE.x - POINTER_SIZE.x) / 4.0) * 2.0,
		LADDER_TOP + GradeRung.SIZE.y + POINTER_DROP
	)
	var rules: GradeDefinition = GradeApply.grade_of(_balance, picked)
	_badge.grade = picked
	_name.text = rules.display_name if rules != null else "GRADE"
	_show_chip()
	_show_rules()
	_show_win()
	_start.disabled = picked > _open
	_start_holder.modulate.a = LOCKED_ALPHA if _start.disabled else 1.0
	_start.sub_line = "LOCKED" if _start.disabled else "GRADE %d" % picked


## The rung of `grade` (tests read its place and state).
func rung(grade: int) -> GradeRung:
	return _rungs[grade]


## The stacked rules' text labels shown, in order (tests; a rule's tomato lead is rule_lead's).
func rule_lines() -> Array[Label]:
	var found: Array[Label] = []
	for row: Node in _rules.get_children():
		var line: Label = row.get_node_or_null(NodePath(RULE_NAME)) as Label
		if line != null:
			found.append(line)
	return found


## The stacked rules as written, lead and rest together, in order (tests).
func rule_texts() -> PackedStringArray:
	var found: PackedStringArray = PackedStringArray()
	for index: int in range(_rules.get_child_count()):
		var lead: Label = rule_lead(index)
		var line: Label = _rules.get_child(index).get_node_or_null(NodePath(RULE_NAME)) as Label
		var rest: String = line.text if line != null else ""
		found.append(rest if lead == null else "%s %s" % [lead.text, rest])
	return found


## Rule row `index`'s tomato lead ("-1"), or null (tests).
func rule_lead(index: int) -> Label:
	if index < 0 or index >= _rules.get_child_count():
		return null
	return _rules.get_child(index).get_node_or_null(NodePath(LEAD_NAME)) as Label


## `text` split into its lead count ("-1", "+2") and the rest after its space; the lead is ""
## when the text has none.
static func split_lead(text: String) -> PackedStringArray:
	var found: RegExMatch = RegEx.create_from_string(LEAD_PATTERN).search(text)
	if found == null:
		return PackedStringArray(["", text])
	return PackedStringArray([found.get_string(1), found.get_string(2)])


## The rule rows (number chip, text and the NEW tag on the picked grade's own), in order (tests
## read their places).
func rule_rows() -> Array[Control]:
	var found: Array[Control] = []
	for row: Node in _rules.get_children():
		found.append(row as Control)
	return found


## The NEW tag on the picked grade's own rule, or null (grade 0).
func new_tag() -> ToyNewTag:
	for row: Node in _rules.get_children():
		for child: Node in row.get_children():
			if child is ToyNewTag:
				return child as ToyNewTag
	return null


func start_plate() -> MenuPlate:
	return _start


func back_plate() -> MenuPlate:
	return _back


func badge() -> GradeBadge:
	return _badge


func pointer() -> Control:
	return _pointer


func status_chip() -> Panel:
	return _chip


## The status chip's words ("BEATEN", "LOCKED · WIN GRADE 2 FIRST").
func status_text() -> String:
	return _chip_line.text()


## The win row (tests read its place).
func win_row() -> Control:
	return _win


## What the win row says, in plain words ("Win: +3 coins and the Express lane badge pin").
func win_text() -> String:
	return _win_text


## Left and Right pick the grade beside the picked one; the other keys are the popup's.
func handle_key(event: InputEvent) -> bool:
	var key: InputEventKey = event as InputEventKey
	if is_open() and key != null and key.pressed:
		if key.keycode == KEY_LEFT or key.keycode == KEY_RIGHT:
			var step: int = 1 if key.keycode == KEY_RIGHT else -1
			pick(clampi(picked + step, 0, _rungs.size() - 1))
			return true
		if key.keycode == KEY_UP or key.keycode == KEY_DOWN:
			move_marker(1 if key.keycode == KEY_DOWN else -1)
			return true
	return super(event)


## The title in paper over an ink shadow one art px down and right, on the band.
func _add_title(page: Control) -> void:
	for shadow: bool in [true, false]:
		var colour: Color = Palette.INK if shadow else Palette.PAPER
		var title: Label = UiKit.pixel_label(TITLE, TITLE_SCALE, colour)
		title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		var rect: Rect2 = TITLE_RECT
		if shadow:
			rect.position += Vector2.ONE * ArtStyle.ART_SCALE
		UiKit.place_pixel_label(title, rect, true)
		page.add_child(title)


func _build_ladder() -> void:
	for old: GradeRung in _rungs:
		old.queue_free()
	_rungs.clear()
	var count: int = GradeApply.count(_balance)
	var width: float = count * GradeRung.SIZE.x + (count - 1) * RUNG_GAP
	var left: float = floorf((_sheet_size.x - width) / 4.0) * 2.0
	for grade: int in range(count):
		var tile: GradeRung = GradeRung.new(grade, grade <= _profile.best_grade_won, grade > _open)
		tile.position = Vector2(left + grade * (GradeRung.SIZE.x + RUNG_GAP), LADDER_TOP)
		var rules: GradeDefinition = GradeApply.grade_of(_balance, grade)
		tile.accessibility_name = rules.display_name if rules != null else str(grade)
		tile.gui_input.connect(_on_rung_input.bind(tile))
		sheet().add_child(tile)
		_rungs.append(tile)
	sheet().move_child(_pointer, -1)


func _on_rung_input(event: InputEvent, tile: GradeRung) -> void:
	var click: InputEventMouseButton = event as InputEventMouseButton
	if click == null or click.button_index != MOUSE_BUTTON_LEFT:
		return
	tile.set_pressed(click.pressed)
	if click.pressed:
		pick(tile.grade)


## Rung `index`'s note of the count-up's ladder, `delay` s from now (at once when still).
func _play_note_after(index: int, delay: float) -> void:
	var sfx: Sfx = Sfx.find(self)
	if sfx == null:
		return
	if delay <= 0.0 or still:
		sfx.play_note(index, NOTE_DB)
		return
	get_tree().create_timer(delay).timeout.connect(
		func() -> void:
			if is_open():
				sfx.play_note(index, NOTE_DB)
	)


## The status chip: its words (and icon) on a fill in the grade's state colour, ink edged.
func _show_chip() -> void:
	var fill: Color = Palette.MUSTARD
	var ink: Color = Palette.INK
	var tokens: Array = ["NOT BEATEN YET"]
	if picked == 0:
		fill = Palette.TEAL
		ink = Palette.PAPER
		tokens = ["THE GAME AS IT IS"]
	elif picked <= _profile.best_grade_won:
		fill = Palette.GOOD
		ink = Palette.PAPER
		tokens = [CHECK, "BEATEN"]
	elif picked > _open:
		fill = Palette.GREY_LIGHT
		ink = Palette.GREY_DARK
		tokens = [PADLOCK, "LOCKED", PixelLine.SEPARATOR, "WIN GRADE", str(picked - 1), "FIRST"]
	_chip_line.show_tokens(tokens, ink, ink)
	_chip.add_theme_stylebox_override("panel", _box(fill))
	# The line's ink (its capitals, taller digits and icon) centred in the chip on the art grid
	# (the user's 2026-11-23 polish: the padlock sat low, the words high).
	var drawn: Rect2 = _chip_line.ink_rect()
	_chip.size = Vector2(drawn.size.x + CHIP_PAD * 2.0, CHIP_HEIGHT)
	_chip_line.position = centred_on_grid(drawn, _chip.size)


## The stacked rules: grade 1 up to the picked one, each beside its number chip; the picked
## grade's own last, in tomato, with the NEW tag. Grade 0: its own line, in grey.
func _show_rules() -> void:
	for child: Node in _rules.get_children():
		_rules.remove_child(child)
		child.queue_free()
	var lines: PackedStringArray = GradeApply.rule_lines(_balance, picked)
	if lines.is_empty():
		var base: GradeDefinition = GradeApply.grade_of(_balance, 0)
		var none: Control = _rule_row(-1, base.rule_text if base != null else NO_RULES, false)
		none.position = Vector2(RULES_LEFT, RULES_TOP)
		_rules.add_child(none)
		return
	for index: int in range(lines.size()):
		var row: Control = _rule_row(index + 1, lines[index], index == lines.size() - 1)
		row.position = Vector2(RULES_LEFT, RULES_TOP + index * RULE_STEP)
		_rules.add_child(row)


## One rule row: the grade's number chip (`grade`; -1 for none), its text, and the NEW tag when
## `own`.
func _rule_row(grade: int, text: String, own: bool) -> Control:
	var row: Control = Control.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var x: float = 0.0
	if grade >= 0:
		row.add_child(_number_chip(grade, own))
		x = NUMBER_CHIP.x + RULE_TEXT_GAP
	var colour: Color = Palette.INK
	if own:
		colour = Palette.TOMATO_DARK
	elif grade < 0:
		colour = Palette.GREY
	var font_size: int = UiKit.text_size(RULE_SIZE)
	var bold: Font = ArtStyle.bold_font(RULE_WEIGHT)
	var parts: PackedStringArray = split_lead(text)
	if not parts[0].is_empty():
		# A rule's count ("-1 redraw per shift"; the user's play test of 2026-11-24) in tomato.
		var lead: Label = _rule_label(parts[0], LEAD_INK, bold, font_size, x)
		lead.name = LEAD_NAME
		row.add_child(lead)
		var space: float = bold.get_string_size(" ", HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
		x = lead.position.x + lead.size.x + ceilf(space)
	var line: Label = _rule_label(parts[1], colour, bold, font_size, x)
	line.name = RULE_NAME
	row.add_child(line)
	var right: float = line.position.x + line.size.x
	if own:
		var tag: ToyNewTag = ToyNewTag.new()
		tag.position = Vector2(
			2.0 * ceilf((right + 6.0) / 2.0), 2.0 * floorf((NUMBER_CHIP.y - tag.size.y) / 4.0)
		)
		row.add_child(tag)
		tag.set_shown(true, still)
		right = tag.position.x + tag.size.x
	row.size = Vector2(right, NUMBER_CHIP.y)
	return row


## One label of a rule row: `text` in the bold face, `colour`, at `x`, centred on the row's
## height.
func _rule_label(text: String, colour: Color, bold: Font, font_size: int, x: float) -> Label:
	var line: Label = UiKit.body_label(text, font_size, colour)
	line.add_theme_font_override("font", bold)
	line.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	line.position = Vector2(x, 0)
	# Measured from the bold face itself: a label out of the tree can report the default font's.
	var width: float = bold.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	line.size = Vector2(ceilf(width), NUMBER_CHIP.y)
	return line


## A rule's grade number on a little rung: brass when that grade is beaten, teal when open, slate
## when locked; the picked grade's own in tomato.
func _number_chip(grade: int, own: bool) -> Control:
	var fill: Color = Palette.TEAL
	if own:
		fill = Palette.TOMATO
	elif grade <= _profile.best_grade_won:
		fill = Palette.BRASS
	elif grade > _open:
		fill = Palette.SLATE
	var chip: Panel = Panel.new()
	chip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	chip.size = NUMBER_CHIP
	chip.add_theme_stylebox_override("panel", _box(fill))
	var digits: String = str(grade)
	var number: PixelWords = PixelWords.new(digits, PixelWords.Sheet.CHUNKY, 2.0, Palette.PAPER)
	number.shadow = Palette.INK
	var shown: Vector2 = PixelWords.text_size(digits, PixelWords.Sheet.CHUNKY, 2.0)
	number.size = shown
	# The digits and their shadow (one font px down and right) centred in the chip (the user's
	# 2026-11-23 polish): a 13 art px chip centres every digit's 7 or 5 by 9 exactly.
	number.position = centred_on_grid(Rect2(Vector2.ZERO, shown + Vector2.ONE * 2.0), NUMBER_CHIP)
	chip.add_child(number)
	return chip


## Where to put a control whose drawn ink is `ink` (from its top left) so the ink is centred in a
## box `box` px big, floored onto the 2 px art grid.
static func centred_on_grid(ink: Rect2, box: Vector2) -> Vector2:
	var at: Vector2 = (box - ink.size) / 2.0 - ink.position
	return (at / ArtStyle.ART_SCALE).floor() * ArtStyle.ART_SCALE


## A flat box in `fill`, edged in ink 2 px (one art px).
static func _box(fill: Color) -> StyleBoxFlat:
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = Palette.INK
	style.set_border_width_all(2)
	return style


## What a win at the picked grade pays, in the panel's corner: A WIN PAYS, the coin and the
## grade's bonus, and the badge pin a first win there unlocks when the profile doesn't own it yet
## (its face and name).
func _show_win() -> void:
	for child: Node in _win.get_children():
		_win.remove_child(child)
		child.queue_free()
	var bonus: int = GradeApply.coin_bonus(_balance, picked)
	_win_text = "Win: +%d coins" % bonus if bonus > 0 else "Win: no bonus"
	var heading: PixelLine = PixelLine.new()
	heading.show_tokens([WIN_HEADING], Palette.GREY, Palette.GREY)
	_win.add_child(heading)
	var coins: PixelLine = PixelLine.new()
	var tokens: Array = [COIN]
	if bonus > 0:
		tokens.append_array(["+", str(bonus), "COINS" if bonus > 1 else "COIN"])
	else:
		tokens.append(NO_BONUS)
	coins.show_tokens(tokens, Palette.INK, Palette.MUSTARD_DARKEST)
	coins.position = Vector2(0, WIN_STEP)
	_win.add_child(coins)
	var right: float = maxf(heading.width(), coins.width())
	var bottom: float = coins.position.y + coins.size.y
	var pin: PinDefinition = _unlocked_pin()
	if pin != null:
		_win_text += " and the %s badge pin" % pin.display_name
		var face: PinFace = PinFace.new(PIN_FACE)
		face.show_pin(pin, _pins.find(pin))
		var cap: float = ArtStyle.PIXEL_CAP_HEIGHT * ArtStyle.ART_SCALE
		face.position = Vector2(-2, WIN_STEP * 2.0 - 2.0 * floorf((PIN_FACE - cap) / 4.0))
		_win.add_child(face)
		var name_line: PixelLine = PixelLine.new()
		name_line.show_tokens([pin.display_name.to_upper()], Palette.INK, Palette.INK)
		name_line.position = Vector2(face.position.x + PIN_FACE + 6.0, WIN_STEP * 2.0)
		_win.add_child(name_line)
		right = maxf(right, name_line.position.x + name_line.width())
		bottom = face.position.y + PIN_FACE
	_win.size = Vector2(right, bottom)


## The badge pin a first win at the picked grade unlocks, when the profile doesn't own it yet.
func _unlocked_pin() -> PinDefinition:
	for pin: PinDefinition in _pins:
		var condition: UnlockCondition = pin.unlock_condition
		if (
			condition != null
			and condition.kind == UnlockCondition.Kind.WIN_AT_GRADE
			and condition.amount == picked
			and not _profile.has_pin(pin)
		):
			return pin
	return null


## The band, the panel and its dashed rule, under everything.
func _draw_decor(decor: Control) -> void:
	decor.draw_rect(BAND, Palette.TEAL_DARK)
	decor.draw_rect(Rect2(BAND.position, Vector2(BAND.size.x, 2)), Palette.TEAL_SHADE)
	decor.draw_rect(Rect2(BAND.position.x, BAND.end.y - 2.0, BAND.size.x, 2), Palette.TEAL_BLACK)
	decor.draw_rect(PANEL, Palette.CREAM)
	decor.draw_rect(PANEL, Palette.INK, false, 2.0)
	var shade: Rect2 = Rect2(PANEL.position + Vector2(2, 2), Vector2(PANEL.size.x - 4.0, 2))
	decor.draw_rect(shade, Palette.CREAM_SHADE)
	var x: float = PANEL.position.x + 20.0
	while x < PANEL.end.x - 20.0:
		decor.draw_rect(Rect2(x, DASH_TOP, 4, 2), Palette.CREAM_SHADE)
		x += 8.0
	var y: float = WIN_AT.y
	while y < DASH_TOP - 12.0:
		decor.draw_rect(Rect2(WIN_RULE_X, y, 2, 4), Palette.CREAM_SHADE)
		y += 8.0


## The rail through the rungs' middles: slate, gold from the first rung to the picked one.
func _draw_rail() -> void:
	if _rungs.is_empty():
		return
	var top: float = LADDER_TOP + floorf((GradeRung.SIZE.y - RAIL_HEIGHT) / 4.0) * 2.0
	var half: float = GradeRung.SIZE.x / 2.0
	var left: float = _rungs[0].position.x + half
	var right: float = _rungs[_rungs.size() - 1].position.x + half
	var lit: float = _rungs[maxi(picked, 0)].position.x + half
	var full: Rect2 = Rect2(left, top, right - left, RAIL_HEIGHT)
	_rail.draw_rect(full, Palette.INK)
	_rail.draw_rect(full.grow(-2.0), Palette.SLATE)
	if lit > left:
		_rail.draw_rect(Rect2(left, top + 2.0, lit - left, RAIL_HEIGHT - 4.0), Palette.GOLD)
		_rail.draw_rect(Rect2(left, top + RAIL_HEIGHT - 4.0, lit - left, 2), Palette.BRASS)


## The pointer: a tomato triangle under the picked rung, pointing down at the panel, ink edged.
func _draw_pointer() -> void:
	var width: float = POINTER_SIZE.x
	for row: int in range(int(POINTER_SIZE.y / 2.0)):
		var inset: float = row * 2.0
		var colour: Color = Palette.INK if row == 0 else Palette.TOMATO
		_pointer.draw_rect(Rect2(inset, row * 2.0, width - inset * 2.0, 2), colour)
		_pointer.draw_rect(Rect2(inset, row * 2.0, 2, 2), Palette.INK)
		_pointer.draw_rect(Rect2(width - inset - 2.0, row * 2.0, 2, 2), Palette.INK)


func _show_marked(entry: Control, on: bool) -> void:
	(entry as MenuPlate).marked = on


func _press(entry: Control) -> void:
	if not is_open():
		return
	if entry == _start:
		if _start.disabled:
			_deny()
			return
		close()
		started.emit(picked)
	else:
		_cancel()


## A click on START while it is off (a locked grade; a disabled button sends no `pressed`).
func _on_start_input(event: InputEvent) -> void:
	var click: InputEventMouseButton = event as InputEventMouseButton
	if click != null and click.pressed and click.button_index == MOUSE_BUTTON_LEFT:
		if _start.disabled and is_open():
			_deny()


## A press on START at a locked grade: the denied buzz and a shake (none when still).
func _deny() -> void:
	Sfx.play_at(self, DENIED_SOUND)
	if still:
		return
	if _shaking != null:
		_shaking.kill()
	_start_holder.position = START_AT
	_shaking = create_tween()
	for offset: float in [SHAKE, -SHAKE, SHAKE / 2.0, 0.0]:
		_shaking.tween_callback(
			func() -> void: _start_holder.position = START_AT + Vector2(offset, 0)
		)
		_shaking.tween_interval(SHAKE_STEP)


## BACK or Esc: closes with ui_close; no run starts.
func _cancel() -> void:
	Sfx.play_at(self, BACK_SOUND)
	close()
	backed.emit()
