class_name UpgradeDefinition
extends Resource
## One register upgrade as designed (plan section 3.8). Upgrades last for the whole run and
## live on the loyalty card. Definitions are shared by reference and never changed at runtime;
## the run's owned upgrades are a list in RunState.
##
## Loyalty levels (#108, v0.61): a perk that can level up names its next level's file
## (`next_level`), a whole UpgradeDefinition of its own (data/upgrades/<family>_lv<n>.tres) with
## the same name, type, builds and icon and stronger numbers. A level file sets `level` (2 or 3)
## and `family_id` (its LV 1 id). A level-up replaces the perk in its loyalty box
## (PerkLevels.with_pick), so scoring and ShiftLimits read a level like any perk.
##
## Family perks (#108, piece 2): a perk that works with one aisle family names it
## (`boosts_tag`: Regulars, Aisle runs, Banana stand), and a jackpot that bends one product's rule
## names it (`needs_card`: Lemon squeezer, Fire sale). The machine draws such a perk only when
## the run's stock or deck holds that family or product (MachineContext.stocks), and it fits the
## deck when its family is one of the deck's two most common families (top_families), or when
## the deck holds its product.
##
## Every exported value defaults to a neutral value, because Godot doesn't write a value that
## equals the default into a .tres file. That is why `type` starts at UNSET: every upgrade file
## must state its type, and a test rejects UNSET.

## New types are added at the end: upgrade files store the number.
enum Type {
	UNSET,
	RULE_BENDER,
	SLOT_ENGINE,
	CATEGORY_ENGINE,
	COUPON_ENGINE,
	ECONOMY,
	RISKY,
	REGULARS,
	AISLE_RUN,
	MIXED_BASKET,
	BULK_DEAL,
	JACKPOT,
}

@export var id: StringName = &""
@export var display_name: String = ""
@export var type: Type = Type.UNSET
## The ticket's effect line, e.g. "The first coupon in the row pays x2".
@export_multiline var effect_text: String = ""
## The ticket's condition, on its own line. May be empty.
@export_multiline var condition_text: String = ""
## The builds this upgrade pushes towards (data/builds), shown on the ticket. None means any
## build (Extra redraw).
@export var builds: Array[BuildDefinition] = []
## The perk's glyph (a res:// path to an art/icons PNG) on its LOYALTY prize ticket (v0.50); empty
## shows its initials. Presentation only: scoring never reads it.
@export var icon_ref: String = ""
## Scoring rules, asked about every slot by the scoring loop (never attached to a card).
@export var rules: Array[UpgradeRule] = []
## Run modifiers (ShiftLimits), from the shift after the pick: redraws added to every shift and
## slots added to the row.
@export var extra_redraws: int = 0
@export var extra_slots: int = 0
## The perk's loyalty level: 0 or 1 is LV 1; a level file sets 2 or 3.
@export var level: int = 0
## A level file's LV 1 id (its family); empty on a LV 1 file, whose family is its own id.
@export var family_id: StringName = &""
## The next level's file, or null at the top level (or for a perk that never levels up).
@export var next_level: UpgradeDefinition
## The aisle family the perk works with (a card tag, e.g. "Produce"), or empty.
@export var boosts_tag: String = ""
## The product whose rule the perk bends (a jackpot), or null.
@export var needs_card: CardDefinition


## The ticket's "Supports" text: the builds' names, or "Any build".
func build_names() -> String:
	if builds.is_empty() and needs_card != null:
		return "Decks with %s" % needs_card.display_name
	if builds.is_empty() and not boosts_tag.is_empty():
		return "%s decks" % boosts_tag
	if builds.is_empty():
		return "Any build"
	return ", ".join(builds.map(func(build: BuildDefinition) -> String: return build.display_name))


## Whether this upgrade fits a deck (an UPGRADE draw guarantees a new perk that does): a jackpot
## when the deck holds its product, a family perk when its family is one of the deck's two most
## common `families` (top_families), else when one of its builds fits. An Economy upgrade helps
## any deck, so it never counts as fitting one.
func fits(deck: Array[CardDefinition], families: PackedStringArray = PackedStringArray()) -> bool:
	if type == Type.ECONOMY:
		return false
	if needs_card != null:
		return deck.any(needs_card.is_same_product)
	if not boosts_tag.is_empty():
		return top_families(deck, families).has(boosts_tag)
	return builds.any(func(build: BuildDefinition) -> bool: return build.fits(deck))


## The deck's two most common families among `families` (a product counts once for each of its
## families; coupons don't count), with every family tied with the second; none with no product
## of any family.
static func top_families(
	deck: Array[CardDefinition], families: PackedStringArray
) -> PackedStringArray:
	var counts: Array[int] = []
	for aisle: String in families:
		var count: int = 0
		for card: CardDefinition in deck:
			if card.is_product() and card.tags.has(aisle):
				count += 1
		counts.append(count)
	var sorted: Array[int] = counts.duplicate()
	sorted.sort()
	sorted.reverse()
	var second: int = sorted[mini(1, sorted.size() - 1)] if not sorted.is_empty() else 0
	var found: PackedStringArray = PackedStringArray()
	for index: int in range(families.size()):
		if counts[index] > 0 and counts[index] >= second:
			found.append(families[index])
	return found


## The type as ticket text, e.g. "Coupon Engine".
func type_label() -> String:
	return String(Type.keys()[type]).capitalize()


## The loyalty level, 1 to 3.
func level_number() -> int:
	return maxi(level, 1)


## The perk's family: its LV 1 id.
func family() -> StringName:
	return family_id if not family_id.is_empty() else id


## Whether `other` is a level of the same perk.
func same_perk(other: UpgradeDefinition) -> bool:
	return other != null and other.family() == family()


## Whether this perk has a next level to draw.
func can_level_up() -> bool:
	return next_level != null
