class_name FamilySticker
extends RefCounted
## The Family sticker (v1.29, the user's answer 2 of 2026-11-11): one coupon whose next item joins
## a family the player picks, in place of the Breakfast sticker and the Clearance tag (their files
## stay for old saves). Its rule is a GrantTagToNextSlotRule with `choices` (the families it can
## give); the family is per card instance:
## - picked on the belt while planning, any time before CHECKOUT, kept across shifts and in the
##   run save (RunState.sticker_families, pick);
## - else a starter pack's preset (StarterPackDefinition.sticker_family: the Breakfast run's
##   sticker is Breakfast) for the pack's own stickers (chosen);
## - else pre-filled from the row (prefill): the family most cards in the row read, else the
##   family of the item after the sticker's next item, else the first of `choices`, each one a
##   family the next item hasn't got yet (one it has would fizzle as "already").
## The run's picks and presets reach scoring as ScoreCredits.sticker_families, like a Price gun's
## relabels; a bare score (the simulator's totals) has none, so every sticker there is pre-filled.
## The UI asks here and displays; it never resolves a family itself.


## The Family sticker rule of `definition` (a GrantTagToNextSlotRule with choices), or null.
static func rule_of(definition: CardDefinition) -> GrantTagToNextSlotRule:
	if definition == null:
		return null
	for rule: Rule in definition.rules:
		var grant: GrantTagToNextSlotRule = rule as GrantTagToNextSlotRule
		if grant != null and not grant.choices.is_empty():
			return grant
	return null


## Whether `definition` is a Family sticker (its family is picked).
static func is_family_sticker(definition: CardDefinition) -> bool:
	return rule_of(definition) != null


## The family the sticker in `slot` gives while `state` is scored: the run's pick or preset
## (ScoreCredits.sticker_families) when it is one of `choices`, else prefill.
static func family_for(state: ScoreState, slot: int, choices: PackedStringArray) -> String:
	if state.credits != null:
		var chosen_tag: String = state.credits.sticker_families.get(state.row[slot].instance_id, "")
		if choices.has(chosen_tag):
			return chosen_tag
	return prefill(state, slot, choices)


## The family a sticker in `slot` fills itself in with (the user's answer 2: pre-filled with a
## sensible family): of `choices`, those the next item (slot + 1) hasn't got, the one most cards
## in the row read (a family rule's tag, a TAG match, an old sticker's grant; ties: `choices`
## order); with none read, the family of the item after the next one (joining the two); else the
## first. With no product next, the most read, else the first of `choices`.
static func prefill(state: ScoreState, slot: int, choices: PackedStringArray) -> String:
	var target: int = slot + 1
	var open: PackedStringArray = PackedStringArray()
	for tag: String in choices:
		if not state.is_product(target) or not state.has_tag(target, tag):
			open.append(tag)
	if open.is_empty():
		return choices[0] if not choices.is_empty() else ""
	var best: String = ""
	var best_count: int = 0
	for tag: String in open:
		var count: int = 0
		for other: int in range(state.size()):
			if other != slot and reads(state.definition(other), tag):
				count += 1
		if count > best_count:
			best = tag
			best_count = count
	if not best.is_empty():
		return best
	if state.is_product(target) and state.is_product(target + 1):
		for tag: String in open:
			if state.has_tag(target + 1, tag):
				return tag
	return open[0]


## Whether a rule of `definition` reads the family `tag`: a family rule's own tag
## (CardAffinity.family_of), a TAG match (Butter's "per Bakery beside") or a fixed sticker's
## grant. A penalty's tag (ZeroPayoutBesideTagRule) never counts: a pre-fill never picks a family
## that zeroes a card.
static func reads(definition: CardDefinition, tag: String) -> bool:
	for rule: Rule in definition.product_card().rules:
		if CardAffinity.family_of(rule) == tag:
			return true
		var adjacent: AdjacentMatchBonusRule = rule as AdjacentMatchBonusRule
		if adjacent != null and adjacent.match_by == AdjacentMatchBonusRule.Match.TAG:
			if adjacent.match_value == tag:
				return true
		var grant: GrantTagToNextSlotRule = rule as GrantTagToNextSlotRule
		if grant != null and grant.choices.is_empty() and grant.tag == tag:
			return true
	return false


