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
##   (Golden Banana, #77). A chain bonus (the Banana, #106) reads PREVIOUS_PRICE, after its
##   factor when that is not 1 ("prev", "2× prev"). `charges` names a charged multiplier's
##   charges (Golden Eggs, #77). `min_size` is a baked batch's least size (Birthday candles, #128);
## - `batch`: the BATCH keyword (BATCH_WORD, #128), which the ticket draws as a chip with its
##   tooltip (GlyphText's keyword runs): it names the Bakery batch the card works in, so a batch
##   card's template names it instead of "{tag} batch";
## - `chain`: the CHAIN keyword (CHAIN_WORD, #128 Produce links), a chip likewise: it names the
##   Banana chain the card works by (CardChain), so a chain card's ticket shows the CHAIN chip;
## - `wasted`: the WASTED keyword (WASTED_WORD, #128 v3 Clearance), a chip likewise: it names the
##   WASTED products a Clearance card profits from (ScoreState.wasted);
## - `pair`: the PAIR keyword (PAIR_WORD, #128 Dairy), a chip likewise: a product beside its
##   partner (CardPairs), which Cream counts;
## - `morning`: the MORNING keyword (MORNING_WORD, #128 Breakfast), a chip likewise: the row's
##   opening run of Breakfast products (CardMorning), which Coffee and Tea bags work by;
## - `percent`: a fractional multiplier's percent per redraw left (Stale popcorn, #128 v3). Such a
##   card's `factor` is live (the user's call of 2026-11-02): ×1 plus `percent`% for each of the
##   shift's redraws left (`redraws_left`, ScoreState.redraws_left), "1.5" with 1 at 50%, so its
##   sticker reads "×1.5 next Snack" like Eggs' "×2 next Food"; the ticket draws that ×N as a live
##   chip (live_word) whose tooltip says how it grows (live_tip). With no `redraws_left` (-1) it is
##   the rule's own factor.
## Any other `{key}` (e.g. `{match_by}`) is left unformatted, braces and all, so the live-data
## test rejects it.
const STICKER_KEYS: Array[String] = [
	"base",
	"name",
	"bonus",
	"bonus_each",
	"factor",
	"charges",
	"tag",
	"match_value",
	"min_size",
	"batch",
	"chain",
	"wasted",
	"pair",
	"morning",
	"percent",
]
const RULE_KEYS: Array[String] = [
	"bonus", "bonus_each", "factor", "charges", "tag", "match_value", "min_size", "percent"
]
## The BATCH keyword's word (#128): `{batch}` in a template.
const BATCH_KEY := "batch"
const BATCH_WORD := "BATCH"
## The CHAIN keyword's word (#128, Produce links): `{chain}` in a template.
const CHAIN_KEY := "chain"
const CHAIN_WORD := "CHAIN"
## The WASTED keyword's word (#128 v3, Clearance): `{wasted}` in a template.
const WASTED_KEY := "wasted"
const WASTED_WORD := "WASTED"
## The PAIR keyword's word (#128, Dairy): `{pair}` in a template.
const PAIR_KEY := "pair"
const PAIR_WORD := "PAIR"
## The MORNING keyword's word (#128, Breakfast): `{morning}` in a template.
const MORNING_KEY := "morning"
const MORNING_WORD := "MORNING"
## A live factor's tooltip (live_tip): the factor now, its percent per redraw left, the redraws
## left.
const LIVE_TIP := "%s now · ×%s, plus %s for each redraw left this shift (%d left)"
## A Family sticker's `{tag}` (v1.28) before a copy's family is known (the hand, the machine,
## the deck view): its ticket on the belt reads the family it gives ("Next joins Breakfast").
const PICK_WORDS := "your pick"
## What a chain bonus's `{bonus}` reads: the previous product's price.
const PREVIOUS_PRICE := "prev"
## The monitor's description (monitor_text) may name every sticker key and these: `max_count`, a
## rule's cap ("up to 2"), `previous`, a chain bonus in words, and `times`, the factor in words.
const MONITOR_RULE_KEYS: Array[String] = ["max_count"]
const PREVIOUS_KEY := "previous"
const TIMES_KEY := "times"
## A live factor's rule in its own numbers (#138 review: Stale popcorn): `own_factor`, its factor
## with no redraw left, `redraw_step`, what each redraw left adds, and `live_now`, LIVE_NOW with the
## factor now while the shift's redraws are known ("" otherwise).
const OWN_FACTOR_KEY := "own_factor"
const REDRAW_STEP_KEY := "redraw_step"
const LIVE_NOW_KEY := "live_now"
const LIVE_NOW := " (now %s)"
const MONITOR_KEYS: Array[String] = [
	"base",
	"name",
	"bonus",
	"bonus_each",
	"factor",
	"charges",
	"tag",
	"match_value",
	"min_size",
	"batch",
	"chain",
	"wasted",
	"pair",
	"morning",
	"percent",
	"max_count",
	PREVIOUS_KEY,
	TIMES_KEY,
	OWN_FACTOR_KEY,
	REDRAW_STEP_KEY,
	LIVE_NOW_KEY,
]
## A chain bonus in words, with its product's name; counted twice and more it reads TIMES_WORDS
## first ("twice the previous Banana's price").
const PREVIOUS_WORDS := "the previous %s's price"
const TIMES_WORDS: Array[String] = ["", "", "twice", "three times", "four times"]
const TIMES_FALLBACK := "%d times"


