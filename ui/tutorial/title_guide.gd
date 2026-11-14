class_name TitleGuide
extends Control
## The guided first run's first step on the title (G1, mock-up tutorial.html): while the next
## new run is guided (due: TutorialFlags.guided_due on the peeked profile), a pulsing gold ring
## around the plate that starts it (TitleMenu.start_entry: START RUN, or NEW RUN with a run
## saved; TutorialAnchors.TITLE_PRIMARY) and a paper callout (TipCard, the hover tips' card, its
## band mustard: YOUR MOVE 1/26) beside it, pointing at it. The line follows the plate's label
## (decided 2026-11-14): "Click START RUN." on a fresh profile, "Click NEW RUN." with a run saved.
## A saved guided run shows no G1: CONTINUE resumes its step.
##
## Display only: it takes no clicks, so the plate and the doors work as always, and nothing is
## saved (G1 shows on every title until a guided run starts). It shows only while `blocked` says
## no (the title's intro, a popup, the handbook, the toy machines or a start) and the plate is
## on screen; it follows the plate as it slides in. Reduced motion (`still`) holds the pulse.
##
## Its text is the approved G1 line with {label} for the plate's label (text_template, so the
## guided script's own line can replace it when the tutorial's data is wired); plain words, no
## chips yet (the glossary's chips come with the tutorial's text data).

const STEP_ID := &"G1"
const HEADER := "YOUR MOVE"
## The guided run's steps (G1..G26), for the header's count.
const STEP_COUNT := 26
const TEXT := (
	"Welcome to the till! Click {label}. Your first SHIFT shows you how to play, one move at a"
	+ " time."
)
const LABEL_KEY := "{label}"
## The callout's footer on a step whose move is a click on its ring.
const CLICK_TARGET := "THE RING"
## The callout's width (the hover tips' card is 256: the mock-up's 440 at 1920 is about 300).
const CARD_WIDTH := 300.0
## The ring: RING_PAD px around its target (its INK + BORDER + INK px frame clear of it), a
## BORDER px gold band between INK px ink lines,
## pulsing gold to mustard pale in PULSE_STEPS steps every PULSE_S (the mock-up's 1.1 s steps(4)).
const RING_PAD := 10.0
const BORDER := 4.0
const INK := 2.0
const PULSE_S := 1.1
const PULSE_STEPS := 4
## The ring's CLICK tab over its top right corner.
const TAB_TEXT := "CLICK"
const TAB_PAD := Vector2(4, 2)

## Holds the pulse (the profile's reduced motion).
var still: bool = false
## The G1 line, {label} the plate's label.
var text_template: String = TEXT
## Returns true while the guide must stay hidden (the title's intro, a popup, a start). None:
## never.
var blocked: Callable = Callable()

var _menu: TitleMenu
var _active: bool = false
var _card: TipCard
var _ring: Control
var _tab: Label
var _clock: float = 0.0


## The guide for `menu`'s start plate (inactive until set_active).
func _init(menu: TitleMenu) -> void:
	name = "TitleGuide"
	_menu = menu
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)
	visible = false
	_ring = Control.new()
	_ring.name = "Ring"
	_ring.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ring.draw.connect(_draw_ring)
	add_child(_ring)
	_tab = UiKit.pixel_label(TAB_TEXT, 2, Palette.INK)
	_tab.name = "ClickTab"
	_tab.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ring.add_child(_tab)
	_card = TipCard.new()
	_card.name = "Callout"
	_card.width_override = CARD_WIDTH
	add_child(_card)


## Whether the title shows G1: a readable profile whose next new run is guided, unless the saved
## run is itself guided (CONTINUE resumes it).
static func due(profile: ProfileState, saved: RunSave) -> bool:
	if profile == null:
		return false
	if saved != null and saved.run != null and saved.run.guided:
		return false
	return TutorialFlags.guided_due(profile)


## Turns G1 on or off (the title, from due).
func set_active(on: bool) -> void:
	if on and not _active:
		_card.show_spec(spec())
	_active = on
	_follow()


