class_name MachineTuning
extends Resource
## The RECEIPT REWARDS machine's tempo (#77, build spec 4.3-4.4): every time of a visit's timeline,
## from the approved page (docs/art/mockups/machine_77_flow.html: buildTimeline, bonusTimeline) and,
## for the premium transform and the draw, mock-up premium_machine_v1.html (v0.50: dressing A,
## rarity reveal R1). They live in data/balance/machine_tempo.tres so they can be tuned without code
## changes; MachinePlan reads them and never hard-codes one. Every default is neutral (0 or empty),
## like CountUpTuning, so a script edit can never silently change the tuned values in the file.
##
## Times are in ms at 1x (the count-up's speed setting doesn't scale the machine); `_rm_ms` fields
## are the reduced-motion variants. A field that is a list holds one value per visit kind, in
## MachineVisit.Kind order: [TICKET, BONUS, STAMP_DAY], or one per rarity, in
## MachinePrize.Rarity order: [COMMON, RARE, LEGENDARY]. A missing entry reads 0.

@export_group("Ticket intro")
## The torn receipt's travel from the printer to over the machine's slot, from the dessert's
## printer feed (machine v2, Q1 = A: the camera glides to the machine meanwhile). As it is torn it
## lifts tear_lift_px and tilts tear_tilt_deg (both eased out early in the travel); it ends
## feed_fit of the slot mouth's width wide. Under reduced motion it cross-fades instead.
@export var travel_ms: int = 0
@export var tear_lift_px: float = 0.0
@export var tear_tilt_deg: float = 0.0
@export var feed_fit: float = 0.0
## The camera's glide to the machine at 2x: it starts glide_lead_ms after the printer feed and
## lasts glide_ms; the belt, the register and the baskets drop fore_drop_px out of frame meanwhile;
## the machine lights up over the glide's last lit_ramp_ms.
@export var glide_lead_ms: int = 0
@export var glide_ms: int = 0
@export var fore_drop_px: float = 0.0
@export var lit_ramp_ms: int = 0
## The BONUS stub (Q2 = 2) snaps off the receipt snap_lead_ms before the travel's end: after
## snap_delay_ms its height shrinks to 0 over snap_ms, while the ticket flies to the slot plate's
## dock over dock_flight_ms (with `rip`, snap_db softer). The dock's caption hides dock_label_ms
## after the travel's end.
@export var snap_lead_ms: int = 0
@export var snap_delay_ms: int = 0
@export var snap_ms: int = 0
@export var dock_flight_ms: int = 0
@export var dock_label_ms: int = 0
@export var snap_db: float = 0.0
## The receipt fed under the slot's clip.
@export var feed_ms: int = 0
@export var feed_rm_ms: int = 0
## "READING…", then the check line.
@export var read_ms: int = 0
## The chute keys lighting up, staggered by key_stagger_ms (one note each).
@export var lights_ms: int = 0
@export var key_stagger_ms: int = 0

@export_group("Return glide")
## After the shift's last visit the camera glides back to the next shift's planning over
## return_glide_ms while the machine dims over dim_ms; an upgrade swaps in place upgrade_after_ms
## after the glide's end.
@export var return_glide_ms: int = 0
@export var dim_ms: int = 0
@export var upgrade_after_ms: int = 0

@export_group("Reduced motion cut")
## Under reduced motion the camera cuts rm_cut_ms after the glide's start, behind a charcoal fade
## that rises to rm_fade_alpha and falls again over rm_fade_ms (the return glide cuts the same way).
@export var rm_cut_ms: int = 0
@export var rm_fade_ms: int = 0
@export var rm_fade_alpha: float = 0.0

@export_group("Bonus intro")
## The bonus ticket moves from the slot plate's dock to over the slot, then is fed under the clip.
@export var bonus_to_slot_ms: int = 0
@export var bonus_feed_ms: int = 0
## The read line after the feed, then the keys going unlit and relit by relight_stagger_ms.
@export var bonus_read_ms: int = 0
@export var bonus_lights_ms: int = 0
@export var relight_stagger_ms: int = 0
## The BONUS TICKET line from the feed's end to the chute wait.
@export var again_ms: int = 0

@export_group("Chute press")
## The pressed chute settles this long after CONFIRM before the draw starts, per kind.
@export var odds_close_ms: PackedInt32Array = PackedInt32Array()
## The push bar (v0.53; CONFIRM › on the display until then) stays down this long before the
## chute is confirmed (#77 machine v2).
@export var confirm_down_ms: int = 0
@export_group("Premium transform")
## A Normal machine turns PREMIUM (mock-up premium_machine_v1.html, dressing A) after a BOOSTED
## visit's receipt is read: the sign, the bulbs, the trim, the gold parts and the keys change over
## premium_ms (reduced motion: a cut after premium_rm_ms), then the keys light.
@export var premium_ms: int = 0
@export var premium_rm_ms: int = 0
@export_group("Draw")
## The tray packs the draw (its light flickers grey, teal, gold) from the press settling to the
## draw's end, per kind; under reduced motion draw_rm_ms.
@export var draw_ms: PackedInt32Array = PackedInt32Array()
@export var draw_rm_ms: int = 0
@export_group("Reveals")
## The prize tickets fly out of the tray to the front (mock-up R1 "drop"): each flight lasts
## fly_ms (per kind; none under reduced motion), the first ticket lands first_land_ms after the
## draw's end (per kind), each next one land_lead_ms after the one before it, by the rarity of the
## ticket landing (per rarity: the LEGENDARY one a beat later); under reduced motion
## land_lead_rm_ms apart.
@export var fly_ms: PackedInt32Array = PackedInt32Array()
@export var first_land_ms: PackedInt32Array = PackedInt32Array()
@export var land_lead_ms: PackedInt32Array = PackedInt32Array()
@export var land_lead_rm_ms: int = 0
## A ticket's landing effect per rarity (COMMON's dust, RARE's shine and glow, LEGENDARY's burst
## shrinking to a glow), and its reduced-motion length.
@export var reveal_ms: PackedInt32Array = PackedInt32Array()
@export var reveal_rm_ms: PackedInt32Array = PackedInt32Array()
## The pick arms this long after the last landing effect, per kind.
@export var pick_arm_ms: PackedInt32Array = PackedInt32Array()
@export_group("Landing")
## From the pick press to the flight's start, per kind.
@export var pick_lead_flight_ms: PackedInt32Array = PackedInt32Array()
## The picked prize's flight to the cart drawer or the loyalty box, per kind, and under reduced
## motion.
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
## A BONUS visit's stamp lands (back ease, from 2.2x) over this, once its ticket is over the slot.
@export var bonus_stamp_land_ms: int = 0


## `list`[index] in seconds, 0 when the list is shorter.
static func seconds(list: PackedInt32Array, index: int) -> float:
	return list[index] / 1000.0 if index >= 0 and index < list.size() else 0.0


## `ms` in seconds.
static func sec(ms: int) -> float:
	return ms / 1000.0
