extends GdUnitTestSuite
## PlanningModel (#71, mock-up h1, H1_BUILD_SPEC.md sections 2, 5 and 7) and the links' gains:
## the reference row's stickers, pays, stamps and strips; the five pay states, the halo's ring
## thresholds and both stamp kinds on synthetic results; EffectLink.gain and cancelled; the
## monitor key's entries; the lane rule; and every golden row builds a model whose numbers all
## come from its steps and payouts. Pure data: no saves, no event log, no Node.

const GoldenRows := preload("res://tests/ui/scan_popup_golden_rows_test.gd")
const PlanTest := preload("res://tests/presentation/count_up_plan_test.gd")
const TUNING := "res://data/balance/planning.tres"
const UPGRADES: Array[String] = [
	"res://data/upgrades/coupon_engine.tres",
	"res://data/upgrades/slot_engine.tres",
]
const INSPECTION := "res://data/inspections/spot_check.tres"


func test_the_reference_row_shows_its_stickers_in_step_order() -> void:
	var model: PlanningModel = _reference_model()
	assert_int(model.slots.size()).is_equal(7)
	# Eggs gives and receives nothing.
	assert_array(model.slots[0].stickers).is_empty()
	# Bread: Eggs' ×2, with the item badge "Eg".
	_assert_stickers(
		model.slots[1], [[StickerSpec.Kind.MULTIPLY, "×2", GiverBadge.Kind.ITEM, "Eg"]]
	)
	# Milk 3: its own bonus (no badge); the Spot check's denial is the stamp, not a sticker.
	var milk: StickerSpec = model.slots[2].stickers[0]
	assert_int(model.slots[2].stickers.size()).is_equal(1)
	assert_int(milk.kind).is_equal(StickerSpec.Kind.ADD)
	assert_int(milk.badge).is_equal(GiverBadge.Kind.NONE)
	assert_str(milk.badge_text).is_empty()
	# Multipack: Coupon engine's fizzle, with the loyalty badge (its box's initials).
	_assert_stickers(
		model.slots[3], [[StickerSpec.Kind.FIZZLE, "pfff", GiverBadge.Kind.LOYALTY, "CoE"]]
	)
	# Milks 5 to 7: their own bonus, then Multipack's ×3 (coupon badge); the 6th product also
	# gets Slot engine's ×2 last.
	for slot: int in [4, 5, 6]:
		var stickers: Array[StickerSpec] = model.slots[slot].stickers
		assert_int(stickers[0].kind).is_equal(StickerSpec.Kind.ADD)
		assert_int(stickers[0].badge).is_equal(GiverBadge.Kind.NONE)
		assert_str(stickers[1].text).is_equal("×3")
		assert_int(stickers[1].badge).is_equal(GiverBadge.Kind.COUPON)
		assert_str(stickers[1].badge_text).is_equal("Mu")
		assert_int(stickers[1].cause_slot).is_equal(3)
	assert_int(model.slots[4].stickers.size()).is_equal(2)
	assert_int(model.slots[6].stickers.size()).is_equal(3)
	_assert_sticker(
		model.slots[6].stickers[2],
		[StickerSpec.Kind.MULTIPLY, "×2", GiverBadge.Kind.LOYALTY, "SlE"]
	)
	assert_int(model.slots[6].stickers[2].cause_kind).is_equal(ScoreStep.SourceKind.UPGRADE)
	assert_int(model.slots[6].stickers[2].cause_index).is_equal(1)
	# Every sticker is in step order.
	for slot: PlanningSlot in model.slots:
		for index: int in range(1, slot.stickers.size()):
			assert_int(slot.stickers[index].step_index).is_greater(
				slot.stickers[index - 1].step_index
			)


