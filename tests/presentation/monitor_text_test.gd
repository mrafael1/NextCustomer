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
	assert_str(ReceiptView.money(80)).is_equal("80€")
	assert_str(ReceiptView.money(-3, true)).is_equal("−3€")


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


## A "gives" row's equation (v1.11): the target's price before, each effect as its operator and
## its number, "=" and the price after; an effect that is no arithmetic says the change alone.
func test_an_equation_spells_out_each_effect() -> void:
	var arrow: String = "=>"
	var times: PackedStringArray = PackedStringArray(["×2"])
	assert_str(MonitorText.equation(2, times, 4, arrow)).is_equal("2€ × 2 = 4€")
	var plus: PackedStringArray = PackedStringArray(["+3€"])
	assert_str(MonitorText.equation(4, plus, 7, arrow)).is_equal("4€ + 3€ = 7€")
	var minus: PackedStringArray = PackedStringArray(["−2€"])
	assert_str(MonitorText.equation(6, minus, 4, arrow)).is_equal("6€ − 2€ = 4€")
	var hyphen: PackedStringArray = PackedStringArray(["-2€"])
	assert_str(MonitorText.equation(6, hyphen, 4, arrow)).is_equal("6€ - 2€ = 4€")
	var both: PackedStringArray = PackedStringArray(["×2", "+3€"])
	assert_str(MonitorText.equation(2, both, 7, arrow)).is_equal("2€ × 2 + 3€ = 7€")
	var override: PackedStringArray = PackedStringArray(["=0"])
	assert_str(MonitorText.equation(17, override, 0, arrow)).is_equal("17€ => 0€")
	var after_times: PackedStringArray = PackedStringArray(["×2", "=0"])
	assert_str(MonitorText.equation(17, after_times, 0, arrow)).is_equal("17€ => 0€")


## Point A (2026-11-05): a copy's line on its copier names the source with the copied amount on
## the amounts' column; its source's note names the copier, none without one.
func test_copy_wording() -> void:
	var line: String = MonitorText.copied_from("Golden Milk", 264)
	assert_str(line).is_equal("Copied from Golden Milk  264€")
	assert_array(MonitorText.row_parts(line)).is_equal(
		PackedStringArray(["Copied from Golden Milk", "264€"])
	)
	assert_str(MonitorText.copied_by("Repeat")).is_equal("Copied by Repeat")
	assert_str(MonitorText.copied_by("")).is_empty()
