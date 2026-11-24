class_name PuzzleBoard
extends TitlePopup
## The title's puzzle board (#183, prep page puzzle_shift.html, full build plan section 7.6): a
## popup over the title drawn on the 640x360 art grid (ArtPen) as the start board. Its head reads
## PUZZLE SHIFTS and SOLVED n/24; under it the three packs' tabs (a locked pack shows its padlock
## and how many solves of the pack before open it); left the open pack's eight puzzles as cards
## in a 4x2 grid (their number, title and target; a solved one wears the check), right the
## clipboard (pixel art: frames/clipboard.png and its clip) with the picked puzzle's sheet: its
## pack and number, its title, HIT EXACTLY and its target, its hand as small item cards with the
## belt's slots, its perks, pins and today's events, its hint, and PLAY.
##
## A completed pack (every puzzle solved; #183 polish, play test 2026-11-23) turns golden: its tab
## the gold button (frames/button_gold.png) and its cards gold foil (a gold band, a mustard pale
## face in a brass inner frame, the gold check, mark_check_gold.png). The first time the board
## opens after the solve that completed it (PuzzlePlay.take_completed), a light sweeps once
## across its tab and cards (SHINE_TIME, in SHINE_STEP art px steps; none when `still`) with a
## ding.
##
## Under the cards each pack shows its reward (polish 5, play test 2026-11-23: why play): its
## badge pin (the catalogue's PUZZLE_PACK pin for it) as a mystery badge (icons/pin_mystery.png,
## a "?" pin silhouette) over "Solve all 8 to unlock" until it is earned, then the real pin's face
## (PinStepDraw.face) with its name, on a gold strip.
##
## The mouse and the keys share one marker (TitlePopup): marking a puzzle picks it for the
## clipboard; pressing it (click, Enter, Space) or PLAY plays it (play_requested); a tab press
## opens its pack (if open); Esc or ‹ TITLE closes the board.

## PLAY (or a press on a picked puzzle) asks for puzzle `puzzle_id`.
signal play_requested(puzzle_id: StringName)

## The sheet (art px) and its parts' rects (art px from the sheet's top left).
const SHEET_ART := Vector2i(600, 320)
const BACK_RECT := Rect2(512, 10, 76, 20)
const TAB_RECT := Rect2(14, 38, 104, 20)
const TAB_PITCH := 110.0
const CARD_RECT := Rect2(14, 66, 76, 108)
const CARD_PITCH := Vector2(82, 116)
## The pack's reward strip under the cards (art px), its badge BADGE art px across.
const REWARD_RECT := Rect2(14, 294, 324, 22)
const BADGE := 16
const REWARD_HEAD := "PACK REWARD · BADGE PIN"
const REWARD_LOCKED := "Solve all %d to unlock"
const REWARD_EARNED := "%s: yours to wear"
const MYSTERY := preload("res://art/icons/pin_mystery.png")
const CATALOGUE := "res://data/catalogue/catalogue.tres"
const CLIP_RECT := Rect2(354, 38, 234, 270)
const PLAY_RECT := Rect2(424, 276, 94, 22)
const TITLE_TEXT := "PUZZLE SHIFTS"
const SOLVED_TEXT := "SOLVED %d/%d"
const BACK_TEXT := "< TITLE"
const PLAY_TEXT := "PLAY"
const LOCKED_TEXT := "SOLVE %d MORE"
const CHECK := preload("res://art/icons/mark_check.png")
const CHECK_GOLD := preload("res://art/icons/mark_check_gold.png")
const GOLD_BUTTON := preload("res://art/frames/button_gold.png")
## The shine over a pack just completed: a light band SHINE_BAND art px wide (paper, then a
## SHINE_TRAIL of mustard pale), leaning SHINE_LEAN art px left per row, sweeping from
## SHINE_FROM to SHINE_TO (art px, the sheet's) over SHINE_TIME in SHINE_STEP steps, once the
## popup has opened and SHINE_DELAY more.
const SHINE_BAND := 3
const SHINE_TRAIL := 2
const SHINE_LEAN := 0.5
const SHINE_FROM := -80.0
const SHINE_TO := 420.0
const SHINE_TIME := 0.9
const SHINE_STEP := 4.0
const SHINE_DELAY := 0.15
const SHINE_SOUND := "ding"
const PADLOCK := preload("res://art/icons/padlock.png")
const BUTTON_MARGINS := Vector4i(3, 3, 3, 4)

