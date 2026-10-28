class_name MachineLook
extends RefCounted
## The machine's dressing at one time of its visit (v0.50, mock-up premium_machine_v1.html,
## dressing A "night sign + gold trim", approved): CLASSIC (RECEIPT REWARDS), or PREMIUM on a
## PREMIUM visit (since v0.61 a rarity boost, #108: the same two chutes, every ticket RARE or
## better), which the same machine turns into after its receipt is read (MachinePlan.premium_at)
## and stays for the whole visit: the sign flashes to a dark night face with lit gold PREMIUM
## REWARDS and its bulbs chase on, a 3 px gold trim runs down both cabinet edges, the gold receipt
## stays in the slot, the tray goes gold, the key plate goes dark, the keys sink and rise back, and
## the stock window's columns restock one by one onto gold pedestals.
## at() reads only the plan and `t`, so every part shows the same transform; the times are the
## mock-up's (seconds into the transform), scaled to MachineTuning.premium_ms; under reduced
## motion the transform is a cut at its end.

## The mock-up's transform length (its times below are in its seconds) and when it is done.
const MOCK_LENGTH := 1.8
const DONE := 99.0
const CLASSIC := -1.0
const FACE_AT := 0.3
const FLASH_LENGTH := 0.08
const BULB_STAGGER := 0.012
const BULBS_ALL := 1.4
const TRIM_FROM := 0.3
const TRIM_TO := 1.0
const TRAY_AT := 0.9
const PLATE_AT := 1.0
const SINK_FROM := 1.0
const SINK_TO := 1.25
const RISE_FROM := 1.3
const RISE_TO := 1.65
const WINDOW_FROM := 1.0
const WINDOW_STAGGER := 0.24
const WINDOW_OUT := 0.12
const WINDOW_IN := 0.26
## The chasing bulbs' step rate (a step every tenth of a second) and the sign's shine period.
const CHASE_RATE := 10.0
const SHINE_PERIOD := 2.4
const SHINE_LENGTH := 0.6

## Seconds into the transform on the mock-up's clock: CLASSIC (no transform, or before it), DONE
## once over (and on a resumed PREMIUM visit).
var d: float = CLASSIC
## A PREMIUM visit (it turns PREMIUM).
var premium_visit: bool = false


## The look of `plan` at `t` (null: the idle machine, classic).
static func at(plan: MachinePlan, t: float) -> MachineLook:
	var look: MachineLook = MachineLook.new()
	if plan == null:
		return look
	look.premium_visit = plan.premium
	var since: float = plan.premium_progress(t)
	if since < 0.0:
		return look
	var length: float = plan.premium_length()
	if plan.reduced_motion or length <= 0.0 or since >= length:
		look.d = DONE if since >= length or not plan.reduced_motion else CLASSIC
		return look
	look.d = since / length * MOCK_LENGTH
	return look


## Whether any of the premium dressing shows (the transform has started).
func premium() -> bool:
	return d >= 0.0


## The sign's night face (PREMIUM REWARDS) shows.
func night_face() -> bool:
	return d >= FACE_AT


## The white flash frame as the sign changes.
func flash() -> bool:
	return d >= FACE_AT and d < FACE_AT + FLASH_LENGTH


## Whether bulb `index` (of the marquee's ring) is lit at `t` (the chase steps on `t`; dark on the
## classic machine): it comes on in turn during the transform, then chases, one in four dark.
func bulb_lit(index: int, t: float) -> bool:
	if d < 0.0:
		return false
	if d < BULBS_ALL and d < index * BULB_STAGGER:
		return false
	return (index + int(floorf(t * CHASE_RATE))) % 4 != 0


## How far down the cabinet's gold trim has run (0 .. 1).
func trim() -> float:
	return MachineArt.ease_out(MachineArt.seg(d, TRIM_FROM, TRIM_TO)) if d >= 0.0 else 0.0


func tray_gold() -> bool:
	return d >= TRAY_AT


func night_plate() -> bool:
	return d >= PLATE_AT


## How far up the keys stand (1 up on the plate .. 0 sunk out of sight): up, and on a PREMIUM
## visit (v0.61, #108) they sink and rise back during the transform, gold (keys_gold).
func keys_up() -> float:
	if not premium_visit or d < 0.0:
		return 1.0
	if d < RISE_FROM:
		return 1.0 - MachineArt.seg(d, SINK_FROM, SINK_TO)
	return MachineArt.ease_back(MachineArt.seg(d, RISE_FROM, RISE_TO))


## Whether the keys are gold: once they rise back during the transform (a PREMIUM visit's keys,
## v0.61), never on the classic machine.
func keys_gold() -> bool:
	return premium_visit and d >= RISE_FROM


## Window column `column_index` (0 left, 1 right) during the transform: [offset px (down: the
## classic tickets leaving; up: the new ones rising), whether it stands on gold pedestals].
func column(column_index: int) -> Array:
	if not premium_visit or d < 0.0:
		return [0.0, false]
	var k0: float = WINDOW_FROM + column_index * WINDOW_STAGGER
	if d < k0:
		return [0.0, false]
	if d < k0 + WINDOW_OUT:
		return [MachineArt.snap(140.0 * pow(MachineArt.seg(d, k0, k0 + WINDOW_OUT), 2.0)), false]
	var rise: float = MachineArt.ease_back(MachineArt.seg(d, k0 + WINDOW_OUT, k0 + WINDOW_IN))
	return [-MachineArt.snap(120.0 * (1.0 - rise)), true]


## The shine band across the night sign at `t` (0 .. 1 while it crosses, else outside): every
## SHINE_PERIOD seconds.
func sign_shine(t: float) -> float:
	if not night_face():
		return -1.0
	return fposmod(t, SHINE_PERIOD) / SHINE_LENGTH
