class_name MonitorCarry
extends RefCounted
## The item column's carried subtotal (v1.14, the user's "fix the missing subtotal across pages":
## a later page repeated the base price, so its visible steps did not add up to the total). Each
## planning row keeps its line's running value (RUN meta: ScanController.ItemLines.runs, the
## score's value_after, -1 for a row that moves no amount) and whether it is a "gives" row (GIVES
## meta: it changes another item); a later page starts from the last RUN of the pages before it,
## its first line the carried line (MonitorBaseLine.make_carried) instead of the base price. A page
## with no amount-moving row before it starts at the base price (its own math does: the line
## repeats legitimately); a later page of "gives" rows only has no head (a carried value over rows
## that change other items would read as adding to them). A coupon has no base line, so its later
## pages get the carried line inline, as their first row (lay_out keeps its room; Repeat's own
## payout moves step by step). Each page's subtotal (subtotals) is the value its rows reached, for
## the page cue. The count's fold of earlier rows shows the running value after the rows it folds
## the same way. Pure: reads the rows' metas, never works a value out.

const RUN := &"run"
const GIVES := &"gives"
## A head placed as its page's first row (a coupon's), not above the rows.
const INLINE := &"inline"
## The count's fold caption: how many earlier steps it carries (FOLD_ONE for one).
const FOLD_CAPTION := "Carried forward (%d steps)"
const FOLD_ONE := "Carried forward (1 step)"


## The running value the item reached before page `page` of `paged` (each page's rows): the last
## RUN at least 0 on the pages before it, or -1 when none moved an amount.
static func carried_before(paged: Array[Array], page: int) -> int:
	var carried: int = -1
	for index: int in range(mini(page, paged.size())):
		for row: Variant in paged[index]:
			var run: int = int((row as Control).get_meta(RUN, -1))
			if run >= 0:
				carried = run
	return carried


## Each page's subtotal: the value the item reached at the end of the page (-1 when nothing moved
## by then).
static func subtotals(paged: Array[Array]) -> PackedInt32Array:
	var found: PackedInt32Array = PackedInt32Array()
	for page: int in range(paged.size()):
		found.append(carried_before(paged, page + 1))
	return found


## `lines` on pages `room` px tall (MonitorStepPages.lay_out); `inline` (a coupon's, no base line
## above the rows): a later page with a value carried into it starts its rows a row's pitch down,
## the room of its carried line (heads), unless its first row would not fit under it.
static func lay_out(lines: Array[Control], room: float, inline: bool) -> Array[Array]:
	if not inline:
		return MonitorStepPages.lay_out(lines, room)
	var paged: Array[Array] = [[]]
	var top: float = 0.0
	var carried: int = -1
	for row: Control in lines:
		if top + row.size.y > room + 0.5 and not paged[-1].is_empty():
			paged.append([])
			var pitch: float = MonitorStepRow.ROW_PITCH
			top = pitch if carried >= 0 and pitch + row.size.y <= room + 0.5 else 0.0
		row.position = Vector2(0, top)
		paged[-1].append(row)
		top += row.size.y
		var run: int = int(row.get_meta(RUN, -1))
		carried = run if run >= 0 else carried
	for shown: Array in paged:
		MonitorStepRow.even_sizes(shown)
	return paged


## Each page's head (see MonitorStepPages; null for none): `base` (the column's base line, or null)
## on the first page, then on a later page the carried line `width` px wide when something is
## carried into it, else a new base line for `base_amount` (none without `base`); none on a page
## of "gives" rows only, and on a coupon's page with no room left for it (lay_out). None at all
## (an empty list) with one page.
static func heads(
	paged: Array[Array], base: Control, base_amount: int, width: float
) -> Array[Control]:
	var found: Array[Control] = []
	if paged.size() < 2:
		return found
	found.append(base)
	for page: int in range(1, paged.size()):
		var carried: int = carried_before(paged, page)
		var rows: Array = paged[page]
		var head: Control = null
		if _gives_only(rows):
			head = null
		elif base != null:
			if carried >= 0:
				head = MonitorBaseLine.make_carried(carried, width)
			else:
				head = MonitorBaseLine.make(base_amount, width)
		elif carried >= 0 and not rows.is_empty():
			if (rows[0] as Control).position.y >= MonitorStepRow.ROW_PITCH - 0.5:
				head = MonitorBaseLine.make_carried(carried, width)
				head.set_meta(INLINE, true)
		found.append(head)
	return found


## The page cue `cue` (null with one page) with each page's subtotal, beside `payout`: the total
## keeps clear of the cue's widest page; when the total still needs the room, the cue goes compact.
## The "=" muted while a page before the last shows.
static func fit_cue(cue: MonitorPager, payout: MonitorPayout, paged: Array[Array]) -> void:
	payout.mute_equals(cue != null)
	if cue == null:
		payout.set_note_inset(0.0)
		return
	cue.set_subtotals(subtotals(paged))
	payout.set_note_inset(cue.widest())
	if payout.left_edge() < cue.widest() + MonitorPayout.NOTE_GAP:
		cue.compact = true
		payout.set_note_inset(cue.widest())


## The count's fold of the `folded` earlier rows, `width` px wide, with the running value after
## them, `carried` (-1: the caption alone); its "line" meta the caption.
static func fold_row(folded: int, carried: int, width: float) -> Control:
	var caption: String = fold_caption(folded)
	var row: Control = MonitorBaseLine.make_carried(carried, width, caption)
	row.name = "Folded"
	row.set_meta(&"line", caption)
	return row


## The fold's caption for `folded` earlier rows.
static func fold_caption(folded: int) -> String:
	return FOLD_ONE if folded == 1 else FOLD_CAPTION % folded


static func _gives_only(rows: Array) -> bool:
	if rows.is_empty():
		return false
	for row: Variant in rows:
		if not bool((row as Control).get_meta(GIVES, false)):
			return false
	return true
