class_name CaptureGrades
extends RefCounted
## The screen capture's grade twists (#182, v1.49), to review their marks on the fixed shift:
## `--grades=<part>+...` plays it at grade 5 (GradeApply.balance_for: Shrinkflation, Expiry dates,
## the Picky regular) with these parts of a twist state set by hand. `shrink`: the belt's first
## product lost 1€ (its shrink sticker on the belt, in the hand and in the cart). `dates`: the
## hand's first product carries a BEST BEFORE date 3 shifts out and the belt's coupon its last
## shift. `picky`: today's Picky regular names the belt's second product's first family, on a day
## with no other day event (the calendar's page shows it), at the cut `cut<percent>` names (`cut15`;
## none: the twist's default), and `gun` gives the belt's first product without that family the
## Price gun's label for it (its promo tag shows). `notice`: the shift opens with the
## week-end news ("Shrinkflation: <item> -1€"). With `--deck=cart` (the deck view open) the parts
## mark the Cart's cards instead: `shrink` shrinks the first repeated product, `copies` dates one of
## its copies DATED_SHIFTS shifts out (the other undated) and `copytip` also hovers that stack, its
## tip open. `stamps<tenths>` plays the shift-opening stamps (GradeMoves) of the shrink and the
## dates set (and today's promo tags with `picky`), and `expired` adds the belt's coupon as an
## expired card (its ghost under the Cart button), frozen that many tenths of a second in.
## `--hover=grade` shows the top bar badge's tip. The file name gets grades_<parts>_.

const ARGUMENT := "--grades="
const GRADE := 5
const DATED_SHIFTS := 3
const SHRUNK_EUROS := 1


## Applies `arguments`' --grades on `screen`'s fixed shift; returns the file name's part ("" for
## none).
static func apply(screen: ShiftScreen, arguments: PackedStringArray) -> String:
	var spec: String = ""
	for argument: String in arguments:
		if argument.begins_with(ARGUMENT):
			spec = argument.trim_prefix(ARGUMENT)
	if spec.is_empty():
		return ""
	var parts: PackedStringArray = spec.split("+", false)
	var run: RunState = screen.run
	run.balance = GradeApply.balance_for(run.balance, GRADE)
	run.grade = GRADE
	(screen._top_bar as TopBar).show_grade(run)
	if screen._deck_view.visible:
		_apply_deck(screen, parts)
		return "grades_%s_" % "_".join(parts)
	var shift: int = run.shift_index + 1
	var belt: Array[CardInstance] = []
	for card: CardInstance in run.row:
		if card != null:
			belt.append(card)
	var shrunk: CardInstance = _first(belt, true)
	if parts.has("shrink") and shrunk != null:
		run.twists.shrinks[shrunk.definition.product_card().id] = SHRUNK_EUROS
	if parts.has("dates"):
		var dated: CardInstance = _first(run.hand(), true, belt)
		if dated != null:
			run.twists.expiry[dated.instance_id] = GradeRules.playing_shift(run) + DATED_SHIFTS - 1
		var coupon: CardInstance = _first(belt, false)
		if coupon != null:
			run.twists.expiry[coupon.instance_id] = GradeRules.playing_shift(run)
	if parts.has("picky"):
		run.inspections = []
		var named: CardInstance = belt[1] if belt.size() > 1 else _first(belt, true)
		var family: String = _family(named)
		run.twists.picky[shift] = family
		run.twists.promo_cuts.erase(shift)
		for part: String in parts:
			if part.begins_with("cut"):
				run.twists.promo_cuts[shift] = part.trim_prefix("cut").to_int()
		if parts.has("gun"):
			for card: CardInstance in belt:
				var product: bool = card.definition.is_product()
				if product and not card.definition.tags.has(family):
					run.relabels[card.instance_id] = family
					break
	else:
		run.twists.picky.erase(shift)
	if parts.has("notice") and shrunk != null:
		run.twists.news = PackedStringArray(
			[GradeRules.SHRINK_NEWS % [shrunk.definition.display_name, SHRUNK_EUROS]]
		)
		run.twists.news_shift = shift
	run.twists.clear_events()
	screen._refresh()
	screen._week.show_chips()
	screen._week._calendar.play_change(false)
	if parts.has("notice"):
		MachineFlow.show_shift_notice(screen)
	_stamps(screen, parts, shrunk, belt)
	return "grades_%s_" % "_".join(parts)


## `stamps<tenths>` (with `expired`): GradeMoves played and frozen that far in.
static func _stamps(
	screen: ShiftScreen, parts: PackedStringArray, shrunk: CardInstance, belt: Array[CardInstance]
) -> void:
	var seconds: float = -1.0
	for part: String in parts:
		if part.begins_with("stamps"):
			seconds = part.trim_prefix("stamps").to_int() / 10.0
	if seconds < 0.0:
		return
	var run: RunState = screen.run
	if parts.has("shrink") and shrunk != null:
		run.twists.fresh_shrunk.append(shrunk.definition.product_card().id)
	run.twists.fresh_promo = parts.has("picky")  # Today's promo tags stamp on too.
	for id: int in run.twists.expiry:
		var coupon: CardInstance = _first(belt, false)
		if coupon == null or coupon.instance_id != id:
			run.twists.fresh_dated.append(id)
	if parts.has("expired"):
		var gone: CardInstance = _first(belt, false)
		run.twists.fresh_expired.append(gone.definition if gone != null else belt[0].definition)
	screen._top_bar.notification(Container.NOTIFICATION_SORT_CHILDREN)  # The Cart button placed.
	for tween: Tween in screen.play_grade_moves():
		tween.custom_step(seconds)
		tween.pause()


## The parts on the open deck view's Cart (see the class comment).
static func _apply_deck(screen: ShiftScreen, parts: PackedStringArray) -> void:
	var run: RunState = screen.run
	var stacked: DeckSummary.Group = null
	for group: DeckSummary.Group in DeckSummary.groups(run.deck.cards):
		if group.card.is_product() and group.copies.size() > 1:
			stacked = group
			break
	if stacked == null:
		return
	if parts.has("shrink"):
		run.twists.shrinks[stacked.card.product_card().id] = SHRUNK_EUROS
	if parts.has("copies") or parts.has("copytip"):
		var dated: CardInstance = stacked.copies[stacked.copies.size() - 1]
		run.twists.expiry[dated.instance_id] = GradeRules.playing_shift(run) + DATED_SHIFTS - 1
	var view: DeckView = screen._deck_view
	view._fill_deck_page(run)
	if parts.has("copytip"):
		for cell: DeckCell in view.cells():
			if cell.card == stacked.card:
				view.hover(cell)


## The first product (or coupon when `product` is false) of `cards` not in `besides`, or null.
static func _first(
	cards: Array[CardInstance], product: bool, besides: Array[CardInstance] = []
) -> CardInstance:
	for card: CardInstance in cards:
		if besides.has(card):
			continue
		if card.definition.is_product() == product and (product or card.definition.is_coupon()):
			return card
	return null


## `card`'s first family the palette knows (not Food), else "Dairy".
static func _family(card: CardInstance) -> String:
	if card != null:
		for tag: String in card.definition.tags:
			if tag != "Food":
				return tag
	return "Dairy"
