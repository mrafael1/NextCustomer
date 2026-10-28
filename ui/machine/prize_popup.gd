class_name PrizePopup
extends ScanPopup
## A revealed prize ticket's effect in full (v0.53, decided with the user on 2026-10-23: "when
## item are revealed after a receipt machine, user can't see effect of them"): the scan popup the
## offers used (ScanPopup), on the machine's card layer over the tickets. Resting the pointer on a
## ticket (PrizeTicket.hovered) opens it with what the prize does: a product's or coupon's card
## (with its aisle and tags), an item upgrade's card at its new tier (its preview's first copy),
## a LOYALTY perk (ScanPopup.show_upgrade; a level-up, #108: titled "LV n", with the owned
## level's effect as its "Now:" line). It opens only once the ticket has landed face up and
## before the pick, beside the ticket (right of it when that fits the stage, else left; never
## over it), and closes as the pointer leaves, at the pick or the bin, and when the visit closes.

## The ticket the popup describes (its index in the row; -1: closed).
var ticket_index: int = -1


func _init() -> void:
	super()
	name = "PrizePopup"
	z_index = 2
	visible = false


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
	if not fill(self, ticket.prize, ticket.prize_preview(), view.run.upgrades):
		close_popup()
		return false
	ticket_index = ticket.index
	visible = true
	var item: Rect2 = ticket.get_global_rect()
	var screen: Rect2 = get_viewport_rect()
	if is_instance_valid(view.stage):
		screen = view.stage.get_global_rect()
	place_at(item, item, screen, screen)
	return true


## Closes the popup.
func close_popup() -> void:
	ticket_index = -1
	visible = false


## Closes the popup if it describes ticket `index` (the pointer left it).
func leave(index: int) -> void:
	if ticket_index == index:
		close_popup()


## Fills `shown` (a ScanPopup in the tree) with what `prize` does: the card it adds, the card an
## item upgrade turns a copy into (`preview`'s first), or the LOYALTY perk (a level-up with the
## effect of the level it replaces among `owned`, the run's perks). False when there is nothing to
## show.
static func fill(
	shown: ScanPopup,
	prize: MachinePrize,
	preview: MachinePreview,
	owned: Array[UpgradeDefinition] = []
) -> bool:
	var card: CardDefinition = prize.card
	match prize.kind:
		MachinePrize.Kind.REGISTER:
			if prize.upgrade == null:
				return false
			var now: String = ""
			var index: int = PerkLevels.owned_index(owned, prize.upgrade)
			if PerkLevels.is_level_up(prize.upgrade) and index >= 0:
				now = owned[index].effect_text
			shown.show_upgrade(prize.upgrade, now)
			return true
		MachinePrize.Kind.UPGRADE:
			card = (
				preview.to_cards[0] if preview != null and not preview.to_cards.is_empty() else null
			)
	if card == null:
		return false
	var tags: PackedStringArray = PackedStringArray()
	if card.is_product():
		tags = card.tags.duplicate()
	shown.show_card(card, tags)
	return true
