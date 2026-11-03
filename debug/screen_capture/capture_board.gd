class_name CaptureBoard
extends RefCounted
## The screen capture's --reveal options for the start screen's board (#107, 2026-11-03), kept out
## of ScreenCapture so it stays under gdlint's file length. On the board (a new run waiting for its
## pick):
## - `hover=pack<n>`: the pointer rests on pack n (from 0): the cart previews it;
## - `hover=<n>`: the scan popup of the cart's ticket n (from 0: the staples, the pack, today's
##   deal, the pins' cards);
## - `stock=<n>`: the popup of today's deal's ticket n;
## - `aisle=<id>`: the pointer rests on that shelf's row (staples or an aisle id): its dealt
##   tickets light.
## Each adds its option to the file name (hoverpack<n>_, hover<n>_, stock<n>_, aisle_<id>_).


## Applies `options` to the board of `reveal`; returns the file name's part for them.
static func apply(reveal: CartReveal, options: PackedStringArray) -> String:
	var board: StartBoard = reveal.board
	var part: String = ""
	if board == null:
		return part
	for option: String in options:
		var value: String = option.get_slice("=", 1)
		if option.begins_with("hover=pack"):
			var face: PackFace = board.choice.faces[value.trim_prefix("pack").to_int()]
			board.set_pointer(face.get_global_rect().get_center())
			part += "hover%s_" % value
		elif option.begins_with("hover="):
			reveal.show_popup(_with_cards(board.sheet.tickets())[value.to_int()])
			part += "hover%s_" % value
		elif option.begins_with("stock="):
			reveal.show_popup(board.sheet.deal_tickets[value.to_int()])
			part += "stock%s_" % value
		elif option.begins_with("aisle="):
			var row: int = board.shelves.shelf_ids.find(StringName(value))
			var rect: Rect2 = board.shelves.row_rect(maxi(row, 0))
			board.set_pointer(board.shelves.get_global_transform() * rect.get_center())
			part += "aisle_%s_" % value
	board.advance(10.0)  # Past the tickets' pop-in.
	return part


static func _with_cards(tickets: Array[CartTicket]) -> Array[CartTicket]:
	var found: Array[CartTicket] = []
	for ticket: CartTicket in tickets:
		if not ticket.is_empty():
			found.append(ticket)
	return found
