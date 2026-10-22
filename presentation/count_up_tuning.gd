class_name CountUpTuning
extends Resource
## The count-up's tuning numbers (#60, decisions D1 to D7): its note ladder, intensity, pauses,
## hit-stops, beat lengths and the long-row fit; the shift's dessert after it and the run's final
## receipt (#61). They live in data/balance/count_up.tres so they can be tuned by ear without
## code changes; CountUpPlan, CountUpDessert and ResultsPanel read them and never hard-code one.
## Every default is neutral (0), like the core definitions, so a script edit can never silently
## change the tuned values in the file. Times are in ms at speed 1 unless a field says
## otherwise; beat lengths run start to start and include the trailing gap.

@export_group("Notes")
## Notes on the ladder (D1): an 11-note pentatonic run, G4 to G6. A row with more gain beats
## spreads its climb over the ladder instead of going past the top.
@export var note_count: int = 0

@export_group("Intensity")
## The least best_so_far the intensity is measured against, in euros (D3). Copied by hand from
## reports/p42_final_report.txt (plan v0.27, greedy@sensible): the shift 1 median checkout.
@export var first_best_floor: int = 0
## A total is large only from this many euros (D4), whatever the best so far. From the same
## report.
@export var large_floor: int = 0
## A total is large from this share of the best so far (D4).
@export var large_factor: float = 0.0
## A total is huge from this share of the best so far (D4). Huge is checked first.
@export var huge_factor: float = 0.0
## The flat auto speed-up (D6), from auto_speed_from_shift on.
@export var auto_speed: float = 0.0
## The first 1-based shift that plays at auto_speed.
@export var auto_speed_from_shift: int = 0
## The count's tempo (2026-10-20, the user: the count ran a bit too fast): multiplies the auto
## speed-up and the speed setting into the speed every beat, ride, roll and bag hop runs at, so
## 0.8 plays the whole count 1.25x slower, evenly. Hit-stops, the pause before the total and the
## dessert don't follow it. 0 (the neutral default) counts as 1.
@export var count_tempo: float = 0.0
## Printer speed (D3) = min(printer_speed_max, 1 + printer_speed_per_shift x (shift - 1)
## + printer_speed_per_step x max(0, steps - printer_free_steps)).
@export var printer_speed_max: float = 0.0
## Printer speed added per shift after the first (D3).
@export var printer_speed_per_shift: float = 0.0
## Printer speed added per step past printer_free_steps (D3).
@export var printer_speed_per_step: float = 0.0
## Steps a row may have before the printer speeds up for its length (D3).
@export var printer_free_steps: int = 0
## The print sound's pitch follows the printer speed up to this (D3: min(printer speed, 1.26),
## at most +4 semitones).
@export var print_pitch_max: float = 0.0
## A payout's roll (D3) = (roll_min_ms + roll_extra_ms x min(1, payout / (roll_full_share x
## best))) / printer speed.
@export var roll_min_ms: int = 0
## Roll time added for a payout of roll_full_share of the best or more (D3).
@export var roll_extra_ms: int = 0
## The share of the best at which a payout gets the whole roll_extra_ms (D3).
@export var roll_full_share: float = 0.0
## A payout rattles (D3) when it is at least rattle_min_payout euros and at least
## rattle_min_share of the best, by min(rattle_max_px, rattle_base_px + rattle_per_best_px x
## payout / best) pixels.
@export var rattle_min_payout: int = 0
## A payout rattles only from this share of the best so far (D3).
@export var rattle_min_share: float = 0.0
## The rattle of the smallest payout that rattles, in pixels (D3).
@export var rattle_base_px: float = 0.0
## Rattle pixels added per best-so-far of payout (D3).
@export var rattle_per_best_px: float = 0.0
## The most a payout rattles before the passing-best extra, in pixels (D3).
@export var rattle_max_px: float = 0.0
## From the payout where the subtotal first passes the best so far, every payout rattles this
## much more (D3), on top of rattle_max_px.
@export var passes_best_rattle_px: float = 0.0
## From that payout on, the subtotal punches this much bigger (D3).
@export var passes_best_punch: float = 0.0

