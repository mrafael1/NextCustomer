class_name PrizeTicket
extends Control
## One prize ticket (v0.50, mock-up premium_machine_v1.html; R1 "drop", approved): ticket i holds
## reveal i. It flies out of the tray to its place in the row over the store (PrizeRow.card_rect;
## view.plan.ticket_flight: a back ease, from 0.45x at the tray's mouth) and lands face up at its
## reveal (reveal_at), where its rarity's effect plays:
## - COMMON: a clean drop, a 2 px bump and a puff of dust;
## - RARE: a teal glow ring round it, one hard 3 px shine band across it, four sparkles (and a
##   two-note chime, MachineSounds);
## - LEGENDARY: it lands a beat later (the plan), a white flash, a dithered sunburst behind it
##   (presentation/dither_burst.gdshader) that grows, then shrinks to a small glow within about a
##   second, coins, orbiting sparkles, a gold pulsing ring, a shine, the scene's short shake
##   (MachineLayers) and a sting.
## The glow and the sunburst stand behind every ticket of the row (z order), the sparkles and coins
## in front. Its rarity shows by its tab (RarityTab: COMMON / RARE! / LEGENDARY!!), its pips (one
## dot, two diamonds, three stars, drawn shapes) and its effect, never by colour alone. Under
## reduced motion it appears in place at its reveal, its burst still and its sparkles held.
##
## The face (paper, its rarity's 2 px edge; the relook's compact 168x248 ticket in v0.86, mock-up
## machine_relook.html V2) holds the art box (PrizeArt: the real sprite, the coupon slip, a
## LOYALTY punch card, an upgrade's item at its new tier) with the pips at its top left and a NEW
## ITEM's price window at its top right, a band in hard pixel capitals ("NEW ITEM", "COUPON",
## "LOYALTY STAMP", a perk's "LEVEL UP · LV 2", "UPGRADE"), the prize's name (in hard pixel lines,
## up to NAME_LINES; a name too long for them in bold Atkinson) and its rule (#105: an item's long
## rule text at the first of RULE_SIZES that shows it uncut in the room left, else cut there: the
## popup has it whole); a LOYALTY prize's win strip runs straight along its foot. Resting the
## pointer on it (hovered) opens the scan popup with the whole effect (v0.53, PrizePopup). A
## click picks it once the machine has armed; after the pick the picked ticket lifts and flies off
## (MachineFlyer takes it), the others fall away, and a bin drops them all. frame(t) reads only
## view.plan, t, view.landing and view.idle_time.

signal clicked(index: int)
## The pointer rests on the ticket, or left it (the view opens or closes its popup).
signal hovered(index: int)
signal unhovered(index: int)

