class_name PinStepDraw
extends RefCounted
## YOUR BUILD's BADGE PINS step (BuildPage, v1.32; the mock-up start_boosters_v3's F5): over the
## dimmed room, a popup with the CASHIER badge wearing the pins being chosen, a row per owned pin
## (its face, name, rule and a WEAR / WORN key), then a grey row per pin still locked (its
## milestone in place of the rule; polish audit v1.36, in place of "+N MORE PINS TO EARN" over an
## empty band), compact rows past FULL_ROWS rows, the packs' gate note with ESC · BACK and the
## confirm key (WEAR 1 PIN / NO PINS). NO PIN IS FINE TOO stands under the badge's NO PIN. The
## number keys still wear the owned rows in order; the rows show no numbers.
## On confirm the worn pin flies to the corkboard badge.
## Pin faces copy PinFace's look on the art grid: an ink rim, a dark band, a glint, the pin's icon
## (its letters when it has none).

const ROW_X := 102
const ROW_TOP := 30
const KEY_MARGINS := Vector4i(3, 7, 3, 4)
## Up to this many rows (owned and locked pins), a row each at full height (face, name, two rule
## lines, WEAR key); more (the catalogue's 8) use compact rows, so all of them fit above the packs'
## gate note.
const FULL_ROWS := 5
const COMPACT_ROW_H := 18
## The rows' bottom limit under the step's top: the gate note's divider (the box height - 66).
const ROWS_BOTTOM := 186
## The smallest face (art px) that shows a pin's large icon (PinDefinition.icon_big): the big
## rows' 20; the compact rows' 14 and the corkboard badge's 16 show the small one.
const BIG_FACE := 20
## Under the badge's NO PIN (the choice the packs' note used to carry); the step's way back;
## a locked row's key.
const NO_PIN_NOTE := "NO PIN IS FINE TOO"
const BACK_NOTE := "ESC · BACK"
const LOCKED_TEXT := "LOCKED"

static var _faces: Dictionary[String, ImageTexture] = {}


static func draw(pen: ArtPen, page: BuildPage) -> void:
	if page.pins_open:
		_step(pen, page)
	elif page.fly_pin != null and not page.rm and page.now - page.fly_t < page.tuning.pin_fly_s:
		_fly(pen, page)


## The step's top (art px) this frame: it pops up from 30 px lower.
static func box_y(page: BuildPage) -> float:
	var u: float = page.now - page.pins_t
	var q: float = 1.0
	if not page.rm:
		q = BoosterPageDraw.e_back(clampf(u / maxf(page.tuning.pins_pop_s, 0.001), 0.0, 1.0))
	return roundf(BuildPage.PIN_BOX.position.y + (1.0 - q) * 30)


