class_name ExpiryTwist
extends GradeTwist
## Expiry dates (#182 grade 3, v1.49): a coupon the machine gives leaves the deck
## `coupon_shifts` shifts after it was taken, and at each week's end `items_min` to `items_max`
## of the products taken that week (the run's RNG) get a BEST BEFORE sticker and leave
## `item_shifts` shifts after they were taken (GradeRules). The starting deck never expires.

## Shifts a machine coupon plays before it leaves (0: never).
@export var coupon_shifts: int = 0
## Shifts a BEST BEFORE product plays after it was taken (0: no product expires).
@export var item_shifts: int = 0
## How many of a week's new products get the sticker, at least and at most (fewer when the
## week brought fewer).
@export var items_min: int = 0
@export var items_max: int = 0
