class_name RewardsMenu
extends TitlePopup
## The REWARDS menu (#56, mock-up title_premium_directions.html, the shared REWARDS overlay): the
## title's one entry for what coins buy, over the dimmed storefront. Under the REWARDS heading,
## a coin LED shows the profile's coins (in gold, in the number font) and two cards stand side
## by side:
## - TOY MACHINES: one capsule of each aisle, a small toy machine (scenery/toy_machine_mini, the
##   sign-free machine with its capsules at half size, its own sprite) and under them, across the
##   card, how many machines and capsules there are and what they do. Pressing it asks the
##   title to open the toy machines screen (toy_machines_requested); the menu stays open under
##   it.
## - LOYALTY, locked until the loyalty program is built: its empty stamp spots, a padlock and a
##   SOON stamp. Pressing it only answers no: the denied sound, and the stamp jolts.
## BACK (a shelf-label plate) and Esc close the menu (ui_back); it opens with ui_open. The
## mouse and the keys share one marker (TitlePopup): Up, Down, Left and Right walk TOY MACHINES,
## LOYALTY and BACK, Enter or Space press the marked one.
##
## Every number is in the number font; Pixelify only prints words, as hard pixel words at 2x
## (the heading at 4x).
## `still` (reduced motion) shows the menu at once and holds the stamp's jolt.

## The TOY MACHINES card was pressed: the title opens the toy machines screen over the menu.
signal toy_machines_requested
## The locked LOYALTY card was pressed (it answered with the denied sound).
signal loyalty_denied

## The sheet: 340x232 art.
const SHEET_ART := Vector2i(340, 232)
const COIN := preload("res://art/icons/coin.png")
const LED_FRAME := preload("res://art/frames/coin_led.png")
const SPOT := preload("res://art/icons/stamp_spot.png")
const PADLOCK := preload("res://art/icons/padlock.png")
const SOON := preload("res://art/icons/soon_stamp.png")
const MACHINE := preload("res://art/scenery/toy_machine_mini.png")
const OPEN_SOUND := "ui_open"
const BACK_SOUND := "ui_back"
const DENIED_SOUND := "denied"
## The places on the sheet, in canvas px from its top left (the mock-up's art px at 2x).
const HEADING_AT := Vector2(24, 6)
const LED_RECT := Rect2(440, 20, 216, 36)
const TAGLINE_AT := Vector2(26, 64)
const MACHINES_AT := Vector2(24, 100)
const LOYALTY_AT := Vector2(348, 100)
const BACK_AT := Vector2(24, 404)
const BACK_SIZE := Vector2(128, 42)
const ESC_AT := Vector2(168, 404)
## On the LED: the coin, then the count and COINS, centred on its face.
const LED_COIN_AT := Vector2(12, 6)
const LED_GAP := 8.0
## On the TOY MACHINES card (the mock-up's places at 2x): the capsules top left (two rows of
## three, the second row half a step right), the small machine top right, the count line and
## UNLOCK NEW ITEMS under them across the card, and the OPEN hint, its right edge at
## OPEN_HINT_RIGHT.
const CAPSULE_AT := Vector2(20, 56)
const CAPSULE_STEP := Vector2(40, 28)
const MACHINE_AT := Vector2(176, 40)
const MACHINES_LINE_AT := Vector2(16, 176)
const UNLOCK_AT := Vector2(16, 200)
const OPEN_HINT_TOP := 236.0
const OPEN_HINT_RIGHT := 292.0
## On the LOYALTY card: two rows of five stamp spots, the padlock and the SOON stamp, the lines.
const SPOT_AT := Vector2(24, 52)
const SPOT_STEP := Vector2(52, 44)
const SPOT_COLUMNS := 5
const SPOTS := 10
const PADLOCK_AT := Vector2(24, 166)
const SOON_AT := Vector2(56, 160)
const LOYALTY_LINE_AT := Vector2(16, 208)
const LOYALTY_LINE := "STAMP CARD · COMING LATER"
## The SOON stamp's jolt on a press: JOLT px right and back, a step every JOLT_STEP.
const JOLT := 4.0
const JOLT_STEP := 0.05
## The words: hard pixel words at WORD_SCALE (the heading at HEADING_SCALE); the number font
## for the coins and the count line.
const HEADING_SCALE := 4
const WORD_SCALE := 2
const COUNT_SIZE := 24
const LINE_SIZE := 16

var _coin_label: Label
var _coins_word: Label
var _led: PanelContainer
var _machines_card: RewardCard
var _loyalty_card: RewardCard
var _back: MenuPlate
var _open_hint: Label
var _soon: TextureRect
var _jolt: Tween