static func _step(pen: ArtPen, page: BuildPage) -> void:
	if page.now < page.pins_t:
		return
	var box: Rect2i = BuildPage.PIN_BOX
	pen.r(0, 28, BoosterArt.AW, BoosterArt.AH - 28, Color(Palette.TEAL_BLACK, 0.6))
	var x: float = box.position.x
	var y: float = box_y(page)
	var w: float = box.size.x
	var h: float = box.size.y
	pen.r(x + 3, y + 3, w, h, Palette.INK)
	pen.nine(BoosterArt.POPUP, x, y, w, h, Vector4i(4, 4, 4, 4))
	pen.chunky("BADGE PINS", x + 10, y + 9, Palette.INK)
	var slots: int = maxi(1, page.run.balance.pin_slots)
	var slot_text: String = "1 SLOT" if slots == 1 else "%d SLOTS" % slots
	pen.caps(
		"WORN PINS: ACTIVE THIS RUN · " + slot_text,
		x + w - 10,
		y + 11,
		Palette.TEAL_SHADE,
		1.0,
		HORIZONTAL_ALIGNMENT_RIGHT
	)
	pen.r(x + 8, y + 22, w - 16, 1, Palette.CREAM_SHADE)
	var tick: Dictionary = page.pins_tick
	var pop_t: float = -INF
	if not tick.is_empty() and page.pins_sel.has(tick.pin as PinDefinition):
		pop_t = tick.t
	badge(pen, page, x + 10, y + 30, 82, 92, page.pins_sel, 28, pop_t)
	var names: PackedStringArray = []
	for pin: PinDefinition in page.pins_sel:
		names.append(pin.display_name.to_upper())
	var worn_line: String = " + ".join(names) if not names.is_empty() else "NO PIN"
	var worn_lines: PackedStringArray = ArtPen.pix_wrap(worn_line, 86)
	for j: int in mini(2, worn_lines.size()):
		pen.pix(
			worn_lines[j],
			x + 51,
			y + 128 + j * 10,
			Palette.INK if not names.is_empty() else Palette.STEEL_SHADE,
			1.0,
			HORIZONTAL_ALIGNMENT_CENTER
		)
	if names.is_empty():
		pen.caps(
			NO_PIN_NOTE, x + 51, y + 140, Palette.STEEL_SHADE, 1.0, HORIZONTAL_ALIGNMENT_CENTER
		)
	var note: String = (
		"One slot: picking another pin swaps the worn one."
		if slots == 1
		else "A full badge swaps its first pin."
	)
	var note_lines: PackedStringArray = BoosterCardDraw.wrap_words(note, 5.2, 80)
	for j: int in note_lines.size():
		pen.atk(note_lines[j], x + 51, y + 152 + j * 6.4, 5.2, Palette.INK_LIGHT, 700)
	var owned: Array[PinDefinition] = page.pins.owned()
	var locked: Array[PinDefinition] = locked_pins(page)
	var count: int = owned.size() + locked.size()
	for k: int in owned.size():
		_row(pen, page, owned[k], k, count, y)
	for k: int in locked.size():
		_locked_row(pen, page, locked[k], owned.size() + k, count, y)
	_gate_note(pen, page, x, y, w, h)
	var rect: Rect2 = confirm_rect(y)
	var worn: int = page.pins_sel.size()
	var label: String = "NO PINS"
	if worn > 0:
		label = "WEAR 1 PIN" if worn == 1 else "WEAR %d PINS" % worn
	var sub: String = "ENTER · DEAL PACKS" if page.packs_held() else "ENTER · KEEP PACKS"
	var armed: float = page.pins_t + 0.3 if page.now - page.pins_t > 0.3 else INF
	BuildPageDraw.key_button(pen, page, rect, label, sub, true, "pinsok", armed)


static func confirm_rect(top: float) -> Rect2:
	var box: Rect2i = BuildPage.PIN_BOX
	return Rect2(box.position.x + box.size.x - 134, top + box.size.y - 42, 120, 28)


## Row `k` of `count` rows (owned, then locked) under the step's top `top` (compact rows past
## FULL_ROWS).
static func row_rect(k: int, count: int, top: float) -> Rect2:
	var box: Rect2i = BuildPage.PIN_BOX
	var h: int = row_height(count)
	return Rect2(
		box.position.x + ROW_X, top + ROW_TOP + k * (h + row_gap(count)), box.size.x - ROW_X - 10, h
	)


static func row_height(count: int) -> int:
	return BuildPage.PIN_ROW_H if count <= FULL_ROWS else COMPACT_ROW_H


static func row_gap(count: int) -> int:
	return 2 if count <= FULL_ROWS else 1


## The catalogue's pins the profile doesn't own yet, in data order (their grey rows follow the
## owned ones).
static func locked_pins(page: BuildPage) -> Array[PinDefinition]:
	var owned: Array[PinDefinition] = page.pins.owned()
	var found: Array[PinDefinition] = []
	for pin: PinDefinition in page.pins.catalogue():
		if not owned.has(pin):
			found.append(pin)
	return found


## A locked pin's line: its milestone ("Unlock: Win a run").
static func unlock_text(pin: PinDefinition) -> String:
	var condition: UnlockCondition = pin.unlock_condition
	return "Unlock: %s" % condition.summary() if condition != null else pin.rule_text


