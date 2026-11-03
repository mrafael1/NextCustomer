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
             seed: int = 1, percents: list[int] | None = None) -> dict:
    upgrades = upgrades or [""] * len(totals)
    inspections = inspections or [""] * len(totals)
    percents = percents or [0] * len(totals)
    return {
        "run_seed": seed,
        "shifts": [
            {"shift": i + 1, "quota": 0, "total": t, "best": t, "passed": True,
             "upgrade_taken": upgrades[i], "inspection": inspections[i],
             "hand": ["eggs", "bread"] if t >= 10 else ["bread"], "quota_percent": percents[i]}
            for i, t in enumerate(totals)
        ],
    }


def make_records(scenarios: dict[str, list[dict]], quotas: list[int] | None = None,
                 slips: tuple[int, int] = (0, 0), week_length: int = 1) -> dict:
    return {
        "quotas": quotas or [0, 0, 0],
        "coins_by_shifts_passed": [0, 0, 1, 2],
        "overtime_coin_euros": 60,
        "overtime_coin_max": 1,
        "write_up_limit": slips[0],
        "write_up_last_shift": slips[1],
        "week_length": week_length,
        "scenarios": scenarios,
    }


def to_runs(entries: list[dict], slips: tuple[int, int] = (0, 0)) -> list[qf.Run]:
    with tempfile.TemporaryDirectory() as folder:
        path = Path(folder) / "records.json"
        path.write_text(json.dumps(make_records({"s": entries}, slips=slips)), encoding="utf-8")
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

    def test_big_basket_no_longer_raises_the_quota(self) -> None:
        # plan v0.46 (#106): Big basket lost its quota raise; an older record's percents are ignored.
        entries = [make_run([10, 19, 30], upgrades=["big_basket", "", ""])]
        records = make_records({"s": entries})
        records["upgrade_quota_percent"] = {"big_basket": 15}
        with tempfile.TemporaryDirectory() as folder:
            path = Path(folder) / "records.json"
            path.write_text(json.dumps(records), encoding="utf-8")
            run = qf.load_records(path).scenarios["s"][0]
        outcome = qf.replay(run, [10, 17, 17])
        self.assertEqual(outcome.quotas, [10, 17, 17])
        self.assertTrue(outcome.won)

    def test_every_register_of_a_shift_is_recorded(self) -> None:
        # #77: the machine's visits record every loyalty perk picked, from UPGRADE (#108, a
        # level-up by its level's id) and from an older record's REGISTER and STAMP DAY visits.
        entry = make_run([10, 30, 30])
        register = {"kind": "register", "id": "big_basket", "rarity": 0}
        coupon = {"kind": "coupon", "id": "repeat", "rarity": 0}
        engine = {"kind": "register", "id": "coupon_engine", "rarity": 1, "level": 1}
        level_up = {"kind": "register", "id": "coupon_engine_lv2", "rarity": 1, "level": 2}
        item = {"kind": "upgrade", "id": "milk", "rarity": 0}
        entry["shifts"][0]["visits"] = [
            {"kind": "ticket", "chute": "register", "picked": 0, "prizes": [register, coupon]},
            {"kind": "stamp_day", "chute": "register", "picked": 1, "prizes": [coupon, register]},
            {"kind": "bonus", "chute": "coupons", "picked": 0, "prizes": [coupon]},
        ]
        entry["shifts"][1]["visits"] = [
            {"kind": "ticket", "chute": "new_items", "picked": -1, "prizes": [coupon]},
            {"kind": "bonus", "chute": "upgrade", "picked": 0, "prizes": [engine, item]},
        ]
        entry["shifts"][2]["visits"] = [
            {"kind": "ticket", "chute": "upgrade", "picked": 1, "prizes": [item, level_up]},
        ]
        run = to_runs([entry])[0]
        self.assertEqual(
            run.upgrades_taken,
            [["big_basket", "big_basket"], ["coupon_engine"], ["coupon_engine_lv2"]],
        )

    def test_a_run_cut_short_by_its_recorded_quotas_is_incomplete(self) -> None:
        run = to_runs([make_run([10, 20])])[0]
        self.assertFalse(qf.replay(run, [5, 5, 5]).complete)
        self.assertTrue(qf.replay(run, [5, 50, 5]).complete)


