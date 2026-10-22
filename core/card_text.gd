class_name CardText
extends RefCounted
## The price sticker's short summary (#75): a card's `sticker_text` template with its numbers and
## names filled in from the card's own data, so a balance pass that changes a rule's numbers
## changes its sticker too. Templates are digit-free (ordinals such as "1st" aside) and name only
## STICKER_KEYS. The UI shows the formatted summary and never reads a rule.

## The keys a template may name:
## - `base`: the card's base value;
## - `name`: its product's display name (a variant names its base card, the same product);
## - `bonus`, `bonus_each`, `factor`, `charges`, `tag` and `match_value`: the fields of the
##   card's first rule that has them. A match bonus's `bonus` is what it pays on a match: the
##   card's base when that rule's bonus is its base (Banana), counted `bonus_factor` times
##   (Golden Banana, #77). `charges` names a charged multiplier's charges (Golden Eggs, #77).
## Any other `{key}` (e.g. `{match_by}`) is left unformatted, braces and all, so the live-data
## test rejects it.
const STICKER_KEYS: Array[String] = [
	"base", "name", "bonus", "bonus_each", "factor", "charges", "tag", "match_value"
]
const RULE_KEYS: Array[String] = ["bonus", "bonus_each", "factor", "charges", "tag", "match_value"]


## The card's sticker summary, or "" when its template is empty (a card with no rule shows only
## its price).
static func sticker_summary(definition: CardDefinition) -> String:
	return sticker_template(definition).format(sticker_values(definition))


## The card's own template, or its base card's when it is a variant with none of its own.
static func sticker_template(definition: CardDefinition) -> String:
	if definition.sticker_text.is_empty() and definition.variant_of != null:
		return definition.variant_of.sticker_text
	return definition.sticker_text


## The values a template can name (STICKER_KEYS), from the card and its rules.
static func sticker_values(definition: CardDefinition) -> Dictionary:
	var values: Dictionary = {
		"base": definition.base,
		"name": definition.product_card().display_name,
	}
	for rule: Rule in definition.rules:
		for property: Dictionary in rule.get_property_list():
			var key: String = property["name"]
			var is_field: bool = (int(property["usage"]) & PROPERTY_USAGE_SCRIPT_VARIABLE) != 0
			if is_field and RULE_KEYS.has(key) and not values.has(key):
				values[key] = rule.get(key)
		var adjacent: AdjacentMatchBonusRule = rule as AdjacentMatchBonusRule
		if adjacent != null and (adjacent.bonus_is_base or adjacent.bonus_factor != 1):
			values["bonus"] = adjacent.bonus_for(definition.base)
	return values


## The sticker values (`base`, then RULE_KEYS) that differ between two cards, e.g. an item tier
## (#77) and the card one tier below it: Golden Eggs against Big Eggs gives ["charges"], Big
## Milk against Milk ["base"]. The hover card highlights these; it never compares rules itself.
static func changed_fields(before: CardDefinition, after: CardDefinition) -> PackedStringArray:
	var old_values: Dictionary = sticker_values(before)
	var new_values: Dictionary = sticker_values(after)
	var found: PackedStringArray = PackedStringArray()
	for key: String in ["base"] + RULE_KEYS:
		var was: Variant = old_values.get(key)
		var now: Variant = new_values.get(key)
		if typeof(was) != typeof(now) or was != now:
			found.append(key)
	return found
