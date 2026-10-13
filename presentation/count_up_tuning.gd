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

@export_group("Paper pile")
## The pile starts at this x (shift - 1) pixels, at most pile_start_max_px (D4).
@export var pile_start_px_per_shift: float = 0.0
## The highest the pile starts, in pixels (D4).
@export var pile_start_max_px: float = 0.0
## Each receipt line printed in this row adds this much, up to pile_cap_px (D4).
@export var pile_px_per_line: float = 0.0
## The pile never grows past this, in pixels (D4).
@export var pile_cap_px: float = 0.0

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
## The quota ding.
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
## at 700; the print-out's lift ends at 850.
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
## The reward print-out (RewardPanel) lifts into full cards over this, from the printer feed;
## it arms once the lift has ended and the mouse is up.
@export var printout_lift_ms: int = 0

@export_group("Final receipt")
## The run's final receipt (#61, ResultsPanel) prints a line this often, from the headline down;
## a tap prints the rest at once.
@export var final_line_ms: int = 0
