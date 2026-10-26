class_name StickerSpec
extends RefCounted
## One sticker on a planning item (#71, mock-up h1, H1_BUILD_SPEC.md section 2.1): an effect the
## item receives, read from one EffectLink. ADD is the cream "+N" price-gun label, MULTIPLY the
## gold "×N" starburst, COPY the teal "=€N" label, FIZZLE the grey "WASTED" label and MORE the
## grey "+N" fold chip the earliest stickers fold into from a stack's 4th sticker (#105 piece 3:
## PlanningLayer makes it). Pure data: it never scores.

enum Kind { ADD, MULTIPLY, COPY, FIZZLE, MORE }

## MORE's text: how many stickers it folds.
const MORE_TEXT := "+%d"

var kind: Kind = Kind.ADD
## The sticker's text: the link's token ("+3", "×3", "=€6", "WASTED") or MORE_TEXT.
var text: String = ""
## The giver's badge: NONE for the item's own rule.
var badge: GiverBadge.Kind = GiverBadge.Kind.NONE
## The badge's initials (GiverBadge.initials_for); empty for NONE and INSPECTION.
var badge_text: String = ""
## An ITEM badge's mini (CardDefinition.badge_mini_ref: the giver's, gold-outlined for GOLDEN);
## a LOYALTY badge's perk icon (UpgradeDefinition.icon_ref, #108 follow-up); empty for a product
## with none (the badge keeps its initials) and for the other badges.
var badge_mini: String = ""
## A LOYALTY badge's Aisle run tag colour (LoyaltyCard.run_mark_colour, #108 follow-up), or
## Color() for no tag.
var badge_run_colour: Color = Color()
## What caused the effect (EffectLink's cause).
var cause_kind: ScoreStep.SourceKind = ScoreStep.SourceKind.CARD
## CARD causes: the causing card's slot; otherwise -1.
var cause_slot: int = -1
## UPGRADE and INSPECTION causes: the index into the run's upgrades or the shift's inspections;
## otherwise -1.
var cause_index: int = -1
## The step's index in ScoreResult.steps (-1 for MORE).
var step_index: int = -1
## MORE: how many stickers it folds (0 for the other kinds).
var folds: int = 0


## A MORE sticker folding `count` stickers.
static func folded(count: int) -> StickerSpec:
	var spec: StickerSpec = StickerSpec.new()
	spec.kind = Kind.MORE
	spec.text = MORE_TEXT % count
	spec.folds = count
	return spec


## The sticker's identity across rebuilds (the slap plays only for a new key): its cause and
## text. The view adds the card instance.
func key() -> String:
	return "%d|%d|%d|%s" % [cause_kind, cause_slot, cause_index, text]


## Whether `slot`'s card caused it.
func caused_by_card(slot: int) -> bool:
	return cause_kind == ScoreStep.SourceKind.CARD and cause_slot == slot
