class_name HandbookEntry
extends Resource
## One entry of the STAFF HANDBOOK (v1.06, mock-up keywords_guide.html, variant A): a word the
## tickets or the monitor use, explained in one plain sentence (`rule`, HandbookMarkup: its terms
## named by id and drawn in their colours), shown on a real example row scored by the game's own
## Scoring (`example_row`, HandbookExample: the numbers can't drift from the rules; a test pins
## `example_total`); a family or the coupon intro has no example (the guide feedback of
## 2026-11-11 removed the notes and the USED BY cards). Its mark is drawn as the game draws it: a
## keyword's chip, a family's glyph, a coupon's icon, an icon or a plain word chip. Entries live
## in data/handbook/entries/, listed by data/handbook/handbook.tres (HandbookBook). Every default
## is neutral (empty).

## How the entry's mark is drawn: NONE nothing; KEYWORD or WORD a chip of `mark_value` (KeywordChip,
## a keyword's own face); FAMILY the glyph of family `mark_value`; CARD the icon of card
## `mark_value` (a coupon's, or an item's sprite); ICON `icon`.
enum Mark { NONE, KEYWORD, WORD, FAMILY, CARD, ICON }

## Where the rule's paragraphs part: the first is the keyword's tooltip (tip_rule); those after
## it show on the page only (BATCH's frame caps, 2026-11-12).
const PARAGRAPH := "\n\n"

## Its id: the handbook's deep links name it (HandbookBook.entry_for_keyword, entry_for_family).
@export var id: StringName = &""
## The tab it sits in (an id of HandbookBook.group_ids).
@export var group: StringName = &""
@export var title: String = ""
@export var mark: Mark = Mark.NONE
@export var mark_value: String = ""
@export var icon: Texture2D
## The rule in one plain sentence, in HandbookMarkup ({kw:CHAIN}, {item:banana}, ...); a page may
## add paragraphs after it (PARAGRAPH apart) that teach what the belt shows.
@export_multiline var rule: String = ""
## The worked example: these cards (ids in data/cards) in a row, scored with `example_events`
## (ids in data/inspections) and `example_redraws_left` redraws left; none for no example.
@export var example_row: PackedStringArray = PackedStringArray()
@export var example_events: PackedStringArray = PackedStringArray()
@export var example_redraws_left: int = 0
## A Price gun's relabels in the example (ScoreCredits.relabels), each "<slot>:<family>" (slot
## from 1: "1:Breakfast"); the clip shows them as the shift does (PinFlow.show_relabel).
@export var example_relabels: PackedStringArray = PackedStringArray()
## A quota for the example (0: none): the clip shows the receipt's TODAY'S TARGET against it.
@export var example_quota: int = 0
## The example row's total, pinned by a test (HandbookExample scores it).
@export var example_total: int = 0


## Whether the entry has an example row.
func has_example() -> bool:
	return not example_row.is_empty()


## The rule's first paragraph: a keyword's tooltip says its plain words (GlyphText.KEYWORD_TIPS).
func tip_rule() -> String:
	return rule.get_slice(PARAGRAPH, 0)


## The rule's paragraphs after the first (PARAGRAPH apart), which the page shows under its example
## (BATCH's frame caps); "" for none.
func page_notes() -> String:
	var at: int = rule.find(PARAGRAPH)
	return "" if at < 0 else rule.substr(at + PARAGRAPH.length())
