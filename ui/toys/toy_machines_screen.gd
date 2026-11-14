class_name ToyMachinesScreen
extends Control
## The TOY MACHINES (#121, mock-up toy_machines_121_v2.html, the title's direction C+, decided
## with the user; full build plan 7.1): a camera cut to the store's exit after closing, where
## one toy machine per aisle (balance.aisles order; ToyMachineView, each aisle its own cabinet on
## the shared coin base) stands under its own recessed lamp by the glass doors. Pick a machine
## to spend a capsule's price on a capsule: CapsuleCounter draws, saves and logs it, the coin
## clinks, the counts drop and the reveal (ToyReveal) shows the item's icon alone for
## ToyReveal.HOLD_S. FIGURINE BOOK opens the FIGURINE BOOK (FigurineBook, v1.30 round 2: the
## card book that replaced the shelf; its BACK returns here); DONE (or
## Escape with no machine picked) closes the screen. Coins can be kept: nothing asks to spend
## them.
##
## A full-screen overlay that blocks clicks behind it, holding a 1280x720 stage centred in the
## window (never scaled; the bands outside it are the night's teal black): one 640x360 art scene
## at 2x (ToyExitArt), every word hard pixel lettering (PixelLine) on its grid, laid out at the
## mock-up's coordinates (art px). Reached from the results (ShiftScreen) and the title
## (TitleScreen), which build the CapsuleCounter: it knows the profile, the stock line and
## whether saves work.
##
## The COINS and FIGURINES readouts (steel LED housings, ToyLed) hang at the top left, the TOY
## MACHINES board between two chains.
## Only a playable machine's lamp is on; the hovered one's burns hotter. Hovering a machine, or
## picking it with the Left and Right keys (Escape lets go), puts its lineup (ToyLineup) in the
## board's place (but an OUT OF ORDER one's). The hint and the
## notices are on one LED strip over the floor. States, never by colour alone: COINS ? and
## every machine OUT OF ORDER with a notice when the profile can't be saved; every machine
## SOLD OUT and COLLECTION COMPLETE on the strip once the collection is complete; the lids
## shut, padlocks on the price LEDs, a tomato 0 and a notice with 0 coins; otherwise the hint.
## FIGURINE BOOK is DONE's button in teal (v0.78: store fixtures, no plain boxes); a NEW tag
## (ToyNewTag, v1.30) hangs on it while a drawn figurine hasn't been seen in the book yet.
## Through the doors the street idles (ToyStreet, v0.79): a car's headlights now and then, the
## lamp's flicker.
##
## Once the reveal's hold is over the icon flies into the drawn machine's lineup card by itself
## (ToyLineupJoin, v1.05, mock-up toy_shelf_unlock.html option B; no OK since 2026-11-11), and a
## capsule that completes its aisle ends on the
## COMPLETED! card and the machine's SOLD OUT. Until the join's beats the screen holds what the
## draw changed (the FIGURINES count, the machine's plate, window and SOLD OUT state, and
## COLLECTION COMPLETE): only COINS changes at the draw.

signal closed

## What the LED strip shows: the hint, the 0 coins or OUT OF ORDER notice, COLLECTION COMPLETE.
enum Strip { HINT, BROKE, OFF, COMPLETE }

