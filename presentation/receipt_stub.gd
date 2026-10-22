class_name ReceiptStub
extends Control
## The receipt's gold BONUS stub line (#77 machine v2, Q2 = 2): a line of the receipt
## (ReceiptStamps.add_bonus_stub), under INSPECTION PASSED and above the tear, holding a
## BonusTicket in its STUB form that runs across the paper inside its frame (past the lines'
## inset). Its height is the stub's: the dessert prints it from 0 to BonusTicket.SIZE.y (grow),
## and at the machine it snaps off, shrinking to 0 while the receipt keeps its body where it is
## (snap: ReceiptView.fit_height leaves the receipt's top where the whole stub put it). The ticket
## shows its top part while the line is shorter, and hides once the stub has snapped.

## How far the ticket runs past the line on each side (the lines' inset in the receipt).
var reach_left: float = ReceiptView.FRAME_OUT
var reach_right: float = ReceiptView.FRAME_PAD
var ticket: BonusTicket
var _full: float = 0.0
var _now: float = 0.0
var _snapping: bool = false


func _init(sub: String) -> void:
	name = "BonusStub"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	ticket = BonusTicket.new(BonusTicket.Form.STUB, sub)
	add_child(ticket)
	resized.connect(_fit_ticket)
	grow(0.0)


## The stub printing: `height` px of it shown (its whole height so far).
func grow(height: float) -> void:
	_snapping = false
	_full = height
	_now = height
	_apply()


## The stub snapping off: `height` px of it left (the whole stub still counts for the receipt's
## height cap, so its body never moves).
func snap(height: float) -> void:
	_snapping = true
	_now = minf(height, _full)
	_apply()


## The stub's height now (shown).
func shown_height() -> float:
	return _now


## The stub's height before it snapped (its whole height while printing).
func full_height() -> float:
	return _full


## How much of it has snapped off (0 while printing).
func lost() -> float:
	return _full - _now


## The whole stub's rect on its line (local: its top-left at the paper's inner edge), as it
## stood before it snapped.
func stub_rect() -> Rect2:
	return Rect2(Vector2(-reach_left, 0.0), Vector2(size.x + reach_left + reach_right, _full))


func _apply() -> void:
	custom_minimum_size = Vector2(0.0, _now)
	ticket.visible = _now > 0.0 and not _snapping
	_fit_ticket()


func _fit_ticket() -> void:
	ticket.position = Vector2(-reach_left, 0.0)
	ticket.size = Vector2(size.x + reach_left + reach_right, _now)