@export_group("Pause before the total")
## The held breath before a normal TOTAL line (D4), never sped up or shortened.
@export var pause_normal_ms: int = 0
## The pause before a large total (D4).
@export var pause_large_ms: int = 0
## The pause before a huge total (D4).
@export var pause_huge_ms: int = 0
## The register rattle during the pause of a large total (D4).
@export var final_rattle_large_px: float = 0.0
## The register rattle during the pause of a huge total (D4).
@export var final_rattle_huge_px: float = 0.0

@export_group("Hit-stops")
## Hit-stops are real ms (D6): never sped up by the auto speed or the speed setting.
## The first multiplier from a card on each card.
@export var hit_stop_card_stamp_ms: int = 0
## A multiplier from an upgrade (or another non-card source).
@export var hit_stop_upgrade_stamp_ms: int = 0
## A payout override (the red 0).
@export var hit_stop_denied_ms: int = 0
## The quota ding: the count holds as the quota bursts (#86 v6).
@export var hit_stop_ding_ms: int = 0
## Hit-stops whose beats start within this many ms (planned timeline at speed 1) merge into
## the first, keeping the longest.
@export var hit_stop_merge_ms: int = 0

@export_group("Beat lengths")
## Before the first beat.
@export var pre_roll_ms: int = 0
## The trailing gap inside every beat length below.
@export var gap_ms: int = 0
## A plain card's merged BASE and PAYOUT beat (D2).
@export var merged_ms: int = 0
## A plain card's merged beat when it pays nothing (D2).
@export var merged_zero_ms: int = 0
## An effect being armed (EFFECT_ARMED), with its quiet note.
@export var armed_ms: int = 0
## A BASE on a card that is not plain.
@export var base_ms: int = 0
## A bonus from another source (a COPY, another card or an upgrade): it flies in.
@export var bonus_other_ms: int = 0
## A card's own flat bonus.
@export var bonus_own_ms: int = 0
## A multiplier from a card.
@export var stamp_card_ms: int = 0
## A multiplier from an upgrade or an inspection: it flies from the loyalty-card box.
@export var stamp_upgrade_ms: int = 0
## A payout override.
@export var denied_ms: int = 0
## A PAYOUT is its roll plus gap_ms; a zero payout has no roll and lasts this long.
@export var payout_zero_ms: int = 0
## A fizzle (WASTED) on the card's own slot or from an upgrade: the grey hold.
@export var fizzle_ms: int = 0
## An Egg-style reset: a card fizzling another card's effect.
@export var fizzle_reset_ms: int = 0
## A tag added to a card (TAG_ADDED): it flies in.
@export var tag_ms: int = 0
## Two cards linked (LINKED): it flies in.
@export var link_ms: int = 0

@export_group("Long-row fit")
## A row planned longer than this is fitted in stages (D7).
@export var fit_target_ms: int = 0
## Stage 1: every beat's trailing gap shrinks from gap_ms to this.
@export var fit_gap_ms: int = 0
## Stage 2: the 2nd and later landings of one armed effect become echoes this long.
@export var echo_ms: int = 0
## Stage 3: payout rolls are cut to at most this.
@export var fit_roll_max_ms: int = 0
## Stage 4: fly-ins, tags and links run at this factor of their length.
@export var fly_in_factor: float = 0.0
## Stage 4 never makes a fly-in, tag or link shorter than this.
@export var fly_in_min_ms: int = 0
## Stage 5: a uniform speed-up of the shortenable beats, at most this factor.
@export var fit_max_factor: float = 0.0
## A fizzle's grey hold never gets shorter than this.
@export var fizzle_hold_min_ms: int = 0