const STAGE := Vector2(1280, 720)
const COIN := preload("res://art/icons/coin.png")
const COIN_DIM := preload("res://art/icons/coin_dim.png")
const WARNING := preload("res://art/icons/warning.png")
## The player-facing words (DECIDE_63's wording: TOY MACHINES, capsule, figurine), in one place,
## in capitals: hard pixel lettering has no lower case look of its own (the title's).
const TITLE_TEXT := "TOY MACHINES"
const EXIT_TEXT := "EXIT"
const COINS_TEXT := "COINS"
const FIGURINES_TEXT := "FIGURINES"
const COUNT_TEXT := "%d/%d"
const UNKNOWN_COINS := "?"
const HINT_TEXT := "PICK A MACHINE: %s A CAPSULE."
const FULL_BANNER := "COLLECTION COMPLETE"
const FULL_HINT := (
	"EVERY FIGURINE IS IN YOUR BOOK. " + "YOUR COINS KEEP ADDING UP ON THE FINAL RECEIPT."
)
const BROKE_NOTICE := "NO COINS LEFT. GET PAST SHIFT 4 IN A RUN TO EARN COINS."
## A profile that never had a coin (no capsule drawn, no pin bought; polish audit v1.36).
const BROKE_FRESH_NOTICE := "NO COINS YET. GET PAST SHIFT 4 IN A RUN TO EARN COINS."
const OFF_NOTICE := (
	"YOUR COLLECTION CAN'T BE SAVED RIGHT NOW, " + "SO THE TOY MACHINES ARE SWITCHED OFF."
)
const SHELF_TEXT := "FIGURINE BOOK"
const DONE_TEXT := "DONE"
const DONE_SOUND := "ui_back"
## The machines' row, in canvas px (twice the art px): six from MACHINE_X0, fewer centred in
## 0..ROW_WIDTH; MACHINE_PITCH apart. The row holds FULL_ROW machines at most: a seventh would
## stand on the doors (a layout test keeps the balance's aisles within it).
const MACHINE_X0 := 40.0
const MACHINE_PITCH := 160.0
const MACHINE_TOP := 250.0
const ROW_WIDTH := 1000.0
const FULL_ROW := 6
## The rest of the layout, in stage art px (one art px is ArtStyle.ART_SCALE canvas px).
## A machine's lamp is over its centre (MACHINE_CENTRE art px in).
const MACHINE_CENTRE := 36
## The LEDs at the top left: CHIP_AT, CHIP_GAP apart, CHIP_HEIGHT tall; their rows' cap top, the
## icon's top over it, their paddings and the gap between a row's tokens.
const CHIP_AT := Vector2i(10, 6)
const CHIP_GAP := 6
const CHIP_HEIGHT := 20
const CHIP_CAP_TOP := 7
const CHIP_ICON_TOP := -3
const CHIP_PADDING := Vector2i(8, 8)
const CHIP_TOKEN_GAP := 4
## The board's words: 2x pixel words centred on BOARD_TEXT_X, their cap top BOARD_TEXT_TOP.
const BOARD_TEXT_X := 255
const BOARD_TEXT_TOP := 77
## The EXIT lightbox's word, centred on EXIT_TEXT_X.
const EXIT_TEXT_X := 576
const EXIT_TEXT_TOP := 14
## The LED strip, centred on STRIP_CENTRE: the hint or a notice (STRIP_TOP, STRIP_HEIGHT), or
## COLLECTION COMPLETE at 2x over its line (COMPLETE_TOP, COMPLETE_HEIGHT).
const STRIP_CENTRE := 320
const STRIP_TOP := 294
const STRIP_HEIGHT := 21
const STRIP_CAP_TOP := 7
const COMPLETE_TOP := 289
const COMPLETE_HEIGHT := 38
const COMPLETE_CAP_TOPS: Array[int] = [6, 25]
const STRIP_PADDING := Vector2i(12, 12)
## FIGURINE BOOK (the 120x28 primary plate in teal) and DONE (the 80x28 primary plate), in
## canvas px.
const SHELF_BUTTON_RECT := Rect2(40, 656, 240, 56)
const SHELF_FRAMES: Array[Texture2D] = [
	preload("res://art/frames/button_teal.png"),
	preload("res://art/frames/button_teal_lit.png"),
]
const DONE_BUTTON_RECT := Rect2(1080, 656, 160, 56)
## Their hover tick's left edge, canvas px left of the plate at rest (the mock-up's: 7 art px).
const BUTTON_TICK_LEFT := 14.0
## DONE's caption: its left edge with its chevron (CHEVRON_GAP font px after the word,
## CHEVRON_ROWS rows of a 2 px stroke, CHEVRON_WIDTH wide) centred on the plate, its cap top
## DONE_TEXT_TOP art px under the plate's top.
const DONE_TEXT_TOP := 7
const CHEVRON_GAP := 2
const CHEVRON_ROWS := 4
const CHEVRON_WIDTH := 5
## DONE's word is centred on the plate as if DONE_SLACK art px followed it (the mock-up's).
const DONE_SLACK := 10
## A spent coin hops the COINS LED POP_RISE art px up for POP_SECONDS (whole pixels, no scale;
## none under reduced motion).
const POP_RISE := 2
const POP_SECONDS := 0.25

