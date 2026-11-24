class_name GradeRules
extends RefCounted
## The difficulty grades' twists in play (#182, v1.49, decided with the user on 2026-11-23; full
## build plan 7.5): the graded balance lists them (BalanceDefinition.twists, GradeApply) and the
## run keeps their state (RunState.twists, GradeState). Pure static rules; every random choice
## uses the run's RNG, and only when a twist plays, so a run without twists draws as before.
##
## Shrinkflation (grade 2): as a week ends (the next week's first shift starts), the product
## checked out most that week loses the twist's euros of its price for the rest of the run (ties
## drawn with the run's RNG, among the ids in order), stacking, never below the floor; a product
## at the floor no longer counts. It plays as one event of tone TWIST at the end of the shift's
## events (tail_events), its steps flying from the items.
## Expiry dates (grade 3): a coupon the machine gives plays coupon_shifts shifts, then leaves the
## deck as the next shift starts; as a week ends, items_min to items_max of the products the
## machine gave that week (and still in the deck) get a BEST BEFORE date item_shifts shifts after
## they were given. The starting deck and the pins' cards never expire, and an upgraded product
## loses its date (on_upgraded).
## The Picky regular (grade 5): from its start week on, one family per shift, drawn for the whole
## week as it is drawn, never the one of the day before, is on promo, each day at its own cut drawn
## with it (15 to 30% in 5% steps: its items pay 75% on a "-25%" day). It plays as a day event of
## tone TWIST after the week event (day_events), on the day calendar.

const SHRINK_NEWS := "Shrinkflation: %s -%d€"
const BEST_BEFORE_NEWS := "Best before: %s"
const EXPIRED_NEWS := "Expired: %s"
## The Picky regular's notice key for the family.
const FAMILY_KEY := "{family}"


static func shrinkflation(balance: BalanceDefinition) -> ShrinkflationTwist:
	for twist: GradeTwist in balance.twists:
		if twist is ShrinkflationTwist:
			return twist as ShrinkflationTwist
	return null


static func expiry(balance: BalanceDefinition) -> ExpiryTwist:
	for twist: GradeTwist in balance.twists:
		if twist is ExpiryTwist:
			return twist as ExpiryTwist
	return null


static func picky(balance: BalanceDefinition) -> PickyRegularTwist:
	for twist: GradeTwist in balance.twists:
		if twist is PickyRegularTwist:
			return twist as PickyRegularTwist
	return null


## The twists' events the shift plays after its week event (WeekSchedule.shift_events): the
## Picky regular's day.
static func day_events(run: RunState) -> Array[InspectionDefinition]:
	var found: Array[InspectionDefinition] = []
	var event: InspectionDefinition = picky_event(run)
	if event != null:
		found.append(event)
	return found


## The twists' events the shift plays last, after the worn pins' (WeekSchedule.shift_events):
## Shrinkflation's, once a product has shrunk. Like a pin's, their steps fly from the items.
static func tail_events(run: RunState) -> Array[InspectionDefinition]:
	var found: Array[InspectionDefinition] = []
	var event: InspectionDefinition = shrink_event(run)
	if event != null:
		found.append(event)
	return found


## Shrinkflation's event for `run` (a copy of the twist's carrying the run's shrinks), or null.
static func shrink_event(run: RunState) -> InspectionDefinition:
	var twist: ShrinkflationTwist = shrinkflation(run.balance)
	if twist == null or twist.event == null or run.twists.shrinks.is_empty():
		return null
	if run.twists.shrink_event == null:
		var event: InspectionDefinition = twist.event.duplicate() as InspectionDefinition
		var rules: Array[InspectionRule] = []
		for rule: InspectionRule in twist.event.rules:
			var copy: InspectionRule = rule.duplicate() as InspectionRule
			if copy is ProductShrinkRule:
				(copy as ProductShrinkRule).shrinks = run.twists.shrinks.duplicate()
			rules.append(copy)
		event.rules = rules
		run.twists.shrink_event = event
	return run.twists.shrink_event


## The family out of favour on the 1-based `shift_number` (0: the current shift), or "".
## A day before the twist's start week has none (a save from before v1.49's play test may still
## name one there).
static func picky_family(run: RunState, shift_number: int = 0) -> String:
	var twist: PickyRegularTwist = picky(run.balance)
	if twist == null:
		return ""
	var shift: int = shift_number if shift_number > 0 else run.shift_index + 1
	if WeekSchedule.week_of(run.balance, shift) + 1 < twist.start_week:
		return ""
	return run.twists.picky.get(shift, "")


