class_name CaptureWebShell
extends RefCounted
## Builds the web build's HTML shell (export/web_shell.html) from its template
## (export/web_shell_template.html) and the boot loader's own pixels (2026-11-13, look A; run by
## tools/boot_frame.sh through capture_title's `--web-shell`). The shell draws the receipt while
## the game downloads, before any of the engine runs, so it can't use the game's fonts: it blits
## stamps the loader's fonts drew here (each receipt word, the live percent's digits and the MB
## line's characters, on the receipt's paper), and for the finished receipt it blits the loader's
## own frame at TOTAL 100%, so the engine's first frame on the web matches it to the pixel. The
## receipt's geometry comes from the loader's constants, never copied by hand.

const LOADER_SCRIPT := "res://ui/boot/boot_loader.gd"
const TEMPLATE := "res://export/web_shell_template.html"
const SHELL := "res://export/web_shell.html"
## The template's placeholder for the receipt's data (a JSON object).
const PLACEHOLDER := "/*NC_RECEIPT_DATA*/null"
## Stamp cells: STAMP_H px tall, the text's baseline STAMP_BASE px down, STAMP_PAD px in from the
## left; two columns of STAMP_ROWS, COLUMN_W px apart.
const STAMP_H := 24
const STAMP_BASE := 18
const STAMP_PAD := 2
const STAMP_ROWS := 24
const COLUMN_W := 320
## The finished receipt's crop on the stage (canvas px), round the slot and the paper.
const DONE_CROP := Rect2i(566, 256, 150, 288)


## Captures the loader's finished receipt and the stamps on `host` (its viewport 1280x720) and
## writes the shell. Errors go to push_error.
static func build(host: Control, loader: Control) -> void:
	var tree: SceneTree = host.get_tree()
	var constants: Dictionary = (load(LOADER_SCRIPT) as GDScript).get_script_constant_map()
	loader.call("show_state", 1.0, 0.0)
	var done: Image = await _grab(tree, host)
	if done.get_size() != Vector2i(1280, 720):
		push_error("--web-shell needs a 1280x720 window, not %s" % done.get_size())
		return
	var crop: Image = done.get_region(DONE_CROP)
	loader.hide()
	var stamps: Array[Dictionary] = _stamp_list(constants)
	var sheet: Control = Control.new()
	sheet.size = Vector2(1280, 720)
	sheet.draw.connect(_draw_stamps.bind(sheet, stamps, constants))
	host.add_child(sheet)
	var grabbed: Image = await _grab(tree, host)
	var height: int = STAMP_ROWS * STAMP_H
	var sheet_image: Image = grabbed.get_region(Rect2i(0, 0, COLUMN_W * 2, height))
	var cells: Dictionary = {}
	for i: int in stamps.size():
		var stamp: Dictionary = stamps[i]
		var key: String = stamp["key"]
		cells[key] = [
			floori(float(i) / STAMP_ROWS) * COLUMN_W,
			(i % STAMP_ROWS) * STAMP_H,
			ceili(stamp["width"]) + STAMP_PAD * 2,
			STAMP_H,
			snappedf(stamp["width"], 0.01),
		]
	var data: Dictionary = {
		"stage": [1280, 720],
		"sky": "#172c2b",
		"receipt_x": constants["RECEIPT_X"],
		"receipt_w": constants["RECEIPT_W"],
		"line_h": constants["LINE_H"],
		"slot_up": constants["SLOT_UP"],
		"doors": _rect_list(constants["OPENINGS"][constants["DOORS"]]),
		"lines": constants["LINES"],
		"line_at": constants["LINE_AT"],
		"line_grow": constants["LINE_GROW"],
		"paper": "#" + Color(constants["PAPER"]).to_html(false),
		"cream_shade": "#" + Color(constants["CREAM_SHADE"]).to_html(false),
		"muted": "#" + Color(constants["MUTED"]).to_html(false),
		"good": "#" + Color(constants["GOOD"]).to_html(false),
		"green_dark": "#" + Color(constants["GREEN_DARK"]).to_html(false),
		"stamp_pad": STAMP_PAD,
		"stamp_base": STAMP_BASE,
		"stamps": _data_uri(sheet_image),
		"cells": cells,
		"done": [DONE_CROP.position.x, DONE_CROP.position.y, _data_uri(crop)],
	}
	var template: String = FileAccess.get_file_as_string(TEMPLATE)
	if not template.contains(PLACEHOLDER):
		push_error("%s has no %s" % [TEMPLATE, PLACEHOLDER])
		return
	var shell: FileAccess = FileAccess.open(ProjectSettings.globalize_path(SHELL), FileAccess.WRITE)
	if shell == null:
		push_error("Can't write %s" % SHELL)
		return
	shell.store_string(template.replace(PLACEHOLDER, JSON.stringify(data)))
	shell.close()
	print("Saved %s" % SHELL)


