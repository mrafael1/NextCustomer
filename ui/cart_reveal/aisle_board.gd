class_name AisleBoard
extends Control
## YOUR STORE's aisle board (full build plan 7.2, reworked 2026-11-05): the Staples shelf row
## and every aisle in data order, one continuous list, each row coloured by its status (STARTER
## CART green, RUN ONLY orange, muted when not in stock today), a legend, and a note under the
## rows. While a regular is carried the rows show where it can go (DROP HERE) or why not. The
## board only displays: StorePage holds the draft statuses and routes its clicks.

signal row_clicked(id: StringName)
signal row_hovered(id: StringName)

enum Status { OFF, GREEN, ORANGE }

## The board's panel, its rows' left, width, first top, step and height (stage px).
const RECT := Rect2(16, 114, 430, 478)
const ROW_X := 24.0
const ROW_WIDTH := 414.0
const ROW_TOP := 184.0
const ROW_STEP := 40.0
const ROW_HEIGHT := 36.0
## A row's status pill (row px) and the note under the rows (stage px).
const PILL := Rect2(286, 5, 120, 26)
const NOTE := Rect2(24, 470, 414, 112)
const FACES: Dictionary[Status, Color] = {
	Status.OFF: Palette.TEAL_BLACK,
	Status.GREEN: Palette.GREEN_DARK,
	Status.ORANGE: Palette.BRASS_DARK
}
const EDGES: Dictionary[Status, Color] = {
	Status.OFF: Palette.RUBBER_DARK,
	Status.GREEN: Palette.GREEN_LIGHT,
	Status.ORANGE: Palette.MUSTARD
}
const LEGEND: Array[Array] = [
	[Status.GREEN, "STARTER CART"], [Status.ORANGE, "RUN ONLY"], [Status.OFF, "NOT TODAY"]
]
## A row that can't take the carried regular, or that a full status leaves as it is.
const MUTED := Color(0.6, 0.62, 0.62, 1.0)

## The rows' ids, the Staples shelf (StartSetup.STAPLES) first, then data order.
var ids: Array[StringName] = []
var rows: Dictionary[StringName, Panel] = {}
var note_title: Label
var note_body: Label
## The keyboard's row (an index of `ids`, -1: none).
var focus: int = -1
var _focus_frame: Panel


## Builds the board. `statuses`: each aisle's status (the draft in SELECT); `tips`: each row's
## tooltip; `pills`: each row's pill words ("" none); `clickable`: rows a click changes;
## `targets`: while a regular is carried, each aisle's target_block reason (empty: not carrying).
func show_board(
	run: RunState,
	profile: ProfileState,
	statuses: Dictionary[StringName, Status],
	tips: Dictionary[StringName, String],
	pills: Dictionary[StringName, String],
	clickable: Array[StringName],
	targets: Dictionary[StringName, StringName]
) -> void:
	StartBoardKit.clear(self)
	ids.clear()
	rows.clear()
	size = ShiftStage.SIZE
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var board: Panel = StartBoardKit.panel(self, RECT, Palette.TEAL_DARK, Palette.TEAL_LIGHT)
	board.name = "Board"
	StartBoardKit.words(self, "YOUR AISLES", Rect2(32, 122, 220, 28), Palette.MUSTARD_LIGHT)
	_legend()
	ids.append(StartSetup.STAPLES)
	for aisle: AisleDefinition in run.balance.aisles:
		ids.append(aisle.id)
	var carrying: bool = not targets.is_empty()
	for index: int in ids.size():
		var id: StringName = ids[index]
		var aisle: AisleDefinition = _aisle(run, id)
		var status: Status = Status.GREEN if aisle == null else statuses.get(id, Status.OFF)
		var row: Panel = StartBoardKit.panel(
			self,
			Rect2(ROW_X, ROW_TOP + index * ROW_STEP, ROW_WIDTH, ROW_HEIGHT),
			FACES[status],
			EDGES[status]
		)
		row.name = "Row_%s" % id
		row.set_meta("status", status)
		row.mouse_filter = Control.MOUSE_FILTER_STOP
		row.tooltip_text = tips.get(id, "")
		var target: bool = carrying and targets.has(id) and targets[id] == &""
		var lit: bool = clickable.has(id) or target
		row.mouse_default_cursor_shape = (
			Control.CURSOR_POINTING_HAND if lit else Control.CURSOR_ARROW
		)
		row.gui_input.connect(_row_input.bind(id))
		row.mouse_entered.connect(func() -> void: row_hovered.emit(id))
		row.mouse_exited.connect(func() -> void: row_hovered.emit(&""))
		rows[id] = row
		_fill_row(run, profile, row, aisle, status, pills.get(id, ""), target)
		if carrying and not target:
			row.modulate = MUTED
		elif target:
			var style: StyleBoxFlat = row.get_theme_stylebox("panel") as StyleBoxFlat
			style.border_color = Palette.GOLD
			style.set_border_width_all(4)
	_focus_frame = StartBoardKit.panel(
		self, Rect2(0, 0, ROW_WIDTH + 8, ROW_HEIGHT + 8), Color(0, 0, 0, 0), Palette.GOLD
	)
	_focus_frame.name = "Focus"
	(_focus_frame.get_theme_stylebox("panel") as StyleBoxFlat).set_border_width_all(4)
	set_focus(focus)
	var note: Panel = StartBoardKit.panel(self, NOTE, Palette.TEAL_BLACK, Palette.INK)
	note.name = "Note"
	note_title = StartBoardKit.tag(note, "", Rect2(12, 8, 390, 24), Palette.MUSTARD_LIGHT)
	note_title.name = "Title"
	note_body = StartBoardKit.body(note, "", Rect2(12, 36, 390, 68), Palette.PAPER, 14)
	note_body.name = "Body"
	note_body.add_theme_font_override("font", ArtStyle.bold_font(700))
	note_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART


