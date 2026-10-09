"""Fits the quota curve and the coin amounts to simulated runs (full build plan section 8, issue #41).
Python 3.11+ standard library only. Run from the repo root:

    python tools/quota_fit.py RECORDS [options]

RECORDS is the run-record file the balance simulator writes with --records (tools/balance_sim.sh
... --quotas=0 --records=res://reports/records.json). No simulator choice reads the quota, so a run
played with every quota at 0 is, shift for shift, the same run as under any other curve until its
first failed shift (the run's RNG is used the same way at every passed checkout). This tool
replays every recorded run under a candidate curve and coin amounts: Big basket's raise from the
shift after its pick (ShiftLimits.raised_quota), the loss at the first total under the quota, and
the coins (CoinPayout: the table by shifts passed plus one overtime coin per overtime_coin_euros of
summed margin, at most overtime_coin_max). A recorded run that ended before the last shift without
failing the candidate curve was cut by the quotas it was played with, so it can't be replayed; it
is counted and the curve's numbers are flagged.

Decided with the user (#41): the curve is fitted to the sensible player ("greedy@sensible": greedy
drafting, rows played by SimHillClimb). Shift 1 is passed by at least --shift1 (0.97) of the runs
and shift 2 by at least --shift2 (0.95) of the runs that reach it; from shift 3 on, every shift
fails the same share of the runs that reach it, set so the run win rate is --win (0.375). A
shift's quota is the highest whole number that the required share of the runs reaching it still
meet, and the curve always rises by at least 1 a shift; a shift held at that floor can miss its
target, and the report warns about it. The coins keep plan 7.1's rule (a run lost on shift 1 or 2
pays no table coins, a won run pays 2) with the fewest shifts a lost run must pass to pay 1 that
still meets the coin targets (the median run pays 1, a great run 2-3, 30 unlocks in 25-40 runs),
and the overtime coin set so just over --overtime-share (0.10) of the runs earn it (so a great
run, the 90th percentile, can reach 3).

Options:
    --scenario=KEY       the scenario the curve is fitted to (default: greedy@sensible, else the
                         first one in the file)
    --curve=A,B,...      evaluate this curve instead of fitting one
    --coins=A,B,...      evaluate this coin table (one entry per number of shifts passed, 0 to
                         the shift count) instead of fitting one
    --overtime-euros=N   with --coins: the overtime coin's euros (0: no overtime coin; default the
                         records' amount)
    --overtime-max=N     with --coins: the most overtime coins a run pays (default the records')
    --win=F --shift1=F --shift2=F --overtime-share=F   the fit's targets (see above)
    --report=PATH        the text report's file (default reports/quota_fit/report.txt)
    --json=PATH          also write the numbers as JSON

The report goes to stdout and to the report file. Exit code 0 on success, 2 on bad arguments or an
unreadable record file. Tests: python tools/quota_fit_test.py
"""

from __future__ import annotations

import argparse
import json
import math
import sys
from collections import Counter, defaultdict
from dataclasses import dataclass, field
from pathlib import Path
from typing import Any

REPO = Path(__file__).resolve().parent.parent
DEFAULT_REPORT = REPO / "reports" / "quota_fit" / "report.txt"
DEFAULT_SCENARIO = "greedy@sensible"
# Plan 7.1: a won run pays 2 table coins, and the collection holds 30 capsules.
WON_RUN_COINS = 2
UNLOCKS = 30
# A great run is the 90th percentile of coins per run (decided with the user in #40).
GREAT_RUN_PERCENTILE = 90
# The share of runs whose shift-1 margin alone earns the overtime coin stays under this (#41).
SHIFT1_OVERTIME_MAX = 0.02
# Coin targets (plan 7.1, #41): the median run pays 1, a great run 3, and 30 unlocks take
# 25-40 runs; the fit aims at the middle of that range.
TARGET_RUNS = (25.0, 40.0)
TARGET_RUNS_MIDDLE = 32.5


