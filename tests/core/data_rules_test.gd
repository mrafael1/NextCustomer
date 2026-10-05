extends GdUnitTestSuite
## Data rules from plan section 3.7 and core/AGENTS.md: neutral defaults in rule and card
## scripts, every card states its kind, and the golden fixture is self-contained.

const FIXTURE_DIR := "res://tests/fixtures/cards_v0_4"
const CARD_DIRS := ["res://data/cards", FIXTURE_DIR]
const NEUTRAL_SCRIPTS := ["res://core/card_definition.gd", "res://core/deck_definition.gd"]


## Godot omits values equal to the script default from .tres files, so a non-neutral default
## would let a script edit silently change card data and the fixture.
func test_exported_values_default_to_neutral() -> void:
	var scripts: Array[String] = []
	scripts.assign(NEUTRAL_SCRIPTS)
	scripts.append("res://core/rule.gd")
	for file: String in DirAccess.get_files_at("res://core/rules"):
		if file.ends_with(".gd"):
			scripts.append("res://core/rules/" + file)
	assert_int(scripts.size()).is_greater(10)
	for path: String in scripts:
		var instance: Object = (load(path) as GDScript).new()
		for property: Dictionary in instance.get_property_list():
			if not property["usage"] & PROPERTY_USAGE_SCRIPT_VARIABLE:
				continue
			if not property["usage"] & PROPERTY_USAGE_STORAGE:
				continue
			var property_name: String = property["name"]
			var value: Variant = instance.get(property_name)
			var where: String = "%s: %s = %s" % [path, property_name, value]
			match typeof(value):
				TYPE_INT:
					var neutral: int = 1 if property_name.ends_with("factor") else 0
					assert_int(value).override_failure_message(where).is_equal(neutral)
				TYPE_BOOL:
					assert_bool(value).override_failure_message(where).is_false()
				TYPE_STRING, TYPE_STRING_NAME:
					assert_str(str(value)).override_failure_message(where).is_empty()
				TYPE_FLOAT:
					var neutral_float: float = 1.0 if property_name.ends_with("factor") else 0.0
					assert_float(value).override_failure_message(where).is_equal(neutral_float)
				TYPE_PACKED_STRING_ARRAY, TYPE_ARRAY, TYPE_DICTIONARY:
					assert_int(value.size()).override_failure_message(where).is_equal(0)
				TYPE_NIL, TYPE_OBJECT:
					assert_object(value).override_failure_message(where).is_null()
				_:
					fail(
						(
							"%s: exported type %d has no neutral-default check yet"
							% [where, typeof(value)]
						)
					)


func test_every_card_states_its_kind() -> void:
	for dir: String in CARD_DIRS:
		var files: PackedStringArray = DirAccess.get_files_at(dir)
		assert_int(files.size()).override_failure_message(dir).is_greater(0)
		for file: String in files:
			if not file.ends_with(".tres"):
				continue
			var card: CardDefinition = load("%s/%s" % [dir, file])
			assert_int(card.kind).override_failure_message(file).is_not_equal(
				CardDefinition.Kind.UNSET
			)
			assert_bool(card.is_connector and not card.is_coupon()).is_false()


## Banana's and Cheese's rules match cards by id, so ids must be present, unique, match the
## file name, and every id a rule names must exist.
func test_card_ids_are_valid() -> void:
	for dir: String in CARD_DIRS:
		var ids: Dictionary = {}
		var cards: Array[CardDefinition] = []
		for file: String in DirAccess.get_files_at(dir):
			if not file.ends_with(".tres"):
				continue
			var card: CardDefinition = load("%s/%s" % [dir, file])
			assert_str(String(card.id)).override_failure_message(file).is_equal(file.get_basename())
			assert_bool(ids.has(card.id)).override_failure_message(file).is_false()
			ids[card.id] = true
			cards.append(card)
		for card: CardDefinition in cards:
			for rule: Rule in card.rules:
				var match_rule: AdjacentMatchBonusRule = rule as AdjacentMatchBonusRule
				if match_rule and match_rule.match_by == AdjacentMatchBonusRule.Match.CARD_ID:
					var named: StringName = StringName(match_rule.match_value)
					assert_bool(ids.has(named)).override_failure_message(card.id).is_true()


func test_fixture_never_points_at_live_data() -> void:
	for file: String in DirAccess.get_files_at(FIXTURE_DIR):
		var text: String = FileAccess.get_file_as_string("%s/%s" % [FIXTURE_DIR, file])
		assert_bool(text.contains("res://data/")).override_failure_message(file).is_false()
