extends Control
## Placeholder entry scene, used to check that the web export runs.


func _ready() -> void:
	var label: Label = $Label
	label.text = "Next Customer — %s" % ProjectSettings.get_setting("next_customer/build_label")
