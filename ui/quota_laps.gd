class_name QuotaLaps
extends RefCounted
## The quota tube's laps (QuotaMeter; the user's feedback of 2026-11-03): display arithmetic and
## colours only. The first lap is full exactly at the quota; once it is met the tube never
## re-scales: lap N runs from (N - 1) to N times the quota and refills the tube from its foot in
## its own colour (LAP_RAMPS, cycling) over a full tube of the lap before's (the met green
## behind lap 2).

## The first lap past the quota.
const FIRST_LAP := 2
## The laps past the quota (lap 2 on), cycling: gold, orange (the palette's wood: it has no pure
## orange, and its coral is the short tube's red), velvet (its magenta) and teal glass (its
## violet stand-in: it has none). Lit, mid and dark columns; no colour of the short tube's.
const LAP_RAMPS: Array[Array] = [
	[Palette.MUSTARD_PALE, Palette.GOLD, Palette.MUSTARD],
	[Palette.WOOD_PALE, Palette.WOOD_LIGHT, Palette.WOOD],
	[Palette.VELVET_SHEEN, Palette.VELVET, Palette.VELVET_DARK],
	[Palette.GLASS, Palette.TEAL_BRIGHT, Palette.TEAL_SHADE],
]


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


## The columns (lit, mid, dark) of lap `lap` (FIRST_LAP or more): LAP_RAMPS, cycling.
static func lap_ramp(lap: int) -> Array[Color]:
	var colours: Array[Color] = []
	colours.assign(LAP_RAMPS[posmod(lap - FIRST_LAP, LAP_RAMPS.size())])
	return colours


## The full tube behind lap `lap` (FIRST_LAP or more): the met first lap's green behind lap 2,
## the lap before's colour behind the others.
static func backdrop_ramp(lap: int) -> Array[Color]:
	return QuotaMeter.MET_RAMP if lap <= FIRST_LAP else lap_ramp(lap - 1)


## The laps `amount_shown` has made of `quota` (whole multiples), 0 for a quota of 0.
static func lap_of(amount_shown: int, quota: int) -> int:
	if quota <= 0:
		return 0
	return floori(float(maxi(amount_shown, 0)) / quota)
