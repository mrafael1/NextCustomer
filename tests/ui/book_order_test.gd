extends GdUnitTestSuite
## What the FIGURINE BOOK holds and in what order (v1.26 round 2, BookOrder): every product of the
## balance once, starters (staples and aisle base products) owned from the start, capsule items
## owned once drawn; every product has a main family; the families in main_family_order with
## cards only; FAMILY gives each family its own pages of at most six in data order; a family
## filter keeps that family's cards only; NEWEST puts the drawn items first (the last drawn
## first), then the starters, then the items not collected yet; the counts. Round 3: the coupons
## of the live pools come last (their own family, their own last pages, last in NEWEST too), owned
## once played in an ended run (the profile's coupon_uses). Round 4 (the user: "food filter should
## show every item that is food"): a family's tab and filter go by the printed tags (Food holds
## every food item, a card shows under each family it carries, Frozen has a tab by Frozen peas),
## a filtered FAMILY view is one run grouped by main family, and ALL still files each card once.
## Round 5 (the SORT dropdown): FOOD shows only the cards printed Food, NON_FOOD only the rest
## (the coupons among them), each one run in family order; Food is no longer a tab.
## Round 6 (the user: "if a family has less than 3 member it will go in other food"): a family
## fewer than MIN_GROUP items carry has no tab nor group (Frozen); OTHER FOOD takes the Food-main
## cards (ALL's group) and shows the food cards of a small family too (Frozen peas), its tab just
## before COUPONS; the threshold comes from the book's data (a test-made book's 2-card family).
## Round 7 (the FAMILY dropdown; FAMILY became the BOOK sort): a sort applies within the family
## picked (BREAKFAST + NON_FOOD: its non-food cards, Coffee and Tea bags among them), and a pick
## that shows nothing gives no page.

const Kit := preload("res://tests/ui/toy_test_kit.gd")
const PER_PAGE := 6


func test_every_product_once_with_starters_owned() -> void:
	var balance: BalanceDefinition = Kit.balance()
	var book: Array[BookEntry] = _book(Kit.profile(0, 0))
	var expected: Array[StringName] = []
	for card: CardDefinition in balance.staples:
		expected.append(card.id)
	for aisle: AisleDefinition in balance.aisles:
		for card: CardDefinition in aisle.base_cards + aisle.capsule_cards:
			if not expected.has(card.id):
				expected.append(card.id)
	var ids: Array[StringName] = []
	for entry: BookEntry in book:
		if entry.coupon:
			continue
		ids.append(entry.card.id)
		assert_bool(entry.card.is_product()).is_true()
		assert_str(entry.family).override_failure_message(str(entry.card.id)).is_not_empty()
		assert_bool(entry.owned).is_equal(entry.starter)
		assert_int(entry.collected_at).is_equal(-1)
	assert_array(ids).is_equal(expected)
	var starters: int = balance.staples.size()
	for aisle: AisleDefinition in balance.aisles:
		starters += aisle.base_cards.size()
	var coupons: int = _pool_coupons(balance).size()
	assert_object(BookOrder.count(book)).is_equal(Vector2i(starters, expected.size() + coupons))


func test_the_families_follow_the_palette_with_cards_only() -> void:
	var order: PackedStringArray = FamilyPalette.shared().main_family_order
	var book: Array[BookEntry] = _book(Kit.profile(0, 0))
	var families: PackedStringArray = BookOrder.families(book, order)
	var last: int = -1
	assert_str(families[-1]).is_equal(BookEntry.COUPON_FAMILY)
	# Round 6: OTHER FOOD just before COUPONS.
	assert_str(families[-2]).is_equal(BookEntry.OTHER_FOOD)
	for family: String in families.slice(0, families.size() - 2):
		var at: int = order.find(family)
		assert_int(at).is_greater(last)
		last = at
		assert_int(BookOrder.count(book, family).y).is_greater_equal(BookOrder.MIN_GROUP)
	# Frozen peas is Produce first (Produce before Frozen), and it alone carries Frozen: too few
	# for a tab (round 6), OTHER FOOD shows it.
	assert_bool(families.has("Frozen")).is_false()
	var peas: BookEntry = _entry(book, &"frozen_peas")
	assert_str(peas.family).is_equal("Produce")
	assert_bool(_groups(book, order).has("Frozen")).is_false()
	assert_array(Array(families)).contains(["Bakery", "Produce", "Breakfast"])
	# Round 5: no Food tab (the FOOD sort shows those cards).
	assert_bool(families.has(BookEntry.FOOD_TAG)).is_false()


