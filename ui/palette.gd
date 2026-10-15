class_name Palette
extends RefCounted
## The art direction's colours (full build plan section 6.1: cream, faded teal, tomato, mustard,
## and the boutique's brass, gold and velvet), shared by the screens. Every colour here is one of
## art/src/palette.txt's (tests/ui/palette_colours_test.gd).

const BACKGROUND := Color("1f3b3a")
const PANEL := Color("2a4d4b")
const PAPER := Color("fbf7ee")
const CREAM := Color("f3e9d2")
const MUSTARD := Color("e2b33c")
const TOMATO := Color("d9534f")
const TEAL := Color("4f9a94")
## The art's warm ink.
const INK := ArtStyle.INK
const MUTED_INK := Color("8a8172")
const GOOD := Color("5fae5a")
## The art palette's paper white.
const LIGHT_TEXT := PAPER
## The boutique look (style frame v2, #55): the ink, grey and cream ramps' other shades.
const INK_LIGHT := Color("4a3f38")
const GREY_DARK := Color("5e574d")
const GREY := Color("8a8172")
const GREY_LIGHT := Color("c7beab")
const CREAM_SHADE := Color("ddcba5")
const TOMATO_DARK := Color("a83a3c")
const MUSTARD_LIGHT := Color("f1d27a")
const MUSTARD_PALE := Color("faecbc")
## Brass (rails, rims and plaques), gold (lettering and the LED) and velvet (the wall, signs and
## CHECKOUT).
const BRASS_DARKEST := Color("4a3010")
const BRASS_DARK := Color("8a5d1a")
const BRASS := Color("c8932b")
const GOLD := Color("ffcf3f")
const VELVET_DARKEST := Color("2a0e14")
const VELVET_DARK := Color("561327")
const VELVET := Color("8a1f33")
const VELVET_SHEEN := Color("b23a55")