const SIZE := Vector2(168, 248)
const RARITY_TEXTS: Array[String] = RarityTab.TEXTS
const EDGES: Array[Color] = [Palette.GREY_LIGHT, Palette.TEAL_BRIGHT, Palette.GOLD]
const PIP_INKS: Array[Color] = [Palette.GREY, Palette.TEAL, Palette.BRASS_DARK]
const TIER_WORDS: Array[String] = ["PLAIN", "BIG", "GOLDEN"]
## The face (the relook, v0.86): the art box, the band (hard pixel capitals), the name (hard
## pixel lines from NAME_TOP, NAME_PITCH apart; a name too long for NAME_LINES of them in bold
## Atkinson NAME_SIZE) and the rule (bold Atkinson, the first RULE_SIZES size that shows it in the
## room left over the win strip or the face's foot, else the smallest, cut: the popup has it all).
const ART_RECT := Rect2(8, 8, 152, 104)
const BAND_RECT := Rect2(4, 114, 160, 22)
const NAME_TOP := 142.0
const NAME_SIZE := 15
const NAME_PITCH := 18.0
const NAME_WIDTH := 152.0
const NAME_LINES := 2
const RULE_GAP := 6.0
const RULE_SIZES: Array[int] = [12, 11, 10]
## Each RULE_SIZES size's line pitch.
const RULE_PITCHES: Array[float] = [14.0, 13.0, 12.0]
const RULE_WIDTH := 152.0
## The rule's foot without a win strip, and its gap over one.
const RULE_BOTTOM := SIZE.y - 8.0
const RULE_STRIP_GAP := 4.0
const BOLD_WEIGHT := 800
## The extra height of a pitched box, so rounding never drops its last line.
const PITCH_SLACK := 1.0
const RULE_WEIGHT := 600
## The pips (5x5 art px each, 1 apart) at the art box's top left.
const PIP_GRIDS: Array[String] = [
	".xxx.xxxxxxxxxxxxxxx.xxx.",
	"..x...xxx.xxxxx.xxx...x..",
	"..x..xxxxx.xxx..x.x.x...x",
]
const PIP_LEFT := 14.0
const PIP_TOP := 14.0
const PIP_PIXEL := 2.0
## A NEW ITEM's price window at the art box's top right (the band no longer carries the price).
const PRICE_RIGHT := 154.0
const PRICE_TOP := 12.0
const PRICE_PAD := 4.0
## The tab's middle above the ticket.
const TAB_MIDDLE := Vector2(84, -10)
## The flight: from this scale at the tray's mouth.
const FLY_SCALE := 0.45
## COMMON's bump and dust, RARE's and LEGENDARY's effect times (seconds after landing).
const BUMP := 4.0
const BUMP_S := 0.12
const DUST_S := 0.4
const RARE_SHINE: Array[float] = [0.1, 0.5]
const LEGEND_SHINE: Array[float] = [0.15, 0.55]
const FLASH_S := 0.09
const FLASH_ALPHA := 0.9
## The sunburst: its full radius, its growth, hold and shrink (to GLOW_SHARE of it at GLOW_ALPHA).
const BURST_RADIUS := 220.0
const BURST_GROW := 0.3
const BURST_HOLD := 0.55
const BURST_SHRINK := 1.1
const GLOW_SHARE := 0.28
const GLOW_ALPHA := 0.5
const BURST_SPIN := 0.5
const BURST_SHADER := preload("res://presentation/dither_burst.gdshader")
const COINS := 16
const COIN_SEED := 31
const COIN_POWER := 0.85
const ORBIT_SPARKLES := 8
## The pick and the bin: the picked ticket lifts, the others fall away, a bin drops them all.
const PICK_LIFT := 10.0
const FALL := 24.0
const FALL_S := 0.3
## Doomed (the SKIP bin hovered): the shake's size and rates, and the shred mark's strips (their
## pitch and width) and cross.
const SHAKE := Vector2(2, 1)
const SHAKE_RATE := Vector2(55, 47)
const SHRED_PITCH := 24.0
const SHRED_WIDTH := 2.0
const SHRED_ALPHA := 0.55
const CROSS_SIZE := 44.0
const CROSS_WIDTH := 8.0
## The win strip (#108 section 4a; straight inside the face's foot in the relook, v0.86, as the
## mock-up draws it): a row per row of the run, the last row and, from shift 2, the best row this
## run, each a small "last row" / "best row" label left and its amount right in hard pixel lettering
## (green), or WASTED in tomato when it would have won nothing. WIN_LABELS are the rows' names in
## win_texts; the labels print them in lower case.
const WIN_LABELS: Array[String] = ["LAST ROW", "BEST ROW"]
const WIN_LABEL_SIZE := 12
const WIN_LABEL_WEIGHT := 700
## A row's height (an ink rule, then the fill), the strip's inset from the face's sides and foot,
## and the words' inset inside it.
const WIN_ROW := 18.0
const WIN_RULE := 2.0
const WIN_INSET := 4.0
const WIN_FOOT := 4.0
const WIN_PAD := 4.0

var index: int = 0
var prize: MachinePrize
## The SKIP bin is hovered (SkipBin): it shakes under a shred mark (before any landing).
var doomed: bool = false
## The machine this part belongs to (setup(), build spec 4.2).
var view: RewardMachineView
var tab: RarityTab
var art: PrizeArt
## Where it lands (machine coordinates) and where it leaves the tray from (its top-left at 1x).
var rest: Vector2 = Vector2.ZERO
var launch: Vector2 = Vector2.ZERO
var _preview: MachinePreview
var _card: Control
var _fx_back: Control
var _fx_front: Control
var _shred: Control
var _burst: ColorRect
var _band: MachineLine
## The name: its hard pixel lines (a holder of MachineLines) or, too long for them, a bold Label.
var _name: Control
var _name_text: String = ""
var _name_lines: int = 1
## A NEW ITEM's price in its window (null: none).
var _price: MachineLine
var _rule: Label
## What the prize would have won on the run's rows (PrizeWin), or null; its sticker.
var _win: PrizeWin
var _win_sticker: Control
var _win_texts: PackedStringArray = PackedStringArray()
## Seconds since it landed face up (below 0: not yet), and the idle time, for the effects.
var _te: float = -1.0
var _idle: float = 0.0
var _rm: bool = false


func _init(
	ticket_index: int, ticket_prize: MachinePrize, preview: MachinePreview, run: RunState
) -> void:
	index = ticket_index
	prize = ticket_prize
	_preview = preview
	name = "PrizeTicket%d" % ticket_index
	size = SIZE
	pivot_offset = Vector2(SIZE.x / 2.0, SIZE.y)
	mouse_filter = Control.MOUSE_FILTER_STOP
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	mouse_entered.connect(func() -> void: hovered.emit(index))
	mouse_exited.connect(func() -> void: unhovered.emit(index))
	visible = false
	# The tickets stand a z step up, their back effects a step down again: every ticket's glow and
	# sunburst draw behind all the tickets' faces, never over a neighbour's card.
	z_index = 1
	_fx_back = _layer("FxBack")
	_fx_back.z_index = -1
	_fx_back.draw.connect(_draw_back)
	_burst = ColorRect.new()
	_burst.name = "Burst"
	_burst.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_burst.size = Vector2.ONE * BURST_RADIUS * 2.0
	_burst.position = SIZE / 2.0 - _burst.size / 2.0
	var burst_look: ShaderMaterial = ShaderMaterial.new()
	burst_look.shader = BURST_SHADER
	burst_look.set_shader_parameter("rect_size", _burst.size)
	burst_look.set_shader_parameter("outer_colour", Palette.GOLD)
	burst_look.set_shader_parameter("middle_colour", Palette.MUSTARD_LIGHT)
	burst_look.set_shader_parameter("core_colour", Palette.MUSTARD_PALE)
	_burst.material = burst_look
	_burst.visible = false
	_fx_back.add_child(_burst)
	_card = _layer("Card")
	_card.draw.connect(_draw_card)
	art = PrizeArt.new(prize, preview)
	art.position = ART_RECT.position
	_card.add_child(art)
	_win = PrizeWin.of(run, preview)
	_add_texts(run)
	if _win != null:
		_add_win()
	var chip: Control = _layer("Chip", _card)
	chip.draw.connect(_draw_chip.bind(chip))
	_add_price()
	_fx_front = _layer("FxFront")
	_fx_front.draw.connect(_draw_front)
	_shred = _layer("Shred")
	_shred.draw.connect(_draw_shred)
	_shred.visible = false
	tab = RarityTab.new(prize.rarity)
	tab.position = MachineArt.snap_point(TAB_MIDDLE - tab.size / 2.0)
	add_child(tab)


