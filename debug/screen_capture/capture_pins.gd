class_name CapturePins
extends RefCounted
## The screen capture's badge pin options (#122, #132), kept out of ScreenCapture so it stays
## under gdlint's file length.
##
## `--double` (#122): the fixed shift wears the Double checkout pin (two rows of 4); the file gets
## double_. `--pin=<pin id>` (#132) wears that pin on the fixed shift (Price gun's relabels the
## belt's first product as Snack); the file gets pin_<id>_. With --pin=price_gun,
## `--gun=<planning|armed|picker|retag>` leaves the belt untagged and shows the labeller lying
## there, picked up, or picked up with the family picker open on the belt's first product (retag:
## that product tagged Snack first, so the picker offers Remove tag); the file gets gun_<state>_.
## `--pin=<id>+<id>` wears two pins. `--pin-card=<n>` keeps worn pin n's card open on the name
## badge's lanyard (PinLanyard, from 0), as a click does; the file gets card<n>_.

const DOUBLE_ARGUMENT := "--double"
const PIN_ARGUMENT := "--pin="
const GUN_ARGUMENT := "--gun="
const CARD_ARGUMENT := "--pin-card="


## Wears the pins the options name on `run` (before its shift is set up).
static func wear(run: RunState) -> void:
	if OS.get_cmdline_user_args().has(DOUBLE_ARGUMENT):
		RunPins.wear(run, [load("res://data/pins/double_checkout.tres") as PinDefinition])
	if not _argument(PIN_ARGUMENT).is_empty():
		var worn: Array[PinDefinition] = []
		for id: String in _pin_ids():
			worn.append(load("res://data/pins/%s.tres" % id) as PinDefinition)
		RunPins.wear(run, worn)


## Whether a worn pin is Day off: a day off is never taken on an inspection day.
static func day_off() -> bool:
	return _pin_ids().has("day_off")


## Price gun's relabel of the row's first card, once the row is placed (before the shift shows).
static func relabel(run: RunState) -> void:
	var gun: String = _argument(GUN_ARGUMENT)
	if _pin_ids().has("price_gun") and (gun.is_empty() or gun == "retag"):
		PinPlay.relabel(run, run.row[0], "Snack")


## The labeller's state on the shown shift: picked up, and the picker open on the row's first
## product, and the kept pin card (--pin-card). `pins` is the shift screen's pin controls.
static func arm_gun(run: RunState, pins: PinFlow) -> void:
	if not _argument(CARD_ARGUMENT).is_empty():
		pins._screen._stage.pin_lanyard.press_pin(int(_argument(CARD_ARGUMENT)))
	var gun: String = _argument(GUN_ARGUMENT)
	if gun in ["armed", "picker", "retag"]:
		pins.press_gun()
	if gun == "picker" or gun == "retag":
		for card: CardInstance in run.row:
			if card.definition.is_product():
				pins.take_click(card)
				break


## The file name's part for the options.
static func file_part() -> String:
	return (
		("double_" if OS.get_cmdline_user_args().has(DOUBLE_ARGUMENT) else "")
		+ ("" if _argument(PIN_ARGUMENT).is_empty() else "pin_%s_" % _argument(PIN_ARGUMENT))
		+ ("" if _argument(GUN_ARGUMENT).is_empty() else "gun_%s_" % _argument(GUN_ARGUMENT))
		+ ("" if _argument(CARD_ARGUMENT).is_empty() else "card%s_" % _argument(CARD_ARGUMENT))
	)


static func _pin_ids() -> PackedStringArray:
	return _argument(PIN_ARGUMENT).split("+", false)


static func _argument(prefix: String) -> String:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with(prefix):
			return argument.trim_prefix(prefix)
	return ""