## The Picky regular's cut (percent) on the 1-based `shift_number` (0: the current shift): the one
## drawn with its family (GradeState.promo_cuts), else the twist's default_cut; 0 on a day without
## one.
static func picky_cut(run: RunState, shift_number: int = 0) -> int:
	var twist: PickyRegularTwist = picky(run.balance)
	if twist == null or picky_family(run, shift_number).is_empty():
		return 0
	var shift: int = shift_number if shift_number > 0 else run.shift_index + 1
	return clampi(run.twists.promo_cuts.get(shift, twist.default_cut()), 0, 100)


## The share (percent) today's promo family pays (100 less its cut), 100 for none.
static func picky_percent(run: RunState) -> int:
	return 100 - picky_cut(run)


## Today's cut as its promo tag reads it ("-25%"), or "" without one.
static func promo_text(run: RunState) -> String:
	var cut: int = picky_cut(run)
	return PickyRegularTwist.off_text(cut) if cut > 0 else ""


## Whether `card`, alone in a basket, is on today's promo: a product carrying today's family among
## its printed families or the Price gun's label on it (the tags the score starts from). On the
## belt the score's own tags decide (promo_slot).
static func on_promo(run: RunState, card: CardInstance) -> bool:
	if card == null or not card.definition.is_product() or picky_cut(run) <= 0:
		return false
	var family: String = picky_family(run)
	return card.definition.tags.has(family) or PinPlay.relabel_of(run, card) == family


## Whether the belt's `slot` is cut by today's promo in `result` (its score): exactly the
## FamilyPayCutRule's test, a product carrying today's family among the score's tags after its
## context pass (the Price gun's label and every other granted family included).
static func promo_slot(run: RunState, result: ScoreResult, slot: int, card: CardInstance) -> bool:
	if result == null or slot < 0 or slot >= result.tags.size() or card == null:
		return false
	if not card.definition.is_product() or picky_cut(run) <= 0:
		return false
	return result.tags[slot].has(picky_family(run))


## The Picky regular's event for the shift (a copy of the twist's naming its family, at its cut),
## or null.
static func picky_event(run: RunState, shift_number: int = 0) -> InspectionDefinition:
	var twist: PickyRegularTwist = picky(run.balance)
	var family: String = picky_family(run, shift_number)
	if twist == null or twist.event == null or family.is_empty():
		return null
	var cut: int = picky_cut(run, shift_number)
	var key: String = "%s|%d" % [family, cut]
	if not run.twists.picky_events.has(key):
		var event: InspectionDefinition = twist.event.duplicate() as InspectionDefinition
		event.display_name = _day_words(twist.event.display_name, family, cut)
		event.notice_text = _day_words(twist.event.notice_text, family, cut)
		event.chip_text = _day_words(twist.event.chip_text, family, cut)
		var rules: Array[InspectionRule] = []
		for rule: InspectionRule in twist.event.rules:
			var copy: InspectionRule = rule.duplicate() as InspectionRule
			copy.receipt_text = _day_words(copy.receipt_text, family, cut)
			if copy is FamilyPayCutRule:
				(copy as FamilyPayCutRule).tag = family
				(copy as FamilyPayCutRule).pay_percent = 100 - cut
			rules.append(copy)
		event.rules = rules
		run.twists.picky_events[key] = event
	return run.twists.picky_events[key]


## A Picky regular day's `text` with its family and cut in place of their keys.
static func _day_words(text: String, family: String, cut: int) -> String:
	return PickyRegularTwist.format_day(text.replace(FAMILY_KEY, family), cut)


## The euros `definition` has lost to Shrinkflation (its product's shrink, kept above the floor);
## 0 for none.
static func shrink_of(run: RunState, definition: CardDefinition) -> int:
	var twist: ShrinkflationTwist = shrinkflation(run.balance)
	if twist == null or definition == null or not definition.is_product():
		return 0
	var shrink: int = run.twists.shrinks.get(definition.product_card().id, 0)
	return mini(shrink, maxi(definition.base - _floor(twist), 0))


