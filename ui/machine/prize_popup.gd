class_name PrizePopup
extends Control
## A revealed prize ticket's effect in full (v0.53, decided with the user on 2026-10-23: "when
## item are revealed after a receipt machine, user can't see effect of them"), in the game's one
## hover tip since polish batch 2 (TipCard, the hover tips revamp's paper card, approved
## 2026-11-13; the old red-header scan popup was the last tip of its kind on the screen): on the
## machine's card layer over the tickets. Resting the pointer on a ticket (PrizeTicket.hovered)
## opens it with what the prize does (spec_for): a product's or coupon's card (its band in its
## rarity's colour as the cart's tips have it, its rarity tag, its rule whole, the families it
## counts as or what its colour means), an item upgrade's card at its new tier (its preview's
## first copy), a LOYALTY perk (PERK, or LV n for a level-up with the owned level's effect as its
## "Now:" line). The rule's keywords get their boxes (TipWords) beside it. It opens only once the
## ticket has landed face up and before the pick, UNDER the ticket (above it when the stage has no
## room there), anchored off the row so it never covers the ticket or its neighbours (the polish
## audit's prize-tip), and closes as the pointer leaves, at the pick or the bin, and when the visit
## closes. Display only: it takes no clicks.

## The tag of a perk prize, and of a perk's level-up ("LV 2", MAX at the top level).
const PERK_TAG := "PERK · NEXT SHIFT"
const LEVEL_TAG := "%s · NEXT SHIFT"
const NOW_LINE := "Now: %s"
const UPGRADE_TAG := "UPGRADE · %s"
## The bands of a RARE and a LEGENDARY card, [band, ink] (the cart tips', CardTip).
const RARE_BAND: Array[Color] = [Palette.TEAL, Palette.PAPER]
const LEGENDARY_BAND: Array[Color] = [Palette.GOLD, Palette.INK]

## The ticket the popup describes (its index in the row; -1: closed).
var ticket_index: int = -1
var _card: TipCard
var _boxes: Array[TipCard] = []


func _init() -> void:
	name = "PrizePopup"
	z_index = 2
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false
	_card = TipCard.new()
	add_child(_card)
	for index: int in range(TipSpec.MAX_SUBS):
		var box: TipCard = TipCard.new(true)
		box.name = "TipBox%d" % index
		box.visible = false
		add_child(box)
		_boxes.append(box)


## Opens the popup for `ticket` (its view's run and plan): false, and closed, when the ticket
## hasn't landed face up yet, the pick is made, or its prize has nothing to show.
func open_for(ticket: PrizeTicket) -> bool:
	var view: RewardMachineView = ticket.view
	if view == null or view.run == null or not ticket.visible or ticket.since_landed() < 0.0:
		close_popup()
		return false
	var plan: MachinePlan = view.plan
	if plan != null and plan.has_landing and view.clock >= plan.press:
		close_popup()
		return false
	var made: TipSpec = spec_for(
		ticket.prize, ticket.prize_preview(), view.run.upgrades, view.run.machine.machine
	)
	if made == null:
		close_popup()
		return false
	ticket_index = ticket.index
	visible = true
	_card.show_spec(made)
	var keys: PackedStringArray = made.shown_subs()
	for index: int in range(_boxes.size()):
		var box_spec: TipSpec = TipWords.box(keys[index]) if index < keys.size() else null
		_boxes[index].visible = box_spec != null
		if box_spec != null:
			_boxes[index].show_spec(box_spec)
	var screen: Rect2 = get_viewport_rect()
	if is_instance_valid(view.stage):
		screen = view.stage.get_global_rect()
	place(ticket.get_global_rect(), screen)
	return true


## Places the card under `ticket_rect` (global), its boxes beside it, all inside `screen` (global).
func place(ticket_rect: Rect2, screen: Rect2) -> void:
	var to_local: Transform2D = get_global_transform().affine_inverse()
	var target: Rect2 = to_local * ticket_rect
	var area: Rect2 = to_local * screen
	var placed: Array = TipCard.place(target, target, TipCard.Opens.BELOW, _card.size, area)
	var card_rect: Rect2 = placed[0]
	_card.position = card_rect.position
	_card.point_tail(placed[1], target)
	var shown: Array[TipCard] = boxes()
	var sizes: Array[Vector2] = []
	for box: TipCard in shown:
		sizes.append(box.size)
	var rects: Array[Rect2] = TipCard.place_boxes(card_rect, placed[1], sizes, area, target)
	for index: int in range(shown.size()):
		shown[index].position = rects[index].position


