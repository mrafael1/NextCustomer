class_name CountTotalTuning
extends Resource
## The monitor's total count-up tuning (#105 piece 2, mock-up readability_v3.html, monitor b of
## readability_v2.html): how each landing rolls the total in whole euros, how hard it punches, its
## sparks and flying chips, the ladder, the item column's motion, the SPEND MET climax and the rail
## light. It lives in data/balance/count_total.tres, beside count_up.tres, so it can be tuned by eye
## without code changes; CountUpPlan, CountUp and the monitor's parts read it and never hard-code
## one. Every default is neutral (0), like CountUpTuning's, so a script edit can
## never silently change the tuned values in the file. Beat times are in ms at speed 1 (they follow
## the count's speed, taps, holds and hit-stops); the motion's times are in seconds of the count's
## clock unless a field says real time.

@export_group("Landings")
## A landing's amount flies from the item column to the total over this, from its beat's start.
@export var landing_fly_ms: int = 0
## Landing beats last at least this (start to start), so one item's landings stand 0.3 s apart.
@export var landing_gap_ms: int = 0
## The long-row fit's last stage may shorten a landing beat down to this, never further.
@export var fit_landing_gap_ms: int = 0
## A landing adds its amount in at most this many whole-euro ticks, tick_gap_ms apart, each one
## a tick sound at tick_db.
@export var ticks_per_landing: int = 0
@export var tick_gap_ms: int = 0
@export var tick_db: float = 0.0

@export_group("Number")
## Only the digits that change roll, over this (s): the old one up and out, the new one up in.
@export var digit_roll_s: float = 0.0
## The number's font sizes, largest first: the first whose group for the count's final total,
## punched to punch_mul, fits the checkout column.
@export var number_sizes: PackedInt32Array = PackedInt32Array()
## A digit's cell height (px) and the gap between the digits and the €.
@export var number_cell_h: float = 0.0
@export var euro_gap: float = 0.0

@export_group("Punch")
## The number's punch at a landing, by its kind (base, +N, ×), about the group's centre, easing
## back over punch_s; a × landing also flashes (brightness flash_mul for flash_s); a +N or ×
## landing runs the shine over the number in shine_s.
@export var punch_base: float = 0.0
@export var punch_add: float = 0.0
@export var punch_mul: float = 0.0
@export var punch_s: float = 0.0
@export var flash_mul: float = 0.0
@export var flash_s: float = 0.0
@export var shine_s: float = 0.0

@export_group("Sparks")
## Sparks out of the number's sides at a landing, by its kind; they fly spark_reach px out over
## spark_out_s, last spark_s and turn into dots from spark_dot_from_s.
@export var sparks_base: int = 0
@export var sparks_add: int = 0
@export var sparks_mul: int = 0
@export var spark_reach: float = 0.0
@export var spark_out_s: float = 0.0
@export var spark_s: float = 0.0
@export var spark_dot_from_s: float = 0.0

@export_group("Multiplier landing")
## A × landing's gold corners round the number (white for corners_white_s, growing corners_grow
## px, gone at corners_s) and its two coins (coin_s).
@export var corners_s: float = 0.0
@export var corners_white_s: float = 0.0
@export var corners_grow: float = 0.0
@export var coin_s: float = 0.0

@export_group("Status")
## The gain box ("×2 → +5€") shows for gain_box_s after a × landing, popping from gain_box_pop.
@export var gain_box_s: float = 0.0
@export var gain_box_pop: float = 0.0
## From near_share of the quota the to-go line turns mustard and pulses by near_pulse every
## near_pulse_s (real time).
@export var near_share: float = 0.0
@export var near_pulse: float = 0.0
@export var near_pulse_s: float = 0.0

@export_group("Chips")
## A flying amount dissolves from chip_dissolve_from of its flight; a ×'s chip flips into its gain
## from mul_flip_from over mul_flip_s (shares of the flight). WASTED's grey €0 drops for
## waste_drop_s, fading from waste_fade_from_s, falling at waste_gravity px/s² and turning
## waste_spin degrees per second.
@export var chip_dissolve_from: float = 0.0
@export var mul_flip_from: float = 0.0
@export var mul_flip_s: float = 0.0
@export var waste_drop_s: float = 0.0
@export var waste_fade_from_s: float = 0.0
@export var waste_gravity: float = 0.0
@export var waste_spin: float = 0.0

@export_group("Ladder")
## The ladder's lamps (one per landing, an octave brighter after each round), the newest white for
## lamp_flash_s; WASTED flickers the next lamp tomato every waste_flicker_s for waste_flicker_for_s.
@export var ladder_lamps: int = 0
@export var lamp_flash_s: float = 0.0
@export var waste_flicker_s: float = 0.0
@export var waste_flicker_for_s: float = 0.0

@export_group("Item column")
## The price punches to item_price_punch and back over item_price_punch_s when its value changes;
## the count's step line fades in over step_fade_s; a scan's parts fade in over part_fade_s at
## part_delays (name, price, effect, rule, first step) and each later step part_step_delay later.
@export var item_price_punch: float = 0.0
@export var item_price_punch_s: float = 0.0
@export var step_fade_s: float = 0.0
@export var part_fade_s: float = 0.0
@export var part_delays: PackedFloat32Array = PackedFloat32Array()
@export var part_step_delay: float = 0.0
## Planning's step lines too many for the compact layout go on pages (Checkout Rhythm v3.1): the
## next page shows every page_interval_s (0: no turning by itself), the pages crossfading over
## page_fade_s (0, or reduced motion: at once).
@export var page_interval_s: float = 0.0
@export var page_fade_s: float = 0.0
## A bonus or multiplier beat in the count (v3.1, the mock-up's doBeat): its monitor line shows
## at step_line_at of the beat's length and its value lands on the item no earlier than
## step_value_at of the beat's motion (the count's clock; reduced motion: the line at once).
@export var step_line_at: float = 0.0
@export var step_value_at: float = 0.0

@export_group("Climax")
## SPEND MET's takeover of the whole screen (real time, sped up only by a tap or a hold): the
## number grows from climax_from to climax_over over climax_in_s, settles to 1 by climax_settle_s,
## and from climax_hold_s shrinks over climax_out_s to climax_end_scale into the column; the stamp
## shows from climax_stamp_at, the tab from climax_tab_at, the shine runs between climax_shine's
## two times, climax_coins coins erupt and the sunburst turns climax_spin degrees per second.
@export var climax_in_s: float = 0.0
@export var climax_settle_s: float = 0.0
@export var climax_from: float = 0.0
@export var climax_over: float = 0.0
@export var climax_hold_s: float = 0.0
@export var climax_out_s: float = 0.0
@export var climax_end_scale: float = 0.0
@export var climax_coins: int = 0
@export var climax_number_size: int = 0
@export var climax_stamp_at: float = 0.0
@export var climax_tab_at: float = 0.0
@export var climax_shine: Vector2 = Vector2.ZERO
@export var climax_spin: float = 0.0
## The small sunburst behind the number once met turns this many degrees per second.
@export var met_sun_spin: float = 0.0

@export_group("Rail light")
## A giver's effect lights the rail gold from its ticket to its target's over rail_run_s, holds to
## rail_hold_s and fades over rail_fade_s (the count's clock).
@export var rail_run_s: float = 0.0
@export var rail_hold_s: float = 0.0
@export var rail_fade_s: float = 0.0
