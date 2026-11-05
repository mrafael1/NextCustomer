class_name RarityTab
extends Control
## A prize ticket's rarity tab (v0.50, mock-up premium_machine_v1.html, R1 "drop"), above the
## ticket: COMMON (v0.97, look C: a flat cream shelf label, ink, a cream dark foot line), RARE!
## (teal, paper, a bright teal top line) or LEGENDARY!! (gold, brass darkest, a mustard pale top
## line and a mustard dark foot line), in hard pixel capitals (MachineLine, 2x; the relook,
## v0.86) on a box with a soft shadow. It shows as its ticket lands face up and punches in: a
## RARE from 1.3x over 0.15 s, a LEGENDARY from 1.7x over 0.2 s (reduced motion: at rest).
## The word, the ticket's pips and the effects tell the rarities apart, never the colour alone.

const TEXTS: Array[String] = ["COMMON", "RARE!", "LEGENDARY!!"]
const FILLS: Array[Color] = [Palette.CREAM_SHADE, Palette.TEAL, Palette.GOLD]
## Each tab's top and foot lines inside its outline (clear: none).
const TOP_LINES: Array[Color] = [Color(Palette.INK, 0.0), Palette.TEAL_BRIGHT, Palette.MUSTARD_PALE]
const FOOT_LINES: Array[Color] = [
	Palette.CREAM_DARKEST, Color(Palette.INK, 0.0), Palette.MUSTARD_DARK
]
const INKS: Array[Color] = [Palette.INK, Palette.PAPER, Palette.BRASS_DARKEST]
const PAD := 10.0
const HEIGHT := 22.0
const SHADOW := 4.0
const PUNCH_FROM: Array[float] = [1.0, 1.3, 1.7]
const PUNCH_LENGTH: Array[float] = [0.0, 0.15, 0.2]

var rarity: int = 0
var _line: MachineLine


func _init(tab_rarity: int = 0) -> void:
	rarity = clampi(tab_rarity, 0, TEXTS.size() - 1)
	name = "RarityTab"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_line = MachineLine.make("Text", TEXTS[rarity], INKS[rarity])
	size = Vector2(MachineArt.snap(_line.width() + 2.0 * PAD), HEIGHT)
	pivot_offset = size / 2.0
	_line.centre_in(Rect2(Vector2.ZERO, size))
	add_child(_line)
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
	return _line.text()


## The word in hard pixel capitals.
func word_line() -> MachineLine:
	return _line


func _draw() -> void:
	var rect: Rect2 = Rect2(Vector2.ZERO, size)
	draw_rect(Rect2(rect.position + Vector2(SHADOW, SHADOW), size), Color(Palette.INK, 0.35))
	var legendary: bool = rarity == MachinePrize.Rarity.LEGENDARY
	var line: Color = Palette.BRASS_DARKEST if legendary else Palette.INK
	MachineArt.box(self, rect, FILLS[rarity], line)
	var p: float = MachineArt.PIXEL
	if TOP_LINES[rarity].a > 0.0:
		draw_rect(Rect2(p, p, size.x - 2.0 * p, p), TOP_LINES[rarity])
	if FOOT_LINES[rarity].a > 0.0:
		draw_rect(Rect2(p, size.y - 2.0 * p, size.x - 2.0 * p, p), FOOT_LINES[rarity])