var _counter: CapsuleCounter
var _balance: BalanceDefinition
var _stage: Control
var _machines_layer: Control
var _machines: Array[ToyMachineView] = []
var _lamps: Array[TextureRect] = []
var _board: TextureRect
var _street: ToyStreet
var _board_title: PixelLine
var _coins_chip: ToyLed
var _coins_line: PixelLine
var _figurines_chip: ToyLed
var _figurines_line: PixelLine
var _strip: ToyLed
var _strip_kind: Strip = Strip.HINT
var _lineup: ToyLineup
var _shelf_button: MenuPlate
var _new_tag: ToyNewTag
var _done_button: MenuPlate
var _reveal: ToyReveal
var _book: FigurineBook
## The machine whose lineup shows: the one under the pointer or picked with the arrow keys.
var _hovered: ToyMachineView
var _shown_coins: int = -1
var _coins_hop: Tween
var _join: ToyLineupJoin
## What the screen holds back from the draw until the join's beats: "aisle" (the drawn one),
## "left" (its items shown left), "owned" (the FIGURINES count shown) and "new" (whether the
## book button's NEW tag showed), until the tick and the SOLD OUT; "strip" (no COLLECTION COMPLETE
## yet), until the collection beat.
var _hold: Dictionary = {}
## The draw's join, between the draw and the end of the reveal's hold.
var _pending: Dictionary = {}


func _init() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false
	var bands: ColorRect = ColorRect.new()
	bands.color = Palette.TEAL_BLACK
	bands.set_anchors_preset(Control.PRESET_FULL_RECT)
	bands.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bands)
	_stage = Control.new()
	_stage.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_stage.clip_contents = true
	_stage.set_anchors_preset(Control.PRESET_CENTER)
	_stage.offset_left = -STAGE.x / 2.0
	_stage.offset_top = -STAGE.y / 2.0
	_stage.offset_right = STAGE.x / 2.0
	_stage.offset_bottom = STAGE.y / 2.0
	add_child(_stage)
	_machines_layer = Control.new()
	_machines_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_machines_layer.size = STAGE
	_stage.add_child(_machines_layer)
	var backdrop: TextureRect = UiKit.sprite(ToyExitArt.backdrop())
	backdrop.size = STAGE
	_machines_layer.add_child(backdrop)
	_street = ToyStreet.new()
	_machines_layer.add_child(_street)
	_build_header()
	_build_footer()
	_lineup = ToyLineup.new()
	_machines_layer.add_child(_lineup)
	_machines_layer.move_child(_lineup, _board.get_index() + 1)  # Its chains pass behind the LEDs.
	_reveal = ToyReveal.new()
	_reveal.held.connect(_on_reveal_held)
	_stage.add_child(_reveal)
	_book = FigurineBook.new()
	_book.back_pressed.connect(_close_shelf)
	_stage.add_child(_book)
	_join = ToyLineupJoin.new()
	_join.setup(_lineup, _reveal, _figurines_chip, _machines_layer, _board, _strip)
	_join.beat.connect(_on_join_beat)
	_join.finished.connect(_on_join_finished)
	_stage.add_child(_join)


## Opens the machines for the `capsules` counter's profile, one per aisle of `balance`.
func open(capsules: CapsuleCounter, balance: BalanceDefinition) -> void:
	if _counter != null and _counter.switched_off.is_connected(_refresh):
		_counter.switched_off.disconnect(_refresh)
	_counter = capsules
	_counter.switched_off.connect(_refresh)
	_balance = balance
	_hovered = null
	_join.finish()
	_hold = {}
	_pending = {}
	_build_machines()
	_reveal.visible = false
	_book.visible = false
	_machines_layer.visible = true
	_shown_coins = -1
	_street.still = _reduced_motion()
	_street.restart()
	visible = true
	_refresh()


## Hides the screen and reports it (DONE).
func close() -> void:
	if not visible:
		return
	_join.finish()
	_reveal.visible = false
	_book.visible = false
	visible = false
	closed.emit()


func counter() -> CapsuleCounter:
	return _counter


## The pieces, for tests and the screen capture.
func stage() -> Control:
	return _stage


func machines() -> Array[ToyMachineView]:
	return _machines


func lamps() -> Array[TextureRect]:
	return _lamps


func coins_chip() -> ToyLed:
	return _coins_chip


func figurines_chip() -> ToyLed:
	return _figurines_chip


## The COINS LED's number ("5", "0" or "?").
func coins_text() -> String:
	return _coins_line.text().get_slice(" ", 0)


## The FIGURINES LED's count ("9/30").
func figurines_text() -> String:
	return _figurines_line.text().get_slice(" ", 0)


func street() -> ToyStreet:
	return _street


func board() -> TextureRect:
	return _board


func strip() -> ToyLed:
	return _strip