func test_the_reference_row_shows_its_pays_halos_and_stamp() -> void:
	var result: ScoreResult = _reference_result()
	var model: PlanningModel = _reference_model()
	var row: Array[CardDefinition] = _reference_row()
	# Eggs pays its base.
	assert_int(model.slots[0].pay).is_equal(PlanningModel.Pay.PLAIN)
	assert_str(model.slots[0].pay_text).is_empty()
	assert_bool(model.slots[0].struck).is_false()
	assert_int(model.slots[0].rings).is_equal(0)
	# Bread and the Milks after Multipack are boosted: struck base, gold burst with the payout.
	for slot: int in [1, 4, 5, 6]:
		var planning: PlanningSlot = model.slots[slot]
		assert_int(planning.pay).is_equal(PlanningModel.Pay.BOOSTED)
		assert_str(planning.pay_text).is_equal("€%d" % result.payouts[slot])
		assert_bool(planning.struck).is_true()
		assert_int(planning.rings).is_equal(_expected_rings(result.payouts[slot], row[slot].base))
		assert_bool(planning.denied).is_false()
		assert_bool(planning.has_stamp()).is_false()
	# The Spot check denies Milk 3: stamp, grey sprite, €0 tag with the warning glyph.
	var milk: PlanningSlot = model.slots[2]
	assert_int(milk.pay).is_equal(PlanningModel.Pay.DENIED)
	assert_int(milk.glyph).is_equal(PlanningModel.Glyph.WARNING)
	assert_str(milk.pay_text).is_equal("€0")
	assert_bool(milk.struck).is_true()
	assert_bool(milk.denied).is_true()
	assert_str(milk.stamp_amount).is_equal("€0")
	assert_str(milk.stamp_caption).is_equal("SPOT CHECK")
	# Multipack pays nothing after Coupon engine's fizzle; a coupon's title is never struck.
	var multipack: PlanningSlot = model.slots[3]
	assert_int(multipack.pay).is_equal(PlanningModel.Pay.ZERO)
	assert_int(multipack.glyph).is_equal(PlanningModel.Glyph.FIZZLE)
	assert_str(multipack.pay_text).is_equal("€0")
	assert_bool(multipack.struck).is_false()
	assert_bool(multipack.has_stamp()).is_false()


func test_the_reference_row_strips_name_givers_targets_and_gains() -> void:
	var result: ScoreResult = _reference_result()
	var model: PlanningModel = _reference_model()
	assert_int(model.strips.size()).is_equal(2)
	var eggs: RailStripSpec = model.strips[0]
	assert_int(eggs.giver_slot).is_equal(0)
	assert_str(eggs.name).is_equal("EGGS")
	assert_array(Array(eggs.targets)).is_equal([1])
	assert_array(Array(eggs.tokens)).is_equal(["×2"])
	assert_bool(eggs.backward).is_false()
	var multipack: RailStripSpec = model.strips[1]
	assert_int(multipack.giver_slot).is_equal(3)
	assert_str(multipack.name).is_equal("MULTIPACK")
	assert_array(Array(multipack.targets)).is_equal([4, 5, 6])
	assert_array(Array(multipack.tokens)).is_equal(["×3", "×3", "×3"])
	# Each gain is the stamp's step: value_after minus the value before it.
	for index: int in range(3):
		var link: EffectLink = model.graph.incoming(multipack.targets[index])[1]
		assert_int(multipack.gains[index]).is_equal(link.gain)
		assert_int(link.gain).is_greater(0)
	# Disjoint spans: both on the lip.
	assert_int(eggs.lane).is_equal(0)
	assert_int(multipack.lane).is_equal(0)
	assert_array(Array(model.related(3))).is_equal([3, 4, 5, 6])
	assert_array(Array(model.related(5))).is_equal([3, 5])
	assert_array(Array(model.related(2))).is_equal([2])
	# Building the model changes no payout or total.
	var again: ScoreResult = _reference_result()
	assert_int(result.total).is_equal(again.total)
	assert_array(Array(result.payouts)).is_equal(Array(again.payouts))