## The menu for `balance`'s toy machines (one per aisle) and their capsules.
func _init(balance: BalanceDefinition) -> void:
	super(SHEET_ART)
	var page: Control = sheet()
	var heading: Label = UiKit.pixel_label("REWARDS", HEADING_SCALE, Palette.INK)
	heading.position = HEADING_AT
	page.add_child(heading)
	_add_led(page)
	var tagline: Label = UiKit.pixel_label("SPEND COINS AT THE STORE", WORD_SCALE, Palette.GREY)
	tagline.position = TAGLINE_AT
	page.add_child(tagline)
	_machines_card = RewardCard.new("TOY MACHINES")
	_machines_card.position = MACHINES_AT
	page.add_child(_machines_card)
	_fill_machines(balance)
	_loyalty_card = RewardCard.new("LOYALTY", true)
	_loyalty_card.position = LOYALTY_AT
	page.add_child(_loyalty_card)
	_fill_loyalty()
	_back = MenuPlate.new("BACK", MenuPlate.Kind.PLATE, BACK_SIZE)
	_back.position = BACK_AT
	page.add_child(_back)
	var esc: Label = UiKit.pixel_label("ESC", WORD_SCALE, Palette.GREY)
	UiKit.place_pixel_label(
		esc, Rect2(ESC_AT, Vector2(0, BACK_SIZE.y - MenuPlate.PLATE_FACE_BOTTOM)), true
	)
	page.add_child(esc)
	for entry: BaseButton in [_machines_card, _loyalty_card, _back] as Array[BaseButton]:
		_add_entry(entry)
		entry.pressed.connect(_press.bind(entry))
	set_coins(0)


## Opens the menu showing `coins` (stepping in unless `still`), with ui_open. Returns the
## step-in (null when still).
func open(coins: int) -> Tween:
	set_coins(coins)
	Sfx.play_at(self, OPEN_SOUND)
	return _show_popup()


## Shows `count` coins on the LED (after a draw at the toy machines, say); a negative count (an
## unreadable profile) shows "?".
func set_coins(count: int) -> void:
	_coin_label.text = str(count) if count >= 0 else "?"
	var count_width: float = _coin_label.get_minimum_size().x
	var words_width: float = UiKit.pixel_text_size(_coins_word).x
	var left: float = LED_COIN_AT.x + ArtStyle.ART_SCALE * 12.0 + LED_GAP
	_coin_label.position = Vector2(left, 0)
	_coin_label.size = Vector2(count_width, LED_RECT.size.y)
	# The word on the 2 px grid, whatever the count's width.
	var words_left: float = 2.0 * ceilf((left + count_width + LED_GAP) / 2.0)
	UiKit.place_pixel_label(_coins_word, Rect2(words_left, 0, words_width, LED_RECT.size.y), true)


func toy_machines_card() -> RewardCard:
	return _machines_card


func loyalty_card() -> RewardCard:
	return _loyalty_card


func back_plate() -> MenuPlate:
	return _back


func coin_label() -> Label:
	return _coin_label


func coin_led() -> PanelContainer:
	return _led


func soon_stamp() -> TextureRect:
	return _soon


func open_hint() -> Label:
	return _open_hint


func _show_marked(entry: Control, on: bool) -> void:
	if entry is RewardCard:
		(entry as RewardCard).marked = on
	elif entry is MenuPlate:
		(entry as MenuPlate).marked = on
	if entry == _machines_card:
		_open_hint.visible = on


func _press(entry: Control) -> void:
	if not is_open():
		return
	if entry == _machines_card:
		Sfx.play_at(self, UiKit.CLICK_SOUND)
		toy_machines_requested.emit()
	elif entry == _loyalty_card:
		Sfx.play_at(self, DENIED_SOUND)
		_jolt_stamp()
		loyalty_denied.emit()
	elif entry == _back:
		_cancel()


## BACK or Esc: closes with ui_back.
func _cancel() -> void:
	Sfx.play_at(self, BACK_SOUND)
	close()


## The coin LED: the coin, the count in gold and COINS in mustard dark on a slate dark face.
func _add_led(page: Control) -> void:
	_led = UiKit.frame_panel(LED_FRAME, 1)
	_led.position = LED_RECT.position
	_led.size = LED_RECT.size
	page.add_child(_led)
	var face: Control = Control.new()
	face.mouse_filter = Control.MOUSE_FILTER_IGNORE
	face.position = LED_RECT.position
	face.size = LED_RECT.size
	page.add_child(face)
	var coin: TextureRect = UiKit.sprite(COIN)
	coin.position = LED_COIN_AT
	coin.size = Vector2(COIN.get_size()) * ArtStyle.ART_SCALE
	face.add_child(coin)
	_coin_label = UiKit.number_label("0", COUNT_SIZE, false)
	_coin_label.add_theme_color_override("font_color", Palette.GOLD)
	_coin_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	face.add_child(_coin_label)
	_coins_word = UiKit.pixel_label("COINS", WORD_SCALE, Palette.MUSTARD_DARK)
	face.add_child(_coins_word)