func strip_kind() -> Strip:
	return _strip_kind


func lineup() -> ToyLineup:
	return _lineup


func book() -> FigurineBook:
	return _book


func reveal() -> ToyReveal:
	return _reveal


## The figurine's join to its lineup card after the reveal (and the COMPLETED! card).
func lineup_join() -> ToyLineupJoin:
	return _join


func shelf_button() -> MenuPlate:
	return _shelf_button


func done_button() -> MenuPlate:
	return _done_button


## Every player-facing string the screen can show (the no-"gacha" check).
static func copy() -> PackedStringArray:
	var words: PackedStringArray = PackedStringArray(
		[
			TITLE_TEXT,
			EXIT_TEXT,
			COINS_TEXT,
			FIGURINES_TEXT,
			HINT_TEXT,
			FULL_BANNER,
			FULL_HINT,
			BROKE_NOTICE,
			BROKE_FRESH_NOTICE,
			OFF_NOTICE,
			SHELF_TEXT,
			DONE_TEXT,
			ToyMachineView.LEFT_TEXT,
			ToyMachineView.SOLD_OUT_TEXT,
			ToyExitArt.SOLD_OUT_WORDS,
			ToyMachineView.PRICE_TEXT,
			ToyMachineView.PRICE_TEXT_PLURAL,
			ToyLineup.TITLE_TEXT,
			ToyExitArt.TAPE_WORDS[0],
			ToyExitArt.TAPE_WORDS[1],
			ToyNewTag.TEXT,
			ToyLineup.COLLECTED_TEXT,
			FigurineBook.TITLE_TEXT,
			FigurineBook.CARDS_TEXT,
			FigurineBook.NEW_TEXT,
			FigurineBook.NEWEST_HEADER,
			FigurineBook.FOOD_TEXT,
			FigurineBook.NON_FOOD_TEXT,
			FigurineBook.SORT_PREFIX,
			FigurineBook.ALL_TEXT,
			FigurineBook.OTHER_ITEMS_TEXT,
			FigurineBook.EMPTY_TEXT,
			FigurineBook.PAGE_TEXT,
			FigurineBook.BACK_TEXT,
			BookCard.PLAIN_TEXT,
			BookCard.COUPONS_NAME,
			BookCard.OTHER_FOOD_NAME,
			BookCard.PERKS_NAME,
		]
	)
	words.append_array(ToyCompletedCard.copy())
	words.append_array(FigurineBook.SORT_CAPTIONS)
	return words


## The left edge of the machine row for `count` machines (canvas px): MACHINE_X0 for a full row
## (FULL_ROW at most), else the row centred in 0..ROW_WIDTH, on the art grid.
static func row_x0(count: int) -> float:
	if count >= FULL_ROW:
		return MACHINE_X0
	var width: float = count * MACHINE_PITCH - (MACHINE_PITCH - ToyMachineView.SIZE.x)
	return 2.0 * roundf((ROW_WIDTH - width) / 4.0)


func _unhandled_key_input(event: InputEvent) -> void:
	# The screen's own keys: nothing starts behind it (the title's Enter and Space). Left and
	# Right pick a machine as the pointer would (its look and lineup), Escape lets it go, or
	# closes the screen as DONE does when none is picked.
	var key: InputEventKey = event as InputEventKey
	if not visible or key == null or not key.pressed:
		return
	get_viewport().set_input_as_handled()
	if _reveal.visible or _book.visible or _join.is_active() or _machines.is_empty():
		return
	match key.keycode:
		KEY_RIGHT, KEY_LEFT:
			var step: int = 1 if key.keycode == KEY_RIGHT else -1
			var count: int = _machines.size()
			var current: int = _machines.find(_hovered)
			var next: int = (0 if step > 0 else count - 1) if current < 0 else current + step
			_select(_machines[posmod(next, count)])
		KEY_ESCAPE:
			if _machines.find(_hovered) >= 0:
				_select(null)
			elif not key.echo:
				Sfx.play_at(self, DONE_SOUND)
				close()


