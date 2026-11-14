class_name AbandonConfirm
extends TitlePopup
## The New run question (#56, mock-up title_premium_directions.html, the abandon confirmation):
## with a run saved, NEW RUN asks before the run is given up. Over the dimmed storefront, a
## popup asks ABANDON THIS RUN? and says what is lost (the saved shift, in the number font);
## ABANDON (the tomato primary plate) gives the run up, KEEP (a shelf-label plate) or Esc keeps
## it. It opens with ui_open; ABANDON clicks, KEEP closes with ui_close. The mouse and the keys
## share one marker (TitlePopup): the arrows walk ABANDON and KEEP, Enter or Space press the
## marked one; it opens on KEEP (the safe key, polish audit v1.36, as QUIT GAME? opens on
## STAY), so Enter alone never abandons a run. `still` (reduced motion) shows it at once.
## QuitConfirm shares its layout: the same plates at the same places (PRIMARY_*, PLATE_*), the
## gap between them room for the marker's tick.

## ABANDON was pressed: the title deletes the save and starts a new run.
signal abandon_confirmed
## KEEP or Esc: the question closed and the save stays.
signal kept

## The sheet: 220x96 art.
const SHEET_ART := Vector2i(220, 96)
const QUESTION := "ABANDON THIS RUN?"
const OPEN_SOUND := "ui_open"
const KEEP_SOUND := "ui_close"
## The places on the sheet, in canvas px from its top left (the mock-up's art px at 2x): the
## primary (tomato) plate on the left, the safe plate on the right, both PLATE_WIDTH wide, their
## middles level, PLATE_GAP apart (the marker's tick, MenuPlate.TICK_LEFT, fits between them).
const QUESTION_RECT := Rect2(0, 14, 440, 32)
const LOST_RECT := Rect2(0, 52, 440, 24)
const PLATE_WIDTH := 160.0
const PLATE_GAP := 40.0
const PRIMARY_AT := Vector2(40, 100)
const PRIMARY_SIZE := Vector2(PLATE_WIDTH, 56)
const PLATE_AT := Vector2(PRIMARY_AT.x + PLATE_WIDTH + PLATE_GAP, 104)
const PLATE_SIZE := Vector2(PLATE_WIDTH, 50)
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
	_abandon = MenuPlate.new("ABANDON", MenuPlate.Kind.PRIMARY, PRIMARY_SIZE)
	_abandon.centre_caption(WORD_SCALE)
	_abandon.position = PRIMARY_AT
	page.add_child(_abandon)
	_keep = MenuPlate.new("KEEP", MenuPlate.Kind.PLATE, PLATE_SIZE)
	_keep.centre_caption()
	_keep.position = PLATE_AT
	page.add_child(_keep)
	for plate: MenuPlate in [_abandon, _keep] as Array[MenuPlate]:
		_add_entry(plate)
		plate.pressed.connect(_press.bind(plate))


## Asks, with `line` saying what is lost (lost_line), with ui_open, the marker on KEEP; steps in
## unless `still`. Returns the step-in (null when still).
func open(line: String) -> Tween:
	_lost.text = line
	Sfx.play_at(self, OPEN_SOUND)
	var opening: Tween = _show_popup()
	_set_marked(_entries.find(_keep))
	return opening


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
