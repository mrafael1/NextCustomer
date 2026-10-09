"""Tests for tools/quota_fit.py, on synthetic run records. Run from the repo root:

    python tools/quota_fit_test.py

(sh tools/test.sh runs them too when it runs the full suite.)
"""

from __future__ import annotations

import contextlib
import io
import json
import sys
import tempfile
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import quota_fit as qf  # noqa: E402


def make_run(totals: list[int], upgrades: list[str] | None = None, inspections: list[str] | None = None,
             seed: int = 1) -> dict:
    upgrades = upgrades or [""] * len(totals)
    inspections = inspections or [""] * len(totals)
    return {
        "run_seed": seed,
        "shifts": [
            {"shift": i + 1, "quota": 0, "total": t, "best": t, "passed": True,
             "upgrade_taken": upgrades[i], "inspection": inspections[i],
             "hand": ["eggs", "bread"] if t >= 10 else ["bread"]}
            for i, t in enumerate(totals)
        ],
    }


def make_records(scenarios: dict[str, list[dict]], quotas: list[int] | None = None) -> dict:
    return {
        "quotas": quotas or [0, 0, 0],
        "upgrade_quota_percent": {"big_basket": 15, "slot_engine": 0},
        "coins_by_shifts_passed": [0, 0, 1, 2],
        "overtime_coin_euros": 60,
        "overtime_coin_max": 1,
        "scenarios": scenarios,
    }


def to_runs(entries: list[dict]) -> list[qf.Run]:
    with tempfile.TemporaryDirectory() as folder:
        path = Path(folder) / "records.json"
        path.write_text(json.dumps(make_records({"s": entries})), encoding="utf-8")
        return qf.load_records(path).scenarios["s"]


class ReplayTest(unittest.TestCase):
    def test_a_run_ends_at_its_first_total_under_the_quota(self) -> None:
        run = to_runs([make_run([10, 20, 30])])[0]
        self.assertEqual(qf.replay(run, [5, 25, 1]).shifts_passed, 1)
        won = qf.replay(run, [10, 20, 30])
        self.assertTrue(won.won)
        self.assertEqual(won.shifts_passed, 3)
        self.assertEqual(won.overtime, 0)
        self.assertEqual(qf.replay(run, [5, 5, 5]).overtime, 5 + 15 + 25)

    def test_big_basket_raises_the_quota_from_the_next_shift_rounded_up(self) -> None:
        # ShiftLimits.raised_quota: 17 * 1.15 = 19.55 -> 20.
        self.assertEqual(qf.raised_quota(17, 15), 20)
        self.assertEqual(qf.raised_quota(17, 0), 17)
        run = to_runs([make_run([10, 19, 30], upgrades=["big_basket", "", ""])])[0]
        outcome = qf.replay(run, [10, 17, 17])
        self.assertEqual(outcome.quotas, [10, 20])
        self.assertEqual(outcome.shifts_passed, 1)

    def test_a_run_cut_short_by_its_recorded_quotas_is_incomplete(self) -> None:
        run = to_runs([make_run([10, 20])])[0]
        self.assertFalse(qf.replay(run, [5, 5, 5]).complete)
        self.assertTrue(qf.replay(run, [5, 50, 5]).complete)


class CoinTest(unittest.TestCase):
    def test_coins_are_the_table_plus_capped_overtime(self) -> None:
        rule = qf.CoinRule([0, 0, 1, 2], 60, 1)
        self.assertEqual(rule.coins(1, 59), 0)
        self.assertEqual(rule.coins(1, 60), 1)
        self.assertEqual(rule.coins(3, 500), 3)
        self.assertEqual(rule.coins(9, 0), 2)
        self.assertEqual(qf.CoinRule([0, 0, 1, 2], 0, 1).coins(3, 500), 2)

    def test_overtime_euros_keep_the_share_of_runs_earning_it(self) -> None:
        outcomes = [qf.Outcome(3, True, margin, 0) for margin in range(0, 100, 10)]
        # Just over 20% of 10 runs: 3 earn it, so the 80th percentile run does.
        euros = qf.overtime_euros_for_share(outcomes, 0.2)
        earning = sum(1 for o in outcomes if o.overtime >= euros)
        self.assertEqual(earning, 3)
        self.assertEqual(euros, 70)

    def test_fitted_coins_keep_plan_7_1(self) -> None:
        runs = to_runs([make_run([10 + i, 20 + i, 30 + i], seed=i) for i in range(40)])
        rule = qf.fit_coins(runs, [10, 25, 50], 0.10, 1)
        self.assertEqual(rule.table[:2], [0, 0])
        self.assertEqual(rule.table[-1], qf.WON_RUN_COINS)
        self.assertEqual(rule.overtime_max, 1)


