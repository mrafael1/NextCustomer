class_name PackChoice
extends Control
## The cart reveal's starter pack choice (#107, mock-up starter_choice_107.html layout A, v0.63):
## PICK A STARTER PACK, the offer's three packs (PackFace) where TODAY'S PICKS will be, and the
## confirm bar under them. A click raises a pack (another click changes it); the bar (or Enter)
## takes the raised one; 1 to 3 raise. The good first pick is raised from the start. It sits at
## the reveal's content origin and draws in stage coordinates. Pure display: CartReveal routes the
## pointer and keys and asks it where things are.

const HEADING_POSITION := Vector2(158, 350)
const SUB_POSITION := Vector2(158, 378)
const HEADING_TEXT := "PICK A STARTER PACK"
const SUB_TEXT := (
	"Click a pack to raise it, then confirm. " + "Hover a pack, or today’s stock, to read it."
)
const FACES_TOP := 410.0
const FACE_GAP := 22.0
## The panel's span the faces are centred on (RevealPanel.RECT's x and width).
const SPAN_LEFT := 96.0
const SPAN_WIDTH := 1088.0
const BAR_RECT := Rect2(352, 622, 576, 44)
const BAR_SIZE := 18
const BAR_IDLE_TEXT := "RAISE A PACK, THEN CONFIRM"
const BAR_TAKE_TEXT := "TAKE %s ›"

var offer: StartOffer
var faces: Array[PackFace] = []
## The raised pack's index, or -1.
var raised_index: int = -1
var bar_hovered: bool = false
var _heading: Label
var _sub: Label
var _bar: Control
var _bar_text: Label


func _init(start_offer: StartOffer) -> void:
	offer = start_offer
	name = "PackChoice"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_heading = UiKit.body_label(HEADING_TEXT, RevealPanel.HEADING_SIZE, Palette.MUSTARD_LIGHT)
	_heading.add_theme_font_override("font", CartReveal.spaced_font(800, 1))
	_heading.position = HEADING_POSITION
	add_child(_heading)
	_sub = UiKit.body_label(SUB_TEXT, RevealPanel.SUB_SIZE, Palette.TEAL_PALE)
	_sub.position = SUB_POSITION
	add_child(_sub)
	var count: int = offer.packs.size()
	var width: float = count * PackFace.SIZE.x + maxf(count - 1, 0) * FACE_GAP
	var left: float = SPAN_LEFT + (SPAN_WIDTH - width) / 2.0
	for index: int in count:
		var pack: StarterPackDefinition = offer.packs[index]
		var face: PackFace = PackFace.new(pack, pack == offer.first_pick)
		face.position = Vector2(
			CartReveal.snap(left + index * (PackFace.SIZE.x + FACE_GAP)), FACES_TOP
		)
		add_child(face)
		faces.append(face)
	_bar = Control.new()
	_bar.name = "ConfirmBar"
	_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_bar.position = BAR_RECT.position
	_bar.size = BAR_RECT.size
	_bar.draw.connect(_draw_bar)
	add_child(_bar)
	_bar_text = UiKit.body_label("", BAR_SIZE, Palette.INK)
	_bar_text.add_theme_font_override("font", CartReveal.spaced_font(800, 1))
	_bar_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_bar_text.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_bar_text.size = BAR_RECT.size
	_bar.add_child(_bar_text)
	if offer.first_pick != null:
		raise(offer.packs.find(offer.first_pick))
	_refresh_bar()


## Raises pack `index` (lowering the one raised before); out of range: none.
func raise(index: int) -> void:
	raised_index = index if index >= 0 and index < faces.size() else -1
	for at: int in faces.size():
		faces[at].set_raised(at == raised_index)
	_refresh_bar()


## The raised pack, or null.
func raised_pack() -> StarterPackDefinition:
	return faces[raised_index].pack if raised_index >= 0 else null


## The pack face under `point` (global), as an index, or -1.
func face_at(point: Vector2) -> int:
	for index: int in faces.size():
		if faces[index].visible and faces[index].get_global_rect().has_point(point):
			return index
	return -1


## Whether `point` (global) is on the confirm bar.
func bar_has(point: Vector2) -> bool:
	return _bar.get_global_rect().has_point(point)


## The tiles of every pack's cards (their popups open on hover).
func tiles() -> Array[RevealTile]:
	var found: Array[RevealTile] = []
	for face: PackFace in faces:
		found.append_array(face.tiles)
	return found


## Lights the face at `index` (-1: none) and the bar (`on_bar`) under the pointer.
func set_pointer(index: int, on_bar: bool) -> void:
	for at: int in faces.size():
		faces[at].set_hovered(at == index)
	if on_bar != bar_hovered:
		bar_hovered = on_bar
		_bar.queue_redraw()


## The confirm bar's text (for tests).
func bar_text() -> String:
	return _bar_text.text


## When the faces have all dropped in (the choice waits from then).
static func ready_time(timing: CartRevealTuning, count: int) -> float:
	return timing.pack_start_s + timing.pack_gap_s * maxf(count - 1, 0) + timing.pack_drop_s


## Poses the choice at `t` on the reveal's timeline: the heading and each face drop in, one after
## another (a raised face sits pack_raise_px higher).
func show_at(t: float, timing: CartRevealTuning) -> void:
	var head: float = clampf((t - timing.pack_start_s) / maxf(timing.pack_drop_s, 0.001), 0.0, 1.0)
	_heading.modulate.a = head
	_sub.modulate.a = head
	for index: int in faces.size():
		var start: float = timing.pack_start_s + timing.pack_gap_s * index
		var q: float = clampf((t - start) / maxf(timing.pack_drop_s, 0.001), 0.0, 1.0)
		var face: PackFace = faces[index]
		face.modulate.a = q
		var lift: float = timing.pack_raise_px if face.raised else 0.0
		var drop: float = (1.0 - CartReveal.ease_out_back(q)) * timing.pack_drop_px
		face.position.y = CartReveal.snap(FACES_TOP - drop - lift)
	var ready_at: float = ready_time(timing, faces.size())
	_bar.modulate.a = clampf((t - ready_at + timing.pack_drop_s) / timing.pack_drop_s, 0.0, 1.0)


func _refresh_bar() -> void:
	var pack: StarterPackDefinition = raised_pack()
	_bar_text.text = BAR_IDLE_TEXT if pack == null else BAR_TAKE_TEXT % pack.display_name.to_upper()
	_bar_text.add_theme_color_override(
		"font_color", Palette.INK if pack != null else Palette.GREY_DARK
	)
	_bar.queue_redraw()


## The push bar: grey while no pack is raised, gold (lighter under the pointer) once one is.
func _draw_bar() -> void:
	var rect: Rect2 = Rect2(Vector2.ZERO, BAR_RECT.size)
	var live: bool = raised_index >= 0
	var face: Color = Palette.GREY_LIGHT
	if live:
		face = Palette.MUSTARD_LIGHT if bar_hovered else Palette.MUSTARD
	_bar.draw_rect(Rect2(rect.position + Vector2(0, 6), rect.size), Palette.INK)
	_bar.draw_rect(rect, Palette.INK)
	_bar.draw_rect(rect.grow(-3.0), face)
	var ledge: Color = Palette.MUSTARD_DARKEST if live else Palette.GREY
	_bar.draw_rect(Rect2(3, rect.size.y - 9, rect.size.x - 6, 6), ledge)
