class_name TutorialText
extends RefCounted
## The tutorial's lines (TutorialStep, TipDefinition): `**WORD**` marks a glossary chip and
## `{name}` a number or name filled in. Numbers come from data, never from the line: the guided
## shift's rows are scored by the game's own Scoring (so "19€, not 14€" is the rules'), the rest
## read from the balance. Live names (the title's plate, T4's MORNING, T14's card) are passed in
## by the caller. markup() turns a filled line into TipMarkup for TipText: a keyword's chip
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

## The guided shift's figures: placeholder, the step whose row_before is scored, what is read,
## and the slot it is read at (TOTAL: unused).
const FIGURES: Array[Array] = [
	["bread_price", &"G11", Measure.PAYOUT, 0],
	["cheese_price", &"G13", Measure.PRICE, 1],
	["cheese_bonus", &"G13", Measure.BONUS, 1],
	["pair_pays", &"G13", Measure.PAYOUT, 1],
	["row_pair", &"G13", Measure.TOTAL, 0],
	["row_wrong", &"G15", Measure.TOTAL, 0],
	["eggs_times", &"G16", Measure.TIMES, 1],
	["bread_doubled", &"G16", Measure.PAYOUT, 1],
	["row_right", &"G16", Measure.TOTAL, 0],
	["banana_price", &"G19", Measure.PAYOUT, 3],
	["banana_chain", &"G19", Measure.PAYOUT, 4],
	["morning_bonus", &"G21", Measure.BONUS, 5],
	["row_full", &"G21", Measure.TOTAL, 0],
]
## The full row's MORNING reader (Coffee), whose per-item bonus T4 names (coffee_per).
const MORNING_READER := [&"G21", 6]
## The live placeholders the caller fills: the title's primary plate (G1), T4's MORNING and T14's
## card and family.
const PRIMARY := "primary"
const MORNING_NAMES := "morning_names"
const MORNING_MAKE := "morning_make"
const MORNING_COUNT := "morning_count"
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
	var scored: Dictionary[StringName, Array] = {}
	for figure: Array in FIGURES:
		var step_id: StringName = figure[1]
		if not scored.has(step_id):
			scored[step_id] = _scored(script, step_id, content)
		var row_and_result: Array = scored[step_id]
		if row_and_result.is_empty():
			continue
		found[str(figure[0])] = str(_measure(row_and_result, figure[2], figure[3]))
	var reader: Array = scored.get(MORNING_READER[0], [])
	if not reader.is_empty():
		found["coffee_per"] = str(_morning_bonus_each(reader[0], MORNING_READER[1]))
	if balance == null:
		return found
	found["quota"] = str(balance.quotas[0]) if not balance.quotas.is_empty() else "0"
	found["slots"] = str(balance.slot_count)
	found["hand"] = str(balance.hand_size)
	found["booster_size"] = str(balance.start_booster_size)
	found["week_shifts"] = str(balance.week_length)
	found["misses"] = str(balance.write_up_limit)
	found["payday_inspections"] = str(balance.review_inspection_count)
	found["pin_slots"] = str(balance.pin_slots)
	found["coin_shifts"] = str(_first_paying(balance.coins_by_shifts_passed))
	var machine: MachineDefinition = balance.machine
	if machine != null:
		found["silver_laps"] = str(machine.overtime_ticket_laps)
		found["gold_laps"] = str(machine.overtime_premium_laps)
		found["payday_draws"] = str(_payday_draws(machine))
	return found


## T4's live names: the MORNING's items ("Eggs and Bread"), its verb and its count.
static func morning_values(names: PackedStringArray) -> Dictionary[String, String]:
	return {
		MORNING_NAMES: listed(names),
		MORNING_MAKE: "makes" if names.size() == 1 else "make",
		MORNING_COUNT: str(names.size()),
	}


## `names` as a list read aloud: "Eggs", "Eggs and Bread", "Eggs, Bread and Milk".
static func listed(names: PackedStringArray) -> String:
	if names.size() <= 1:
		return "".join(names)
	return "%s and %s" % [", ".join(names.slice(0, names.size() - 1)), names[names.size() - 1]]


## The row of step `step_id` as instances and its ScoreResult, or [] when a card is missing.
static func _scored(script: TutorialScript, step_id: StringName, content: ContentLookup) -> Array:
	var step: TutorialStep = script.step(step_id) if script != null else null
	if step == null:
		return []
	var row: Array[CardInstance] = []
	for card_id: StringName in step.row_before:
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


static func _morning_bonus_each(row: Array[CardInstance], slot: int) -> int:
	if slot < 0 or slot >= row.size():
		return 0
	for rule: Rule in row[slot].definition.rules:
		var count_rule: MorningCountRule = rule as MorningCountRule
		if count_rule != null:
			return count_rule.bonus_each
	return 0


## The fewest shifts passed that pay coins.
static func _first_paying(coins: PackedInt32Array) -> int:
	for passed: int in coins.size():
		if coins[passed] > 0:
			return passed
	return 0


## A payday's PREMIUM draws: its ticket's, and its BONUS visit's when it has one.
static func _payday_draws(machine: MachineDefinition) -> int:
	if machine.premium_shifts.is_empty():
		return 0
	var payday: int = machine.premium_shifts[0]
	return 1 + (1 if machine.bonus_extra_shifts.has(payday) else 0)


static func _placeholder_pattern() -> RegEx:
	if _placeholder == null:
		_placeholder = RegEx.create_from_string("\\{([a-z_0-9]+)\\}")
	return _placeholder


static func _chip_pattern() -> RegEx:
	if _chip == null:
		_chip = RegEx.create_from_string("\\*\\*(.+?)\\*\\*")
	return _chip
