class_name TutorialText
extends RefCounted
## The tutorial's lines (TutorialStep, TipDefinition): `**WORD**` marks a glossary chip and
## `{name}` a number or name filled in. Numbers come from data, never from the line: the guided
## shift's answer row is scored by the game's own Scoring (so its total is the rules'), the rest
## read from the balance. Live names (the title's plate, T14's card) are passed in by the
## caller. markup() turns a filled line into TipMarkup for TipText: a keyword's chip
## ("[PAIR]") or a word's box ("~CARDS|CARD~", TipWords).

## How a figure is read off a scored row.
enum Measure { TOTAL, PAYOUT, PRICE, BONUS, TIMES }

## Each chip's written form and its TipWords key (the mock-up's TERM_KEYS: plurals and the forms
## of one word share a key). A keyword's key is the keyword (GlyphText.KEYWORD_TIPS).
const CHIP_KEYS: Dictionary[String, String] = {
	"SHIFT": "SHIFT",
	"SHIFTS": "SHIFT",
	"CARD": "CARD",
	"CARDS": "CARD",
	"ITEM": "ITEM",
	"ITEMS": "ITEM",
	"COUPON": "COUPON",
	"COUPONS": "COUPON",
	"BASKET": "BASKETS",
	"BASKETS": "BASKETS",
	"ROW": "ROW",
	"PRICE": "PRICE",
	"RULE": "RULE",
	"CHECKOUT": "CHECKOUT",
	"QUOTA": "QUOTA",
	"BESIDE": "BESIDE",
	"RIGHT BEFORE": "RIGHT BEFORE",
	"RIGHT AFTER": "RIGHT BEFORE",
	"EARLIER": "LATER",
	"LATER": "LATER",
	"NEXT": "NEXT",
	"FAMILY": "FAMILY",
	"FAMILIES": "FAMILY",
	"REDRAW": "REDRAW",
	"CHAIN": "CHAIN",
	"BATCH": "BATCH",
	"PAIR": "PAIR",
	"MORNING": "MORNING",
	"WASTED": "WASTED",
	"RECEIPT REWARDS": "RECEIPT REWARDS",
	"NEW ITEMS": "NEW ITEMS",
	"IMPROVE": "IMPROVE",
	"BIG": "BIG",
	"GOLDEN": "GOLDEN",
	"RARE": "RARITY",
	"LEGENDARY": "RARITY",
	"COMMON": "RARITY",
	"CART": "CART",
	"PILE": "PILE",
	"WEEK": "WEEK",
	"DAY EVENT": "DAY EVENT",
	"GOOD DAY": "GOOD DAY",
	"INSPECTION": "INSPECTION",
	"INSPECTIONS": "INSPECTION",
	"PAYDAY": "PAYDAY",
	"MISS": "MISS",
	"EXTRA DRAW": "EXTRA DRAW",
	"PREMIUM": "PREMIUM",
	"SILVER": "MEDALS",
	"GOLD": "MEDALS",
	"MEDALS": "MEDALS",
	"LOYALTY PERKS": "LOYALTY PERKS",
	"LOYALTY PERK": "LOYALTY PERKS",
	"LOYALTY": "LOYALTY PERKS",
	"STARTER PACK": "STARTER PACK",
	"STARTER PACKS": "STARTER PACK",
	"YOUR REGULARS": "YOUR REGULARS",
	"REGULARS": "YOUR REGULARS",
	"BADGE PINS": "BADGE PINS",
	"BADGE PIN": "BADGE PINS",
	"COINS": "COINS",
	"HANDBOOK": "HANDBOOK",
	"BOOSTER": "BOOSTER",
	"BOOSTERS": "BOOSTER",
	"RESTOCK": "RESTOCK",
	"SWAP": "SWAP",
	"SKIP": "SKIP",
}
## Chips the line checker doesn't hold to the teaching order (the mock-up's null TERM_KEYS: SKIP
## is the machine's own key label, beside the tip).
const UNCHECKED: Array[String] = ["SKIP"]

## The guided shift's figures, read off its answer row (TutorialScript.answer): placeholder, what
## is read and the slot it is read at (TOTAL: unused).
const FIGURES: Array[Array] = [
	["answer_total", Measure.TOTAL, 0],
]
## The retry line's live figure: the missed rehearsal's total.
const MISSED := "missed"
## The live placeholders the caller fills: the title's primary plate (G1) and T14's card and
## family.
const PRIMARY := "primary"
const WASTED_CARD := "card"
const WASTED_FAMILY := "family"

