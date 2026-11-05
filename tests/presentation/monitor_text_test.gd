extends GdUnitTestSuite
## MonitorText's euro helpers ("80€ everywhere", 2026-11-03): every price the player sees puts the
## € after the number with no space, its sign before it, and a step line's leading amount still
## splits off its text.


func test_whole_euros_put_the_sign_after_the_number() -> void:
	assert_str(MonitorText.euros(80)).is_equal("80€")
	assert_str(MonitorText.euros(0)).is_equal("0€")
	assert_str(MonitorText.signed_euros(2)).is_equal("+2€")
	assert_str(MonitorText.signed_euros(0)).is_equal("+0€")
	assert_str(MonitorText.signed_euros(-2)).is_equal("−2€")
	assert_str(ReceiptView.money(80)).is_equal("80.00€")
	assert_str(ReceiptView.money(-3, true)).is_equal("−3.00€")


func test_a_leading_amount_splits_off_its_line() -> void:
	assert_array(Array(MonitorText.step_parts("+1€ Eggs before it"))).is_equal(
		["Eggs before it", "+1€"]
	)
	assert_array(Array(MonitorText.step_parts("−2€ Late delivery"))).is_equal(
		["Late delivery", "−2€"]
	)
	assert_array(Array(MonitorText.step_parts("×2 Eggs"))).is_equal(["×2 Eggs", "×2"])
	assert_array(Array(MonitorText.step_parts("Pays  17€"))).is_equal(["Pays", "17€"])


## A row says its amount once (#138 review): a factor only as the amount, an override's "= 0" as
## "0€" (or not at all when the words say it), a name ending in its amount loses it there.
func test_a_row_says_its_amount_once() -> void:
	assert_array(Array(MonitorText.row_parts("×3 Multipack"))).is_equal(["Multipack", "×3"])
	assert_array(Array(MonitorText.row_parts("Soup beside Frozen  = 0"))).is_equal(
		["Soup beside Frozen", "0€"]
	)
	assert_array(Array(MonitorText.row_parts("Spot check: slot 3 pays 0€  = 0"))).is_equal(
		["Spot check: slot 3 pays 0€", ""]
	)
	assert_array(Array(MonitorText.row_parts("+2€ Bakery festival: Bakery +2€"))).is_equal(
		["Bakery festival: Bakery", "+2€"]
	)
	assert_array(Array(MonitorText.row_parts("+1€ Eggs before it"))).is_equal(
		["Eggs before it", "+1€"]
	)
