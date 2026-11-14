class_name StartTip
extends TipTarget
## The tooltip of a START chip (DeckCell.add_start_mark, the cart and run info polish,
## 2026-11-12): it covers the chip, draws nothing, and names where the item came from ("Starting
## cart · Breakfast run pack"). Its tip opens below the chip, so on the first shelf it never hides
## the Cart's tag line. It takes no clicks: the item under it keeps its hover and clicks.

const HEAD := "Starting cart"
const REGULAR := "a regular"
const PACK := "%s pack"
const DEALT := "from the %s booster"
const STAPLES := "from the staples shelf"
const PIN := "%s pin"


## A tip saying `source` (HEAD alone when empty), over its parent's rect.
func _init(source: String) -> void:
	super()
	name = "StartTip"
	tip_text = HEAD if source.is_empty() else "%s · %s" % [HEAD, source]
	set_anchors_preset(Control.PRESET_FULL_RECT)
	tip_below = true
	tip_anchor = self


## What the tip says for a starting-cart line `line` (StartCartLine).
static func source_of(line: StartCartLine) -> String:
	match line.source:
		StartCartLine.Source.REGULAR:
			return REGULAR
		StartCartLine.Source.PACK:
			return PACK % line.origin_name
		StartCartLine.Source.DEALT:
			return DEALT % line.origin_name if not line.origin_name.is_empty() else STAPLES
		StartCartLine.Source.PIN:
			return PIN % line.origin_name
	return ""
