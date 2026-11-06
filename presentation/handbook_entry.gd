class_name HandbookEntry
extends Resource
## One entry of the STAFF HANDBOOK (v1.06, mock-up keywords_guide.html, variant A): a word the
## tickets, the monitor or the shift use, explained in one plain sentence (`rule`), shown on a
## real example row scored by the game's own Scoring (`example_row`, HandbookExample: the numbers
## can't drift from the rules; a test pins `example_total`), with a longer note (`details`) and
## the cards that use it. Its mark is drawn as the game draws it: a keyword's chip, a family's
## glyph, a coupon's icon, an icon or a plain word chip. Entries live in data/handbook/entries/,
## listed by data/handbook/handbook.tres (HandbookBook). Every default is neutral (empty).

## How the entry's mark is drawn: NONE nothing; KEYWORD or WORD a chip of `mark_value` (KeywordChip,
## a keyword's own face); FAMILY the glyph of family `mark_value`; CARD the icon of card
## `mark_value` (a coupon's, or an item's sprite); ICON `icon`.
enum Mark { NONE, KEYWORD, WORD, FAMILY, CARD, ICON }

## Its id: the handbook's deep links name it (HandbookBook.entry_for_keyword, entry_for_family).
@export var id: StringName = &""
## The tab it sits in (an id of HandbookBook.group_ids).
@export var group: StringName = &""
@export var title: String = ""
@export var mark: Mark = Mark.NONE
@export var mark_value: String = ""
@export var icon: Texture2D
## The rule in one plain sentence.
@export_multiline var rule: String = ""
## The worked example: these cards (ids in data/cards) in a row, scored with `example_events`
## (ids in data/inspections) and `example_redraws_left` redraws left; none for no example.
@export var example_row: PackedStringArray = PackedStringArray()
@export var example_events: PackedStringArray = PackedStringArray()
@export var example_redraws_left: int = 0
## The example row's total, pinned by a test (HandbookExample scores it).
@export var example_total: int = 0
## A short line after the example (what it shows), or the example itself when there is no row.
@export var example_note: String = ""
## The longer note: where it shows, who reads it, edge cases.
@export_multiline var details: String = ""
## The cards that use it (ids in data/cards), shown as their sprites.
@export var cards: PackedStringArray = PackedStringArray()


## Whether the entry has an example row.
func has_example() -> bool:
	return not example_row.is_empty()
