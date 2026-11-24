class_name PuzzleVerdictKeys
extends Control
## A puzzle shift's verdict keys (#183 polish, play test 2026-11-23): after the count, the next
## move stands big in the middle of the play area, centred on the belt's shown part (from the
## scanner's end to the short belt's cut) over its rail. A miss (OVER, SHORT): RETRY, big, in
## mustard (try again; polish 5: clear of NEXT's tomato and the miss stamp's). A solve (EXACT):
## NEXT (the pack's next open puzzle), or BOARD when there is none, big and tomato, with a small
## mustard RETRY beside it; a solve that completes its pack (polish 5): BOARD alone, on the gold
## button.
##
## The entrance (polish 5, the game's stamp vocabulary): once the receipt's stamp has landed
## (ENTRANCE_DELAY, EXACT_DELAY after a solve's celebration), each key appears big and hangs a
## beat (anticipation), then slams down through ENTRANCE_SCALES (an overshoot under 1, a
## rebound, the settle), one step every ENTRANCE_STEP, with the stamp's sound and a dust puff on
## impact; the small key ENTRANCE_STAGGER later. Then the big key hops one art px and brightens
## every PULSE_PERIOD (an idle pulse) until it is pressed or hidden. `still` (reduced motion):
## the keys at once, no pulse, no dust. Display and input only: PuzzleFlow acts on the signals
## and hides them (hide_keys) when the belt is played again.

signal retry_pressed
signal next_pressed
signal board_pressed

## What the big key does: RETRY (a miss), NEXT or BOARD (a solve).
enum Big { RETRY, NEXT, BOARD }

## The keys' middle height on the stage (canvas px: the belt's rail) and the belt's shown part's
## left end (the scanner's).
const MIDDLE_Y := 444.0
const BELT_LEFT := 354.0
## The big key and the small RETRY beside it (canvas px), SMALL_GAP apart.
const BIG_SIZE := Vector2(236, 76)
const BIG_FONT := 32
const SMALL_SIZE := Vector2(116, 56)
const SMALL_FONT := 18
const SMALL_GAP := 14.0
const RETRY_TEXT := "RETRY"
const NEXT_TEXT := "NEXT >"
const BOARD_TEXT := "BOARD"
const GO_FRAME := preload("res://art/frames/button.png")
const RETRY_FRAME := preload("res://art/frames/button_mustard.png")
const GOLD_FRAME := preload("res://art/frames/button_gold.png")
## The entrance: after ENTRANCE_DELAY (EXACT_DELAY after a solve), each key shows at
## ENTRANCE_SCALES[0] for ANTICIPATION, then takes the next scales one ENTRANCE_STEP apart; it
## lands (the sound, the dust) on IMPACT_STEP. The small key ENTRANCE_STAGGER later.
const ENTRANCE_DELAY := 0.35
const EXACT_DELAY := 0.6
const ENTRANCE_SCALES: Array[float] = [1.5, 1.25, 0.88, 1.06, 1.0]
const ANTICIPATION := 0.09
const ENTRANCE_STEP := 0.05
const IMPACT_STEP := 2
const ENTRANCE_STAGGER := 0.1
const ENTRANCE_SOUND := "stamp"
## Dust on impact: DUST pieces from the key's foot.
const DUST := 10
## The idle pulse: every PULSE_PERIOD the big key hops PULSE_LIFT px for PULSE_ON, its face lit.
const PULSE_PERIOD := 1.3
const PULSE_ON := 0.16
const PULSE_LIFT := 2.0
const PULSE_FACE := Color(1.14, 1.14, 1.14)

var still: bool = false
var _big: FramedButton
var _small: FramedButton
var _kind: Big = Big.RETRY
var _entrances: Array[Tween] = []
var _dust: CheerConfetti
## The big key's resting top (canvas px), for the idle pulse.
var _big_top: float = 0.0
var _pulse_clock: float = 0.0
## The belt's shown part's right end (canvas px).
var _belt_right: float = ShiftStage.BELT_RECT.end.x


func _init() -> void:
	name = "PuzzleVerdictKeys"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	size = ShiftStage.SIZE
	_big = UiKit.framed_button(self, RETRY_TEXT, _on_big, BIG_FONT, RETRY_FRAME, BIG_SIZE)
	_small = UiKit.framed_button(
		self, RETRY_TEXT, retry_pressed.emit, SMALL_FONT, RETRY_FRAME, SMALL_SIZE
	)
	_dust = CheerConfetti.new()
	_dust.size = size
	add_child(_dust)
	hide_keys()


## Centres the keys on a belt cut `cut` canvas px short (BeltPanel.cut).
func fit(cut: float) -> void:
	_belt_right = ShiftStage.BELT_RECT.end.x - cut
	_place()


