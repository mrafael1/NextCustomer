extends GdUnitTestSuite
## CouponFinds (the handbook's found coupons, 2026-11-15): a coupon in a run's cart is found (an
## "own:" flag in the profile's seen, kept by RESET TIPS), a product never is, and a coupon used
## in an ended run counts too.

const BALANCE := "res://data/balance/balance.tres"


func test_owned_coupons_are_found() -> void:
	var balance: BalanceDefinition = load(BALANCE) as BalanceDefinition
	var lookup: ContentLookup = ContentLookup.new(balance)
	var profile: ProfileState = ProfileState.new()
	var coupon: CardDefinition = lookup.card("two_for_one")
	var product: CardDefinition = lookup.card("milk")
	assert_bool(CouponFinds.found(profile, &"two_for_one")).is_false()
	var cards: Array[CardInstance] = [CardInstance.new(product, 1), CardInstance.new(coupon, 2)]
	assert_bool(CouponFinds.note(profile, cards)).is_true()
	assert_bool(CouponFinds.note(profile, cards)).is_false()
	assert_bool(CouponFinds.found(profile, &"two_for_one")).is_true()
	assert_bool(profile.seen.has(CouponFinds.flag(&"milk"))).is_false()
	TutorialFlags.reset_tips(profile)
	assert_bool(CouponFinds.found(profile, &"two_for_one")).is_true()
	profile.coupon_uses[&"multipack"] = 2
	assert_bool(CouponFinds.found(profile, &"multipack")).is_true()
	var again: ProfileState = ProfileState.from_dictionary(profile.to_dictionary())
	assert_bool(CouponFinds.found(again, &"two_for_one")).is_true()
