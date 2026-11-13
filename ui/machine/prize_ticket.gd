class_name PrizeTicket
extends Control
## One prize ticket (v0.50, mock-up premium_machine_v1.html; R1 "drop", approved): ticket i holds
## reveal i. It flies out of the tray to its pedestal in the prize bay (PrizeRow.card_rect;
## view.plan.ticket_flight: a back ease, from 0.45x at the tray's mouth) and lands face up at its
## reveal (reveal_at), where its rarity's effect plays:
## - COMMON: a clean drop, a 2 px bump and a puff of dust;
## - RARE: the foil's sweep crosses it (CardFoil), four sparkles (and a two-note chime,
##   MachineSounds);
## - LEGENDARY: it lands a beat later (the plan), a white flash, a dithered sunburst behind it
##   (presentation/dither_burst.gdshader) that grows, then shrinks to a small glow within about a
##   second, coins, orbiting sparkles, its art climbing out over the plate, the gold sweep, the
##   scene's short shake (MachineLayers) and a sting.
## The sunburst stands behind every ticket of the row (z order), the sparkles, the coins and the
## corner glints in front; the sweep comes back every few seconds. Since v0.99 the card itself
## carries its rarity (CardFoil, the user's picks on mock-up card_rarity.html: COMMON a shelf label,
## RARE a teal holo laminate, LEGENDARY gold foil with its plate, flecks, rays and breakout), with
## its tab (RarityTab: COMMON / RARE! / LEGENDARY!!) and its pips (one dot, two diamonds, three
## stars, drawn shapes): never by colour alone; the C2 rim and chase lights behind it are gone.
## Under reduced motion it appears in place at its reveal, its burst still, its foil still and its
## sparkles and glints on.
##
## The face (V3's 144x244 ticket in v0.98, mock-ups machine_relook_v2.html and _v3.html: paper
## with an ink outline and a cream edge) holds the art window (PrizeArt, in the kind's colour:
## the real sprite, the coupon slip, a LOYALTY punch card, an upgrade's item at its new tier) with
## the pips at its top left, the family chips under them (B2: one 13x13 art px chip per family of
## the prize's ticket, two for a split, a perk's the family it boosts) and a NEW ITEM's price
## window at its top right (its chunky digits on paper); under it the band in the kind's colour
## (cream item, teal coupon, mustard upgrade or loyalty) holding the prize's name centred in hard
## pixel lettering, on one row or two (a name too long for them in bold Atkinson), and the rule
## (#105: Atkinson 600, centred, at the first of RULE_SIZES that shows it uncut in the room left,
## else cut there: the popup has it whole). A LOYALTY prize's LAST ROW / BEST ROW sticker
## (WinSticker, S1) hangs off its foot. Resting the pointer on it (hovered) opens the scan popup
## with the whole effect (v0.53, PrizePopup). A click picks it once the machine has armed; after
## the pick the picked ticket wears a gold rim, lifts and flies off (MachineFlyer takes it), the
## others fall away, and a bin drops them all. frame(t) reads only view.plan, t, view.landing and
## view.idle_time.

signal clicked(index: int)
## The pointer rests on the ticket, or left it (the view opens or closes its popup).
signal hovered(index: int)
signal unhovered(index: int)

