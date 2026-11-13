extends GdUnitTestSuite
## The opening-time aisle booster draw (StartBoosterDraw, full build plan 7.2, v1.32): the hit
## card's RARE odds (start_booster_hit_rare_percent), never GOLDEN, the products' hidden draw
## weights, the copy rule and a short booster. On the live data, with test streams.

const Kit := preload("res://tests/core/start_setup_kit.gd")
const SEED := 20261113

var _balance: BalanceDefinition
var _recipe: DeckDefinition


func before_test() -> void:
	_balance = Kit.balance()
	_recipe = Kit.recipe()


## The hit card is RARE (its chain's BIG tier) about start_booster_hit_rare_percent (50) of the
## time; commons never roll; GOLDEN never; at 0 never RARE, at 100 always (with a BIG to take).
func test_the_hit_card_is_rare_about_half_the_time_and_never_golden() -> void:
	assert_int(_balance.start_booster_hit_rare_percent).is_equal(50)
	assert_int(_balance.start_booster_hit_slots).is_equal(1)
	var run: RunState = Kit.run(Kit.profile(3), SEED)
	var aisle: StringName = run.start_setup.stock_aisles[0]
	var pool: Array[CardDefinition] = StartBoosterDraw.pool(run, Kit.profile(3), aisle)
	assert_int(pool.size()).is_greater(_balance.start_booster_size)
	var rng: RandomNumberGenerator = EventLogService.derived_stream(SEED, "test_hits")
	var rare: int = 0
	var draws: int = 400
	for _draw: int in draws:
		var copies: Dictionary[CardDefinition, int] = {}
		var booster: StartBooster = StartBoosterDraw.draw(
			_balance, run.starter, aisle, pool, copies, rng
		)
		_assert_booster(booster)
		rare += booster.rare_count()
	assert_float(float(rare) / draws).is_between(0.42, 0.58)
	for percent: int in [0, 100]:
		var odds: BalanceDefinition = _balance.duplicate()
		odds.start_booster_hit_rare_percent = percent
		for _draw: int in 20:
			var copies: Dictionary[CardDefinition, int] = {}
			var booster: StartBooster = StartBoosterDraw.draw(
				odds, run.starter, aisle, pool, copies, rng
			)
			assert_int(booster.rare_count()).is_equal(1 if percent == 100 else 0)


## Products are picked by their hidden draw_weight (0 never), distinct, under copy_max; a pool
## that runs dry gives a short booster (its hit place is the last one reached, or none).
func test_a_booster_draws_by_weight_under_the_copy_rule_and_can_come_up_short() -> void:
	var heavy: CardDefinition = _card(&"test_heavy", 3)
	var light: CardDefinition = _card(&"test_light", 1)
	var never: CardDefinition = _card(&"test_never", 0)
	var pool: Array[CardDefinition] = [heavy, light, never]
	var one: BalanceDefinition = _balance.duplicate()
	one.start_booster_size = 1
	one.start_booster_hit_slots = 0
	var rng: RandomNumberGenerator = EventLogService.derived_stream(SEED, "test_weights")
	var counts: Dictionary[CardDefinition, int] = {}
	for _draw: int in 400:
		var copies: Dictionary[CardDefinition, int] = {}
		var booster: StartBooster = StartBoosterDraw.draw(one, _recipe, &"x", pool, copies, rng)
		counts[booster.cards[0]] = int(counts.get(booster.cards[0], 0)) + 1
	assert_int(int(counts.get(never, 0))).is_equal(0)
	assert_float(float(counts[heavy]) / 400.0).is_between(0.68, 0.82)
	# Three places, two cards open (one at copy_max): short, its hit place never reached.
	var capped: Dictionary[CardDefinition, int] = {light: _recipe.copy_max}
	var short: StartBooster = StartBoosterDraw.draw(
		_balance, _recipe, &"x", [heavy, light, never], capped, rng
	)
	assert_array(short.cards).is_equal([heavy])
	assert_int(short.hits).is_equal(0)
	assert_bool(short.is_hit(0)).is_false()


## A booster's own checks: cards of its aisle, distinct products, at most the size, BIG only at a
## hit place, never GOLDEN.
func _assert_booster(booster: StartBooster) -> void:
	assert_int(booster.cards.size()).is_less_equal(_balance.start_booster_size)
	var products: Array[CardDefinition] = []
	for index: int in booster.cards.size():
		var card: CardDefinition = booster.cards[index]
		assert_bool(Kit.of_aisle(card, booster.aisle)).is_true()
		assert_bool(products.has(card.product_card())).is_false()
		products.append(card.product_card())
		assert_int(card.tier).is_not_equal(CardDefinition.Tier.GOLDEN)
		if card.tier == CardDefinition.Tier.BIG:
			assert_bool(booster.is_hit(index)).is_true()


static func _card(id: StringName, weight: int) -> CardDefinition:
	var card: CardDefinition = CardDefinition.new()
	card.id = id
	card.kind = CardDefinition.Kind.PRODUCT
	card.draw_weight = weight
	return card