## The LEDs, the hanging board and the EXIT lightbox's word.
func _build_header() -> void:
	var art: float = ArtStyle.ART_SCALE
	_board = UiKit.sprite(ToyExitArt.board())
	_board.position = Vector2(ToyExitArt.BOARD_LAYER.position) * art
	_board.size = Vector2(ToyExitArt.BOARD_LAYER.size) * art
	_machines_layer.add_child(_board)
	_board_title = PixelLine.new()
	_board_title.show_tokens([TITLE_TEXT], Palette.PAPER, Palette.PAPER, 2)
	_board_title.position = (
		Vector2(BOARD_TEXT_X * art - floorf(_board_title.width() / 2.0 / art) * art, 0)
		- _board.position
		+ Vector2(0, BOARD_TEXT_TOP * art)
	)
	_board.add_child(_board_title)
	var exit_word: PixelLine = PixelLine.new()
	# Unlit scenery (DONE is the way out): a dim green, so it doesn't compete with DONE (v1.36).
	exit_word.show_tokens([EXIT_TEXT], Palette.GREEN_DARK, Palette.GREEN_DARK)
	exit_word.position = Vector2(
		EXIT_TEXT_X * art - floorf(exit_word.width() / 2.0 / art) * art, EXIT_TEXT_TOP * art
	)
	_machines_layer.add_child(exit_word)
	_coins_chip = ToyLed.new()
	_machines_layer.add_child(_coins_chip)
	_figurines_chip = ToyLed.new()
	_machines_layer.add_child(_figurines_chip)


func _build_footer() -> void:
	_strip = ToyLed.new()
	_machines_layer.add_child(_strip)
	_shelf_button = MenuPlate.new(SHELF_TEXT, MenuPlate.Kind.PRIMARY, SHELF_BUTTON_RECT.size)
	_shelf_button.use_frames(SHELF_FRAMES)
	_shelf_button.centre_caption(MenuPlate.PLATE_TEXT_SCALE)
	_shelf_button.position = SHELF_BUTTON_RECT.position
	_shelf_button.pressed.connect(func() -> void: Sfx.play_at(self, UiKit.CLICK_SOUND))
	_shelf_button.pressed.connect(_open_shelf)
	_new_tag = ToyNewTag.new()
	_new_tag.position = ToyNewTag.ON_BUTTON
	_shelf_button.add_child(_new_tag)
	_done_button = MenuPlate.new(DONE_TEXT, MenuPlate.Kind.PRIMARY, DONE_BUTTON_RECT.size)
	_done_button.centre_caption()
	_done_button.position = DONE_BUTTON_RECT.position
	_done_button.pressed.connect(func() -> void: Sfx.play_at(self, DONE_SOUND))
	_done_button.pressed.connect(close)
	for plate: MenuPlate in [_shelf_button, _done_button] as Array[MenuPlate]:
		plate.tick().position.x = -BUTTON_TICK_LEFT
		plate.mouse_entered.connect(func() -> void: plate.marked = true)
		plate.mouse_exited.connect(func() -> void: plate.marked = false)
		_machines_layer.add_child(plate)
	_place_captions()


## DONE's chevron: drawn on its caption (so it moves with it), the pair centred on the plate.
func _place_captions() -> void:
	var art: float = ArtStyle.ART_SCALE
	var font: Font = ArtStyle.pixel_display_font()
	var cap_top: float = font.get_ascent(ArtStyle.PIXEL_TEXT_SIZE) - ArtStyle.PIXEL_CAP_HEIGHT
	var caption: Label = _done_button.caption_label()
	var word: float = PixelLine.word_width(DONE_TEXT) / art
	var pair: float = word * 2.0 + DONE_SLACK
	caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	caption.position = Vector2(
		(
			floorf((DONE_BUTTON_RECT.size.x / art - pair) / 2.0) * art
			- PixelLine.LEFT_BEARING * caption.scale.x
		),
		DONE_TEXT_TOP * art - cap_top * caption.scale.y
	)
	var chevron: Control = Control.new()
	chevron.mouse_filter = Control.MOUSE_FILTER_IGNORE
	chevron.size = Vector2(CHEVRON_WIDTH, ArtStyle.PIXEL_CAP_HEIGHT)
	chevron.position = Vector2(PixelLine.LEFT_BEARING + word + CHEVRON_GAP, cap_top)
	chevron.draw.connect(
		func() -> void:
			for row: int in CHEVRON_ROWS:
				var foot: int = ArtStyle.PIXEL_CAP_HEIGHT - 1 - row
				chevron.draw_rect(Rect2(row, row, 2, 1), Palette.PAPER)
				chevron.draw_rect(Rect2(row, foot, 2, 1), Palette.PAPER)
	)
	caption.add_child(chevron)


