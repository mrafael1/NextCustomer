class_name MorningBand
extends RefCounted
## The MORNING ZONE's print on a row's belt (2026-11-18, in place of v1.24's pins, chain and
## post; the playtest of that day: "must start at slot 1 + continuity" lost most players). The
## zone is the row's first slots (MorningZone.slots, balance data): each of those cells wears a
## MorningZoneTile on its belt patch, under everything else of the cell (its holder is the cell's
## first child), and the zone's middle cell the MorningZoneLabel on the painted strip. The belt is
## drawn with slot 1 at its left end, by the scanner, which is the first slot scored, so the zone
## is the cells from the row's left.
##
## The print shows while planning when the run's cart holds a card that reads MORNING
## (CardMorning.zone_of the deck's cards), and hides otherwise and for the count (refresh, show
## with 0 slots): less on screen for a run with no MORNING card. A slot whose item counts (a
## MORNING item, PlanningModel.mornings) lights its patch's strip; a MORNING tooltip (the label's,
## or a ticket's MORNING chip's) lights the whole band (light).
##
## Static: the print lives on the RowStrip's cells, found again by name, so the shift screen and a
## handbook clip share it and a rebuilt row just gets it again at the next refresh.

const HOLDER_NAME := &"MorningZone"


## Planning's refresh: the zone of `run`'s cart on `row` (none when no card of the deck reads
## MORNING), its slots in `counting` lit (the preview's MORNING items).
static func refresh(row: RowStrip, run: RunState, counting: PackedInt32Array) -> void:
	show(row, zone_slots(run), counting)


## The zone's slots for `run`'s cart: 0 when no card of its deck reads MORNING (nor one of the
## shift's hand or row, which can hold a copy the deck doesn't: the debug panel's).
static func zone_slots(run: RunState) -> int:
	var cards: Array[CardDefinition] = []
	if run != null and run.deck != null:
		for card: CardInstance in run.deck.cards + run.hand() + run.row:
			cards.append(card.definition)
	var zone: MorningZone = CardMorning.zone_of(cards)
	return zone.slots if zone != null else 0


## Prints the zone on `row`'s first `slots` open cells (0: none), the patches of the slots in
## `counting` lit.
static func show(row: RowStrip, slots: int, counting: PackedInt32Array) -> void:
	var count: int = clampi(slots, 0, row.slots.size())
	var separation: float = row.box.get_theme_constant("separation")
	var hot: bool = false
	for tile: MorningZoneTile in tiles(row):
		hot = hot or tile.is_hot()
	for slot: int in range(row.slots.size()):
		var panel: PanelContainer = row.slots[slot]
		var holder: Control = panel.get_node_or_null(NodePath(HOLDER_NAME)) as Control
		if slot >= count:
			if holder != null:
				panel.remove_child(holder)
				holder.queue_free()
			continue
		if holder == null:
			holder = _new_holder(slot)
			panel.add_child(holder)
			# Under the talkers (an express lane), the footprint, the ticket and the item.
			panel.move_child(holder, 0)
		var tile: MorningZoneTile = holder.get_child(0) as MorningZoneTile
		var rect: Rect2 = MorningZoneTile.cell_rect(separation)
		tile.position = rect.position
		tile.size = rect.size
		tile.first = slot == 0
		tile.last = slot == count - 1
		tile.set_counts(counting.has(slot))
		tile.set_hot(hot)
		tile.queue_redraw()
		@warning_ignore("integer_division")
		_place_label(row, holder, tile, slot == (count - 1) / 2)


## The zone's patches on `row`, in slot order (empty: no zone shown).
static func tiles(row: RowStrip) -> Array[MorningZoneTile]:
	var found: Array[MorningZoneTile] = []
	for panel: PanelContainer in row.slots:
		var holder: Node = panel.get_node_or_null(NodePath(HOLDER_NAME))
		if holder != null and not holder.is_queued_for_deletion():
			found.append(holder.get_child(0) as MorningZoneTile)
	return found


## The zone's label on `row`, or null.
static func label(row: RowStrip) -> MorningZoneLabel:
	for panel: PanelContainer in row.slots:
		var holder: Node = panel.get_node_or_null(NodePath(HOLDER_NAME))
		if holder != null and not holder.is_queued_for_deletion() and holder.get_child_count() > 1:
			return holder.get_child(1) as MorningZoneLabel
	return null


## The zone's band on `row` (global rect: its patches' union), or an empty rect.
static func band_rect(row: RowStrip) -> Rect2:
	var band: Rect2 = Rect2()
	for tile: MorningZoneTile in tiles(row):
		var rect: Rect2 = tile.get_global_rect()
		band = rect if band.size == Vector2.ZERO else band.merge(rect)
	return band


## Lights the whole band (a MORNING tooltip shows) or puts it back. `lit` first, so a Callable
## bound to its row takes the tooltip's flag.
static func light(lit: bool, row: RowStrip) -> void:
	if not is_instance_valid(row):
		return
	for tile: MorningZoneTile in tiles(row):
		tile.set_hot(lit)


static func _new_holder(slot: int) -> Control:
	var holder: Control = Control.new()
	holder.name = HOLDER_NAME
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.add_child(MorningZoneTile.new(slot))
	return holder


## Puts the zone's label on `tile`'s strip, centred on its cell, when `wanted`; else takes it off.
static func _place_label(
	row: RowStrip, holder: Control, tile: MorningZoneTile, wanted: bool
) -> void:
	var shown: MorningZoneLabel = null
	if holder.get_child_count() > 1:
		shown = holder.get_child(1) as MorningZoneLabel
	if not wanted:
		if shown != null:
			holder.remove_child(shown)
			shown.queue_free()
		return
	if shown == null:
		shown = MorningZoneLabel.new()
		shown.on_tip = MorningBand.light.bind(row)
		# What covers the label is what covers the row's label layer, drawn over every cell: the
		# label lies under its cell's drop target, which would else hide its tooltip.
		shown.tip_cover = row.labels
		holder.add_child(shown)
	var strip_top: float = tile.position.y + tile.size.y - MorningZoneTile.STRIP
	var left: float = (RowStrip.CELL_SIZE.x - shown.size.x) / 2.0
	shown.position = Vector2(left, strip_top).snappedf(ArtStyle.ART_SCALE)