const SIZE := Vector2(144, 244)
const RARITY_TEXTS: Array[String] = RarityTab.TEXTS
const PIP_INKS: Array[Color] = [Palette.GREY, Palette.TEAL, Palette.BRASS_DARKEST]
const TIER_WORDS: Array[String] = ["PLAIN", "BIG", "GOLDEN"]
## An UPGRADES ticket's rule (upgrade_text) and a SHELF one's name (upgrade_name).
const UPGRADE_ONE := "Turns 1 %s copy %s"
const UPGRADE_SHELF := "All your %s (×%d): +1 level"
const SHELF_NAME := "Shelf upgrade"
## The face: the art window, the band (the name in hard pixel rows, BAND_PITCH apart from
## BAND_PAD down; a name too long for NAME_LINES of them in bold Atkinson NAME_SIZE) and the rule
## (Atkinson 600, the first RULE_SIZES size that shows it in the room left over the foot, else
## the smallest, cut: the popup has it all).
const ART_RECT := Rect2(6, 6, 132, 100)
const BAND_TOP := 108.0
const BAND_LEFT := 4.0
const BAND_WIDTH := 136.0
## RARE and LEGENDARY bands stand inside their 3 art px foil frames (v0.99).
const FOIL_BAND_LEFT := 6.0
const FOIL_BAND_WIDTH := 132.0
const BAND_PAD := 6.0
const BAND_PITCH := 20.0
const NAME_SIZE := 13
const NAME_WIDTH := 128.0
const NAME_LINES := 2
const RULE_GAP := 6.0
const RULE_SIZES: Array[int] = [12, 11, 10]
## Each RULE_SIZES size's line pitch.
const RULE_PITCHES: Array[float] = [16.0, 14.0, 12.0]
const RULE_WIDTH := 128.0
## The rule moves down this share of the room it leaves (the mock-up's centring).
const RULE_SETTLE := 0.4
const RULE_SETTLE_MIN := 12.0
## The face's foot under the rule: with a win sticker (it hangs over it) and without.
const FOOT_WITH_STICKER := 12.0
const FOOT_PLAIN := 4.0
const FACE_INSET := 6.0
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
const PIP_LEFT := 10.0
const PIP_TOP := 10.0
const PIP_PIXEL := 2.0
## The family chips (B2) under the pips: CHIP_SIZE square, CHIP_STEP apart from CHIP_AT.
const CHIP_AT := Vector2(8, 22)
## A LEGENDARY card's chips and price window: under its plate (CardFoil.PLATE), at its window's
## foot (CHIP_FOOT, PRICE_FOOT), or (the price) at the top right as on every card, wherever they
## cover the least of the climbed art (_corner_tops).
const LEGENDARY_CHIP_TOP := 26.0
const CHIP_FOOT := 76.0
const PRICE_FOOT := 78.0
const CHIP_SIZE := 26.0
const CHIP_STEP := 28.0
## A NEW ITEM's price window at the art box's top right: its chunky digits on paper.
const PRICE_RIGHT := 136.0
const PRICE_TOP := 8.0
const PRICE_PAD := 6.0
const PRICE_HEIGHT := 24.0
## The tab's middle above the ticket.
const TAB_MIDDLE := Vector2(72, -7)
## The flight: from this scale at the tray's mouth.
const FLY_SCALE := 0.45
## COMMON's bump and dust, RARE's and LEGENDARY's effect times (seconds after landing).
const BUMP := 4.0
const BUMP_S := 0.12
const DUST_S := 0.4
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

