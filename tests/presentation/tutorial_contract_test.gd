extends GdUnitTestSuite
## The tutorial's frozen contract (tutorial plan section 1.2): the hook events and their args
## (TutorialEvents), the gate actions (TutorialActions; a null gate allows everything) and the
## anchor ids (TutorialAnchors).


func test_every_event_has_its_args_and_each_arg_a_type() -> void:
	assert_int(TutorialEvents.ARGS.size()).is_equal(38)
	for event: StringName in TutorialEvents.ARGS:
		assert_bool(TutorialEvents.is_event(event)).is_true()
		for key: StringName in TutorialEvents.ARGS[event]:
			assert_bool(TutorialEvents.ARG_TYPES.has(key)).override_failure_message(key).is_true()
	assert_bool(TutorialEvents.is_event(&"no_such_event")).is_false()


func test_args_are_checked_by_key_count_and_type() -> void:
	var placed: Dictionary = {
		TutorialEvents.ARG_CARD: &"bread",
		TutorialEvents.ARG_INSTANCE: 5,
		TutorialEvents.ARG_SLOT: 0,
	}
	assert_bool(TutorialEvents.args_valid(TutorialEvents.CARD_PLACED, placed)).is_true()
	assert_bool(TutorialEvents.args_valid(TutorialEvents.CHECKOUT_STARTED, {})).is_true()
	assert_bool(TutorialEvents.args_valid(TutorialEvents.CARD_PICKED, placed)).is_false()
	var wrong_type: Dictionary = placed.duplicate()
	wrong_type[TutorialEvents.ARG_CARD] = "bread"
	assert_bool(TutorialEvents.args_valid(TutorialEvents.CARD_PLACED, wrong_type)).is_false()
	var extra: Dictionary = placed.duplicate()
	extra[TutorialEvents.ARG_INDEX] = 1
	assert_bool(TutorialEvents.args_valid(TutorialEvents.CARD_PLACED, extra)).is_false()
	assert_bool(TutorialEvents.args_valid(&"no_such_event", {})).is_false()


func test_a_null_gate_allows_everything_and_a_gate_is_asked() -> void:
	assert_bool(TutorialActions.allows(Callable(), TutorialActions.CHECKOUT)).is_true()
	var asked: Array = []
	var gate: Callable = func(action: StringName, args: Dictionary) -> bool:
		asked.append([action, args])
		return action != TutorialActions.REDRAW
	assert_bool(TutorialActions.allows(gate, TutorialActions.REDRAW)).is_false()
	var hit: Dictionary = {TutorialActions.ARG_ID: TutorialAnchors.booster(0)}
	assert_bool(TutorialActions.allows(gate, TutorialActions.HIT, hit)).is_true()
	assert_array(asked).is_equal([[TutorialActions.REDRAW, {}], [TutorialActions.HIT, hit]])
	for action: StringName in TutorialActions.ARGS:
		assert_bool(TutorialActions.is_action(action)).is_true()
		for key: StringName in TutorialActions.ARGS[action]:
			var known: bool = TutorialEvents.ARG_TYPES.has(key) or key == TutorialActions.ARG_ID
			assert_bool(known).override_failure_message(key).is_true()


func test_anchor_ids_fixed_and_indexed() -> void:
	for id: StringName in TutorialAnchors.FIXED:
		assert_bool(TutorialAnchors.is_known(id)).is_true()
	assert_str(String(TutorialAnchors.slot(0))).is_equal("slot0")
	assert_str(String(TutorialAnchors.hand(7))).is_equal("hand7")
	assert_str(String(TutorialAnchors.basket(3))).is_equal("basket3")
	assert_str(String(TutorialAnchors.card(1, 2))).is_equal("card1_2")
	assert_str(String(TutorialAnchors.swap_card(0, 1))).is_equal("swap_card0_1")
	assert_str(String(TutorialAnchors.pack(2))).is_equal("pack2")
	for id: StringName in [&"slot6", &"hand0", &"booster1", &"hit0", &"pack2", &"card0_2"]:
		assert_bool(TutorialAnchors.is_known(id)).override_failure_message(id).is_true()
	for id: StringName in [&"slot", &"slot-1", &"slot01", &"slotx", &"card1", &"nowhere", &"G12"]:
		assert_bool(TutorialAnchors.is_known(id)).override_failure_message(id).is_false()
	assert_int(TutorialAnchors.index_of(&"slot3", TutorialAnchors.SLOT)).is_equal(3)
	assert_int(TutorialAnchors.index_of(&"hand3", TutorialAnchors.SLOT)).is_equal(-1)
	assert_int(TutorialAnchors.index_of(&"machine_keys", TutorialAnchors.MACHINE_KEY)).is_equal(-1)
	# No fixed id is also an indexed one.
	for id: StringName in TutorialAnchors.FIXED:
		for prefix: String in TutorialAnchors.PREFIXES:
			assert_int(TutorialAnchors.index_of(id, prefix)).override_failure_message(id).is_equal(
				-1
			)
