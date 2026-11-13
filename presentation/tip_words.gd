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
	["COUPON", "Most coupons pay nothing themselves; they boost other items. Its card says how."],
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