var index: int = 0
var prize: MachinePrize
## The SKIP bin is hovered (SkipBin): it shakes under a shred mark (before any landing).
var doomed: bool = false
## The machine this part belongs to (setup(), build spec 4.2).
var view: RewardMachineView
var tab: RarityTab
var art: PrizeArt
## The card's rarity look (CardFoil.look_of) and its foil (stripes, rays, sweep). Every rarity cue
## on the ticket reads it (the stock, foil, band, chips, tab, pips, glints and landing effects),
## and the machine plans its landing from it (RewardMachineView), so they never disagree.
var look: int = 0
var foil: CardFoil
## Where it lands (machine coordinates) and where it leaves the tray from (its top-left at 1x).
var rest: Vector2 = Vector2.ZERO
var launch: Vector2 = Vector2.ZERO
var _preview: MachinePreview
var _card: Control
var _fx_back: Control
var _fx_front: Control
var _shred: Control
var _burst: ColorRect
## The name: its hard pixel rows (a holder of MachineLines) or, too long for them, a bold Label.
var _name: Control
var _name_text: String = ""
var _name_rows: int = 1
## A NEW ITEM's price in its window (null: none).
var _price: MachineLine
var _rule: Label
## The family chips' looks (B2).
var _families: Array[FamilyStyle] = []
## The family chips' and the price window's tops (_corner_tops; V3's on COMMON and RARE).
var _chip_top: float = CHIP_AT.y
var _price_top: float = PRICE_TOP
## What the prize would have won on the run's rows (PrizeWin), or null; its sticker.
var _win: PrizeWin
var _sticker: WinSticker
## Seconds since it landed face up (below 0: not yet), and the idle time, for the effects.
var _te: float = -1.0
var _idle: float = 0.0
var _rm: bool = false
var _gold: bool = false
var _hovered: bool = false


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
	mouse_entered.connect(_on_hover.bind(true))
	mouse_exited.connect(_on_hover.bind(false))
	visible = false
	# The tickets stand a z step up, their back effects a step down again: every ticket's rim and
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
	look = CardFoil.look_of(prize)
	foil = CardFoil.new(look, prize.kind)
	_card.add_child(foil)
	art = PrizeArt.new(prize, preview)
	art.position = ART_RECT.position
	_card.add_child(art)
	if look == MachinePrize.Rarity.LEGENDARY:
		art.break_out(CardFoil.window_rect(look).position.y - ART_RECT.position.y)
	_families = FamilyPalette.shared().styles(chip_families(prize))
	if look == MachinePrize.Rarity.LEGENDARY and not _families.is_empty():
		var width: float = CHIP_SIZE + CHIP_STEP * (_families.size() - 1)
		var row: Rect2 = Rect2(CHIP_AT, Vector2(width, CHIP_SIZE))
		var chip_tops: Array[float] = [LEGENDARY_CHIP_TOP, CHIP_FOOT]
		_chip_top = _corner_tops(row, chip_tops)
	_win = PrizeWin.of(run, preview)
	_add_texts()
	foil.set_band(band_rect(_name_rows, look))
	var chip: Control = _layer("Chip", _card)
	chip.draw.connect(_draw_chip.bind(chip))
	_add_price()
	_fx_front = _layer("FxFront")
	_fx_front.draw.connect(_draw_front)
	if _win != null:
		var gains: Array[int] = [_win.last]
		if _win.rows > 1:
			gains.append(_win.best)
		_sticker = WinSticker.new(gains, SIZE)
		add_child(_sticker)
	_shred = _layer("Shred")
	_shred.draw.connect(_draw_shred)
	_shred.visible = false
	tab = RarityTab.new(look)
	tab.position = MachineArt.snap_point(TAB_MIDDLE - tab.size / 2.0)
	add_child(tab)
	# The card's icons are whole art px at an integer scale: nearest keeps them crisp (the
	# default linear filter blurred the family glyphs, the stamp rings and the sparkles).
	for crisp: CanvasItem in [chip, art, _fx_back, _fx_front]:
		crisp.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	art.keep_text_smooth()


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


## The families whose chips the ticket wears (B2): its ticket's (FamilyPalette.ticket_families:
## one, two for a split, none for a plain coupon), or a perk's the family it boosts (none
## without). Pure.
static func chip_families(shown: MachinePrize) -> PackedStringArray:
	if shown.kind == MachinePrize.Kind.REGISTER:
		var tag: String = shown.upgrade.boosts_tag if shown.upgrade != null else ""
		if tag.is_empty() or FamilyPalette.shared().style(tag) == null:
			return PackedStringArray()
		return PackedStringArray([tag])
	if shown.card == null:
		return PackedStringArray()
	return FamilyPalette.shared().ticket_families(shown.card)