## The band's text: "NEW ITEM" (its price, a BIG or GOLDEN item's own, in the price window),
## "COUPON", "LOYALTY STAMP", a perk's level-up "LEVEL UP · LV 2" (#108), or "UPGRADE".
static func band_text(shown: MachinePrize) -> String:
	match shown.kind:
		MachinePrize.Kind.COUPON:
			return "COUPON"
		MachinePrize.Kind.REGISTER:
			if PerkLevels.is_level_up(shown.upgrade):
				return "LEVEL UP · LV %d" % shown.upgrade.level_number()
			return "LOYALTY STAMP"
		MachinePrize.Kind.UPGRADE:
			return "UPGRADE"
	return "NEW ITEM"


## A NEW ITEM's price as its window prints it ("2€"); "" for any other prize.
static func price_text(shown: MachinePrize) -> String:
	if shown.kind != MachinePrize.Kind.PRODUCT:
		return ""
	return "%d€" % shown.card.base


## The prize's name on its ticket: the item's, the perk's, or the upgrade's name line.
static func prize_name(shown: MachinePrize) -> String:
	match shown.kind:
		MachinePrize.Kind.REGISTER:
			return shown.upgrade.display_name
		MachinePrize.Kind.UPGRADE:
			return upgrade_name(shown)
	return shown.card.display_name


## The prize's rule on its ticket: the item's long rule text (#105), the perk's effect, or what
## the upgrade does (upgrade_text).
static func rule_text(shown: MachinePrize, preview: MachinePreview) -> String:
	match shown.kind:
		MachinePrize.Kind.REGISTER:
			return shown.upgrade.effect_text
		MachinePrize.Kind.UPGRADE:
			return upgrade_text(shown, preview)
	return shown.card.rule_text


## The rule's lines and its size (an index into RULE_SIZES) on a ticket whose name takes
## `name_lines` lines over a win strip of `strip_rows` rows: at the first size that shows `text`
## uncut in the room left (rule_room), else the smallest, cut to its room. Pure.
static func rule_fit(text: String, name_lines: int, strip_rows: int = 0) -> Vector2i:
	var font: Font = ArtStyle.bold_font(RULE_WEIGHT)
	for step: int in RULE_SIZES.size():
		var lines: int = text_lines(font, text, RULE_SIZES[step], RULE_WIDTH)
		if lines <= rule_room(name_lines, strip_rows, step):
			return Vector2i(lines, step)
	var last: int = RULE_SIZES.size() - 1
	return Vector2i(rule_room(name_lines, strip_rows, last), last)


## How many rule lines at RULE_SIZES[step] fit between the name (`name_lines` lines) and the win
## strip (`strip_rows` rows, 0: none) or the face's foot; at least one.
static func rule_room(name_lines: int, strip_rows: int, step: int) -> int:
	var bottom: float = RULE_BOTTOM
	if strip_rows > 0:
		bottom = strip_rect(strip_rows).position.y - RULE_STRIP_GAP
	return maxi(1, floori((bottom - rule_top(name_lines)) / RULE_PITCHES[step]))


## The rule's top under a name of `name_lines` lines.
static func rule_top(name_lines: int) -> float:
	return NAME_TOP + NAME_PITCH * (name_lines - 1) + ArtStyle.PIXEL_CAP_HEIGHT * 2.0 + RULE_GAP


## The win strip's rect on the face for `rows` rows.
static func strip_rect(rows: int) -> Rect2:
	var height: float = WIN_ROW * rows
	return Rect2(WIN_INSET, SIZE.y - WIN_FOOT - height, SIZE.x - 2.0 * WIN_INSET, height)


## Whether the rule `text` shows whole (rule_fit) under a name of `name_lines` lines over a win
## strip of `strip_rows` rows. Pure.
static func rule_whole(text: String, name_lines: int, strip_rows: int = 0) -> bool:
	var fit: Vector2i = rule_fit(text, name_lines, strip_rows)
	var font: Font = ArtStyle.bold_font(RULE_WEIGHT)
	var needed: int = text_lines(font, text, RULE_SIZES[fit.y], RULE_WIDTH)
	return needed <= rule_room(name_lines, strip_rows, fit.y)