## The family `card` (a Family sticker of the run) was given: the player's pick, else its starter
## pack's preset, else "" (pre-filled from the row when scored).
static func chosen(run: RunState, card: CardInstance) -> String:
	var picked: String = run.sticker_families.get(card.instance_id, "")
	if not picked.is_empty():
		return picked
	return _preset(run).get(card.instance_id, "")


## Every chosen family of the run's Family stickers (picks and presets), by instance id: what
## ScoreCredits.for_run hands scoring.
static func chosen_all(run: RunState) -> Dictionary[int, String]:
	var families: Dictionary[int, String] = _preset(run)
	for id: int in run.sticker_families:
		families[id] = run.sticker_families[id]
	return families


## A starter pack's preset (StarterPackDefinition.sticker_family), for the pack's own dealt
## Family stickers only: the deck's copies made from the starting deck's pack cards (the cards
## after its core cards, Deck.from_definition giving them the instance ids from
## Deck.FIRST_INSTANCE_ID in order). A copy drafted later, or a save whose pack slice holds the
## pack's former cards (the old Breakfast sticker), gets none.
static func _preset(run: RunState) -> Dictionary[int, String]:
	var preset: Dictionary[int, String] = {}
	var pack: StarterPackDefinition = null
	if run.starter != null:
		pack = run.starter.starter_pack
	if pack == null or pack.sticker_family.is_empty() or run.deck == null:
		return preset
	var first: int = run.starter.core_cards.size()
	var last: int = mini(first + pack.cards.size(), run.starter.cards.size())
	var dealt: Dictionary[int, bool] = {}
	for index: int in range(first, last):
		if is_family_sticker(run.starter.cards[index]):
			dealt[index + Deck.FIRST_INSTANCE_ID] = true
	for card: CardInstance in run.deck.cards:
		if dealt.has(card.instance_id) and is_family_sticker(card.definition):
			preset[card.instance_id] = pack.sticker_family
	return preset


## The families `card` may be given now: its rule's choices while the run plans and the card is
## on the belt (a Double checkout's checked-out row 1 aside); none otherwise.
static func choices_now(run: RunState, card: CardInstance) -> PackedStringArray:
	var rule: GrantTagToNextSlotRule = rule_of(card.definition)
	if rule == null or run.phase != RunState.Phase.PLANNING or not run.row.has(card):
		return PackedStringArray()
	return rule.choices


## The item the Family sticker `card` on the belt gives its family to (the row's next card, a
## product), or null.
static func next_item(run: RunState, card: CardInstance) -> CardInstance:
	var slot: int = run.row.find(card)
	if slot < 0 or slot + 1 >= run.row.size():
		return null
	var next: CardInstance = run.row[slot + 1]
	return next if next.definition.is_product() else null


## The families of `card`'s choices its next item already has on the run's preview (a pick of one
## would fizzle as "already"): the picker marks them. Empty with no item next.
static func held(run: RunState, card: CardInstance) -> PackedStringArray:
	var found: PackedStringArray = PackedStringArray()
	var rule: GrantTagToNextSlotRule = rule_of(card.definition)
	if rule == null or next_item(run, card) == null:
		return found
	var slot: int = run.row.find(card)
	var result: ScoreResult = run.preview()
	if slot + 1 >= result.tags.size():
		return found
	var gained: String = ""
	for step: ScoreStep in result.steps:
		var own: bool = step.source_slot == slot and step.slot == slot + 1
		if own and step.step_type == ScoreStep.StepType.TAG_ADDED:
			gained = step.tag
	for tag: String in rule.choices:
		if tag != gained and result.tags[slot + 1].has(tag):
			found.append(tag)
	return found


## Picks `tag` for the Family sticker `card` on the belt (free, any number of times before
## CHECKOUT; kept across shifts). False, changing nothing, when not allowed (choices_now).
static func pick(run: RunState, card: CardInstance, tag: String) -> bool:
	if not choices_now(run, card).has(tag):
		return false
	run.sticker_families[card.instance_id] = tag
	return true


## The family the sticker in `slot` of `result` gave or tried to give (its TAG_ADDED step, or its
## fizzle's, which carries the family too); "" for none.
static func given(result: ScoreResult, slot: int) -> String:
	if result == null:
		return ""
	for step: ScoreStep in result.steps:
		if step.source_slot != slot or step.source_kind != ScoreStep.SourceKind.CARD:
			continue
		if step.step_type == ScoreStep.StepType.TAG_ADDED:
			return step.tag
		if step.step_type == ScoreStep.StepType.WASTED and not step.tag.is_empty():
			return step.tag
	return ""
