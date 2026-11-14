class_name BuildPins
extends RefCounted
## YOUR BUILD's BADGE PINS step (BuildPage, v1.32; mock-up start_boosters_v3 F5): the owned pins,
## the step's open and close, the choice (one slot: another pin swaps the worn one, as
## ProfilePins.wear) and its confirm, saved through StartBoardActions.wear_pins; the first confirm
## deals the packs, a later one keeps them. The step's state lives on the page (pins_open,
## pins_t, pins_sel, pins_tick, fly_t, fly_pin), which PinStepDraw draws.

var page: BuildPage


func _init(owner_page: BuildPage) -> void:
	page = owner_page


## The pin catalogue in data order (empty without the board's actions).
func catalogue() -> Array[PinDefinition]:
	var found: Array[PinDefinition] = []
	if page.actions != null and page.actions.pin_catalogue.is_valid():
		found = page.actions.pin_catalogue.call()
	return found


## The catalogue's pins the profile owns, in data order.
func owned() -> Array[PinDefinition]:
	var found: Array[PinDefinition] = []
	if page.profile == null:
		return found
	for pin: PinDefinition in catalogue():
		if page.profile.has_pin(pin):
			found.append(pin)
	return found


## How many owned pins hold the packs for the step, asked through the board actions (StartChoice:
## ProfilePins.start_gate, the one copy of the rule: earned, bought or worn; the pins every
## profile starts with don't). 0 without the actions.
func gate_count() -> int:
	if page.actions == null or not page.actions.pins_gate.is_valid():
		return 0
	return page.actions.pins_gate.call()


## Pin `pin`'s place in the catalogue (its colour goes by it).
func index_of(pin: PinDefinition) -> int:
	return maxi(0, catalogue().find(pin))


## Opens the step at `at` (the corkboard, P, the held packs); with no pin owned, says how to earn
## one.
func open(at: float) -> bool:
	if page.flight != null or page.run == null or page.pins_open:
		return false
	if owned().is_empty():
		page.flash("FINISH A RUN TO EARN A PIN")
		return false
	page.pins_open = true
	page.pins_t = at
	page.pins_sel = page.run.pins.duplicate()
	page.cue(at, page.sfx.bind("ui_open", -6.0))
	return true


## Esc on the step: it closes without changes (the packs stay held while not confirmed).
func close() -> bool:
	if not page.pins_open:
		return false
	page.pins_open = false
	page.pins_sel = page.run.pins.duplicate()
	page.sfx("ui_close", -8.0)
	page.set_hint(BuildPageDraw.PINS_FIRST_HINT if page.packs_held() else "")
	return true


## Wears or takes off owned pin `pin` in the step.
func toggle(pin: PinDefinition) -> void:
	if not page.pins_open:
		return
	if page.pins_sel.has(pin):
		page.pins_sel.erase(pin)
		page.sfx("card_return_1", -8.0)
	else:
		while page.pins_sel.size() >= maxi(1, page.run.balance.pin_slots):
			page.pins_sel.remove_at(0)
		page.pins_sel.append(pin)
		page.sfx("stamp_1", -6.0)
		page.sfx("tag", -8.0)
	page.pins_tick = {"pin": pin, "t": page.now}


## Number key `number` in the step: the owned pin in that row.
func toggle_at(number: int) -> bool:
	var list: Array[PinDefinition] = owned()
	if number < 0 or number >= list.size():
		return false
	toggle(list[number])
	return true


## WEAR n PINS / NO PINS: saves the choice; the first confirm deals the packs.
func confirm(_via: String = "click") -> bool:
	if not page.pins_open or page.now - page.pins_t < 0.15:
		return false
	var first: bool = page.packs_held()
	var ids: Array[StringName] = []
	for pin: PinDefinition in page.pins_sel:
		ids.append(pin.id)
	if not page.actions.wear_pins.call(ids):
		page.flash("COULD NOT SAVE YOUR PINS")
		return false
	var run: RunState = page.run
	page.pins_open = false
	page.fly_pin = run.pins[0] if not run.pins.is_empty() else null
	page.fly_t = page.now if page.fly_pin != null else -INF
	page.sfx("stamp_loyalty" if page.fly_pin != null else "ui_click_1", -4.0)
	if page.fly_pin != null and not page.rm:
		page.cue(page.now + page.tuning.pin_fly_s, _landed)
	if first:
		var t0: float = page.now + (0.0 if page.rm else page.tuning.pins_deal_s)
		page.deal_packs(t0)
		if not page.rm:
			page.cue(t0, page.sfx.bind("shuffle", -6.0))
	else:
		page.set_hint("" if page.picked() >= 0 else "HOVER A PACK, CLICK TO PICK")
	page.show_build(run, page.profile, page.actions)
	return true


func _landed() -> void:
	page.sfx("card_place_2", -4.0)
	var cork: Vector2i = BuildPage.CORK_PIN
	BuildPageDraw.add_sparkles(page, cork.x - 4, cork.y - 4, 24, 24, page.now, 0.05)