func test_family_pages_start_each_family_on_its_own_page() -> void:
	var order: PackedStringArray = FamilyPalette.shared().main_family_order
	var book: Array[BookEntry] = _book(Kit.profile(0, 0))
	var pages: Array[Array] = BookOrder.pages(book, BookOrder.Sort.BOOK, "", PER_PAGE, order)
	var seen: Array[BookEntry] = []
	var families: PackedStringArray = PackedStringArray()
	for page: Array in pages:
		assert_int(page.size()).is_between(1, PER_PAGE)
		var family: String = BookOrder.page_family(page)
		assert_str(family).is_not_empty()
		if families.is_empty() or families[-1] != family:
			assert_bool(families.has(family)).is_false()
			families.append(family)
		for entry: BookEntry in page:
			seen.append(entry)
	assert_array(Array(families)).is_equal(Array(_groups(book, order)))
	# Each card once under ALL (round 4: a card carrying several families isn't repeated).
	assert_int(seen.size()).is_equal(book.size())
	for entry: BookEntry in book:
		assert_int(seen.count(entry)).override_failure_message(str(entry.card.id)).is_equal(1)
	# Inside a family, data order.
	for family: String in families:
		var in_book: Array = book.filter(func(e: BookEntry) -> bool: return e.group == family)
		var in_pages: Array = seen.filter(func(e: BookEntry) -> bool: return e.group == family)
		assert_array(in_pages).is_equal(in_book)
	# Round 6: the Food-main cards' group is OTHER FOOD (no FOOD group), no Frozen group.
	assert_bool(families.has(BookEntry.OTHER_FOOD)).is_true()
	assert_bool(families.has(BookEntry.FOOD_TAG) or families.has("Frozen")).is_false()


func test_a_family_filter_keeps_every_card_carrying_that_family() -> void:
	var book: Array[BookEntry] = _book(Kit.profile(0, 0))
	var carrying: Array[BookEntry] = []
	for entry: BookEntry in book:
		if not entry.coupon and entry.card.tags.has("Produce"):
			carrying.append(entry)
	for sort: BookOrder.Sort in [BookOrder.Sort.BOOK, BookOrder.Sort.NEWEST]:
		var shown: Array[BookEntry] = _shown(book, sort, "Produce")
		assert_int(shown.size()).is_equal(carrying.size())
		for entry: BookEntry in carrying:
			assert_bool(shown.has(entry)).override_failure_message(str(entry.card.id)).is_true()
	assert_int(BookOrder.count(book, "Produce").y).is_equal(carrying.size())
	# The group's own count (the ALL pages' header) stays its group's cards: Breakfast fewer
	# than the cards carrying it.
	var main: int = book.filter(func(e: BookEntry) -> bool: return e.group == "Breakfast").size()
	assert_int(BookOrder.count(book, "Breakfast", true).y).is_equal(main)
	assert_int(main).is_less(BookOrder.count(book, "Breakfast").y)