## The shifts `card` still plays before it expires, the coming or current one included; -1 when
## it never expires.
static func shifts_left(run: RunState, card: CardInstance) -> int:
	if card == null or not run.twists.expiry.has(card.instance_id):
		return -1
	return maxi(run.twists.expiry[card.instance_id] - playing_shift(run) + 1, 0)


## The 1-based shift being planned, or after a checkout the next one.
static func playing_shift(run: RunState) -> int:
	var planning: bool = run.phase in [RunState.Phase.PLANNING, RunState.Phase.CHOOSE_START]
	return run.shift_index + (1 if planning else 2)


## The machine gave `card` (RewardMachine.pick): a coupon gets its expiry date, a product joins
## the week's BEST BEFORE candidates.
static func on_added(run: RunState, card: CardInstance) -> void:
	var twist: ExpiryTwist = expiry(run.balance)
	if twist == null or card == null:
		return
	var taken: int = run.shift_index + 1
	if card.definition.is_coupon():
		if twist.coupon_shifts > 0:
			run.twists.expiry[card.instance_id] = taken + twist.coupon_shifts
	elif twist.item_shifts > 0:
		run.twists.week_added[card.instance_id] = taken


## The machine upgraded `card` (RewardMachine.pick; Deck.upgrade keeps its instance id): a dated
## product's BEST BEFORE date is cancelled and it never gets one, so the upgraded item never
## expires (the user's play test of 2026-11-24). A coupon keeps its date.
static func on_upgraded(run: RunState, card: CardInstance) -> void:
	if card == null or not card.definition.is_product():
		return
	run.twists.expiry.erase(card.instance_id)
	run.twists.week_added.erase(card.instance_id)


## A new shift starts (RunState.next_shift, its index already raised, before its week is drawn):
## a week's end shrinks its top product and dates its new items; then what expired leaves the
## deck. The shift's news lists what changed.
static func start_shift(run: RunState) -> void:
	if run.balance.twists.is_empty():
		return
	var shift: int = run.shift_index + 1
	run.twists.news = PackedStringArray()
	run.twists.news_shift = shift
	run.twists.clear_fresh()
	run.twists.fresh_promo = picky(run.balance) != null  # Its promo tags stamp on (PromoTag).
	if shift > 1 and WeekSchedule.is_week_start(run.balance, shift):
		_shrink_week(run, shift - 1)
		_date_week(run)
	_expire(run, shift)


## A new week was drawn (RunState's week plan): the Picky regular's families and cuts for its
## days, each day's family then its cut.
static func plan_week(run: RunState) -> void:
	var twist: PickyRegularTwist = picky(run.balance)
	if twist == null or twist.families.is_empty():
		return
	var shift: int = run.shift_index + 1
	if WeekSchedule.week_of(run.balance, shift) + 1 < twist.start_week:
		run.twists.picky_events = {}
		return
	var first: int = WeekSchedule.first_shift(run.balance, shift)
	var present: PackedStringArray = PackedStringArray()
	for family: String in twist.families:
		for card: CardInstance in run.deck.cards:
			if card.definition.is_product() and card.definition.tags.has(family):
				present.append(family)
				break
	if present.size() < 2:
		present = twist.families
	for day: int in range(first, first + WeekSchedule.days_in(run.balance, shift)):
		var options: PackedStringArray = present.duplicate()
		var before: String = run.twists.picky.get(day - 1, "")
		if options.size() > 1 and options.has(before):
			options.remove_at(options.find(before))
		run.twists.picky[day] = options[run.rng.randi_range(0, options.size() - 1)]
		run.twists.promo_cuts[day] = twist.draw_cut(run.rng)
	run.twists.picky_events = {}


## The current shift's opening news (one line each), or "" (none, or another shift's).
static func notice(run: RunState) -> String:
	if run.twists.news_shift != run.shift_index + 1:
		return ""
	return "\n".join(run.twists.news)


## The balance simulator's guess of how much of a new `card`'s value lasts: the share of the run's
## shifts left that a coupon plays before it expires (1 without Expiry dates, or for a product,
## which only may get a date).
static func lasting_share(run: RunState, card: CardDefinition) -> float:
	var twist: ExpiryTwist = expiry(run.balance)
	if twist == null or card == null or not card.is_coupon() or twist.coupon_shifts <= 0:
		return 1.0
	var left: int = run.shift_count() - (run.shift_index + 1)
	return minf(1.0, twist.coupon_shifts / float(left)) if left > 0 else 1.0


