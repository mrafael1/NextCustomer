class_name BadgeScreen
extends TitlePopup
## BADGE PINS (#122, full build plan 7.4; decided with the user on 2026-10-31): the badge pins
## popup over REWARDS. The cashier's name badge (NameBadge) shows the pins worn in the balance's
## pin_slots, with the worn pin's rule under it; beside it one row per pin of the catalogue
## (PinRow): WORN, WEAR or LOCKED with its milestone. Pressing an owned pin wears it (with every
## slot taken it takes the first slot's place) and pressing a worn one takes it off, saved at
## once; a locked one answers no. UNLOCK A RANDOM PIN (the way past a milestone out of reach)
## spends the balance's pin_coin_price coins on one locked pin drawn on its own derived stream
## of the profile's capsule seed (ProfileState.PIN_STREAM), made here the first time, as the
## toy machines do. A save that fails rolls the change back. Worn pins ride from the next run
## started: a run copies them at its start (RunPins) and never reads the profile again.
## BACK and Esc close it. The mouse and the keys share one marker (TitlePopup).

## The profile changed and was saved (a pin worn, taken off or bought): the title follows its
## coins.
signal profile_changed

const SHEET_ART := Vector2i(340, 232)
const COIN := preload("res://art/icons/coin.png")
const HEADING_AT := Vector2(24, 6)
const COINS_RECT := Rect2(456, 16, 200, 36)
const TAGLINE_AT := Vector2(26, 64)
const TAGLINE := "WORN PINS SHAPE YOUR NEXT RUN"
const BADGE_AT := Vector2(24, 96)
const WORN_RECT := Rect2(24, 260, 248, 80)
const WORN_SIZE := 14
const ROWS_AT := Vector2(296, 96)
const ROW_STEP := 80.0
const BUY_AT := Vector2(296, 352)
const BUY_SIZE := Vector2(360, 42)
const BUY_WORDS := "UNLOCK A RANDOM PIN"
const BACK_AT := Vector2(24, 404)
const BACK_SIZE := Vector2(128, 42)
const ESC_AT := Vector2(168, 404)
const NOTE_RECT := Rect2(296, 404, 360, 42)
const NOTE_SIZE := 13
const OPEN_SOUND := "ui_open"
const BACK_SOUND := "ui_back"
const DENIED_SOUND := "denied"
const WEAR_SOUND := "stamp_loyalty"
const OFF_SOUND := "card_return_1"
const BUY_SOUND := "coin_2"

var _profile: ProfileState
var _catalogue: CatalogueDefinition
var _balance: BalanceDefinition
var _saves: SaveService
var _log: EventLogService
var _can_save: bool = true
var _badge: NameBadge
var _worn_label: Label
var _coin_label: Label
var _rows: Array[PinRow] = []
var _buy: MenuPlate
var _back: MenuPlate
var _note: Label


## The screen for `catalogue`'s pins (the rows, in data order) and `balance`'s slots and price.
func _init(catalogue: CatalogueDefinition, balance: BalanceDefinition) -> void:
	super(SHEET_ART)
	name = "BadgeScreen"
	_catalogue = catalogue
	_balance = balance
	var page: Control = sheet()
	var heading: Label = UiKit.pixel_label("BADGE PINS", 4, Palette.INK)
	heading.position = HEADING_AT
	page.add_child(heading)
	_coin_label = UiKit.number_label("", 24, false)
	_coin_label.add_theme_color_override("font_color", Palette.MUSTARD_DARK)
	_coin_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_coin_label.position = COINS_RECT.position
	_coin_label.size = COINS_RECT.size
	page.add_child(_coin_label)
	var tagline: Label = UiKit.pixel_label(TAGLINE, 2, Palette.GREY)
	tagline.position = TAGLINE_AT
	page.add_child(tagline)
	_badge = NameBadge.new()
	_badge.position = BADGE_AT
	page.add_child(_badge)
	_worn_label = UiKit.body_label("", WORN_SIZE, Palette.INK_LIGHT)
	_worn_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_worn_label.position = WORN_RECT.position
	_worn_label.size = WORN_RECT.size
	page.add_child(_worn_label)
	for index: int in catalogue.pins.size():
		var row: PinRow = PinRow.new(catalogue.pins[index], index)
		row.position = ROWS_AT + Vector2(0, index * ROW_STEP)
		page.add_child(row)
		_rows.append(row)
	_buy = MenuPlate.new(BUY_WORDS, MenuPlate.Kind.PLATE, BUY_SIZE)
	_buy.name = "BuyPin"
	_buy.position = BUY_AT
	page.add_child(_buy)
	_back = MenuPlate.new("BACK", MenuPlate.Kind.PLATE, BACK_SIZE)
	_back.position = BACK_AT
	page.add_child(_back)
	var esc: Label = UiKit.pixel_label("ESC", 2, Palette.GREY)
	UiKit.place_pixel_label(
		esc, Rect2(ESC_AT, Vector2(0, BACK_SIZE.y - MenuPlate.PLATE_FACE_BOTTOM)), true
	)
	page.add_child(esc)
	_note = UiKit.body_label("", NOTE_SIZE, Palette.GREY_DARK)
	_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_note.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_note.position = NOTE_RECT.position
	_note.size = NOTE_RECT.size
	page.add_child(_note)
	var entries: Array[BaseButton] = []
	entries.assign(_rows)
	entries.append_array([_buy, _back] as Array[BaseButton])
	for entry: BaseButton in entries:
		_add_entry(entry)
		entry.pressed.connect(_press.bind(entry))