## Round 6 (the user: "I think cold case could go to other food to. if a family has less than 3
## member it will go in other food"): Frozen (Frozen peas alone) is small, so no tab and no
## group; the Food-main cards (Soup, Sugar cubes, Mixed herbs) are OTHER FOOD's ALL group, Frozen
## peas stays in Produce under ALL (once) and OTHER FOOD's tab shows it with them; the counts.
func test_other_food_takes_the_small_families_and_the_food_main_cards() -> void:
	var order: PackedStringArray = FamilyPalette.shared().main_family_order
	var book: Array[BookEntry] = _book(Kit.profile(0, 0))
	assert_array(Array(BookOrder.small_families(book, order))).is_equal(["Frozen"])
	# OTHER FOOD's ALL group: the Food-main cards, and the printed-Food cards of a main family
	# fewer than MIN_GROUP items have (Clearance: Ham ends, Dented can), which keeps its tab.
	var members: Dictionary[String, int] = {}
	for entry: BookEntry in book:
		if not entry.coupon:
			members[entry.family] = members.get(entry.family, 0) + 1
	assert_int(members["Clearance"]).is_less(BookOrder.MIN_GROUP)
	assert_bool(BookOrder.families(book, order).has("Clearance")).is_true()
	var food_main: Array[BookEntry] = []
	for entry: BookEntry in book:
		if entry.coupon:
			continue
		var tiny: bool = members[entry.family] < BookOrder.MIN_GROUP and entry.is_food()
		if entry.family == BookEntry.FOOD_TAG or tiny:
			food_main.append(entry)
	assert_bool(food_main.has(_entry(book, &"ham_ends"))).is_true()
	assert_bool(food_main.has(_entry(book, &"dented_can"))).is_true()
	assert_bool(food_main.has(_entry(book, &"soup"))).is_true()
	# Every ALL group but the coupons' holds at least MIN_GROUP cards.
	for group: String in _groups(book, order):
		var size: int = book.filter(func(e: BookEntry) -> bool: return e.group == group).size()
		assert_int(size).override_failure_message(group).is_greater_equal(BookOrder.MIN_GROUP)
	var peas: BookEntry = _entry(book, &"frozen_peas")
	assert_str(peas.group).is_equal("Produce")
	var grouped: Array = book.filter(
		func(e: BookEntry) -> bool: return e.group == BookEntry.OTHER_FOOD
	)
	assert_array(grouped).is_equal(food_main)
	var shown: Array[BookEntry] = _shown(book, BookOrder.Sort.BOOK, BookEntry.OTHER_FOOD)
	var expected: Array[BookEntry] = []
	for entry: BookEntry in book:
		if entry == peas or food_main.has(entry):
			expected.append(entry)
	assert_array(shown).contains_exactly_in_any_order(expected)
	for entry: BookEntry in shown:
		assert_bool(entry.is_food()).is_true()
	var owned: int = food_main.filter(func(e: BookEntry) -> bool: return e.owned).size()
	assert_object(BookOrder.count(book, BookEntry.OTHER_FOOD, true)).is_equal(
		Vector2i(owned, food_main.size())
	)
	var tab_owned: int = owned + (1 if peas.owned else 0)
	assert_object(BookOrder.count(book, BookEntry.OTHER_FOOD)).is_equal(
		Vector2i(tab_owned, food_main.size() + 1)
	)
	# ALL: each card once, Frozen peas on a Produce page, the OTHER FOOD pages before COUPONS'.
	var pages: Array[Array] = BookOrder.pages(book, BookOrder.Sort.BOOK, "", PER_PAGE, order)
	var page_groups: PackedStringArray = PackedStringArray()
	for page: Array in pages:
		var family: String = BookOrder.page_family(page)
		if page.has(peas):
			assert_str(family).is_equal("Produce")
		if page_groups.is_empty() or page_groups[-1] != family:
			page_groups.append(family)
	assert_str(page_groups[-2]).is_equal(BookEntry.OTHER_FOOD)
	assert_int(_shown(book, BookOrder.Sort.BOOK, "").count(peas)).is_equal(1)
	# FOOD and NON-FOOD unchanged: every food card, every other card.
	var food: Array[BookEntry] = _shown(book, BookOrder.Sort.FOOD, "")
	assert_int(food.size()).is_equal(
		book.filter(func(e: BookEntry) -> bool: return e.is_food()).size()
	)
	(
		assert_bool(
			food.has(peas) and food_main.all(func(e: BookEntry) -> bool: return food.has(e))
		)
		. is_true()
	)


