class_name ToyCabinet
extends Resource
## One aisle's TOY MACHINE cabinet (#121, mock-up toy_machines_121_v2.html; full build plan 6.1
## and 7.1), as data (data/toy_cabinets/<aisle id>.tres), so a cabinet is switched by data alone:
## which art set it draws (art/toys/toy_<part>_<art_id>[_dim|_off].png: the cabinet top, the
## aisle's base, the front overlay, the window capsule and the plinth), where its capsules sit,
## its window (the OUT OF ORDER tape is centred on it) and the figurine standing on its plinth.
## An aisle with no file gets an empty cabinet (for_aisle): no cabinet top, the plain teal base,
## no capsules and no topper. Every default is neutral (empty), so a script edit never silently
## changes the data. Presentation only: the draw rules never read it.

## The tones of an art set: lit (a machine you can play), dim (out of coins, collected) and off
## (out of order).
enum Tone { LIT, DIM, OFF }

const PATH := "res://data/toy_cabinets/%s.tres"
const ART_PATH := "res://art/toys/toy_%s_%s%s.png"
const TONE_SUFFIXES: Array[String] = ["", "_dim", "_off"]

## The art set's name in the art files' names (the aisle's id for the six cabinets).
@export var art_id: StringName = &""
## The figurine standing on the plinth above the sign: its item sprite (art_ref), or its
## `_dim` twin when the machine is dimmed. Null: no plinth and no topper.
@export var topper: CardDefinition
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


## The art of `part` (cabinet, base, front, capsule_window, plinth) in `tone`, or null when the set
## has no such file (Bakery has no front overlay).
func art(part: String, tone: Tone) -> Texture2D:
	if art_id == &"":
		return null
	var path: String = ART_PATH % [part, art_id, TONE_SUFFIXES[tone]]
	return load(path) as Texture2D if ResourceLoader.exists(path) else null


## The topper's sprite, lit or dimmed (its art_ref's `_dim` twin; the lit one when it has none).
## Null (no plinth, no topper) without a topper or when its sprite is missing: never the
## art-pending box on a plinth.
func topper_art(dimmed: bool) -> Texture2D:
	if topper == null:
		return null
	var lit: Texture2D = ArtStyle.item_sprite(topper)
	if lit == null or lit == ArtStyle.ITEM_PENDING:
		return null
	if not dimmed or topper.art_ref.is_empty():
		return lit
	var path: String = topper.art_ref.get_basename() + "_dim.png"
	return load(path) as Texture2D if ResourceLoader.exists(path) else lit