## The card's sticker summary, or "" when its template is empty (a card with no rule shows only
## its price).
## `redraws_left` (-1: unknown) fills a live factor (see `percent` above); `family` a Family
## sticker's `{tag}` (the family one copy gives, v1.28; "": PICK_WORDS).
static func sticker_summary(
	definition: CardDefinition, redraws_left: int = -1, family: String = ""
) -> String:
	var values: Dictionary = sticker_values(definition, redraws_left)
	if FamilySticker.is_family_sticker(definition):
		values["tag"] = family if not family.is_empty() else PICK_WORDS
	return sticker_template(definition).format(values)


## A live factor's words on the sticker ("×1.5", #128 v3 Stale popcorn), or "" for a card with
## none or an unknown `redraws_left` (-1).
static func live_word(definition: CardDefinition, redraws_left: int) -> String:
	var rule: GrantChargedMultiplierRule = live_rule(definition)
	if rule == null or redraws_left < 0:
		return ""
	return "×" + ScoreStep.percent_text(live_percent(rule, redraws_left))


## A live factor's tooltip: how it grows, and what it is now.
static func live_tip(definition: CardDefinition, redraws_left: int) -> String:
	var rule: GrantChargedMultiplierRule = live_rule(definition)
	if rule == null or redraws_left < 0:
		return ""
	var step: String = ScoreStep.percent_text(rule.factor * rule.percent)
	return LIVE_TIP % [live_word(definition, redraws_left), rule.factor, step, redraws_left]


## The live words' tooltips for GlyphLabel.set_live ({word: tip}; empty without a live factor).
static func live_tips(definition: CardDefinition, redraws_left: int) -> Dictionary:
	var word: String = live_word(definition, redraws_left)
	if word.is_empty():
		return {}
	return {word: live_tip(definition, redraws_left)}


## The card's first rule with a live factor (a charged multiplier with a `percent`), or null.
static func live_rule(definition: CardDefinition) -> GrantChargedMultiplierRule:
	if definition == null:
		return null
	for rule: Rule in definition.rules:
		var charged: GrantChargedMultiplierRule = rule as GrantChargedMultiplierRule
		if charged != null and charged.percent > 0:
			return charged
	return null


## A live factor in percent with `redraws_left` (scoring's: 100 plus `percent` for each).
static func live_percent(rule: GrantChargedMultiplierRule, redraws_left: int) -> int:
	return rule.live_percent(redraws_left)


## The card's own template, or its base card's when it is a variant with none of its own.
static func sticker_template(definition: CardDefinition) -> String:
	if definition.sticker_text.is_empty() and definition.variant_of != null:
		return definition.variant_of.sticker_text
	return definition.sticker_text