## The family chips' rects on the ticket (B2), for `count` families, on a card of `rarity` (a
## LEGENDARY card's under its plate), their top at `top` when given (a ticket's: family_rects).
static func chip_rects(count: int, rarity: int = 0, top: float = -1.0) -> Array[Rect2]:
	var rects: Array[Rect2] = []
	var at: Vector2 = CHIP_AT
	if top >= 0.0:
		at.y = top
	elif rarity == MachinePrize.Rarity.LEGENDARY:
		at.y = LEGENDARY_CHIP_TOP
	for chip: int in range(count):
		rects.append(Rect2(at + Vector2(CHIP_STEP * chip, 0), Vector2.ONE * CHIP_SIZE))
	return rects


## The band's rect for a name of `rows` rows on a card of `rarity` (inside a foil frame on RARE
## and LEGENDARY).
static func band_rect(rows: int, rarity: int = 0) -> Rect2:
	var height: float = BAND_PAD + BAND_PITCH * rows
	if rarity == MachinePrize.Rarity.COMMON:
		return Rect2(BAND_LEFT, BAND_TOP, BAND_WIDTH, height)
	return Rect2(FOIL_BAND_LEFT, BAND_TOP, FOIL_BAND_WIDTH, height)


## The rule's lines and its size (an index into RULE_SIZES) under a band of `row_count` rows,
## with a win sticker (`sticker`) or not: at the first size that shows `text` uncut in the room
## left (rule_room), else the smallest, cut to its room. Pure.
static func rule_fit(text: String, row_count: int, sticker: bool = false) -> Vector2i:
	var font: Font = ArtStyle.bold_font(RULE_WEIGHT)
	for step: int in RULE_SIZES.size():
		var lines: int = text_lines(font, text, RULE_SIZES[step], RULE_WIDTH)
		if lines <= rule_room(row_count, sticker, step):
			return Vector2i(lines, step)
	var last: int = RULE_SIZES.size() - 1
	return Vector2i(rule_room(row_count, sticker, last), last)


## How many rule lines at RULE_SIZES[step] fit between the band (`row_count` rows) and the face's
## foot (a sticker's, or the plain one); at least one.
static func rule_room(row_count: int, sticker: bool, step: int) -> int:
	return maxi(1, floori((rule_bottom(sticker) - rule_top(row_count)) / RULE_PITCHES[step]))


## The rule room's top under a band of `row_count` rows.
static func rule_top(row_count: int) -> float:
	return band_rect(row_count).end.y + RULE_GAP


## The rule room's foot: over a win sticker's margin, or the face's.
static func rule_bottom(sticker: bool) -> float:
	return SIZE.y - FACE_INSET - (FOOT_WITH_STICKER if sticker else FOOT_PLAIN)


## Whether the rule `text` shows whole (rule_fit) under a band of `row_count` rows. Pure.
static func rule_whole(text: String, row_count: int, sticker: bool = false) -> bool:
	var fit: Vector2i = rule_fit(text, row_count, sticker)
	var font: Font = ArtStyle.bold_font(RULE_WEIGHT)
	var needed: int = text_lines(font, text, RULE_SIZES[fit.y], RULE_WIDTH)
	return needed <= rule_room(row_count, sticker, fit.y)


## `text` as the band's hard pixel rows: one when it fits NAME_WIDTH, else the two-row split whose
## wider row is narrowest; empty when no split fits (the bold fallback). Pure.
static func name_rows(text: String) -> PackedStringArray:
	if MachineLine.width_of(text) <= NAME_WIDTH:
		return PackedStringArray([text])
	var words: PackedStringArray = text.split(" ", false)
	var best: PackedStringArray = PackedStringArray()
	var best_width: float = INF
	for cut: int in range(1, words.size()):
		var first: String = " ".join(words.slice(0, cut))
		var second: String = " ".join(words.slice(cut))
		var wider: float = maxf(MachineLine.width_of(first), MachineLine.width_of(second))
		if wider <= NAME_WIDTH and wider < best_width:
			best_width = wider
			best = PackedStringArray([first, second])
	return best