func test_gain_is_the_step_s_change_and_a_later_denial_cancels_it() -> void:
	var graph: EffectGraph = _reference_model().graph
	var steps: Array[ScoreStep] = _reference_result().steps
	for link: EffectLink in graph.links:
		var step: ScoreStep = steps[link.step_index]
		match link.kind:
			EffectLink.Kind.BONUS, EffectLink.Kind.STAMP, EffectLink.Kind.COPY:
				assert_int(link.gain).is_equal(step.value_after - _value_before(steps, link))
			_:
				assert_int(link.gain).is_equal(0)
	# Milk 3's own bonus is cancelled by the Spot check after it; Bread's stamp is not.
	assert_bool(graph.incoming(2)[0].cancelled).is_true()
	assert_bool(graph.incoming(2)[1].cancelled).is_false()
	assert_bool(graph.incoming(1)[0].cancelled).is_false()
	# Synthetic: base 4, +3 (gain 3), ×2 (gain 7).
	var result: ScoreResult = _result(
		[
			_step(ScoreStep.StepType.BASE, 0, 0, 4, 4),
			_step(ScoreStep.StepType.FLAT, 0, 0, 3, 7, "+3"),
			_step(ScoreStep.StepType.MULTIPLIER, 0, 0, 2, 14, "×2"),
			_step(ScoreStep.StepType.PAYOUT, 0, 0, 14, 14),
		],
		[14]
	)
	var plain: EffectGraph = EffectGraph.build(result)
	assert_int(plain.links[0].gain).is_equal(3)
	assert_int(plain.links[1].gain).is_equal(7)
	assert_bool(plain.links[0].cancelled).is_false()


func test_the_five_pay_states() -> void:
	var tuning: PlanningTuning = load(TUNING)
	var product: CardDefinition = _card(CardDefinition.Kind.PRODUCT, "Bread", 5)
	var coupon: CardDefinition = _card(CardDefinition.Kind.COUPON, "Multipack", 0)
	# PLAIN: pays its base; a coupon paying 0 with nothing on it.
	assert_int(_one(product, [], 5, tuning).pay).is_equal(PlanningModel.Pay.PLAIN)
	assert_int(_one(coupon, [], 0, tuning).pay).is_equal(PlanningModel.Pay.PLAIN)
	assert_bool(_one(coupon, [], 0, tuning).struck).is_false()
	# BOOSTED.
	var boosted: PlanningSlot = _one(product, [_flat(0, 3, 8)], 8, tuning)
	assert_int(boosted.pay).is_equal(PlanningModel.Pay.BOOSTED)
	assert_str(boosted.pay_text).is_equal("€8")
	assert_bool(boosted.struck).is_true()
	# LOWERED: 0 < pay < base.
	var lowered: PlanningSlot = _one(
		product, [_override(0, 0, ScoreStep.SourceKind.CARD, 2)], 2, tuning
	)
	assert_int(lowered.pay).is_equal(PlanningModel.Pay.LOWERED)
	assert_str(lowered.pay_text).is_equal("€2")
	assert_bool(lowered.struck).is_true()
	assert_bool(lowered.denied).is_false()
	assert_str(lowered.stamp_amount).is_equal("€2")
	# DENIED by an inspection (warning glyph) and by the card itself (fizzle glyph).
	var inspected: PlanningSlot = _one(
		product, [_override(0, 0, ScoreStep.SourceKind.INSPECTION, 0)], 0, tuning
	)
	assert_int(inspected.pay).is_equal(PlanningModel.Pay.DENIED)
	assert_int(inspected.glyph).is_equal(PlanningModel.Glyph.WARNING)
	assert_bool(inspected.denied).is_true()
	assert_str(inspected.stamp_caption).is_equal("SPOT CHECK")
	var soup: CardDefinition = _card(CardDefinition.Kind.PRODUCT, "Soup", 6)
	var own: PlanningSlot = _one(soup, [_override(0, 0, ScoreStep.SourceKind.CARD, 0)], 0, tuning)
	assert_int(own.pay).is_equal(PlanningModel.Pay.DENIED)
	assert_int(own.glyph).is_equal(PlanningModel.Glyph.FIZZLE)
	assert_str(own.stamp_amount).is_equal("€0")
	assert_str(own.stamp_caption).is_equal("SOUP")
	# ZERO: a coupon that pays nothing after a fizzle; never struck.
	var zero: PlanningSlot = _one(coupon, [_wasted(0, 0)], 0, tuning)
	assert_int(zero.pay).is_equal(PlanningModel.Pay.ZERO)
	assert_int(zero.glyph).is_equal(PlanningModel.Glyph.FIZZLE)
	assert_str(zero.pay_text).is_equal("€0")
	assert_bool(zero.struck).is_false()
	assert_int(zero.stickers.size()).is_equal(1)
	assert_int(zero.stickers[0].kind).is_equal(StickerSpec.Kind.FIZZLE)
	assert_int(zero.stickers[0].badge).is_equal(GiverBadge.Kind.NONE)


