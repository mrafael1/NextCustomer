class_name GradeApply
extends RefCounted
## The difficulty grades' rules applied to the balance data (#182, full build plan 7.5). Pure: a
## graded run plays a copy of the balance (RunState takes its balance), so the balance data and
## every other run are never changed.


## How many grades the balance has (grade 0 to count - 1); 1 when it lists none (grade 0 only).
static func count(balance: BalanceDefinition) -> int:
	return maxi(balance.grades.size(), 1)


## Grade `grade`'s definition, or null when the balance doesn't list it.
static func grade_of(balance: BalanceDefinition, grade: int) -> GradeDefinition:
	if grade < 0 or grade >= balance.grades.size():
		return null
	return balance.grades[grade]


## Whether `grade` is a grade of the balance (0 always is).
static func is_valid(balance: BalanceDefinition, grade: int) -> bool:
	return grade == 0 or grade_of(balance, grade) != null


## The balance a run at `grade` plays: `base` itself for grade 0 (or a grade it doesn't list),
## else a copy with grades 1 to `grade` applied in order, each set field replacing the one below,
## and their twists listed. `base` is never changed.
static func balance_for(base: BalanceDefinition, grade: int) -> BalanceDefinition:
	if grade <= 0 or grade >= base.grades.size():
		return base
	var graded: BalanceDefinition = base.duplicate() as BalanceDefinition
	var twists: Array[GradeTwist] = base.twists.duplicate()
	for index: int in range(1, grade + 1):
		var rules: GradeDefinition = base.grades[index]
		if rules == null:
			continue
		if rules.base_redraws >= 0:
			graded.base_redraws = rules.base_redraws
		if rules.slot_count > 0:
			graded.slot_count = rules.slot_count
		if rules.twist != null and not twists.has(rules.twist):
			twists.append(rules.twist)
	graded.twists = twists
	return graded


## The stacked rules of `grade`, one line each from grade 1 up (empty for grade 0).
static func rule_lines(balance: BalanceDefinition, grade: int) -> PackedStringArray:
	var lines: PackedStringArray = PackedStringArray()
	for index: int in range(1, mini(grade, balance.grades.size() - 1) + 1):
		var rules: GradeDefinition = balance.grades[index]
		if rules != null and rules.twist != null:
			lines.append(rules.twist.format_text(rules.rule_text))  # "{off}": "-25%".
		elif rules != null:
			lines.append(rules.rule_text)
	return lines


## The coins a won run at `grade` adds (its definition's coin_bonus; 0 for none).
static func coin_bonus(balance: BalanceDefinition, grade: int) -> int:
	var rules: GradeDefinition = grade_of(balance, grade)
	return rules.coin_bonus if rules != null else 0
