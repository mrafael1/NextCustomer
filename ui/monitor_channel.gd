class_name MonitorChannel
extends Control
## The hung monitor's store channel in planning (#80, the user's play test of 2026-10-17: the
## monitor no longer shows PROJECTED, which the receipt and the top bar's SPEND chip carry). While
## nothing is scanned the monitor's screen cycles slides about the shift, each for
## ScanTuning.channel_slide_ms (data/balance/scan.tres), with a page dot per slide under them:
## 1. the shift's brief: "SHIFT n/m", "SPEND €N+" (#86) and the shift's inspections, each with
##    its name and notice, or "No inspection this shift";
## 2. one slide per owned loyalty upgrade: its name, its effect and its condition (the ticket's
##    lines);
## 3. the coupons in play (on the belt, then in the hand; each coupon once): each one's name and
##    its sticker's short effect, over as many slides as they need.
## Upgrades and coupons are skipped when there are none; a slide alone shows no dots and never
## changes. The brief and an upgrade take the first of TIERS' text sizes that fits the slide.
## In planning the brief also gets a sticker key pinned to its bottom (#71, mock-up h1,
## H1_BUILD_SPEC.md section 7; set_key): the first real sticker of each kind on the belt, each
## with its caption ("+3 own rule", "×3 from an item", ...), in order, skipping one that doesn't
## fit the width left (a later, narrower one still may, as h1's "+12 loyalty"). The brief
## first tries the tiers in the room over the key; when none fits, it is built without the key at
## its full height.
##
## MonitorView owns it: it runs it (set_running) while the screen is the channel's, and the shift
## screen fills it through the monitor on every refresh (show_state). A state that keeps the slide
## shown stays on it, its time running on; one that drops it goes back to the brief, and so does
## a new shift (its planning opens on its brief, whichever slide the last one ended on). The channel
## stops while a scan, a notice or the count-up has the screen, and starts again on the slide it
## was on, for a full period.
##
## A change of slide wipes the new one in from the left, WIPE_STEP px at a time over WIPE_S; under
## reduced motion it cuts. Its clock is `now_ms` (tests set it and call tick(); nothing here waits
## in real time). Display only: every text is the definitions' own, from data.

## The slides' text area (the page dots under it) and the dots: DOT_SIZE squares DOT_GAP apart,
## centred under the text, the shown slide's filled with ink, the others hollow.
const SLIDE_HEIGHT := 124.0
const DOT_SIZE := 6.0
const DOT_GAP := 4.0
const DOT_BORDER := 2.0
const DOTS_TOP := 130.0
## The wipe: the new slide shows from the left, a step at a time.
const WIPE_S := 0.24
const WIPE_STEP := 16.0
## Each slide's caption (the count-up's caption voice: the spaced display font in light ink).
const KICKER_HEIGHT := 16.0
const KICKER_SIZE := 12
const KICKER_SPACING := 1
const GAP := 4.0
## The brief's top row: "SHIFT n/m" at the left, "SPEND €N+" at the right (each word in the
## display font, its number in the number font, both at TITLE_SIZE in ink).
const TITLE_HEIGHT := 26.0
const TITLE_SIZE := 20
const WORD_GAP := 6.0
const SHIFT_WORD := "SHIFT"
const SHIFT_TEXT := "%d/%d"
const QUOTA_WORD := LedDisplay.QUOTA_WORD
const QUOTA_TEXT := LedDisplay.QUOTA_AMOUNT
const INSPECTION_KICKER := "INSPECTION"
const NO_INSPECTION_TEXT := "No inspection this shift"
const INSPECTION_NAME_SIZE := 16
const INSPECTION_NAME_HEIGHT := 20.0
const UPGRADE_KICKER := "LOYALTY UPGRADE"
const UPGRADE_NAME_SIZE := 20
const COUPONS_KICKER := "COUPONS IN PLAY"
## A coupon's row: its name in a column COUPON_NAME_WIDTH wide, its sticker's effect beside it.
const COUPON_NAME_WIDTH := 150.0
const COUPON_NAME_SIZE := 14
const COUPON_TEXT_SIZE := 13
const COUPON_COLUMN_GAP := 8.0
## The rule text's and the second line's sizes, largest first: the brief and an upgrade take the
## first that fits SLIDE_HEIGHT (the last one regardless).
const TIERS: Array[Vector2i] = [Vector2i(13, 12), Vector2i(12, 11), Vector2i(11, 10)]
const BRIEF_KEY := "brief"
## The brief's sticker key: a row KEY_HEIGHT tall at the slide's bottom under a dashed rule
## (KEY_RULE thick, in the GAP over the row, KEY_DASH dashes KEY_DASH_GAP apart, in cream shade),
## each entry a real sticker (badge included) then its caption KEY_CAPTION_GAP after it, in the
## bold body font; entries KEY_GAP apart.
const KEY_HEIGHT := 34.0
const KEY_GAP := 12.0
const KEY_RULE := 2.0
const KEY_DASH := 6.0
const KEY_DASH_GAP := 4.0
const KEY_CAPTION_GAP := 4.0
const KEY_CAPTION_SIZE := 12
const KEY_CAPTION_WEIGHT := 700
const KEY_NAME := "Key"
const KEY_TEXT := "%s %s"