func test_the_halo_rings_follow_the_tuned_ratios() -> void:
	var tuning: PlanningTuning = load(TUNING)
	assert_array(Array(tuning.halo_ratios)).is_equal([5, 20])
	var product: CardDefinition = _card(CardDefinition.Kind.PRODUCT, "Milk", 4)
	for case: Array in [[5, 1], [19, 1], [20, 2], [79, 2], [80, 3], [400, 3]]:
		var planning: PlanningSlot = _one(
			product, [_flat(0, case[0] - 4, case[0])], case[0], tuning
		)
		assert_int(planning.rings).override_failure_message(str(case)).is_equal(case[1])
	# A base of 0 counts as 1.
	var free: CardDefinition = _card(CardDefinition.Kind.PRODUCT, "Sample", 0)
	assert_int(_one(free, [_flat(0, 4, 4)], 4, tuning).rings).is_equal(1)
	assert_int(_one(free, [_flat(0, 5, 5)], 5, tuning).rings).is_equal(2)
	assert_int(_one(free, [_flat(0, 20, 20)], 20, tuning).rings).is_equal(3)
	# Not boosted: no halo.
	assert_int(_one(product, [], 4, tuning).rings).is_equal(0)


func test_repeated_fizzles_show_once() -> void:
	var tuning: PlanningTuning = load(TUNING)
	var eggs: CardDefinition = _card(CardDefinition.Kind.PRODUCT, "Eggs", 1)
	var planning: PlanningSlot = _one(eggs, [_wasted(0, 0), _wasted(0, 0)], 1, tuning)
	assert_int(planning.stickers.size()).is_equal(1)
	# The golden reset row: the second Eggs' reset fizzles the first, with an item badge.
	var model: PlanningModel = _golden_model(
		"res://tests/fixtures/cards_v0_4", "eggs,eggs,bread,bread,bread"
	)
	var fizzles: Array[StickerSpec] = []
	for sticker: StickerSpec in model.slots[0].stickers:
		if sticker.kind == StickerSpec.Kind.FIZZLE:
			fizzles.append(sticker)
	assert_int(fizzles.size()).is_greater(0)
	(
		assert_bool(
			fizzles.any(func(s: StickerSpec) -> bool: return s.badge == GiverBadge.Kind.ITEM)
		)
		. is_true()
	)


func test_copies_make_a_backward_strip_when_the_copy_comes_first() -> void:
	var fixture: String = "res://tests/fixtures/cards_v0_4"
	var model: PlanningModel = _golden_model(fixture, "banana,repeat,banana")
	_assert_sticker(
		model.slots[1].stickers[0],
		[StickerSpec.Kind.COPY, model.slots[1].stickers[0].text, GiverBadge.Kind.ITEM, "Ba"]
	)
	assert_str(model.slots[1].stickers[0].text).starts_with("=€")
	var copy: RailStripSpec = model.strips[0]
	assert_int(copy.giver_slot).is_equal(0)
	assert_array(Array(copy.targets)).is_equal([1])
	assert_bool(copy.backward).is_false()
	# A strip is backward when every target is before its giver; its span still runs from the
	# leftmost target to the giver.
	var spec: RailStripSpec = _spec(4, [2, 1])
	spec.backward = true
	assert_int(spec.lo()).is_equal(1)
	assert_int(spec.hi()).is_equal(4)


func test_key_entries_take_the_first_sticker_of_each_kind_in_order() -> void:
	var model: PlanningModel = _reference_model()
	var entries: Array[StickerSpec] = model.key_entries()
	var captions: Array = []
	for entry: StickerSpec in entries:
		captions.append(PlanningModel.key_caption(entry))
	# Bread's item stamp comes first on the belt, but the key's order is fixed.
	assert_array(captions).is_equal(
		["own rule", "from an item", "from a coupon", "loyalty", "fizzled"]
	)
	assert_bool(entries[0] == model.slots[2].stickers[0]).is_true()
	assert_bool(entries[1] == model.slots[1].stickers[0]).is_true()
	assert_bool(entries[2] == model.slots[4].stickers[1]).is_true()
	assert_bool(entries[3] == model.slots[6].stickers[2]).is_true()
	assert_bool(entries[4] == model.slots[3].stickers[0]).is_true()
	# No stickers, no key.
	assert_array(PlanningModel.new().key_entries()).is_empty()
	assert_str(PlanningModel.key_caption(StickerSpec.folded(3))).is_empty()
	assert_str(StickerSpec.folded(3).text).is_equal("…+3")


