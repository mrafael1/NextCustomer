class_name GlyphText
extends RefCounted
## Sticker text with its family names drawn as glyphs (#105, mock-up readability v3, rich()): a
## card's formatted summary ("+1 per earlier Breakfast") split into runs of text and glyphs, so a
## label draws the Breakfast mug where the word was. A word is a glyph when it is a family's id
## (case-sensitive, as cards write tags) or one of its `words` (the coupon mark's "coupon"),
## with any trailing punctuation kept as text after it.
##
## A run is a Dictionary: {"text": String, "family": ""} for text, {"text": word, "family":
## id} for a glyph (the word it replaces, e.g. "coupon" for the coupon mark). Text never wraps
## inside a piece (pieces()): a glyph is glued to the word before it, and to the word before
## that too when that word is a count ("next 2 Food" wraps as one piece), so a glyph never
## starts a line alone.
##
## A keyword (#128: CardText.BATCH_WORD, CHAIN_WORD and WASTED_WORD, from a template's `{batch}`,
## `{chain}` or `{wasted}`) is a keyword run, {"text": word, "family": "", "keyword": word}, that
## a label draws as a boxed chip with its tooltip (KEYWORD_TIPS). It is glued to the plain word
## after it ("BATCH 1st:" wraps as one piece), so a chip never ends a line alone.

## Punctuation that may follow a family's name (or a keyword) and stays text after its glyph (or
## chip); the ellipsis of a line the monitor cuts short (MonitorItemColumn) too.
const TRAILING := ",.:;!?)…"
## Each keyword's tooltip (#128, the approved Bound strip mock-up): the keyword, then what it
## means; keyword_tip() fills in its least size (KEYWORD_SIZES).
const KEYWORD_TIPS: Dictionary[String, String] = {
	CardText.BATCH_WORD:
	(
		"BATCH · %d or more Bakery side by side make one batch. "
		+ "Each card's line says where in its batch it works."
	),
	CardText.CHAIN_WORD:
	(
		"CHAIN · %d or more Bananas linked one after another. "
		+ "Each Banana adds the price of the one before it. "
		+ "Each card's line says where by the chain it works."
	),
	CardText.WASTED_WORD:
	(
		"WASTED · An item whose rule did nothing where it stands. "
		+ "Some Clearance items pay for WASTED items."
	),
	CardText.PAIR_WORD:
	(
		"PAIR · A PAIR item beside the partner its line names (Cheese beside Bread). "
		+ "Cream pays for each PAIR in the row."
	),
	CardText.MORNING_WORD:
	(
		"MORNING · The row's opening run of Breakfast items, from the first item "
		+ "until one without Breakfast. Coupons don't end it."
	),
}
## The least size each keyword's tooltip names (its `%d`).
const KEYWORD_SIZES: Dictionary[String, int] = {
	CardText.BATCH_WORD: CardBatch.MIN_SIZE,
	CardText.CHAIN_WORD: CardChain.MIN_SIZE,
}


## The text's unbreakable pieces, in order, each an Array of runs; a line may break between
## two pieces (where the text had a space). A glued piece's text run ends with its space ("next
## 2 "), so the glyph follows it on the line.
## `live` (#128 v3, Stale popcorn's ×N) maps a live word to its tooltip: that word is a keyword run
## too (a chip), with its own tip (run_tip) instead of a KEYWORD_TIPS one.
static func pieces(text: String, palette: FamilyPalette, live: Dictionary = {}) -> Array[Array]:
	var found: Array[Array] = []
	var after_keyword: bool = false
	for word: String in text.split(" ", false):
		var stem: String = word.rstrip(TRAILING)
		if KEYWORD_TIPS.has(stem) or live.has(stem):
			var keyword: Array = [keyword_run(stem, str(live.get(stem, "")))]
			if stem.length() < word.length():
				keyword.append(text_run(word.substr(stem.length())))
			found.append(keyword)
			after_keyword = stem.length() == word.length()
			continue
		var family: String = palette.family_for_word(stem) if not stem.is_empty() else ""
		if family.is_empty() and after_keyword:
			# The word after a keyword joins its piece.
			found[found.size() - 1].append(text_run(" " + word))
			after_keyword = false
			continue
		after_keyword = false
		if family.is_empty():
			found.append([text_run(word)])
			continue
		var glued: String = ""
		if _is_plain(found):
			glued = _pop_text(found) + " "
			if _is_count(glued.strip_edges()) and _is_plain(found):
				glued = _pop_text(found) + " " + glued
		var piece: Array = []
		if not glued.is_empty():
			piece.append(text_run(glued))
		piece.append(glyph_run(family, stem))
		if stem.length() < word.length():
			piece.append(text_run(word.substr(stem.length())))
		found.append(piece)
	return found


