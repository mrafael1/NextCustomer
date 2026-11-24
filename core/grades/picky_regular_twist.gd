class_name PickyRegularTwist
extends GradeTwist
## The Picky regular (#182 grade 5, v1.49): from week `start_week` on, each shift one family,
## drawn with the run's RNG when its week is drawn and never the one of the shift before, is on
## promo: its items' price is cut by that shift's own percent, drawn with it from cut_min to
## cut_max in cut_step steps (the user's play test of 2026-11-24: "randomly each shift between
## -15% and -30%"), rounded down (event's FamilyPayCutRule, a copy per family and cut). Its words
## read as a store promo: "{off}" is the cut as a tag prints it ("-25%"), "{cut}" as a sentence
## says it ("25%": "Dairy price reduced by 25%"); a grade's rule line, with no shift, reads the
## range ("-15 to -30%"). The day calendar shows it with the family's glyph, the top bar a promo
## sign under the grade badge (PickySign) and each of the cut items on screen a red promo tag
## (PromoTag).

## The keys the data's words write the cut as.
const OFF_KEY := "{off}"
const CUT_KEY := "{cut}"
## The cut's words: as a tag ("-25%"), as a sentence ("25%"), and a range ("-15 to -30%").
const OFF_TEXT := "-%d%%"
const CUT_TEXT := "%d%%"
const RANGE_TEXT := "-%d to -%d%%"

## The families it picks from, as cards write them; only those in the deck's products when the
## week is drawn (all of them when the deck has none but one).
@export var families: PackedStringArray = PackedStringArray()
## The first week (1-based) with a Picky regular every day; the weeks before have none.
@export var start_week: int = 1
## Each shift's cut (percent off the family's items): from cut_min to cut_max, every cut_step.
@export_range(0, 100) var cut_min: int = 25
@export_range(0, 100) var cut_max: int = 25
@export_range(1, 100) var cut_step: int = 5
## The day event (tone TWIST) with one FamilyPayCutRule; its notice_text names the family as
## "{family}". A copy per family and cut carries it (GradeRules.picky_event). Its rule's
## pay_percent is the cut of a day that has none drawn (default_cut).
@export var event: InspectionDefinition


## The cuts a shift can draw, lowest first (cut_min alone when the range is empty).
func cut_options() -> Array[int]:
	var options: Array[int] = []
	var top: int = maxi(cut_max, cut_min)
	var cut: int = cut_min
	while cut <= top:
		options.append(cut)
		cut += maxi(cut_step, 1)
	return options


## A shift's cut, drawn with `rng` (the run's).
func draw_cut(rng: RandomNumberGenerator) -> int:
	var options: Array[int] = cut_options()
	return options[rng.randi_range(0, options.size() - 1)]


## The cut of a day with none drawn: 100 less its event's FamilyPayCutRule's share (0 for none).
func default_cut() -> int:
	if event == null:
		return 0
	for rule: InspectionRule in event.rules:
		if rule is FamilyPayCutRule:
			return 100 - (rule as FamilyPayCutRule).pay_percent
	return 0


## The cut as a promo tag prints it: "-25%" for 25.
static func off_text(cut: int) -> String:
	return OFF_TEXT % cut


## A grade's rule line: "{off}" the range of cuts ("-15 to -30%", or one cut's "-25%").
func format_text(text: String) -> String:
	var options: Array[int] = cut_options()
	var off: String = off_text(options[0])
	if options.size() > 1:
		off = RANGE_TEXT % [options[0], options[-1]]
	return text.replace(OFF_KEY, off)


## A day's words with its `cut`: "{off}" as "-25%", "{cut}" as "25%".
static func format_day(text: String, cut: int) -> String:
	return text.replace(OFF_KEY, off_text(cut)).replace(CUT_KEY, CUT_TEXT % cut)