func test_lanes_keep_overlapping_strips_apart() -> void:
	# Disjoint spans share lane 0.
	var disjoint: Array[RailStripSpec] = [_spec(0, [1]), _spec(3, [4, 5])]
	PlanningModel.assign_lanes(disjoint)
	assert_array(_lanes(disjoint)).is_equal([0, 0])
	# A touching chain (Eggs→Bread, Bread→Milk) shares a slot: lanes 0 and 1.
	var chain: Array[RailStripSpec] = [_spec(1, [2]), _spec(0, [1])]
	PlanningModel.assign_lanes(chain)
	assert_array(_lanes(chain)).is_equal([1, 0])
	# A third overlapping strip overflows.
	var triple: Array[RailStripSpec] = [_spec(0, [3]), _spec(1, [2]), _spec(2, [4])]
	PlanningModel.assign_lanes(triple)
	assert_array(_lanes(triple)).is_equal([0, 1, -1])
	# A backward strip's span runs from its leftmost target to its giver; after a free lane-0
	# gap, a later strip takes lane 0 again.
	var backward: RailStripSpec = _spec(3, [2, 1])
	backward.backward = true
	var mixed: Array[RailStripSpec] = [backward, _spec(0, [1]), _spec(4, [5])]
	PlanningModel.assign_lanes(mixed)
	assert_array(_lanes(mixed)).is_equal([1, 0, 0])


func test_hot_lanes_give_each_hot_strip_its_own_lane() -> void:
	# Item 2 hovered: its own strip (2→3) takes lane 0; of the strips giving to it (0→2 in calm
	# lane 1, gain 4; 1→2 calm lane 0, gain 9), the larger gain takes lane 1, the other none.
	var own: RailStripSpec = _spec(2, [3])
	var small: RailStripSpec = _spec(0, [2])
	small.gains = PackedInt32Array([4])
	small.lane = 1
	var large: RailStripSpec = _spec(1, [2])
	large.gains = PackedInt32Array([9])
	var specs: Array[RailStripSpec] = [small, large, own]
	var hot: Dictionary[int, int] = {2: -1, 0: 2, 1: 2}
	var lanes: Dictionary[int, int] = PlanningModel.hot_lanes(specs, hot)
	assert_dict(lanes).is_equal({2: 0, 1: 1})
	# With no own strip, the largest gain keeps its calm lane 1 and the next takes lane 0; a
	# third giver to the same item gets none.
	large.lane = 1
	small.lane = 0
	var third: RailStripSpec = _spec(4, [2, 5])
	third.gains = PackedInt32Array([1, 6])
	specs = [small, large, third]
	hot = {0: 2, 1: 2, 4: 2}
	lanes = PlanningModel.hot_lanes(specs, hot)
	assert_dict(lanes).is_equal({1: 1, 0: 0})
	# A cancelled gain (-1) counts as none, so equal gains go by giver slot; strips that aren't
	# hot are left out.
	var cancelled: RailStripSpec = _spec(5, [6])
	cancelled.gains = PackedInt32Array([-1])
	var plain: RailStripSpec = _spec(7, [6])
	plain.gains = PackedInt32Array([0])
	specs = [plain, cancelled, own]
	hot = {5: 6, 7: 6}
	assert_dict(PlanningModel.hot_lanes(specs, hot)).is_equal({5: 0, 7: 1})
	hot = {7: 6}
	assert_dict(PlanningModel.hot_lanes(specs, hot)).is_equal({7: 0})