static func _row(
	pen: ArtPen, page: BuildPage, pin: PinDefinition, k: int, count: int, y: float
) -> void:
	if count > FULL_ROWS:
		_compact_row(pen, page, pin, k, count, y)
		return
	var rect: Rect2 = row_rect(k, count, y)
	var rx: float = rect.position.x
	var rw: float = rect.size.x
	var rh: float = rect.size.y
	var on: bool = page.pins_sel.has(pin)
	var hv: bool = page.is_hovered("pin_%s" % pin.id)
	var lift: float = 1.0 if hv and not page.rm else 0.0
	var ry: float = rect.position.y - lift
	pen.r(rx, ry, rw, rh, Palette.INK)
	pen.r(
		rx + 1,
		ry + 1,
		rw - 2,
		rh - 2,
		Palette.MUSTARD_PALE if on else (Palette.PAPER if hv else Palette.CREAM)
	)
	if on:
		pen.r(rx + 1, ry + 1, 2, rh - 2, Palette.MUSTARD)
	face(pen, pin, page.pins.index_of(pin), rx + 5, ry + 3, 20)
	pen.pix(pin.display_name.to_upper(), rx + 30, ry + 3, Palette.INK)
	var rule: PackedStringArray = BoosterCardDraw.wrap_words(pin.rule_text, 5.2, rw - 66)
	for j: int in mini(2, rule.size()):
		pen.atk(
			rule[j],
			rx + 30,
			ry + 17 + j * 6.2,
			5.2,
			Palette.INK_LIGHT,
			700,
			HORIZONTAL_ALIGNMENT_LEFT
		)
	var kx: float = rx + rw - 32
	var ky: float = ry + 4
	pen.nine(BoosterArt.KEY_LIT if on else BoosterArt.KEY, kx, ky, 28, 13, KEY_MARGINS)
	pen.caps(
		"WORN" if on else "WEAR",
		kx + 14,
		ky + 3,
		Palette.TOMATO_DARK if on else Palette.INK,
		1.0,
		HORIZONTAL_ALIGNMENT_CENTER
	)
	if on:
		pen.tex(BoosterArt.TICK, rx - 8, ry + 9)


## A compact row (more than FULL_ROWS pins owned): a smaller face, the name, one rule line (a
## smaller size when the rule is long), the WEAR / WORN key with the row's number before it.
static func _compact_row(
	pen: ArtPen, page: BuildPage, pin: PinDefinition, k: int, count: int, y: float
) -> void:
	var rect: Rect2 = row_rect(k, count, y)
	var rx: float = rect.position.x
	var rw: float = rect.size.x
	var rh: float = rect.size.y
	var on: bool = page.pins_sel.has(pin)
	var hv: bool = page.is_hovered("pin_%s" % pin.id)
	var ry: float = rect.position.y - (1.0 if hv and not page.rm else 0.0)
	pen.r(rx, ry, rw, rh, Palette.INK)
	pen.r(
		rx + 1,
		ry + 1,
		rw - 2,
		rh - 2,
		Palette.MUSTARD_PALE if on else (Palette.PAPER if hv else Palette.CREAM)
	)
	if on:
		pen.r(rx + 1, ry + 1, 2, rh - 2, Palette.MUSTARD)
		pen.tex(BoosterArt.TICK, rx - 8, ry + 5)
	face(pen, pin, page.pins.index_of(pin), rx + 4, ry + 2, 14)
	pen.pix(pin.display_name.to_upper(), rx + 22, ry + 2, Palette.INK)
	var rule_w: float = compact_rule_width(rw)
	var size: float = compact_rule_size(pin.rule_text, rule_w)
	var rule: PackedStringArray = BoosterCardDraw.wrap_words(pin.rule_text, size, rule_w)
	if not rule.is_empty():
		pen.atk(
			rule[0], rx + 22, ry + 15.5, size, Palette.INK_LIGHT, 700, HORIZONTAL_ALIGNMENT_LEFT
		)
	var kx: float = rx + rw - 31
	var ky: float = ry + 2
	pen.nine(BoosterArt.KEY_LIT if on else BoosterArt.KEY, kx, ky, 28, 13, KEY_MARGINS)
	pen.caps(
		"WORN" if on else "WEAR",
		kx + 14,
		ky + 3,
		Palette.TOMATO_DARK if on else Palette.INK,
		1.0,
		HORIZONTAL_ALIGNMENT_CENTER
	)