## Whether the name `text` shows in hard pixel lines (name_rows) on a ticket whose rule is `rule`
## over a win strip of `strip_rows` rows: when it fits them, unless its two lines would cut the
## rule where the bold name takes fewer lines and leaves it whole. Pure.
static func name_in_rows(text: String, rule: String, strip_rows: int = 0) -> bool:
	var rows: PackedStringArray = name_rows(text)
	if rows.is_empty():
		return false
	if rows.size() == 1 or rule_whole(rule, rows.size(), strip_rows):
		return true
	var bold_lines: int = mini(
		text_lines(ArtStyle.bold_font(BOLD_WEIGHT), text, NAME_SIZE, NAME_WIDTH), NAME_LINES
	)
	return not (bold_lines < rows.size() and rule_whole(rule, bold_lines, strip_rows))


## `text` wrapped into hard pixel lines no wider than NAME_WIDTH; empty when it takes more than
## NAME_LINES of them, or a word alone is too wide (the bold fallback). Pure.
static func name_rows(text: String) -> PackedStringArray:
	var rows: PackedStringArray = []
	var row: String = ""
	for word: String in text.split(" ", false):
		var tried: String = word if row.is_empty() else "%s %s" % [row, word]
		if MachineLine.width_of(tried) <= NAME_WIDTH:
			row = tried
			continue
		if row.is_empty() or MachineLine.width_of(word) > NAME_WIDTH:
			return PackedStringArray()
		rows.append(row)
		row = word
	if not row.is_empty():
		rows.append(row)
	return rows if rows.size() <= NAME_LINES else PackedStringArray()


## What an UPGRADES pick does, from the machine's preview: one copy one step ("1 copy: BIG ›
## GOLDEN"), a plain copy straight to GOLDEN, or every copy (SHELF).
static func upgrade_text(upgrade_prize: MachinePrize, preview: MachinePreview) -> String:
	if preview == null or preview.targets.is_empty():
		return ""
	var from_tier: int = preview.targets[0].definition.tier
	var to_tier: int = preview.to_cards[0].tier
	match upgrade_prize.rarity:
		MachinePrize.Rarity.RARE:
			return "1 plain copy, 2 steps"
		MachinePrize.Rarity.LEGENDARY:
			return (
				"SHELF ×%d · every %s +1 step" % [preview.copies, upgrade_prize.card.display_name]
			)
	return "1 copy: %s › %s" % [TIER_WORDS[from_tier], TIER_WORDS[to_tier]]


## The name line of an UPGRADES ticket: which item it improves and how ("Milk +1 step", "Milk ›
## GOLDEN", "Shelf upgrade").
static func upgrade_name(upgrade_prize: MachinePrize) -> String:
	var item_name: String = upgrade_prize.card.display_name
	match upgrade_prize.rarity:
		MachinePrize.Rarity.RARE:
			return "%s › GOLDEN" % item_name
		MachinePrize.Rarity.LEGENDARY:
			return "Shelf upgrade"
	return "%s +1 step" % item_name


## How many lines `text` takes in `font` at `font_size`, wrapped at `width`. Pure.
static func text_lines(font: Font, text: String, font_size: int, width: float) -> int:
	var lines: TextParagraph = TextParagraph.new()
	lines.add_string(text, font, font_size)
	lines.width = width
	lines.break_flags = (
		TextServer.BREAK_MANDATORY | TextServer.BREAK_WORD_BOUND | TextServer.BREAK_ADAPTIVE
	)
	return lines.get_line_count()


## Hooks this part to the machine: RewardMachineView calls it once, after placing it (`rest`,
## `launch`) and before adding it (build spec 4.2).
func setup(machine: RewardMachineView) -> void:
	view = machine


## The ticket at `t` on view.plan: hidden before its flight, flying out of the tray, then face up
## with its rarity's effect; after the pick, lifted and gone (picked) or falling away.
func frame(t: float) -> void:
	var plan: MachinePlan = view.plan if view != null else null
	if plan == null or not plan.has_draw or index >= plan.n_prizes:
		visible = false
		return
	_rm = plan.reduced_motion
	_idle = view.idle_time
	var flight: float = plan.ticket_flight(index, t)
	visible = flight >= 0.0
	if not visible:
		return
	var k: float = MachineArt.ease_back(clampf(flight, 0.0, 1.0))
	var at: Vector2 = launch.lerp(rest, k)
	scale = Vector2.ONE * (lerpf(FLY_SCALE, 1.0, k) if flight < 1.0 else 1.0)
	_te = t - plan.reveal_at[index]
	var bump: float = BUMP if _te >= 0.0 and _te < BUMP_S and not _rm else 0.0
	var shaking: bool = doomed and not plan.has_landing
	_shred.visible = shaking
	if shaking and not _rm:
		at += Vector2(sin(_idle * SHAKE_RATE.x), cos(_idle * SHAKE_RATE.y)) * SHAKE
	if plan.has_landing and t >= plan.press:
		at += _after_pick(plan, t)
	position = MachineArt.snap_point(at + Vector2(0, bump))
	tab.show_at(_te, _rm)
	_frame_burst()
	_fx_back.queue_redraw()
	_fx_front.queue_redraw()


