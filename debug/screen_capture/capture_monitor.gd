class_name CaptureMonitor
extends RefCounted
## The screen capture's monitor cases (PR #138 monitor): `--monitor=<case>` sets the fixed shift up
## with CASES' row (its inspection and upgrades) and fully scans that case's item (the nth of its
## card on the belt, or in the hand), pinned on the monitor, with the shift's opening notice
## cleared so nothing covers the item column. The file is shift_screen_monitor_<case>_<w>x<h>.png.
## A case with a "page" (from 0) holds the item column's rows on that page (MonitorStepPages), so
## every page of a paged item is captured (#138 review).

const ARGUMENT := "--monitor="
const FILE_PART := "monitor_%s_"
## Frames for the shift's items to be laid out before one is scanned, then the wait for the bay's
## swap and the item column's fades (real time).
const SETTLE_FRAMES := 2
const SETTLE_S := ScannerBay.PLAN_OUT_S + BayBed.FALL_S + 1.0
## The wait for a turned page's fade.
const PAGE_S := 0.6
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
	"penalty": {"row": ["soup", "frozen_peas"], "scan": "soup"},
	"unused": {"row": ["eggs", "batteries"], "scan": "eggs"},
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
	var page: int = int(case.get("page", -1))
	var pages: MonitorStepPages = screen._monitor.item_column().pages
	if pages != null:
		pages.hold(true)  # The capture shows one page, never a turn half done.
		if page >= 0 and page < pages.count():
			while pages.page() != page:
				pages.turn(1)
			await node.get_tree().create_timer(PAGE_S).timeout
	return FILE_PART % case["name"]
