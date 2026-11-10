class_name CapturePrices
extends RefCounted
## The screen capture's ticket prices (price leak, 2026-11-10), to review big prices on the belt:
## `--prices=<entry>,...` gives the belt's tickets, in slot order, a pay the fixed shift never
## reaches. An entry is `<state>:<amount>[+<family>]`, or `-` to leave a slot as it is. The state
## is `p` (printed ink), `b1`, `b2` or `b3` (boosted, at that ink step) or `l` (lowered), with a
## `d` after it for an item dimmed as while another is hovered (the mix grey and the faded pay);
## `+<family>` first gives the ticket that gained family (a third icon narrows its window). A
## coupon's slot keeps its scissors. E.g. `--prices=b2:87,b3:1250,p:9999,b1:250+Household`. The
## file name gets prices_<name>_, the name from `--prices-name=<name>` (default "set").

const ARGUMENT := "--prices="
const NAME_ARGUMENT := "--prices-name="
const SKIP := "-"
const DIM_MARK := "d"
const STATES: Dictionary[String, PriceWindow.State] = {
	"p": PriceWindow.State.PRINTED,
	"b1": PriceWindow.State.BOOSTED,
	"b2": PriceWindow.State.BOOSTED,
	"b3": PriceWindow.State.BOOSTED,
	"l": PriceWindow.State.LOWERED,
}
const TUNING := "res://data/balance/planning.tres"


## Applies `arguments`' --prices on `screen`'s belt; returns the file name's part ("" for none).
static func apply(screen: ShiftScreen, arguments: PackedStringArray) -> String:
	var spec: String = ""
	var shown_name: String = "set"
	for argument: String in arguments:
		if argument.begins_with(ARGUMENT):
			spec = argument.trim_prefix(ARGUMENT)
		elif argument.begins_with(NAME_ARGUMENT):
			shown_name = argument.trim_prefix(NAME_ARGUMENT)
	if spec.is_empty():
		return ""
	var tuning: PlanningTuning = load(TUNING) as PlanningTuning
	var entries: PackedStringArray = spec.split(",")
	var slot: int = 0
	for view: CardView in screen._row_views:
		var item: ItemView = view as ItemView
		if item == null or slot >= entries.size():
			break
		if entries[slot] != SKIP:
			_show(item, entries[slot], tuning)
		slot += 1
	return "prices_%s_" % shown_name


## Shows `entry` on `item`'s ticket.
static func _show(item: ItemView, entry: String, tuning: PlanningTuning) -> void:
	var parts: PackedStringArray = entry.split(":")
	if parts.size() < 2:
		return
	var state_key: String = parts[0]
	var dimmed: bool = state_key.ends_with(DIM_MARK)
	if dimmed:
		state_key = state_key.trim_suffix(DIM_MARK)
	var price: PackedStringArray = parts[1].split("+")
	var amount: int = price[0].to_int()
	var sticker: PriceSticker = item.sticker()
	if price.size() > 1:
		sticker.show_gained(price[1])
	if dimmed:
		item.relation_fade = 0.0
		item.dim_greyness = Vector2(tuning.mix_brightness, tuning.mix_saturation)
		item.relation = ItemView.Relation.DIM
	var window: PriceWindow = sticker.window()
	if not item.card.definition.is_coupon():
		var state: PriceWindow.State = STATES.get(state_key, PriceWindow.State.PRINTED)
		window.show_pay(state, amount, _base_for(state_key, amount))
	if dimmed:
		window.dimmed_alpha = tuning.dim_ticket_alpha
		window.set_dimmed(true)


## The base that puts a boosted `amount` at `state_key`'s ink step (PriceWindow.boost_step).
static func _base_for(state_key: String, amount: int) -> int:
	var ratios: PackedInt32Array = PriceWindow.ink_ratios()
	match state_key:
		"b2":
			return maxi(floori(float(amount) / ratios[0]), 1)
		"b3":
			return maxi(floori(float(amount) / ratios[1]), 1)
	return amount