func test_every_golden_row_builds_a_model_from_its_steps() -> void:
	var tuning: PlanningTuning = load(TUNING)
	var rows: int = 0
	for fixture: String in GoldenRows.GOLDEN_ROWS:
		for ids: String in GoldenRows.GOLDEN_ROWS[fixture]:
			var instances: Array[CardInstance] = GoldenRows._fixture_row(fixture, ids)
			var result: ScoreResult = Scoring.score(instances)
			var row: Array[CardDefinition] = []
			for instance: CardInstance in instances:
				row.append(instance.definition)
			var model: PlanningModel = PlanningModel.build(result, row, [], [], tuning)
			assert_int(model.slots.size()).override_failure_message(ids).is_equal(row.size())
			for slot: int in range(row.size()):
				var planning: PlanningSlot = model.slots[slot]
				if planning.pay != PlanningModel.Pay.PLAIN:
					assert_str(planning.pay_text).override_failure_message(ids).is_equal(
						"€%d" % result.payouts[slot]
					)
				for sticker: StickerSpec in planning.stickers:
					assert_str(sticker.text).override_failure_message(ids).is_not_empty()
					assert_int(sticker.step_index).override_failure_message(ids).is_between(
						0, result.steps.size() - 1
					)
			for strip: RailStripSpec in model.strips:
				assert_int(strip.lane).override_failure_message(ids).is_between(-1, 1)
				assert_int(strip.targets.size()).override_failure_message(ids).is_greater(0)
				assert_int(strip.tokens.size()).is_equal(strip.targets.size())
				assert_int(strip.gains.size()).is_equal(strip.targets.size())
			_assert_lanes_hold(model.strips, ids)
			rows += 1
	assert_int(rows).is_equal(66)
	assert_int(PlanningModel.build(null, [], [], [], tuning).slots.size()).is_equal(0)


func test_the_tuning_defaults_are_neutral_and_the_file_holds_the_values() -> void:
	var neutral: PlanningTuning = PlanningTuning.new()
	assert_int(neutral.halo_ratios.size()).is_equal(0)
	for property: String in [
		"focus_fade_s",
		"unfocus_delay_s",
		"dim_item_alpha",
		"dim_ticket_alpha",
		"dim_strip_alpha",
		"slap_frame_s",
		"halo_step_s",
	]:
		assert_float(neutral.get(property)).override_failure_message(property).is_equal(0.0)
	var tuning: PlanningTuning = load(TUNING)
	assert_float(tuning.focus_fade_s).is_equal_approx(0.12, 0.0001)
	assert_float(tuning.unfocus_delay_s).is_equal_approx(0.08, 0.0001)
	assert_float(tuning.dim_item_alpha).is_equal_approx(0.4, 0.0001)
	assert_float(tuning.dim_ticket_alpha).is_equal_approx(0.45, 0.0001)
	assert_float(tuning.dim_strip_alpha).is_equal_approx(0.3, 0.0001)
	assert_float(tuning.slap_frame_s).is_equal_approx(0.04, 0.0001)
	assert_float(tuning.halo_step_s).is_equal_approx(0.08, 0.0001)


func test_badge_initials() -> void:
	assert_str(GiverBadge.initials_for(GiverBadge.Kind.ITEM, "Eggs")).is_equal("Eg")
	assert_str(GiverBadge.initials_for(GiverBadge.Kind.ITEM, "Milk")).is_equal("Mi")
	assert_str(GiverBadge.initials_for(GiverBadge.Kind.COUPON, "2 for 1")).is_equal("2f")
	assert_str(GiverBadge.initials_for(GiverBadge.Kind.LOYALTY, "Coupon engine")).is_equal(
		LoyaltyCard.initials("Coupon engine")
	)
	assert_int(GiverBadge.initials_for(GiverBadge.Kind.LOYALTY, "A b c d e").length()).is_equal(3)
	assert_str(GiverBadge.initials_for(GiverBadge.Kind.INSPECTION, "Spot check")).is_empty()
	assert_str(GiverBadge.initials_for(GiverBadge.Kind.NONE, "Eggs")).is_empty()


