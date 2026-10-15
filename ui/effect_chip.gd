class_name EffectChip
extends Control
## An effect chip under a belt item (#75; style frame v2's spec section 4.4; the base #71
## extends): a step that lands on this card from elsewhere (an upgrade, an inspection or another
## card's FLAT or MULTIPLIER) or a WASTED step that fizzled here. A landed chip has a solid gold
## edge and ink text ("+15 · Category"); a fizzle chip a dashed tomato-dark edge, the fizzle
## icon and the cause in tomato dark. Solid versus dashed plus the icon carry the meaning, not
## colour alone. The text comes from the step (ReceiptView.source_text), shortened by measuring
## with the real font, never cut mid-word.

const SIZE := Vector2(116, 18)
## The text must fit this width, measured with the chip's font.
const TEXT_WIDTH := 88.0
const FONT_SIZE := 12
const FONT_WEIGHT := 700
const ICON_RECT := Rect2(4, 2, 14, 14)
const FIZZLE_TEXT_RECT := Rect2(22, 0, 90, 18)
const LANDED_TEXT_RECT := Rect2(4, 0, 108, 18)
## At most this many chips per cell; the rest fold into the last one as "+N more".
const MAX_PER_CELL := 2
const MORE_TEXT := "+%d more"
## A dimmed chip's text and icon (its face fades to EffectMarker.DIMMED_ALPHA).
const DIMMED_TEXT_ALPHA := 0.7
const SEPARATOR := " · "

const FIZZLE_FRAME := preload("res://art/frames/chip_fizzle.png")
const LANDED_FRAME := preload("res://art/frames/chip_landed.png")
const FIZZLE_ICON := preload("res://art/icons/fizzle.png")

var _fizzle: bool = false
var _dimmed: bool = false
var _face: TextureRect
var _icon: TextureRect
var _label: Label


func _init(text: String = "", fizzle: bool = false) -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	size = SIZE
	custom_minimum_size = SIZE
	_face = UiKit.sprite(LANDED_FRAME)
	_face.size = SIZE
	add_child(_face)
	_icon = UiKit.sprite(FIZZLE_ICON)
	_icon.position = ICON_RECT.position
	_icon.size = ICON_RECT.size
	add_child(_icon)
	_label = UiKit.body_label(text, FONT_SIZE, Palette.INK)
	_label.add_theme_font_override("font", font())
	_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	add_child(_label)
	set_content(text, fizzle)


## An opaque cream underlay while dimmed, inside the face's rounded corners, so the belt never
## shows through a dimmed chip.
func _draw() -> void:
	if not _dimmed:
		return
	var corner: float = ArtStyle.ART_SCALE
	draw_rect(Rect2(corner, 0, SIZE.x - 2.0 * corner, SIZE.y), Palette.CREAM)
	draw_rect(Rect2(0, corner, SIZE.x, SIZE.y - 2.0 * corner), Palette.CREAM)


func label() -> Label:
	return _label


## Dims a chip whose step is still to come: its face fades to EffectMarker.DIMMED_ALPHA and its
## icon and text to DIMMED_TEXT_ALPHA, over an opaque cream underlay, so the belt never shows
## through and the text stays readable.
func set_dimmed(dimmed: bool) -> void:
	_dimmed = dimmed
	_face.modulate.a = EffectMarker.DIMMED_ALPHA if dimmed else 1.0
	var text_alpha: float = DIMMED_TEXT_ALPHA if dimmed else 1.0
	_label.modulate.a = text_alpha
	_icon.modulate.a = text_alpha
	queue_redraw()


## Shows `text` as a landed or a fizzle chip, in place: a chip someone holds stays valid (a
## folded chip turns into "+N more" this way). Keeps the dimmed look.
func set_content(text: String, fizzle: bool) -> void:
	_fizzle = fizzle
	_face.texture = FIZZLE_FRAME if fizzle else LANDED_FRAME
	_icon.visible = fizzle
	_label.text = text
	_label.add_theme_color_override("font_color", Palette.TOMATO_DARK if fizzle else Palette.INK)
	_label.horizontal_alignment = (
		HORIZONTAL_ALIGNMENT_LEFT if fizzle else HORIZONTAL_ALIGNMENT_CENTER
	)
	var text_rect: Rect2 = FIZZLE_TEXT_RECT if fizzle else LANDED_TEXT_RECT
	_label.position = text_rect.position
	_label.size = text_rect.size