## The stamps: each receipt word as the loader prints it, the live percent's characters and the
## MB line's (number font, grey).
static func _stamp_list(constants: Dictionary) -> Array[Dictionary]:
	var words: Font = (load(LOADER_SCRIPT) as GDScript).call("words_font")
	var numbers: Font = _font(constants["NUMBER_FONT"], constants["NUMBER_WEIGHT"])
	var small: int = constants["TEXT_SIZE"]
	var big: int = constants["BIG_TEXT_SIZE"]
	var word_size: int = constants["WORD_SIZE"]
	var ink: Color = constants["INK"]
	var muted: Color = constants["MUTED"]
	var list: Array[Dictionary] = []
	list.append(_stamp("NEXT CUSTOMER", words, word_size, ink))
	list.append(_stamp("STORE OPENING", words, word_size, muted))
	for word: String in constants["LINES"]:
		list.append(_stamp(word, words, word_size, ink))
	list.append(_stamp("OK", words, word_size, constants["GREEN_DARK"]))
	list.append(_stamp("STOCK", words, word_size, ink))
	for character: String in "0123456789%":
		list.append(_stamp(character, numbers, big, constants["TOMATO_DARK"], "live"))
	for character: String in "0123456789./ MB":
		list.append(_stamp(character, numbers, small, muted, "mb"))
	return list


static func _stamp(
	text: String, font: Font, text_size: int, colour: Color, prefix: String = ""
) -> Dictionary:
	var width: float = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, text_size).x
	return {
		"key": prefix + ":" + text if prefix != "" else text,
		"text": text,
		"font": font,
		"size": text_size,
		"colour": colour,
		"width": width,
	}


static func _draw_stamps(sheet: Control, stamps: Array[Dictionary], constants: Dictionary) -> void:
	sheet.draw_rect(Rect2(0, 0, COLUMN_W * 2, STAMP_ROWS * STAMP_H), constants["PAPER"])
	for i: int in stamps.size():
		var stamp: Dictionary = stamps[i]
		var at := Vector2(
			floori(float(i) / STAMP_ROWS) * COLUMN_W + STAMP_PAD, (i % STAMP_ROWS) * STAMP_H
		)
		sheet.draw_string(
			stamp["font"],
			at + Vector2(0, STAMP_BASE),
			stamp["text"],
			HORIZONTAL_ALIGNMENT_LEFT,
			-1,
			stamp["size"],
			stamp["colour"]
		)


static func _font(base: Font, weight: int) -> FontVariation:
	var font: FontVariation = FontVariation.new()
	font.base_font = base
	var tag: int = TextServerManager.get_primary_interface().name_to_tag("wght")
	font.variation_opentype = {tag: weight}
	return font


static func _grab(tree: SceneTree, host: Control) -> Image:
	for _frame: int in 4:
		await tree.process_frame
	await RenderingServer.frame_post_draw
	return host.get_viewport().get_texture().get_image()


static func _data_uri(image: Image) -> String:
	return "data:image/png;base64," + Marshalls.raw_to_base64(image.save_png_to_buffer())


static func _rect_list(rect: Rect2) -> Array[float]:
	return [rect.position.x, rect.position.y, rect.size.x, rect.size.y]
