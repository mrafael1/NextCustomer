class_name AbandonConfirm
extends TitlePopup
## The New run question (#56, mock-up title_premium_directions.html, the abandon confirmation):
## with a run saved, NEW RUN asks before the run is given up. Over the dimmed storefront, a
## popup asks ABANDON THIS RUN? and says what is lost (the saved shift, in the number font);
## ABANDON (the tomato primary plate) gives the run up, KEEP (a shelf-label plate) or Esc keeps
## it. It opens with ui_open; ABANDON clicks, KEEP closes with ui_close. The mouse and the keys
## share one marker (TitlePopup): the arrows walk ABANDON and KEEP, Enter or Space press the
## marked one, so Enter alone never abandons a run. `still` (reduced motion) shows it at once.

## ABANDON was pressed: the title deletes the save and starts a new run.
signal abandon_confirmed
## KEEP or Esc: the question closed and the save stays.
signal kept

## The sheet: 220x96 art.
const SHEET_ART := Vector2i(220, 96)
const QUESTION := "ABANDON THIS RUN?"
const OPEN_SOUND := "ui_open"
const KEEP_SOUND := "ui_close"
## The places on the sheet, in canvas px from its top left (the mock-up's art px at 2x).
const QUESTION_RECT := Rect2(0, 14, 440, 32)
const LOST_RECT := Rect2(0, 52, 440, 24)
const ABANDON_AT := Vector2(36, 100)
const ABANDON_SIZE := Vector2(176, 56)
const KEEP_AT := Vector2(232, 104)
const KEEP_SIZE := Vector2(172, 50)
## Hard pixel words at 2x for the question and the keys, the number font for the lost line.
const WORD_SCALE := 2
const LOST_SIZE := 16

var _lost: Label
var _abandon: MenuPlate
var _keep: MenuPlate


func _init() -> void:
	super(SHEET_ART)
	var page: Control = sheet()
	var question: Label = UiKit.pixel_label(QUESTION, WORD_SCALE, Palette.INK)
	_put_centred(question, QUESTION_RECT)
	page.add_child(question)
	_lost = UiKit.number_label("", LOST_SIZE, false)
	_lost.add_theme_color_override("font_color", Palette.GREY)
	_put_centred(_lost, LOST_RECT)
	page.add_child(_lost)
	_abandon = MenuPlate.new("ABANDON", MenuPlate.Kind.PRIMARY, ABANDON_SIZE)
	_abandon.centre_caption(WORD_SCALE)
	_abandon.position = ABANDON_AT
	page.add_child(_abandon)
	_keep = MenuPlate.new("KEEP", MenuPlate.Kind.PLATE, KEEP_SIZE)
	_keep.centre_caption()
	_keep.position = KEEP_AT
	page.add_child(_keep)
	for plate: MenuPlate in [_abandon, _keep] as Array[MenuPlate]:
		_add_entry(plate)
		plate.pressed.connect(_press.bind(plate))


## Asks, with `line` saying what is lost (lost_line), with ui_open; steps in unless `still`.
## Returns the step-in (null when still).
func open(line: String) -> Tween:
	_lost.text = line
	Sfx.play_at(self, OPEN_SOUND)
	return _show_popup()


## The line saying what is lost, for a saved run: its shift out of the run's shifts.
static func lost_line(saved: RunSave) -> String:
	return "SHIFT %d/%d WILL BE LOST" % [saved.run.shift_index + 1, saved.run.shift_count()]


func abandon_plate() -> MenuPlate:
	return _abandon


func keep_plate() -> MenuPlate:
	return _keep


func lost_label() -> Label:
	return _lost


func _show_marked(entry: Control, on: bool) -> void:
	(entry as MenuPlate).marked = on


func _press(entry: Control) -> void:
	if not is_open():
		return
	if entry == _abandon:
		Sfx.play_at(self, UiKit.CLICK_SOUND)
		close()
		abandon_confirmed.emit()
	else:
		_cancel()


## KEEP or Esc: closes with ui_close; the save stays.
func _cancel() -> void:
	Sfx.play_at(self, KEEP_SOUND)
	close()
	kept.emit()


func _put_centred(label: Label, rect: Rect2) -> void:
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	if label.scale.x > 1.0:
		UiKit.place_pixel_label(label, rect, true)
	else:
		label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		label.position = rect.position
		label.size = rect.size