static var _placeholder: RegEx
static var _chip: RegEx


## `text` with each `{name}` replaced by `fills[name]`; a name `fills` lacks is left as it is.
static func fill(text: String, fills: Dictionary) -> String:
	var filled: String = ""
	var at: int = 0
	for found: RegExMatch in _placeholder_pattern().search_all(text):
		filled += text.substr(at, found.get_start() - at)
		var name: String = found.get_string(1)
		filled += str(fills[name]) if fills.has(name) else found.get_string()
		at = found.get_end()
	return filled + text.substr(at)


## The placeholders `text` names, in order, once each.
static func placeholders(text: String) -> PackedStringArray:
	var found: PackedStringArray = PackedStringArray()
	for each: RegExMatch in _placeholder_pattern().search_all(text):
		if not found.has(each.get_string(1)):
			found.append(each.get_string(1))
	return found


## The chips' written forms in `text` ("CARDS", "RIGHT BEFORE"), in order.
static func chips(text: String) -> PackedStringArray:
	var found: PackedStringArray = PackedStringArray()
	for each: RegExMatch in _chip_pattern().search_all(text):
		found.append(each.get_string(1))
	return found


## Chip form `form`'s TipWords key, or "" when it has none.
static func chip_key(form: String) -> String:
	return CHIP_KEYS.get(form, "")


## `text` as it reads, without the chip marks.
static func plain(text: String) -> String:
	return text.replace("**", "")


## `text` (filled) as TipMarkup: each chip a keyword's ("[PAIR]") or a word's box
## ("~CARDS|CARD~"); a form with no key stays plain words.
static func markup(text: String) -> String:
	var marked: String = ""
	var at: int = 0
	for each: RegExMatch in _chip_pattern().search_all(text):
		marked += text.substr(at, each.get_start() - at)
		var form: String = each.get_string(1)
		var key: String = chip_key(form)
		if GlyphText.KEYWORD_TIPS.has(key) and key == form:
			marked += "[%s]" % form
		elif key.is_empty():
			marked += form
		else:
			marked += "~%s|%s~" % [form, key]
		at = each.get_end()
	return marked + text.substr(at)


## The numbers the lines name, by placeholder, read from `balance` and the guided shift's rows
## (`script`'s steps, scored with no perks and no day events: shift 1 has none), their cards
## found by `lookup` (the game's data/cards by default).
static func values(
	script: TutorialScript, balance: BalanceDefinition, lookup: ContentLookup = null
) -> Dictionary[String, String]:
	var found: Dictionary[String, String] = {}
	var content: ContentLookup = lookup if lookup != null else ContentLookup.new(balance)
	var answer: Array = _scored(script, content)
	for figure: Array in FIGURES:
		if not answer.is_empty():
			found[str(figure[0])] = str(_measure(answer, figure[1], figure[2]))
	if balance == null:
		return found
	found["quota"] = str(balance.quotas[0]) if not balance.quotas.is_empty() else "0"
	found["misses"] = str(balance.write_up_limit)
	return found


## The script's answer row as instances and its ScoreResult, or [] when a card is missing.
static func _scored(script: TutorialScript, content: ContentLookup) -> Array:
	if script == null or script.answer.is_empty():
		return []
	var row: Array[CardInstance] = []
	for card_id: StringName in script.answer:
		var card: CardDefinition = content.card(String(card_id))
		if card == null:
			return []
		row.append(CardInstance.new(card, row.size() + 1))
	return [row, Scoring.score(row)]


static func _measure(row_and_result: Array, measure: Measure, slot: int) -> int:
	var row: Array[CardInstance] = row_and_result[0]
	var result: ScoreResult = row_and_result[1]
	if measure == Measure.TOTAL:
		return result.total
	if slot < 0 or slot >= row.size():
		return 0
	var price: int = row[slot].definition.base
	var payout: int = result.payouts[slot]
	match measure:
		Measure.PAYOUT:
			return payout
		Measure.PRICE:
			return price
		Measure.BONUS:
			return payout - price
		Measure.TIMES:
			return floori(float(payout) / float(price)) if price != 0 else 0
	return 0


static func _placeholder_pattern() -> RegEx:
	if _placeholder == null:
		_placeholder = RegEx.create_from_string("\\{([a-z_0-9]+)\\}")
	return _placeholder


static func _chip_pattern() -> RegEx:
	if _chip == null:
		_chip = RegEx.create_from_string("\\*\\*(.+?)\\*\\*")
	return _chip
