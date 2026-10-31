extends GdUnitTestSuite
## Data rules from plan sections 3.7, 3.8 and 3.9 and core/AGENTS.md: neutral defaults in
## rule, upgrade, inspection and card scripts, every card states its kind, every upgrade its
## type, every inspection its id and notice, and the golden fixture is self-contained.

const FIXTURE_DIR := "res://tests/fixtures/cards_v0_4"
const FIXTURE_V0_5_DIR := "res://tests/fixtures/cards_v0_5"
const FIXTURE_V0_6_DIR := "res://tests/fixtures/cards_v0_6"
const FIXTURE_DIRS := [FIXTURE_DIR, FIXTURE_V0_5_DIR, FIXTURE_V0_6_DIR]
const CARD_DIRS := ["res://data/cards", FIXTURE_DIR, FIXTURE_V0_5_DIR, FIXTURE_V0_6_DIR]
const NEUTRAL_SCRIPTS := [
	"res://core/card_definition.gd",
	"res://core/deck_definition.gd",
	"res://core/balance_definition.gd",
	"res://core/upgrade_definition.gd",
	"res://core/build_definition.gd",
	"res://core/inspection_definition.gd",
	"res://core/unlock_condition.gd",
	"res://core/aisle_definition.gd",
	"res://core/catalogue_definition.gd",
	"res://core/pin_definition.gd",
]
const RULE_DIRS := ["res://core/rules", "res://core/upgrades", "res://core/inspections"]
const UPGRADE_DIR := "res://data/upgrades"
const CATALOGUE := "res://data/catalogue/catalogue.tres"
const INSPECTION_DIR := "res://data/inspections"


## Godot omits values equal to the script default from .tres files, so a non-neutral default
## would let a script edit silently change card data and the fixture.
func test_exported_values_default_to_neutral() -> void:
	var scripts: Array[String] = []
	scripts.assign(NEUTRAL_SCRIPTS)
	scripts.append("res://core/rule.gd")
	for dir: String in RULE_DIRS:
		for file: String in DirAccess.get_files_at(dir):
			if file.ends_with(".gd"):
				scripts.append("%s/%s" % [dir, file])
	assert_bool(scripts.has("res://core/upgrades/upgrade_rule.gd")).is_true()
	assert_bool(scripts.has("res://core/inspections/inspection_rule.gd")).is_true()
	assert_int(scripts.size()).is_greater(15)
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
				TYPE_PACKED_STRING_ARRAY, TYPE_PACKED_INT32_ARRAY, TYPE_ARRAY, TYPE_DICTIONARY:
					assert_int(value.size()).override_failure_message(where).is_equal(0)
				TYPE_COLOR:
					assert_that(value).override_failure_message(where).is_equal(Color())
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
		var by_id: Dictionary[StringName, CardDefinition] = {}
		var cards: Array[CardDefinition] = []
		for file: String in DirAccess.get_files_at(dir):
			if not file.ends_with(".tres"):
				continue
			var card: CardDefinition = load("%s/%s" % [dir, file])
			assert_str(String(card.id)).override_failure_message(file).is_equal(file.get_basename())
			assert_bool(ids.has(card.id)).override_failure_message(file).is_false()
			ids[card.id] = true
			by_id[card.id] = card
			cards.append(card)
		for card: CardDefinition in cards:
			for rule: Rule in card.rules:
				var match_rule: AdjacentMatchBonusRule = rule as AdjacentMatchBonusRule
				if match_rule and match_rule.match_by == AdjacentMatchBonusRule.Match.CARD_ID:
					var named: StringName = StringName(match_rule.match_value)
					assert_bool(ids.has(named)).override_failure_message(card.id).is_true()
					# A variant counts as its base card (plan 3.4, "same product"), so a rule
					# that named a variant could never match: it must name the base card.
					if ids.has(named):
						(
							assert_object(by_id[named].variant_of)
							. override_failure_message("%s names a variant" % card.id)
							. is_null()
						)


## Plan section 3.8: like a card's kind, an upgrade's type has an UNSET default that no
## upgrade file may keep. Ids are present, unique and match the file name.
func test_every_upgrade_states_its_type_and_id() -> void:
	var files: PackedStringArray = DirAccess.get_files_at(UPGRADE_DIR)
	var ids: Dictionary = {}
	for file: String in files:
		if not file.ends_with(".tres"):
			continue
		var upgrade: UpgradeDefinition = load("%s/%s" % [UPGRADE_DIR, file])
		assert_int(upgrade.type).override_failure_message(file).is_not_equal(
			UpgradeDefinition.Type.UNSET
		)
		assert_str(String(upgrade.id)).override_failure_message(file).is_equal(file.get_basename())
		assert_bool(ids.has(upgrade.id)).override_failure_message(file).is_false()
		ids[upgrade.id] = true
		assert_str(upgrade.display_name).override_failure_message(file).is_not_empty()
		assert_str(upgrade.effect_text).override_failure_message(file).is_not_empty()
		for build: BuildDefinition in upgrade.builds:
			assert_object(build).override_failure_message(file).is_not_null()
		# Only Extra redraw (each level of it) supports any build (no build listed); a family perk
		# or a jackpot (#108) fits by its family or its product instead.
		var fits_by_family: bool = not upgrade.boosts_tag.is_empty() or upgrade.needs_card != null
		if upgrade.family() != &"extra_redraw" and not fits_by_family:
			assert_array(upgrade.builds).override_failure_message(file).is_not_empty()
		_assert_level_chain(upgrade, file)
	# Extra coupon slot was removed in plan v0.46 (#106); #108 added LV 2 and LV 3 of four perks,
	# then (piece 2) 7 Regulars and 7 Aisle runs, Mixed basket and Bulk deal at 3 levels each and
	# the 3 jackpots.
	assert_int(ids.size()).is_equal(65)


