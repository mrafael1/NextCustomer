class_name QuotaLaps
extends RefCounted
## The quota tube's laps (QuotaMeter; the user's feedback of 2026-11-03, the colours of mock-up
## shift_scene_polish_v4.html, A1): display arithmetic and colours only. The first lap is full
## exactly at the quota; once it is met the tube never re-scales: lap N runs from (N - 1) to N
## times the quota and refills the tube from its foot in its own colour (LAP_RAMPS) over a full
## tube of the lap before's (the met green behind lap 2). The lap lamp over the tube names
## the laps made in the newest full lap's colour (backdrop_ramp, lamp_ink).

## The first lap past the quota.
const FIRST_LAP := 2
## The laps past the quota (lap 2 on), the week medals' metals (2026-11-06, mock-up
## docs/art/mockups/week_medals.html section 3): lap 2 (×1 to ×2) silver, lap 3 (×2 to ×3) gold,
## then from lap 4 on (TWINKLE_LAP) a brighter gold, with twinkles (QuotaMeter), each over a full
## tube of the plain gold. Lit, mid and dark columns (the silver's body a mid steel, so it reads
## as metal, not an empty tube). None shares a colour with the first lap's short or near ramps
## (QuotaMeter.SHORT_RAMP, NEAR_RAMP); each body sits at least HUE_GAP degrees from theirs, or
## VALUE_GAP of value (HSV) from a warning body near it in hue (VALUE_SEPARATED: the golds, brighter
## than the near tube's brass), or, a grey, CHROMA_GAP less saturated than them (the silver), so a
## big shift never reads as short.
const LAP_RAMPS: Array[Array] = [
	[Palette.STEEL_HIGHLIGHT, Palette.STEEL_LIGHT, Palette.STEEL],
	[Palette.MUSTARD_PALE, Palette.GOLD, Palette.MUSTARD_DARK],
	[Palette.PAPER, Palette.MUSTARD_PALE, Palette.GOLD],
]
## The lap from which the colour stays the brighter gold, and twinkles.
const TWINKLE_LAP := 4
## The hue gap (degrees) the lap bodies keep from the short and near bodies.
const HUE_GAP := 18.0
## The lap bodies told from a warning body of near hue by value instead: the golds (brighter than
## the near tube's brass).
const VALUE_SEPARATED: Array[Color] = [Palette.GOLD, Palette.MUSTARD_PALE]
const VALUE_GAP := 0.2
## A lap body this much less saturated than every warning body reads apart from them however near
## its hue (the silver).
const CHROMA_GAP := 0.3
## The lap lamp's glyphs are ink on a lap colour this light (its body's luminance) or lighter,
## paper on a darker one.
const LAMP_INK_LUMINANCE := 0.5


## The lap `amount_shown` is in against `quota`: 1 while short or not `met`, else the whole
## multiples made plus one (lap 2 from the quota, lap 3 from twice it).
static func lap_for(amount_shown: int, quota: int, met: bool) -> int:
	if not met or quota <= 0 or amount_shown < quota:
		return 1
	return lap_of(amount_shown, quota) + 1


## Lap `lap`'s fill for `amount_shown` against `quota` (0 to 1): the first lap's is the share of
## the quota, lap N's runs from (N - 1) to N times the quota; full for a quota of 0.
static func lap_fill(amount_shown: float, quota: int, lap: int) -> float:
	if quota <= 0:
		return 1.0
	return clampf((amount_shown - (maxi(lap, 1) - 1) * quota) / quota, 0.0, 1.0)


## The columns (lit, mid, dark) of lap `lap` (FIRST_LAP or more): silver, gold, then the brighter
## gold from TWINKLE_LAP on.
static func lap_ramp(lap: int) -> Array[Color]:
	var colours: Array[Color] = []
	colours.assign(LAP_RAMPS[clampi(lap - FIRST_LAP, 0, LAP_RAMPS.size() - 1)])
	return colours


## The full tube behind lap `lap` (FIRST_LAP or more): the met first lap's green behind lap 2,
## the silver behind lap 3, the plain gold behind every brighter gold lap (so its front shows).
static func backdrop_ramp(lap: int) -> Array[Color]:
	if lap <= FIRST_LAP:
		return QuotaMeter.MET_RAMP
	return lap_ramp(mini(lap - 1, TWINKLE_LAP - 1))


## The lamp's glyph colour on `ramp`: ink on a light body, paper on a dark one.
static func lamp_ink(ramp: Array[Color]) -> Color:
	return Palette.INK if ramp[1].get_luminance() >= LAMP_INK_LUMINANCE else Palette.PAPER


## The laps `amount_shown` has made of `quota` (whole multiples), 0 for a quota of 0.
static func lap_of(amount_shown: int, quota: int) -> int:
	if quota <= 0:
		return 0
	return floori(float(maxi(amount_shown, 0)) / quota)
