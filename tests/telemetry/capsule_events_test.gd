extends GdUnitTestSuite
## The TOY MACHINES' telemetry (#63): the `capsule` event and the derived streams.

const BALANCE := "res://data/balance/balance.tres"


## The `capsule` event (#63): the machine, the item, its run index, the coins left, the draw's
## stream index and the seed as a decimal string (it can pass 2^31).
func test_capsule_event_fields() -> void:
	var balance: BalanceDefinition = load(BALANCE)
	var bakery: AisleDefinition = balance.aisles[4]
	var data: Dictionary = RunEvents.capsule(bakery, bakery.capsule_cards[0], -1, 3, 7, 4294967295)
	(
		assert_dict(data)
		. is_equal(
			{
				"machine": "bakery",
				"item": "baguette",
				"run_index": -1,
				"coins_left": 3,
				"draw": 7,
				"capsule_seed": "4294967295",
			}
		)
	)
	var read: Dictionary = JSON.parse_string(JSON.stringify(data))
	assert_str(read["capsule_seed"]).is_equal("4294967295")


## The derived streams of #63: the surprise list's and each capsule draw's, the same for the
## same seed and name, and different draws get different streams.
func test_capsule_and_surprise_list_streams() -> void:
	var first: RandomNumberGenerator = EventLogService.capsule_stream(5, 0)
	assert_int(first.seed).is_equal(EventLogService.derived_stream(5, "capsule_0").seed)
	assert_int(EventLogService.capsule_stream(5, 0).randi()).is_equal(first.randi())
	assert_int(EventLogService.capsule_stream(5, 1).seed).is_not_equal(
		EventLogService.capsule_stream(5, 0).seed
	)
	assert_str(EventLogService.SURPRISE_LIST_STREAM).is_equal("surprise_list")