## The win sticker's lines ("ON YOUR LAST ROW +6€", "BEST ROW THIS RUN WASTED"); empty without one.
func win_texts() -> PackedStringArray:
	return _win_texts


func win_sticker() -> Control:
	return _win_sticker


## A win's amount as its sticker prints it: "+6€", or WASTED for nothing.
static func win_amount(gain: int) -> String:
	return MonitorText.gain(gain) if gain > 0 else "WASTED"


## The prize's rarity texts (the tab), for tests.
func rarity_texts() -> PackedStringArray:
	return PackedStringArray([tab.text()])


## The art's chip on the ticket (ticket coordinates; empty when it has none): a BIG or GOLDEN
## item's tier, an upgrade's, a level-up's "LV n".
func chip_rect() -> Rect2:
	var rect: Rect2 = art.chip_rect()
	if rect.has_area():
		rect.position += ART_RECT.position
	return rect


## The face's texts: the band, the name and the rule.
func face_texts() -> PackedStringArray:
	return PackedStringArray([_band.text(), _name_text, _rule.text])


## The face's labels (the band's, the name's, the rule), for layout tests.
func face_labels() -> Array[Label]:
	var found: Array[Label] = []
	for holder: Control in [_band, _name]:
		if holder is Label:
			found.append(holder as Label)
		for child: Node in holder.find_children("*", "Label", true, false):
			found.append(child as Label)
	found.append(_rule)
	return found


## The price window's line (null: not a NEW ITEM).
func price_line() -> MachineLine:
	return _price


## The name (a holder of hard pixel lines, or the bold fallback's Label) and its line count.
func name_control() -> Control:
	return _name


func name_line_count() -> int:
	return _name_lines


func rule_label() -> Label:
	return _rule


## Whether `text` prints in hard pixel lines (name_rows; else the bold fallback).
static func name_is_display(text: String) -> bool:
	return not name_rows(text).is_empty()


## Whether the LEGENDARY sunburst shows now, and its radius.
func burst_radius() -> float:
	return (
		float((_burst.material as ShaderMaterial).get_shader_parameter("radius"))
		if _burst.visible
		else 0.0
	)


## The pips' text (● / ◆◆ / ★★★), drawn as shapes.
func pips_text() -> String:
	return ["●", "◆◆", "★★★"][prize.rarity]


## Seconds since it landed face up (below 0: not yet).
func since_landed() -> float:
	return _te


## What picking it would do (RewardMachine.preview), or null.
func prize_preview() -> MachinePreview:
	return _preview


func _gui_input(event: InputEvent) -> void:
	var press: InputEventMouseButton = event as InputEventMouseButton
	if press and press.pressed and press.button_index == MOUSE_BUTTON_LEFT:
		accept_event()
		clicked.emit(index)


## The offset after the pick at `t`: the picked ticket lifts (and hides once it flies, MachineFlyer
## carrying its prize); the others fall away and fade, as every ticket does on a bin.
func _after_pick(plan: MachinePlan, t: float) -> Vector2:
	var picked: bool = _picked()
	if picked and plan.landing != MachinePlan.Landing.BIN:
		visible = t < (plan.fly_out if not _rm else plan.land)
		return Vector2(0, -PICK_LIFT * MachineArt.seg(t, plan.press, plan.fly_out))
	var fall: float = MachineArt.seg(t, plan.press, plan.press + FALL_S)
	if _rm:
		fall = 1.0 if t > plan.press else 0.0
	modulate.a = 1.0 - fall
	visible = fall < 1.0
	return Vector2(0, FALL * MachineArt.ease_in_out(fall))


func _picked() -> bool:
	if view.run == null or view.run.history.is_empty():
		return false
	var visits: Array[MachineVisit] = view.run.history[-1].visits
	return not visits.is_empty() and visits[-1].picked == index


## The LEGENDARY sunburst's life: grows (BURST_GROW), holds, then shrinks to a small glow by
## BURST_SHRINK; it turns on view.idle_time (still under reduced motion, at its glow).
func _frame_burst() -> void:
	var legendary: bool = prize.rarity == MachinePrize.Rarity.LEGENDARY
	_burst.visible = legendary and _te >= 0.0
	if not _burst.visible:
		return
	var radius: float = BURST_RADIUS * GLOW_SHARE
	var alpha: float = GLOW_ALPHA
	if not _rm:
		if _te < BURST_GROW:
			radius = BURST_RADIUS * MachineArt.ease_back(_te / BURST_GROW)
			alpha = 1.0
		elif _te < BURST_HOLD:
			radius = BURST_RADIUS
			alpha = 1.0
		else:
			var k: float = MachineArt.ease_in_out(MachineArt.seg(_te, BURST_HOLD, BURST_SHRINK))
			radius = lerpf(BURST_RADIUS, BURST_RADIUS * GLOW_SHARE, k)
			alpha = lerpf(1.0, GLOW_ALPHA, k)
	var look: ShaderMaterial = _burst.material as ShaderMaterial
	look.set_shader_parameter("radius", MachineArt.snap(radius))
	look.set_shader_parameter("alpha", alpha)
	look.set_shader_parameter("rotation", _idle * BURST_SPIN)