func is_active() -> bool:
	return _active


## Whether the ring and the callout are on screen now.
func is_showing() -> bool:
	return visible


## The G1 line for the start plate's label.
func line() -> String:
	var start: MenuPlate = _menu.plate(_menu.start_entry())
	return text_template.replace(LABEL_KEY, start.caption)


## The callout's card: the line, YOUR MOVE 1/26 on the mustard band, CLICK THE RING.
func spec() -> TipSpec:
	var made: TipSpec = TipSpec.make(TipSpec.Kind.WORD, HEADER, line())
	made.tag = "1/%d" % STEP_COUNT
	made.band = Palette.MUSTARD
	made.band_ink = Palette.INK
	made.click = CLICK_TARGET
	return made


## The ring's rect and the callout's (global canvas px).
func ring_rect() -> Rect2:
	return _ring.get_global_rect()


func card() -> TipCard:
	return _card


func click_tab() -> Label:
	return _tab


func _process(delta: float) -> void:
	_follow()
	if not visible or still:
		return
	_clock = fmod(_clock + delta, PULSE_S)
	_ring.queue_redraw()


## Shows the ring and the callout on the plate as it is now, or hides them.
func _follow() -> void:
	var target: Rect2 = _menu.anchor_rect(TutorialAnchors.TITLE_PRIMARY)
	var held: bool = blocked.is_valid() and bool(blocked.call())
	visible = _active and not held and target.has_area()
	if not visible:
		return
	var to_local: Transform2D = get_global_transform().affine_inverse()
	var ring: Rect2 = (to_local * target).grow(RING_PAD)
	_ring.position = ring.position
	_ring.size = ring.size
	var words: Vector2 = UiKit.pixel_text_size(_tab)
	_tab.position = Vector2(ring.size.x - words.x - TAB_PAD.x - INK, -words.y - TAB_PAD.y - INK)
	var screen: Rect2 = to_local * get_viewport_rect()
	var placed: Array = TipCard.place(ring, ring, TipCard.Opens.RIGHT, _card.size, screen)
	var box: Rect2 = placed[0]
	_card.position = box.position
	_card.point_tail(placed[1] as TipCard.Opens, ring)


## The ring's band now: gold, stepping to mustard pale and back each PULSE_S (gold when still).
func _band_colour() -> Color:
	if still:
		return Palette.GOLD
	var phase: float = _clock / PULSE_S
	var stepped: float = floorf(phase * PULSE_STEPS) / PULSE_STEPS
	var share: float = 1.0 - absf(stepped * 2.0 - 1.0)
	return Palette.GOLD.lerp(Palette.MUSTARD_PALE, share)


## An ink line, the gold band, an ink line, from the ring's rect inwards; the CLICK tab's gold
## chip in an ink line.
func _draw_ring() -> void:
	var rect: Rect2 = Rect2(Vector2.ZERO, _ring.size)
	_frame(rect, INK, Palette.INK)
	_frame(rect.grow(-INK), BORDER, _band_colour())
	_frame(rect.grow(-INK - BORDER), INK, Palette.INK)
	var words: Vector2 = UiKit.pixel_text_size(_tab)
	var chip: Rect2 = Rect2(_tab.position - TAB_PAD, words + TAB_PAD * 2.0).grow(INK)
	_ring.draw_rect(chip, Palette.GOLD)
	_frame(chip, INK, Palette.INK)


## A `width` px frame of `colour` just inside `rect`.
func _frame(rect: Rect2, width: float, colour: Color) -> void:
	_ring.draw_rect(Rect2(rect.position, Vector2(rect.size.x, width)), colour)
	_ring.draw_rect(Rect2(rect.position.x, rect.end.y - width, rect.size.x, width), colour)
	_ring.draw_rect(Rect2(rect.position, Vector2(width, rect.size.y)), colour)
	_ring.draw_rect(Rect2(rect.end.x - width, rect.position.y, width, rect.size.y), colour)