## The threshold comes from the book's data (round 6): a test-made book with two Dairy cards (a
## 2-card family), three Bakery cards and one Household card. Dairy and Household get no tab
## and no group; the Dairy cards (printed Food) join OTHER FOOD; Household's card, not food, has
## no food group to join: ALL files it on the unfamilied last pages and no tab shows it. A third
## Dairy card gives Dairy its tab and group back.
func test_the_threshold_comes_from_the_books_data() -> void:
	var order: PackedStringArray = FamilyPalette.shared().main_family_order
	var ids: Array[StringName] = [
		&"cheese", &"butter", &"bread", &"baguette", &"scone", &"scissors"
	]
	var book: Array[BookEntry] = _made_book(ids)
	BookOrder.regroup(book, order)
	var small: PackedStringArray = BookOrder.small_families(book, order)
	assert_bool(small.has("Dairy") and small.has("Household")).is_true()
	assert_bool(small.has("Bakery")).is_false()
	var families: PackedStringArray = BookOrder.families(book, order)
	assert_array(Array(families)).is_equal(["Bakery", BookEntry.OTHER_FOOD])
	for id: StringName in [&"cheese", &"butter"]:
		var dairy: BookEntry = _entry(book, id)
		assert_str(dairy.family).is_equal("Dairy")
		assert_str(dairy.group).is_equal(BookEntry.OTHER_FOOD)
		assert_bool(dairy.has_family(BookEntry.OTHER_FOOD)).is_true()
	var scissors: BookEntry = _entry(book, &"scissors")
	assert_str(scissors.group).is_empty()
	assert_bool(scissors.other_food).is_false()
	assert_array(Array(_groups(book, order))).is_equal(["Bakery", BookEntry.OTHER_FOOD])
	var pages: Array[Array] = BookOrder.pages(book, BookOrder.Sort.BOOK, "", PER_PAGE, order)
	var seen: Array[BookEntry] = []
	for page: Array in pages:
		seen.append_array(page)
	assert_array(seen).contains_exactly_in_any_order(book)
	assert_bool(pages[-1].has(scissors)).is_true()
	# Three Dairy cards: Dairy is big enough again.
	var more: Array[StringName] = ids.duplicate()
	more.append(&"cream")
	var bigger: Array[BookEntry] = _made_book(more)
	BookOrder.regroup(bigger, order)
	assert_bool(BookOrder.families(bigger, order).has("Dairy")).is_true()
	assert_str(_entry(bigger, &"cheese").group).is_equal("Dairy")
	# OTHER FOOD has no group left, its tab only Bread (printed Food, carrying the small
	# Breakfast, Bread's alone here).
	assert_bool(_groups(bigger, order).has(BookEntry.OTHER_FOOD)).is_false()
	var other: Array[BookEntry] = _shown(bigger, BookOrder.Sort.BOOK, BookEntry.OTHER_FOOD)
	assert_array(other).is_equal([_entry(bigger, &"bread")])