## A locked pin's grey row (row `k` of `count`): a grey face, the name, its milestone in place of
## the rule and LOCKED in place of the key; it takes no click.
static func _locked_row(
	pen: ArtPen, _page: BuildPage, pin: PinDefinition, k: int, count: int, y: float
) -> void:
	var compact: bool = count > FULL_ROWS
	var rect: Rect2 = row_rect(k, count, y)
	var rx: float = rect.position.x
	var ry: float = rect.position.y
	var rw: float = rect.size.x
	var rh: float = rect.size.y
	pen.r(rx, ry, rw, rh, Palette.STEEL_PALE)
	pen.r(rx + 1, ry + 1, rw - 2, rh - 2, Palette.CREAM_SHADE)
	var d: int = 14 if compact else 20
	var key: String = "locked|%d" % d
	if not _faces.has(key):
		_faces[key] = _disc(d, Palette.STEEL_PALE, Palette.STEEL_SHADE, Palette.CREAM_SHADE)
	var fx: float = rx + (4 if compact else 5)
	var fy: float = ry + (2 if compact else 3)
	pen.tex(_faces[key], fx, fy)
	pen.caps(
		pin.face_text,
		fx + d / 2.0,
		fy + d / 2.0 - 3,
		Palette.CREAM,
		1.0,
		HORIZONTAL_ALIGNMENT_CENTER
	)
	var tx: float = rx + (22 if compact else 30)
	pen.pix(pin.display_name.to_upper(), tx, ry + (2 if compact else 3), Palette.STEEL_SHADE)
	pen.atk(
		unlock_text(pin),
		tx,
		ry + (15.5 if compact else 17.0),
		5.2 if not compact else compact_rule_size(unlock_text(pin), compact_rule_width(rw)),
		Palette.STEEL_SHADE,
		700,
		HORIZONTAL_ALIGNMENT_LEFT
	)
	pen.caps(
		LOCKED_TEXT,
		rx + rw - (17 if compact else 18),
		ry + (5 if compact else 7),
		Palette.STEEL_SHADE,
		1.0,
		HORIZONTAL_ALIGNMENT_CENTER
	)


## A compact row's rule width (art px) in a row `rw` wide: from the name's left to the row's
## number before the key.
static func compact_rule_width(rw: float) -> float:
	return rw - 22 - 40


## A compact row's rule size: 5.2 art px, 4.6 when that needs two lines.
static func compact_rule_size(rule: String, width: float) -> float:
	return 5.2 if BoosterCardDraw.wrap_words(rule, 5.2, width).size() <= 1 else 4.6


static func _gate_note(
	pen: ArtPen, page: BuildPage, x: float, y: float, w: float, h: float
) -> void:
	pen.r(x + 8, y + h - 66, w - 16, 1, Palette.CREAM_SHADE)
	if page.packs_held():
		for k: int in 3:
			var bx: float = x + 12 + k * 6
			var by: float = y + h - 46 + k
			pen.r(bx, by, 14, 20, Palette.INK)
			pen.r(bx + 1, by + 1, 12, 18, Palette.TEAL_SHADE)
			pen.r(bx + 2, by + 2, 10, 16, Palette.TEAL)
			pen.r(bx + 5, by + 8, 4, 4, Palette.CREAM)
		pen.tex(BoosterArt.PADLOCK, x + 22, y + h - 30)
		pen.pix("3 STARTER PACKS", x + 44, y + h - 45, Palette.INK)
		pen.caps("DEAL WHEN YOU CONFIRM", x + 44, y + h - 33, Palette.TOMATO_DARK)
		pen.caps(BACK_NOTE, x + 44, y + h - 24, Palette.STEEL_SHADE)
	else:
		pen.pix("PACKS ALREADY DEALT", x + 12, y + h - 45, Palette.INK)
		pen.caps("CHANGING PINS KEEPS YOUR PACKS", x + 12, y + h - 33, Palette.TEAL_SHADE)
		pen.caps("ESC KEEPS THE WORN PIN", x + 12, y + h - 24, Palette.STEEL_SHADE)


