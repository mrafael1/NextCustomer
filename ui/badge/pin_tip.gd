class_name PinTip
extends TipCard
## A worn badge pin's card on the shift screen (#122; since the hover tips revamp of 2026-11-13 the
## game's one tip, TipCard, of the PIN kind): the brass band with the pin's face (PinFace) in its
## icon box, its name and the BADGE PIN tag, its rule, the charges it has left (`charges`, e.g. "1
## relabel left this shift") as the live line (grey once none is left), and the footer's key: CLICK
## KEEP OPEN, or CLICK CLOSE once kept. PIN_WIDTH (narrower than a tip's) keeps the card between the
## receipt and the monitor's screen: it opens under its pin, centred on it as far as `area`
## (PinLanyard's room for it) lets. Display only: it takes no clicks (PinLanyard opens, keeps and
## closes it).

const PIN_WIDTH := 200.0
const FACE_SIZE := 22.0
const TAG := "BADGE PIN"
## The footer's click actions: open, then kept.
const FOOT_HINT := "KEEP OPEN"
const FOOT_KEPT := "CLOSE"
## The gap under the pin to the card's top (the tail fills it).
const PIN_GAP := 12.0

var _face: PinFace
var _charges: String = ""


func _init() -> void:
	super()
	name = "PinTip"
	width_override = PIN_WIDTH
	_face = PinFace.new(FACE_SIZE)
	_face.name = "Face"
	icon_node = _face
	# Its child from the start, so a card never shown still frees it.
	add_child(_face)


## Shows `pin` (the `index`-th of the catalogue, for its colour) with `charges` ("" for none),
## `kept` (open on a click), under its pin at `pin_rect`, inside `area` (shadow included): all in
## this card's parent's coordinates.
func show_for(
	pin: PinDefinition, index: int, charges: String, is_kept: bool, pin_rect: Rect2, area: Rect2
) -> void:
	_face.show_pin(pin, index)
	_charges = charges
	var made: TipSpec = TipSpec.make(
		TipSpec.Kind.PIN, pin.display_name, TipMarkup.auto(pin.rule_text)
	)
	made.tag = TAG
	made.click = FOOT_KEPT if is_kept else FOOT_HINT
	if not charges.is_empty():
		made.live = TipMarkup.auto(TipSpec.sentences(charges))
		made.live_kind = TipSpec.Live.OFF if charges.begins_with("0 ") else TipSpec.Live.OK
	show_spec(made)
	var middle: float = pin_rect.get_center().x
	var left: float = roundf((middle - PIN_WIDTH / 2.0) / PX) * PX
	var right_most: float = area.end.x - SHADOW.x - PIN_WIDTH
	position = Vector2(clampf(left, area.position.x, right_most), pin_rect.end.y + PIN_GAP)
	point_tail(Opens.BELOW, Rect2(pin_rect.position, pin_rect.size))


func pin_name() -> String:
	return spec.title if spec != null else ""


func rule_text() -> String:
	return body().plain_text() if body() != null else ""


## The charges shown ("" for none).
func charges_text() -> String:
	return _charges


## The footer's click action (FOOT_HINT, or FOOT_KEPT once kept).
func foot_text() -> String:
	return spec.click if spec != null else ""


func face() -> PinFace:
	return _face