var list: PuzzleList
var profile: ProfileState
## The pack shown (from 1) and the puzzle on the clipboard.
var pack: int = 1
var picked: PuzzleDefinition
var _canvas: Control
var _pen: ArtPen
var _tabs: Array[Control] = []
var _cards: Array[Control] = []
var _play: Control
var _back: Control
## The shine's left edge on the tabs' top row (art px), or NAN while none sweeps.
var _shine_x: float = NAN
var _shine: Tween
## Each pack's reward pin (pack number -> its PUZZLE_PACK pin) and its catalogue place.
var _rewards: Dictionary[int, PinDefinition] = {}
var _reward_index: Dictionary[int, int] = {}


func _init() -> void:
	super(SHEET_ART)
	name = "PuzzleBoard"
	_canvas = Control.new()
	_canvas.name = "Page"
	_canvas.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_canvas.size = Vector2(SHEET_ART) * ArtStyle.ART_SCALE
	ArtStyle.use_pixel_material(_canvas)
	_canvas.draw.connect(_draw_page)
	sheet().add_child(_canvas)
	_pen = ArtPen.new(_canvas)
	for index: int in 8:
		var at: Vector2 = CARD_RECT.position + Vector2(index % 4, floori(index / 4.0)) * CARD_PITCH
		_cards.append(_hit(Rect2(at.floor(), CARD_RECT.size), "Puzzle%d" % (index + 1)))
	_play = _hit(PLAY_RECT, "Play")
	for index: int in 3:
		var at: Vector2 = TAB_RECT.position + Vector2(index * TAB_PITCH, 0)
		_tabs.append(_hit(Rect2(at, TAB_RECT.size), "Pack%d" % (index + 1)))
	_back = _hit(BACK_RECT, "Back")


## Opens the board on `profile`'s progress through `puzzles`, on the newest open pack, its first
## unsolved puzzle picked (`at`: that puzzle instead, the one just played).
func open(puzzle_list: PuzzleList, player: ProfileState, at: StringName = &"") -> void:
	list = puzzle_list
	profile = player
	_find_rewards()
	pack = 1
	for number: int in range(1, list.pack_count() + 1):
		if list.is_open(number, profile.solved_puzzles):
			pack = number
	var played: PuzzleDefinition = list.find(at) if at != &"" else null
	if played != null:
		pack = played.pack
	var completed: int = PuzzlePlay.take_completed()
	if completed > 0 and is_golden(completed) and pack != completed:
		pack = completed
		played = null
	_show_pack(pack, played)
	_show_popup()
	if completed > 0 and completed == pack:
		shine()


## The light sweeps once across the shown pack's tab and cards (a pack just completed), with a
## ding; nothing when `still`.
func shine() -> void:
	if _shine != null:
		_shine.kill()
	_shine_x = NAN
	if still:
		return
	_shine = create_tween()
	_shine.tween_interval(TitlePopup.OPEN_TIME + SHINE_DELAY)
	_shine.tween_callback(Sfx.play_at.bind(self, SHINE_SOUND, 0.0))
	_shine.tween_method(_set_shine, SHINE_FROM, SHINE_TO, SHINE_TIME)
	_shine.tween_callback(_set_shine.bind(NAN))


## Whether the shine is sweeping now.
func is_shining() -> bool:
	return not is_nan(_shine_x)


## Pack `number`'s reward pin (null: none) and whether the profile has earned it.
func reward_pin(number: int) -> PinDefinition:
	return _rewards.get(number) as PinDefinition


func reward_earned(number: int) -> bool:
	var pin: PinDefinition = reward_pin(number)
	return pin != null and profile.has_pin(pin)


## The reward strip's rect on the canvas (global).
func reward_rect() -> Rect2:
	var k: float = ArtStyle.ART_SCALE
	return Rect2(sheet().global_position + REWARD_RECT.position * k, REWARD_RECT.size * k)


## Whether pack `number` is complete (golden) on the profile.
func is_golden(number: int) -> bool:
	return list.is_complete(number, profile.solved_puzzles)


## Shows pack `number` (if open) with `puzzle` (none: its first unsolved one) on the clipboard.
func show_pack(number: int) -> void:
	if list.is_open(number, profile.solved_puzzles):
		_show_pack(number, null)


