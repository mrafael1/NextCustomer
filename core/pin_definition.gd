class_name PinDefinition
extends Resource
## A badge pin (#122, decided with the user on 2026-10-31; full build plan 7.4): a talent kept
## between runs and worn on the cashier's name badge before a run, in one of the profile's badge
## slots (BalanceDefinition.pin_slots). A run copies the pins worn when it starts
## (RunState.pins) and never reads the profile again. Pins give new ways to play, never a flat
## payout increase. Unlocked by a milestone (`unlock_condition`, checked at a run's end like a
## deck's), or bought at random for many coins when a milestone is out of reach
## (ProfileState.buy_random_pin); a pin without a condition is owned from the start.
##
## Every exported value defaults to a neutral value (no cards, no effect), because Godot doesn't
## write a value that equals the default into a .tres file.

@export var id: StringName = &""
@export var display_name: String = ""
## The pin's rule in one line, as the badge screen and the cart reveal show it.
@export var rule_text: String = ""
## The few letters on the pin's face when it has no icon (e.g. "2×1"); only a fallback now that
## every pin has its icons (icon, icon_big).
@export var face_text: String = ""
## The face's colour, counted from 1 in the badge screen's pin colours (PinFace.COLOURS: 1 tomato,
## 2 teal, 3 mustard, 4 velvet, 5 green, 6 gold, 7 brown, 8 slate); 0 goes by catalogue place.
@export var face_colour: int = 0
## The icon on the pin's small faces (art/pin_icons/<id>.png, up to 8x8 art px): the lanyard, the
## pin tip and the start screen's compact rows and corkboard badge (PinFace, PinStepDraw). None:
## the face shows face_text. Display only.
@export var icon: Texture2D
## The icon on the pin's large faces (art/pin_icons/<id>_big.png, up to 14x14 art px): the badge
## screen, the new-pin card and the start screen's big rows and badge card. None: the small icon.
## Display only.
@export var icon_big: Texture2D
## The milestone that unlocks it (UnlockCheck); none: owned from the start.
@export var unlock_condition: UnlockCondition
## Cards added to the run's starting deck (after the starter pack is taken).
@export var starting_cards: Array[CardDefinition] = []
## While planning, the player may move hand items between baskets (RunPins.repack), so lone
## items can share one basket and go in one redraw.
@export var repack: bool = false
## Double checkout (#122 part 2): each shift checks out two rows of this many slots (0: one row of
## the balance's slot_count). Row 1 is scored and spent at its checkout and the hand refills to
## its size; both rows' totals count toward the quota.
@export var row_slots: int = 0
## Recycle (#122, the user's call of 2026-11-02): the items a redraw replaces go back into the draw
## pile, shuffled in, so a later redraw can draw them again (instead of being set aside for the
## rest of the shift).
@export var recycle: bool = false
## Redraws added to every shift's own (ShiftLimits.for_shift's `pin_redraws`).
@export var extra_redraws: int = 0
## Stock list (#132): while planning, the next this many items of the draw pile are shown
## (PinPlay.peek).
@export var peek_count: int = 0
## Day off (#132): this many normal days a week (no inspection nor review) may be skipped; a day
## off passes exactly on its quota (PinPlay.can_take_day_off).
@export var days_off_per_week: int = 0
## Golden basket (#132): after a checkout the player may keep this many of its items; they fill
## the first basket of the next shift's hand (PinPlay.keep).
@export var keep_count: int = 0
## Price gun (#132): this many items a shift may gain one of `relabel_tags` while planning
## (PinPlay.relabel), so they join that family's batches and chains.
@export var relabels_per_shift: int = 0
## The families a Price gun may give.
@export var relabel_tags: PackedStringArray = PackedStringArray()
## Express lane (#132): slots added to the row (negative: a shorter row), before the upgrades'
## and the day events' (ShiftLimits.for_shift's base slots).
@export var slot_delta: int = 0
## Events every shift is played under while the pin is worn (WeekSchedule.shift_events, after
## the week event): Express lane's ×2 on the row's ends.
@export var events: Array[InspectionDefinition] = []
