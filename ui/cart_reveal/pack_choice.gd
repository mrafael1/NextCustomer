class_name PackChoice
extends Control
## The start screen's starter packs (#107, mock-up starter_choice_107.html layout A, v0.63;
## redrawn for the clock-in board, mock-up start_screen.html layout A, part 1, 2026-11-03): "1 PICK
## A STARTER PACK" and the offer's three packs (PackFace) in a row. A click picks a pack (raise:
## another click changes it), 1 to 3 pick; hovering a pack (set_pointer) previews it in the cart
## sheet but never changes the pick. The good first pick is picked from the start. The board's
## OPEN STORE key confirms. It sits at the board's content origin and draws in stage coordinates.
## Pure display: CartReveal routes the pointer and keys and asks it where things are.

const NUMBER_CHIP := Rect2(26, 80, 22, 22)
const HEADING_RECT := Rect2(58, 80, 260, 22)
const SUB_POSITION := Vector2(322, 82)
const HEADING_TEXT := "PICK A STARTER PACK"
const SUB_TEXT := "3 cards that start your build. Hover to preview, click to pick."
const SUB_SIZE := 13
const FACES_TOP := 124.0
const FACE_GAP := 16.0
## The span the faces are centred on (the cart sheet's x and width).
const SPAN_LEFT := 44.0
const SPAN_WIDTH := 780.0

var offer: StartOffer
var faces: Array[PackFace] = []
## The picked pack's index, or -1, and the hovered one, or -1.
var raised_index: int = -1
var hovered_index: int = -1
var _heading: Control
var _sub: Label


func _init(start_offer: StartOffer) -> void:
	offer = start_offer
	name = "PackChoice"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_heading = Control.new()
	_heading.name = "Heading"
	_heading.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_heading)
	var chip: RevealChip = RevealChip.new(
		Palette.MUSTARD, NUMBER_CHIP.size, null, "1", 15, Palette.INK
	)
	chip.position = NUMBER_CHIP.position
	_heading.add_child(chip)
	var title: Label = UiKit.pixel_label(HEADING_TEXT, 2, Palette.MUSTARD_LIGHT)
	_heading.add_child(title)
	UiKit.place_pixel_label(title, HEADING_RECT, true)
	_sub = UiKit.body_label(SUB_TEXT, SUB_SIZE, Palette.TEAL_PALE)
	_sub.add_theme_font_override("font", CartReveal.font(700))
	_sub.position = SUB_POSITION
	_heading.add_child(_sub)
	var count: int = offer.packs.size()
	var width: float = count * PackFace.SIZE.x + maxf(count - 1, 0) * FACE_GAP
	var left: float = SPAN_LEFT + (SPAN_WIDTH - width) / 2.0
	for index: int in count:
		var pack: StarterPackDefinition = offer.packs[index]
		var face: PackFace = PackFace.new(pack, pack == offer.first_pick, index + 1)
		face.position = Vector2(
			CartReveal.snap(left + index * (PackFace.SIZE.x + FACE_GAP)), FACES_TOP
		)
		add_child(face)
		faces.append(face)
	if offer.first_pick != null:
		raise(offer.packs.find(offer.first_pick))


## Picks pack `index` (unpicking the one before); out of range: none.
func raise(index: int) -> void:
	raised_index = index if index >= 0 and index < faces.size() else -1
	for at: int in faces.size():
		faces[at].set_raised(at == raised_index)


## The picked pack, or null.
func raised_pack() -> StarterPackDefinition:
	return faces[raised_index].pack if raised_index >= 0 else null


## The pack the cart sheet shows: the hovered one, else the picked one (null: none).
func shown_pack() -> StarterPackDefinition:
	if hovered_index >= 0:
		return faces[hovered_index].pack
	return raised_pack()


## The pack face under `point` (global), as an index, or -1.
func face_at(point: Vector2) -> int:
	for index: int in faces.size():
		if faces[index].visible and faces[index].get_global_rect().has_point(point):
			return index
	return -1


## The tiles of every pack's cards (their popups open on hover).
func tiles() -> Array[CartTicket]:
	var found: Array[CartTicket] = []
	for face: PackFace in faces:
		found.append_array(face.tiles)
	return found


## Lights the face at `index` (-1: none) under the pointer. Returns whether the hover changed.
func set_pointer(index: int) -> bool:
	if index == hovered_index:
		return false
	hovered_index = index
	for at: int in faces.size():
		faces[at].set_hovered(at == index)
	return true


## When the faces have all dropped in (the choice waits from then).
static func ready_time(timing: CartRevealTuning, count: int) -> float:
	return timing.pack_start_s + timing.pack_gap_s * maxf(count - 1, 0) + timing.pack_drop_s


## Poses the choice at `t` on the reveal's timeline: the heading and each face drop in, one after
## another (a picked face sits pack_raise_px higher).
func show_at(t: float, timing: CartRevealTuning) -> void:
	var head: float = clampf((t - timing.pack_start_s) / maxf(timing.pack_drop_s, 0.001), 0.0, 1.0)
	_heading.modulate.a = head
	for index: int in faces.size():
		var start: float = timing.pack_start_s + timing.pack_gap_s * index
		var q: float = clampf((t - start) / maxf(timing.pack_drop_s, 0.001), 0.0, 1.0)
		var face: PackFace = faces[index]
		face.modulate.a = q
		var lift: float = timing.pack_raise_px if face.raised else 0.0
		var drop: float = (1.0 - CartReveal.ease_out_back(q)) * timing.pack_drop_px
		face.position.y = CartReveal.snap(FACES_TOP - drop - lift)
