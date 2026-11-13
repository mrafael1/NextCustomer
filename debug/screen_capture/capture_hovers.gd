class_name CaptureHovers
extends RefCounted
## The screen capture's hover tips (the hover tips revamp, design B; captures in
## docs/art/mockups/hover_tips_game/), kept out of ScreenCapture so it stays under gdlint's file
## length. `--hover=<what>[,shift]` shows the tip of one target on the fixed shift, at full size
## (its pop skipped), and the file name gets hover_<what>_; `,shift` keeps it as Shift does (its
## footer then says SHIFT KEPT). <what> is one of:
## - perk<n>: loyalty stamp n's (from 0) on the top bar's loyalty chip;
## - loyalty: the LOYALTY word's;
## - silver, gold: the week's medals' on the cash drawer;
## - week: the register's week glass;
## - chute<n>: the machine's chute key n (with --machine=);
## - window<n>: price window n's (from 0, the belt's tickets in order);
## - menu: the top bar's Menu key.

const ARGUMENT := "--hover="


## Shows the tip `arguments` ask for on `screen`; returns the file name's part ("" for none).
static func apply(screen: ShiftScreen, arguments: PackedStringArray) -> String:
	var spec: String = ""
	for argument: String in arguments:
		if argument.begins_with(ARGUMENT):
			spec = argument.trim_prefix(ARGUMENT)
	if spec.is_empty():
		return ""
	var parts: PackedStringArray = spec.split(",")
	var kept: bool = parts.size() > 1 and parts[1] == "shift"
	# Once now, and again after the containers have laid the targets out.
	show(screen, parts[0], kept)
	screen.get_tree().process_frame.connect(
		func() -> void: show(screen, parts[0], kept), CONNECT_ONE_SHOT
	)
	return "hover_%s_" % spec.replace(",", "_")


## Shows the tip of the target `what` names (kept as Shift does when `kept`), at full size.
static func show(screen: ShiftScreen, what: String, kept: bool) -> void:
	var target: TipTarget = find(screen, what)
	if target == null:
		push_warning("CaptureHovers: no target for %s" % what)
		return
	var tips: GlyphTips = screen._glyph_tips
	tips.hide_tip()
	tips.point_at(target.get_global_rect().get_center())
	tips.show_tip(target)
	if kept:
		tips.keep()
	if tips._pop != null:
		tips._pop.kill()
	tips.tip().scale = Vector2.ONE
	for box: TipCard in tips.boxes():
		box.scale = Vector2.ONE


## The target `what` names on `screen` (see the class comment), or null.
static func find(screen: ShiftScreen, what: String) -> TipTarget:
	if what.begins_with("perk"):
		return _cover(screen._loyalty_card.box(what.trim_prefix("perk").to_int()))
	if what == "loyalty":
		for node: Node in screen._loyalty_card.find_children("Tip", "TipTarget", true, false):
			if node.get_parent() is Label:
				return node as TipTarget
	if what == "silver" or what == "gold":
		return screen._stage.medal_case.tip_target(what == "gold")
	if what == "week":
		return _cover(screen._stage.week_glass)
	if what == "menu":
		return _first(screen, "TopBar", "Tip")
	if what.begins_with("chute"):
		return _first(screen, "ChuteKey%d" % what.trim_prefix("chute").to_int(), "Tip")
	if what.begins_with("window"):
		var windows: Array[Node] = screen.find_children("PriceWindow", "PriceWindow", true, false)
		var index: int = what.trim_prefix("window").to_int()
		return windows[index] as TipTarget if index < windows.size() else null
	return null


static func _cover(control: Control) -> TipTarget:
	if control == null:
		return null
	return control.get_node_or_null(NodePath(TipTarget.COVER_NAME)) as TipTarget


static func _first(screen: Node, holder: String, child: String) -> TipTarget:
	for node: Node in screen.find_children(holder, "", true, false):
		var found: Array[Node] = node.find_children(child, "TipTarget", true, false)
		if not found.is_empty():
			return found[0] as TipTarget
	return null
