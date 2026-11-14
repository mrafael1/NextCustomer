class_name StartTips
extends Control
## The start screen's hover tips (v1.33, the words pass and hover tips B: the approved start rows of
## docs/art/mockups/hover_tips.html): a pool of TipTargets laid over a canvas page's hit areas
## (BoosterPage's regulars and opened booster cards, the swap window's cards, BuildPage's spread
## pack), each with its TipSpec, placed every frame from the page's tip list. The board's
## GlyphTips (StartBoard) shows them as the game's other tips; the targets take no clicks, so the
## page under them keeps its hover, its drag and its clicks.
##
## A tip-list entry is {rect (art px), key (what it shows: a changed key builds its spec again),
## make (a Callable returning its TipSpec)}, bottom first: a later entry (a family chip on its
## card) is the topmost.

## The regular's tag, and the click that opens the swap window from page 1's crate.
const REGULAR_TAG := "YOUR REGULAR"
const SWAP_CLICK := "SWAP"
## The swap window's swapped-in card and swapped-out regular.
const SWAPPED_IN_TAG := "SWAPPED IN"
const SWAPPED_OUT_LIVE := "Swapped out. Drag it back to its spot to undo."
const SWAPPED_IN_LIVE := "Drag it out of the basket to undo."
## The copy limit (the copy rule, run.starter.copy_max), as its tip says it.
const COPY_LIMIT_LIVE := "You can't have more than %d of one item."
## The copy limit's in-place tag (a dimmed card, a refused slot) and its hint LED line.
const COPY_LIMIT_TAG := "MAX %d IN CART"
const COPY_LIMIT_LINE := "YOU CAN'T HAVE MORE THAN %d OF ONE ITEM"
## The locked swaps' hint LED line (one swap per finished aisle; no per-aisle limit since v1.32).
const SWAPS_LOCKED_LINE := "SWAPS LOCKED · 1 SWAP PER FINISHED AISLE"
## Swaps: locked with no finished aisle, and waiting for the boosters.
const SWAPS_LOCKED_LIVE := "Swaps locked: 1 swap per finished aisle."
const SWAPS_WAIT_LIVE := "Open every booster to swap it."
## A plain item's body (no rule of its own) and an item with a rule's fine print.
const PLAIN_BODY := "Pays its price: %d€."
const PRICE_COND := "Price: %d€."
## A family chip's body, and a starter pack's family band's.
const FAMILY_BODY := "%s is a %s item."
const PACK_FAMILY_BODY := "This starter pack is built around %s items."
## The meta naming a target's entry key (for captures and tests).
const KEY_META := &"tip_key"
## The targets built at once (a page's most: the swap window's ten cards with their family chips
## and its basket), so no node is built while the board's pages slide; more are added if needed.
const POOL := 40

var _targets: Array[TipTarget] = []
var _keys: PackedStringArray = PackedStringArray()


func _init() -> void:
	name = "StartTips"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	size = ShiftStage.SIZE
	_target(POOL - 1)


## Lays the targets over `entries` (see the class comment); the targets left over hide.
func show_entries(entries: Array[Dictionary]) -> void:
	for index: int in entries.size():
		var entry: Dictionary = entries[index]
		var target: TipTarget = _target(index)
		var rect: Rect2 = entry.rect
		target.position = rect.position * ArtPen.UNIT
		target.size = rect.size * ArtPen.UNIT
		var key: String = entry.key
		if _keys[index] != key:
			_keys[index] = key
			var made: TipSpec = (entry.make as Callable).call()
			target.spec = made
			target.tip_text = made.plain()
			target.set_meta(KEY_META, key)
		target.visible = true
	for index: int in range(entries.size(), _targets.size()):
		_targets[index].visible = false


## Hides every target (a page that shows no tips now).
func clear() -> void:
	show_entries([])


## The shown target whose key begins with `prefix` (captures, tests), or null.
func target_for(prefix: String) -> TipTarget:
	for index: int in _targets.size():
		if _targets[index].visible and _keys[index].begins_with(prefix):
			return _targets[index]
	return null


## The shown targets (tests).
func shown_targets() -> Array[TipTarget]:
	var shown: Array[TipTarget] = []
	for target: TipTarget in _targets:
		if target.visible:
			shown.append(target)
	return shown