## Shows the verdict's keys: a solve's (`exact`; `next`: a next puzzle is open; `completed`: the
## solve completed its pack, BOARD alone in gold) or a miss's.
func show_keys(exact: bool, next: bool, completed: bool = false) -> void:
	_kill_entrances()
	_kind = Big.RETRY
	if exact:
		_kind = Big.NEXT if next and not completed else Big.BOARD
	_big.caption = [RETRY_TEXT, NEXT_TEXT, BOARD_TEXT][_kind]
	var frame: Texture2D = RETRY_FRAME if _kind == Big.RETRY else GO_FRAME
	var gold: bool = completed and exact
	_big.set_frame(GOLD_FRAME if gold else frame)
	_ink(_big, gold)
	_small.visible = exact and not completed
	_big.visible = true
	_place()
	_pulse_clock = 0.0
	if still:
		return
	var delay: float = EXACT_DELAY if exact else ENTRANCE_DELAY
	_enter(_big, delay)
	if _small.visible:
		_enter(_small, delay + ENTRANCE_STAGGER)


## Takes the keys away (the belt is played again).
func hide_keys() -> void:
	_kill_entrances()
	_big.visible = false
	_small.visible = false
	for key: FramedButton in [_big, _small]:
		key.scale = Vector2.ONE
		key.face().modulate = Color.WHITE
	_place()


func big_key() -> FramedButton:
	return _big


func small_key() -> FramedButton:
	return _small


func big_kind() -> Big:
	return _kind


## The keys have landed (their entrance is over, or none plays).
func is_landed() -> bool:
	for entrance: Tween in _entrances:
		if entrance.is_running():
			return false
	return true


## Whether the big key is mid-hop (its idle pulse).
func is_pulsing() -> bool:
	return _big.visible and _big.position.y < _big_top


func _process(delta: float) -> void:
	if still or not _big.visible or not is_landed():
		return
	_pulse_clock = fmod(_pulse_clock + delta, PULSE_PERIOD)
	var on: bool = _pulse_clock >= PULSE_PERIOD - PULSE_ON
	_big.position.y = _big_top - (PULSE_LIFT if on else 0.0)
	if _big.get_draw_mode() == BaseButton.DRAW_NORMAL:
		_big.face().modulate = PULSE_FACE if on else Color.WHITE


## The big key and the small one (when shown) centred together on the belt's shown part.
func _place() -> void:
	var width: float = BIG_SIZE.x + (SMALL_GAP + SMALL_SIZE.x if _small.visible else 0.0)
	var left: float = roundf(((BELT_LEFT + _belt_right) / 2.0 - width / 2.0) / 2.0) * 2.0
	_big_top = MIDDLE_Y - BIG_SIZE.y / 2.0
	_big.size = BIG_SIZE
	_big.position = Vector2(left, _big_top)
	_big.pivot_offset = BIG_SIZE / 2.0
	_small.size = SMALL_SIZE
	_small.position = Vector2(left + BIG_SIZE.x + SMALL_GAP, MIDDLE_Y - SMALL_SIZE.y / 2.0)
	_small.pivot_offset = SMALL_SIZE / 2.0


## `key` comes in `delay` from now: hidden, then big for ANTICIPATION, then each scale of
## ENTRANCE_SCALES; the impact plays the stamp's sound and puffs dust from its foot.
func _enter(key: FramedButton, delay: float) -> void:
	key.visible = false
	var entrance: Tween = create_tween()
	_entrances.append(entrance)
	entrance.tween_interval(delay)
	entrance.tween_callback(_scale_key.bind(key, ENTRANCE_SCALES[0]))
	entrance.tween_interval(ANTICIPATION)
	for step: int in range(1, ENTRANCE_SCALES.size()):
		entrance.tween_callback(_scale_key.bind(key, ENTRANCE_SCALES[step]))
		if step == IMPACT_STEP:
			entrance.tween_callback(_impact.bind(key))
		entrance.tween_interval(ENTRANCE_STEP)


## The caption in brass darkest with no outline on the gold button (as the board's gold tab),
## else the frames' paper with its outline.
static func _ink(key: FramedButton, gold: bool) -> void:
	var label: Label = key.caption_label()
	if gold:
		label.add_theme_color_override("font_color", Palette.BRASS_DARKEST)
		label.add_theme_constant_override("outline_size", 0)
	else:
		label.add_theme_color_override("font_color", Palette.PAPER)
		label.add_theme_constant_override("outline_size", UiKit.LIGHT_OUTLINE)


func _scale_key(key: FramedButton, factor: float) -> void:
	key.visible = true
	key.scale = Vector2.ONE * factor


func _impact(key: FramedButton) -> void:
	Sfx.play_at(self, ENTRANCE_SOUND, 0.0)
	var foot: Vector2 = Vector2(key.position.x + key.size.x / 2.0, key.position.y + key.size.y)
	_dust.dust(foot, DUST, int(key.position.x))


func _kill_entrances() -> void:
	for entrance: Tween in _entrances:
		entrance.kill()
	_entrances.clear()


func _on_big() -> void:
	match _kind:
		Big.NEXT:
			next_pressed.emit()
		Big.BOARD:
			board_pressed.emit()
		_:
			retry_pressed.emit()
