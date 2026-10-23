class_name RarityTab
extends Control
## A prize ticket's rarity tab (v0.50, mock-up premium_machine_v1.html, R1 "drop"), above the
## ticket: COMMON (grey light, ink), RARE! (teal, paper) or LEGENDARY!! (gold, brass darkest, a
## mustard pale top line), bold Atkinson 16 on a box with a soft shadow. It shows as its ticket
## lands face up and punches in: a RARE from 1.3x over 0.15 s, a LEGENDARY from 1.7x over 0.2 s
## (reduced motion: at rest). The word, the ticket's pips and the effects tell the rarities apart,
## never the colour alone.

const TEXTS: Array[String] = ["COMMON", "RARE!", "LEGENDARY!!"]
const FILLS: Array[Color] = [Palette.GREY_LIGHT, Palette.TEAL, Palette.GOLD]
const INKS: Array[Color] = [Palette.INK, Palette.PAPER, Palette.BRASS_DARKEST]
const FONT_SIZE := 16
const BOLD_WEIGHT := 800
const PAD := 12.0
const HEIGHT := 26.0
const SHADOW := 4.0
const PUNCH_FROM: Array[float] = [1.0, 1.3, 1.7]
const PUNCH_LENGTH: Array[float] = [0.0, 0.15, 0.2]

var rarity: int = 0
var _label: Label


func _init(tab_rarity: int = 0) -> void:
	rarity = clampi(tab_rarity, 0, TEXTS.size() - 1)
	name = "RarityTab"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var font: Font = ArtStyle.bold_font(BOLD_WEIGHT)
	var width: float = MachineArt.text_width(TEXTS[rarity], font, FONT_SIZE)
	size = Vector2(MachineArt.snap(width + 2.0 * PAD), HEIGHT)
	pivot_offset = size / 2.0
	_label = UiKit.body_label(TEXTS[rarity], FONT_SIZE, INKS[rarity])
	_label.name = "Text"
	_label.add_theme_font_override("font", font)
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	RewardMachineView.fit(_label, Rect2(Vector2.ZERO, size))
	add_child(_label)
	visible = false


## The tab `te` seconds after its ticket landed face up (below 0: hidden).
func show_at(te: float, rm: bool) -> void:
	visible = te >= 0.0
	var punch: float = 1.0
	if visible and not rm and PUNCH_LENGTH[rarity] > 0.0:
		var p: float = MachineArt.ease_out(MachineArt.seg(te, 0.0, PUNCH_LENGTH[rarity]))
		punch = lerpf(PUNCH_FROM[rarity], 1.0, p)
	scale = Vector2.ONE * punch


func text() -> String:
	return _label.text


func label() -> Label:
	return _label


func _draw() -> void:
	var rect: Rect2 = Rect2(Vector2.ZERO, size)
	draw_rect(Rect2(rect.position + Vector2(SHADOW, SHADOW), size), Color(Palette.INK, 0.35))
	var legendary: bool = rarity == MachinePrize.Rarity.LEGENDARY
	var line: Color = Palette.BRASS_DARKEST if legendary else Palette.INK
	MachineArt.box(self, rect, FILLS[rarity], line)
	if rarity == MachinePrize.Rarity.LEGENDARY:
		draw_rect(Rect2(2, 2, size.x - 4, 2), Palette.MUSTARD_PALE)
