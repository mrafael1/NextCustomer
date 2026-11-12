class_name BookOrder
extends RefCounted
## What the FIGURINE BOOK (v1.30 round 2) holds and in what order, from data alone: every
## product of the balance once (its staples, then each aisle's products in balance.aisles order,
## base ones before capsule ones), each in its main family (CardFamilies.main_family with the
## palette's main_family_order). A starter (a staple or an aisle's base product) is always owned;
## a capsule item is owned once drawn, collected_at its place in the profile's draw order
## (ProfileState.unlocked_items keeps the order the items were drawn in, and saves it). Round 3:
## then every coupon of the live coupon pools (balance.coupon_pool, then any of first_offer_pool
## not in it), in BookEntry.COUPON_FAMILY, owned once played in a run that has ended (the
## profile's coupon_uses, which counts a run's coupon uses when it ends; nothing else tracks
## coupons). coupon_uses is saved as a plain dictionary (its keys come back sorted), so it keeps
## no play order: a played coupon's collected_at is 0 and the coupons stay in book order.
##
## The book's pages: FAMILY (the default; round 7: BOOK) gives each family its own pages,
## families in main_family_order and cards in data order, the coupons last; NEWEST puts the
## collected capsule items first (the last drawn first), then the starters, then the items not
## collected yet (in family order), then the played coupons and the coupons not played yet
## (each in book order). A family filter keeps that family's cards only.
## Round 4 (the user: "food filter should show every item that is food, current one is a bit
## counter intuitive"): a family's filter keeps every card carrying the family as a printed tag
## (BookEntry.has_family: Food holds every food item, Produce Frozen peas too), and a family has
## a tab when any card carries it (Frozen, by Frozen peas). FAMILY with a filter is one run of
## pages under that family (its cards grouped by their main family, in data order inside), its
## count the filtered cards; FAMILY with ALL still files each card once, under its main family.
## Round 5 (the user: "sort change in toys section: instead of 2 buttons => dropdown with: family
## / newest / food / non-food"): FOOD keeps only the cards printed Food (BookEntry.is_food) and
## NON_FOOD only the rest (Household, Coffee, Tea bags ..., the coupons), each one run of pages
## in family order like a filtered FAMILY. Food is no longer a tab (families() leaves it out:
## FOOD covers it); FOOD and NON_FOOD read the whole book, so the book then reset the tab to ALL
## when either was picked (superseded by round 7: a sort applies within the family picked).
## Round 6 (the user: "I think cold case could go to other food to. if a family has less than 3
## member it will go in other food"): a family fewer than MIN_GROUP of the book's items carry
## as a printed tag (Frozen: Frozen peas alone) has no tab and no group of its own (regroup, from
## data). OTHER FOOD (BookEntry.OTHER_FOOD) takes them: under ALL it files every card whose main
## family is Food (the old FOOD group, renamed) or such a small family, and its tab, just before
## COUPONS, shows those and every food card carrying a small family (Frozen peas, which ALL still
## files under Produce, its main family). A card of a small family that is not printed Food has
## no food group to join: ALL files it on the unfamilied last pages and it keeps the tabs of the
## families it carries that are big enough. A family the main family of fewer than MIN_GROUP
## items (Clearance: 2) keeps its tab, but its printed-Food items join OTHER FOOD's ALL group
## (and so its tab) rather than make a tiny group. FOOD and NON_FOOD are unchanged.
## Round 7 (the user: "double family are a problem for breakfast and clearance ... book stay
## sorted as all by default and don't show doublon ... sort by family can be removed from sort and
## have its own dropdown"): the tabs became the FAMILY dropdown (its options are families(), after
## ALL) and FAMILY the BOOK sort (the book order: ALL's groups, a family's run). A sort now applies
## within the family picked: NEWEST orders its cards, FOOD and NON_FOOD keep its food or non-food
## cards (BREAKFAST + NON_FOOD: Coffee, Tea bags), and neither resets the other.

enum Sort { BOOK, NEWEST, FOOD, NON_FOOD }

## The fewest items carrying a family for it to have a FAMILY option and a group of its own
## (round 6).
const MIN_GROUP := 3