## The user: "dropdown with: family / newest / food / non-food" ("show only those"). FOOD shows
## every item printed Food, whatever its main family (Bread, Milk, Banana ...), NON_FOOD every
## other card (Household, Coffee, Tea bags, the coupons): together the whole book, each card in
## one of them. Each runs on (full pages but the last), grouped by main family in the palette's
## order with the coupons last, data order inside; the counts are theirs.
func test_food_and_non_food_split_the_book() -> void:
	var order: PackedStringArray = FamilyPalette.shared().main_family_order
	var profile: ProfileState = Kit.profile(0, 0, {&"pantry": 1, &"household": 1})
	profile.coupon_uses[Kit.balance().coupon_pool[0].id] = 1
	var book: Array[BookEntry] = _book(profile)
	var food: Array[BookEntry] = []
	var other: Array[BookEntry] = []
	var mains: PackedStringArray = PackedStringArray()
	for entry: BookEntry in book:
		if not entry.coupon and entry.card.tags.has("Food"):
			food.append(entry)
			if not mains.has(entry.family):
				mains.append(entry.family)
		else:
			other.append(entry)
	assert_array(Array(mains)).contains(["Bakery", "Produce", "Dairy", "Snack", "Food"])
	for id: StringName in [&"coffee", &"tea_bags", &"batteries"]:
		assert_bool(other.has(_entry(book, id))).override_failure_message(str(id)).is_true()
	assert_bool(other.any(func(e: BookEntry) -> bool: return e.coupon)).is_true()
	assert_int(food.size() + other.size()).is_equal(book.size())
	for split: Array in [[BookOrder.Sort.FOOD, food], [BookOrder.Sort.NON_FOOD, other]]:
		var sort: BookOrder.Sort = split[0]
		var kept: Array[BookEntry] = []
		kept.assign(split[1])
		var shown: Array[BookEntry] = _shown(book, sort, "")
		assert_int(shown.size()).is_equal(kept.size())
		var counted: Vector2i = BookOrder.count_shown(book, sort, "")
		assert_int(counted.y).is_equal(kept.size())
		var owned: int = kept.filter(func(e: BookEntry) -> bool: return e.owned).size()
		assert_int(counted.x).is_equal(owned)
		assert_int(owned).is_between(1, kept.size() - 1)
		var pages: Array[Array] = BookOrder.pages(book, sort, "", PER_PAGE, order)
		for page: Array in pages.slice(0, pages.size() - 1):
			assert_int(page.size()).is_equal(PER_PAGE)
		var ranks: PackedStringArray = order.duplicate()
		ranks.append("")
		ranks.append(BookEntry.COUPON_FAMILY)
		var last: int = -1
		for entry: BookEntry in shown:
			assert_bool(kept.has(entry)).override_failure_message(str(entry.card.id)).is_true()
			var at: int = ranks.find(entry.family)
			assert_int(at).is_greater_equal(last)
			last = at
		for family: String in ranks:
			var in_book: Array = kept.filter(func(e: BookEntry) -> bool: return e.family == family)
			var in_pages: Array = shown.filter(
				func(e: BookEntry) -> bool: return e.family == family
			)
			assert_array(in_pages).is_equal(in_book)
	# A family's filter still meets the split (the book never shows both at once: it resets the
	# tab): Dairy's food cards only.
	for entry: BookEntry in _shown(book, BookOrder.Sort.FOOD, "Dairy"):
		assert_bool(entry.is_food() and entry.has_family("Dairy")).is_true()


## A card carrying several families (Frozen peas: Food, Frozen and Produce) shows under each of
## their filters, once each, under no other family's, and once under ALL in both sorts.
func test_a_card_shows_under_each_family_it_carries() -> void:
	var book: Array[BookEntry] = _book(Kit.profile(0, 0))
	var peas: BookEntry = _entry(book, &"frozen_peas")
	assert_bool(peas.is_food()).is_true()
	for family: String in ["Food", "Produce", BookEntry.OTHER_FOOD]:
		assert_bool(peas.has_family(family)).is_true()
		var shown: Array[BookEntry] = _shown(book, BookOrder.Sort.BOOK, family)
		assert_int(shown.count(peas)).override_failure_message(family).is_equal(1)
	for family: String in ["Dairy", "Bakery", BookEntry.COUPON_FAMILY]:
		assert_bool(_shown(book, BookOrder.Sort.BOOK, family).has(peas)).is_false()
	assert_int(_shown(book, BookOrder.Sort.BOOK, "").count(peas)).is_equal(1)
	assert_int(_shown(book, BookOrder.Sort.NEWEST, "").count(peas)).is_equal(1)
	# NEWEST with a filter keeps that family's cards only.
	for entry: BookEntry in _shown(book, BookOrder.Sort.NEWEST, BookEntry.OTHER_FOOD):
		assert_bool(entry.has_family(BookEntry.OTHER_FOOD)).is_true()
	# A coupon only ever shows under COUPONS.
	var coupon: BookEntry = book[-1]
	assert_bool(coupon.coupon).is_true()
	assert_bool(coupon.has_family(BookEntry.COUPON_FAMILY)).is_true()
	assert_bool(coupon.has_family("Food") or coupon.has_family("")).is_false()
	assert_bool(coupon.is_food()).is_false()