## Returns true when the player asked for reduced motion (cuts, no wipe). None means false.
var reduced_motion: Callable = Callable()
## Returns the clock in ms. Tests set it; by default Time.get_ticks_msec.
var now_ms: Callable = Callable()
## The slide's length (ScanTuning.channel_slide_ms), loaded from ScanController.TUNING_PATH
## unless set before the channel enters the tree.
var tuning: ScanTuning

var _slides: Array[Control] = []
var _keys: PackedStringArray = PackedStringArray()
var _index: int = 0
## The clock's time the shown slide came on (or the channel started running again).
var _since: int = 0
var _running: bool = false
var _wipe: Tween
## The state shown (show_state), its signature, and whether it waits for the tree to be built.
var _shift: int = 0
var _shift_count: int = 0
var _quota: int = 0
var _inspections: Array[InspectionDefinition] = []
var _upgrades: Array[UpgradeDefinition] = []
var _coupons: Array[CardDefinition] = []
var _signature: String = ""
var _pending: bool = false
## The planning key's entries (set_key), their signature, and the texts the brief shows.
var _key: Array[StickerSpec] = []
var _key_signature: String = ""
var _key_texts: PackedStringArray = PackedStringArray()


func _init() -> void:
	name = "Channel"
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _ready() -> void:
	if tuning == null:
		tuning = load(ScanController.TUNING_PATH) as ScanTuning
	if _pending:
		_rebuild()


func _process(_delta: float) -> void:
	tick()


func _draw() -> void:
	if _slides.size() < 2:
		return
	for index: int in range(_slides.size()):
		var dot: Rect2 = dot_rect(index)
		draw_rect(dot, Palette.INK)
		if index != _index:
			draw_rect(dot.grow(-DOT_BORDER), Palette.PAPER)


## The shift's state to show: shift `shift` of `shift_count` against `quota`, its `inspections`,
## the owned `upgrades` and the `coupons` in play (belt first, then hand; repeats are shown once).
## Rebuilds the slides only when something shown changed. Measured with the real fonts, so the
## slides are built once the channel is in the tree.
func show_state(
	shift: int,
	shift_count: int,
	quota: int,
	inspections: Array[InspectionDefinition],
	upgrades: Array[UpgradeDefinition],
	coupons: Array[CardDefinition]
) -> void:
	var unique: Array[CardDefinition] = []
	for coupon: CardDefinition in coupons:
		if not unique.has(coupon):
			unique.append(coupon)
	var signature: String = (
		"%d/%d/%d|%s|%s|%s"
		% [shift, shift_count, quota, _ids(inspections), _ids(upgrades), _ids(unique)]
	)
	if signature == _signature and not _slides.is_empty():
		return
	_signature = signature
	if shift != _shift:
		# A new shift's planning opens on its brief, for a full period.
		_index = 0
		_since = _now()
	_shift = shift
	_shift_count = shift_count
	_quota = quota
	_inspections = inspections.duplicate()
	_upgrades = upgrades.duplicate()
	_coupons = unique
	if is_inside_tree():
		_rebuild()
	else:
		_pending = true