## Every card in the book, in data order (see above); `used_coupons` is the profile's
## coupon_uses.
static func entries(
	balance: BalanceDefinition,
	unlocked: Dictionary[StringName, int],
	main_order: PackedStringArray,
	used_coupons: Dictionary[StringName, int] = {}
) -> Array[BookEntry]:
	var drawn: Array[StringName] = []
	drawn.assign(unlocked.keys())
	var found: Array[BookEntry] = []
	var seen: Dictionary[StringName, bool] = {}
	var add: Callable = func(card: CardDefinition, starter: bool) -> void:
		if card == null or not card.is_product() or seen.has(card.id):
			return
		seen[card.id] = true
		var family: String = CardFamilies.main_family(card, main_order)
		found.append(BookEntry.new(card, family, starter, -1 if starter else drawn.find(card.id)))
	for card: CardDefinition in balance.staples:
		add.call(card, true)
	for aisle: AisleDefinition in balance.aisles:
		for card: CardDefinition in aisle.base_cards:
			add.call(card, true)
		for card: CardDefinition in aisle.capsule_cards:
			add.call(card, false)
	for card: CardDefinition in balance.coupon_pool + balance.first_offer_pool:
		if card == null or not card.is_coupon() or seen.has(card.id):
			continue
		seen[card.id] = true
		var played: bool = used_coupons.get(card.id, 0) > 0
		found.append(BookEntry.new(card, BookEntry.COUPON_FAMILY, false, 0 if played else -1))
	regroup(found, main_order)
	return found


## Files `book`'s items for OTHER FOOD (round 6, see above): the families of `main_order` fewer
## than MIN_GROUP items carry are small; an item whose main family is Food or small goes to the
## OTHER_FOOD group if printed Food, else to "" (ALL only). A family that keeps its option but is
## the main family of fewer than MIN_GROUP items (Clearance: Ham ends and Dented can) would make
## a tiny ALL group: its printed-Food items go to OTHER_FOOD too, the others keep their group.
## The OTHER FOOD option shows the OTHER_FOOD group and every food item carrying a small family.
static func regroup(book: Array[BookEntry], main_order: PackedStringArray) -> void:
	var small: PackedStringArray = small_families(book, main_order)
	var is_small: Callable = func(tag: String) -> bool: return small.has(tag)
	var members: Dictionary[String, int] = {}
	for entry: BookEntry in book:
		if not entry.coupon:
			members[entry.family] = members.get(entry.family, 0) + 1
	for entry: BookEntry in book:
		if entry.coupon:
			continue
		entry.group = entry.family
		if entry.family == BookEntry.FOOD_TAG or small.has(entry.family):
			entry.group = BookEntry.OTHER_FOOD if entry.is_food() else ""
		elif members[entry.family] < MIN_GROUP and entry.is_food():
			entry.group = BookEntry.OTHER_FOOD
		var carries_small: bool = Array(entry.tags).any(is_small)
		entry.other_food = (
			entry.group == BookEntry.OTHER_FOOD or (entry.is_food() and carries_small)
		)


## The families of `main_order` (Food aside: it never has an option) that fewer than MIN_GROUP of
## `book`'s items carry as a printed tag, none included (round 6).
static func small_families(
	book: Array[BookEntry], main_order: PackedStringArray
) -> PackedStringArray:
	var carried: Dictionary[String, int] = {}
	for entry: BookEntry in book:
		if entry.coupon:
			continue
		for tag: String in entry.tags:
			carried[tag] = carried.get(tag, 0) + 1
	var small: PackedStringArray = PackedStringArray()
	for family: String in main_order:
		if family != BookEntry.FOOD_TAG and carried.get(family, 0) < MIN_GROUP:
			small.append(family)
	return small


## The FAMILY dropdown's families (after its ALL): those with at least one card carrying them
## (BookEntry.has_family), in `main_order`, then OTHER_FOOD when a card shows under it, then
## COUPON_FAMILY when the book holds a coupon. Never "" (the dropdown's ALL): a card with no family
## shows under ALL only, on the FAMILY sort's last pages before the coupons'. Never
## BookEntry.FOOD_TAG (round 5: the FOOD sort shows those cards), nor a small family (round 6: OTHER
## FOOD takes its cards).
static func families(book: Array[BookEntry], main_order: PackedStringArray) -> PackedStringArray:
	var shown: PackedStringArray = _families_with(book, main_order)
	shown.erase(BookEntry.FOOD_TAG)
	for family: String in small_families(book, main_order):
		shown.erase(family)
	return shown


