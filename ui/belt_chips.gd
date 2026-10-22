class_name BeltChips
extends RefCounted
## The belt items' corner marks and paid chips (#80, step 7; mock-up B2; #75's effect chips
## before it), retired from the count by #86 v6 (mock-up count_up_86_v6_scan): planning shows
## #71's stickers (PlanningEffects), the count fires them as their steps land (BeltRide) while
## the receipt and the monitor show the pay, and a resumed checkout's belt is empty, its items in
## the bag. What is left is the shift screen's word for it: show_all takes any mark and paid chip
## off the belt items, in planning and on a resumed checkout alike. Nothing here scores.


## Takes every mark and paid chip off the belt items `views` (any view not an item, or freed, is
## left alone).
func show_all(views: Array[CardView]) -> void:
	for view: CardView in views:
		if not is_instance_valid(view):
			continue
		var item: ItemView = view as ItemView
		if item != null:
			item.clear_mark()
			item.hide_badge()
