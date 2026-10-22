class_name MachineTuning
extends Resource
## The RECEIPT REWARDS machine's tempo (#77, build spec 4.3-4.4): every time of a visit's
## timeline, from the approved page (docs/art/mockups/machine_77_flow.html: buildTimeline,
## bonusTimeline and look F's plan). They live in data/balance/machine_tempo.tres so they can be
## tuned without code changes; MachinePlan reads them and never hard-codes one. Every default is
## neutral (0 or empty), like CountUpTuning, so a script edit can never silently change the tuned
## values in the file.
##
## Times are in ms at 1x (the count-up's speed setting doesn't scale the machine); `_rm_ms` fields
## are the reduced-motion variants. A field that is a list holds one value per visit kind, in
## MachineVisit.Kind order: [TICKET, BONUS, STAMP_DAY], or one per rarity, in
## MachinePrize.Rarity order: [COMMON, RARE, LEGENDARY]. A missing entry reads 0.

@export_group("Ticket intro")
## The receipt's flight from the receipt column to the slot, from the dessert's printer feed.
@export var flight_ms: int = 0
@export var flight_rm_ms: int = 0
## The receipt fed under the slot's clip.
@export var feed_ms: int = 0
@export var feed_rm_ms: int = 0
## "READING…", then the check line.
@export var read_ms: int = 0
## The chute keys lighting up, staggered by key_stagger_ms (one note each).
@export var lights_ms: int = 0
@export var key_stagger_ms: int = 0

@export_group("Bonus intro")
## The BONUS TICKET! head stamp and the stub printing out of the printer mouth.
@export var stub_ms: int = 0
@export var stub_rm_ms: int = 0
## From the stub printed to its flight's start (none under reduced motion).
@export var stub_lead_ms: int = 0
## The stub's flight to the slot (a jump under reduced motion).
@export var stub_flight_ms: int = 0
## The stub fed under the clip (slower under reduced motion: the stub shows while it reads).
@export var stub_feed_ms: int = 0
@export var stub_feed_rm_ms: int = 0
## The read line after the feed, then the keys going unlit and relit by relight_stagger_ms.
@export var bonus_read_ms: int = 0
@export var bonus_lights_ms: int = 0
@export var relight_stagger_ms: int = 0
## "PICK A CHUTE AGAIN" from the feed's end to the chute wait.
@export var again_ms: int = 0

@export_group("Odds card")
## The odds card popping open (ease) and closing after CONFIRM, per kind.
@export var odds_open_ms: int = 0
@export var odds_close_ms: PackedInt32Array = PackedInt32Array()

@export_group("Draw")
## "PACKING YOUR ORDER…": from the odds card closed to the draw's end, per kind (STAMP DAY: 0,
## its drops are timed from the visit's start).
@export var draw_ms: PackedInt32Array = PackedInt32Array()
@export var draw_rm_ms: int = 0
## When box i reaches its gate, after the draw's end (look F's LANDS).
@export var lands_ms: PackedInt32Array = PackedInt32Array()
## The first bay pick, after the draw starts (look F's `T.draw + .05`; STAMP DAY's `T.sd + .02`),
## per kind; none under reduced motion for TICKET and BONUS.
@export var pick_lead_ms: PackedInt32Array = PackedInt32Array()
## Belt speed in machine px per second (look F's V_MAIN, V_SD), per kind.
@export var belt_px_per_s: PackedInt32Array = PackedInt32Array()
## The belt's speed ramps up before its first box and down after its last.
@export var belt_ramp_up_ms: int = 0
@export var belt_ramp_down_ms: int = 0
## A box shows on the belt this long before it clears the curtain (look F's `r.e - .05`).
@export var box_show_early_ms: int = 0
## A box's trip from its bay (look F's RUN), per kind: the trapdoor fall, the runway speed in
## stockroom art px per second, and the time inside the hatch.
@export var fall_ms: PackedInt32Array = PackedInt32Array()
@export var runway_px_per_s: PackedInt32Array = PackedInt32Array()
@export var hidden_ms: PackedInt32Array = PackedInt32Array()
## Under reduced motion boxes appear at their gates: box i at drop_gap_rm_ms x i after the draw's
## end, for drop_rm_ms.
@export var drop_gap_rm_ms: int = 0
@export var drop_rm_ms: int = 0
## STAMP DAY's drops (it has no belt run timed from LANDS): box i drops at stamp_drop_ms +
## stamp_drop_gap_ms x i, for stamp_drop_length_ms.
@export var stamp_drop_ms: int = 0
@export var stamp_drop_gap_ms: int = 0
@export var stamp_drop_gap_rm_ms: int = 0
@export var stamp_drop_length_ms: int = 0
@export var stamp_drop_length_rm_ms: int = 0
## The PACKED stamp after the last bay pick (STAMP DAY: packed_stamp_day_ms), its 1.6 -> 1 pop,
## and under reduced motion after the draw starts.
@export var packed_ms: int = 0
@export var packed_stamp_day_ms: int = 0
@export var packed_pop_ms: int = 0
@export var packed_rm_ms: int = 0