func _add_texts(_run: RunState) -> void:
	_band = MachineLine.make("Band", band_text(prize), _band_ink())
	_band.centre_in(BAND_RECT)
	_card.add_child(_band)
	_name_text = prize_name(prize)
	var text: String = rule_text(prize, _preview)
	var rows: PackedStringArray = name_rows(_name_text)
	var bold: Font = ArtStyle.bold_font(BOLD_WEIGHT)
	if name_in_rows(_name_text, text, _strip_rows()):
		var holder: Control = Control.new()
		holder.name = "Name"
		holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
		holder.position = Vector2((SIZE.x - NAME_WIDTH) / 2.0, NAME_TOP)
		var cap: float = ArtStyle.PIXEL_CAP_HEIGHT * 2.0
		holder.size = Vector2(NAME_WIDTH, NAME_PITCH * (rows.size() - 1) + cap)
		for row: int in rows.size():
			var line: MachineLine = MachineLine.make("Row%d" % row, rows[row], Palette.INK)
			line.position = MachineArt.snap_point(
				Vector2((NAME_WIDTH - line.width()) / 2.0, NAME_PITCH * row)
			)
			holder.add_child(line)
		_card.add_child(holder)
		_name = holder
		_name_lines = rows.size()
	else:
		var label: Label = _label(_name_text, NAME_SIZE, bold, Palette.INK)
		label.name = "Name"
		_name_lines = mini(text_lines(bold, _name_text, NAME_SIZE, NAME_WIDTH), NAME_LINES)
		label.max_lines_visible = NAME_LINES
		var cap_middle: float = NAME_TOP + ArtStyle.PIXEL_CAP_HEIGHT - NAME_PITCH / 2.0
		var name_band: Vector2 = Vector2(NAME_WIDTH, cap_middle)
		_fit_pitched(label, bold, NAME_SIZE, NAME_PITCH, name_band, _name_lines)
		_name = label
	var rule_font: Font = ArtStyle.bold_font(RULE_WEIGHT)
	var fit: Vector2i = rule_fit(text, _name_lines, _strip_rows())
	var rule_size: int = RULE_SIZES[fit.y]
	var room: int = rule_room(_name_lines, _strip_rows(), fit.y)
	_rule = _label(text, rule_size, rule_font, Palette.INK)
	_rule.name = "Rule"
	_rule.max_lines_visible = room
	var band: Vector2 = Vector2(RULE_WIDTH, rule_top(_name_lines))
	_fit_pitched(_rule, rule_font, rule_size, RULE_PITCHES[fit.y], band, room)
	_rule.vertical_alignment = VERTICAL_ALIGNMENT_TOP


## The win strip's rows (0: none).
func _strip_rows() -> int:
	if _win == null:
		return 0
	return 2 if _win.rows > 1 else 1


## A NEW ITEM's price in its window at the art box's top right.
func _add_price() -> void:
	var price: String = price_text(prize)
	if price.is_empty():
		return
	_price = MachineLine.make("Price", price, Palette.INK)
	var width: float = _price.width()
	_price.position = MachineArt.snap_point(
		Vector2(PRICE_RIGHT - PRICE_PAD - width, PRICE_TOP + PRICE_PAD)
	)
	_card.add_child(_price)


## The price window's rect (ticket coordinates; empty: none).
func price_rect() -> Rect2:
	if _price == null:
		return Rect2()
	return Rect2(_price.position, _price.size).grow(PRICE_PAD)


## The chip layer: the art's chip, the pips and the price window, over the art.
func _draw_chip(chip: Control) -> void:
	art.draw_chip(chip, ART_RECT.position)
	_draw_pips(chip)
	if _price != null:
		MachineArt.box(chip, price_rect(), Palette.PAPER, Palette.INK)


## The win strip inside the face's foot: a row per row of the run, its small label left and its
## amount right in hard pixel lettering, green, or WASTED in tomato.
func _add_win() -> void:
	var gains: Array[int] = [_win.last]
	if _win.rows > 1:
		gains.append(_win.best)
	var strip: Rect2 = strip_rect(gains.size())
	_win_sticker = Control.new()
	_win_sticker.name = "WinSticker"
	_win_sticker.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_win_sticker.position = strip.position
	_win_sticker.size = strip.size
	_win_sticker.draw.connect(_draw_win.bind(gains.size()))
	_card.add_child(_win_sticker)
	var font: Font = ArtStyle.bold_font(WIN_LABEL_WEIGHT)
	for line: int in gains.size():
		var amount: String = win_amount(gains[line])
		_win_texts.append("%s %s" % [WIN_LABELS[line], amount])
		var row: Rect2 = Rect2(0, WIN_ROW * line + WIN_RULE, strip.size.x, WIN_ROW - WIN_RULE)
		var ink: Color = Palette.GREEN_DARK if gains[line] > 0 else Palette.TOMATO_DARK
		var shown: MachineLine = MachineLine.make("WinAmount%d" % line, amount, ink)
		shown.centre_in(row)
		shown.position.x = MachineArt.snap(strip.size.x - WIN_PAD - shown.width())
		_win_sticker.add_child(shown)
		var words: Label = _label(
			WIN_LABELS[line].to_lower(), WIN_LABEL_SIZE, font, Palette.INK_LIGHT, _win_sticker
		)
		words.name = "WinLabel%d" % line
		words.autowrap_mode = TextServer.AUTOWRAP_OFF
		words.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		var width: float = shown.position.x - 2.0 * WIN_PAD
		RewardMachineView.fit(words, Rect2(WIN_PAD, row.position.y, width, row.size.y))


