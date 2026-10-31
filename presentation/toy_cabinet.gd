class_name ToyCabinet
extends Resource
## One aisle's TOY MACHINE cabinet (#121, mock-up toy_machines_121_v2.html; full build plan 6.1
## and 7.1), as data (data/toy_cabinets/<aisle id>.tres), so a cabinet is switched by data alone:
## which art set it draws (art/toys/toy_<part>_<art_id>[_dim|_off].png: the cabinet top, the
## aisle's base, the front overlay and the window capsule), where its capsules sit and its
## window (the OUT OF ORDER tape and the SOLD OUT card are centred on it; no figurine stands on
## top since v0.78). An aisle with no file gets an empty cabinet (for_aisle): no cabinet top, the
## plain teal base and no capsules. Every default is neutral (empty), so a script edit never
## silently changes the data. Presentation only: the draw rules never read it.

## The tones of an art set: lit (a machine you can play), dim (out of coins, collected) and off
## (out of order).
enum Tone { LIT, DIM, OFF }

const PATH := "res://data/toy_cabinets/%s.tres"
const ART_PATH := "res://art/toys/toy_%s_%s%s.png"
const TONE_SUFFIXES: Array[String] = ["", "_dim", "_off"]

## The art set's name in the art files' names (the aisle's id for the six cabinets).
@export var art_id: StringName = &""
## The capsules' top-left corners, in machine art px, filled in this order: one capsule per item
## left, as many as there are slots.
@export var slots: Array[Vector2i] = []
## The window the capsules sit in, in machine art px.
@export var window: Rect2i = Rect2i()


## The cabinet of the aisle `aisle_id`: its file, or an empty cabinet (no file, or a file that
## is not a ToyCabinet).
static func for_aisle(aisle_id: StringName) -> ToyCabinet:
	var path: String = PATH % aisle_id
	var found: ToyCabinet = load(path) as ToyCabinet if ResourceLoader.exists(path) else null
	return found if found != null else ToyCabinet.new()


## The art of `part` (cabinet, base, front, capsule_window) in `tone`, or null when the set
## has no such file (Bakery has no front overlay).
func art(part: String, tone: Tone) -> Texture2D:
	if art_id == &"":
		return null
	var path: String = ART_PATH % [part, art_id, TONE_SUFFIXES[tone]]
	return load(path) as Texture2D if ResourceLoader.exists(path) else null