class CoinTargetTest(unittest.TestCase):
    def test_lost_runs_are_paid_from_the_earliest_shift_the_targets_allow(self) -> None:
        # 100 runs: 40 win, 30 lose on shift 2 (1 passed), 30 lose on shift 3 (2 passed).
        entries = [make_run([10, 10, 10], seed=i) for i in range(40)]
        entries += [make_run([10, 0, 10], seed=100 + i) for i in range(30)]
        entries += [make_run([10, 10, 0], seed=200 + i) for i in range(30)]
        rule = qf.fit_coins(to_runs(entries), [5, 5, 5], 0.0, 1)
        # Paying from 2 shifts passed: mean (30 + 80) / 100 = 1.1 coins, 27 runs to 30 unlocks.
        self.assertEqual(rule.table, [0, 0, 1, qf.WON_RUN_COINS])
        stats = qf.coin_stats([qf.replay(r, [5, 5, 5]) for r in to_runs(entries)], rule)
        self.assertTrue(qf.meets_coin_targets(stats))
        self.assertFalse(qf.meets_coin_targets({**stats, "median": 2}))
        self.assertFalse(qf.meets_coin_targets({**stats, "runs_to_unlock_all": 20.0}))


class FitTest(unittest.TestCase):
    def runs(self) -> list[qf.Run]:
        # 200 runs whose totals spread evenly: shift s of run i scores 10 * s + i % 50.
        return to_runs([make_run([10 * s + i % 50 for s in range(1, 4)], seed=i) for i in range(200)])

    def test_the_shift_targets_hold_and_the_curve_rises(self) -> None:
        runs = self.runs()
        curve = qf.fit_curve(runs, 3, 0.5, 0.97, 0.95)
        result = qf.evaluate(runs, curve, qf.CoinRule([0, 0, 1, 2], 0, 1))
        self.assertGreaterEqual(result["shifts"][0]["pass_rate"], 0.97)
        self.assertGreaterEqual(result["shifts"][1]["pass_rate"], 0.95)
        self.assertTrue(all(b > a for a, b in zip(curve, curve[1:])))
        self.assertAlmostEqual(result["win_rate"], 0.5, delta=0.03)

    def test_each_quota_is_the_highest_meeting_its_share(self) -> None:
        runs = self.runs()
        curve = qf.fit_curve(runs, 3, 0.5, 0.97, 0.95)
        raised = list(curve)
        raised[0] += 1
        self.assertLess(qf.evaluate(runs, raised, qf.CoinRule([0], 0, 0))["shifts"][0]["pass_rate"], 0.97)

    def test_inspections_and_upgrades_are_reported(self) -> None:
        entries = [
            make_run([10, 30, 40], upgrades=["slot_engine", "", ""], inspections=["", "", "spot_check"], seed=1),
            make_run([10, 5, 40], upgrades=["", "", ""], inspections=["", "short_belt", ""], seed=2),
        ]
        result = qf.evaluate(to_runs(entries), [5, 10, 20], qf.CoinRule([0, 0, 1, 2], 0, 1))
        self.assertEqual(result["inspections"]["short_belt"]["failed"], 1)
        self.assertEqual(result["inspections"]["spot_check"]["failed"], 0)
        self.assertEqual(result["upgrades"]["slot_engine"]["runs"], 1)
        self.assertEqual(result["upgrades"]["slot_engine"]["win_rate"], 1.0)
        self.assertEqual(result["upgrades"]["slot_engine"]["late_pass_rate"], 1.0)