## The strip: each row's ink rule over its pale mustard fill.
func _draw_win(rows: int) -> void:
	var box: Vector2 = _win_sticker.size
	for line: int in rows:
		var top: float = WIN_ROW * line
		_win_sticker.draw_rect(Rect2(0, top, box.x, WIN_RULE), Palette.INK)
		_win_sticker.draw_rect(
			Rect2(0, top + WIN_RULE, box.x, WIN_ROW - WIN_RULE), Palette.MUSTARD_PALE
		)


func _label(
	text: String, font_size: int, font: Font, colour: Color, parent: Control = null
) -> Label:
	var label: Label = UiKit.body_label(text, font_size, colour)
	label.add_theme_font_override("font", font)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.clip_text = true
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	(parent if parent != null else _card).add_child(label)
	return label


## Sets `label`'s line spacing so its lines are `pitch` px apart and fits it centred in a box
## `band.x` wide whose first line's middle sits at `band.y + pitch / 2`. The box is one font height
## plus a pitch per further line (`lines` in all), so Godot shows every line: a box only
## `pitch * lines` high holds one line fewer when the font is taller than the pitch.
static func _fit_pitched(
	label: Label, font: Font, font_size: int, pitch: float, band: Vector2, lines: int
) -> void:
	var height: float = font.get_height(font_size)
	var spacing: int = roundi(pitch - height)
	label.add_theme_constant_override("line_spacing", spacing)
	var box: float = height + (height + spacing) * (lines - 1) + PITCH_SLACK
	var top: float = band.y + (pitch - height) / 2.0 - PITCH_SLACK / 2.0
	RewardMachineView.fit(label, Rect2((SIZE.x - band.x) / 2.0, top, band.x, box))


func _band_colour() -> Color:
	match prize.kind:
		MachinePrize.Kind.REGISTER, MachinePrize.Kind.UPGRADE:
			return Palette.MUSTARD
		MachinePrize.Kind.COUPON:
			return Palette.TEAL
	return Palette.CREAM_SHADE


func _band_ink() -> Color:
	match prize.kind:
		MachinePrize.Kind.REGISTER, MachinePrize.Kind.UPGRADE:
			return Palette.BRASS_DARKEST
		MachinePrize.Kind.COUPON:
			return Palette.PAPER
	return Palette.INK


func _art_colour() -> Color:
	match prize.kind:
		MachinePrize.Kind.REGISTER, MachinePrize.Kind.UPGRADE:
			return Palette.MUSTARD_PALE
		MachinePrize.Kind.COUPON:
			return Palette.TEAL_PALE
	return Palette.CREAM


func _layer(layer_name: String, parent: Control = null) -> Control:
	var layer: Control = Control.new()
	layer.name = layer_name
	layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.size = SIZE
	(parent if parent != null else self).add_child(layer)
	return layer


## The face: its shadow, paper with its rarity's edge, the art box and its shadow, the band, the
## pips.
func _draw_card() -> void:
	var rect: Rect2 = Rect2(Vector2.ZERO, SIZE)
	var legendary: bool = prize.rarity == MachinePrize.Rarity.LEGENDARY
	_card.draw_rect(Rect2(Vector2(6, 6), SIZE), Color(Palette.INK, 0.35))
	MachineArt.box(_card, rect, Palette.PAPER, Palette.BRASS_DARKEST if legendary else Palette.INK)
	_card.draw_rect(rect.grow(-2.0), EDGES[prize.rarity])
	_card.draw_rect(rect.grow(-4.0), Palette.PAPER)
	_card.draw_rect(ART_RECT, _art_colour())
	_card.draw_rect(BAND_RECT, _band_colour())


func _draw_pips(item: CanvasItem) -> void:
	var grid: String = PIP_GRIDS[prize.rarity]
	var count: int = prize.rarity + 1
	var origin: Vector2 = Vector2(PIP_LEFT, PIP_TOP)
	for pip: int in range(count):
		for cell: int in range(25):
			if grid[cell] == "x":
				var at: Vector2 = (
					origin + Vector2(pip * 6 + cell % 5, floori(cell / 5.0)) * PIP_PIXEL
				)
				item.draw_rect(Rect2(at, Vector2(PIP_PIXEL, PIP_PIXEL)), PIP_INKS[prize.rarity])