## The open pack's puzzles, in order.
func puzzles() -> Array[PuzzleDefinition]:
	return list.pack(pack)


## The hit rects (sheet children) for checks: the cards, the tabs, PLAY and ‹ TITLE.
func card_hits() -> Array[Control]:
	return _cards


func tab_hits() -> Array[Control]:
	return _tabs


func play_hit() -> Control:
	return _play


func back_hit() -> Control:
	return _back


## The clipboard's rect on the canvas (global).
func clipboard_rect() -> Rect2:
	var k: float = ArtStyle.ART_SCALE
	return Rect2(sheet().global_position + CLIP_RECT.position * k, CLIP_RECT.size * k)


func _show_pack(number: int, puzzle: PuzzleDefinition) -> void:
	pack = number
	picked = puzzle
	if picked == null:
		for each: PuzzleDefinition in list.pack(pack):
			if not ProfilePuzzles.is_solved(profile, each):
				picked = each
				break
	if picked == null:
		picked = list.pack(pack)[0]
	_entries.clear()
	_entries.append_array(_cards)
	_entries.append_array([_play, _back])
	_entries.append_array(_tabs)
	_canvas.queue_redraw()


func _set_shine(x: float) -> void:
	_shine_x = x if is_nan(x) else floorf(x / SHINE_STEP) * SHINE_STEP
	_canvas.queue_redraw()


func _hit(rect: Rect2, hit_name: String) -> Control:
	var hit: Control = Control.new()
	hit.name = hit_name
	hit.position = rect.position * ArtStyle.ART_SCALE
	hit.size = rect.size * ArtStyle.ART_SCALE
	hit.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	hit.gui_input.connect(
		func(event: InputEvent) -> void:
			var click: InputEventMouseButton = event as InputEventMouseButton
			if click != null and click.pressed and click.button_index == MOUSE_BUTTON_LEFT:
				_press(hit)
	)
	sheet().add_child(hit)
	_add_entry(hit)
	return hit


func _show_marked(entry: Control, on: bool) -> void:
	var index: int = _cards.find(entry)
	if on and index >= 0 and index < puzzles().size():
		picked = puzzles()[index]
	_canvas.queue_redraw()


func _press(entry: Control) -> void:
	if entry == _back:
		close()
	elif entry == _play:
		play_requested.emit(picked.id)
	elif _tabs.has(entry):
		show_pack(_tabs.find(entry) + 1)
	elif _cards.has(entry):
		var puzzle: PuzzleDefinition = puzzles()[_cards.find(entry)]
		if puzzle == picked:
			play_requested.emit(puzzle.id)
		picked = puzzle
		_canvas.queue_redraw()


func _draw_page() -> void:
	if list == null:
		return
	var lit: Control = marked()
	_pen.chunky(TITLE_TEXT, 16, 12, Palette.TEAL_DARK, 2.0)
	var solved: String = SOLVED_TEXT % [profile.solved_puzzles.size(), list.puzzles.size()]
	_pen.caps(solved, 340, 18, Palette.INK_LIGHT, 2.0, HORIZONTAL_ALIGNMENT_RIGHT)
	_button(BACK_RECT, BACK_TEXT, BoosterArt.BUTTON_TEAL, lit == _back)
	for index: int in list.pack_count():
		_draw_tab(index + 1, lit == _tabs[index])
	var shown: Array[PuzzleDefinition] = puzzles()
	for index: int in shown.size():
		_draw_card(shown[index], index, lit == _cards[index])
	_draw_reward()
	PuzzleBoardSheet.draw(_pen, CLIP_RECT, picked, list, profile)
	_button(PLAY_RECT, PLAY_TEXT, BoosterArt.BUTTON, lit == _play)


func _button(rect: Rect2, text: String, frame: Texture2D, lit: bool) -> void:
	_pen.nine(frame, rect.position.x, rect.position.y, rect.size.x, rect.size.y, BUTTON_MARGINS)
	var middle: float = rect.position.x + rect.size.x / 2.0
	_pen.chunky(text, middle, rect.position.y + 6, Palette.PAPER, 1.0, HORIZONTAL_ALIGNMENT_CENTER)
	if lit:
		_pen.focus_ring(rect.position.x, rect.position.y, rect.size.x, rect.size.y)


