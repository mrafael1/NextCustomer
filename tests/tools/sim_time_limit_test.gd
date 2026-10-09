extends GdUnitTestSuite
## The balance simulator's time limit (--max-minutes, tools/balance_sim/sim_time_limit.gd): the
## time is shared out between the phases, and a stopped search or run is dropped, never cached
## or reported half-played.

const BalanceSimTest := preload("res://tests/tools/balance_sim_test.gd")


## --max-minutes: the time is shared out between the phases, and a phase can use what earlier
## ones left over.
func test_time_limit_shares_the_time_between_phases() -> void:
	var limit: SimTimeLimit = SimTimeLimit.new(1.0, 3, 0)
	limit.begin_phase(0)
	assert_bool(limit.is_phase_over(19999)).is_false()
	assert_bool(limit.is_phase_over(20000)).is_true()
	# The first phase took only 5 s: the other two share the 55 s left.
	limit.begin_phase(5000)
	assert_bool(limit.is_phase_over(32499)).is_false()
	assert_bool(limit.is_phase_over(32500)).is_true()
	assert_bool(limit.was_hit()).is_true()


func test_no_time_limit_never_stops() -> void:
	var limit: SimTimeLimit = SimTimeLimit.new(0.0, 2, 0)
	limit.begin_phase(0)
	assert_bool(limit.is_phase_over(1000000000)).is_false()
	assert_bool(limit.was_hit()).is_false()


func test_a_phase_that_starts_after_the_end_is_over_at_once() -> void:
	var limit: SimTimeLimit = SimTimeLimit.new(1.0, 2, 0)
	limit.begin_phase(90000)
	assert_bool(limit.is_phase_over(90000)).is_true()


## --max-minutes: a search past its time stops where it is and caches nothing, so the same
## search later gives the full result.
func test_a_search_past_its_time_stops_and_caches_nothing() -> void:
	var no_upgrades: Array[UpgradeDefinition] = []
	var hand: String = "eggs,banana,banana,repeat,soup,frozen_peas,final_markdown"
	var search: SimRowSearch = SimRowSearch.new(BalanceSimTest._balance(6, 1))
	search.stop_at_msec = 1
	search.search(BalanceSimTest._cards(hand), no_upgrades)
	assert_bool(search.stopped).is_true()
	assert_int(search.cache_size()).is_equal(0)
	search.stop_at_msec = 0
	search.stopped = false
	var full: SimHandBest = SimRowSearch.new(BalanceSimTest._balance(6, 1)).search(
		BalanceSimTest._cards(hand), no_upgrades
	)
	assert_int(search.search(BalanceSimTest._cards(hand), no_upgrades).score).is_equal(full.score)


## A run the time limit stops partway is dropped (no record), never reported half-played.
func test_a_run_past_its_time_is_dropped() -> void:
	var player: SimPlayer = _helpers()._player("greedy")
	player._search.stop_at_msec = 1
	assert_object(player.play(5)).is_null()
	player._search.stop_at_msec = 0
	player._search.stopped = false
	assert_object(player.play(5)).is_not_null()


func _helpers() -> BalanceSimTest:
	return auto_free(BalanceSimTest.new())