func is_dimmed() -> bool:
	return _dimmed


func is_fizzle() -> bool:
	return _fizzle


## The chips' font: bold Atkinson.
static func font() -> Font:
	return ArtStyle.bold_font(FONT_WEIGHT)


## Whether a step becomes a chip: a WASTED step, or a FLAT or MULTIPLIER step that another
## source caused (an upgrade, an inspection or another card).
static func qualifies(step: ScoreStep) -> bool:
	match step.step_type:
		ScoreStep.StepType.WASTED:
			return true
		ScoreStep.StepType.FLAT, ScoreStep.StepType.MULTIPLIER:
			return step.source_kind != ScoreStep.SourceKind.CARD or step.source_slot != step.slot
	return false


## The indices into `result.steps` of the steps that become chips on `slot`, in step order.
static func step_indices(result: ScoreResult, slot: int) -> PackedInt32Array:
	var found: PackedInt32Array = PackedInt32Array()
	for index: int in range(result.steps.size()):
		var step: ScoreStep = result.steps[index]
		if step.slot == slot and qualifies(step):
			found.append(index)
	return found


## The chip's text: "+15 · " or "×2 · " (none for a fizzle), then the first cause that fits
## TEXT_WIDTH with `chip_font`: the receipt's source text, the source's display name, then its
## first word (kept whole even when it doesn't fit).
static func chip_text(
	step: ScoreStep,
	names: PackedStringArray,
	upgrade_names: PackedStringArray,
	inspection_names: PackedStringArray,
	chip_font: Font,
	font_size: int
) -> String:
	var prefix: String = ""
	match step.step_type:
		ScoreStep.StepType.FLAT:
			prefix = "+%d%s" % [step.value, SEPARATOR]
		ScoreStep.StepType.MULTIPLIER:
			prefix = "×%d%s" % [step.value, SEPARATOR]
	var display_name: String = source_name(step, names, upgrade_names, inspection_names)
	var causes: PackedStringArray = [
		ReceiptView.source_text(step, upgrade_names, inspection_names),
		display_name,
		display_name.get_slice(" ", 0),
	]
	for cause: String in causes:
		var text: String = prefix + cause
		if fits(text, chip_font, font_size):
			return text
	return prefix + causes[causes.size() - 1]


## Whether `text` fits TEXT_WIDTH in `chip_font` at `font_size`.
static func fits(text: String, chip_font: Font, font_size: int) -> bool:
	var width: float = chip_font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	return width <= TEXT_WIDTH


## The display name of the step's source: the card, upgrade or inspection.
static func source_name(
	step: ScoreStep,
	names: PackedStringArray,
	upgrade_names: PackedStringArray,
	inspection_names: PackedStringArray
) -> String:
	var source_names: PackedStringArray = names
	var index: int = step.source_slot
	match step.source_kind:
		ScoreStep.SourceKind.UPGRADE:
			source_names = upgrade_names
			index = step.source_index
		ScoreStep.SourceKind.INSPECTION:
			source_names = inspection_names
			index = step.source_index
	if index < 0 or index >= source_names.size():
		return step.text
	return source_names[index]


## The step's full line for the scan popup's footer: "+15 Category engine", "×2 Slot engine",
## or a fizzle's "Coupon engine: <reason>", as the receipt names its cause.
static func full_line(
	step: ScoreStep, upgrade_names: PackedStringArray, inspection_names: PackedStringArray
) -> String:
	var cause: String = ReceiptView.source_text(step, upgrade_names, inspection_names)
	match step.step_type:
		ScoreStep.StepType.FLAT:
			return "+%d %s" % [step.value, cause]
		ScoreStep.StepType.MULTIPLIER:
			return "×%d %s" % [step.value, cause]
	return "%s: %s" % [cause, step.reason]
