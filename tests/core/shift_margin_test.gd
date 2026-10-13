extends GdUnitTestSuite
## A shift's margin against its quota (#61): over, on (0, a pass) or short, and by how much.


func test_over_the_quota() -> void:
	var margin: ShiftMargin = ShiftMargin.of(109, 34)
	assert_int(margin.kind()).is_equal(ShiftMargin.Kind.OVER)
	assert_int(margin.margin).is_equal(75)
	assert_int(margin.amount()).is_equal(75)
	assert_bool(margin.passed()).is_true()


func test_exactly_on_the_quota_is_a_pass_of_zero() -> void:
	var margin: ShiftMargin = ShiftMargin.of(34, 34)
	assert_int(margin.kind()).is_equal(ShiftMargin.Kind.ON)
	assert_int(margin.amount()).is_equal(0)
	assert_bool(margin.passed()).is_true()


func test_short_of_the_quota() -> void:
	var margin: ShiftMargin = ShiftMargin.of(5, 34)
	assert_int(margin.kind()).is_equal(ShiftMargin.Kind.SHORT)
	assert_int(margin.margin).is_equal(-29)
	assert_int(margin.amount()).is_equal(29)
	assert_bool(margin.passed()).is_false()


## One euro either side of the quota.
func test_one_euro_either_side() -> void:
	assert_int(ShiftMargin.of(35, 34).kind()).is_equal(ShiftMargin.Kind.OVER)
	assert_int(ShiftMargin.of(35, 34).amount()).is_equal(1)
	assert_int(ShiftMargin.of(33, 34).kind()).is_equal(ShiftMargin.Kind.SHORT)
	assert_int(ShiftMargin.of(33, 34).amount()).is_equal(1)
	assert_int(ShiftMargin.of(0, 0).kind()).is_equal(ShiftMargin.Kind.ON)


## It agrees with the run: a shift passes when its total reaches the quota.
func test_it_agrees_with_the_run_record() -> void:
	for total: int in [0, 33, 34, 35, 200]:
		var record: ShiftRecord = ShiftRecord.new(1, 34, total)
		assert_bool(ShiftMargin.of(record.total, record.quota).passed()).is_equal(record.passed)
