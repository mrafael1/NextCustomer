class_name TipMarkup
extends RefCounted
## A hover tip's text markup (the hover tips revamp, mock-up docs/art/mockups/hover_tips.html,
## its tips.js): `{x2}` (or `{×2}`) a multiplier's amber pill, `{+5€}` money gained (green dark),
## `{0€}` nothing (tomato dark), `{+1}` a count (teal shade), `[PAIR]` a keyword's chip (`[PAIR!]`
## a keyword that is not working: tomato), `<Food>` a family's chip with its dot, and `~row|ROW~` a
## word underlined in mustard whose box (TipWords) shows beside the tip. TipText lays the runs out.
##
## auto() marks up a plain text (a card's rule from data, a perk's effect): its money, multipliers
## and counts, its keywords, its families' names and the first use of each word that has a box.

enum Run { TEXT, MONEY, ZERO, COUNT, PILL, KEYWORD, KEYWORD_BAD, FAMILY, TERM }

## The words that have a box (TipWords.WORDS), as auto() finds them: each written form and its key.
const TERM_FORMS: Dictionary[String, String] = {
	"row": "ROW",
	"rows": "ROW",
	"slot": "SLOT",
	"slots": "SLOT",
	"quota": "QUOTA",
	"coupon": "COUPON",
	"coupons": "COUPON",
	"family": "FAMILY",
	"families": "FAMILY",
	"PREMIUM": "PREMIUM",
}
## Families auto() leaves as text: the coupon mark is not a family a player collects.
const PLAIN_FAMILIES: Array[String] = ["Coupon"]
## Punctuation around a word, kept as text beside its run.
const LEADING := "(\"'"
const TRAILING := ",.:;!?)\"'…"
const MARK_PATTERN := "(\\{[^}]+\\}|\\[[^\\]]+\\]|<[^>]+>|~[^~]+~)"

static var _mark: RegEx
static var _money: RegEx
static var _times: RegEx
static var _count: RegEx


## `text`'s runs, in order: each {"run": Run, "text": what it shows, "key": a keyword's or a
## word's TipWords key, or a family's id}.
static func runs(text: String) -> Array[Dictionary]:
	var found: Array[Dictionary] = []
	var at: int = 0
	for match_found: RegExMatch in _mark_pattern().search_all(text):
		if match_found.get_start() > at:
			found.append(_run(Run.TEXT, text.substr(at, match_found.get_start() - at)))
		found.append(_marked(match_found.get_string()))
		at = match_found.get_end()
	if at < text.length():
		found.append(_run(Run.TEXT, text.substr(at)))
	return found


## The text without its markup, as it reads ("{x2}" reads "×2").
static func plain(text: String) -> String:
	var words: String = ""
	for run: Dictionary in runs(text):
		words += str(run["text"])
	return words


## The TipWords keys `text` names, in order (keywords, working or not, and boxed words), once each.
static func subs_of(text: String) -> PackedStringArray:
	var found: PackedStringArray = PackedStringArray()
	for run: Dictionary in runs(text):
		var kind: Run = run["run"]
		if kind in [Run.KEYWORD, Run.KEYWORD_BAD, Run.TERM]:
			var key: String = str(run["key"])
			if not key.is_empty() and not found.has(key):
				found.append(key)
	return found


## `text` as a sentence's start: lower case with a capital first letter ("SPOT CHECK" ->
## "Spot check"; not String.capitalize, which capitalises every word).
static func sentence_case(text: String) -> String:
	var low: String = text.to_lower()
	return low.left(1).to_upper() + low.substr(1)


## `text` (plain words, from data) marked up: money, multipliers, counts, keywords, families and
## the first use of each boxed word. Text that has markup already is returned as it is.
static func auto(text: String) -> String:
	if _mark_pattern().search(text) != null:
		return text
	var palette: FamilyPalette = FamilyPalette.shared()
	var termed: PackedStringArray = PackedStringArray()
	var words: PackedStringArray = PackedStringArray()
	for word: String in text.split(" ", false):
		var lead: String = ""
		var core: String = word
		while not core.is_empty() and LEADING.contains(core.left(1)):
			lead += core.left(1)
			core = core.substr(1)
		var tail: String = ""
		while not core.is_empty() and TRAILING.contains(core.right(1)):
			tail = core.right(1) + tail
			core = core.left(core.length() - 1)
		words.append(lead + _auto_word(core, palette, termed) + tail)
	return " ".join(words)


static func _auto_word(core: String, palette: FamilyPalette, termed: PackedStringArray) -> String:
	if core.is_empty():
		return core
	if _money_pattern().search(core) != null:
		return "{%s}" % core
	if _times_pattern().search(core) != null:
		return "{%s}" % core
	if _count_pattern().search(core) != null:
		return "{%s}" % core
	if GlyphText.KEYWORD_TIPS.has(core):
		return "[%s]" % core
	if (
		palette != null
		and palette.style(core) != null
		and not PLAIN_FAMILIES.has(core)
		and core.left(1) == core.left(1).to_upper()
	):
		return "<%s>" % core
	var key: String = TERM_FORMS.get(core, "")
	if not key.is_empty() and not termed.has(key):
		termed.append(key)
		return "~%s|%s~" % [core, key]
	return core


static func _marked(mark: String) -> Dictionary:
	var inside: String = mark.substr(1, mark.length() - 2)
	match mark.left(1):
		"{":
			if inside.begins_with("x") or inside.begins_with("×"):
				return _run(Run.PILL, "×" + inside.substr(1))
			if inside == "0€":
				return _run(Run.ZERO, inside)
			if inside.contains("€"):
				return _run(Run.MONEY, inside)
			return _run(Run.COUNT, inside)
		"[":
			var bad: bool = inside.ends_with("!")
			var word: String = inside.trim_suffix("!")
			return _run(Run.KEYWORD_BAD if bad else Run.KEYWORD, word, word)
		"<":
			return _run(Run.FAMILY, inside, inside)
		"~":
			var parts: PackedStringArray = inside.split("|")
			return _run(Run.TERM, parts[0], parts[1] if parts.size() > 1 else "")
	return _run(Run.TEXT, mark)


static func _run(kind: Run, text: String, key: String = "") -> Dictionary:
	return {"run": kind, "text": text, "key": key}


static func _mark_pattern() -> RegEx:
	if _mark == null:
		_mark = RegEx.create_from_string(MARK_PATTERN)
	return _mark


static func _money_pattern() -> RegEx:
	if _money == null:
		_money = RegEx.create_from_string("^[+−-]?\\d+(?:[.,]\\d+)?€$")
	return _money


static func _times_pattern() -> RegEx:
	if _times == null:
		_times = RegEx.create_from_string("^×\\d+(?:[.,]\\d+)?$")
	return _times


static func _count_pattern() -> RegEx:
	if _count == null:
		_count = RegEx.create_from_string("^[+−]\\d+%?$")
	return _count
