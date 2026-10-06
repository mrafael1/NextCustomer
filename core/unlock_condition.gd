class_name UnlockCondition
extends Resource
## What unlocks a deck or a card variant (full build plan section 7.3), as data. Checked when a
## run ends by UnlockCheck. A deck or variant without a condition is available from the start.
##
## Every exported value defaults to a neutral value, because Godot doesn't write a value that
## equals the default into a .tres file. That is why `kind` starts at UNSET: every condition
## must state its kind, and a test rejects UNSET.

## WIN_WITH_CARD: win a run whose final deck holds `card`. SCORE_IN_ONE_CHECKOUT: score at least
## `amount` in one checkout. USE_COUPON_TIMES: check out the coupon `card` `amount` times in
## all (every copy in a checked-out row counts once).
enum Kind { UNSET, WIN_WITH_CARD, SCORE_IN_ONE_CHECKOUT, USE_COUPON_TIMES }

@export var kind: Kind = Kind.UNSET
## WIN_WITH_CARD: the card; USE_COUPON_TIMES: the coupon.
@export var card: CardDefinition
## SCORE_IN_ONE_CHECKOUT: the checkout total; USE_COUPON_TIMES: how many uses.
@export var amount: int = 0


## The condition as the player reads it, e.g. "Score €40 in one checkout".
func summary() -> String:
	match kind:
		Kind.WIN_WITH_CARD:
			return "Win a run with %s in your deck" % _card_name()
		Kind.SCORE_IN_ONE_CHECKOUT:
			return "Score €%d in one checkout" % amount
		Kind.USE_COUPON_TIMES:
			return "Use %s %d times" % [_card_name(), amount]
	return ""


## Why this condition can't work as data, or an empty list (checked by a data test).
func problems() -> PackedStringArray:
	var found: PackedStringArray = PackedStringArray()
	match kind:
		Kind.UNSET:
			found.append("kind is UNSET")
		Kind.WIN_WITH_CARD:
			if card == null:
				found.append("WIN_WITH_CARD needs a card")
		Kind.SCORE_IN_ONE_CHECKOUT:
			if amount <= 0:
				found.append("SCORE_IN_ONE_CHECKOUT needs an amount above 0")
		Kind.USE_COUPON_TIMES:
			if card == null or not card.is_coupon():
				found.append("USE_COUPON_TIMES needs a coupon")
			if amount <= 0:
				found.append("USE_COUPON_TIMES needs an amount above 0")
	return found


func _card_name() -> String:
	return card.display_name if card != null else "?"
