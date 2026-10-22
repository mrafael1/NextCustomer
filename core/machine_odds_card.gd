class_name MachineOddsCard
extends RefCounted
## The exact odds of one chute's next draw (#77, build spec 1.5), as the odds card shows them.
## Made by MachineOdds (every possible draw enumerated with its probability, no RNG used); the
## next-visit fields are set by RewardMachine. The UI only displays these numbers; `notes` are
## keys the UI maps to text.

## Note keys.
const NOTE_LEGENDARY_EMPTY := &"legendary_empty_falls"
const NOTE_LEGENDARY_NONE_IN_STOCK := &"legendary_none_in_stock"
const NOTE_SHORT_DRAW := &"short_draw"
const NOTE_NEW_ARRIVAL_HELD := &"new_arrival_held"
const NOTE_CART_FULL := &"cart_full"
## Drop 1 can land below the level's first-drop floor (its rarity and those above are empty).
const NOTE_FLOOR_FALLS := &"floor_falls"

## RewardMachine.Chute.
var chute: int = 0
var level: int = 0
## The share of each rarity (COMMON, RARE, LEGENDARY) per drop, over the drops that land, as the
## card prints it: at a level with a first-drop floor, the share of drops 2 to n (`first_share`
## is drop 1's); otherwise, or when no draw reaches drop 2, `all_share`.
var rarity_share: PackedFloat64Array = PackedFloat64Array([0.0, 0.0, 0.0])
## Over every drop that lands.
var all_share: PackedFloat64Array = PackedFloat64Array([0.0, 0.0, 0.0])
## Drop 1 only.
var first_share: PackedFloat64Array = PackedFloat64Array([0.0, 0.0, 0.0])
## Drops 2 to n.
var rest_share: PackedFloat64Array = PackedFloat64Array([0.0, 0.0, 0.0])
## The level's first-drop floor (1: "1 of 3 at least RARE"; 0: none).
var first_drop_min_rarity: int = 0
## Prize key (MachinePrize.key) to the chance the prize is among the drops; prizes that can't
## drop are left out.
var in_draw: Dictionary = {}
## The chance of at least one RARE or better, of a LEGENDARY, of fewer drops than the visit's
## prizes (a short draw), and that the draw holds its guarantee.
var p_rare_plus: float = 0.0
var p_legendary: float = 0.0
var p_short: float = 0.0
var p_guarantee_held: float = 0.0
## Whether the chute has a guarantee this draw (a non-empty guarantee set).
var guarded: bool = false
## The prize keys (MachinePrize.key) in the guarantee set (MachineDraw.guarantee), each true:
## the names the odds card prints bold.
var guaranteed: Dictionary = {}
var notes: Array[StringName] = []
## Set by RewardMachine: the level after this visit's pick or bin, whether the meter rises, and
## the per-drop shares this chute would print on its next visit (as `rarity_share`).
var next_level: int = 0
var meter_rises: bool = false
var next_rarity_share: PackedFloat64Array = PackedFloat64Array([0.0, 0.0, 0.0])