## The CASHIER badge (art/scenery/pin_badge's look, larger): brass plate, teal band, paper face,
## one pin place per slot (`pins` worn there, else a dashed ring); a pin toggled at `pop_t` pops.
static func badge(
	pen: ArtPen,
	page: BuildPage,
	x: float,
	y: float,
	w: float,
	h: float,
	pins: Array[PinDefinition],
	d: int,
	pop_t: float
) -> void:
	pen.r(x + 2, y + 2, w, h, Palette.INK)
	pen.r(x, y, w, h, Palette.INK)
	pen.r(x + 1, y + 1, w - 2, h - 2, Palette.BRASS)
	pen.r(x + 1, y + 1, w - 2, 1, Palette.MUSTARD_LIGHT)
	pen.r(x + 1, y + h - 2, w - 2, 1, Palette.BRASS_DARK)
	pen.r(x + 3, y + 3, w - 6, 16, Palette.INK)
	pen.r(x + 4, y + 4, w - 8, 14, Palette.TEAL)
	pen.r(x + 4, y + 4, w - 8, 1, Palette.TEAL_LIGHT)
	pen.caps("NEXT", x + w / 2.0, y + 5, Palette.PAPER, 1.0, HORIZONTAL_ALIGNMENT_CENTER)
	pen.caps("CUSTOMER", x + w / 2.0, y + 11, Palette.PAPER, 1.0, HORIZONTAL_ALIGNMENT_CENTER)
	pen.r(x + 3, y + 19, w - 6, h - 22, Palette.INK)
	pen.r(x + 4, y + 20, w - 8, h - 24, Palette.PAPER)
	pen.caps("CASHIER", x + w / 2.0, y + 24, Palette.TEAL_SHADE, 1.0, HORIZONTAL_ALIGNMENT_CENTER)
	var i: float = x + 8
	while i < x + w - 8:
		pen.r(i, y + 31, 1, 1, Palette.CREAM_DARKEST)
		i += 2
	var slots: int = maxi(1, page.run.balance.pin_slots)
	var cx: float = x + w / 2.0
	var cy: float = y + 33 + roundf((h - 37) / 2.0)
	for k: int in slots:
		var px: float = roundf(cx - (slots * d + (slots - 1) * 4) / 2.0 + k * (d + 4))
		var py: float = roundf(cy - d / 2.0)
		if k < pins.size():
			var u: float = page.now - pop_t
			var pop: int = 0
			if not page.rm and u >= 0.0 and u < 0.14:
				pop = 2 if u < 0.07 else 1
			face(pen, pins[k], page.pins.index_of(pins[k]), px - pop, py - pop, d + pop * 2, d)
		else:
			empty(pen, px, py, d)


## The confirmed pin flying from the step's badge to the corkboard's, shrinking on an arc.
static func _fly(pen: ArtPen, page: BuildPage) -> void:
	var u: float = clampf((page.now - page.fly_t) / page.tuning.pin_fly_s, 0.0, 1.0)
	var q: float = BoosterPageDraw.e_in(u)
	var box: Rect2i = BuildPage.PIN_BOX
	var fx: float = box.position.x + 10 + 41 - 14
	var fy: float = box.position.y + 30 + 33 + roundf((92 - 37) / 2.0) - 14
	var to: Vector2 = Vector2(BuildPage.CORK_PIN)
	var d: int = roundi(lerpf(28, 16, q))
	if d % 2 == 1:
		d += 1
	face(
		pen,
		page.fly_pin,
		page.pins.index_of(page.fly_pin),
		roundf(lerpf(fx, to.x, q)),
		roundf(lerpf(fy, to.y, q) - sin(u * PI) * 30),
		d
	)


## The icon a `d` art px face of `pin` shows, as its texture (one art px a texel): the large one
## (PinDefinition.icon_big) from BIG_FACE up, else the small one (PinFace.icon_for).
static func icon_for(pin: PinDefinition, d: int) -> Texture2D:
	return PinFace.icon_for(pin, d, BIG_FACE)


