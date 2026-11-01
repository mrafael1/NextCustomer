class_name ProfilePins
extends RefCounted
## The badge pins a profile owns and wears (#122, full build plan 7.4), kept on the profile
## (ProfileState.unlocked_pins, worn_pins, pins_bought): wearing, taking off and the random
## purchase for coins.


## The worn pins that the catalogue holds and the profile owns, in slot order (an unknown or
## no longer owned id is skipped).
static func worn(profile: ProfileState, catalogue: CatalogueDefinition) -> Array[PinDefinition]:
	var found: Array[PinDefinition] = []
	for id: StringName in profile.worn_pins:
		for pin: PinDefinition in catalogue.pins:
			if pin.id == id and profile.has_pin(pin):
				found.append(pin)
	return found


## Wears an owned pin in one of `slots` badge slots; with every slot taken, it takes the first
## slot's place (one slot: the pins swap). False, changing nothing, for a pin not owned, already
## worn, or no slot at all.
static func wear(profile: ProfileState, pin: PinDefinition, slots: int) -> bool:
	if slots <= 0 or not profile.has_pin(pin) or profile.worn_pins.has(pin.id):
		return false
	while profile.worn_pins.size() >= slots:
		profile.worn_pins.remove_at(0)
	profile.worn_pins.append(pin.id)
	return true


## Takes a worn pin off the badge. False when it wasn't worn.
static func take_off(profile: ProfileState, pin: PinDefinition) -> bool:
	if not profile.worn_pins.has(pin.id):
		return false
	profile.worn_pins.erase(pin.id)
	return true


## The catalogue's pins not owned yet, in data order.
static func locked(profile: ProfileState, catalogue: CatalogueDefinition) -> Array[PinDefinition]:
	var found: Array[PinDefinition] = []
	for pin: PinDefinition in catalogue.pins:
		if not profile.has_pin(pin):
			found.append(pin)
	return found


## Whether a random pin can be bought: `price` coins (more than 0) and a pin still locked.
static func can_buy(profile: ProfileState, catalogue: CatalogueDefinition, price: int) -> bool:
	return price > 0 and profile.coins >= price and not locked(profile, catalogue).is_empty()


## Buys one locked pin at random (#122: the way past a milestone out of reach) with `rng`, the
## caller's stream for this purchase (ProfileState.PIN_STREAM with pins_bought): spends `price`
## coins, unlocks the pin and counts the purchase. Null, with nothing changed, when can_buy is
## false.
static func buy_random(
	profile: ProfileState, catalogue: CatalogueDefinition, price: int, rng: RandomNumberGenerator
) -> PinDefinition:
	if not can_buy(profile, catalogue, price):
		return null
	var choices: Array[PinDefinition] = locked(profile, catalogue)
	var pin: PinDefinition = choices[rng.randi_range(0, choices.size() - 1)]
	profile.coins -= price
	profile.unlocked_pins.append(pin.id)
	profile.pins_bought += 1
	return pin