## A loyalty level (#108): LV 1 has no family id, a level file names its LV 1 file as family and
## is LV 2 or 3, and each next level is one level up, of the same family, name, type and builds,
## up to LV 3.
func _assert_level_chain(upgrade: UpgradeDefinition, file: String) -> void:
	if upgrade.level_number() == 1:
		assert_str(String(upgrade.family_id)).override_failure_message(file).is_empty()
	else:
		assert_int(upgrade.level).override_failure_message(file).is_between(2, 3)
		var first: UpgradeDefinition = load("%s/%s.tres" % [UPGRADE_DIR, upgrade.family_id])
		assert_object(first).override_failure_message(file).is_not_null()
	var next: UpgradeDefinition = upgrade.next_level
	if next == null:
		return
	assert_int(next.level_number()).override_failure_message(file).is_equal(
		upgrade.level_number() + 1
	)
	assert_int(next.level_number()).override_failure_message(file).is_less_equal(3)
	assert_bool(next.same_perk(upgrade)).override_failure_message(file).is_true()
	assert_str(next.display_name).override_failure_message(file).is_equal(upgrade.display_name)
	assert_int(next.type).override_failure_message(file).is_equal(upgrade.type)
	assert_array(next.builds).override_failure_message(file).is_equal(upgrade.builds)


## Plan section 5.2: like an upgrade's type, a build's measure has an UNSET default that no
## build file may keep. Ids are present, unique and match the file name, and every build needs
## at least one card to fit.
func test_every_build_states_its_measure_and_id() -> void:
	var ids: Dictionary = {}
	for file: String in DirAccess.get_files_at("res://data/builds"):
		if not file.ends_with(".tres"):
			continue
		var build: BuildDefinition = load("res://data/builds/%s" % file)
		assert_int(build.measure).override_failure_message(file).is_not_equal(
			BuildDefinition.Measure.UNSET
		)
		assert_str(String(build.id)).override_failure_message(file).is_equal(file.get_basename())
		assert_bool(ids.has(build.id)).override_failure_message(file).is_false()
		ids[build.id] = true
		assert_str(build.display_name).override_failure_message(file).is_not_empty()
		assert_int(build.min_count).override_failure_message(file).is_greater(0)
	assert_int(ids.size()).is_equal(5)


## Plan section 3.9: every inspection has an id matching its file name (unique), a name and a
## notice to announce.
func test_every_inspection_states_its_id_and_notice() -> void:
	var ids: Dictionary = {}
	for file: String in DirAccess.get_files_at(INSPECTION_DIR):
		if not file.ends_with(".tres"):
			continue
		var inspection: InspectionDefinition = load("%s/%s" % [INSPECTION_DIR, file])
		assert_str(String(inspection.id)).override_failure_message(file).is_equal(
			file.get_basename()
		)
		assert_bool(ids.has(inspection.id)).override_failure_message(file).is_false()
		ids[inspection.id] = true
		assert_str(inspection.display_name).override_failure_message(file).is_not_empty()
		assert_str(inspection.notice_text).override_failure_message(file).is_not_empty()
		assert_str(inspection.chip_text).override_failure_message(file).is_not_empty()
	# Coupon slot closed was removed in plan v0.46 (#106); v0.69's day events: 6 inspections
	# (maluses) and 6 boons.
	assert_int(ids.size()).is_equal(12)


## Full build plan 7.3: the catalogue lists every deck file and every card variant, each once,
## so the end-of-run unlock check sees them all. Item tiers (#77) are variants too, but they are
## run upgrades, not unlocks: the catalogue never lists them.
func test_the_catalogue_lists_every_deck_and_variant() -> void:
	var catalogue: CatalogueDefinition = load(CATALOGUE)
	var decks: Array[DeckDefinition] = []
	for file: String in DirAccess.get_files_at("res://data/decks"):
		if file.ends_with(".tres"):
			decks.append(load("res://data/decks/" + file))
	assert_int(catalogue.decks.size()).is_equal(decks.size())
	assert_array(catalogue.decks).contains_exactly_in_any_order(decks)
	var variants: Array[CardDefinition] = []
	for file: String in DirAccess.get_files_at("res://data/cards"):
		var card: CardDefinition = (
			load("res://data/cards/" + file) if file.ends_with(".tres") else null
		)
		if card != null and card.variant_of != null and card.tier == CardDefinition.Tier.PLAIN:
			variants.append(card)
	assert_int(catalogue.variants.size()).is_equal(variants.size())
	assert_array(catalogue.variants).contains_exactly_in_any_order(variants)


