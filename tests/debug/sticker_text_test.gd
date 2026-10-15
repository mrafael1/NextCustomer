extends GdUnitTestSuite
## Style frame v2's sticker summaries (debug/style_frame_v2/sticker_texts.tres, #75): every
## fixture card has a template, the templates carry no number (only ordinals such as "2nd"),
## every number and name on a sticker comes from the card's data, and a product a rule names by
## id is spelled as that card's display name.

const STICKERS := preload("res://debug/style_frame_v2/sticker_texts.tres")
const PLACEHOLDER := "\\{([a-z_]+)\\}"
const ORDINAL := "\\d+(st|nd|rd|th)"
## A number that isn't an ordinal ("2nd" stays): the data's numbers, which balance passes may
## change.
const NUMBER := "\\d+(?!st|nd|rd|th)"
## The approved readings' wording (spec section 4.1), with every number from the data as N.
const READINGS: Dictionary[String, String] = {
	"eggs": "×N next Food",
	"tea_bags": "×N next Breakfast",
	"banana": "+N after Banana",
	"batteries": "+N in last slot",
	"two_for_one": "Same both sides: 2nd ×N",
	"crisps": "+N beside Bread",
	"coffee": "+N next Breakfast",
	"milk": "+N per earlier Breakfast",
	"cheese": "+N after Bread",
	"strawberries": "+N beside Produce",
	"croissant": "+N beside Bakery",
	"multipack": "×N later with prior's tag",
}


func test_every_fixture_card_has_a_digit_free_template() -> void:
	var ordinal: RegEx = RegEx.create_from_string(ORDINAL)
	var digit: RegEx = RegEx.create_from_string("\\d")
	var ids: Array[String] = StyleFrameFixture.card_ids()
	assert_int(ids.size()).is_equal(12)
	for card_id: String in ids:
		var definition: CardDefinition = StyleFrameFixture.card(card_id)
		assert_bool(STICKERS.has_template(definition)).override_failure_message(card_id).is_true()
		var template: String = STICKERS.templates[definition.id]
		var without_ordinals: String = ordinal.sub(template, "", true)
		(
			assert_object(digit.search(without_ordinals))
			. override_failure_message("%s: %s" % [card_id, template])
			. is_null()
		)


func test_summaries_take_their_numbers_and_names_from_the_data() -> void:
	var placeholder: RegEx = RegEx.create_from_string(PLACEHOLDER)
	var number: RegEx = RegEx.create_from_string(NUMBER)
	for card_id: String in StyleFrameFixture.card_ids():
		var definition: CardDefinition = StyleFrameFixture.card(card_id)
		var summary: String = STICKERS.summary(definition)
		var message: String = "%s: %s" % [card_id, summary]
		assert_str(summary).override_failure_message(message).is_not_empty()
		assert_bool(summary.contains("{") or summary.contains("}")).is_false()
		var values: Dictionary = StickerTexts.values(definition)
		for found: RegExMatch in placeholder.search_all(STICKERS.templates[definition.id]):
			var key: String = found.get_string(1)
			assert_bool(values.has(key)).override_failure_message(message + " " + key).is_true()
			if values[key] is int:
				(
					assert_bool(summary.contains(str(values[key])))
					. override_failure_message(message + " " + key)
					. is_true()
				)
		# The wording without the numbers (the loop above checks those against the data).
		assert_str(number.sub(summary, "N", true)).override_failure_message(message).is_equal(
			READINGS[card_id]
		)


## A rule that names a product by id (Cheese and Crisps name Bread) spells it as that card's
## display name.
func test_named_products_are_spelled_as_their_cards() -> void:
	var checked: int = 0
	for card_id: String in StyleFrameFixture.card_ids():
		var definition: CardDefinition = StyleFrameFixture.card(card_id)
		var rule: AdjacentMatchBonusRule = definition.rules[0] as AdjacentMatchBonusRule
		if rule == null or rule.match_by != AdjacentMatchBonusRule.Match.CARD_ID:
			continue
		var named: CardDefinition = StyleFrameFixture.card(rule.match_value)
		assert_bool(STICKERS.summary(definition).contains(named.display_name)).is_true()
		checked += 1
	assert_int(checked).is_equal(2)