func _draw_tab(number: int, lit: bool) -> void:
	var x: float = TAB_RECT.position.x + (number - 1) * TAB_PITCH
	var y: float = TAB_RECT.position.y
	var opened: bool = list.is_open(number, profile.solved_puzzles)
	var golden: bool = is_golden(number)
	var frame: Texture2D = BoosterArt.BUTTON if number == pack else BoosterArt.BUTTON_TEAL
	if golden:
		frame = GOLD_BUTTON
	_pen.nine(frame, x, y, TAB_RECT.size.x, TAB_RECT.size.y, BUTTON_MARGINS, _dim(opened))
	var words: String = list.pack_title(number)
	var middle: float = x + TAB_RECT.size.x / 2.0
	if opened:
		var solved: int = list.solved_in(number, profile.solved_puzzles)
		var done: String = "%s %d/%d" % [words, solved, list.pack(number).size()]
		var ink: Color = Palette.BRASS_DARKEST if golden else Palette.PAPER
		_pen.caps(done, middle, y + 7, ink, 1.0, HORIZONTAL_ALIGNMENT_CENTER)
		if golden and number == pack:  # The pack shown: a tomato strip under its gold tab.
			_pen.r(x + 3, y + TAB_RECT.size.y + 1, TAB_RECT.size.x - 6, 2, Palette.TOMATO)
		if golden:
			_draw_shine(Rect2(x + 1, y + 1, TAB_RECT.size.x - 2, TAB_RECT.size.y - 4))
	else:
		_pen.tex(PADLOCK, x + 6, y + 4)
		var left: int = list.unlock_solves - list.solved_in(number - 1, profile.solved_puzzles)
		_pen.caps(words, middle + 6, y + 4, Palette.PAPER, 1.0, HORIZONTAL_ALIGNMENT_CENTER)
		_pen.caps(LOCKED_TEXT % left, middle + 6, y + 11, Palette.MUSTARD_LIGHT, 1.0, 1)
	if lit:
		_pen.focus_ring(x, y, TAB_RECT.size.x, TAB_RECT.size.y)


func _draw_card(puzzle: PuzzleDefinition, index: int, lit: bool) -> void:
	var at: Vector2 = (
		(CARD_RECT.position + Vector2(index % 4, floori(index / 4.0)) * CARD_PITCH).floor()
	)
	var w: float = CARD_RECT.size.x
	var h: float = CARD_RECT.size.y
	var chosen: bool = puzzle == picked
	if is_golden(puzzle.pack):
		_draw_gold_card(puzzle, index, at, chosen)
	else:
		var face: Color = Palette.PAPER if chosen else Palette.CREAM
		_pen.rb(at.x, at.y, w, h, face)
		_pen.r(at.x + 1, at.y + h - 3, w - 2, 2, Palette.CREAM_SHADE)
		var band: Color = Palette.TEAL if not chosen else Palette.TOMATO
		_pen.r(at.x + 1, at.y + 1, w - 2, 18, band)
		_draw_card_words(puzzle, index, at, [Palette.PAPER, Palette.INK_LIGHT, Palette.TEAL_DARK])
		if ProfilePuzzles.is_solved(profile, puzzle):
			_pen.tex(CHECK, at.x + w - 18, at.y + h - 20)
	if lit:
		_pen.focus_ring(at.x, at.y, w, h)


## A completed pack's card in gold foil: a gold band (brass when picked) over a mustard pale face
## (paper when picked) in a brass inner frame, brass words, the gold check; the shine crosses it
## while it sweeps.
func _draw_gold_card(puzzle: PuzzleDefinition, index: int, at: Vector2, chosen: bool) -> void:
	var w: float = CARD_RECT.size.x
	var h: float = CARD_RECT.size.y
	_pen.rb(at.x, at.y, w, h, Palette.BRASS)
	_pen.r(at.x + 2, at.y + 2, w - 4, h - 4, Palette.PAPER if chosen else Palette.MUSTARD_PALE)
	_pen.r(at.x + 2, at.y + h - 4, w - 4, 2, Palette.MUSTARD_LIGHT)
	_pen.r(at.x + 2, at.y + 2, w - 4, 17, Palette.BRASS if chosen else Palette.GOLD)
	_pen.r(at.x + 2, at.y + 2, w - 4, 1, Palette.MUSTARD_PALE)
	_pen.r(at.x + 2, at.y + 18, w - 4, 1, Palette.BRASS_DARK)
	var band_ink: Color = Palette.PAPER if chosen else Palette.BRASS_DARKEST
	_draw_card_words(puzzle, index, at, [band_ink, Palette.BRASS_DARK, Palette.BRASS_DARK])
	_pen.tex(CHECK_GOLD, at.x + w - 18, at.y + h - 20)
	_draw_shine(Rect2(at.x + 1, at.y + 1, w - 2, h - 2))


