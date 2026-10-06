class_name ConnectorBridgeRule
extends Rule
## Context pass: the product immediately before a run of connectors and the product
## immediately after it count as adjacent (Bundle). Consecutive connectors act as one bridge.
## When either neighbour isn't a product (an end of the row, or a coupon that isn't a
## connector), nothing is bridged.


func modify_context(state: ScoreState, slot: int) -> void:
	# Only the first connector of a run acts, so a run makes one bridge.
	if not state.is_connector(slot) or state.is_connector(slot - 1):
		return
	var run_end: int = slot
	while state.is_connector(run_end + 1):
		run_end += 1
	var left: int = slot - 1
	var right: int = run_end + 1
	if state.is_product(left) and state.is_product(right):
		state.link_products(left, right, slot, text_for(state.definition(slot)))
		return
	# Nothing to bridge: every connector of the run fizzles.
	for connector: int in range(slot, run_end + 1):
		state.add_waste(
			connector, text_for(state.definition(connector)), "no product on both sides"
		)