func _target(index: int) -> TipTarget:
	while _targets.size() <= index:
		var target: TipTarget = TipTarget.new()
		target.name = "StartTip%d" % _targets.size()
		target.visible = false
		add_child(target)
		_targets.append(target)
		_keys.append("")
	return _targets[index]


## An entry (see the class comment).
static func entry_of(rect: Rect2, key: String, make: Callable) -> Dictionary:
	return {"rect": rect, "key": key, "make": make}


## The entries of `card` drawn as a booster card face at art (`x`, `y`): the card (tagged `tag`,
## its live line `live` of `live_kind`), then its family chips (BoosterArt.face's), appended to
## `list`. `key` names the place.
static func card_entries(
	list: Array[Dictionary],
	card: CardDefinition,
	rare: bool,
	at: Vector2,
	key: String,
	tag: String,
	live: String = "",
	live_kind: TipSpec.Live = TipSpec.Live.INFO
) -> void:
	var rect: Rect2 = Rect2(at, Vector2(BoosterArt.CW, BoosterArt.CH))
	var shown: String = "%s|%s|%s|%s|%s" % [key, card.id, tag, live, live_kind]
	list.append(entry_of(rect, shown, card_spec.bind(card, tag, "", live, live_kind)))
	var win: Rect2i = BoosterArt.window_of(rare)
	var styles: Array[FamilyStyle] = BoosterArt.families(card)
	for k: int in styles.size():
		var chip: Rect2 = Rect2(
			at.x + win.position.x + 1, at.y + win.position.y + 8 + k * 14, 12, 12
		)
		list.append(
			entry_of(
				chip, "%s|fam%d|%s" % [key, k, styles[k].id], family_spec.bind(styles[k], card)
			)
		)


## A card's tip: its name, `tag`, its rule (or what a plain item pays), its price as fine print,
## the footer's CLICK `click` and a live line `live` of `live_kind`.
static func card_spec(
	card: CardDefinition,
	tag: String,
	click: String = "",
	live: String = "",
	live_kind: TipSpec.Live = TipSpec.Live.INFO
) -> TipSpec:
	var coupon: bool = card.is_coupon()
	var rule: String = CardText.monitor_text(card)
	var body: String = rule
	if body.is_empty():
		body = PLAIN_BODY % card.base if not coupon else card.rule_text.strip_edges()
	var spec: TipSpec = TipSpec.make(
		TipSpec.Kind.COUPON if coupon else TipSpec.Kind.ITEM, card.display_name.to_upper(), body
	)
	spec.icon = ArtStyle.coupon_icon(card) if coupon else mini_of(card)
	spec.tag = tag
	if not coupon and not rule.is_empty():
		spec.cond = PRICE_COND % card.base
	spec.click = click
	spec.live = live
	spec.live_kind = live_kind
	spec.source = spec.plain()
	return spec


## A product's mini (its giver badge's, CardDefinition.badge_mini_ref) for its tip's icon box, or
## null when it has none.
static func mini_of(card: CardDefinition) -> Texture2D:
	var ref: String = card.badge_mini_ref()
	if ref.is_empty() or not ResourceLoader.exists(ref):
		return null
	return load(ref) as Texture2D


## A family chip's tip (the approved HOUSEHOLD · FAMILY row): the family's band and glyph, "Scissors
## is a Household item.", and the FAMILY box beside it.
static func family_spec(style: FamilyStyle, card: CardDefinition) -> TipSpec:
	var body: String = FAMILY_BODY % [card.display_name, style.display_name] if card != null else ""
	var spec: TipSpec = TipSpec.make(TipSpec.Kind.FAMILY, style.display_name.to_upper(), body)
	spec.tag = TipSpec.FAMILY_TAG
	spec.icon = style.glyph
	spec.band = style.face if style.has_ticket_colours() else Palette.CREAM_SHADE
	spec.band_ink = Palette.PAPER if style.paper_text else Palette.INK
	spec.subs = PackedStringArray(["FAMILY"])
	spec.source = spec.plain()
	return spec


## A starter pack's family band's tip: the family's (family_spec), tagged with the pack's name.
static func pack_family_spec(style: FamilyStyle, pack: StarterPackDefinition) -> TipSpec:
	var spec: TipSpec = family_spec(style, null)
	spec.body = PACK_FAMILY_BODY % style.display_name
	spec.tag = pack.display_name.to_upper()
	spec.source = spec.plain()
	return spec