## The values a template can name (STICKER_KEYS), from the card and its rules; `redraws_left`
## fills a live factor (-1: the rule's own).
static func sticker_values(definition: CardDefinition, redraws_left: int = -1) -> Dictionary:
	var values: Dictionary = {
		"base": definition.base,
		"name": definition.product_card().display_name,
		BATCH_KEY: BATCH_WORD,
		CHAIN_KEY: CHAIN_WORD,
		WASTED_KEY: WASTED_WORD,
		PAIR_KEY: PAIR_WORD,
		MORNING_KEY: MORNING_WORD,
	}
	for rule: Rule in definition.rules:
		for property: Dictionary in rule.get_property_list():
			var key: String = property["name"]
			var is_field: bool = (int(property["usage"]) & PROPERTY_USAGE_SCRIPT_VARIABLE) != 0
			if is_field and RULE_KEYS.has(key) and not values.has(key):
				values[key] = rule.get(key)
		var adjacent: AdjacentMatchBonusRule = rule as AdjacentMatchBonusRule
		if adjacent != null and adjacent.bonus_is_previous_price:
			values["bonus"] = previous_price_text(adjacent.bonus_factor)
		elif adjacent != null and (adjacent.bonus_is_base or adjacent.bonus_factor != 1):
			values["bonus"] = adjacent.bonus_for(definition.base)
	var live: GrantChargedMultiplierRule = live_rule(definition)
	if live != null and redraws_left >= 0:
		values["factor"] = ScoreStep.percent_text(live_percent(live, redraws_left))
	return values


## Whether the card's template names the BATCH keyword (`{batch}`, #128): a batch card, whose
## ticket shows the BATCH chip (and the belt frames its batch while planning).
static func names_batch(definition: CardDefinition) -> bool:
	return definition != null and sticker_template(definition).contains("{%s}" % BATCH_KEY)


## Whether the card's template names the CHAIN keyword (`{chain}`, #128 Produce links): a chain
## card (the Banana or a helper with a place by the chain), whose ticket shows the CHAIN chip.
static func names_chain(definition: CardDefinition) -> bool:
	return definition != null and sticker_template(definition).contains("{%s}" % CHAIN_KEY)


## The card's monitor description (PR #138 monitor: CardDefinition.monitor_text, the rule in plain
## language with more detail than the sticker) with its numbers and names filled in from the card's
## data, or "" when its template is empty. `redraws_left` fills a live factor as on the sticker.
static func monitor_text(definition: CardDefinition, redraws_left: int = -1) -> String:
	return monitor_template(definition).format(monitor_values(definition, redraws_left))


## The card's own monitor template, or its base card's when it is a variant with none of its own.
static func monitor_template(definition: CardDefinition) -> String:
	if definition.monitor_text.is_empty() and definition.variant_of != null:
		return definition.variant_of.monitor_text
	return definition.monitor_text


## The values a monitor template can name (MONITOR_KEYS): the sticker's, then MONITOR_RULE_KEYS
## from the card's first rule that has them, `previous` (a chain bonus's PREVIOUS_WORDS, counted
## by its factor: "twice the previous Banana's price") and `times` (the `factor` in words).
static func monitor_values(definition: CardDefinition, redraws_left: int = -1) -> Dictionary:
	var values: Dictionary = sticker_values(definition, redraws_left)
	for rule: Rule in definition.rules:
		for property: Dictionary in rule.get_property_list():
			var key: String = property["name"]
			var is_field: bool = (int(property["usage"]) & PROPERTY_USAGE_SCRIPT_VARIABLE) != 0
			if is_field and MONITOR_RULE_KEYS.has(key) and not values.has(key):
				values[key] = rule.get(key)
		var adjacent: AdjacentMatchBonusRule = rule as AdjacentMatchBonusRule
		if adjacent != null and adjacent.bonus_is_previous_price:
			var words: String = PREVIOUS_WORDS % values["name"]
			var times: String = times_words(adjacent.bonus_factor)
			values[PREVIOUS_KEY] = words if times.is_empty() else "%s %s" % [times, words]
	var factor: Variant = values.get("factor")
	if factor is int:
		values[TIMES_KEY] = times_words(factor)
	var live: GrantChargedMultiplierRule = live_rule(definition)
	if live != null:
		values[OWN_FACTOR_KEY] = ScoreStep.percent_text(live.live_percent(0))
		values[REDRAW_STEP_KEY] = ScoreStep.percent_text(live.factor * live.percent)
		var now: String = live_word(definition, redraws_left)
		values[LIVE_NOW_KEY] = "" if now.is_empty() else LIVE_NOW % now
	return values


## `factor` in words ("twice", "three times"; "" for 1).
static func times_words(factor: int) -> String:
	if factor <= 1:
		return ""
	if factor < TIMES_WORDS.size():
		return TIMES_WORDS[factor]
	return TIMES_FALLBACK % factor


## A chain bonus's `{bonus}`: PREVIOUS_PRICE, counted `factor` times ("prev", "2× prev").
static func previous_price_text(factor: int) -> String:
	return PREVIOUS_PRICE if factor == 1 else "%d× %s" % [factor, PREVIOUS_PRICE]


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