func test_the_halo_and_grey_materials() -> void:
	for rings: int in [1, 2, 3]:
		var halo: ShaderMaterial = ArtStyle.halo_material(rings)
		assert_object(halo.shader).is_same(ArtStyle.HALO_SHADER)
		assert_int(halo.get_shader_parameter(&"rings")).is_equal(rings)
		assert_object(ArtStyle.halo_material(rings)).is_same(halo)
		var bands: PackedColorArray = ArtStyle.halo_bands(rings)
		assert_int(bands.size()).is_equal(4)
		assert_that(bands[rings]).is_equal(Palette.INK)
	assert_array(Array(ArtStyle.halo_bands(1)).slice(0, 1)).is_equal([Palette.MUSTARD_LIGHT])
	assert_array(Array(ArtStyle.halo_bands(2)).slice(0, 2)).is_equal(
		[Palette.MUSTARD_PALE, Palette.MUSTARD]
	)
	assert_array(Array(ArtStyle.halo_bands(3)).slice(0, 3)).is_equal(
		[Palette.PAPER, Palette.MUSTARD_LIGHT, Palette.MUSTARD]
	)
	assert_object(ArtStyle.halo_material(9)).is_same(ArtStyle.halo_material(3))
	var denied: ShaderMaterial = ArtStyle.grey_material(ArtStyle.Grey.DENIED)
	var drained: ShaderMaterial = ArtStyle.grey_material(ArtStyle.Grey.DRAINED)
	assert_object(denied.shader).is_same(ArtStyle.GREY_SHADER)
	assert_float(denied.get_shader_parameter(&"brightness")).is_equal_approx(0.78, 0.0001)
	assert_float(denied.get_shader_parameter(&"contrast")).is_equal_approx(0.9, 0.0001)
	assert_float(drained.get_shader_parameter(&"brightness")).is_equal_approx(0.62, 0.0001)
	assert_float(drained.get_shader_parameter(&"contrast")).is_equal_approx(0.55, 0.0001)
	# set_sharp keeps a look material instead of resetting it.
	var sprite: TextureRect = auto_free(TextureRect.new())
	ArtStyle.set_look(sprite, denied)
	ArtStyle.set_sharp(sprite, true)
	assert_object(sprite.material).is_same(denied)
	ArtStyle.set_sharp(sprite, false)
	assert_object(sprite.material).is_same(denied)
	ArtStyle.set_look(sprite, null)
	assert_object(sprite.material).is_same(ArtStyle.pixel_material())
	ArtStyle.set_sharp(sprite, false)
	assert_object(sprite.material).is_null()


static func _reference_row() -> Array[CardDefinition]:
	var row: Array[CardDefinition] = []
	for instance: CardInstance in PlanTest._row(PlanTest.FULL_ROW, PlanTest.CARDS):
		row.append(instance.definition)
	return row


static func _upgrades() -> Array[UpgradeDefinition]:
	var upgrades: Array[UpgradeDefinition] = []
	for path: String in UPGRADES:
		upgrades.append(load(path) as UpgradeDefinition)
	return upgrades


static func _inspections() -> Array[InspectionDefinition]:
	var inspections: Array[InspectionDefinition] = [load(INSPECTION) as InspectionDefinition]
	return inspections


static func _reference_result() -> ScoreResult:
	return Scoring.score(
		PlanTest._row(PlanTest.FULL_ROW, PlanTest.CARDS), _upgrades(), _inspections()
	)


static func _reference_model() -> PlanningModel:
	return PlanningModel.build(
		_reference_result(), _reference_row(), _upgrades(), _inspections(), load(TUNING)
	)


static func _golden_model(fixture: String, ids: String) -> PlanningModel:
	var instances: Array[CardInstance] = GoldenRows._fixture_row(fixture, ids)
	var row: Array[CardDefinition] = []
	for instance: CardInstance in instances:
		row.append(instance.definition)
	return PlanningModel.build(Scoring.score(instances), row, [], [], load(TUNING))


static func _expected_rings(payout: int, base: int) -> int:
	var unit: int = maxi(base, 1)
	return 1 + (1 if payout >= unit * 5 else 0) + (1 if payout >= unit * 20 else 0)


static func _value_before(steps: Array[ScoreStep], link: EffectLink) -> int:
	var value: int = 0
	for index: int in range(link.step_index):
		var step: ScoreStep = steps[index]
		if step.slot == link.target_slot and EffectGraph.VALUE_STEPS.has(step.step_type):
			value = step.value_after
	return value


