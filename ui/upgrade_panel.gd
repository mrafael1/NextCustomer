class_name UpgradePanel
extends PanelContainer
## The upgrade choice on upgrade shifts (plan section 3.8, full build plan 5.2), after the
## reward: the exit kiosk drops 1 to 3 prize tickets and the player must pick one. There is no
## skip. It only shows the offer and reports the pick; RunState applies it.

signal picked(upgrade: UpgradeDefinition)

const TITLE := "EXIT KIOSK: pick your prize"

## The offer's presentation timeline (presented_ms, armed_ms, decide_ms, presentation_skipped;
## plan section 8), started by show_offer and kept while the panel is hidden and shown again.
## A skippable presentation (phase 3) sets its presentation_skipped.
var timeline: OfferTimeline = OfferTimeline.new()
var _headline: Label
var _tickets: HBoxContainer
## Like the reward panel: tickets only react once the mouse has been released after the panel
## appeared, so a click meant for something else never picks a ticket the player didn't read.
var _armed: bool = false
var _shown_ms: int = 0


func _init() -> void:
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = Palette.PAPER
	style.border_color = Palette.INK
	style.set_border_width_all(4)
	style.set_corner_radius_all(12)
	style.set_content_margin_all(24)
	add_theme_stylebox_override("panel", style)
	var column: VBoxContainer = VBoxContainer.new()
	column.add_theme_constant_override("separation", 14)
	add_child(column)
	_headline = UiKit.label(TITLE, 28, Palette.INK)
	_headline.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(_headline)
	var note: Label = UiKit.label(
		"Pick one ticket. It goes on your loyalty card for the rest of the run.",
		16,
		Palette.MUTED_INK
	)
	note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(note)
	_tickets = HBoxContainer.new()
	_tickets.alignment = BoxContainer.ALIGNMENT_CENTER
	_tickets.add_theme_constant_override("separation", 22)
	column.add_child(_tickets)
	visible = false
	# The tickets' wrapped lines only get their real height once the tickets have a width, a
	# frame after they are added. Until then the panel's minimum height is far too big (the
	# panel once stayed 3,000 px tall, tickets off screen), so it refits whenever that changes.
	minimum_size_changed.connect(_fit_to_content)


func _process(_delta: float) -> void:
	if not visible or _armed:
		return
	var waited: bool = Time.get_ticks_msec() - _shown_ms >= 350
	if waited and not Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		_set_armed(true)
		timeline.mark_armed(Time.get_ticks_msec())


func show_offer(offer: Array[UpgradeDefinition]) -> void:
	for child: Node in _tickets.get_children():
		_tickets.remove_child(child)
		child.queue_free()
	for upgrade: UpgradeDefinition in offer:
		var ticket: UpgradeTicket = UpgradeTicket.new(upgrade)
		ticket.clicked.connect(_on_ticket_clicked)
		_tickets.add_child(ticket)
	_shown_ms = Time.get_ticks_msec()
	timeline = OfferTimeline.new(_shown_ms)
	_set_armed(false)
	timeline.presented_when(UiKit.pop_in(self))


## Shown but not yet accepting clicks (the top bar's Deck waits for it too).
func is_arming() -> bool:
	return visible and not _armed


## The tickets on show, in offer order.
func tickets() -> Array[UpgradeTicket]:
	var shown: Array[UpgradeTicket] = []
	for child: Node in _tickets.get_children():
		if child is UpgradeTicket and not child.is_queued_for_deletion():
			shown.append(child as UpgradeTicket)
	return shown


## Shrinks the panel to its content and centres it again (a Control never shrinks by itself).
func _fit_to_content() -> void:
	if not visible:
		return
	reset_size()
	set_anchors_and_offsets_preset(Control.PRESET_CENTER, Control.PRESET_MODE_MINSIZE)
	pivot_offset = size / 2.0


func _set_armed(armed: bool) -> void:
	_armed = armed
	for ticket: UpgradeTicket in tickets():
		ticket.armed = armed
		ticket.modulate = Color.WHITE if armed else Color(1, 1, 1, 0.8)


func _on_ticket_clicked(ticket: UpgradeTicket) -> void:
	if _armed:
		picked.emit(ticket.upgrade)