## The text's runs in order, the pieces joined by spaces (adjacent text merged).
static func runs(text: String, palette: FamilyPalette) -> Array[Dictionary]:
	var found: Array[Dictionary] = []
	var all: Array[Array] = pieces(text, palette)
	for index: int in all.size():
		if index > 0:
			_append(found, text_run(" "))
		for run: Dictionary in all[index]:
			_append(found, run)
	return found


## The tooltip of `keyword` (a KEYWORD_TIPS key), or "".
static func keyword_tip(keyword: String) -> String:
	if not KEYWORD_TIPS.has(keyword):
		return ""
	if KEYWORD_SIZES.has(keyword):
		return KEYWORD_TIPS[keyword] % KEYWORD_SIZES[keyword]
	return KEYWORD_TIPS[keyword]


## The keywords the text draws as chips, in order (repeats kept).
static func keywords(text: String, palette: FamilyPalette) -> PackedStringArray:
	var found: PackedStringArray = PackedStringArray()
	for run: Dictionary in runs(text, palette):
		if is_keyword(run):
			found.append(str(run["keyword"]))
	return found


## The families the text draws as glyphs, in order (repeats kept).
static func families(text: String, palette: FamilyPalette) -> PackedStringArray:
	var found: PackedStringArray = PackedStringArray()
	for run: Dictionary in runs(text, palette):
		if is_glyph(run):
			found.append(str(run["family"]))
	return found


static func text_run(text: String) -> Dictionary:
	return {"text": text, "family": ""}


## A glyph run for `family`, replacing `word` (the family's id when empty).
static func glyph_run(family: String, word: String = "") -> Dictionary:
	return {"text": word if not word.is_empty() else family, "family": family}


## A keyword run for `word` (a KEYWORD_TIPS key), drawn as a chip.
static func keyword_run(word: String, tip: String = "") -> Dictionary:
	if not tip.is_empty():
		return {"text": word, "family": "", "keyword": word, "tip": tip}
	return {"text": word, "family": "", "keyword": word}


## A keyword run's tooltip: a live word's own (keyword_run's `tip`), else keyword_tip's.
static func run_tip(run: Dictionary) -> String:
	if run.has("tip"):
		return str(run["tip"])
	return keyword_tip(str(run.get("keyword", "")))


## Whether a keyword run is a live word (its own tip): a value chip, not a family keyword.
static func is_live(run: Dictionary) -> bool:
	return run.has("tip")


static func is_glyph(run: Dictionary) -> bool:
	return not str(run["family"]).is_empty()


static func is_keyword(run: Dictionary) -> bool:
	return run.has("keyword")


## Whether a run is plain text (neither a glyph nor a keyword).
static func is_text(run: Dictionary) -> bool:
	return not is_glyph(run) and not is_keyword(run)


## Whether a word is a count: digits only ("2", never "+2" or "×2").
static func _is_count(word: String) -> bool:
	return not word.is_empty() and word.is_valid_int() and word[0] >= "0" and word[0] <= "9"


## Whether the last piece is one plain text word (a glyph can be glued to it).
static func _is_plain(found: Array[Array]) -> bool:
	if found.is_empty():
		return false
	var last: Array = found[found.size() - 1]
	return last.size() == 1 and is_text(last[0] as Dictionary)


static func _pop_text(found: Array[Array]) -> String:
	var last: Array = found.pop_back()
	return str((last[0] as Dictionary)["text"])


static func _append(found: Array[Dictionary], run: Dictionary) -> void:
	if not found.is_empty() and is_text(run) and is_text(found[found.size() - 1]):
		found[found.size() - 1] = text_run(str(found[found.size() - 1]["text"]) + str(run["text"]))
	else:
		found.append(run)