## What an UPGRADES pick does, from the machine's preview (v1.36, polish audit: it no longer
## repeats the name line): one copy one step ("Turns 1 BIG copy GOLDEN"), a plain copy straight to
## GOLDEN ("Turns 1 PLAIN copy GOLDEN"), or every copy ("All your Milk (×2): +1 level").
static func upgrade_text(upgrade_prize: MachinePrize, preview: MachinePreview) -> String:
	if preview == null or preview.targets.is_empty():
		return ""
	var from_tier: int = preview.targets[0].definition.tier
	var to_tier: int = preview.to_cards[0].tier
	match upgrade_prize.rarity:
		MachinePrize.Rarity.RARE:
			return UPGRADE_ONE % [TIER_WORDS[0], TIER_WORDS[2]]
		MachinePrize.Rarity.LEGENDARY:
			return UPGRADE_SHELF % [upgrade_prize.card.display_name, preview.copies]
	return UPGRADE_ONE % [TIER_WORDS[from_tier], TIER_WORDS[to_tier]]


## The name line of an UPGRADES ticket: the item it improves ("Milk"; v1.36, polish audit: the
## tier it reaches is the art's chip, so the name fits the hard pixel rows), or "Shelf upgrade".
static func upgrade_name(upgrade_prize: MachinePrize) -> String:
	if upgrade_prize.rarity == MachinePrize.Rarity.LEGENDARY:
		return SHELF_NAME
	return upgrade_prize.card.display_name


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
## with its rarity's effect; after the pick, lifted in its gold rim and gone (picked) or falling
## away.
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
	_gold = false
	if plan.has_landing and t >= plan.press:
		at += _after_pick(plan, t)
	position = MachineArt.snap_point(at + Vector2(0, bump))
	tab.show_at(_te, _rm)
	foil.frame(_idle, _te, index, _hovered, _rm)
	if look == MachinePrize.Rarity.LEGENDARY:
		art.climb(_te, _rm)
	if _sticker != null:
		_sticker.frame(_te, _rm)
	_frame_burst()
	_fx_back.queue_redraw()
	_fx_front.queue_redraw()


## The win sticker's lines ("LAST ROW +6€", "BEST ROW WASTED"); empty without one.
func win_texts() -> PackedStringArray:
	return _sticker.texts() if _sticker != null else PackedStringArray()


## The LAST ROW / BEST ROW sticker (null: not a LOYALTY prize with a row to show).
func win_sticker() -> WinSticker:
	return _sticker


## The prize's rarity texts (the tab), for tests.
func rarity_texts() -> PackedStringArray:
	return PackedStringArray([tab.text()])


## The art's chip on the ticket (ticket coordinates; empty when it has none): a BIG or GOLDEN
## item's tier, an upgrade's, the SHELF's, a level-up's "LV n".
func chip_rect() -> Rect2:
	var rect: Rect2 = art.chip_rect()
	if rect.has_area():
		rect.position += ART_RECT.position
	return rect


## The family chips' looks (B2), in order.
func family_chips() -> Array[FamilyStyle]:
	return _families


## The face's texts: the name and the rule.
func face_texts() -> PackedStringArray:
	return PackedStringArray([_name_text, _rule.text])


## The face's labels (the name's bold fallback, the rule), for layout tests.
func face_labels() -> Array[Label]:
	var found: Array[Label] = []
	if _name is Label:
		found.append(_name as Label)
	found.append(_rule)
	return found


## The price window's line (null: not a NEW ITEM).
func price_line() -> MachineLine:
	return _price


## The name (a holder of hard pixel rows, or the bold fallback's Label) and its row count.
func name_control() -> Control:
	return _name


func name_line_count() -> int:
	return _name_rows


func rule_label() -> Label:
	return _rule


## Whether the LEGENDARY sunburst shows now, and its radius.
func burst_radius() -> float:
	return (
		float((_burst.material as ShaderMaterial).get_shader_parameter("radius"))
		if _burst.visible
		else 0.0
	)


## The pips' text (● / ◆◆ / ★★★), drawn as shapes.
func pips_text() -> String:
	return ["●", "◆◆", "★★★"][look]