@export_group("Dessert")
## The shift's dessert after the verdict (#61), in ms at speed 1 (the speed setting applies, the
## auto speed-up doesn't). A pass with no notice: the slam starts at 100 and lands at 300, the
## margin counts 300 to 500 with `pass` at 450, PAID at 520, the tear at 560 and the printer feed
## at 700, where the RECEIPT REWARDS machine opens (#77).
## From the verdict (the TOTAL line) to the slam's start.
@export var dessert_slam_delay_ms: int = 0
## The slam, from its start to its landing on the TOTAL line (`total` or `miss`, the shake).
@export var dessert_slam_ms: int = 0
## The margin line counts up for this long from the landing.
@export var dessert_margin_ms: int = 0
## `pass` or `fail` sounds this long after the landing, while the margin counts.
@export var dessert_verdict_sound_ms: int = 0
## PAID is stamped this long after the margin has counted (a pass).
@export var dessert_paid_ms: int = 0
## A passed shift with a bonus ticket to come (#77 machine v2, Q2 = 2): the gold stub prints at
## the receipt's foot over dessert_stub_ms (under reduced motion over dessert_stub_rm_ms, a slow
## grow too, never a jump), with "+1 BONUS TICKET" beside the receipt fading in over
## dessert_banner_in_ms and out over dessert_banner_out_ms once the stub has printed.
@export var dessert_stub_ms: int = 0
@export var dessert_stub_rm_ms: int = 0
@export var dessert_banner_in_ms: int = 0
@export var dessert_banner_out_ms: int = 0
## The receipt tears this long after PAID; on a miss, this long after `fail` has rung out.
@export var dessert_tear_ms: int = 0
## The next shift's notice prints this long after the tear (inside the printer feed's wait).
@export var dessert_notice_ms: int = 0
## The printer feeds (a pass ends here) this long after the tear.
@export var dessert_feed_ms: int = 0
## A miss ends this long after the tear.
@export var dessert_miss_end_ms: int = 0
## The shake as the slam lands, in pixels: a pass's and a miss's, before intensity.
@export var dessert_shake_pass_px: float = 0.0
@export var dessert_shake_miss_px: float = 0.0
## A large total shakes this share more, a huge one twice that (none under reduced motion).
@export var dessert_shake_step: float = 0.0

@export_group("Final receipt")
## The run's final receipt (#61, ResultsPanel) prints a line this often, from the headline down;
## a tap prints the rest at once.
@export var final_line_ms: int = 0

@export_group("Scan")
## The ride before each item's first beat (#86 v6): the item slides into the scanner (the row's
## first cell) while the one before it hops into the bag. It counts in the plan's length, is never
## shortened by the fit and runs at the count's speed like a beat. None for item 0 when it already
## stands in the scanner's cell.
@export var ride_ms: int = 0
## The last item's hop into the bag after the last beat: it overlaps the pause before the TOTAL
## line and adds nothing to the count.
@export var bag_ms: int = 0

