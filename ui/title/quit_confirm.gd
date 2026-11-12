class_name QuitConfirm
extends TitlePopup
## The quit question (the title's QUIT plate or Esc on the title): over the dimmed storefront, a
## popup asks QUIT GAME? (with a run saved, the line under it says it stays saved); YES (the
## tomato primary plate) closes the game, NO (a shelf-label plate) or Esc keeps it open. Its
## look is AbandonConfirm's. It opens with ui_open; NO closes with ui_close. The mouse and the
## keys share one marker (TitlePopup): the arrows walk YES and NO, Enter or Space press the
## marked one, and it opens on NO, so Esc then Enter never quits by accident. Desktop only: the
## web build offers no quit (its tab is closed instead).

## YES was pressed: the title closes the game.
signal quit_confirmed
## NO or Esc: the question closed.
signal kept

const SHEET_ART := Vector2i(220, 96)
const QUESTION := "QUIT GAME?"
const SAVED_LINE := "YOUR RUN STAYS SAVED"
const OPEN_SOUND := "ui_open"
const KEEP_SOUND := "ui_close"
## The places on the sheet, in canvas px from its top left (AbandonConfirm's text): YES and NO
## sized to their short words, side by side and centred, their middles level, with room for the
## marker's tick between them.
const QUESTION_RECT := Rect2(0, 14, 440, 32)
const LINE_RECT := Rect2(0, 52, 440, 24)
const YES_AT := Vector2(96, 100)
const YES_SIZE := Vector2(104, 52)
const NO_AT := Vector2(240, 104)
const NO_SIZE := Vector2(104, 44)
const WORD_SCALE := 2
const LINE_SIZE := 16

var _line: Label
var _yes: MenuPlate
var _no: MenuPlate


func _init() -> void:
	super(SHEET_ART)
	var page: Control = sheet()
	var question: Label = UiKit.pixel_label(QUESTION, WORD_SCALE, Palette.INK)
	question.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	UiKit.place_pixel_label(question, QUESTION_RECT, true)
	page.add_child(question)
	_line = UiKit.body_label("", LINE_SIZE, Palette.GREY)
	_line.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_line.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_line.position = LINE_RECT.position
	_line.size = LINE_RECT.size
	page.add_child(_line)
	_yes = MenuPlate.new("YES", MenuPlate.Kind.PRIMARY, YES_SIZE)
	_yes.centre_caption(WORD_SCALE)
	_yes.position = YES_AT
	page.add_child(_yes)
	_no = MenuPlate.new("NO", MenuPlate.Kind.PLATE, NO_SIZE)
	_no.centre_caption()
	_no.position = NO_AT
	page.add_child(_no)
	for plate: MenuPlate in [_yes, _no] as Array[MenuPlate]:
		_add_entry(plate)
		plate.pressed.connect(_press.bind(plate))


## Asks, with ui_open, the marker on NO; `saved`: a run is saved (the line says it stays).
## Steps in unless `still`; returns the step-in (null when still).
func open(saved: bool) -> Tween:
	_line.text = SAVED_LINE if saved else ""
	Sfx.play_at(self, OPEN_SOUND)
	var opening: Tween = _show_popup()
	_set_marked(_entries.find(_no))
	return opening


func yes_plate() -> MenuPlate:
	return _yes


func no_plate() -> MenuPlate:
	return _no


func line_label() -> Label:
	return _line


func _show_marked(entry: Control, on: bool) -> void:
	(entry as MenuPlate).marked = on


func _press(entry: Control) -> void:
	if not is_open():
		return
	if entry == _yes:
		Sfx.play_at(self, UiKit.CLICK_SOUND)
		close()
		quit_confirmed.emit()
	else:
		_cancel()


## NO or Esc: closes with ui_close.
func _cancel() -> void:
	Sfx.play_at(self, KEEP_SOUND)
	close()
	kept.emit()