## The brief's sticker key: `entries` (PlanningModel.key_entries; empty takes the key off).
## Rebuilds the slides only when the key changed, staying on the slide shown.
func set_key(entries: Array[StickerSpec]) -> void:
	var parts: PackedStringArray = PackedStringArray()
	for entry: StickerSpec in entries:
		parts.append("%d|%s|%d|%s" % [entry.kind, entry.text, entry.badge, entry.badge_text])
	var signature: String = ",".join(parts)
	if signature == _key_signature:
		return
	_key_signature = signature
	_key = entries.duplicate()
	if _signature.is_empty():
		return  # show_state builds the slides.
	if is_inside_tree():
		_rebuild()
	else:
		_pending = true


## The key's entries the brief shows ("+3 own rule"), in order; empty without a key.
func key_texts() -> PackedStringArray:
	return _key_texts


## The brief's key row, or null.
func key_row() -> Control:
	var index: int = _keys.find(BRIEF_KEY)
	if index < 0:
		return null
	return _slides[index].get_node_or_null(KEY_NAME) as Control


## Runs the channel's clock (`running`), or stops it: back on, the slide shown gets a full period.
func set_running(running: bool) -> void:
	if running and not _running:
		_since = _now()
	if not running:
		_end_wipe()
	_running = running


func is_running() -> bool:
	return _running


## Follows the clock: once the shown slide has had its period, the next one comes on (wiped in,
## or cut under reduced motion). Called each frame; tests call it after moving their clock.
func tick() -> void:
	if not _running or _slides.size() < 2:
		return
	if _now() - _since < period_ms():
		return
	_show_slide((_index + 1) % _slides.size(), true)


## A slide's length in ms (ScanTuning.channel_slide_ms).
func period_ms() -> int:
	return tuning.channel_slide_ms


func slide_count() -> int:
	return _slides.size()


## Each slide's key: "brief", "upgrade:<id>" or "coupons:<page>".
func slide_keys() -> PackedStringArray:
	return _keys


func current_index() -> int:
	return _index


func current_key() -> String:
	return _keys[_index] if _index < _keys.size() else ""


func slide(index: int) -> Control:
	return _slides[index]


## Every label of slide `index`, in the order built.
func slide_labels(index: int) -> Array[Label]:
	var labels: Array[Label] = []
	for child: Node in _slides[index].get_children():
		if child is Label and not child.is_queued_for_deletion():
			labels.append(child as Label)
	return labels


func slide_texts(index: int) -> PackedStringArray:
	var texts: PackedStringArray = PackedStringArray()
	for label: Label in slide_labels(index):
		texts.append(label.text)
	return texts


## The wipe running now, or null.
func wipe() -> Tween:
	return _wipe if _wipe != null and _wipe.is_valid() else null


## Page dot `index`'s rect, in the channel's coordinates.
func dot_rect(index: int) -> Rect2:
	var count: int = _slides.size()
	var width: float = count * DOT_SIZE + (count - 1) * DOT_GAP
	var left: float = roundf((size.x - width) / 2.0) + index * (DOT_SIZE + DOT_GAP)
	return Rect2(left, DOTS_TOP, DOT_SIZE, DOT_SIZE)


## Builds every slide again for the state, staying on the slide shown when it is still there.
func _rebuild() -> void:
	_pending = false
	var shown: String = current_key()
	_end_wipe()
	for old: Control in _slides:
		remove_child(old)
		old.queue_free()
	_slides.clear()
	_keys = PackedStringArray()
	_fit_brief()
	for upgrade: UpgradeDefinition in _upgrades:
		_fitted("upgrade:%s" % upgrade.id, _build_upgrade.bind(upgrade))
	_build_coupons()
	var index: int = _keys.find(shown)
	if index < 0:
		_show_slide(0, false)
		return
	# The same slide stays on, its time running on.
	var since: int = _since
	_show_slide(index, false)
	_since = since