## Seconds since it landed face up (below 0: not yet).
func since_landed() -> float:
	return _te


## What picking it would do (RewardMachine.preview), or null.
func prize_preview() -> MachinePreview:
	return _preview


## The price window's rect (ticket coordinates; empty: none).
func price_rect() -> Rect2:
	if _price == null:
		return Rect2()
	var width: float = _price.width() + 2.0 * PRICE_PAD
	return Rect2(PRICE_RIGHT - width, _price_top, width, PRICE_HEIGHT)


## This ticket's family chips' rects (chip_rects at their placed top).
func family_rects() -> Array[Rect2]:
	return chip_rects(_families.size(), look, _chip_top)


## Of the tops `tops` for `rect` (ticket coordinates), the one whose rect covers the fewest of the
## art's ink texels once it has climbed (PrizeArt.ink_texels), never over the art's own chip; the
## first on a tie. When the art climbs out over the plate the window's foot (the last top) comes
## first, as mock-up card_rarity_B.html drops the chips and the price there.
func _corner_tops(rect: Rect2, tops: Array[float]) -> float:
	var order: Array[float] = tops.duplicate()
	if art.climb_full() > 0.0:
		var foot: float = tops[tops.size() - 1]
		order.remove_at(order.size() - 1)
		order.insert(0, foot)
	var art_chip: Rect2 = art.chip_rect()
	art_chip.position += ART_RECT.position
	var best: float = order[0]
	var least: int = -1
	for top: float in order:
		var spot: Rect2 = Rect2(rect.position.x, top, rect.size.x, rect.size.y)
		if art_chip.has_area() and spot.intersects(art_chip):
			continue
		var ink: int = art.ink_texels(Rect2(spot.position - ART_RECT.position, spot.size))
		if least < 0 or ink < least:
			least = ink
			best = top
	return best


## Whether the pointer rests on it (the RARE foil runs faster under it).
func is_hovered() -> bool:
	return _hovered


func _on_hover(on: bool) -> void:
	_hovered = on
	if on:
		hovered.emit(index)
	else:
		unhovered.emit(index)


func _gui_input(event: InputEvent) -> void:
	var press: InputEventMouseButton = event as InputEventMouseButton
	if press and press.pressed and press.button_index == MOUSE_BUTTON_LEFT:
		accept_event()
		clicked.emit(index)


## The offset after the pick at `t`: the picked ticket wears its gold rim and lifts (and hides
## once it flies, MachineFlyer carrying its prize); the others fall away and fade, as every ticket
## does on a bin.
func _after_pick(plan: MachinePlan, t: float) -> Vector2:
	var picked: bool = _picked()
	if picked and plan.landing != MachinePlan.Landing.BIN:
		_gold = true
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
	var legendary: bool = look == MachinePrize.Rarity.LEGENDARY
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
	var burst: ShaderMaterial = _burst.material as ShaderMaterial
	burst.set_shader_parameter("radius", MachineArt.snap(radius))
	burst.set_shader_parameter("alpha", alpha)
	burst.set_shader_parameter("rotation", _idle * BURST_SPIN)