func test_newest_first_puts_the_last_drawn_first() -> void:
	var order: PackedStringArray = FamilyPalette.shared().main_family_order
	var profile: ProfileState = Kit.profile(0, 0)
	for id: StringName in [&"lemon", &"cream", &"crisps"]:
		profile.unlocked_items[id] = 2
	var book: Array[BookEntry] = _book(profile)
	var pages: Array[Array] = BookOrder.pages(book, BookOrder.Sort.NEWEST, "", PER_PAGE, order)
	var ordered: Array[BookEntry] = []
	for page: Array in pages:
		ordered.append_array(page)
	assert_int(ordered.size()).is_equal(book.size())
	var ids: Array[StringName] = []
	for entry: BookEntry in ordered.slice(0, 3):
		ids.append(entry.card.id)
	assert_array(ids).is_equal([&"crisps", &"cream", &"lemon"])
	# Then every starter, then the items not collected yet (grey), never mixed.
	var stage: int = 0
	for entry: BookEntry in ordered.slice(3):
		var kind: int = 0 if entry.starter else 1
		assert_int(kind).is_greater_equal(stage)
		stage = kind
		assert_bool(entry.owned).is_equal(entry.starter)
	# A NEWEST page isn't a family page.
	assert_str(BookOrder.page_family(pages[0])).is_empty()


func test_the_draw_order_survives_a_save() -> void:
	var profile: ProfileState = Kit.profile(0, 0)
	for id: StringName in [&"potatoes", &"scone", &"egg_timer"]:
		profile.unlocked_items[id] = 1
	var loaded: ProfileState = ProfileState.from_dictionary(profile.to_dictionary())
	assert_object(loaded).is_not_null()
	var newest: Array[BookEntry] = BookOrder.newest_first(_book(loaded))
	assert_str(String(newest[0].card.id)).is_equal("egg_timer")
	assert_str(String(newest[2].card.id)).is_equal("potatoes")


## A card with no family (none today) never makes a second ALL tab: the families never hold "",
## and FAMILY still lists the card, on its last page.
func test_a_card_with_no_family_shows_under_all_only() -> void:
	var order: PackedStringArray = FamilyPalette.shared().main_family_order
	var book: Array[BookEntry] = _book(Kit.profile(0, 0))
	var loose: BookEntry = BookEntry.new(book[0].card, "", true)
	book.append(loose)
	assert_bool(BookOrder.families(book, order).has("")).is_false()
	var pages: Array[Array] = BookOrder.pages(book, BookOrder.Sort.BOOK, "", PER_PAGE, order)
	# Its page is the last before the coupons'.
	var at: int = pages.find(pages.filter(func(page: Array) -> bool: return page.has(loose))[0])
	assert_str(BookOrder.page_family(pages[at + 1])).is_equal(BookEntry.COUPON_FAMILY)
	assert_str(BookOrder.page_family(pages[at - 1])).is_not_equal(BookEntry.COUPON_FAMILY)
	var count: int = 0
	for page: Array in pages:
		count += page.size()
	assert_int(count).is_equal(book.size())