class QuotaPercentTest(unittest.TestCase):
    def test_the_percent_rounds_like_shift_limits(self) -> None:
        # ShiftLimits.with_percent: roundi (half away from zero), never under 1, 0 % or 0 kept.
        self.assertEqual(qf.with_percent(35, 10), 39)  # 38.5 rounds up, not to even.
        self.assertEqual(qf.with_percent(45, 10), 50)  # 49.5
        self.assertEqual(qf.with_percent(25, -10), 23)  # 22.5
        self.assertEqual(qf.with_percent(85, 10), 94)  # 93.5
        self.assertEqual(qf.with_percent(29, 0), 29)
        self.assertEqual(qf.with_percent(0, 25), 0)
        self.assertEqual(qf.with_percent(1, -90), 1)
        self.assertEqual(qf.with_percent(175, 25), 219)  # 218.75

    def test_each_shift_plays_its_recorded_percent(self) -> None:
        run = to_runs([make_run([11, 22, 30], percents=[10, 25, 0])])[0]
        outcome = qf.replay(run, [10, 20, 30])
        self.assertEqual(outcome.quotas, [11, 25])
        self.assertFalse(outcome.won)
        self.assertEqual(outcome.shifts_passed, 1)
        self.assertEqual(outcome.passes, [True, False])
        # The fit meets a share at the raised quotas: base 20 at +25% is 25, base 17 is 21.
        runs = to_runs([make_run([5, 22, 50], percents=[0, 25, 0])])
        self.assertEqual(qf.fit_curve(runs, 3, 1.0, 1.0, 1.0)[1], 17)

    def test_old_records_read_with_no_percents_or_slips(self) -> None:
        records = make_records({"s": [make_run([5, 10, 30])]})
        for key in ["write_up_limit", "write_up_last_shift", "week_length"]:
            del records[key]
        for shift in records["scenarios"]["s"][0]["shifts"]:
            del shift["quota_percent"]
        with tempfile.TemporaryDirectory() as folder:
            path = Path(folder) / "records.json"
            path.write_text(json.dumps(records), encoding="utf-8")
            loaded = qf.load_records(path)
        self.assertFalse(loaded.current)
        run = loaded.scenarios["s"][0]
        self.assertEqual(run.quota_percents, [0, 0, 0])
        outcome = qf.replay(run, [6, 10, 30])
        self.assertFalse(outcome.won)
        self.assertEqual(outcome.slips, 0)
        text = qf.format_report(loaded, "s", [6, 10, 30], qf.CoinRule([0, 0, 1, 2], 0, 1), False,
                                {"s": qf.evaluate(loaded.scenarios["s"], [6, 10, 30],
                                                  qf.CoinRule([0, 0, 1, 2], 0, 1))},
                                {"win": 0.5, "shift1": 0.9, "shift2": 0.9, "overtime_share": 0.1})
        self.assertIn("WARNING: records from before v0.95", text)


class SlipTest(unittest.TestCase):
    # The training week: misses on shifts 1-4 forgiven up to 2, never on the last shift (6 here).
    SLIPS = (2, 4)
    CURVE = [10, 10, 10, 10, 10, 10]

    def test_a_training_week_miss_is_a_slip(self) -> None:
        run = to_runs([make_run([5, 10, 10, 10, 10, 10])], self.SLIPS)[0]
        outcome = qf.replay(run, self.CURVE)
        self.assertTrue(outcome.won)
        self.assertEqual(outcome.slips, 1)
        self.assertEqual(outcome.shifts_passed, 5)
        self.assertEqual(outcome.passes, [False] + [True] * 5)
        # A slip earns no overtime.
        self.assertEqual(qf.replay(run, [4, 10, 10, 10, 10, 10]).overtime, 1)
        self.assertEqual(outcome.overtime, 0)

    def test_the_third_training_week_miss_ends_the_run(self) -> None:
        run = to_runs([make_run([5, 5, 10, 5, 10, 10])], self.SLIPS)[0]
        outcome = qf.replay(run, self.CURVE)
        self.assertFalse(outcome.won)
        self.assertEqual(outcome.slips, 2)
        self.assertEqual(outcome.shifts_passed, 1)
        self.assertEqual(len(outcome.quotas), 4)

    def test_a_miss_after_the_training_week_ends_the_run(self) -> None:
        run = to_runs([make_run([10, 10, 10, 10, 5, 10])], self.SLIPS)[0]
        outcome = qf.replay(run, self.CURVE)
        self.assertFalse(outcome.won)
        self.assertEqual(outcome.slips, 0)
        self.assertEqual(outcome.shifts_passed, 4)
        # Every shift covered (last shift 0) still never forgives the run's last shift.
        last = to_runs([make_run([10, 10, 10, 10, 10, 5])], (2, 0))[0]
        self.assertFalse(qf.replay(last, self.CURVE).won)
        self.assertTrue(qf.replay(to_runs([make_run([10, 10, 10, 10, 5, 10])], (2, 0))[0], self.CURVE).won)

    def test_a_slip_on_a_fitted_prefix_s_last_shift_is_forgiven(self) -> None:
        # Fitting shift 4 of 6: a miss on shift 3 is a slip of the 6-shift run, not its end.
        run = to_runs([make_run([10, 10, 5, 10, 10, 10])], self.SLIPS)[0]
        self.assertFalse(qf.replay(run, self.CURVE[:3]).won)
        prefix = qf.replay(run, self.CURVE[:3], len(self.CURVE))
        self.assertTrue(prefix.won)
        self.assertEqual(prefix.slips, 1)

    def test_a_run_that_slipped_just_before_reaches_the_fitted_shift(self) -> None:
        # 10 runs slip on shift 2 and score 40 on shift 3; 10 pass shift 2 and score 20. Every
        # run reaches shift 3, so keeping 0.5 of them is a quota of 40, not 20.
        entries = [make_run([10, 5, 40, 10, 10, 10], seed=i) for i in range(10)]
        entries += [make_run([10, 10, 20, 10, 10, 10], seed=100 + i) for i in range(10)]
        runs = to_runs(entries, self.SLIPS)
        self.assertEqual(qf._quota_for_share(runs, [10, 10], 0.5, len(self.CURVE)), 40)

    def test_a_won_run_with_slips_pays_the_last_entry(self) -> None:
        run = to_runs([make_run([5, 5, 10, 10, 10, 10])], self.SLIPS)[0]
        outcome = qf.replay(run, self.CURVE)
        self.assertTrue(outcome.won)
        self.assertEqual(outcome.shifts_passed, 4)
        rule = qf.CoinRule([0, 0, 0, 0, 1, 1, 3], 0, 1)
        self.assertEqual(qf.coin_stats([outcome], rule)["median"], 3)
        self.assertEqual(rule.coins(4, 0), 1)
        self.assertEqual(rule.coins(4, 0, True), 3)

    def test_slips_are_reported(self) -> None:
        runs = to_runs([make_run([5, 10, 10, 10, 10, 10]), make_run([10] * 6)], self.SLIPS)
        result = qf.evaluate(runs, self.CURVE, qf.CoinRule([0] * 6 + [3], 0, 1))
        self.assertEqual(result["slipped_share"], 0.5)
        self.assertEqual(result["shifts"][0]["pass_rate"], 0.5)
        self.assertEqual(result["shifts"][1]["reached"], 2)
        self.assertEqual(result["win_rate"], 1.0)


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
        self.assertEqual(rule.table[0], 0)
        self.assertIn(rule.table[-1], range(qf.MIN_WON_RUN_COINS, qf.WON_RUN_COINS + 1))
        self.assertEqual(rule.overtime_max, 1)
        self.assertTrue(all(b >= a for a, b in zip(rule.table, rule.table[1:])))

    def test_coin_steps_never_fall(self) -> None:
        self.assertEqual(qf.coin_steps(2, 2), [[0, 0], [0, 1], [0, 2], [1, 1], [1, 2], [2, 2]])
        self.assertEqual(qf.coin_steps(0, 3), [[]])


