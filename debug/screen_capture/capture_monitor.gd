class_name CaptureMonitor
extends RefCounted
## The screen capture's monitor cases (PR #138 monitor): `--monitor=<case>` sets the fixed shift up
## with CASES' row (its inspection and upgrades) and fully scans that case's item (the nth of its
## card on the belt, or in the hand), pinned on the monitor, with the shift's opening notice
## cleared so nothing covers the item column. The file is shift_screen_monitor_<case>_<w>x<h>.png.
## A case with a "page" (from 0) holds the item column's rows on that page (MonitorStepPages), so
## every page of a paged item is captured (#138 review). A case's "cue" (v1.15 review) shows the
## page cue at "rest" (the pointer off the monitor: its ground unlit) or "hot" (under the pointer);
## else it is lit, as while the pages are held.

const ARGUMENT := "--monitor="
const FILE_PART := "monitor_%s_"
## Frames for the shift's items to be laid out before one is scanned, then the wait for the bay's
## swap and the item column's fades (real time).
const SETTLE_FRAMES := 2
const SETTLE_S := ScannerBay.PLAN_OUT_S + BayBed.FALL_S + 1.0
## The wait for a turned page's fade.
const PAGE_S := 0.6
## The "carry" cases' upgrades (v1.15).
const CARRY_UPGRADES: Array[String] = [
	"category_engine_lv2", "dairy_regulars", "dairy_aisle_run_lv2", "breakfast_aisle_run_lv3"
]
## Each case: its belt, its inspection ("" for none), its upgrades, the card scanned and which of
## its copies (from 0; "hand" scans the hand's).
const CASES: Dictionary[String, Dictionary] = {
	"plain": {"row": ["bread"], "scan": "bread"},
	"bare": {"row": ["potatoes"], "upgrades": ["extra_redraw"], "scan": "potatoes"},
	"families": {"row": ["stale_popcorn", "crisps"], "scan": "stale_popcorn"},
	"split": {"row": ["breakfast_sticker", "croissant"], "scan": "breakfast_sticker"},
	"long": {"row": ["banana", "lemon", "banana"], "scan": "lemon"},
	"bonuses":
	{"row": ["strawberries", "banana", "two_for_one", "banana"], "scan": "banana", "nth": 1},
	"large":
	{
		"row":
		[
			"banana_golden",
			"lemon_golden",
			"banana_golden",
			"lemon_golden",
			"banana_golden",
			"lemon_golden",
			"banana_golden"
		],
		"upgrades": ["produce_aisle_run_lv3", "lemon_squeezer", "banana_stand"],
		"scan": "banana_golden",
		"nth": 3
	},
	"large_p2":
	{
		"row":
		[
			"banana_golden",
			"lemon_golden",
			"banana_golden",
			"lemon_golden",
			"banana_golden",
			"lemon_golden",
			"banana_golden"
		],
		"upgrades": ["produce_aisle_run_lv3", "lemon_squeezer", "banana_stand"],
		"scan": "banana_golden",
		"nth": 3,
		"page": 1
	},
	"bonuses_p2":
	{
		"row": ["strawberries", "banana", "two_for_one", "banana"],
		"scan": "banana",
		"nth": 1,
		"page": 1
	},
	"bonuses_p3":
	{
		"row": ["strawberries", "banana", "two_for_one", "banana"],
		"scan": "banana",
		"nth": 1,
		"page": 2
	},
	"coupon": {"row": ["banana", "two_for_one", "banana"], "scan": "two_for_one"},
	"multipack":
	{
		"row": ["eggs", "bread", "milk", "multipack", "milk", "milk", "milk"],
		"inspection": "spot_check",
		"scan": "multipack"
	},
	"zero":
	{
		"row": ["eggs", "bread", "milk", "multipack", "milk", "milk", "milk"],
		"inspection": "spot_check",
		"scan": "milk"
	},
	"paged":
	{
		"row": ["eggs", "bread", "milk", "multipack", "milk", "milk", "milk"],
		"inspection": "spot_check",
		"scan": "milk",
		"nth": 3
	},
	# PR #138 round 7: every coupon card's scan (the "gives" rows and the coupon's "+N€").
	"multipack_p2":
	{
		"row": ["eggs", "bread", "milk", "multipack", "milk", "milk", "milk"],
		"inspection": "spot_check",
		"scan": "multipack",
		"page": 1
	},
	"multipack_many":
	{"row": ["milk", "multipack", "milk", "milk", "milk", "milk"], "scan": "multipack"},
	"coupon_opening": {"row": ["opening_deal", "milk", "bread"], "scan": "opening_deal"},
	"coupon_repeat": {"row": ["bread", "repeat", "milk"], "scan": "repeat"},
	"coupon_markdown": {"row": ["bread", "milk", "final_markdown"], "scan": "final_markdown"},
	"coupon_bundle": {"row": ["bread", "bundle", "butter"], "scan": "bundle"},
	"coupon_clearance": {"row": ["clearance_tag", "milk", "bread"], "scan": "clearance_tag"},
	"coupon_swap": {"row": ["bread", "shelf_swap", "milk", "butter"], "scan": "shelf_swap"},
	# v1.00: a coupon that adds nothing (no target after it) leaves its payout zone empty.
	"coupon_wasted": {"row": ["milk", "multipack"], "scan": "multipack"},
	# v1.11: Eggs in slot 3 under the Spot check (it pays 0€) gives Banana ×2: its "gives" row's
	# equation under it, the Spot check on its own line; in the count, Banana's ×2 from Eggs in the
	# bag (the bag glyph beside the giver).
	"eggs_banana":
	{"row": ["bread", "milk", "eggs", "banana"], "inspection": "spot_check", "scan": "eggs"},
	"eggs_banana_target":
	{"row": ["bread", "milk", "eggs", "banana"], "inspection": "spot_check", "scan": "banana"},
	"penalty": {"row": ["soup", "frozen_peas"], "scan": "soup"},
	# Point A (2026-11-05): Repeat copies Golden Milk; Milk's scan has no "to Repeat" row, its
	# quiet "Copied by Repeat" note by its total; Repeat's scan reads "Copied from Golden Milk"
	# with the copied amount. Repeat first copies nothing: no note on Milk.
	"repeat_source": {"row": ["butter", "milk_golden", "repeat"], "scan": "milk_golden"},
	"repeat_copy": {"row": ["butter", "milk_golden", "repeat"], "scan": "repeat"},
	"repeat_none": {"row": ["repeat", "milk_golden", "butter"], "scan": "milk_golden"},
	"repeat_none_copy": {"row": ["repeat", "milk_golden", "butter"], "scan": "repeat"},
	"unused": {"row": ["eggs", "batteries"], "scan": "eggs"},
	# v1.15 (the user's "fix the missing subtotal across pages"): Golden Milk 6€, +8 +12 +3 = 29€
	# on page 1, then ×2 ×4 ×5 = 1160€ on page 2, which starts "Carried forward 29€".
	"carry":
	{
		"row": ["eggs", "milk", "milk", "milk_golden", "two_for_one", "milk_golden"],
		"upgrades": CARRY_UPGRADES,
		"scan": "milk_golden",
		"nth": 1
	},
	"carry_p2":
	{
		"row": ["eggs", "milk", "milk", "milk_golden", "two_for_one", "milk_golden"],
		"upgrades": CARRY_UPGRADES,
		"scan": "milk_golden",
		"nth": 1,
		"page": 1
	},
	"carry_rest":
	{
		"row": ["eggs", "milk", "milk", "milk_golden", "two_for_one", "milk_golden"],
		"upgrades": CARRY_UPGRADES,
		"scan": "milk_golden",
		"nth": 1,
		"cue": "rest"
	},
	"carry_hot":
	{
		"row": ["eggs", "milk", "milk", "milk_golden", "two_for_one", "milk_golden"],
		"upgrades": CARRY_UPGRADES,
		"scan": "milk_golden",
		"nth": 1,
		"page": 1,
		"cue": "hot"
	},
	# v1.15 review: a huge payout on 4 pages (BIG_LINES at BIG_PAYOUT, debug only, as the ladder):
	# the total keeps clear of the cue, which goes compact.
	"big": {"row": ["potatoes"], "upgrades": ["extra_redraw"], "scan": "potatoes", "big": true},
	"hand": {"row": ["bread"], "scan": "coffee", "hand": true},
	"ladder":
	{"row": ["potatoes"], "upgrades": ["extra_redraw"], "scan": "potatoes", "ladder": true},
}
## The "ladder" case (PR #138 round 3): the scanned item's column (Potatoes: no description, so
## the four rows fit one page) shows LADDER_LINES (a factor of each strength,
## MonitorStepRow.factor_step) at LADDER_PAYOUT instead of its own score, so one capture shows the
## factors' ink ramp. Debug only: these lines are no score.
const LADDER_LINES: Array[String] = [
	"× Snack deal  ×1",
	"× 2 for 1  ×2",
	"× Multipack  ×3",
	"× Banana stand  ×5",
]
const LADDER_PAYOUT := 90
const BIG_PAYOUT := 12345678
const BIG_ROWS := 14
const UPGRADE_IDS: Array[String] = ["coupon_engine", "slot_engine", "category_engine"]