## Every coupon of the live pools once, after the items, in pool order (coupon_pool, then the
## first offer's others), in the coupons' family; owned once played (a use counted at a run's
## end). The profile goes through the save's JSON first: coupon_uses keeps no play order there
## (its keys come back sorted), so the played coupons stay in book order in NEWEST too.
func test_the_coupons_come_last_owned_once_played() -> void:
	var balance: BalanceDefinition = Kit.balance()
	var played_profile: ProfileState = Kit.profile(0, 0)
	played_profile.coupon_uses[&"two_for_one"] = 1
	played_profile.coupon_uses[&"multipack"] = 0
	played_profile.coupon_uses[&"repeat"] = 2
	var saved: String = JSON.stringify(played_profile.to_dictionary(), "	")
	var profile: ProfileState = ProfileState.from_dictionary(JSON.parse_string(saved))
	assert_object(profile).is_not_null()
	assert_int(profile.coupon_uses.get(&"repeat", 0)).is_equal(2)
	var book: Array[BookEntry] = _book(profile)
	var pool: Array[StringName] = _pool_coupons(balance)
	assert_int(pool.size()).is_greater(0)
	var coupons: Array[BookEntry] = book.slice(book.size() - pool.size())
	var ids: Array[StringName] = []
	for entry: BookEntry in coupons:
		ids.append(entry.card.id)
		assert_bool(entry.coupon and entry.card.is_coupon()).is_true()
		assert_str(entry.family).is_equal(BookEntry.COUPON_FAMILY)
		assert_bool(entry.starter).is_false()
		var played: bool = profile.coupon_uses.get(entry.card.id, 0) > 0
		assert_bool(entry.owned).override_failure_message(str(entry.card.id)).is_equal(played)
	assert_array(ids).is_equal(pool)
	for entry: BookEntry in book.slice(0, book.size() - pool.size()):
		assert_bool(entry.coupon).is_false()
	assert_object(BookOrder.count(book, BookEntry.COUPON_FAMILY)).is_equal(Vector2i(2, pool.size()))
	# FAMILY: the coupons' pages are the last, coupons only.
	var order: PackedStringArray = FamilyPalette.shared().main_family_order
	var pages: Array[Array] = BookOrder.pages(book, BookOrder.Sort.BOOK, "", PER_PAGE, order)
	var coupon_pages: int = ceili(pool.size() / float(PER_PAGE))
	for page: Array in pages.slice(pages.size() - coupon_pages):
		assert_str(BookOrder.page_family(page)).is_equal(BookEntry.COUPON_FAMILY)
	# NEWEST: after every item, the played coupons, then the ones not played yet, each in book
	# order (the order they were played in is not saved).
	var newest: Array[BookEntry] = BookOrder.newest_first(book)
	var tail: Array[StringName] = []
	for entry: BookEntry in newest.slice(newest.size() - pool.size()):
		tail.append(entry.card.id)
	var played_ids: Array[StringName] = []
	for id: StringName in pool:
		if profile.coupon_uses.get(id, 0) > 0:
			played_ids.append(id)
	assert_int(played_ids.size()).is_equal(2)
	assert_array(tail.slice(0, 2)).is_equal(played_ids)
	for entry: BookEntry in newest.slice(newest.size() - pool.size() + 2):
		assert_bool(entry.owned).is_false()
	# The coupons' filter keeps the coupons only.
	var filtered: Array[Array] = BookOrder.pages(
		book, BookOrder.Sort.NEWEST, BookEntry.COUPON_FAMILY, PER_PAGE, order
	)
	var count: int = 0
	for page: Array in filtered:
		for entry: BookEntry in page:
			assert_bool(entry.coupon).is_true()
			count += 1
	assert_int(count).is_equal(pool.size())


## The live coupon pools' coupons once each, in pool order.
static func _pool_coupons(balance: BalanceDefinition) -> Array[StringName]:
	var ids: Array[StringName] = []
	for card: CardDefinition in balance.coupon_pool + balance.first_offer_pool:
		if card.is_coupon() and not ids.has(card.id):
			ids.append(card.id)
	return ids