## The band's name (hard pixel rows, centred, or the bold fallback) and the rule under it.
func _add_texts() -> void:
	_name_text = prize_name(prize)
	var rows: PackedStringArray = name_rows(_name_text)
	var ink: Color = _band_ink()
	if not rows.is_empty():
		var band: Rect2 = band_rect(rows.size(), look)
		var holder: Control = Control.new()
		holder.name = "Name"
		holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
		holder.position = band.position
		holder.size = band.size
		for row: int in rows.size():
			var line: MachineLine = MachineLine.make("Row%d" % row, rows[row], ink)
			line.position = MachineArt.snap_point(
				Vector2((band.size.x - line.width()) / 2.0, BAND_PAD + BAND_PITCH * row)
			)
			holder.add_child(line)
		_card.add_child(holder)
		_name = holder
		_name_rows = rows.size()
	else:
		# Deliberate fallback (v0.98 changelog): an UPGRADES prize's long name ("Reduced yogurt ›
		# GOLDEN", "Birthday candles +1 step") has no two-row split within NAME_WIDTH.
		var bold: Font = ArtStyle.bold_font(BOLD_WEIGHT)
		_name_rows = NAME_LINES
		var label: Label = _label(_name_text, NAME_SIZE, bold, ink)
		label.name = "Name"
		label.max_lines_visible = NAME_LINES
		var band: Rect2 = band_rect(NAME_LINES, look)
		var middle: float = band.position.y + BAND_PAD / 2.0
		_fit_pitched(label, bold, NAME_SIZE, BAND_PITCH, Vector2(NAME_WIDTH, middle), NAME_LINES)
		_name = label
	var text: String = rule_text(prize, _preview)
	var sticker: bool = _win != null
	var rule_font: Font = ArtStyle.bold_font(RULE_WEIGHT)
	var fit: Vector2i = rule_fit(text, _name_rows, sticker)
	var rule_size: int = RULE_SIZES[fit.y]
	var room: int = rule_room(_name_rows, sticker, fit.y)
	var pitch: float = RULE_PITCHES[fit.y]
	var top: float = rule_top(_name_rows)
	var spare: float = rule_bottom(sticker) - top - pitch * fit.x
	if spare > RULE_SETTLE_MIN:
		top += MachineArt.snap(spare * RULE_SETTLE)
	_rule = _label(text, rule_size, rule_font, Palette.INK_LIGHT)
	_rule.name = "Rule"
	_rule.max_lines_visible = room
	_fit_pitched(_rule, rule_font, rule_size, pitch, Vector2(RULE_WIDTH, top), fit.x)
	_rule.vertical_alignment = VERTICAL_ALIGNMENT_TOP


## A NEW ITEM's price in its window at the art box's top right: chunky digits.
func _add_price() -> void:
	var price: String = price_text(prize)
	if price.is_empty():
		return
	_price = MachineLine.make("Price", price, Palette.INK)
	if look == MachinePrize.Rarity.LEGENDARY:
		var price_tops: Array[float] = [PRICE_TOP, LEGENDARY_CHIP_TOP, PRICE_FOOT]
		_price_top = _corner_tops(price_rect(), price_tops)
	var window: Rect2 = price_rect()
	# The chunky digits stand an art px over the line's capitals: their top 4 px into the window.
	_price.position = window.position + Vector2(PRICE_PAD, PRICE_PAD)
	_card.add_child(_price)


## The chip layer over the art: the art's chip, the pips, the family chips and the price window.
func _draw_chip(chip: Control) -> void:
	art.draw_chip(chip, ART_RECT.position)
	_draw_pips(chip)
	var rects: Array[Rect2] = family_rects()
	var p: float = MachineArt.PIXEL
	for chip_index: int in range(_families.size()):
		var family: FamilyStyle = _families[chip_index]
		var rect: Rect2 = rects[chip_index]
		chip.draw_rect(rect, Palette.INK)
		var face: Rect2 = rect.grow(-p)
		chip.draw_rect(face, family.face)
		chip.draw_rect(Rect2(face.position, Vector2(face.size.x, p)), family.light)
		chip.draw_rect(Rect2(face.end.x - p, face.position.y + p, p, face.size.y - p), family.shade)
		chip.draw_rect(Rect2(face.position.x, face.end.y - p, face.size.x, p), family.shade)
		if family.glyph != null:
			var glyph: Rect2 = Rect2(
				rect.position + Vector2(2.0 * p, 2.0 * p), family.glyph.get_size() * p
			)
			chip.draw_texture_rect(family.glyph, glyph, false)
	if _price != null:
		MachineArt.box(chip, price_rect(), Palette.PAPER, Palette.INK)


