class_name FocusWatch
extends Node
## Whether the player is at the game, for planning time (plan section 8: planning time pauses
## while the player is away). On the web that means the page is visible (another tab or a
## minimised window hides it): canvas focus also drops on any click outside the game, e.g. on
## the itch.io page, while the player can still see the hand and think. On desktop it is window
## focus. Starts watching once it is in the tree.

signal player_left
signal player_returned

## Web only: keeps the page-visibility callback alive.
var _visibility_callback: JavaScriptObject


func _ready() -> void:
	if OS.has_feature("web"):
		var document: JavaScriptObject = JavaScriptBridge.get_interface("document")
		_visibility_callback = JavaScriptBridge.create_callback(_on_page_visibility_changed)
		document.call("addEventListener", "visibilitychange", _visibility_callback)
	else:
		get_window().focus_exited.connect(func() -> void: player_left.emit())
		get_window().focus_entered.connect(func() -> void: player_returned.emit())


func is_player_present() -> bool:
	if OS.has_feature("web"):
		return not bool(JavaScriptBridge.eval("document.hidden", true))
	return get_window().has_focus()


func _on_page_visibility_changed(_arguments: Array) -> void:
	if is_player_present():
		player_returned.emit()
	else:
		player_left.emit()