## Shrinkflation at the end of the week of the 1-based `last_shift`.
static func _shrink_week(run: RunState, last_shift: int) -> void:
	var twist: ShrinkflationTwist = shrinkflation(run.balance)
	if twist == null or twist.euros <= 0:
		return
	var week: int = WeekSchedule.week_of(run.balance, last_shift)
	var counts: Dictionary[StringName, int] = {}
	var cards: Dictionary[StringName, CardDefinition] = {}
	for record: ShiftRecord in run.history:
		if WeekSchedule.week_of(run.balance, record.shift) != week:
			continue
		for played: CardDefinition in record.played:
			var plain: CardDefinition = played.product_card() if played != null else null
			if plain == null or not plain.is_product() or _room(run, twist, plain) <= 0:
				continue
			counts[plain.id] = counts.get(plain.id, 0) + 1
			cards[plain.id] = plain
	if counts.is_empty():
		return
	var top: int = counts.values().max()
	var tied: Array[StringName] = []
	for id: StringName in counts:
		if counts[id] == top:
			tied.append(id)
	tied.sort_custom(func(a: StringName, b: StringName) -> bool: return String(a) < String(b))
	var picked: StringName = tied[0]
	if tied.size() > 1:
		picked = tied[run.rng.randi_range(0, tied.size() - 1)]
	var lost: int = mini(twist.euros, _room(run, twist, cards[picked]))
	run.twists.shrinks[picked] = run.twists.shrinks.get(picked, 0) + lost
	run.twists.fresh_shrunk.append(picked)
	run.twists.clear_events()
	run.twists.news.append(SHRINK_NEWS % [cards[picked].display_name, lost])


## Expiry dates at a week's end: BEST BEFORE on some of the week's new products.
static func _date_week(run: RunState) -> void:
	var twist: ExpiryTwist = expiry(run.balance)
	var added: Dictionary[int, int] = run.twists.week_added
	run.twists.week_added = {}
	if twist == null or twist.item_shifts <= 0 or added.is_empty():
		return
	var candidates: Array[CardInstance] = []
	for card: CardInstance in run.deck.cards:
		if added.has(card.instance_id) and not run.twists.expiry.has(card.instance_id):
			candidates.append(card)
	if candidates.is_empty():
		return
	var most: int = maxi(twist.items_max, twist.items_min)
	var count: int = mini(run.rng.randi_range(twist.items_min, most), candidates.size())
	var names: PackedStringArray = PackedStringArray()
	for index: int in range(count):
		var card: CardInstance = candidates.pop_at(run.rng.randi_range(0, candidates.size() - 1))
		run.twists.expiry[card.instance_id] = added[card.instance_id] + twist.item_shifts
		run.twists.fresh_dated.append(card.instance_id)
		names.append(card.definition.display_name)
	if not names.is_empty():
		run.twists.news.append(BEST_BEFORE_NEWS % ", ".join(names))


## The cards whose last shift is before the 1-based `shift` leave the deck.
static func _expire(run: RunState, shift: int) -> void:
	var names: PackedStringArray = PackedStringArray()
	var kept: Dictionary[int, int] = {}
	for card: CardInstance in run.deck.cards.duplicate():
		if not run.twists.expiry.has(card.instance_id):
			continue
		if run.twists.expiry[card.instance_id] < shift:
			run.deck.remove_card(card)
			run.twists.fresh_expired.append(card.definition)
			names.append(card.definition.display_name)
		else:
			kept[card.instance_id] = run.twists.expiry[card.instance_id]
	run.twists.expiry = kept  # A card swapped out meanwhile drops its date too.
	if not names.is_empty():
		run.twists.news.append(EXPIRED_NEWS % ", ".join(names))


## How many euros `plain` can still lose.
static func _room(run: RunState, twist: ShrinkflationTwist, plain: CardDefinition) -> int:
	var shrink: int = run.twists.shrinks.get(plain.id, 0)
	return maxi(plain.base - _floor(twist) - shrink, 0)


## The lowest price Shrinkflation leaves: its event's ProductShrinkRule.min_base (0 without one).
static func _floor(twist: ShrinkflationTwist) -> int:
	if twist.event != null:
		for rule: InspectionRule in twist.event.rules:
			if rule is ProductShrinkRule:
				return (rule as ProductShrinkRule).min_base
	return 0
