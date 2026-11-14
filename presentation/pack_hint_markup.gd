class_name PackHintMarkup
extends RefCounted
## A starter pack's plain hint (StarterPackDefinition.hint_text) as HandbookMarkup, so the deck
## view's RUN FAMILY card (RunInfoHero, the cart and run info polish, 2026-11-12) draws its terms
## in the handbook's colours (HandbookText): each keyword (GlyphText.KEYWORD_TIPS), each name of
## `cards` (a product as {item:...}, its plural "Bananas" as {items:...}, a coupon as
## {coupon:...}; a BIG or GOLDEN copy by its plain product) and each family's name
## (FamilyPalette) becomes its token; every other word stays plain. Whole words only, the longest
## name first ("Tea bags" before "Tea"). Pure: no nodes.


## `hint` with its terms marked up.
static func of(hint: String, cards: Array[CardDefinition], families: Array[FamilyStyle]) -> String:
	var terms: Dictionary[String, Array] = {}
	for word: String in GlyphText.KEYWORD_TIPS:
		terms[word] = ["kw", word]
	for family: FamilyStyle in families:
		terms[family.display_name] = ["fam", family.id]
	for card: CardDefinition in cards:
		var plain: CardDefinition = card.product_card()
		terms[plain.display_name] = ["coupon" if plain.is_coupon() else "item", String(plain.id)]
	var names: Array[String] = terms.keys()
	names.sort_custom(func(a: String, b: String) -> bool: return a.length() > b.length())
	var escaped: PackedStringArray = PackedStringArray()
	for term: String in names:
		escaped.append(_escaped(term))
	var pattern: RegEx = RegEx.create_from_string("\\b(%s)(s?)\\b" % "|".join(escaped))
	var marked: String = ""
	var start: int = 0
	for found: RegExMatch in pattern.search_all(hint):
		var term: Array = terms[found.get_string(1)]
		var plural: bool = not found.get_string(2).is_empty()
		marked += hint.substr(start, found.get_start() - start)
		if plural and term[0] != "item":
			# Only an item has a plural token: another term's plural stays plain words.
			marked += found.get_string()
		else:
			var kind: String = HandbookMarkup.PLURAL_KIND if plural else term[0] as String
			marked += (
				"%s%s%s%s%s"
				% [
					HandbookMarkup.OPEN,
					kind,
					HandbookMarkup.SEPARATOR,
					term[1],
					HandbookMarkup.CLOSE
				]
			)
		start = found.get_end()
	return marked + hint.substr(start)


## `text` with the regular expression's special characters escaped.
static func _escaped(text: String) -> String:
	var escaped: String = ""
	for character: String in text:
		escaped += "\\" + character if "\\^$.|?*+()[]{}".contains(character) else character
	return escaped