## Closes the popup.
func close_popup() -> void:
	ticket_index = -1
	visible = false
	for box: TipCard in _boxes:
		box.visible = false


## Closes the popup if it describes ticket `index` (the pointer left it).
func leave(index: int) -> void:
	if ticket_index == index:
		close_popup()


## The tip card (for tests and captures).
func tip_card() -> TipCard:
	return _card


## The keyword boxes shown beside it.
func boxes() -> Array[TipCard]:
	var shown: Array[TipCard] = []
	for box: TipCard in _boxes:
		if box.visible:
			shown.append(box)
	return shown


## The card's rect and its boxes', global (for layout tests).
func shown_rects() -> Array[Rect2]:
	var found: Array[Rect2] = [_card.get_global_rect()]
	for box: TipCard in boxes():
		found.append(box.get_global_rect())
	return found


## The title the card shows (its spec's words).
func name_text() -> String:
	return _card.spec.title if _card.spec != null else ""


## The rule the card shows, as plain words.
func rule_text() -> String:
	return TipMarkup.plain(_card.spec.body) if _card.spec != null else ""


## The tip of `prize` (`machine` gives a card's rarity): the card it adds, the card an item
## upgrade turns a copy into (`preview`'s first), or the LOYALTY perk (a level-up with the effect
## of the level it replaces among `owned`, the run's perks). Null when there is nothing to show.
static func spec_for(
	prize: MachinePrize,
	preview: MachinePreview,
	owned: Array[UpgradeDefinition] = [],
	machine: MachineDefinition = null
) -> TipSpec:
	var card: CardDefinition = prize.card
	match prize.kind:
		MachinePrize.Kind.REGISTER:
			return _perk_spec(prize.upgrade, owned) if prize.upgrade != null else null
		MachinePrize.Kind.UPGRADE:
			card = (
				preview.to_cards[0] if preview != null and not preview.to_cards.is_empty() else null
			)
	if card == null:
		return null
	var made: TipSpec = TipSpec.make(
		TipSpec.Kind.COUPON if card.is_coupon() else TipSpec.Kind.ITEM,
		card.display_name,
		TipMarkup.auto(card.rule_text)
	)
	made.icon = ArtStyle.coupon_icon(card) if card.is_coupon() else ArtStyle.item_sprite(card)
	made.tag = CardTip.tag_of(card, machine) if machine != null else ""
	if prize.kind == MachinePrize.Kind.UPGRADE and not made.tag.is_empty():
		made.tag = UPGRADE_TAG % made.tag
	var meaning: String = CardTip.counts_as(card)
	if meaning.is_empty():
		meaning = CardTip.works_with(card)
	made.cond = TipMarkup.auto(meaning)
	if machine != null:
		match CartCardDraw.look_of(card, machine):
			BoosterArt.Look.RARE:
				made.band = RARE_BAND[0]
				made.band_ink = RARE_BAND[1]
			BoosterArt.Look.LEGENDARY:
				made.band = LEGENDARY_BAND[0]
				made.band_ink = LEGENDARY_BAND[1]
	return made


static func _perk_spec(upgrade: UpgradeDefinition, owned: Array[UpgradeDefinition]) -> TipSpec:
	var rule: String = upgrade.effect_text
	if not upgrade.condition_text.is_empty():
		rule += "\n" + upgrade.condition_text
	var made: TipSpec = TipSpec.make(
		TipSpec.Kind.PERK, upgrade.display_name, TipMarkup.auto(TipSpec.sentences(rule))
	)
	var level: int = upgrade.level_number()
	made.tag = PERK_TAG if level <= 1 else LEVEL_TAG % LoyaltyCard.level_text(upgrade)
	if not upgrade.icon_ref.is_empty() and ResourceLoader.exists(upgrade.icon_ref):
		made.icon = load(upgrade.icon_ref) as Texture2D
	var index: int = PerkLevels.owned_index(owned, upgrade)
	if PerkLevels.is_level_up(upgrade) and index >= 0:
		made.cond = TipMarkup.auto(NOW_LINE % owned[index].effect_text)
	return made
