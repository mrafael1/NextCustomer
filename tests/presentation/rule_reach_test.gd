extends GdUnitTestSuite
## RuleReach: a works-with chip's rule reaches the belt items its direction and their tags say,
## never a coupon, and names its direction when nothing matches.

const CARDS := "res://data/cards/%s.tres"


## Milk counts every earlier Breakfast item only; with none before it, the tip says so.
func test_an_earlier_rule_reaches_the_earlier_items() -> void:
	var belt: Array[String] = ["cereal", "milk", "coffee", "multipack", "eggs"]
	var reach: RuleReach = _reach(belt, 1, "Breakfast")
	assert_array(Array(reach.slots)).is_equal([0])
	reach = _reach(["milk", "cereal", "coffee"], 0, "Breakfast")
	assert_array(Array(reach.slots)).is_empty()
	assert_str(reach.none_text("Breakfast")).is_equal("No Breakfast item before it on the belt")


## Eggs' "×2 next Food" reaches the first later Food product, past a coupon.
func test_a_next_rule_reaches_the_next_matching_product() -> void:
	var reach: RuleReach = _reach(["bread", "eggs", "multipack", "bread", "milk"], 1, "Food")
	assert_array(Array(reach.slots)).is_equal([3])
	reach = _reach(["bread", "eggs"], 1, "Food")
	assert_str(reach.none_text("Food")).is_equal("No Food item after it on the belt")


## Frozen peas reach the Frozen products beside them, Soup the Frozen beside it (its penalty), and
## the Breakfast sticker the product in the next slot.
func test_beside_and_next_slot_rules() -> void:
	var belt: Array[String] = ["frozen_peas", "frozen_peas", "soup", "frozen_peas"]
	assert_array(Array(_reach(belt, 1, "Frozen").slots)).is_equal([0])
	assert_array(Array(_reach(belt, 2, "Frozen").slots)).is_equal([1, 3])
	var sticker: Array[String] = ["breakfast_sticker", "bread", "milk"]
	assert_array(Array(_reach(sticker, 0, "Breakfast").slots)).is_equal([1])


## A family no rule of the card names reaches every other product of it on the belt.
func test_an_unnamed_family_reaches_the_whole_row() -> void:
	var reach: RuleReach = _reach(["bread", "milk", "cheese"], 1, "Dairy")
	assert_int(reach.direction).is_equal(RuleReach.Direction.ROW)
	assert_array(Array(reach.slots)).is_equal([2])


static func _reach(ids: Array[String], slot: int, family: String) -> RuleReach:
	var tags: Array[PackedStringArray] = []
	var products: Array[bool] = []
	var definitions: Array[CardDefinition] = []
	for id: String in ids:
		var definition: CardDefinition = load(CARDS % id) as CardDefinition
		definitions.append(definition)
		tags.append(definition.tags)
		products.append(definition.is_product())
	return RuleReach.of(definitions[slot], slot, family, tags, products)