class CoinTargetTest(unittest.TestCase):
    def test_the_fit_can_pay_a_won_run_less_than_the_records(self) -> None:
        # Weeks of 2 shifts, 4 shifts, records paying a win 3. 100 runs: 90 win, 10 lose on
        # shift 1. Paying 3 a win is 2.7 coins a run (11 runs to 30 unlocks), paying 2 still 1.8
        # (median 2): the nearest to 32.5 runs pays a win the fewest, 2.
        entries = [make_run([10, 10, 10, 10], seed=i) for i in range(90)]
        entries += [make_run([0, 10, 10, 10], seed=100 + i) for i in range(10)]
        rule = qf.fit_coins(to_runs(entries), [5, 5, 5, 5], 0.0, 1, won_coins=3, week_length=2)
        self.assertEqual(rule.table[-1], qf.MIN_WON_RUN_COINS)


    def test_lost_runs_are_paid_by_completed_weeks(self) -> None:
        # Weeks of 2 shifts, 4 shifts, a won run paying 2. 100 runs: 40 win, 30 lose on shift 2
        # (no week completed), 30 lose on shift 3 (1 week).
        entries = [make_run([10, 10, 10, 10], seed=i) for i in range(40)]
        entries += [make_run([10, 0, 10, 10], seed=100 + i) for i in range(30)]
        entries += [make_run([10, 10, 0, 10], seed=200 + i) for i in range(30)]
        runs = to_runs(entries)
        rule = qf.fit_coins(runs, [5, 5, 5, 5], 0.0, 1, won_coins=2, week_length=2)
        # Paying 1 a completed week: mean (30 + 80) / 100 = 1.1 coins, 27 runs to 30 unlocks,
        # median 1, p90 2. Paying 0 has median 0, paying 2 median 2.
        self.assertEqual(rule.table, [0, 0, 1, 1, 2])
        stats = qf.coin_stats([qf.replay(r, [5, 5, 5, 5]) for r in runs], rule)
        self.assertTrue(qf.meets_coin_targets(stats))
        self.assertFalse(qf.meets_coin_targets({**stats, "median": 2}))
        self.assertFalse(qf.meets_coin_targets({**stats, "runs_to_unlock_all": 20.0}))

    def test_the_command_line_fit_pays_the_records_won_entry(self) -> None:
        entries = [make_run([10, 10, 10], seed=i) for i in range(10)]
        with tempfile.TemporaryDirectory() as folder:
            records = Path(folder) / "records.json"
            records.write_text(json.dumps(make_records({"greedy@sensible": entries})), encoding="utf-8")
            data = Path(folder) / "fit.json"
            output = io.StringIO()
            with contextlib.redirect_stdout(output):
                status = qf.main([str(records), f"--report={Path(folder) / 'r.txt'}", f"--json={data}"])
            self.assertEqual(status, 0)
            # The records' table ends at 2 (make_records).
            self.assertEqual(json.loads(data.read_text(encoding="utf-8"))["coins_by_shifts_passed"][-1], 2)


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