## The book's pages of at most `per_page` cards for `sort` and `filter` (a family, or "" for
## every family). BOOK with ALL starts each group on a new page; with a filter, the filtered
## cards run on, grouped by main family; FOOD and NON_FOOD (within the filter) run on likewise;
## NEWEST orders the filter's cards newest first. Empty when nothing shows (COUPONS + FOOD).
static func pages(
	book: Array[BookEntry], sort: Sort, filter: String, per_page: int, main_order: PackedStringArray
) -> Array[Array]:
	var kept: Array[BookEntry] = []
	for entry: BookEntry in book:
		if shows(entry, sort, filter):
			kept.append(entry)
	var result: Array[Array] = []
	if sort == Sort.NEWEST:
		_chunk(newest_first(kept), per_page, result)
		return result
	# ALL's FAMILY pages go by group (round 6: OTHER FOOD); the runs (a filter, FOOD, NON_FOOD)
	# keep their main families' order.
	var by_group: bool = filter.is_empty() and sort == Sort.BOOK
	var groups: PackedStringArray = main_order.duplicate()
	groups.append(BookEntry.OTHER_FOOD)
	groups.append("")
	groups.append(BookEntry.COUPON_FAMILY)
	var run: Array[BookEntry] = []
	for family: String in groups:
		var group: Array[BookEntry] = []
		for entry: BookEntry in kept:
			if (entry.group if by_group else entry.family) == family:
				group.append(entry)
		if by_group:
			_chunk(group, per_page, result)
		else:
			run.append_array(group)
	_chunk(run, per_page, result)
	return result


## `book` newest first: collected capsule items (the last drawn first), starters, the items not
## collected yet, then the played coupons and the coupons not played yet (both in book order:
## the save keeps no coupon play order); each group in its book order otherwise.
static func newest_first(book: Array[BookEntry]) -> Array[BookEntry]:
	var collected: Array[BookEntry] = []
	var starters: Array[BookEntry] = []
	var missing: Array[BookEntry] = []
	var played: Array[BookEntry] = []
	var unplayed: Array[BookEntry] = []
	for entry: BookEntry in book:
		if entry.coupon:
			(played if entry.owned else unplayed).append(entry)
		elif entry.starter:
			starters.append(entry)
		elif entry.owned:
			collected.append(entry)
		else:
			missing.append(entry)
	var newer: Callable = func(a: BookEntry, b: BookEntry) -> bool:
		return a.collected_at > b.collected_at
	collected.sort_custom(newer)
	var ordered: Array[BookEntry] = []
	for group: Array[BookEntry] in [collected, starters, missing, played, unplayed]:
		ordered.append_array(group)
	return ordered


## How many of `family`'s cards are owned (x) out of how many (y): the cards its filter shows
## (BookEntry.has_family), or with `main_only` the cards of its group (BookEntry.group: the
## FAMILY sort's group under ALL); "" counts every card, or with `main_only` the unfamilied
## group's (round 6).
static func count(book: Array[BookEntry], family: String = "", main_only: bool = false) -> Vector2i:
	var owned: int = 0
	var total: int = 0
	for entry: BookEntry in book:
		var shown: bool = entry.group == family if main_only else entry.has_family(family)
		if (family.is_empty() and not main_only) or shown:
			total += 1
			owned += 1 if entry.owned else 0
	return Vector2i(owned, total)


## Whether `entry` shows under `sort` and `filter` (a family, or "" for every family): FOOD
## keeps the cards printed Food, NON_FOOD the others.
static func shows(entry: BookEntry, sort: Sort, filter: String) -> bool:
	if not filter.is_empty() and not entry.has_family(filter):
		return false
	if sort == Sort.FOOD or sort == Sort.NON_FOOD:
		return entry.is_food() == (sort == Sort.FOOD)
	return true


## How many of the cards `sort` and `filter` show are owned (x) out of how many (y).
static func count_shown(book: Array[BookEntry], sort: Sort, filter: String) -> Vector2i:
	var owned: int = 0
	var total: int = 0
	for entry: BookEntry in book:
		if shows(entry, sort, filter):
			total += 1
			owned += 1 if entry.owned else 0
	return Vector2i(owned, total)


## The group (BookEntry.group) every card of `page` shares, or "" when they differ (a NEWEST
## page).
static func page_family(page: Array) -> String:
	if page.is_empty():
		return ""
	var family: String = (page[0] as BookEntry).group
	for entry: BookEntry in page:
		if entry.group != family:
			return ""
	return family


static func _chunk(group: Array[BookEntry], per_page: int, into: Array[Array]) -> void:
	for start: int in range(0, group.size(), per_page):
		into.append(group.slice(start, start + per_page))


static func _families_with(
	book: Array[BookEntry], main_order: PackedStringArray
) -> PackedStringArray:
	var shown: PackedStringArray = PackedStringArray()
	var order: PackedStringArray = main_order.duplicate()
	order.append(BookEntry.OTHER_FOOD)
	order.append(BookEntry.COUPON_FAMILY)
	for family: String in order:
		var carried: Callable = func(entry: BookEntry) -> bool: return entry.has_family(family)
		if book.any(carried):
			shown.append(family)
	return shown