## Full build plan 7.4 (#122): the catalogue lists every badge pin file, each once, and every pin
## has an id matching its file, a name, a rule, a face and something it does; a milestone can
## work.
func test_the_catalogue_lists_every_well_formed_pin() -> void:
	var catalogue: CatalogueDefinition = load(CATALOGUE)
	var pins: Array[PinDefinition] = []
	for file: String in DirAccess.get_files_at("res://data/pins"):
		if not file.ends_with(".tres"):
			continue
		var pin: PinDefinition = load("res://data/pins/" + file)
		pins.append(pin)
		assert_str(String(pin.id)).override_failure_message(file).is_equal(file.get_basename())
		assert_str(pin.display_name).override_failure_message(file).is_not_empty()
		assert_str(pin.rule_text).override_failure_message(file).is_not_empty()
		assert_str(pin.face_text).override_failure_message(file).is_not_empty()
		var does: bool = not pin.starting_cards.is_empty() or pin.full_redraw
		assert_bool(does).override_failure_message(file).is_true()
		if pin.unlock_condition != null:
			assert_array(pin.unlock_condition.problems()).override_failure_message(file).is_empty()
	assert_int(pins.size()).is_greater(1)
	assert_int(catalogue.pins.size()).is_equal(pins.size())
	assert_array(catalogue.pins).contains_exactly_in_any_order(pins)


## Full build plan 7.3: every deck has an id matching its file, a name and a description; a
## variant is a variant of a card that is not itself a variant, of the same kind; and every
## unlock condition can work.
func test_decks_and_variants_are_well_formed() -> void:
	var deck_dir: String = "res://data/decks"
	for file: String in DirAccess.get_files_at(deck_dir):
		if not file.ends_with(".tres"):
			continue
		var deck: DeckDefinition = load("%s/%s" % [deck_dir, file])
		assert_str(String(deck.id)).override_failure_message(file).is_equal(file.get_basename())
		assert_str(deck.display_name).override_failure_message(file).is_not_empty()
		assert_str(deck.description).override_failure_message(file).is_not_empty()
		# A fixed deck lists its cards; a recipe (v0.49) its core cards, and no dealt cards.
		var cards: Array[CardDefinition] = deck.core_cards if deck.is_recipe() else deck.cards
		assert_array(cards).override_failure_message(file).is_not_empty()
		if deck.is_recipe():
			assert_array(deck.cards).override_failure_message(file).is_empty()
			assert_int(deck.copy_max).override_failure_message(file).is_greater(0)
		if deck.unlock_condition != null:
			assert_array(deck.unlock_condition.problems()).override_failure_message(file).is_empty()
	for dir: String in CARD_DIRS:
		for file: String in DirAccess.get_files_at(dir):
			if not file.ends_with(".tres"):
				continue
			var card: CardDefinition = load("%s/%s" % [dir, file])
			if card.unlock_condition != null:
				(
					assert_array(card.unlock_condition.problems())
					. override_failure_message(file)
					. is_empty()
				)
			assert_array(card.variant_problems()).override_failure_message(file).is_empty()


## Full build plan section 4: a run save names content by id, so every card, upgrade,
## inspection and deck file must resolve through ContentLookup by its file name (a plain name
## equal to the resource's id), and every aisle of the balance by its id.
func test_every_data_id_resolves_through_the_content_lookup() -> void:
	var lookup: ContentLookup = ContentLookup.new(load("res://data/balance/balance.tres"))
	var resolvers: Dictionary[String, Callable] = {
		ContentLookup.CARDS_FOLDER: lookup.card,
		ContentLookup.UPGRADES_FOLDER: lookup.upgrade,
		ContentLookup.INSPECTIONS_FOLDER: lookup.inspection,
		ContentLookup.DECKS_FOLDER: lookup.deck,
	}
	var checked: int = 0
	for folder: String in resolvers:
		var dir: String = ContentLookup.DATA_ROOT.path_join(folder)
		for file: String in DirAccess.get_files_at(dir):
			if not file.ends_with(".tres"):
				continue
			var resolved: Resource = resolvers[folder].call(file.get_basename())
			assert_object(resolved).override_failure_message(file).is_same(
				load(dir.path_join(file))
			)
			checked += 1
	assert_int(checked).is_greater(15)
	for aisle: AisleDefinition in lookup.balance.aisles:
		assert_object(lookup.aisle(String(aisle.id))).is_same(aisle)


func test_fixtures_never_point_at_live_data() -> void:
	for fixture: String in FIXTURE_DIRS:
		for file: String in DirAccess.get_files_at(fixture):
			var text: String = FileAccess.get_file_as_string("%s/%s" % [fixture, file])
			assert_bool(text.contains("res://data/")).override_failure_message(file).is_false()