## Adds the slide `key` built by `build` (a Callable(slide, sizes) -> bottom) at the first of TIERS
## whose content ends inside SLIDE_HEIGHT, else at the last.
func _fitted(key: String, build: Callable) -> void:
	for tier: int in range(TIERS.size()):
		var page: Control = _new_slide(key)
		var bottom: float = build.call(page, TIERS[tier])
		if bottom <= SLIDE_HEIGHT or tier == TIERS.size() - 1:
			return
		_drop_last_slide()


## The brief: with the key under it at the first of TIERS that fits over the key, else without
## the key (_fitted).
func _fit_brief() -> void:
	_key_texts = PackedStringArray()
	if not _key.is_empty():
		for tier: int in range(TIERS.size()):
			var page: Control = _new_slide(BRIEF_KEY)
			var bottom: float = _build_brief(page, TIERS[tier])
			if bottom <= SLIDE_HEIGHT - KEY_HEIGHT - GAP:
				_add_key(page)
				return
			_drop_last_slide()
	_fitted(BRIEF_KEY, _build_brief)


## The key row at the bottom of `page`: the dashed rule, then each entry (its sticker and
## caption) in order, skipping an entry that doesn't fit the width left (a later, narrower one may).
func _add_key(page: Control) -> void:
	var row: Control = Control.new()
	row.name = KEY_NAME
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	page.add_child(row)
	row.position = Vector2(0.0, SLIDE_HEIGHT - KEY_HEIGHT)
	row.size = Vector2(page.size.x, KEY_HEIGHT)
	row.draw.connect(_draw_key_rule.bind(row))
	var x: float = 0.0
	var middle: float = KEY_HEIGHT / 2.0
	for entry: StickerSpec in _key:
		var sticker: EffectSticker = EffectSticker.new(entry, 0.0)
		var caption_text: String = PlanningModel.key_caption(entry)
		var caption: Label = UiKit.label(caption_text, KEY_CAPTION_SIZE, Palette.INK)
		caption.name = "Caption"
		caption.add_theme_font_override("font", ArtStyle.bold_font(KEY_CAPTION_WEIGHT))
		caption.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		row.add_child(caption)
		var caption_width: float = ceilf(caption.get_minimum_size().x)
		var overhang: float = EffectSticker.badge_overhang(entry)
		var width: float = overhang + sticker.size.x + KEY_CAPTION_GAP + caption_width
		if x + width > row.size.x:
			row.remove_child(caption)
			caption.queue_free()
			sticker.free()
			continue
		sticker.position = Vector2(
			x + overhang, snappedf(middle - sticker.size.y / 2.0, ArtStyle.ART_SCALE)
		)
		row.add_child(sticker)
		row.move_child(sticker, caption.get_index())
		caption.position = Vector2(sticker.position.x + sticker.size.x + KEY_CAPTION_GAP, 0.0)
		caption.size = Vector2(caption_width, KEY_HEIGHT)
		_key_texts.append(KEY_TEXT % [entry.text, caption_text])
		x += width + KEY_GAP
	if _key_texts.is_empty():
		page.remove_child(row)
		row.queue_free()


## The key row's dashed rule along its top, just over it (in the gap under the brief), so a
## burst sticker has the row's whole height.
func _draw_key_rule(row: Control) -> void:
	var x: float = 0.0
	while x < row.size.x:
		var dash: float = minf(KEY_DASH, row.size.x - x)
		row.draw_rect(Rect2(x, -KEY_RULE, dash, KEY_RULE), Palette.CREAM_SHADE)
		x += KEY_DASH + KEY_DASH_GAP


