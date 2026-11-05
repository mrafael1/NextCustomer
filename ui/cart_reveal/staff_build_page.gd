class_name StaffBuildPage
extends Control
## YOUR BUILD as v4 B's staff room (full build plan 7.2): lockers, the bench's three crates (each
## with its strategy line and an example row), NEW PACKS under the sign, the order sheet (the
## cart overview, the picked pack's lines highlighted) and the time clock.

signal pick_requested(index: int)
signal preview_requested(index: int)
signal pins_requested
signal open_requested
signal new_packs_requested

const PICK_TITLE := "PICK A STARTER PACK"
const PICKED_TITLE := "YOUR STARTER PACK"

var crates: Array[PackCrate] = []
var order: OrderSheet
var open_key: Button
## The time clock key's second line ("Clock in · <pack> · n cards", or how to pick).
var open_line: Label
## The pins card's parts: the faces on the badge, the note's rule text and free-slot line.
var pin_faces: Array[PinFace] = []
var pin_rule: Label
var pin_note: Label
## The NEW PACKS key under the sign (disabled with its reason as the tip once used, or when no
## other packs fit).
var new_packs_key: Button
var _room: TextureRect
var _recap: Control
var _clock: Control
var _pins: Control
var _notice: Control
var _answer: Label
## The sign's title: PICK A STARTER PACK, then YOUR STARTER PACK once a crate is picked.
var _notice_title: Label
var _dial: Control
var _time_card: Control
var _decor: Control


func _init() -> void:
	size = ShiftStage.SIZE
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_room = UiKit.sprite(StaffRoomArt.texture())
	_room.size = ShiftStage.SIZE
	add_child(_room)
	_decor = StaffRoomDetails.new()
	add_child(_decor)
	for index: int in 4:
		var locker: Label = StartBoardKit.number(
			self, str(12 + index), Rect2(416 + index * 120, 170, 44, 22), Palette.INK, 20
		)
		locker.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_notice = StartBoardKit.panel(self, Rect2(402, 198, 428, 76), Palette.PAPER)
	_notice_title = StartBoardKit.words(_notice, PICK_TITLE, Rect2(12, 8, 404, 32), Palette.INK, 3)
	_notice_title.name = "SignTitle"
	StartBoardKit.centre(_notice_title, Rect2(12, 8, 404, 32))
	_answer = StartBoardKit.body(_notice, "", Rect2(12, 46, 404, 24))
	_answer.name = "Answer"
	_answer.add_theme_font_override("font", ArtStyle.bold_font(700))
	new_packs_key = StartBoardKit.key(
		self, "NEW PACKS", Rect2(676, 280, 154, 36), func() -> void: new_packs_requested.emit()
	)
	new_packs_key.name = "NewPacks"
	_pins = Control.new()
	add_child(_pins)
	_recap = Control.new()
	add_child(_recap)
	order = OrderSheet.new()
	order.position = Vector2(876, 70)
	_recap.add_child(order)
	_clock = StartBoardKit.panel(self, Rect2(890, 584, 374, 128), Palette.STEEL_PALE)
	StartBoardKit.panel(_clock, Rect2(4, 4, 366, 30), Palette.BRASS)
	StartBoardKit.words(_clock, "TIME CLOCK", Rect2(18, 4, 210, 28), Palette.MUSTARD_PALE)
	_dial = StaffRoomDetails.new(true)
	_dial.position = Vector2(320, 4)
	_dial.size = Vector2(30, 30)
	_dial.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_clock.add_child(_dial)
	StartBoardKit.panel(_clock, Rect2(14, 46, 38, 70), Palette.CHARCOAL)
	_time_card = Control.new()
	_time_card.position = Vector2(20, 54)
	_time_card.size = Vector2(26, 60)
	_time_card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_clock.add_child(_time_card)
	StartBoardKit.panel(_time_card, Rect2(0, 0, 26, 60), Palette.CREAM)
	StartBoardKit.words(_time_card, "IN", Rect2(0, -6, 26, 24), Palette.TEAL)
	for index: int in 4:
		StartBoardKit.panel(
			_time_card, Rect2(4, 24 + index * 8, 18, 2), Palette.CREAM_SHADE, Palette.CREAM_SHADE
		)
	open_key = StartBoardKit.key(
		_clock, "OPEN STORE ›", Rect2(72, 44, 288, 74), func() -> void: open_requested.emit(), true
	)
	open_line = StartBoardKit.subtitle(open_key, "")
	open_line.name = "OpenLine"
	var hints: Control = StartBoardKit.hints(
		self,
		[
			"ESC",
			"back",
			"1|2|3",
			"pick a crate",
			"N",
			"new packs",
			"P",
			"pins",
			"ENTER",
			"clock in"
		],
		Vector2(262, 684),
		Palette.CREAM
	)
	# Centred under the bench (it runs 16 to 864), clear of the ‹ STORE plaque.
	hints.position.x = maxf(262.0, 2.0 * floorf((440.0 - hints.size.x / 2.0) / 2.0))


