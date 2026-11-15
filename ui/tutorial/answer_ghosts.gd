class_name AnswerGhosts
extends Control
## The guided shift's answer (play test 1, 2026-11-15): from the TutorialScript.ANSWER_AFTER-th
## missed rehearsal on, a faded sprite of each answer item stands on its belt slot, where the
## player drags the real one. A slot already holding its answer item shows no ghost. It never
## takes a click.

## The ghosts' see-through.
const ALPHA := 0.45

var _cards: Array[CardDefinition] = []
var _ghosts: Array[ItemView] = []


func _init() -> void:
	name = "AnswerGhosts"
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false


## Shows the answer `cards` (slot order) with `balance`'s aisles.
func show_answer(cards: Array[CardDefinition], balance: BalanceDefinition) -> void:
	for ghost: ItemView in _ghosts:
		ghost.queue_free()
	_ghosts.clear()
	_cards = cards.duplicate()
	for card: CardDefinition in _cards:
		var aisle: AisleDefinition = balance.aisle_of(card) if balance != null else null
		var ghost: ItemView = ItemView.new(CardInstance.new(card, 0), aisle, ItemView.Form.GHOST)
		ghost.modulate = Color(1, 1, 1, ALPHA)
		ghost.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_ignore_mouse(ghost)
		add_child(ghost)
		_ghosts.append(ghost)
	visible = true


## Stands each ghost where a belt item stands in its slot's cell (`slot_cell`: slot index → the
## cell Control, or null when the slot isn't shown), hiding the ones whose slot already holds
## their item (`row`).
func follow(slot_cell: Callable, row: Array[CardInstance]) -> void:
	var own: Transform2D = get_global_transform().affine_inverse()
	for slot: int in _ghosts.size():
		var ghost: ItemView = _ghosts[slot]
		var cell: Control = slot_cell.call(slot)
		var done: bool = slot < row.size() and row[slot].definition == _cards[slot]
		ghost.visible = cell != null and cell.is_visible_in_tree() and not done
		if not ghost.visible:
			continue
		var to_cell: Transform2D = own * cell.get_global_transform()
		ghost.position = (to_cell * ItemView.BELT_SPRITE).floor()
		ghost.scale = to_cell.get_scale()


## Whether every ghost is placed (or none shows).
func all_placed() -> bool:
	for ghost: ItemView in _ghosts:
		if ghost.visible:
			return false
	return true


static func _ignore_mouse(node: Node) -> void:
	for child: Node in node.get_children():
		if child is Control:
			(child as Control).mouse_filter = Control.MOUSE_FILTER_IGNORE
		_ignore_mouse(child)
