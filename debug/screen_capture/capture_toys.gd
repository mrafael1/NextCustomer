class_name CaptureToys
extends RefCounted
## The screen capture's TOY MACHINES option (#121), kept out of ScreenCapture so it stays under
## gdlint's file length.
##
## `--toys=<state>[,hover=<aisle id>]` opens the TOY MACHINES over the shift on a profile with 9
## of the 30 figurines (the mock-up's partial collection): `normal` (5 coins), `broke` (0 coins),
## `off` (the profile can't be saved) or `complete` (every figurine, 5 coins); `hover=` hovers
## that aisle's machine; `car=<seconds>` (v0.79) catches a car that passed the doors that long
## ago, `lamp` the street lamp's flicker. The file is
## shift_screen_toys_<state>_[<aisle>_][car<tenths>_][lamp_]<width>x<height>.png.

## The partial collection: the first items of each aisle owned (the mock-up's).
const OWNED: Dictionary[StringName, int] = {
	&"cold_cases": 1, &"pantry": 2, &"household": 1, &"fruit_and_veg": 3, &"bakery": 2
}


## Opens the TOY MACHINES as a child of `host` for `spec` (see above), on a fresh profile saved
## through `saves` (the capture's temporary folder); the capture file name's part.
static func open(
	host: Node, balance: BalanceDefinition, saves: SaveService, spec: String
) -> String:
	var parts: PackedStringArray = spec.split(",")
	var state: String = parts[0]
	var profile: ProfileState = ProfileState.new()
	profile.coins = 0 if state == "broke" else 5
	profile.run_count = 4
	for aisle: AisleDefinition in balance.aisles:
		var count: int = OWNED.get(aisle.id, 0)
		if state == "complete":
			count = aisle.capsule_cards.size()
		for card: CardDefinition in aisle.capsule_cards.slice(0, count):
			profile.unlocked_items[card.id] = 0
	var event_log: EventLogService = host.get_node("/root/EventLog")
	var counter: CapsuleCounter = CapsuleCounter.new(
		profile, saves, balance, event_log, false, state != "off"
	)
	var toys_screen: ToyMachinesScreen = ToyMachinesScreen.new()
	host.add_child(toys_screen)
	toys_screen.open(counter, balance)
	var part: String = "toys_%s_" % state
	toys_screen.street().set_process(false)  # The capture keeps the moment asked for.
	for option: String in parts.slice(1):
		if option.begins_with("car="):
			var seconds: float = option.trim_prefix("car=").to_float()
			toys_screen.street().pass_car(1)
			toys_screen.street()._process(seconds)
			part += "car%d_" % roundi(seconds * 10.0)
		if option == "lamp":
			toys_screen.street()._process(ToyStreet.LAMP_FRAME * (ToyStreet.LAMP_OFF[0] + 0.5))
			part += "lamp_"
		if not option.begins_with("hover="):
			continue
		var aisle_id: String = option.trim_prefix("hover=")
		for view: ToyMachineView in toys_screen.machines():
			if view.aisle().id == StringName(aisle_id):
				view._on_hover(true)
		part += aisle_id + "_"
	return part