## A test-made book of the balance's products `ids`, each a starter in its main family.
func _made_book(ids: Array[StringName]) -> Array[BookEntry]:
	var order: PackedStringArray = FamilyPalette.shared().main_family_order
	var made: Array[BookEntry] = []
	for entry: BookEntry in _book(Kit.profile(0, 0)):
		if ids.has(entry.card.id):
			var family: String = CardFamilies.main_family(entry.card, order)
			made.append(BookEntry.new(entry.card, family, true))
	assert_int(made.size()).is_equal(ids.size())
	return made


## Round 7: a sort within a family: FOOD and NON_FOOD keep the family's food or non-food cards
## (one run, in family order), NEWEST orders the family's cards newest first; the count_shown
## counts match; COUPONS + FOOD shows nothing (no page).
func test_a_sort_applies_within_the_family_picked() -> void:
	var profile: ProfileState = Kit.profile(0, 0, {&"pantry": 2})
	var book: Array[BookEntry] = _book(profile)
	var breakfast: Array[BookEntry] = book.filter(
		func(e: BookEntry) -> bool: return e.has_family("Breakfast")
	)
	var non_food: Array[BookEntry] = _shown(book, BookOrder.Sort.NON_FOOD, "Breakfast")
	var food: Array[BookEntry] = _shown(book, BookOrder.Sort.FOOD, "Breakfast")
	assert_int(non_food.size() + food.size()).is_equal(breakfast.size())
	for entry: BookEntry in non_food:
		assert_bool(entry.has_family("Breakfast") and not entry.is_food()).is_true()
	for entry: BookEntry in food:
		assert_bool(entry.has_family("Breakfast") and entry.is_food()).is_true()
	var ids: Array[StringName] = []
	for entry: BookEntry in non_food:
		ids.append(entry.card.id)
	assert_array(ids).contains([&"coffee", &"tea_bags"])
	var counted: Vector2i = BookOrder.count_shown(book, BookOrder.Sort.NON_FOOD, "Breakfast")
	assert_int(counted.y).is_equal(non_food.size())
	# NEWEST within the family: the same cards, the drawn ones first.
	var newest: Array[BookEntry] = _shown(book, BookOrder.Sort.NEWEST, "Breakfast")
	assert_array(newest).contains_exactly_in_any_order(breakfast)
	assert_array(newest).is_equal(BookOrder.newest_first(breakfast))
	# Nothing shows: no page.
	var order: PackedStringArray = FamilyPalette.shared().main_family_order
	var none: Array[Array] = BookOrder.pages(
		book, BookOrder.Sort.FOOD, BookEntry.COUPON_FAMILY, PER_PAGE, order
	)
	assert_array(none).is_empty()


func _book(profile: ProfileState) -> Array[BookEntry]:
	return BookOrder.entries(
		Kit.balance(),
		profile.unlocked_items,
		FamilyPalette.shared().main_family_order,
		profile.coupon_uses
	)


## Every card `sort` and `filter` show, page by page.
func _shown(book: Array[BookEntry], sort: BookOrder.Sort, filter: String) -> Array[BookEntry]:
	var order: PackedStringArray = FamilyPalette.shared().main_family_order
	var shown: Array[BookEntry] = []
	for page: Array in BookOrder.pages(book, sort, filter, PER_PAGE, order):
		shown.append_array(page)
	return shown


static func _entry(book: Array[BookEntry], id: StringName) -> BookEntry:
	for entry: BookEntry in book:
		if entry.card.id == id:
			return entry
	return null


## The ALL groups with at least one card (each card in one, BookEntry.group), in `main_order`,
## then OTHER_FOOD, then COUPON_FAMILY: the BOOK sort's groups under ALL.
static func _groups(book: Array[BookEntry], main_order: PackedStringArray) -> PackedStringArray:
	var order: PackedStringArray = main_order.duplicate()
	order.append(BookEntry.OTHER_FOOD)
	order.append(BookEntry.COUPON_FAMILY)
	var found: PackedStringArray = PackedStringArray()
	for family: String in order:
		if book.any(func(entry: BookEntry) -> bool: return entry.group == family):
			found.append(family)
	return found