@export_group("Reveals")
## The first reveal after the last box lands, per kind.
@export var reveal_start_ms: PackedInt32Array = PackedInt32Array()
## A reveal's length per rarity: TICKET and BONUS, STAMP DAY, and their reduced-motion lengths.
@export var reveal_ms: PackedInt32Array = PackedInt32Array()
@export var reveal_rm_ms: PackedInt32Array = PackedInt32Array()
@export var reveal_stamp_day_ms: PackedInt32Array = PackedInt32Array()
@export var reveal_stamp_day_rm_ms: PackedInt32Array = PackedInt32Array()
## The gap after each reveal, per kind.
@export var reveal_gap_ms: PackedInt32Array = PackedInt32Array()
## The pick arms this long after the last reveal's gap (the page's curPick), per kind.
@export var pick_arm_ms: PackedInt32Array = PackedInt32Array()

@export_group("Landing")
## From the pick press to the flight's start, per kind.
@export var pick_lead_flight_ms: PackedInt32Array = PackedInt32Array()
## The prize's flight to the cart drawer or the loyalty box, per kind, and under reduced motion.
@export var pick_flight_ms: PackedInt32Array = PackedInt32Array()
@export var pick_flight_rm_ms: int = 0
## UPGRADES: the glint after the landing (per kind; reduced motion), one step per extra copy and
## the glint's tail (none under reduced motion).
@export var glint_ms: PackedInt32Array = PackedInt32Array()
@export var glint_rm_ms: int = 0
@export var glint_copy_ms: int = 0
@export var glint_tail_ms: int = 0
## The punch after the landing: a new card (NEW ITEMS, COUPONS), a register stamp, an upgrade
## (after the glint's end); per kind; and the reduced-motion waits, per kind.
@export var punch_new_ms: PackedInt32Array = PackedInt32Array()
@export var punch_register_ms: PackedInt32Array = PackedInt32Array()
@export var punch_upgrade_ms: PackedInt32Array = PackedInt32Array()
@export var punch_rm_ms: PackedInt32Array = PackedInt32Array()
## A binned draw's punch after the bin press.
@export var punch_bin_ms: int = 0
## The punch itself (jaw, chad, "+1").
@export var punch_length_ms: int = 0
## The cart drawer slides in before the flight's start and out after the punch.
@export var drawer_lead_ms: int = 0
@export var drawer_tail_ms: int = 0
## The bays refill after the punch, restock_gap_ms apart (together under reduced motion);
## STAMP DAY's after its landing.
@export var restock_ms: int = 0
@export var restock_stamp_day_ms: int = 0
@export var restock_gap_ms: int = 0

@export_group("Holds")
## The end hold after the punch when no visit follows, per kind (STAMP DAY: after its landing).
@export var end_hold_ms: PackedInt32Array = PackedInt32Array()
## The hold before the next visit: a BONUS TICKET, STAMP DAY.
@export var before_bonus_ms: int = 0
@export var before_stamp_day_ms: int = 0

@export_group("Head stamp")
## The BONUS TICKET! / STAMP DAY! head stamp: it lands (2x to 1x) and blinks in from the visit's
## start, and lifts this long after the punch's end (STAMP DAY: its landing).
@export var head_stamp_land_ms: int = 0
@export var head_stamp_blink_ms: int = 0
@export var head_stamp_lift_ms: int = 0


## `list`[index] in seconds, 0 when the list is shorter.
static func seconds(list: PackedInt32Array, index: int) -> float:
	return list[index] / 1000.0 if index >= 0 and index < list.size() else 0.0


## `ms` in seconds.
static func sec(ms: int) -> float:
	return ms / 1000.0
