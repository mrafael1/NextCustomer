class_name QuitConfirm
extends TitlePopup
## The quit question (the title's QUIT plate or Esc on the title): over the dimmed storefront, a
## popup asks QUIT GAME? (with a run saved, the line under it says it stays saved); QUIT (the
## tomato primary plate) closes the game, STAY (a shelf-label plate) or Esc keeps it open. Its
## look and layout are AbandonConfirm's (polish audit v1.36: the same plates at the same places,
## QUIT / STAY for YES / NO); with no run saved the empty line folds away and the sheet is
## shorter. It opens with ui_open; STAY closes with ui_close. The mouse and the keys share one
## marker (TitlePopup): the arrows walk QUIT and STAY, Enter or Space press the marked one, and
## it opens on STAY, so Esc then Enter never quits by accident. Desktop only: the web build
## offers no quit (its tab is closed instead).

## YES was pressed: the title closes the game.
signal quit_confirmed
## NO or Esc: the question closed.
signal kept

const SHEET_ART := AbandonConfirm.SHEET_ART
## With no run saved: the line's room (LINE_RECT's height and the gap under it) folds away.
const FOLDED_ART := Vector2i(220, 80)
const QUESTION := "QUIT GAME?"
const SAVED_LINE := "YOUR RUN STAYS SAVED"
const QUIT_TEXT := "QUIT"
const STAY_TEXT := "STAY"
const OPEN_SOUND := "ui_open"
const KEEP_SOUND := "ui_close"
## The places on the sheet, in canvas px from its top left: AbandonConfirm's.
const QUESTION_RECT := AbandonConfirm.QUESTION_RECT
const LINE_RECT := AbandonConfirm.LOST_RECT
const WORD_SCALE := AbandonConfirm.WORD_SCALE
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
	_yes = MenuPlate.new(QUIT_TEXT, MenuPlate.Kind.PRIMARY, AbandonConfirm.PRIMARY_SIZE)
	_yes.centre_caption(WORD_SCALE)
	page.add_child(_yes)
	_no = MenuPlate.new(STAY_TEXT, MenuPlate.Kind.PLATE, AbandonConfirm.PLATE_SIZE)
	_no.centre_caption()
	page.add_child(_no)
	_place_plates(true)
	for plate: MenuPlate in [_yes, _no] as Array[MenuPlate]:
		_add_entry(plate)
		plate.pressed.connect(_press.bind(plate))


## Asks, with ui_open, the marker on STAY; `saved`: a run is saved (the line says it stays; with
## none the line folds away). Steps in unless `still`; returns the step-in (null when still).
func open(saved: bool) -> Tween:
	_line.text = SAVED_LINE if saved else ""
	_line.visible = saved
	_place_plates(saved)
	var sheet_art: Vector2i = SHEET_ART if saved else FOLDED_ART
	_resize_sheet(sheet_art)
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


## The plates at AbandonConfirm's places, raised by the folded line's room without a save.
func _place_plates(saved: bool) -> void:
	var lift: float = 0.0 if saved else float((SHEET_ART.y - FOLDED_ART.y) * ArtStyle.ART_SCALE)
	_yes.position = AbandonConfirm.PRIMARY_AT - Vector2(0, lift)
	_no.position = AbandonConfirm.PLATE_AT - Vector2(0, lift)


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