## Pin `pin` (catalogue place `index`) as a `d` art px face at (`x`, `y`): its icon centred
## (icon_for), else its letters. A popping face passes its resting size as `rest_d`, so it keeps
## the resting face's icon through the pop.
static func face(
	pen: ArtPen, pin: PinDefinition, index: int, x: float, y: float, d: int, rest_d: int = 0
) -> void:
	var key: String = "%s|%d|%d" % [pin.id, index, d]
	if not _faces.has(key):
		var colours: Array = PinFace.COLOURS[PinFace.colour_index(pin, index)]
		_faces[key] = _disc(d, colours[0], colours[1], colours[2])
	pen.tex(_faces[key], x, y)
	var icon: Texture2D = icon_for(pin, rest_d if rest_d > 0 else d)
	if icon != null:
		var art: Vector2 = icon.get_size()
		pen.tex(icon, x + floorf((d - art.x) / 2.0), y + floorf((d - art.y) / 2.0))
		return
	var colours2: Array = PinFace.COLOURS[PinFace.colour_index(pin, index)]
	var dark: Color = colours2[1]
	var letters: String = pin.face_text
	if d >= 26:
		var words: ImageTexture = ArtPen.word_texture(letters, Palette.PAPER, true)
		var lx: float = x + d / 2.0 - roundf(words.get_width() / 2.0)
		pen.chunky(letters, lx + 1, y + d / 2.0 - 3, dark)
		pen.chunky(letters, lx, y + d / 2.0 - 4, Palette.PAPER)
	else:
		pen.caps(letters, x + d / 2.0 + 1, y + d / 2.0 - 2, dark, 1.0, HORIZONTAL_ALIGNMENT_CENTER)
		pen.caps(
			letters, x + d / 2.0, y + d / 2.0 - 3, Palette.PAPER, 1.0, HORIZONTAL_ALIGNMENT_CENTER
		)


## An empty pin place: a dashed grey ring.
static func empty(pen: ArtPen, x: float, y: float, d: int) -> void:
	var key: String = "empty|%d" % d
	if not _faces.has(key):
		var image: Image = Image.create(d, d, false, Image.FORMAT_RGBA8)
		var rr: float = d / 2.0
		for row: int in d:
			for col: int in d:
				var dist: float = Vector2(col + 0.5 - rr, row + 0.5 - rr).length()
				if dist <= rr and dist > rr - 1 and row % 3 != 0:
					image.set_pixel(col, row, Palette.GREY)
		_faces[key] = ImageTexture.create_from_image(image)
	pen.tex(_faces[key], x, y)


static func _disc(d: int, face_colour: Color, dark: Color, light: Color) -> ImageTexture:
	var image: Image = Image.create(d, d, false, Image.FORMAT_RGBA8)
	var rr: float = d / 2.0
	for row: int in d:
		for col: int in d:
			var dist: float = Vector2(col + 0.5 - rr, row + 0.5 - rr).length()
			if dist > rr:
				continue
			var colour: Color = face_colour
			if dist > rr - 1:
				colour = Palette.INK
			elif dist > rr - 2:
				colour = dark
			elif Vector2(col + 0.5 - rr * 0.6, row + 0.5 - rr * 0.6).length() < rr * 0.24:
				colour = light
			image.set_pixel(col, row, colour)
	return ImageTexture.create_from_image(image)


## The step's hits (modal: the background swallows every other click).
static func hits(page: BuildPage, list: Array[Dictionary]) -> void:
	var full: Rect2 = Rect2(0, 28, BoosterArt.AW, BoosterArt.AH - 28)
	var held: bool = page.packs_held()
	list.append(
		{
			"rect": full,
			"id": "modal_pins",
			"act": page.flash.bind("CONFIRM YOUR PINS FIRST" if held else "CONFIRM, OR ESC TO KEEP")
		}
	)
	var top: float = BuildPage.PIN_BOX.position.y
	var owned: Array[PinDefinition] = page.pins.owned()
	var count: int = owned.size() + locked_pins(page).size()
	for k: int in owned.size():
		list.append(
			{
				"rect": row_rect(k, count, top),
				"id": "pin_%s" % owned[k].id,
				"act": page.pins.toggle.bind(owned[k])
			}
		)
	list.append({"rect": confirm_rect(top), "id": "pinsok", "act": page.pins.confirm.bind("click")})