## A card's number, slots, title, HIT and target; `inks`: the band's words, HIT's and the
## target's colours.
func _draw_card_words(
	puzzle: PuzzleDefinition, index: int, at: Vector2, inks: Array[Color]
) -> void:
	var w: float = CARD_RECT.size.x
	_pen.chunky(str(index + 1), at.x + 6, at.y + 6, inks[0])
	_pen.caps("%d SLOTS" % puzzle.slot_count, at.x + w - 5, at.y + 8, inks[0], 1.0, 2)
	var line: int = 0
	for words: String in ArtPen.pix_wrap(puzzle.title, w - 10):
		_pen.pix(words, at.x + 5, at.y + 26 + line * 10, Palette.INK)
		line += 1
	_pen.caps("HIT", at.x + 5, at.y + 64, inks[1])
	_pen.chunky("%d€" % puzzle.target, at.x + 5, at.y + 72, inks[2], 2.0)


## The shine's band over art rect `rect`, row by row (it leans SHINE_LEAN left per row down).
func _draw_shine(rect: Rect2) -> void:
	if is_nan(_shine_x):
		return
	for row: int in int(rect.size.y):
		var y: float = rect.position.y + row
		var left: float = _shine_x - floorf((y - TAB_RECT.position.y) * SHINE_LEAN)
		_shine_row(rect, y, left, SHINE_BAND, Palette.PAPER)
		_shine_row(rect, y, left - SHINE_TRAIL, SHINE_TRAIL, Palette.MUSTARD_PALE)


func _shine_row(rect: Rect2, y: float, left: float, width: float, colour: Color) -> void:
	var from: float = maxf(left, rect.position.x)
	var to: float = minf(left + width, rect.end.x)
	if to > from:
		_pen.r(from, y, to - from, 1, colour)


## The shown pack's reward: the mystery badge and how to earn it, or the earned pin on gold.
func _draw_reward() -> void:
	var pin: PinDefinition = reward_pin(pack)
	if pin == null:
		return
	var x: float = REWARD_RECT.position.x
	var y: float = REWARD_RECT.position.y
	var earned: bool = reward_earned(pack)
	var face: Color = Palette.MUSTARD_PALE if earned else Palette.CREAM
	_pen.rb(x, y, REWARD_RECT.size.x, REWARD_RECT.size.y, face, Palette.BROWN_DARK)
	_pen.r(x + 1, y + REWARD_RECT.size.y - 2, REWARD_RECT.size.x - 2, 1, Palette.CREAM_SHADE)
	var badge_y: float = y + floorf((REWARD_RECT.size.y - BADGE) / 2.0) - 1
	if earned:
		PinStepDraw.face(_pen, pin, int(_reward_index[pack]), x + 4, badge_y, BADGE)
	else:
		_pen.tex(MYSTERY, x + 4, badge_y)
	var head_ink: Color = Palette.BRASS_DARK if earned else Palette.INK_LIGHT
	_pen.caps(REWARD_HEAD, x + BADGE + 9, y + 4, head_ink)
	var line: String = REWARD_LOCKED % list.pack(pack).size()
	if earned:
		line = REWARD_EARNED % pin.display_name
	_pen.pix(line, x + BADGE + 9, y + 11, Palette.INK)


func _find_rewards() -> void:
	_rewards.clear()
	_reward_index.clear()
	var catalogue: CatalogueDefinition = load(CATALOGUE)
	for index: int in catalogue.pins.size():
		var condition: UnlockCondition = catalogue.pins[index].unlock_condition
		if condition != null and condition.kind == UnlockCondition.Kind.PUZZLE_PACK:
			_rewards[condition.amount] = catalogue.pins[index]
			_reward_index[condition.amount] = index


static func _dim(opened: bool) -> Color:
	return Color.WHITE if opened else Color(0.7, 0.7, 0.7)