func _label(text: String, font_size: int, font: Font, colour: Color) -> Label:
	var label: Label = UiKit.body_label(text, font_size, colour)
	label.add_theme_font_override("font", font)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.clip_text = true
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_card.add_child(label)
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


## The band's colour by kind: cream item, teal coupon, mustard upgrade or loyalty.
func _band_colour() -> Color:
	match prize.kind:
		MachinePrize.Kind.REGISTER, MachinePrize.Kind.UPGRADE:
			return Palette.MUSTARD
		MachinePrize.Kind.COUPON:
			return Palette.TEAL
	return Palette.CREAM_SHADE


func _band_ink() -> Color:
	return Palette.PAPER if prize.kind == MachinePrize.Kind.COUPON else Palette.INK


func _layer(layer_name: String, parent: Control = null) -> Control:
	var layer: Control = Control.new()
	layer.name = layer_name
	layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.size = SIZE
	(parent if parent != null else self).add_child(layer)
	return layer


## The face: its rarity's stock (CardFoil.draw_stock: frame, paper, the art window in the kind's
## colour, the band).
func _draw_card() -> void:
	var chip: Rect2 = art.chip_rect()
	var chip_left: bool = chip.has_area() and chip.get_center().x < PrizeArt.SIZE.x / 2.0
	CardFoil.draw_stock(
		_card, look, prize.kind, band_rect(_name_rows, look), _band_colour(), chip_left
	)


func _draw_pips(item: CanvasItem) -> void:
	var grid: String = PIP_GRIDS[look]
	var count: int = look + 1
	var origin: Vector2 = Vector2(PIP_LEFT, PIP_TOP)
	for pip: int in range(count):
		for cell: int in range(25):
			if grid[cell] == "x":
				var at: Vector2 = (
					origin + Vector2(pip * 6 + cell % 5, floori(cell / 5.0)) * PIP_PIXEL
				)
				item.draw_rect(Rect2(at, Vector2(PIP_PIXEL, PIP_PIXEL)), PIP_INKS[look])


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


## Behind the ticket: the picked ticket's gold rim (the card's own foil carries its rarity, v0.99:
## no rim or chase lights behind it).
func _draw_back() -> void:
	if _gold:
		TicketRim.draw_pick(_fx_back, SIZE)


## Over the ticket: COMMON's dust, the corner glints, RARE's sparkles, LEGENDARY's flash,
## orbiting sparkles and coins (the sweep is the foil's, under the art and the words).
func _draw_front() -> void:
	if _te < 0.0:
		return
	var te: float = _te
	if not _gold:
		TicketRim.draw_glints(_fx_front, look, _idle, _rm, SIZE)
	match look:
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
			_draw_rare(te)
		MachinePrize.Rarity.LEGENDARY:
			_draw_legendary(te)


## RARE's four sparkles round it, twinkling once they have popped.
func _draw_rare(te: float) -> void:
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


func _draw_legendary(te: float) -> void:
	var centre: Vector2 = SIZE / 2.0
	if not _rm and te < FLASH_S:
		_fx_front.draw_rect(Rect2(Vector2.ZERO, SIZE), Color(Palette.PAPER, FLASH_ALPHA))
	var a: float = 1.0 if _rm else clampf((te - 0.1) / 0.3, 0.0, 1.0)
	for k: int in range(ORBIT_SPARKLES):
		var angle: float = k * TAU / ORBIT_SPARKLES + _idle * 1.2
		var radius: float = 120.0 + 16.0 * sin(_idle * 3.0 + k)
		var at: Vector2 = centre + Vector2(cos(angle) * radius * 0.8, sin(angle) * radius)
		var big: bool = (k + int(floorf(_idle * 6.0))) % 3 == 0
		MachineArt.sparkle(_fx_front, at, 2.0 if big else 1.0, a)
	if not _rm:
		MachineArt.coins(
			_fx_front, Vector2(centre.x, 20), te, COINS, COIN_SEED, COIN_POWER, SIZE.y + 200.0
		)