## TOY MACHINES: a capsule of each aisle, the small machine, the lines and the OPEN hint.
func _fill_machines(balance: BalanceDefinition) -> void:
	var content: Control = _machines_card.content()
	var capsule_size: Vector2 = Vector2.ONE * ToyMachineView.CAPSULE_ART * ArtStyle.ART_SCALE
	var capsules: int = 0
	for i: int in balance.aisles.size():
		var aisle: AisleDefinition = balance.aisles[i]
		capsules += aisle.capsule_cards.size()
		var path: String = BareToyMachine.CAPSULE_PATH % aisle.id
		if i >= 6 or not ResourceLoader.exists(path):
			continue
		var capsule: TextureRect = UiKit.sprite(load(path) as Texture2D)
		var row: int = floori(i / 3.0)
		capsule.position = (
			CAPSULE_AT
			+ Vector2((i % 3) * CAPSULE_STEP.x + row * CAPSULE_STEP.x / 2.0, row * CAPSULE_STEP.y)
		)
		capsule.size = capsule_size
		content.add_child(capsule)
	var machine: TextureRect = UiKit.sprite(MACHINE)
	machine.position = MACHINE_AT
	machine.size = Vector2(MACHINE.get_size()) * ArtStyle.ART_SCALE
	content.add_child(machine)
	var counts: Label = UiKit.number_label(
		"%d MACHINES · %d CAPSULES" % [balance.aisles.size(), capsules], LINE_SIZE, false
	)
	counts.add_theme_color_override("font_color", Palette.INK_LIGHT)
	counts.position = MACHINES_LINE_AT
	content.add_child(counts)
	var unlock: Label = UiKit.pixel_label("UNLOCK NEW ITEMS", WORD_SCALE, Palette.GREY)
	unlock.position = UNLOCK_AT
	content.add_child(unlock)
	_open_hint = UiKit.pixel_label("OPEN", WORD_SCALE, Palette.TOMATO)
	var hint_width: float = UiKit.pixel_text_size(_open_hint).x
	_open_hint.position = Vector2(OPEN_HINT_RIGHT - hint_width, OPEN_HINT_TOP)
	_open_hint.visible = false
	content.add_child(_open_hint)


## LOYALTY, locked: the empty stamp spots, the padlock and the SOON stamp, and the lines.
func _fill_loyalty() -> void:
	var content: Control = _loyalty_card.content()
	var spot_size: Vector2 = Vector2(SPOT.get_size()) * ArtStyle.ART_SCALE
	for i: int in SPOTS:
		var spot: TextureRect = UiKit.sprite(SPOT)
		var cell: Vector2 = Vector2(i % SPOT_COLUMNS, floori(float(i) / SPOT_COLUMNS))
		spot.position = SPOT_AT + cell * SPOT_STEP
		spot.size = spot_size
		content.add_child(spot)
	var padlock: TextureRect = UiKit.sprite(PADLOCK)
	padlock.position = PADLOCK_AT
	padlock.size = Vector2(PADLOCK.get_size()) * ArtStyle.ART_SCALE
	content.add_child(padlock)
	_soon = UiKit.sprite(SOON)
	_soon.position = SOON_AT
	_soon.size = Vector2(SOON.get_size()) * ArtStyle.ART_SCALE
	content.add_child(_soon)
	var line: Label = UiKit.pixel_label(LOYALTY_LINE, WORD_SCALE, Palette.INK_LIGHT)
	line.position = LOYALTY_LINE_AT
	content.add_child(line)


## The SOON stamp jolts JOLT px right and back in two steps (held still under reduced motion).
func _jolt_stamp() -> void:
	if still:
		return
	if _jolt != null:
		_jolt.kill()
	_soon.position = SOON_AT + Vector2(JOLT, 0)
	_jolt = create_tween()
	_jolt.tween_interval(JOLT_STEP)
	_jolt.tween_callback(func() -> void: _soon.position = SOON_AT - Vector2(JOLT, 0))
	_jolt.tween_interval(JOLT_STEP)
	_jolt.tween_callback(func() -> void: _soon.position = SOON_AT)
