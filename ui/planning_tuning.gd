class_name PlanningTuning
extends Resource
## The planning effects' tuning (#71, mock-up h1, H1_BUILD_SPEC.md section 3.4): when a boosted
## item's halo gains its 2nd and 3rd ring, and the hover's fades and the stickers' motion. It
## lives in data/balance/planning.tres so it can be tuned by feel without code changes;
## PlanningModel and PlanningEffects read it and never hard-code it. The defaults are neutral (0
## or empty), like ScanTuning's, so a script edit can never silently change the tuned values in
## the file. Geometry stays in code constants, as everywhere else in ui/.

## A boosted item's halo: 1 ring for any boost, a 2nd once its pay is at least `halo_ratios[0]`
## times its base (at least 1), a 3rd at `halo_ratios[1]` times. Display only: the pay and the
## base come from the score's steps.
@export var halo_ratios: PackedInt32Array = PackedInt32Array()

## Seconds the hover takes to fade the unrelated items, tickets and strips (0 under reduced
## motion).
@export var focus_fade_s: float = 0.0

## Seconds the pointer may be off a hovered giver before its focus ends (so moving between two
## related items doesn't flicker).
@export var unfocus_delay_s: float = 0.0

## The mix highlight's calm grey (#105 piece 3, mock-up readability v3's saturate(.2)
## brightness(.78)) on an item unrelated to the hovered item, glyph or held card: its brightness and
## the share of its colour it keeps (ArtStyle.set_mix_grey), faded in over mix_fade_s seconds (0
## under reduced motion).
@export var mix_brightness: float = 0.0
@export var mix_saturation: float = 0.0
@export var mix_fade_s: float = 0.0

## The pay tag's alpha of an item unrelated to the hovered one.
@export var dim_ticket_alpha: float = 0.0

## A rail strip's alpha while an unrelated item is hovered.
@export var dim_strip_alpha: float = 0.0

## Seconds of each frame of a new sticker's squash (the slap).
@export var slap_frame_s: float = 0.0

## Seconds between two rings of a boosted item's halo stepping out.
@export var halo_step_s: float = 0.0

@export_group("Bonus notice")
## #77 machine v2: on an inspected shift whose pass earns the bonus ticket, planning's notice
## pulses once as the shift opens (none under reduced motion): the top bar's chip for
## notice_pulse_ms, scaling by 1 + notice_pulse_scale x sin(notice_pulse_rate x seconds).
## BonusNotice reads them.
@export var notice_pulse_ms: int = 0
@export var notice_pulse_scale: float = 0.0
@export var notice_pulse_rate: float = 0.0

@export_group("Upgrade swap")
## #77 machine v2: the shift after an UPGRADES pick, each upgraded copy on screen swaps in place
## (UpgradeSwap): a white flash masked to its sprite (swap_flash_alpha fading to 0 over
## swap_flash_ms), a gold sunburst behind it (swap_shine_px across, turning swap_shine_turn_deg_s,
## growing from swap_shine_from to swap_shine_to over swap_shine_grow_ms, its alpha a sine bump
## of swap_shine_alpha over swap_shine_ms), a pop to swap_pop_scale and back over swap_pop_ms, and
## the gold "BANANA › GOLDEN" tag: in from swap_tag_delay_ms over swap_tag_in_ms, rising
## swap_tag_rise_px over swap_tag_rise_ms, held swap_tag_hold_ms, then out over swap_tag_out_ms.
## Several copies start swap_stagger_ms apart. Reduced motion: the tag only, at once.
@export var swap_flash_ms: int = 0
@export var swap_flash_alpha: float = 0.0
@export var swap_shine_ms: int = 0
@export var swap_shine_px: float = 0.0
@export var swap_shine_turn_deg_s: float = 0.0
@export var swap_shine_grow_ms: int = 0
@export var swap_shine_from: float = 0.0
@export var swap_shine_to: float = 0.0
@export var swap_shine_alpha: float = 0.0
@export var swap_pop_ms: int = 0
@export var swap_pop_scale: float = 0.0
@export var swap_tag_delay_ms: int = 0
@export var swap_tag_in_ms: int = 0
@export var swap_tag_rise_ms: int = 0
@export var swap_tag_rise_px: float = 0.0
@export var swap_tag_hold_ms: int = 0
@export var swap_tag_out_ms: int = 0
@export var swap_stagger_ms: int = 0