## Sets the note under the rows: pixel `title` over one or two lines of `body`.
func set_note(title: String, body: String) -> void:
	note_title.text = title
	UiKit.place_pixel_label(note_title, Rect2(12, 8, 390, 24), true)
	note_body.text = body


## Moves the keyboard's frame to row `index` (-1 hides it).
func set_focus(index: int) -> void:
	focus = index if index >= 0 and index < ids.size() else -1
	if _focus_frame == null:
		return
	_focus_frame.visible = focus >= 0
	if focus >= 0:
		_focus_frame.position = Vector2(ROW_X - 4, ROW_TOP + focus * ROW_STEP - 4)


## The row under global point `point` (its id), or &"".
func row_at(point: Vector2) -> StringName:
	for id: StringName in ids:
		if rows[id].get_global_rect().has_point(point):
			return id
	return &""


## Row `id`'s rect in stage px.
func row_rect(id: StringName) -> Rect2:
	var index: int = ids.find(id)
	return Rect2(ROW_X, ROW_TOP + maxi(index, 0) * ROW_STEP, ROW_WIDTH, ROW_HEIGHT)


func _row_input(event: InputEvent, id: StringName) -> void:
	var button: InputEventMouseButton = event as InputEventMouseButton
	if button != null and button.pressed and button.button_index == MOUSE_BUTTON_LEFT:
		accept_event()
		row_clicked.emit(id)


func _fill_row(
	run: RunState,
	profile: ProfileState,
	row: Panel,
	aisle: AisleDefinition,
	status: Status,
	pill_text: String,
	target: bool
) -> void:
	var held: int = (
		RunStock.items(aisle, profile.unlocked_items).size()
		if aisle != null
		else run.balance.staples.size()
	)
	var total: int = StartSetupRules.total_items(aisle) if aisle != null else held
	var off: bool = status == Status.OFF
	var glyph: TextureRect = StartBoardKit.icon(row, StartBoardKit.glyph(aisle), Vector2(8, 8))
	var ink: Color = Palette.GREY_LIGHT if off else Palette.PAPER
	if off:
		glyph.modulate = Color(0.55, 0.57, 0.56)
	var name_label: Label = StartBoardKit.tag(
		row, aisle.display_name if aisle != null else "Staples shelf", Rect2(34, 2, 170, 32), ink
	)
	name_label.name = "Name"
	var complete: bool = aisle != null and held == total
	var count: Label = StartBoardKit.number(
		row,
		str(held) if aisle == null else "%d/%d%s" % [held, total, "★" if complete else ""],
		Rect2(198, 2, 80, 32),
		Palette.MUSTARD_LIGHT if complete and not off else ink,
		22
	)
	count.name = "Items"
	count.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	if pill_text == "":
		return
	var face: Color = Palette.GOLD if target else Color(Palette.INK, 0.35)
	var pill: Panel = StartBoardKit.panel(
		row, PILL, face, Palette.INK if target else Color(0, 0, 0, 0)
	)
	pill.name = "Pill"
	var words: Label = StartBoardKit.tag(
		pill,
		pill_text,
		Rect2(0, 0, PILL.size.x, PILL.size.y - 2),
		Palette.INK if target else ink,
		2,
		true
	)
	words.name = "Words"


## The swatches over the rows: what each row colour means.
func _legend() -> void:
	var legend: Control = Control.new()
	legend.name = "Legend"
	legend.position = Vector2(32, 154)
	legend.size = Vector2(404, 20)
	legend.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(legend)
	var font: Font = ArtStyle.bold_font(700)
	var x: float = 0
	for entry: Array in LEGEND:
		var status: Status = entry[0]
		StartBoardKit.panel(legend, Rect2(x, 2, 22, 16), FACES[status], EDGES[status])
		var words: String = entry[1]
		var label: Label = StartBoardKit.body(
			legend, words, Rect2(x + 28, -1, 130, 20), Palette.PAPER, 13
		)
		label.add_theme_font_override("font", font)
		x += 28 + ceilf(font.get_string_size(words, HORIZONTAL_ALIGNMENT_LEFT, -1, 13).x) + 18


static func _aisle(run: RunState, id: StringName) -> AisleDefinition:
	for aisle: AisleDefinition in run.balance.aisles:
		if aisle.id == id:
			return aisle
	return null
