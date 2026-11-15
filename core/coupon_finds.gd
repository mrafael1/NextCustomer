class_name CouponFinds
extends RefCounted
## The coupons a profile has found, for the handbook's COUPONS tab (play test feedback,
## 2026-11-15: a coupon not found yet shows as a locked row). A coupon is found once it is owned:
## in a run's cart (picked at the machine, dealt by a starter pack or a booster). Kept as
## "own:<card id>" flags in ProfileState.seen, so the profile's format is unchanged (RESET TIPS
## never clears them); a coupon used in an ended run (ProfileState.coupon_uses) counts too, so a
## profile from before the flags finds what it played. The shift screen notes the cart at its
## save points from the first checkout on (a run just started writes no profile); the handbook
## in a run counts the cart under way too (owns). Pure and static: the caller saves the profile
## after a change.

const PREFIX := "own:"


## The flag of coupon `card_id` ("own:<card id>").
static func flag(card_id: StringName) -> StringName:
	return StringName(PREFIX + String(card_id))


## Whether coupon `card_id` was found: owned in a run, or used in an ended one.
static func found(profile: ProfileState, card_id: StringName) -> bool:
	return profile.seen.has(flag(card_id)) or profile.coupon_uses.has(card_id)


## Whether `cards` (a run's cart) hold coupon `card_id`: the run under way finds it before its
## next save point notes it.
static func owns(cards: Array[CardInstance], card_id: StringName) -> bool:
	for card: CardInstance in cards:
		if card.definition != null and card.definition.id == card_id:
			return true
	return false


## Marks the coupons among `cards` (a run's cart) found. Returns whether the profile changed.
static func note(profile: ProfileState, cards: Array[CardInstance]) -> bool:
	var changed: bool = false
	for card: CardInstance in cards:
		if card.definition == null or not card.definition.is_coupon():
			continue
		var id: StringName = flag(card.definition.id)
		if not profile.seen.has(id):
			profile.seen.append(id)
			changed = true
	return changed
