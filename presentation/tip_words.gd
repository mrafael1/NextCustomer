class_name TipWords
extends RefCounted
## The boxes a hover tip shows beside it (the hover tips revamp, mock-up
## docs/art/mockups/hover_tips.html, its SUB boxes; approved 2026-11-13): a keyword's (a mechanic:
## PAIR, CHAIN, BATCH, MORNING, WASTED; its rule is the handbook's, GlyphText.keyword_tip, so the
## box, the chip and the handbook say the same thing) or a plain word's (WORDS: THE ROW, SLOT,
## QUOTA, COUPON, FAMILY, PREMIUM), each a TipSpec (KEYWORD or WORD kind, no footer). The dominant
## terms (2026-11-13): QUOTA for the € a shift needs, SHIFT for the turn.

## Each plain word's title and meaning.
const WORDS: Dictionary[String, Array] = {
	"FAMILY":
	[
		"FAMILY",
		(
			"A group of items, shown by the coloured icons on a ticket. An item can be in more "
			+ "than one family."
		)
	],
	"ROW": ["THE ROW", "Your items on the belt, scanned left to right at checkout."],
	"SLOT": ["SLOT", "The numbered places on the belt, left to right."],
	"QUOTA":
	["QUOTA", "The € you need at checkout to pass the shift. It is on the receipt, top left."],
	"PREMIUM": ["PREMIUM", "The prize machine's gold mode, with rarer prizes."],
	"COUPON":
	# The tutorial's glossary words (tutorial_glossary.json's "teach" lines, trimmed): the
	["COUPON", "Most coupons pay nothing themselves; they boost other items. Its card says how."],
	# boxes of its chips (TutorialText.CHIP_KEYS). Drafts, for approval.
	"SHIFT":
	["SHIFT", "One turn of the game: fill the row, press CHECKOUT and see if you met the quota."],
	"CARD": ["CARD", "Everything in your cart: items, which have a price, and coupons."],
	"ITEM": ["ITEM", "A card with a price. Its rule, if it has one, can make it pay more."],
	"BASKETS":
	["BASKETS", "The cards you drew this shift. Drag them from their baskets to the row."],
	"PRICE": ["PRICE", "What an item pays by itself. A rule can make it pay more."],
	"RULE":
	["RULE", "The line on a card that adds € or multiplies when the card sits in the right place."],
	"CHECKOUT": ["CHECKOUT", "Every card in the row pays, from left to right."],
	"BESIDE":
	[
		"BESIDE",
		"Directly left or right. A coupon between two items stops them being beside each other."
	],
	"RIGHT BEFORE":
	["RIGHT BEFORE / AFTER", "The very next slot to the left or right. NEXT can skip items."],
	"LATER":
	["EARLIER / LATER", "EARLIER: anywhere to its left in the row. LATER: anywhere to its right."],
	"NEXT": ["NEXT", "The first item of that family later in the row, even past other items."],
	"REDRAW": ["REDRAW", "Swap a whole basket for new cards from your pile. A few each shift."],
	"RECEIPT REWARDS":
	[
		"RECEIPT REWARDS",
		"The prize machine. After each shift you pass, pick NEW ITEMS or IMPROVE and draw prizes."
	],
	"NEW ITEMS": ["NEW ITEMS", "New cards for your cart. Items can arrive BIG or GOLDEN."],
	"IMPROVE": ["IMPROVE", "Make a card you own better (BIG, then GOLDEN), or get a loyalty perk."],
	"RARITY":
	["RARITY", "COMMON, RARE or LEGENDARY: how hard a prize is to find. Not BIG or GOLDEN."],
	"CART": ["CART", "All your cards for this run."],
	"PILE": ["PILE", "The cards in your cart still to draw this shift."],
	"WEEK": ["WEEK", "A run of shifts that ends on PAYDAY. Each week has its own week event."],
	"DAY EVENT":
	["DAY EVENT", "A shift's twist: a GOOD DAY's bonus or an INSPECTION's harder rule."],
	"GOOD DAY": ["GOOD DAY", "A green day event: a bonus for this shift."],
	"INSPECTION": ["INSPECTION", "A red day event: a harder rule for this shift."],
	"PAYDAY":
	[
		"PAYDAY",
		(
			"The week's last shift, with inspections. Meet the quota for PREMIUM draws. The last "
			+ "one wins the run."
		)
	],
	"MISS":
	[
		"MISS",
		"A shift that didn't meet its quota: no prizes. After training week, one miss ends the run."
	],
	"EXTRA DRAW": ["EXTRA DRAW", "One more prize draw at the machine."],
	"MEDALS": ["MEDALS", "SILVER and GOLD, for paying the quota a few times over in one shift."],
	"LOYALTY PERKS":
	[
		"LOYALTY PERKS",
		"Machine prizes that last the whole run, on your LOYALTY card. Some level up."
	],
	"YOUR REGULARS": ["YOUR REGULARS", "The cards that start in your cart on every run."],
	"BOOSTER":
	["BOOSTER", "An aisle's sealed cards on the start screen. Open it: they join your cart."],
	"BADGE PINS": ["BADGE PINS", "Earned between runs. A pin you wear changes a rule for a run."],
	"COINS": ["COINS", "Paid at a run's end. They buy toy capsules at the exit."],
	"RESTOCK": ["RESTOCK", "Send one opened booster back for a new one, once per run start."],
	"SWAP": ["SWAP", "Trade one of your regulars for a plain card, for this run only."],
	"SKIP": ["SKIP", "Bin the machine's prizes and keep none."],
	"BIG": ["BIG", "An improved item: it pays more. A later IMPROVE can make it GOLDEN."],
	"GOLDEN": ["GOLDEN", "An item's best tier, after BIG."],
	"HANDBOOK": ["HANDBOOK", "In the menu: the rules of keywords, families, coupons and places."],
}


## Whether `key` has a box (a keyword or a word).
static func has(key: String) -> bool:
	return WORDS.has(key) or GlyphText.KEYWORD_TIPS.has(key)


static func is_keyword(key: String) -> bool:
	return GlyphText.KEYWORD_TIPS.has(key)


## The box's title ("THE ROW"; a keyword's own word).
static func title_of(key: String) -> String:
	if WORDS.has(key):
		return str(WORDS[key][0])
	return key


## `key`'s box: a keyword's (KEYWORD, its handbook rule) or a word's (WORD), or null for none.
static func box(key: String) -> TipSpec:
	if GlyphText.KEYWORD_TIPS.has(key):
		var keyword: TipSpec = TipSpec.make(
			TipSpec.Kind.KEYWORD, key, TipMarkup.auto(GlyphText.keyword_tip(key))
		)
		keyword.tag = TipSpec.KEYWORD_TAG
		return keyword
	if not WORDS.has(key):
		return null
	var word: TipSpec = TipSpec.make(TipSpec.Kind.WORD, str(WORDS[key][0]), str(WORDS[key][1]))
	word.tag = TipSpec.WORD_TAG
	return word