## One machine and one lamp per aisle, laid out for their count.
func _build_machines() -> void:
	for machine: ToyMachineView in _machines:
		_machines_layer.remove_child(machine)
		machine.queue_free()
	for lamp: TextureRect in _lamps:
		_machines_layer.remove_child(lamp)
		lamp.queue_free()
	_machines = []
	_lamps = []
	var art: float = ArtStyle.ART_SCALE
	var x0: float = row_x0(_balance.aisles.size())
	for index: int in range(_balance.aisles.size()):
		var x: float = x0 + index * MACHINE_PITCH
		var lamp: TextureRect = UiKit.sprite(ToyExitArt.lamp("off"))
		var lamp_left: float = x + (MACHINE_CENTRE - ToyExitArt.LAMP_WIDTH / 2.0) * art
		lamp.position = Vector2(lamp_left, ToyExitArt.LAMP_TOP * art)
		lamp.size = Vector2(ToyExitArt.lamp("off").get_size()) * art
		_machines_layer.add_child(lamp)
		_machines_layer.move_child(lamp, 1)
		_lamps.append(lamp)
		var machine: ToyMachineView = ToyMachineView.new()
		machine.position = Vector2(x, MACHINE_TOP)
		machine.picked.connect(_on_machine_picked)
		machine.hover_changed.connect(_on_machine_hover)
		_machines_layer.add_child(machine)
		_machines_layer.move_child(machine, _board.get_index())
		_machines.append(machine)


## Shows the counter's coins, the collection's counts and every machine's state, the lamps, the
## lineup and the one line on the strip that fits (OFF's notice, the full collection's banner,
## the 0 coins notice, or the hint).
func _refresh() -> void:
	if _counter == null:
		return
	var profile: ProfileState = _counter.profile
	var can_save: bool = _counter.can_save()
	var coins: int = profile.coins
	var spent: bool = can_save and _shown_coins >= 0 and coins < _shown_coins
	_shown_coins = coins if can_save else -1
	var owned: int = int(_hold.get("owned", profile.owned_capsules(_balance)))
	var all_empty: bool = not _hold.has("strip")
	var broke: bool = false
	for aisle: AisleDefinition in _balance.aisles:
		all_empty = all_empty and _counter.items_left(aisle) == 0
		broke = broke or _counter.machine_state(aisle) == CapsuleCounter.State.BROKE
	for index: int in range(_machines.size()):
		var aisle: AisleDefinition = _balance.aisles[index]
		var left: int = _counter.items_left(aisle)
		var state: CapsuleCounter.State = _counter.machine_state(aisle)
		if _hold.get("aisle") == aisle and _hold.has("left"):
			left = int(_hold["left"])
			if state == CapsuleCounter.State.EMPTY:
				var short: bool = coins < _counter.price()
				state = CapsuleCounter.State.BROKE if short else CapsuleCounter.State.OK
		_machines[index].set_machine(
			aisle, left, aisle.capsule_cards.size(), state, _counter.price()
		)
	_show_chips(can_save, coins, owned)
	var fresh: bool = bool(_hold.get("new", not _counter.new_figurines().is_empty()))
	_new_tag.set_shown(fresh, _reduced_motion())
	if spent and not _reduced_motion():
		_pop_coins()
	if not can_save:
		_show_strip(Strip.OFF)
	elif all_empty:
		_show_strip(Strip.COMPLETE)
	elif broke:
		_show_strip(Strip.BROKE)
	else:
		_show_strip(Strip.HINT)
	_show_hover()


## The COINS LED (the coin, the count in gold, a tomato 0, or ? by the dim coin) and the
## FIGURINES LED beside it.
func _show_chips(can_save: bool, coins: int, owned: int) -> void:
	var art: float = ArtStyle.ART_SCALE
	var number: String = str(coins) if can_save else UNKNOWN_COINS
	var number_colour: Color = Palette.TOMATO if can_save and coins == 0 else Palette.GOLD
	_coins_line = PixelLine.new()
	_coins_line.show_tokens(
		[COIN if can_save else COIN_DIM, number, COINS_TEXT],
		Palette.MUSTARD_DARK,
		number_colour,
		1,
		CHIP_TOKEN_GAP,
		CHIP_ICON_TOP
	)
	var coins_width: float = _coins_chip.show_rows(
		[_coins_line], [CHIP_CAP_TOP], CHIP_HEIGHT, CHIP_PADDING
	)
	_coins_chip.position = Vector2(CHIP_AT) * art
	_figurines_line = PixelLine.new()
	var count: String = COUNT_TEXT % [owned, CapsuleDraw.capsule_count(_balance)]
	_figurines_line.show_tokens(
		[count, FIGURINES_TEXT], Palette.MUSTARD_DARK, Palette.GOLD, 1, CHIP_TOKEN_GAP
	)
	_figurines_chip.show_rows([_figurines_line], [CHIP_CAP_TOP], CHIP_HEIGHT, CHIP_PADDING)
	_figurines_chip.position = Vector2(CHIP_AT) * art + Vector2(coins_width + CHIP_GAP * art, 0)