## The shred mark of a doomed ticket: tomato strips down the face and a cross on the art.
func _draw_shred() -> void:
	var x: float = SHRED_PITCH
	while x < SIZE.x - SHRED_WIDTH:
		_shred.draw_rect(
			Rect2(x, 4.0, SHRED_WIDTH, SIZE.y - 8.0), Color(Palette.TOMATO_DARK, SHRED_ALPHA)
		)
		x += SHRED_PITCH
	var middle: Vector2 = ART_RECT.get_center()
	var half: float = CROSS_SIZE / 2.0
	for line: int in range(2):
		var from: Vector2 = middle + Vector2(-half, -half if line == 0 else half)
		var to: Vector2 = middle + Vector2(half, half if line == 0 else -half)
		_shred.draw_line(from, to, Palette.INK, CROSS_WIDTH + 4.0)
		_shred.draw_line(from, to, Palette.TOMATO, CROSS_WIDTH)


## Behind the ticket: a RARE ticket's teal glow ring.
func _draw_back() -> void:
	if _te < 0.0 or prize.rarity != MachinePrize.Rarity.RARE:
		return
	var a: float = clampf(_te / 0.1, 0.0, 1.0) * (0.35 + 0.25 * sin(_idle * 5.0)) + 0.15
	MachineArt.ring(
		_fx_back, Rect2(-10, -10, SIZE.x + 20, SIZE.y + 20), Color(Palette.TEAL_BRIGHT, a), 2.0
	)
	MachineArt.ring(_fx_back, Rect2(-6, -6, SIZE.x + 12, SIZE.y + 12), Color(Palette.TEAL_LIGHT, a))


## Over the ticket: COMMON's dust, RARE's shine and sparkles, LEGENDARY's flash, orbiting
## sparkles, coins, shine and ring.
func _draw_front() -> void:
	if _te < 0.0:
		return
	var te: float = _te
	var inner: Rect2 = Rect2(6, 6, SIZE.x - 12, SIZE.y - 12)
	match prize.rarity:
		MachinePrize.Rarity.COMMON:
			if _rm:
				return
			var a: float = 1.0 - MachineArt.seg(te, 0.0, DUST_S)
			for k: int in range(6):
				if a <= 0.0:
					break
				var side: float = -1.0 if k < 3 else 1.0
				var x: float = SIZE.x / 2.0 + side * (40.0 + (k % 3) * 28.0 + te * 120.0)
				var y: float = SIZE.y - 4.0 - (k % 2) * 6.0 - te * 20.0
				_fx_front.draw_rect(
					Rect2(MachineArt.snap_point(Vector2(x, y)), Vector2(4, 4)),
					Color(Palette.GREY_LIGHT, a)
				)
		MachinePrize.Rarity.RARE:
			if not _rm:
				MachineArt.shine(
					_fx_front,
					inner,
					MachineArt.seg(te, RARE_SHINE[0], RARE_SHINE[1]),
					Palette.TEAL_PALE,
					3.0
				)
			var points: Array[Vector2] = [
				Vector2(-4, 12),
				Vector2(SIZE.x + 4, 40),
				Vector2(SIZE.x - 8, SIZE.y + 4),
				Vector2(8, SIZE.y - 20)
			]
			for k: int in range(points.size()):
				var since: float = te - 0.15 - k * 0.08
				if since <= 0.0 and not _rm:
					continue
				var twinkle: float = 1.0 if fposmod(_idle * 0.7 + k * 0.37, 2.0) < 0.3 else 0.0
				var alpha: float = sin(PI * since / 0.5) if since < 0.5 and not _rm else twinkle
				MachineArt.sparkle(
					_fx_front, points[k], 2.0 if since < 0.5 else 1.0, alpha if not _rm else 1.0
				)
		MachinePrize.Rarity.LEGENDARY:
			_draw_legendary(te, inner)


func _draw_legendary(te: float, inner: Rect2) -> void:
	var centre: Vector2 = SIZE / 2.0
	if not _rm and te < FLASH_S:
		_fx_front.draw_rect(Rect2(Vector2.ZERO, SIZE), Color(Palette.PAPER, FLASH_ALPHA))
	var a: float = 1.0 if _rm else clampf((te - 0.1) / 0.3, 0.0, 1.0)
	for k: int in range(ORBIT_SPARKLES):
		var angle: float = k * TAU / ORBIT_SPARKLES + _idle * 1.2
		var radius: float = 128.0 + 16.0 * sin(_idle * 3.0 + k)
		var at: Vector2 = centre + Vector2(cos(angle) * radius, sin(angle) * radius * 0.8)
		var big: bool = (k + int(floorf(_idle * 6.0))) % 3 == 0
		MachineArt.sparkle(_fx_front, at, 2.0 if big else 1.0, a)
	if not _rm:
		MachineArt.coins(
			_fx_front, Vector2(centre.x, 20), te, COINS, COIN_SEED, COIN_POWER, SIZE.y + 200.0
		)
		MachineArt.shine(
			_fx_front,
			inner,
			MachineArt.seg(te, LEGEND_SHINE[0], LEGEND_SHINE[1]),
			Palette.MUSTARD_PALE,
			3.0
		)
	var pulse: float = 0.5 + 0.5 * sin(_idle * 4.0)
	MachineArt.ring(
		_fx_front, Rect2(-4, -4, SIZE.x + 8, SIZE.y + 8), Color(Palette.GOLD, pulse), 2.0
	)
