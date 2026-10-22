class_name ReceiptStamps
extends RefCounted
## The clerk's stamps on the receipt (split out of ReceiptView, #77, build spec 4.5): PAID on a
## passed shift's margin line (#61), and INSPECTION PASSED on a passed inspected shift (#77,
## round 3: the shift that earns the BONUS TICKET), a paper stamp in a dark tomato border,
## tilted, naming the inspection under its title. Both are tilted like a clerk's stamp and keep
## their tilt when their line's container sorts again.

## PAID on the margin line, tilted.
const PAID_TEXT := "PAID"
const PAID_TILT_DEG := -8.0
## INSPECTION PASSED: its title (Pixelify 12) over the inspection's name (bold Atkinson 11), in a
## dark tomato border on paper, tilted INSPECTION_TILT_DEG around its left end.
const INSPECTION_TEXT := "INSPECTION PASSED ✓"
const INSPECTION_TILT_DEG := -3.0
const INSPECTION_NAME := "InspectionStamp"
const TITLE_SIZE := 12
const NAME_SIZE := 11
const NAME_WEIGHT := 800
const BORDER := 2
const PAD_X := 6
const PAD_Y := 2
## The stamp's left inset on its line, and the room left under it for its tilt.
const STAMP_INSET := 4.0
const STAMP_ROOM := 6.0
## Pixelify has no ✓: the title's font falls back to the mono font for it (desktop and web alike).
const TITLE_NAME := "Title"

static var _title_font: FontVariation


## PAID is stamped on a passed shift's margin `line`, tilted. Returns the stamp's label.
static func stamp_paid(line: Control) -> Label:
	var stamp: Label = line.get_child(1) as Label
	stamp.text = PAID_TEXT
	stamp.add_theme_color_override("font_color", Palette.TOMATO)
	tilt(stamp, PAID_TILT_DEG, true)
	# A container sets its children's rotation back to 0 whenever it sorts them.
	(line as Container).sort_children.connect(tilt.bind(stamp, PAID_TILT_DEG, true))
	return stamp


## INSPECTION PASSED with `inspection_name` under it, on a new line of `receipt` under the
## margin line (which keeps PAID): the stamp hangs on the line's left label (inspection_of()),
## which is as tall as the stamp, so the line keeps a receipt line's two labels. Returns the line.
static func stamp_inspection(receipt: ReceiptView, inspection_name: String) -> Control:
	var line: Control = receipt.add_line("", "", ReceiptView.LineStyle.MARGIN)
	var left: Label = line.get_child(0) as Label
	var stamp: PanelContainer = inspection_stamp(inspection_name)
	left.add_child(stamp)
	stamp.position = Vector2(STAMP_INSET, 0.0)
	stamp.size = stamp.get_combined_minimum_size()
	_fit_line(left, stamp)
	# Laid out in the tree (its fonts), the stamp may grow: its line grows with it.
	stamp.resized.connect(_fit_line.bind(left, stamp))
	return line


## The gold BONUS stub (#77 machine v2, `sub` its small line) at `receipt`'s foot, 0 high
## (ReceiptStub.grow prints it).
static func add_bonus_stub(receipt: ReceiptView, sub: String) -> ReceiptStub:
	var made: ReceiptStub = ReceiptStub.new(sub)
	receipt.stub = made
	return made


## The INSPECTION PASSED stamp alone (the BONUS TICKET's stub carries one too), tilted.
static func inspection_stamp(inspection_name: String) -> PanelContainer:
	var stamp: PanelContainer = PanelContainer.new()
	stamp.name = INSPECTION_NAME
	stamp.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	stamp.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = Palette.PAPER
	style.border_color = Palette.TOMATO_DARK
	style.set_border_width_all(BORDER)
	style.content_margin_left = PAD_X
	style.content_margin_right = PAD_X
	style.content_margin_top = PAD_Y
	style.content_margin_bottom = PAD_Y
	stamp.add_theme_stylebox_override("panel", style)
	var lines: VBoxContainer = VBoxContainer.new()
	lines.add_theme_constant_override("separation", 0)
	lines.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stamp.add_child(lines)
	var title: Label = UiKit.display_label(INSPECTION_TEXT, TITLE_SIZE, false)
	title.name = TITLE_NAME
	title.add_theme_font_override("font", title_font())
	title.add_theme_color_override("font_color", Palette.TOMATO_DARK)
	lines.add_child(title)
	if not inspection_name.is_empty():
		var name_label: Label = UiKit.body_label(inspection_name, NAME_SIZE, Palette.TOMATO_DARK)
		name_label.add_theme_font_override("font", ArtStyle.bold_font(NAME_WEIGHT))
		lines.add_child(name_label)
	tilt(stamp, INSPECTION_TILT_DEG, false)
	return stamp


## The INSPECTION PASSED title's font: Pixelify with the mono font behind it for the ✓.
static func title_font() -> Font:
	if _title_font == null:
		_title_font = FontVariation.new()
		_title_font.base_font = ArtStyle.DISPLAY_FONT
		var fallbacks: Array[Font] = [ArtStyle.MONO_FONT]
		_title_font.fallbacks = fallbacks
	return _title_font


## The INSPECTION PASSED stamp on `line` (stamp_inspection), or null.
static func inspection_of(line: Control) -> PanelContainer:
	if line == null or line.get_child_count() == 0:
		return null
	return line.get_child(0).get_node_or_null(INSPECTION_NAME) as PanelContainer


## Tilts `stamp` by `degrees`, around its centre (`centred`) or its left end.
static func tilt(stamp: Control, degrees: float, centred: bool) -> void:
	stamp.pivot_offset = stamp.size / 2.0 if centred else Vector2(0.0, stamp.size.y / 2.0)
	stamp.rotation = deg_to_rad(degrees)


static func _fit_line(left: Label, stamp: Control) -> void:
	left.custom_minimum_size.y = stamp.size.y + STAMP_ROOM
	tilt(stamp, INSPECTION_TILT_DEG, false)