func show_build(
	run: StartBuildView, selected: int, preview: int, reduced: bool, packs_reason: StringName = &""
) -> void:
	_ensure_crates(run.start_offer, reduced)
	_show_crates(selected, preview)
	var shown: int = preview if preview >= 0 else selected
	var pack: StarterPackDefinition = run.start_offer.packs[shown] if shown >= 0 else null
	var previewing: bool = preview >= 0 and preview != selected
	order.show_cart(run, pack, previewing)
	var answer: Label = _answer
	answer.text = (
		"Pick a crate to open the store"
		if selected < 0
		else "%s rides in your cart" % run.start_offer.packs[selected].display_name.to_upper()
	)
	answer.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_notice_title.text = (PICK_TITLE if selected < 0 else PICKED_TITLE).replace(" ", "  ")
	StartBoardKit.centre(_notice_title, Rect2(12, 8, 404, 32))
	answer.add_theme_color_override(
		"font_color", Palette.TOMATO_DARK if selected < 0 else Palette.GREEN_DARK
	)
	open_key.disabled = selected < 0
	var key_label: Label = StartBoardKit.key_caption(open_key)
	key_label.text = "PICK A PACK FIRST" if selected < 0 else "OPEN STORE ›"
	UiKit.use_pixel_text(key_label, 2 if selected < 0 else 4)
	var room: Rect2 = Rect2(8, 4, 272, open_key.size.y - 30)
	UiKit.place_pixel_label(key_label, room, true)
	StartBoardKit.centre(key_label, room)
	key_label.add_theme_color_override(
		"font_color", Palette.INK_LIGHT if selected < 0 else Palette.PAPER
	)
	var picked: StarterPackDefinition = run.start_offer.packs[selected] if selected >= 0 else null
	open_line.text = (
		"Pick a crate, or press 1, 2 or 3"
		if picked == null
		else (
			"Clock in · %s · %d cards"
			% [
				picked.display_name,
				(
					StartSetupRules
					. cart_cards(
						StartSetupRules.cart_lines(
							run.starter, run.start_offer, run.balance, run.pins, picked
						)
					)
					. size()
				)
			]
		)
	)
	open_line.add_theme_color_override(
		"font_color", Palette.INK if picked == null else Palette.PAPER
	)
	_show_pins(run)
	new_packs_key.disabled = packs_reason != &""
	new_packs_key.tooltip_text = StartReasons.new_packs(packs_reason)
	var packs_caption: Label = StartBoardKit.key_caption(new_packs_key)
	packs_caption.add_theme_color_override(
		"font_color", Palette.INK_LIGHT if new_packs_key.disabled else Palette.PAPER
	)