@dataclass
class Run:
    """One recorded run: per played shift its total, the inspection it was played under, the
    upgrade taken after it and the quota percent that upgrade adds (Big basket)."""

    seed: int
    totals: list[int]
    inspections: list[str]
    upgrades_taken: list[str]
    percents_taken: list[int]
    # The card ids of each shift's hand at checkout (empty lists in older records).
    hands: list[list[str]] = field(default_factory=list)


@dataclass
class Records:
    quotas: list[int]
    coins_by_shifts_passed: list[int]
    overtime_coin_euros: int
    overtime_coin_max: int
    scenarios: dict[str, list[Run]]


@dataclass
class CoinRule:
    table: list[int]
    overtime_euros: int
    overtime_max: int

    def coins(self, shifts_passed: int, overtime: int) -> int:
        coins = self.table[min(shifts_passed, len(self.table) - 1)] if self.table else 0
        if self.overtime_euros > 0:
            coins += min(overtime // self.overtime_euros, self.overtime_max)
        return coins


@dataclass
class Outcome:
    """A run replayed under a curve."""

    shifts_passed: int
    won: bool
    overtime: int
    shift1_margin: int
    # The quota of each shift it played (raised by Big basket), in order.
    quotas: list[int] = field(default_factory=list)
    # False when the recorded run ended early without failing this curve (can't be replayed).
    complete: bool = True


def raised_quota(base: int, percent: int) -> int:
    """ShiftLimits.raised_quota: rounded up to whole euros."""
    return math.ceil(base * (100 + percent) / 100.0) if percent > 0 else base


def load_records(path: Path) -> Records:
    data = json.loads(path.read_text(encoding="utf-8"))
    percents: dict[str, int] = {k: int(v) for k, v in data["upgrade_quota_percent"].items()}
    scenarios: dict[str, list[Run]] = {}
    for key, entries in data["scenarios"].items():
        runs = []
        for entry in entries:
            shifts = entry["shifts"]
            upgrades = [str(s.get("upgrade_taken", "")) for s in shifts]
            runs.append(Run(
                seed=int(entry["run_seed"]),
                totals=[int(s["total"]) for s in shifts],
                inspections=[str(s.get("inspection", "")) for s in shifts],
                upgrades_taken=upgrades,
                percents_taken=[percents.get(u, 0) for u in upgrades],
                hands=[[str(card) for card in s.get("hand", [])] for s in shifts],
            ))
        scenarios[key] = runs
    return Records(
        quotas=[int(q) for q in data["quotas"]],
        coins_by_shifts_passed=[int(c) for c in data["coins_by_shifts_passed"]],
        overtime_coin_euros=int(data["overtime_coin_euros"]),
        overtime_coin_max=int(data["overtime_coin_max"]),
        scenarios=scenarios,
    )


def replay(run: Run, curve: list[int]) -> Outcome:
    percent = 0
    passed = 0
    overtime = 0
    quotas: list[int] = []
    for index, base in enumerate(curve):
        if index >= len(run.totals):
            return Outcome(passed, False, overtime, _shift1_margin(run, curve), quotas, False)
        quota = raised_quota(base, percent)
        quotas.append(quota)
        total = run.totals[index]
        if total < quota:
            return Outcome(passed, False, overtime, _shift1_margin(run, curve), quotas)
        passed += 1
        overtime += total - quota
        percent += run.percents_taken[index]
    return Outcome(passed, True, overtime, _shift1_margin(run, curve), quotas)


def _shift1_margin(run: Run, curve: list[int]) -> int:
    return run.totals[0] - curve[0] if run.totals and curve else 0


def nearest_rank(values: list[int], percent: int) -> int:
    """SimSummary.nearest_rank; -1 with no values."""
    if not values:
        return -1
    ordered = sorted(values)
    rank = math.ceil(percent / 100.0 * len(ordered))
    return ordered[min(max(rank - 1, 0), len(ordered) - 1)]


def fit_curve(runs: list[Run], shifts: int, win: float, shift1: float, shift2: float) -> list[int]:
    """The curve for these targets: shift 1 and 2 by their pass shares, then one failure share for
    every later shift, found by bisection so the win rate comes closest to `win`."""
    def curve_for(fail: float) -> list[int]:
        curve: list[int] = []
        for index in range(shifts):
            keep = shift1 if index == 0 else shift2 if index == 1 else 1.0 - fail
            curve.append(_quota_for_share(runs, curve, keep))
        return curve

    low, high = 0.0, 1.0
    best = curve_for(0.0)
    for _ in range(40):
        middle = (low + high) / 2.0
        curve = curve_for(middle)
        rate = win_rate(runs, curve)
        if abs(rate - win) < abs(win_rate(runs, best) - win):
            best = curve
        if rate > win:
            low = middle
        else:
            high = middle
    return best


def _quota_for_share(runs: list[Run], curve: list[int], keep: float) -> int:
    """The highest quota for the next shift that at least `keep` of the runs reaching it meet
    (each against its own raised quota), and at least 1 more than the previous shift's."""
    index = len(curve)
    floor = curve[-1] + 1 if curve else 0
    reaching: list[tuple[int, int]] = []
    for run in runs:
        outcome = replay(run, curve)
        if outcome.won and outcome.complete and len(run.totals) > index:
            percent = sum(run.percents_taken[:index])
            reaching.append((run.totals[index], percent))
    if not reaching:
        return floor
    need = math.ceil(keep * len(reaching) - 1e-9)
    # Pass count only falls as the quota rises: bisect for the highest quota keeping `need`.
    low, high = floor, max(t for t, _ in reaching) + 1
    if _meeting(reaching, low) < need:
        return floor
    while high - low > 1:
        middle = (low + high) // 2
        if _meeting(reaching, middle) >= need:
            low = middle
        else:
            high = middle
    return low


def _meeting(reaching: list[tuple[int, int]], quota: int) -> int:
    return sum(1 for total, percent in reaching if total >= raised_quota(quota, percent))


def win_rate(runs: list[Run], curve: list[int]) -> float:
    outcomes = [replay(run, curve) for run in runs]
    return sum(1 for o in outcomes if o.won) / len(outcomes) if outcomes else 0.0


def fit_coins(runs: list[Run], curve: list[int], overtime_share: float, overtime_max: int) -> CoinRule:
    """Plan 7.1's coin shape for this curve: table entries 0 below `first_paid` shifts passed (at
    least 2: a run lost on shift 1 or 2 pays nothing), 1 from there, WON_RUN_COINS for a won run,
    and the overtime coin's euros so about `overtime_share` of the runs earn it. Of the candidates
    meeting the targets (the median run pays 1, a great run 2-3, 30 unlocks in 25-40 runs, the
    shift-1 margin alone earns the overtime coin in under 2% of runs), the one that pays lost runs
    from the earliest shift ("something even for a lost run"); with none, the nearest to 32.5 runs."""
    shifts = len(curve)
    outcomes = [replay(run, curve) for run in runs]
    euros = overtime_euros_for_share(outcomes, overtime_share)
    nearest: tuple[float, CoinRule] | None = None
    for first_paid in range(2, shifts):
        table = [0 if passed < first_paid else 1 for passed in range(shifts)] + [WON_RUN_COINS]
        rule = CoinRule(table, euros, overtime_max)
        stats = coin_stats(outcomes, rule)
        if meets_coin_targets(stats):
            return rule
        distance = abs(stats["runs_to_unlock_all"] - TARGET_RUNS_MIDDLE)
        if nearest is None or distance < nearest[0]:
            nearest = (distance, rule)
    if nearest is None:
        return CoinRule([0, 0] + [1] * (shifts - 2) + [WON_RUN_COINS], euros, overtime_max)
    return nearest[1]


def meets_coin_targets(stats: dict[str, Any]) -> bool:
    return (
        stats["median"] == 1
        and 2 <= stats["great_run"] <= 3
        and TARGET_RUNS[0] <= stats["runs_to_unlock_all"] <= TARGET_RUNS[1]
        and stats["shift1_overtime_share"] < SHIFT1_OVERTIME_MAX
    )


def overtime_euros_for_share(outcomes: list[Outcome], share: float) -> int:
    """The largest whole euros for which more than `share` of the runs earn an overtime coin
    (the runs whose overtime reaches it), so a 90th-percentile run can earn it at 0.10. A share of
    0 means no overtime coin (0 euros)."""
    margins = sorted((o.overtime for o in outcomes), reverse=True)
    if not margins or share <= 0:
        return 0
    earning = math.floor(share * len(margins)) + 1
    if earning > len(margins):
        return 1
    return max(margins[earning - 1], 1)


def coin_stats(outcomes: list[Outcome], rule: CoinRule) -> dict[str, Any]:
    coins = [rule.coins(o.shifts_passed, o.overtime) for o in outcomes]
    mean = sum(coins) / len(coins) if coins else 0.0
    counts = Counter(coins)
    overtime_runs = sum(
        1 for o in outcomes if rule.overtime_euros > 0 and o.overtime >= rule.overtime_euros
    )
    shift1 = sum(
        1 for o in outcomes if rule.overtime_euros > 0 and o.shift1_margin >= rule.overtime_euros
    )
    return {
        "mean": mean,
        "median": nearest_rank(coins, 50),
        "great_run": nearest_rank(coins, GREAT_RUN_PERCENTILE),
        "runs_by_amount": [counts.get(a, 0) for a in range(max(coins, default=0) + 1)],
        "runs_to_unlock_all": UNLOCKS / mean if mean > 0 else -1.0,
        "overtime_share": overtime_runs / len(outcomes) if outcomes else 0.0,
        "shift1_overtime_share": shift1 / len(outcomes) if outcomes else 0.0,
    }


def evaluate(runs: list[Run], curve: list[int], rule: CoinRule) -> dict[str, Any]:
    outcomes = [replay(run, curve) for run in runs]
    shifts = len(curve)
    reached = [0] * shifts
    passed = [0] * shifts
    totals_reaching: list[list[int]] = [[] for _ in range(shifts)]
    for run, outcome in zip(runs, outcomes):
        for index in range(min(shifts, outcome.shifts_passed + 1, len(run.totals))):
            reached[index] += 1
            totals_reaching[index].append(run.totals[index])
            if index < outcome.shifts_passed:
                passed[index] += 1
    return {
        "runs": len(runs),
        "incomplete": sum(1 for o in outcomes if not o.complete),
        "win_rate": sum(1 for o in outcomes if o.won) / len(runs) if runs else 0.0,
        "mean_shifts_passed": sum(o.shifts_passed for o in outcomes) / len(runs) if runs else 0.0,
        "shifts": [
            {
                "shift": index + 1,
                "quota": curve[index],
                "reached": reached[index],
                "passed": passed[index],
                "pass_rate": passed[index] / reached[index] if reached[index] else 0.0,
                "reach_rate": reached[index] / len(runs) if runs else 0.0,
                "p50_total": nearest_rank(totals_reaching[index], 50),
            }
            for index in range(shifts)
        ],
        "coins": coin_stats(outcomes, rule),
        "inspections": inspection_stats(runs, outcomes),
        "upgrades": upgrade_stats(runs, outcomes, rule, shifts),
        "cards": card_stats(runs, outcomes),
    }


def inspection_stats(runs: list[Run], outcomes: list[Outcome]) -> dict[str, dict[str, Any]]:
    """Per inspection: shifts played under it and how many of those failed (a fair split puts
    each inspection's share of failed inspected shifts near its share of inspected shifts)."""
    played: Counter = Counter()
    failed: Counter = Counter()
    for run, outcome in zip(runs, outcomes):
        for index in range(min(outcome.shifts_passed + 1, len(run.totals), len(outcome.quotas))):
            inspection = run.inspections[index]
            if not inspection:
                continue
            played[inspection] += 1
            if index == outcome.shifts_passed and not outcome.won:
                failed[inspection] += 1
    all_played = sum(played.values())
    all_failed = sum(failed.values())
    return {
        name: {
            "played": played[name],
            "failed": failed[name],
            "fail_rate": failed[name] / played[name] if played[name] else 0.0,
            "share_of_inspected": played[name] / all_played if all_played else 0.0,
            "share_of_failures": failed[name] / all_failed if all_failed else 0.0,
        }
        for name in sorted(played)
    }


def upgrade_stats(
    runs: list[Run], outcomes: list[Outcome], rule: CoinRule, shifts: int
) -> dict[str, dict[str, Any]]:
    """Per upgrade, over the runs that owned it on a shift they played (an upgrade is owned from
    the shift after its pick): their win rate, the pass rate of the last two shifts among the runs
    that reached them owning it, and the share of those runs earning the overtime coin."""
    counts: dict[str, Counter] = defaultdict(Counter)
    for run, outcome in zip(runs, outcomes):
        played = len(outcome.quotas)
        owned_from: dict[str, int] = {}
        for index, upgrade in enumerate(run.upgrades_taken[: max(played - 1, 0)]):
            if upgrade and upgrade not in owned_from:
                owned_from[upgrade] = index + 1
        for upgrade, first in owned_from.items():
            entry = counts[upgrade]
            entry["runs"] += 1
            entry["won"] += int(outcome.won)
            entry["overtime"] += int(
                rule.overtime_euros > 0 and outcome.overtime >= rule.overtime_euros
            )
            for index in range(max(shifts - 2, first), min(played, shifts)):
                entry["late_reached"] += 1
                entry["late_passed"] += int(index < outcome.shifts_passed)
    return {
        name: {
            "runs": entry["runs"],
            "win_rate": entry["won"] / entry["runs"],
            "late_pass_rate": (
                entry["late_passed"] / entry["late_reached"] if entry["late_reached"] else 0.0
            ),
            "overtime_share": entry["overtime"] / entry["runs"],
        }
        for name, entry in sorted(counts.items())
    }


# A card is reported once at least this many played shifts held it and this many didn't.
CARD_MIN_SHIFTS = 30


def card_stats(runs: list[Run], outcomes: list[Outcome]) -> dict[str, dict[str, Any]]:
    """Per card: the pass rate of the shifts played (under the curve) whose hand held it, and of
    those whose hand didn't, from shift 2 on (the deck is still the starting deck on shift 1).
    A large gap marks a card the run can't do without, e.g. a single point of failure."""
    held: Counter = Counter()
    held_passed: Counter = Counter()
    played = 0
    passed = 0
    for run, outcome in zip(runs, outcomes):
        for index in range(1, min(len(outcome.quotas), len(run.hands))):
            ok = index < outcome.shifts_passed
            played += 1
            passed += int(ok)
            for card in set(run.hands[index]):
                held[card] += 1
                held_passed[card] += int(ok)
    result: dict[str, dict[str, Any]] = {}
    for card in sorted(held):
        without = played - held[card]
        if held[card] < CARD_MIN_SHIFTS or without < CARD_MIN_SHIFTS:
            continue
        result[card] = {
            "held": held[card],
            "pass_rate_held": held_passed[card] / held[card],
            "pass_rate_without": (passed - held_passed[card]) / without,
        }
    return result


def warnings(curve: list[int], result: dict[str, Any], targets: dict[str, float]) -> list[str]:
    """The fitted scenario's missed shift targets, and the quotas held at the previous one + 1."""
    found: list[str] = []
    for index, key in enumerate(["shift1", "shift2"][: len(curve)]):
        rate = result["shifts"][index]["pass_rate"]
        if rate < targets[key]:
            found.append(f"shift {index + 1} passed by {rate:.1%}, under its {targets[key]:.0%} target")
    for index in range(1, len(curve)):
        if curve[index] == curve[index - 1] + 1:
            found.append(
                f"shift {index + 1}'s quota {curve[index]} is held at the previous quota + 1, so its"
                " share of runs failed differs from the target"
            )
    return found


def format_report(
    records: Records, scenario: str, curve: list[int], rule: CoinRule, fitted: bool,
    results: dict[str, dict[str, Any]], targets: dict[str, float],
) -> str:
    lines: list[str] = []
    lines.append("Quota fit (issue #41) - " + ("fitted" if fitted else "given") + f" curve for {scenario}")
    lines.append(
        f"Targets: shift 1 passed by {targets['shift1']:.0%}, shift 2 by {targets['shift2']:.0%} of the runs"
        f" reaching it, win rate {targets['win']:.1%}; overtime coin for ~{targets['overtime_share']:.0%} of runs"
    )
    lines.append(f"Recorded with quotas {records.quotas}")
    lines.append(f"Curve: {curve}")
    lines.append(
        f"Coins: table {rule.table} - one overtime coin per {rule.overtime_euros} euros of summed margin,"
        f" at most {rule.overtime_max}"
    )
    for warning in warnings(curve, results[scenario], targets):
        lines.append("WARNING: " + warning)
    for key, result in results.items():
        lines.append("")
        lines.append(f"== {key} ({result['runs']} runs) ==")
        if result["incomplete"]:
            lines.append(
                f"WARNING: {result['incomplete']} runs ended early under the recorded quotas and can't be"
                " replayed under this curve (record with --quotas=0)"
            )
        lines.append(
            f"Win rate {result['win_rate']:.1%} - mean shifts passed {result['mean_shifts_passed']:.2f}"
        )
        lines.append("Shift  Quota  Reached  Passed  Pass rate  Median total")
        for shift in result["shifts"]:
            lines.append(
                f"{shift['shift']:5d}  {shift['quota']:5d}  {shift['reach_rate']:7.1%}  {shift['passed']:6d}"
                f"  {shift['pass_rate']:9.1%}  {shift['p50_total']:12d}"
            )
        coins = result["coins"]
        amounts = ", ".join(
            f"{amount}: {count / result['runs']:.1%}" for amount, count in enumerate(coins["runs_by_amount"])
        )
        lines.append(
            f"Coins per run: mean {coins['mean']:.2f} - median {coins['median']} - p90 {coins['great_run']}"
            f" (a great run) - {amounts}"
        )
        lines.append(
            f"Runs to 30 unlocks (30 / mean coins): {coins['runs_to_unlock_all']:.1f} - overtime coin"
            f" {coins['overtime_share']:.1%} of runs - shift-1 margin alone earns it in"
            f" {coins['shift1_overtime_share']:.1%}"
        )
        if result["inspections"]:
            lines.append("Inspection          Played  Failed  Fail rate  Share of inspected  Share of failures")
            for name, entry in result["inspections"].items():
                lines.append(
                    f"{name:<19} {entry['played']:6d}  {entry['failed']:6d}  {entry['fail_rate']:9.1%}"
                    f"  {entry['share_of_inspected']:18.1%}  {entry['share_of_failures']:17.1%}"
                )
        if result["upgrades"]:
            lines.append("Upgrade             Runs  Win rate  Last 2 shifts passed  Overtime coin")
            for name, entry in result["upgrades"].items():
                lines.append(
                    f"{name:<19} {entry['runs']:4d}  {entry['win_rate']:8.1%}  {entry['late_pass_rate']:20.1%}"
                    f"  {entry['overtime_share']:13.1%}"
                )
        if result["cards"]:
            lines.append(
                f"Cards (shifts 2+, {CARD_MIN_SHIFTS}+ shifts with and without): pass rate with it in hand"
                " / without, by gap"
            )
            ordered = sorted(
                result["cards"].items(),
                key=lambda item: item[1]["pass_rate_without"] - item[1]["pass_rate_held"],
            )
            lines.append("  " + ", ".join(
                f"{card} {entry['pass_rate_held']:.0%}/{entry['pass_rate_without']:.0%}"
                for card, entry in ordered
            ))
    return "\n".join(lines)


def parse_ints(text: str, name: str) -> list[int]:
    try:
        values = [int(part) for part in text.split(",") if part.strip()]
    except ValueError:
        raise SystemExit(f"error: --{name} needs whole numbers, got {text}")
    if not values or any(v < 0 for v in values):
        raise SystemExit(f"error: --{name} needs whole numbers of at least 0, got {text}")
    return values


def main(argv: list[str]) -> int:
    parser = argparse.ArgumentParser(description="Fit the quota curve and coins to simulated runs.")
    parser.add_argument("records")
    parser.add_argument("--scenario", default="")
    parser.add_argument("--curve", default="")
    parser.add_argument("--coins", default="")
    parser.add_argument("--overtime-euros", type=int, default=None)
    parser.add_argument("--overtime-max", type=int, default=None)
    parser.add_argument("--win", type=float, default=0.375)
    parser.add_argument("--shift1", type=float, default=0.97)
    parser.add_argument("--shift2", type=float, default=0.95)
    parser.add_argument("--overtime-share", type=float, default=0.10)
    parser.add_argument("--report", default=str(DEFAULT_REPORT))
    parser.add_argument("--json", default="")
    try:
        args = parser.parse_args(argv)
    except SystemExit as error:
        return 0 if error.code == 0 else 2
    try:
        records = load_records(Path(args.records))
    except (OSError, ValueError, KeyError, TypeError) as error:
        print(f"error: {args.records} is not a run-record file ({error})", file=sys.stderr)
        return 2
    if not records.scenarios:
        print(f"error: {args.records} holds no runs", file=sys.stderr)
        return 2
    scenario = args.scenario or (
        DEFAULT_SCENARIO if DEFAULT_SCENARIO in records.scenarios else next(iter(records.scenarios))
    )
    if scenario not in records.scenarios or not records.scenarios[scenario]:
        print(f"error: no runs for scenario {scenario} (have {list(records.scenarios)})", file=sys.stderr)
        return 2
    runs = records.scenarios[scenario]
    shifts = len(records.quotas)
    try:
        if args.curve:
            curve = parse_ints(args.curve, "curve")
            if len(curve) != shifts:
                raise SystemExit(f"error: --curve needs {shifts} values, got {len(curve)}")
        else:
            curve = fit_curve(runs, shifts, args.win, args.shift1, args.shift2)
        if args.coins:
            table = parse_ints(args.coins, "coins")
            if len(table) != shifts + 1:
                raise SystemExit(f"error: --coins needs {shifts + 1} values, got {len(table)}")
            euros = records.overtime_coin_euros if args.overtime_euros is None else args.overtime_euros
            cap = records.overtime_coin_max if args.overtime_max is None else args.overtime_max
            rule = CoinRule(table, max(euros, 0), max(cap, 0))
        else:
            cap = 1 if args.overtime_max is None else args.overtime_max
            rule = fit_coins(runs, curve, args.overtime_share, max(cap, 0))
    except SystemExit as error:
        print(error, file=sys.stderr)
        return 2
    targets = {
        "win": args.win, "shift1": args.shift1, "shift2": args.shift2,
        "overtime_share": args.overtime_share,
    }
    results = {key: evaluate(scenario_runs, curve, rule) for key, scenario_runs in records.scenarios.items()}
    text = format_report(records, scenario, curve, rule, not args.curve, results, targets)
    print(text)
    try:
        report = Path(args.report)
        report.parent.mkdir(parents=True, exist_ok=True)
        report.write_text(text + "\n", encoding="utf-8")
        if args.json:
            Path(args.json).write_text(json.dumps({
                "scenario": scenario, "curve": curve, "coins_by_shifts_passed": rule.table,
                "warnings": warnings(curve, results[scenario], targets),
                "overtime_coin_euros": rule.overtime_euros, "overtime_coin_max": rule.overtime_max,
                "targets": targets, "results": results,
            }, indent=2), encoding="utf-8")
    except OSError as error:
        print(f"error: couldn't write the report ({error})", file=sys.stderr)
        return 2
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