class CardTest(unittest.TestCase):
    def test_a_card_missing_from_failed_hands_shows_a_gap(self) -> None:
        # Shift 2 fails exactly when Eggs isn't in the hand (total under 10).
        entries = [make_run([10, 10 if i % 2 else 5, 10], seed=i) for i in range(80)]
        runs = to_runs(entries)
        stats = qf.card_stats(runs, [qf.replay(r, [5, 10, 10]) for r in runs])
        self.assertEqual(stats["eggs"]["pass_rate_held"], 1.0)
        self.assertEqual(stats["eggs"]["pass_rate_without"], 0.0)
        self.assertNotIn("bread", stats)


class CommandLineTest(unittest.TestCase):
    def run_main(self, args: list[str]) -> tuple[int, str]:
        output = io.StringIO()
        with contextlib.redirect_stdout(output), contextlib.redirect_stderr(io.StringIO()):
            status = qf.main(args)
        return status, output.getvalue()

    def test_evaluates_a_given_curve_and_writes_reports(self) -> None:
        with tempfile.TemporaryDirectory() as folder:
            records = Path(folder) / "records.json"
            records.write_text(json.dumps(make_records({
                "greedy@sensible": [make_run([10, 20, 30], seed=1), make_run([10, 5, 30], seed=2)],
                "skip@sensible": [make_run([3, 3, 3], seed=1)],
            })), encoding="utf-8")
            report = Path(folder) / "report.txt"
            data = Path(folder) / "fit.json"
            status, text = self.run_main([
                str(records), "--curve=5,10,20", "--coins=0,0,1,2", "--overtime-euros=0",
                f"--report={report}", f"--json={data}",
            ])
            self.assertEqual(status, 0)
            self.assertIn("Curve: [5, 10, 20]", text)
            self.assertIn("== skip@sensible (1 runs) ==", text)
            self.assertTrue(report.exists())
            numbers = json.loads(data.read_text(encoding="utf-8"))
            self.assertEqual(numbers["results"]["greedy@sensible"]["win_rate"], 0.5)

    def test_warns_about_missed_targets_and_floor_held_quotas(self) -> None:
        with tempfile.TemporaryDirectory() as folder:
            records = Path(folder) / "records.json"
            records.write_text(json.dumps(make_records({
                "greedy@sensible": [make_run([10, 20, 30], seed=1), make_run([10, 5, 30], seed=2)],
            })), encoding="utf-8")
            status, text = self.run_main([
                str(records), "--curve=5,6,20", "--coins=0,0,1,2", f"--report={Path(folder) / 'r.txt'}",
            ])
            self.assertEqual(status, 0)
            self.assertIn("WARNING: shift 2 passed by 50.0%, under its 95% target", text)
            self.assertIn("WARNING: shift 2's quota 6 is held at the previous quota + 1", text)
            # --coins without --overtime-euros keeps the records' overtime coin (60 euros).
            self.assertIn("one overtime coin per 60 euros", text)

    def test_help_exits_0(self) -> None:
        self.assertEqual(self.run_main(["--help"])[0], 0)

    def test_bad_input_exits_2(self) -> None:
        with tempfile.TemporaryDirectory() as folder:
            missing = Path(folder) / "missing.json"
            self.assertEqual(self.run_main([str(missing)])[0], 2)
            records = Path(folder) / "records.json"
            records.write_text(json.dumps(make_records({"s": [make_run([1, 2, 3])]})), encoding="utf-8")
            self.assertEqual(self.run_main([str(records), "--curve=1,2"])[0], 2)
            self.assertEqual(self.run_main([str(records), "--scenario=nope"])[0], 2)
            self.assertEqual(self.run_main([str(records), "--coins=0,1"])[0], 2)


if __name__ == "__main__":
    unittest.main()