## A one-slot model of `card` with a BASE step, then `steps`, then its PAYOUT of `payout`.
static func _one(
	card: CardDefinition, steps: Array[ScoreStep], payout: int, tuning: PlanningTuning
) -> PlanningSlot:
	var all: Array[ScoreStep] = [_step(ScoreStep.StepType.BASE, 0, 0, card.base, card.base)]
	all.append_array(steps)
	all.append(_step(ScoreStep.StepType.PAYOUT, 0, 0, payout, payout))
	var row: Array[CardDefinition] = [card]
	var inspections: Array[InspectionDefinition] = _inspections()
	return PlanningModel.build(_result(all, [payout]), row, [], inspections, tuning).slots[0]


static func _result(steps: Array[ScoreStep], payouts: Array) -> ScoreResult:
	var result: ScoreResult = ScoreResult.new()
	result.steps = steps
	result.payouts = PackedInt32Array(payouts)
	for payout: int in payouts:
		result.total += payout
	return result


static func _step(
	type: ScoreStep.StepType,
	slot: int,
	source: int,
	value: int,
	value_after: int,
	text: String = ""
) -> ScoreStep:
	var step: ScoreStep = ScoreStep.new()
	step.step_type = type
	step.slot = slot
	step.source_slot = source
	step.value = value
	step.value_after = value_after
	step.text = text
	return step


static func _flat(slot: int, amount: int, value_after: int) -> ScoreStep:
	return _step(ScoreStep.StepType.FLAT, slot, slot, amount, value_after, "+%d" % amount)


static func _override(slot: int, source: int, kind: ScoreStep.SourceKind, payout: int) -> ScoreStep:
	var step: ScoreStep = _step(ScoreStep.StepType.PAYOUT_OVERRIDE, slot, source, payout, payout)
	step.source_kind = kind
	return step


static func _wasted(slot: int, source: int) -> ScoreStep:
	var step: ScoreStep = _step(ScoreStep.StepType.WASTED, slot, source, 0, 0, "Own rule")
	step.reason = "nothing to do"
	return step


static func _card(kind: CardDefinition.Kind, display_name: String, base: int) -> CardDefinition:
	var card: CardDefinition = CardDefinition.new()
	card.kind = kind
	card.display_name = display_name
	card.base = base
	return card


static func _spec(giver: int, targets: Array) -> RailStripSpec:
	var spec: RailStripSpec = RailStripSpec.new()
	spec.giver_slot = giver
	spec.targets = PackedInt32Array(targets)
	return spec


## On a real row the lane rule holds: no two strips in one lane share a slot, a lane-1 strip
## shares one with a lane-0 strip, and an overflowing one with a strip in each lane.
func _assert_lanes_hold(strips: Array[RailStripSpec], ids: String) -> void:
	for strip: RailStripSpec in strips:
		var blocked: Array[bool] = [false, false]
		for other: RailStripSpec in strips:
			if other == strip or not strip.conflicts(other) or other.lane < 0:
				continue
			assert_int(other.lane).override_failure_message(ids).is_not_equal(strip.lane)
			blocked[other.lane] = true
		if strip.lane >= 1:
			assert_bool(blocked[0]).override_failure_message(ids).is_true()
		if strip.lane < 0:
			assert_array(blocked).override_failure_message(ids).is_equal([true, true])


static func _lanes(specs: Array[RailStripSpec]) -> Array:
	var lanes: Array = []
	for spec: RailStripSpec in specs:
		lanes.append(spec.lane)
	return lanes


func _assert_stickers(slot: PlanningSlot, expected: Array) -> void:
	assert_int(slot.stickers.size()).is_equal(expected.size())
	for index: int in range(mini(expected.size(), slot.stickers.size())):
		_assert_sticker(slot.stickers[index], expected[index])


func _assert_sticker(sticker: StickerSpec, expected: Array) -> void:
	assert_int(sticker.kind).is_equal(expected[0])
	assert_str(sticker.text).is_equal(expected[1])
	assert_int(sticker.badge).is_equal(expected[2])
	assert_str(sticker.badge_text).is_equal(expected[3])