## The brief: SHIFT and QUOTA on the top row, then the inspections (or none).
func _build_brief(page: Control, sizes: Vector2i) -> float:
	var shift_word: Label = UiKit.display_label(SHIFT_WORD, TITLE_SIZE, false)
	var shift_x: float = _add_inline(page, shift_word, 0.0, TITLE_HEIGHT)
	var shift: Label = UiKit.number_label(SHIFT_TEXT % [_shift, _shift_count], TITLE_SIZE, false)
	_add_inline(page, shift, shift_x + WORD_GAP, TITLE_HEIGHT)
	var quota: Label = UiKit.number_label(QUOTA_TEXT % _quota, TITLE_SIZE, false)
	var quota_width: float = _width(page, quota)
	_add_inline(page, quota, page.size.x - quota_width, TITLE_HEIGHT)
	var quota_word: Label = UiKit.display_label(QUOTA_WORD, TITLE_SIZE, false)
	var word_width: float = _width(page, quota_word)
	_add_inline(page, quota_word, quota.position.x - WORD_GAP - word_width, TITLE_HEIGHT)
	var y: float = TITLE_HEIGHT + 2.0 * GAP
	y = _add_kicker(page, INSPECTION_KICKER, y)
	if _inspections.is_empty():
		var none: Label = UiKit.body_label(NO_INSPECTION_TEXT, sizes.x, Palette.GREY_DARK)
		return _add_wrapped(page, none, 0.0, y, page.size.x)
	for inspection: InspectionDefinition in _inspections:
		var title: Label = UiKit.display_label(inspection.display_name, INSPECTION_NAME_SIZE, false)
		y = _add_wrapped(page, title, 0.0, y, page.size.x)
		var notice: Label = UiKit.body_label(inspection.notice_text, sizes.x, Palette.INK)
		y = _add_wrapped(page, notice, 0.0, y, page.size.x) + GAP
	return y - GAP


## An upgrade: its name, its effect and, when it has one, its condition (the ticket's lines).
func _build_upgrade(page: Control, sizes: Vector2i, upgrade: UpgradeDefinition) -> float:
	var y: float = _add_kicker(page, UPGRADE_KICKER, 0.0)
	var title: Label = UiKit.display_label(upgrade.display_name, UPGRADE_NAME_SIZE, false)
	y = _add_wrapped(page, title, 0.0, y, page.size.x)
	var effect: Label = UiKit.body_label(upgrade.effect_text, sizes.x, Palette.INK)
	y = _add_wrapped(page, effect, 0.0, y + GAP / 2.0, page.size.x)
	if upgrade.condition_text.is_empty():
		return y
	var condition: Label = UiKit.body_label(upgrade.condition_text, sizes.y, Palette.GREY_DARK)
	return _add_wrapped(page, condition, 0.0, y + GAP, page.size.x)


## The coupons in play, a row each (name, sticker effect), as many rows to a slide as fit.
func _build_coupons() -> void:
	if _coupons.is_empty():
		return
	var page: Control = null
	var y: float = 0.0
	for coupon: CardDefinition in _coupons:
		if page == null:
			page = _new_slide("coupons:%d" % (_slides.size()))
			y = _add_kicker(page, COUPONS_KICKER, 0.0)
		var bottom: float = _add_coupon_row(page, coupon, y)
		if bottom > SLIDE_HEIGHT and page.get_child_count() > 3:
			# The row moves onto a slide of its own: take its two labels off this one.
			for _label: int in range(2):
				var last: Node = page.get_child(page.get_child_count() - 1)
				page.remove_child(last)
				last.queue_free()
			page = _new_slide("coupons:%d" % (_slides.size()))
			y = _add_kicker(page, COUPONS_KICKER, 0.0)
			bottom = _add_coupon_row(page, coupon, y)
		y = bottom + GAP


## One coupon's row at `y`: its name in its column, its sticker's effect (its rule text when it
## has no sticker text) beside it. Returns the row's bottom.
func _add_coupon_row(page: Control, coupon: CardDefinition, y: float) -> float:
	var title: Label = UiKit.display_label(coupon.display_name, COUPON_NAME_SIZE, false)
	var name_bottom: float = _add_wrapped(page, title, 0.0, y, COUPON_NAME_WIDTH)
	var summary: String = coupon.sticker_summary()
	if summary.is_empty():
		summary = coupon.rule_text
	var effect: Label = UiKit.body_label(summary, COUPON_TEXT_SIZE, Palette.INK)
	var x: float = COUPON_NAME_WIDTH + COUPON_COLUMN_GAP
	return maxf(name_bottom, _add_wrapped(page, effect, x, y, page.size.x - x))


