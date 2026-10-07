class_name ResultsPanel
extends PanelContainer
## The win and lose screens (plan section 2): the ended run's result, its history and the coins
## at the bottom of the final receipt (full build plan 7.1). It only shows the run; New run and
## Export log are reported to the shift screen.

signal new_run_requested
signal export_requested

var _headline: Label
var _detail: Label
var _history_view: RunHistoryView
var _coin_receipt: CoinReceipt
var _new_run_button: Button
## Like the reward panel: New run waits for the mouse to be released after the panel appears.
var _armed_ms: int = 0


func _init() -> void:
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = Palette.PAPER
	style.border_color = Palette.INK
	style.set_border_width_all(4)
	style.set_corner_radius_all(12)
	style.set_content_margin_all(24)
	add_theme_stylebox_override("panel", style)
	var column: VBoxContainer = VBoxContainer.new()
	column.add_theme_constant_override("separation", 16)
	add_child(column)
	_headline = UiKit.label("", 48, Palette.INK)
	_headline.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(_headline)
	_detail = UiKit.label("", 20, Palette.INK)
	_detail.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(_detail)
	_history_view = RunHistoryView.new()
	_history_view.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	column.add_child(_history_view)
	_coin_receipt = CoinReceipt.new()
	_coin_receipt.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	column.add_child(_coin_receipt)
	var buttons: HBoxContainer = HBoxContainer.new()
	buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	buttons.add_theme_constant_override("separation", 16)
	column.add_child(buttons)
	_new_run_button = UiKit.button(buttons, "New run", func() -> void: new_run_requested.emit(), 22)
	UiKit.button(buttons, "Export log", func() -> void: export_requested.emit(), 18)
	visible = false


func _process(_delta: float) -> void:
	if not visible or not _new_run_button.disabled or Time.get_ticks_msec() < _armed_ms:
		return
	if not Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		_new_run_button.disabled = false


## Shows a won or lost run: `result` is its last checkout, `coins_total` the profile's coins
## after the run, or -1 when the profile couldn't be saved.
func show_results(run: RunState, result: ScoreResult, coins_total: int) -> void:
	var won: bool = run.phase == RunState.Phase.WON
	_headline.text = "RUN WON!" if won else "RUN OVER"
	_headline.add_theme_color_override("font_color", Palette.GOOD if won else Palette.TOMATO)
	if won:
		_detail.text = (
			"All %d shifts cleared. Last checkout €%d / €%d."
			% [run.shift_count(), result.total, run.quota()]
		)
	else:
		_detail.text = (
			"Shift %d / %d: €%d of €%d, short by €%d."
			% [
				run.shift_index + 1,
				run.shift_count(),
				result.total,
				run.quota(),
				run.quota() - result.total,
			]
		)
	_history_view.show_history(run.history)
	_coin_receipt.show_payout(CoinPayout.for_run(run), coins_total)
	_new_run_button.disabled = true
	_armed_ms = Time.get_ticks_msec() + 350
	UiKit.pop_in(self)


## The line under the headline (for tests).
func detail_text() -> String:
	return _detail.text
