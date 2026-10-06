class_name NextTagBonusEffect
extends ScoreEffect
## A flat bonus given once, to the next product with a tag (Coffee: +3 to the next Breakfast
## product, anywhere later in the row). If no such product comes, the bonus is lost.

var tag: String = ""
var bonus: int = 0
var _used: bool = false


func _init(
	effect_source_slot: int, effect_text: String, bonus_tag: String, bonus_amount: int
) -> void:
	super(effect_source_slot, effect_text)
	tag = bonus_tag
	bonus = bonus_amount


func flat_bonus(state: ScoreState, slot: int) -> int:
	if _used or not state.has_tag(slot, tag):
		return 0
	_used = true
	return bonus


func waste_reason() -> String:
	return "" if _used else "no %s product after it" % tag


func is_spent() -> bool:
	return _used