## The out-of-coins notice: NO COINS YET for a profile that never had any (it drew no capsule,
## owns no capsule item and bought no pin), else NO COINS LEFT.
func _broke_notice() -> String:
	var profile: ProfileState = _counter.profile
	var spent: bool = (
		profile.capsule_draws > 0
		or profile.pins_bought > 0
		or not profile.unlocked_items.is_empty()
	)
	return BROKE_NOTICE if spent else BROKE_FRESH_NOTICE


## The LED strip's line: the hint (the coin before the price), a notice (the warning first) or
## COLLECTION COMPLETE at 2x over its line.
func _show_strip(kind: Strip) -> void:
	_strip_kind = kind
	var art: float = ArtStyle.ART_SCALE
	var rows: Array[PixelLine] = []
	var top: int = STRIP_TOP
	var height: int = STRIP_HEIGHT
	var cap_tops: Array[int] = [STRIP_CAP_TOP]
	match kind:
		Strip.COMPLETE:
			var heading: PixelLine = PixelLine.new()
			heading.show_tokens([FULL_BANNER], Palette.GOLD, Palette.GOLD, 2)
			var line: PixelLine = PixelLine.new()
			line.show_tokens(PixelLine.split(FULL_HINT), Palette.CREAM_SHADE, Palette.GOLD)
			rows = [heading, line]
			top = COMPLETE_TOP
			height = COMPLETE_HEIGHT
			cap_tops = COMPLETE_CAP_TOPS
		Strip.BROKE, Strip.OFF:
			var tokens: Array = [WARNING]
			tokens.append_array(
				PixelLine.split(_broke_notice() if kind == Strip.BROKE else OFF_NOTICE)
			)
			rows = [_strip_line(tokens)]
		_:
			var price: String = ToyMachineView.price_text(_counter.price())
			var tokens: Array = PixelLine.split(HINT_TEXT % price)
			for index: int in tokens.size():
				if PixelLine.is_number(str(tokens[index])):
					tokens.insert(index, COIN)
					break
			rows = [_strip_line(tokens)]
	var width: float = _strip.show_rows(rows, cap_tops, height, STRIP_PADDING)
	_strip.position = Vector2(STRIP_CENTRE * art - floorf(width / 2.0 / art) * art, top * art)


func _strip_line(tokens: Array) -> PixelLine:
	var line: PixelLine = PixelLine.new()
	line.show_tokens(tokens, Palette.CREAM_SHADE, Palette.GOLD)
	return line


## The lamps (on over a playable machine, hot over the hovered one) and the hovered machine's
## lineup in the board's place (none for an OUT OF ORDER machine, nor over the reveal).
func _show_hover() -> void:
	for index: int in range(_machines.size()):
		var machine: ToyMachineView = _machines[index]
		var kind: String = "off"
		if machine.state() == CapsuleCounter.State.OK:
			kind = "hot" if machine.is_hot() else "on"
		_lamps[index].texture = ToyExitArt.lamp(kind)
	if _join.owns_lineup():
		return  # The join's lineup card (kept up behind the reveal, then the join's stage).
	var lineup_up: bool = (
		_hovered != null
		and _hovered.state() != CapsuleCounter.State.OFF
		and not _reveal.visible
		and not _book.visible
	)
	if lineup_up:
		var centre: int = roundi(_hovered.position.x / ArtStyle.ART_SCALE) + MACHINE_CENTRE
		_lineup.show_aisle(_hovered.aisle(), _counter.profile.unlocked_items, centre)
	_lineup.visible = lineup_up
	_board.visible = not lineup_up


func _on_machine_hover(machine: ToyMachineView, inside: bool) -> void:
	if inside:
		for other: ToyMachineView in _machines:
			other.set_selected(false)
		_hovered = machine
	elif _hovered == machine:
		_hovered = null
	if _counter != null:
		_show_hover()


