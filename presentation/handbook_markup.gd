class_name HandbookMarkup
extends RefCounted
## The STAFF HANDBOOK's text markup (the guide feedback of 2026-11-11: "use more colors for a
## quicker and easier identification"): an entry's text names its terms by id, and the handbook
## draws each kind in its own colour (HandbookText). The names come from data, so they are never
## typed twice:
##   {kw:CHAIN}           a keyword (a GlyphText.KEYWORD_TIPS key), shown as itself
##   {item:banana}        a product card (data/cards), shown as its display name ("Banana")
##   {items:banana}       the same, plural ("Bananas"; a name already ending in s is kept)
##   {coupon:repeat}      a coupon card, shown as its display name ("Repeat")
##   {fam:Breakfast}      a family (data/families, its id as cards write tags), its display name
## A token that names no known kind or id is UNKNOWN: it shows its id (or its whole inside) as
## plain text, and unknown_tokens() lists it so a data test fails on it. Pure: no nodes.

enum Kind { TEXT, KEYWORD, ITEM, COUPON, FAMILY, UNKNOWN }

const OPEN := "{"
const CLOSE := "}"
const SEPARATOR := ":"
## Each token kind's word, and the plural item's.
const KINDS: Dictionary[String, Kind] = {
	"kw": Kind.KEYWORD,
	"item": Kind.ITEM,
	"items": Kind.ITEM,
	"coupon": Kind.COUPON,
	"fam": Kind.FAMILY,
}
const PLURAL_KIND := "items"
const PLURAL := "s"


## One run of the text: plain text, or a term (its kind, its id and the name it shows).
class Run:
	extends RefCounted

	var kind: Kind = Kind.TEXT
	## What it shows: the text, or the term's display name.
	var text: String = ""
	## A term's id: the keyword, the card's id or the family's id ("" for text).
	var id: String = ""
	## The token as written ("{item:banana}"; "" for text).
	var token: String = ""

	func _init(run_kind: Kind, shown: String, term_id: String = "", written: String = "") -> void:
		kind = run_kind
		text = shown
		id = term_id
		token = written


## `text`'s runs, in order.
static func runs(text: String) -> Array[Run]:
	var found: Array[Run] = []
	var at: int = 0
	while at < text.length():
		var start: int = text.find(OPEN, at)
		var end: int = text.find(CLOSE, start) if start >= 0 else -1
		if start < 0 or end < 0:
			found.append(Run.new(Kind.TEXT, text.substr(at)))
			break
		if start > at:
			found.append(Run.new(Kind.TEXT, text.substr(at, start - at)))
		found.append(term(text.substr(start + 1, end - start - 1)))
		at = end + 1
	return found


## The run of a token's inside (`kind:id`), UNKNOWN when it names nothing.
static func term(inside: String) -> Run:
	var written: String = OPEN + inside + CLOSE
	var parts: PackedStringArray = inside.split(SEPARATOR, true, 1)
	if parts.size() != 2 or not KINDS.has(parts[0]):
		return Run.new(Kind.UNKNOWN, inside, "", written)
	var term_id: String = parts[1]
	var kind: Kind = KINDS[parts[0]]
	var shown: String = _name(kind, term_id)
	if shown.is_empty():
		return Run.new(Kind.UNKNOWN, term_id, term_id, written)
	if parts[0] == PLURAL_KIND and not shown.ends_with(PLURAL):
		shown += PLURAL
	return Run.new(kind, shown, term_id, written)


## `text` as plain words: every term as the name it shows.
static func plain(text: String) -> String:
	var words: String = ""
	for run: Run in runs(text):
		words += run.text
	return words


## The tokens in `text` that name nothing (as written).
static func unknown_tokens(text: String) -> PackedStringArray:
	var found: PackedStringArray = PackedStringArray()
	for run: Run in runs(text):
		if run.kind == Kind.UNKNOWN:
			found.append(run.token)
	return found


## The name a term of `kind` with `term_id` shows, or "" when it names nothing.
static func _name(kind: Kind, term_id: String) -> String:
	match kind:
		Kind.KEYWORD:
			return term_id if GlyphText.KEYWORD_TIPS.has(term_id) else ""
		Kind.ITEM, Kind.COUPON:
			var card: CardDefinition = FamilyPalette.data_card(term_id)
			if card == null or card.is_coupon() != (kind == Kind.COUPON):
				return ""
			return card.display_name
		Kind.FAMILY:
			var style: FamilyStyle = FamilyPalette.shared().style(term_id)
			return FamilyPalette.shared().display_name(term_id) if style != null else ""
	return ""
