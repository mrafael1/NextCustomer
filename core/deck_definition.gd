class_name DeckDefinition
extends Resource
## A starting deck (full build plan section 7.3): the cards a run begins with, one entry per
## copy. Definitions are shared by reference and never changed at runtime. The staples are the
## balance data's own list (BalanceDefinition.staples, section 7.2), not a deck's products.
##
## A deck is either fixed (`cards`, e.g. the starter deck the tests and the balance simulator's
## --deck use) or a recipe (v0.49, section 5.2: `random_count` or `random_coupon_count` > 0). A
## recipe's run starts with its `core_cards`, then `random_coupon_count` coupons (v0.51) and
## `random_count` products drawn from the run's stock (StartingDeck.deal), and the dealt deck is a
## copy of the recipe with those cards in `cards`. The cart reveal (v0.51) lays out at most 4 core
## cards and 9 dealt cards (RevealPanel.fits); a recipe needing more needs its layout reworked.

@export var id: StringName = &""
@export var display_name: String = ""
## Shown when choosing a deck.
@export_multiline var description: String = ""
## A fixed deck's cards; for a dealt recipe, the cards dealt (empty in a recipe's file).
@export var cards: Array[CardDefinition] = []
## A recipe's fixed cards, one entry per copy, dealt first.
@export var core_cards: Array[CardDefinition] = []
## How many products a recipe draws from the run's stock on top of its core cards (0: a fixed
## deck).
@export var random_count: int = 0
## How many coupons a recipe draws from the run's stock (its coupon pool) after its core cards
## and before its products (v0.51; 0: none).
@export var random_coupon_count: int = 0
## The most copies of one card a dealt recipe holds, its core cards included.
@export var copy_max: int = 0
## Whether a recipe also draws capsule products (an aisle's capsule_cards) that have an item-tier
## chain (v0.52). Off: the draw keeps to the fresh-stock products, as before their chains (#89);
## the user decides whether capsule products join it (full build plan 7.2, TODO(S2)).
@export var random_capsules: bool = false
## The fair-deal check (v0.54, full build plan 7.2): a recipe's deal is kept when, of
## `fair_deal_hands` hands of the balance's hand_size sampled from it on the deal's stream, at
## least `fair_deal_passes` reach shift 1's quota with the sensible climb (RowClimb, up to
## `fair_deal_changes` changes, no redraws). Otherwise it is dealt again on the same stream, up to
## `fair_deal_redeals` times, and the deal with the most passing hands (the first on a tie) is
## kept. 0 hands: no check.
@export var fair_deal_hands: int = 0
@export var fair_deal_passes: int = 0
@export var fair_deal_changes: int = 0
@export var fair_deal_redeals: int = 0
## An upgrade the run owns from the start (optional): offers skip it, and it takes a box of its
## own on the loyalty card before the upgrade-shift boxes.
@export var starting_upgrade: UpgradeDefinition
## What unlocks this deck; none means it is available from the start.
@export var unlock_condition: UnlockCondition


## Whether this deck is a recipe, dealt at the start of each run (StartingDeck).
func is_recipe() -> bool:
	return random_count > 0 or random_coupon_count > 0