@export_group("Monitor juice")
## The count's monitor (the monitor juice, mock-up monitor_juice_v2.html, K1 "one tank", FILL A,
## WIN B, FONT C; GoldTank and TankBurst). Times here are real seconds: the gold, the punch and
## the win never follow the count's speed or its hit-stops.
## The gold's level is the shown total / the quota (0 at the bottom of the group's ink, 1 at its
## top), held under tank_hold until the payout that meets the quota lands; then its target is
## tank_overfill (over the brim), the level reaching at most tank_overfill_max. Before the
## quota the spring may pass the hold by tank_hold_slack.
@export var tank_hold: float = 0.0
@export var tank_overfill: float = 0.0
@export var tank_overfill_max: float = 0.0
@export var tank_hold_slack: float = 0.0
## The level follows its target on a stiff spring (per second squared, and its damping per
## second): a little slosh, no lag you can see.
@export var tank_stiffness: float = 0.0
@export var tank_damping: float = 0.0
## The surface's waves (px), and a landing's kick added to them (px), dying away at
## tank_kick_decay per second.
@export var tank_wave_px: float = 0.0
@export var tank_kick_px: float = 0.0
@export var tank_kick_decay: float = 0.0
## A landing's ripple from the group's middle both ways: tank_ripple_px deep, at
## tank_ripple_speed px per second, tank_ripple_width wide (px squared), over tank_ripple_s.
@export var tank_ripple_px: float = 0.0
@export var tank_ripple_speed: float = 0.0
@export var tank_ripple_width: float = 0.0
@export var tank_ripple_s: float = 0.0
## Droplets jumping off the surface on a landing, and on one after the quota.
@export var tank_drops: int = 0
@export var tank_drops_met: int = 0
## Bubbles in the gold, once it is over tank_bubble_from: tank_bubble_rate per second plus
## tank_bubble_rate_full more at full, rising tank_bubble_speed (px per second, from x to y) up to
## tank_bubble_rise px.
@export var tank_bubble_from: float = 0.0
@export var tank_bubble_rate: float = 0.0
@export var tank_bubble_rate_full: float = 0.0
@export var tank_bubble_speed: Vector2 = Vector2.ZERO
@export var tank_bubble_rise: float = 0.0
## FONT C's shine: a band rising up the number and the € together over shine_s as money lands;
## the total's landing sends a second one shine_second_s later. twinkles (twinkles_total on the
## total) sparkle on the group's top, twinkle_stagger_s apart, each over twinkle_s.
@export var shine_s: float = 0.0
@export var shine_second_s: float = 0.0
@export var twinkles: int = 0
@export var twinkles_total: int = 0
@export var twinkle_stagger_s: float = 0.0
@export var twinkle_s: float = 0.0
## The digits' punch (the € never moves or scales): a count punch of strength s punches them to
## min(digits_punch_max, digits_punch_base + (s - 1) x digits_punch_share), its peak (with the
## ease's overshoot) never past digits_punch_max; up over digits_punch_up_s, back over
## digits_punch_down_s.
@export var digits_punch_base: float = 0.0
@export var digits_punch_share: float = 0.0
@export var digits_punch_max: float = 0.0
@export var digits_punch_up_s: float = 0.0
@export var digits_punch_down_s: float = 0.0
## WIN B, the coin fountain, on the landing that meets the quota: coins spray out of the whole
## number and € for win_fountain_s at win_fountain_rate per second; each payout after it sprays
## after_fountain_s at after_fountain_rate, at after_fountain_power of the speed.
@export var win_fountain_s: float = 0.0
@export var win_fountain_rate: float = 0.0
@export var after_fountain_s: float = 0.0
@export var after_fountain_rate: float = 0.0
@export var after_fountain_power: float = 0.0
## The win's sparks round the monitor (after_sparks on a later payout), its gold splashes on the
## bezel (from win_splash_delay_s, for win_splash_s, at win_splash_rate per second), its shake
## (px, s) and the paper's flash (alpha, fading over win_flash_s).
@export var win_sparks: int = 0
@export var after_sparks: int = 0
@export var win_splash_delay_s: float = 0.0
@export var win_splash_s: float = 0.0
@export var win_splash_rate: float = 0.0
@export var win_shake_px: float = 0.0
@export var win_shake_s: float = 0.0
@export var win_flash: float = 0.0
@export var win_flash_s: float = 0.0
## The win's own punch of the digits (a count punch strength, as digits_punch: the mock-up's 1.6,
## so the landing that meets the quota punches them to digits_punch_max), from the scale they show.
@export var win_punch: float = 0.0
## The fountain's coins (TankBurst): their speed in art px per second sideways (x plus up to y)
## and upwards (x plus up to y); those leaving from the group's left fountain_left share go left,
## the rest right.
@export var fountain_side: Vector2 = Vector2.ZERO
@export var fountain_up: Vector2 = Vector2.ZERO
@export var fountain_left: float = 0.0
## The sunburst once met reaches sunburst_met_radius px (the monitor's), growing out to it over
## sunburst_grow_s on a back-out ease as the win pops (the mock-up's).
@export var sunburst_met_radius: float = 0.0
@export var sunburst_grow_s: float = 0.0
## FONT C's shine starts shine_below_px under the group's ink and rises shine_past_px past its top.
@export var shine_below_px: float = 0.0
@export var shine_past_px: float = 0.0


## A count punch of `strength` on the digits: digits_punch_base + (strength - 1) x
## digits_punch_share, at most digits_punch_max (`strength` itself when no cap is tuned).
func digits_punch(strength: float) -> float:
	if digits_punch_max <= 0.0:
		return strength
	return minf(digits_punch_max, digits_punch_base + (strength - 1.0) * digits_punch_share)