## A slide's caption at `y`. Returns where the slide goes on under it.
func _add_kicker(page: Control, text: String, y: float) -> float:
	var kicker: Label = _kicker_label(text, KICKER_SIZE)
	page.add_child(kicker)
	kicker.position = Vector2(0.0, y)
	kicker.size = Vector2(page.size.x, KICKER_HEIGHT)
	return y + KICKER_HEIGHT


## `label` on one row at `x` from the top, `height` tall, as wide as its text. Returns its end.
func _add_inline(page: Control, label: Label, x: float, height: float) -> float:
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	var width: float = _width(page, label)
	label.position = Vector2(x, 0.0)
	label.size = Vector2(width, height)
	return x + width


## `label`'s text width, in the tree (out of it a label measures with the default size).
func _width(page: Control, label: Label) -> float:
	if label.get_parent() == null:
		page.add_child(label)
	return label.get_minimum_size().x


## `label` at (`x`, `y`), `width` wide, wrapping onto as many lines as it needs. Returns its
## bottom.
func _add_wrapped(page: Control, label: Label, x: float, y: float, width: float) -> float:
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	page.add_child(label)
	label.position = Vector2(x, y)
	label.size = Vector2(width, 1.0)
	# Whole pixels, so the next line starts exactly under it.
	label.size.y = ceilf(label.get_minimum_size().y)
	return y + label.size.y


## A new slide (hidden, clipped for the wipe) for `key`, as wide as the channel.
func _new_slide(key: String) -> Control:
	var page: Control = Control.new()
	page.name = "Slide%d" % _slides.size()
	page.mouse_filter = Control.MOUSE_FILTER_IGNORE
	page.clip_contents = true
	page.visible = false
	add_child(page)
	page.size = Vector2(size.x, SLIDE_HEIGHT)
	_slides.append(page)
	_keys.append(key)
	return page


func _drop_last_slide() -> void:
	var page: Control = _slides.pop_back()
	_keys.remove_at(_keys.size() - 1)
	remove_child(page)
	page.queue_free()


## Shows slide `index` alone (wiped in when `wiped` and motion is on) and restarts its time.
func _show_slide(index: int, wiped: bool) -> void:
	_end_wipe()
	_index = index
	_since = _now()
	for slot: int in range(_slides.size()):
		_slides[slot].visible = slot == index
	queue_redraw()
	if not wiped or _wants_reduced_motion() or _slides.is_empty():
		return
	var page: Control = _slides[index]
	page.size.x = 0.0
	_wipe = create_tween()
	_wipe.tween_method(_wipe_to.bind(page), 0.0, 1.0, WIPE_S)


## The wipe at `progress` (0 to 1): the slide shows from the left, a WIPE_STEP at a time.
func _wipe_to(progress: float, page: Control) -> void:
	page.size.x = minf(size.x, ceilf(size.x * progress / WIPE_STEP) * WIPE_STEP)


## Stops a running wipe, the slides at their full width.
func _end_wipe() -> void:
	if _wipe != null and _wipe.is_valid():
		_wipe.kill()
	_wipe = null
	for page: Control in _slides:
		page.size.x = size.x


func _now() -> int:
	return int(now_ms.call()) if now_ms.is_valid() else Time.get_ticks_msec()


func _wants_reduced_motion() -> bool:
	return reduced_motion.is_valid() and bool(reduced_motion.call())


## A caption in the count-up's voice: the spaced display font in light ink.
static func _kicker_label(text: String, font_size: int) -> Label:
	var label: Label = UiKit.display_label(text, font_size, false)
	label.add_theme_font_override("font", ArtStyle.spaced_display_font(KICKER_SPACING))
	label.add_theme_color_override("font_color", Palette.INK_LIGHT)
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	return label


static func _ids(definitions: Array) -> String:
	var ids: PackedStringArray = PackedStringArray()
	for definition: Resource in definitions:
		ids.append(str(definition.get("id")))
	return ",".join(ids)
