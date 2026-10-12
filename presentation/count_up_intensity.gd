class_name CountUpIntensity
extends RefCounted
## How big a count-up's ending was, for what plays after the final total (#60, decision D11):
## the dessert (#61) scales its slam, pass or fail sound and shake from it. CountUp sets it from
## its plan when the total is shown. Like the plan, it never depends on the quota.

## The register rattle of the pause before the total, in pixels (0 for a normal total and
## always 0 under reduced motion).
var rattle_px: float = 0.0
## The total is large (at least the large threshold); a huge total is large too.
var is_large: bool = false
## The total is huge.
var is_huge: bool = false
## The player asked for reduced motion: no shakes.
var reduced_motion: bool = false


static func from_plan(plan: CountUpPlan) -> CountUpIntensity:
	var intensity: CountUpIntensity = CountUpIntensity.new()
	intensity.rattle_px = plan.final_rattle_px
	intensity.is_large = plan.size != CountUpPlan.Size.NORMAL
	intensity.is_huge = plan.size == CountUpPlan.Size.HUGE
	intensity.reduced_motion = plan.reduced_motion
	return intensity
