class_name HandbookBook
extends Resource
## The STAFF HANDBOOK's contents (v1.06, mock-up keywords_guide.html, variant A), as data in
## data/handbook/handbook.tres: its tabs (group_ids and their group_titles, in order) and every
## entry (HandbookEntry, in index order within each tab). The deep links find an entry from what a
## tooltip shows: a keyword's chip (entry_for_keyword), a family's glyph or colour
## (entry_for_family), a coupon's ticket (entry_for_card) or a line that opens with an entry's
## title (entry_titled). Every default is neutral (empty).

const PATH := "res://data/handbook/handbook.tres"

static var _shared: HandbookBook

@export var group_ids: Array[StringName] = []
@export var group_titles: PackedStringArray = PackedStringArray()
@export var entries: Array[HandbookEntry] = []
## The entry the handbook opens at the first time.
@export var first_entry: StringName = &""


## The game's handbook, loaded once.
static func shared() -> HandbookBook:
	if _shared == null:
		_shared = load(PATH) as HandbookBook
	return _shared


## The entry with this id, or null.
func entry(entry_id: StringName) -> HandbookEntry:
	for each: HandbookEntry in entries:
		if each.id == entry_id:
			return each
	return null


## The entries of tab `group_id`, in index order.
func entries_in(group_id: StringName) -> Array[HandbookEntry]:
	var found: Array[HandbookEntry] = []
	for each: HandbookEntry in entries:
		if each.group == group_id:
			found.append(each)
	return found


## The title of tab `group_id`, or "".
func group_title(group_id: StringName) -> String:
	var index: int = group_ids.find(group_id)
	return group_titles[index] if index >= 0 and index < group_titles.size() else ""


## The entry whose mark is `kind` of `value` (case-insensitive), or null.
func entry_marked(kind: HandbookEntry.Mark, value: String) -> HandbookEntry:
	for each: HandbookEntry in entries:
		if each.mark == kind and each.mark_value.nocasecmp_to(value) == 0:
			return each
	return null


## The entry of a keyword chip's word (CHAIN, MORNING, PAIR...), or null.
func entry_for_keyword(word: String) -> HandbookEntry:
	var found: HandbookEntry = entry_marked(HandbookEntry.Mark.KEYWORD, word)
	return found if found != null else entry_marked(HandbookEntry.Mark.WORD, word)


## The entry of family `family` (its id, as data/families names it), or null.
func entry_for_family(family: String) -> HandbookEntry:
	return entry_marked(HandbookEntry.Mark.FAMILY, family)


## The entry of card `card_id` (a coupon's), or null.
func entry_for_card(card_id: String) -> HandbookEntry:
	return entry_marked(HandbookEntry.Mark.CARD, card_id)


## The entry whose title opens `text` (case-insensitive, a whole word: "Opening deal: ×5 on the
## first item"), the longest such title, or null. One-word titles shorter than 4 letters never
## match.
func entry_titled(text: String) -> HandbookEntry:
	var found: HandbookEntry = null
	var lowered: String = text.to_lower()
	for each: HandbookEntry in entries:
		var title: String = each.title.to_lower()
		if title.length() < 4 or not lowered.begins_with(title):
			continue
		if lowered.length() > title.length() and lowered[title.length()].is_valid_identifier():
			continue
		if found == null or title.length() > found.title.length():
			found = each
	return found
