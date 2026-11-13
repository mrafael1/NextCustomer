class_name CaptureDeckFilter
extends RefCounted
## The screen capture's deck view family filter (the cart and run info polish, play feedback
## 2026-11-12; ScreenCapture.deck): its options `pin=<n>` (the page's family icon n, from 0, is
## clicked: its filter pinned) and `filter=<n>` (the pointer rests on icon n: its family
## previewed, over a pin), applied in that order, then the rebuilt grid laid out. The run-start
## time card is dropped first, so it covers none of the view.


## Drops `screen`'s time card, applies `options`' pin= and filter= to `view`'s shown page and
## waits for the grid's layout.
static func apply(screen: ShiftScreen, view: DeckView, options: PackedStringArray) -> void:
	screen._week.skip()
	for option: String in options:
		if option.begins_with("pin=") and not _family(view, option).is_empty():
			view.toggle_pin(_family(view, option))
	for option: String in options:
		if option.begins_with("filter=") and not _family(view, option).is_empty():
			view.preview_family(_family(view, option))
	for frame: int in range(2):
		await view.get_tree().process_frame


## The family of the icon an `<name>=<n>` option names, or "" (with a printed note) when the page
## has no icon n or its family can't filter the page.
static func _family(view: DeckView, option: String) -> String:
	var icons: Array[FamilyCount] = view.family_icons()
	var index: int = option.get_slice("=", 1).to_int()
	if index < 0 or index >= icons.size():
		print(
			(
				"capture: %s ignored: the page has %d family icons (0 to %d)"
				% [option, icons.size(), icons.size() - 1]
			)
		)
		return ""
	var family: String = icons[index].family
	if not view.can_filter(family):
		print("capture: %s ignored: %s can't filter this page" % [option, family])
		return ""
	return family
