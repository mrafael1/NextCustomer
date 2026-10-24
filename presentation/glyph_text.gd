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

## Punctuation that may follow a family's name and stays text after its glyph.
const TRAILING := ",.:;!?)"


## The text's unbreakable pieces, in order, each an Array of runs; a line may break between
## two pieces (where the text had a space). A glued piece's text run ends with its space ("next
## 2 "), so the glyph follows it on the line.
static func pieces(text: String, palette: FamilyPalette) -> Array[Array]:
	var found: Array[Array] = []
	for word: String in text.split(" ", false):
		var stem: String = word.rstrip(TRAILING)
		var family: String = palette.family_for_word(stem) if not stem.is_empty() else ""
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


static func is_glyph(run: Dictionary) -> bool:
	return not str(run["family"]).is_empty()


## Whether a word is a count: digits only ("2", never "+2" or "×2").
static func _is_count(word: String) -> bool:
	return not word.is_empty() and word.is_valid_int() and word[0] >= "0" and word[0] <= "9"


## Whether the last piece is one plain text word (a glyph can be glued to it).
static func _is_plain(found: Array[Array]) -> bool:
	if found.is_empty():
		return false
	var last: Array = found[found.size() - 1]
	return last.size() == 1 and not is_glyph(last[0] as Dictionary)


static func _pop_text(found: Array[Array]) -> String:
	var last: Array = found.pop_back()
	return str((last[0] as Dictionary)["text"])


static func _append(found: Array[Dictionary], run: Dictionary) -> void:
	if not found.is_empty() and not is_glyph(run) and not is_glyph(found[found.size() - 1]):
		found[found.size() - 1] = text_run(str(found[found.size() - 1]["text"]) + str(run["text"]))
	else:
		found.append(run)