## Opens on `shown_profile` (changed and saved through `saves`; `can_save` false: shown, every
## change refused), stepping in unless `still`, with ui_open.
func open(
	shown_profile: ProfileState, saves: SaveService, event_log: EventLogService, can_save: bool
) -> Tween:
	_profile = shown_profile
	_saves = saves
	_log = event_log
	_can_save = can_save
	_note.text = ""
	_refresh()
	Sfx.play_at(self, OPEN_SOUND)
	return _show_popup()


func profile() -> ProfileState:
	return _profile


func badge() -> NameBadge:
	return _badge


func rows() -> Array[PinRow]:
	return _rows


func buy_plate() -> MenuPlate:
	return _buy


func back_plate() -> MenuPlate:
	return _back


func note() -> Label:
	return _note


func worn_label() -> Label:
	return _worn_label


## Wears `pin`, or takes it off when worn; a locked pin (or a profile that can't be saved)
## answers no. True when the profile changed and was saved.
func toggle(pin: PinDefinition) -> bool:
	if not _can_save or not _profile.has_pin(pin):
		Sfx.play_at(self, DENIED_SOUND)
		return false
	var before: Array[StringName] = _profile.worn_pins.duplicate()
	var worn: bool = before.has(pin.id)
	if worn:
		ProfilePins.take_off(_profile, pin)
	else:
		ProfilePins.wear(_profile, pin, _balance.pin_slots)
	if not _saves.save_profile(_profile):
		_profile.worn_pins = before
		_can_save = false
		Sfx.play_at(self, DENIED_SOUND)
		_refresh()
		return false
	Sfx.play_at(self, OFF_SOUND if worn else WEAR_SOUND)
	_note.text = "" if worn else "Worn from your next run."
	_refresh()
	profile_changed.emit()
	return true


## Buys a random locked pin: the pin, or null when it can't be bought (or the save failed,
## rolled back).
func buy() -> PinDefinition:
	var price: int = _balance.pin_coin_price
	if not _can_save or not ProfilePins.can_buy(_profile, _catalogue, price):
		Sfx.play_at(self, DENIED_SOUND)
		return null
	var had_seed: bool = _profile.has_capsule_seed
	if not had_seed:
		_profile.set_capsule_seed(_log.new_run_seed())
	var rng: RandomNumberGenerator = EventLogService.derived_stream(
		_profile.capsule_seed, ProfileState.PIN_STREAM % _profile.pins_bought
	)
	var pin: PinDefinition = ProfilePins.buy_random(_profile, _catalogue, price, rng)
	if not _saves.save_profile(_profile):
		_profile.coins += price
		_profile.unlocked_pins.erase(pin.id)
		_profile.pins_bought -= 1
		_profile.has_capsule_seed = had_seed
		_can_save = false
		Sfx.play_at(self, DENIED_SOUND)
		_refresh()
		return null
	Sfx.play_at(self, BUY_SOUND)
	_note.text = "Unlocked: %s. Press it to wear it." % pin.display_name
	_refresh()
	profile_changed.emit()
	return pin


func _refresh() -> void:
	_coin_label.text = "%d COINS" % _profile.coins
	var worn: Array[PinDefinition] = ProfilePins.worn(_profile, _catalogue)
	var indexes: Array[int] = []
	for pin: PinDefinition in worn:
		indexes.append(_catalogue.pins.find(pin))
	_badge.show_pins(worn, _balance.pin_slots, indexes)
	_worn_label.text = (
		"No pin worn. Press a pin to wear it."
		if worn.is_empty()
		else "%s: %s" % [worn[0].display_name, worn[0].rule_text]
	)
	for index: int in _rows.size():
		var pin: PinDefinition = _rows[index].pin
		var state: PinRow.State = PinRow.State.LOCKED
		if _profile.worn_pins.has(pin.id) and _profile.has_pin(pin):
			state = PinRow.State.WORN
		elif _profile.has_pin(pin):
			state = PinRow.State.OWNED
		_rows[index].show_state(state, index)
	var price: int = _balance.pin_coin_price
	_buy.show_coins(price)
	_buy.disabled = not ProfilePins.can_buy(_profile, _catalogue, price)
	if not _can_save:
		_note.text = "Your profile can't be saved: pins can't change."
	elif _note.text.is_empty() and ProfilePins.locked(_profile, _catalogue).is_empty():
		_note.text = "Every pin unlocked."


func _show_marked(entry: Control, on: bool) -> void:
	if entry is PinRow:
		(entry as PinRow).marked = on
	elif entry is MenuPlate:
		(entry as MenuPlate).marked = on


func _press(entry: Control) -> void:
	if not is_open():
		return
	if entry is PinRow:
		toggle((entry as PinRow).pin)
	elif entry == _buy:
		buy()
	elif entry == _back:
		_cancel()


## BACK or Esc: closes with ui_back.
func _cancel() -> void:
	Sfx.play_at(self, BACK_SOUND)
	close()
