class_name HandbookCollection
extends Control
## The COLLECTION opened from the staff handbook (2026-11-19, the user: "a nice touch could be
## adding figurine book link (rename to collection) in handbook"): the TOY MACHINES' card book
## (FigurineBook) on its own 1280x720 stage, centred over teal-black bands as the TOY MACHINES
## show it, over the handbook. BACK, Esc or Backspace (the book's own keys) close it and the
## handbook shows again where it was.
##
## It only reads the profile: the cards drawn since the TOY MACHINES' book was last opened wear
## the NEW tag here too, but stay new (only the TOY MACHINES mark them seen and save), so the
## title's NEW tag on the book button still means something. Every key goes to the book while it
## is open (before the screen behind sees it), but Alt+key (Alt+Enter's full screen).

signal closed

var _book: FigurineBook


func _init() -> void:
	name = "Collection"
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false
	var bands: ColorRect = ColorRect.new()
	bands.color = Palette.TEAL_BLACK
	bands.set_anchors_preset(Control.PRESET_FULL_RECT)
	bands.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bands)
	var stage: Control = Control.new()
	stage.name = "Stage"
	stage.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stage.clip_contents = true
	stage.set_anchors_preset(Control.PRESET_CENTER)
	stage.offset_left = -FigurineBook.STAGE.x / 2.0
	stage.offset_top = -FigurineBook.STAGE.y / 2.0
	stage.offset_right = FigurineBook.STAGE.x / 2.0
	stage.offset_bottom = FigurineBook.STAGE.y / 2.0
	add_child(stage)
	_book = FigurineBook.new()
	_book.back_pressed.connect(close)
	stage.add_child(_book)


## Opens the book on `profile`'s collection of `balance` (still: no drops, pages at once).
func open(profile: ProfileState, balance: BalanceDefinition, still: bool = false) -> void:
	_book.show_collection(
		balance,
		profile.unlocked_items,
		profile.coupon_uses,
		profile.new_figurines,
		still,
		profile.perk_levels
	)
	_book.visible = true
	visible = true


func close() -> void:
	if not visible:
		return
	visible = false
	_book.visible = false
	closed.emit()


func is_open() -> bool:
	return visible


func book() -> FigurineBook:
	return _book


func _input(event: InputEvent) -> void:
	var key: InputEventKey = event as InputEventKey
	if not visible or key == null or key.alt_pressed:
		return
	_book.handle_key(key)
	get_viewport().set_input_as_handled()