func _show_pins(run: StartBuildView) -> void:
	StartBoardKit.clear(_pins)
	pin_faces.clear()
	StartBoardKit.panel(_pins, Rect2(94, 128, 124, 24), Palette.TEAL_BLACK)
	var pins_title: Label = StartBoardKit.words(
		_pins, "BADGE PINS", Rect2(94, 128, 124, 24), Palette.PAPER
	)
	StartBoardKit.centre(pins_title, Rect2(94, 128, 124, 24))
	var badge: Panel = StartBoardKit.panel(_pins, Rect2(94, 176, 112, 136), Palette.CREAM)
	badge.name = "Badge"
	StartBoardKit.panel(badge, Rect2(2, 2, 108, 38), Palette.TEAL)
	for line: Array in [
		["NEXT", Rect2(2, 0, 108, 22), Palette.PAPER],
		["CUSTOMER", Rect2(2, 18, 108, 22), Palette.PAPER],
		["CASHIER", Rect2(2, 44, 108, 24), Palette.TEAL_SHADE],
	]:
		var badge_line: Label = StartBoardKit.tag(badge, line[0], line[1], line[2])
		StartBoardKit.centre(badge_line, line[1])
	# One big face per slot (mock-up v4 B_s2), side by side and centred under CASHIER.
	var slots: int = maxi(1, run.balance.pin_slots)
	var diameter: float = minf(56.0, 4.0 * floorf((100.0 - 4.0 * (slots - 1)) / slots / 4.0))
	var left: float = (112.0 - slots * diameter - (slots - 1) * 4.0) / 2.0
	for slot: int in slots:
		var face: PinFace = PinFace.new(diameter)
		face.position = Vector2(roundf(left + slot * (diameter + 4.0)), 72)
		badge.add_child(face)
		pin_faces.append(face)
		if slot < run.pins.size():
			face.show_pin(run.pins[slot], slot)
		else:
			var plus: Label = StartBoardKit.body(
				face, "+", Rect2(0, 0, diameter, diameter), Palette.GREY, 20
			)
			plus.name = "Plus"
			plus.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			plus.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	var note: Panel = StartBoardKit.panel(
		_pins, Rect2(216, 158, 152, 96 if run.pins.is_empty() else 136), Palette.PAPER
	)
	note.name = "Note"
	StartBoardKit.panel(note, Rect2(46, -6, 48, 10), Palette.MUSTARD_PALE, Palette.MUSTARD)
	# WEARING n/m centred as one group over the centred lines below.
	var worn_text: String = "%d/%d" % [run.pins.size(), run.balance.pin_slots]
	var worn_width: float = ceilf(
		ArtStyle.pixel_number_font().get_string_size(worn_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 24).x
	)
	var group: float = StartBoardKit.text_width("WEARING") + 6 + worn_width
	var group_left: float = 2.0 * floorf((152.0 - group) / 4.0)
	var wearing: Label = StartBoardKit.tag(
		note, "WEARING", Rect2(group_left, 8, 96, 22), Palette.MUSTARD_DARKEST
	)
	wearing.name = "Wearing"
	var count: Label = StartBoardKit.number(
		note,
		worn_text,
		Rect2(group_left + StartBoardKit.text_width("WEARING") + 6, 4, worn_width + 4, 26),
		Palette.MUSTARD_DARK,
		24
	)
	count.name = "Worn"
	var names: PackedStringArray = []
	var rules: PackedStringArray = []
	for pin: PinDefinition in run.pins:
		names.append(pin.display_name)
		rules.append(pin.rule_text)
	var title: Label = StartBoardKit.body(
		note,
		"No pin worn" if names.is_empty() else " · ".join(names),
		Rect2(8, 32, 138, 20),
		Palette.INK,
		13
	)
	title.add_theme_font_override("font", ArtStyle.bold_font(700))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	# The worn pins' rules (mock-up v4 B_s2), then the free slots; with none worn the free line
	# sits right under "No pin worn".
	pin_rule = StartBoardKit.body(note, " ".join(rules), Rect2(8, 52, 138, 46), Palette.INK, 11)
	pin_rule.name = "Rule"
	pin_rule.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	pin_rule.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	pin_rule.visible = not rules.is_empty()
	var free: int = maxi(0, run.balance.pin_slots - run.pins.size())
	pin_note = StartBoardKit.body(
		note,
		(
			"%d slot%s free · click to change" % [free, "" if free == 1 else "s"]
			if free > 0
			else "click to change"
		),
		Rect2(8, 52 if rules.is_empty() else 98, 138, 34),
		Palette.TEAL_SHADE,
		11
	)
	pin_note.name = "Free"
	pin_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	pin_note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	pin_note.add_theme_font_override("font", ArtStyle.bold_font(700))
	var button: Button = Button.new()
	button.flat = true
	button.position = Vector2(90, 158)
	button.size = Vector2(280, 156)
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	button.focus_mode = Control.FOCUS_NONE
	button.pressed.connect(func() -> void: pins_requested.emit())
	_pins.add_child(button)


func punch() -> Tween:
	var tween: Tween = create_tween()
	tween.tween_property(_time_card, "position:y", 44.0, 0.1)
	tween.tween_interval(0.12)
	tween.tween_property(_time_card, "position:y", 60.0, 0.08)
	return tween


## Builds the crates for the offer's packs (again after NEW PACKS changed them).
func _ensure_crates(offer: StartOffer, reduced: bool) -> void:
	var shown: Array[StarterPackDefinition] = []
	for crate: PackCrate in crates:
		shown.append(crate.pack)
	if shown != offer.packs:
		for crate: PackCrate in crates:
			remove_child(crate)
			crate.queue_free()
		crates.clear()
		for index: int in offer.packs.size():
			var offered: StarterPackDefinition = offer.packs[index]
			var crate: PackCrate = PackCrate.new(offered, index, offered == offer.first_pick)
			crate.position = Vector2(24 + index * 280, 360)
			crate.reduced = reduced
			add_child(crate)
			crates.append(crate)
			crate.picked.connect(func(at: int) -> void: pick_requested.emit(at))
			crate.previewed.connect(func(at: int) -> void: preview_requested.emit(at))


func _show_crates(selected: int, preview: int) -> void:
	for index: int in crates.size():
		var crate: PackCrate = crates[index]
		crate.hovered = preview == index
		crate.position.y = 354 if index == selected or preview == index else 360
		crate.show_state(index == selected, selected >= 0)