## Picks `machine` (null: none) as the arrow keys do: its hovered look and lineup, every other
## machine cooled.
func _select(machine: ToyMachineView) -> void:
	for other: ToyMachineView in _machines:
		other.clear_hover()
		other.set_selected(other == machine)
	_hovered = machine
	_show_hover()


## Every machine cooled and no lineup (the reveal or the book covers them).
func _cool_machines() -> void:
	for machine: ToyMachineView in _machines:
		machine.clear_hover()
	_hovered = null
	_show_hover()


## The COINS LED hops POP_RISE art px up and back (whole pixels: the LED stays on the grid).
func _pop_coins() -> void:
	if _coins_hop != null:
		_coins_hop.kill()
	var rest: Vector2 = _coins_chip.position
	_coins_chip.position = rest - Vector2(0, POP_RISE * ArtStyle.ART_SCALE)
	_coins_hop = _coins_chip.create_tween()
	_coins_hop.tween_interval(POP_SECONDS)
	_coins_hop.tween_callback(func() -> void: _coins_chip.position = rest)


func _reduced_motion() -> bool:
	return _counter != null and _counter.profile.reduced_motion()


func _on_machine_picked(aisle: AisleDefinition) -> void:
	if _reveal.visible or _book.visible or _join.is_active() or _counter == null:
		return
	var profile: ProfileState = _counter.profile
	var before: Dictionary = profile.unlocked_items.duplicate()
	var hold: Dictionary = {
		"aisle": aisle,
		"left": _counter.items_left(aisle),
		"owned": profile.owned_capsules(_balance),
		"new": not _counter.new_figurines().is_empty(),
		"strip": true,
	}
	var kept: bool = _lineup.visible and _hovered != null and _hovered.aisle() == aisle
	var card: CardDefinition = _counter.draw(aisle)
	if card == null:
		_refresh()
		return
	_hold = hold
	_pending = {"card": card, "aisle": aisle, "before": before}
	_join.hold_lineup(kept)
	_refresh()
	Sfx.play_at(self, "coin")
	_cool_machines()
	_reveal.still = _reduced_motion()
	_reveal.show_card(card)
	_show_hover()


## The reveal's hold is over: the icon flies into its lineup card.
func _on_reveal_held() -> void:
	if _pending.is_empty():
		_reveal.leave(1.0)
		_refresh()
		return
	var aisle: AisleDefinition = _pending["aisle"]
	var profile: ProfileState = _counter.profile
	var completed: bool = (
		CapsuleDraw.is_empty(aisle, profile.unlocked_items)
		and StartSetupRules.completed(_balance, profile).has(aisle)
	)
	var all_done: bool = profile.owned_capsules(_balance) == CapsuleDraw.capsule_count(_balance)
	var index: int = _balance.aisles.find(aisle)
	var options: Dictionary = {"reduced": _reduced_motion(), "collection": all_done}
	_join.play(
		_pending["card"],
		aisle,
		_machines[index],
		_lamps[index],
		_pending["before"],
		completed,
		options
	)
	_pending = {}


## The join's beats: the tick shows the counts after the draw, SOLD OUT the machine's emptied
## state, the collection beat COLLECTION COMPLETE.
func _on_join_beat(id: StringName) -> void:
	match id:
		&"tick":
			_hold["left"] = _counter.items_left(_hold["aisle"]) if _hold.has("aisle") else 0
			_hold.erase("owned")
			_hold.erase("new")
		&"sold":
			_hold.erase("aisle")
			_hold.erase("left")
		&"collection":
			_hold.erase("strip")
		_:
			return
	_refresh()


func _on_join_finished() -> void:
	_hold = {}
	_refresh()


## Opening the FIGURINE BOOK shows every new figurine: its cards wear the NEW tag this time
## (CapsuleCounter.new_figurines, read first), then they are marked seen and saved
## (CapsuleCounter.mark_all_seen) and the button's NEW tag goes.
func _open_shelf() -> void:
	if _reveal.visible:
		return
	_book.show_collection(
		_balance,
		_counter.profile.unlocked_items,
		_counter.profile.coupon_uses,
		_counter.new_figurines(),
		_reduced_motion(),
		_counter.profile.perk_levels
	)
	_counter.mark_all_seen()
	_new_tag.set_shown(false, true)
	_cool_machines()
	_book.visible = true
	_machines_layer.visible = false


func _close_shelf() -> void:
	_book.visible = false
	_machines_layer.visible = true
	_refresh()