## The case named `name` with its defaults filled in (an unknown name: the plain case).
static func spec(case_name: String) -> Dictionary:
	var found: Dictionary = CASES.get(case_name, CASES["plain"]).duplicate()
	found["name"] = case_name if CASES.has(case_name) else "plain"
	var upgrades: Array[String] = []
	upgrades.assign(found.get("upgrades", UPGRADE_IDS))
	found["upgrades"] = upgrades
	var row: Array[String] = []
	row.assign(found["row"])
	found["row"] = row
	return found


## Scans `case`'s item on `screen` once its items are laid out, clears the opening notice and waits
## for the bay to settle; returns the file name's part.
static func scan(node: Node, screen: ShiftScreen, case: Dictionary) -> String:
	for _frame: int in range(SETTLE_FRAMES):
		await node.get_tree().process_frame
	var cards: Array[CardInstance] = screen.run.hand()
	if not bool(case.get("hand", false)):
		cards = screen.run.row
	var nth: int = int(case.get("nth", 0))
	for card: CardInstance in cards:
		if card.definition.id != StringName(case["scan"]):
			continue
		if nth > 0:
			nth -= 1
			continue
		screen.debug_scan(card)
		break
	screen._notice_label.clear_notice()
	await node.get_tree().create_timer(SETTLE_S).timeout
	if bool(case.get("ladder", false)):
		var column: MonitorItemColumn = screen._monitor.item_column()
		var shown: CardDefinition = column.shown_definition()
		var ladder: ScanController.ItemLines = ScanController.ItemLines.new()
		ladder.payout = LADDER_PAYOUT
		ladder.lines = PackedStringArray(LADDER_LINES)
		ladder.fizzles.resize(LADDER_LINES.size())
		ladder.fizzles.fill(false)
		column.show_item(shown, shown.tags, ladder)
		await node.get_tree().process_frame
	if bool(case.get("big", false)):
		var column: MonitorItemColumn = screen._monitor.item_column()
		var shown: CardDefinition = column.shown_definition()
		column.show_item(shown, shown.tags, _big_lines(shown.base))
		await node.get_tree().process_frame
	var page: int = int(case.get("page", -1))
	var pages: MonitorStepPages = screen._monitor.item_column().pages
	if pages != null:
		pages.hold(true)  # The capture shows one page, never a turn half done.
		if page >= 0 and page < pages.count():
			while pages.page() != page:
				pages.turn(1)
			await node.get_tree().create_timer(PAGE_S).timeout
		var cue: MonitorPager = pages.pager()
		if cue != null and case.get("cue", "") == "rest":
			cue.lit = false
		elif cue != null and case.get("cue", "") == "hot":
			cue.mouse_entered.emit()
	return FILE_PART % case["name"]


## The "big" case's lines: BIG_ROWS bonuses then factors from `base` to BIG_PAYOUT (debug only).
static func _big_lines(base: int) -> ScanController.ItemLines:
	var big: ScanController.ItemLines = ScanController.ItemLines.new()
	var value: int = base
	for index: int in range(BIG_ROWS - 1):
		value += 10 * (index + 1)
		big.lines.append("+ Bonus %d  +%d€" % [index + 1, 10 * (index + 1)])
		big.runs.append(value)
	big.lines.append("× Override  =%d€" % BIG_PAYOUT)
	big.runs.append(BIG_PAYOUT)
	big.fizzles.resize(big.lines.size())
	big.fizzles.fill(false)
	big.payout = BIG_PAYOUT
	return big
