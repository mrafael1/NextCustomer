"""Tests for tools/log_summary.py, on synthetic logs in temporary folders. Run from the repo root:

    python tools/log_summary_test.py

(sh tools/test.sh runs them too when it runs the full suite.)
"""

from __future__ import annotations

import contextlib
import io
import itertools
import json
import os
import subprocess
import sys
import tempfile
import unittest
from datetime import datetime, timedelta
from pathlib import Path
from unittest import mock

sys.path.insert(0, str(Path(__file__).resolve().parent))
import log_summary as ls  # noqa: E402

SCRIPT = Path(__file__).resolve().parent / "log_summary.py"
# Every synthetic run gets its own seed, as real runs do (random 64-bit seeds).
SEEDS = itertools.count(1000)

FIXTURE_CARDS = {
    "banana": ("Banana", 1), "bread": ("Bread", 1), "milk": ("Milk", 1), "eggs": ("Eggs", 1),
    "repeat": ("Repeat", 2), "multipack": ("Multipack", 2),
}
FIXTURE_UPGRADES = {"coupon_engine": "Coupon engine", "extra_redraw": "Extra redraw"}
FIXTURE_AISLES = {"placeholder": "Placeholder aisle", "dairy": "Dairy"}

TRES_CARD = """[gd_resource type="Resource" script_class="CardDefinition" format=3]

[ext_resource type="Script" path="res://core/card_definition.gd" id="1_card"]

[sub_resource type="Resource" id="Resource_x"]
id = &"not_the_card"
kind = 7

[resource]
script = ExtResource("1_card")
id = &"{id}"
display_name = "{name}"
kind = {kind}
tags = PackedStringArray()
"""
TRES_NAMED = """[gd_resource type="Resource" format=3]

[resource]
id = &"{id}"
display_name = "{name}"
"""


def write_fixture_data(folder: Path) -> Path:
    for sub in ("cards", "upgrades", "aisles"):
        (folder / sub).mkdir(parents=True)
    for card_id, (name, kind) in FIXTURE_CARDS.items():
        (folder / "cards" / f"{card_id}.tres").write_text(
            TRES_CARD.format(id=card_id, name=name, kind=kind), encoding="utf-8")
    for sub, names in (("upgrades", FIXTURE_UPGRADES), ("aisles", FIXTURE_AISLES)):
        for item_id, name in names.items():
            (folder / sub / f"{item_id}.tres").write_text(
                TRES_NAMED.format(id=item_id, name=name), encoding="utf-8")
    return folder


class Session:
    """One synthetic game session: events with session_id, seq, time and build."""

    def __init__(self, session_id: str, start: str = "2026-10-08T10:00:00",
                 build: str = "fb-p1") -> None:
        self.session_id = session_id
        self.build = build
        self.clock = datetime.fromisoformat(start)
        self.seq = 0
        self.events: list[dict] = []

    def log(self, event_type: str, run_id: str = "", **data: object) -> dict:
        self.seq += 1
        self.clock += timedelta(seconds=1)
        event = {
            "session_id": self.session_id, "run_id": run_id, "seq": self.seq,
            "time": self.clock.strftime("%Y-%m-%dT%H:%M:%S") + "Z", "t_ms": self.seq * 1000,
            "build": self.build, "type": event_type,
        }
        event.update(data)
        self.events.append(event)
        return event

    def run_start(self, run_id: str, deck: tuple = ("banana", "bread", "repeat"),
                  rack: tuple = ("milk", "eggs", "banana"), pick: str = "", replaced: str = "",
                  times: tuple = (220, 350, 4000), skipped: bool = False,
                  aisles: tuple | None = ("placeholder",), shift_count: int | None = 8,
                  seed: int | None = None) -> dict:
        data: dict = {
            "seed": next(SEEDS) if seed is None else seed,
            "starting_deck": list(deck), "impulse_offer": list(rack),
            "impulse_pick": pick, "impulse_replaced": replaced,
            "impulse_presented_ms": times[0], "impulse_armed_ms": times[1],
            "impulse_decide_ms": times[2], "impulse_presentation_skipped": skipped,
            "impulse_deck_view_opened": False, "stock": [],
        }
        if aisles is not None:
            data["listed_aisles"] = list(aisles)
        if shift_count is not None:
            data["shift_count"] = shift_count
        return self.log("run_start", run_id, **data)

    def shift(self, run_id: str, shift: int, passed: bool = True,
              order: tuple = ("banana", "bread", "milk"), rearrangements: int = 0,
              placements: int | None = None, method: str = "click") -> None:
        self.log("shift_start", run_id, shift=shift, quota=10, cards_drawn=[], inspections=[])
        self.log("checkout", run_id, shift=shift, final_order=list(order), score=12, quota=10,
                 passed=passed, placements=placements if placements is not None
                 else len(order) + rearrangements, removals=0, rearrangements=rearrangements,
                 distinct_projected_totals=1, planning_ms=5000, input_method=method,
                 next_inspection="")

    def count_up(self, run_id: str, shift: int, skip_used: bool = False, skip_at: int = -1,
                 dessert: bool = False, fast_forward: bool = False) -> None:
        self.log("count_up", run_id, shift=shift, count_up_ms=2000,
                 fast_forward_used=fast_forward, skip_used=skip_used, skip_at_ms=skip_at,
                 dessert_skipped=dessert)

    def reward(self, run_id: str, shift: int, offered: tuple, picked: str = "",
               replaced: str = "", times: tuple = (220, 350, 1500),
               skipped: bool = False) -> None:
        self.log("reward", run_id, shift=shift, offered=list(offered), picked=picked,
                 skipped=picked == "", replaced=replaced, presented_ms=times[0],
                 armed_ms=times[1], decide_ms=times[2], presentation_skipped=skipped,
                 deck_view_opened=False)

    def upgrade(self, run_id: str, shift: int, picked: str, times: tuple = (220, 350, 900),
                skipped: bool = False) -> None:
        self.log("upgrade", run_id, shift=shift, offered=[picked], picked=picked,
                 presented_ms=times[0], armed_ms=times[1], decide_ms=times[2],
                 presentation_skipped=skipped)

    def run_end(self, run_id: str, won: bool, shift_reached: int,
                upgrades: tuple = ()) -> None:
        self.log("run_end", run_id, result="win" if won else "loss",
                 shift_reached=shift_reached, last_score=12, run_ms=60000,
                 upgrades=list(upgrades))

    def lines(self) -> list[str]:
        return [json.dumps(event) for event in self.events]


class LogTestCase(unittest.TestCase):
    def setUp(self) -> None:
        self._temp = tempfile.TemporaryDirectory()
        self.folder = Path(self._temp.name)
        self.data = write_fixture_data(self.folder / "data")
        self.catalogue = ls.load_catalogue(self.data)
        self.logs = self.folder / "logs"
        self.logs.mkdir()

    def tearDown(self) -> None:
        self._temp.cleanup()

    def write(self, name: str, *parts: Session | str) -> Path:
        lines: list[str] = []
        for part in parts:
            lines += part.lines() if isinstance(part, Session) else [part]
        path = self.logs / name
        path.write_text("\n".join(lines) + "\n", encoding="utf-8")
        return path

    def summary(self, *paths: Path, one_player: bool = False, include_debug: bool = False,
                builds: list[str] | None = None) -> dict:
        players, inputs = ls.load_players(
            ls.resolve_players([str(p) for p in paths], one_player), one_player,
            include_debug, builds)
        return ls.summarise(players, inputs, self.catalogue, include_debug)

    def run_script(self, *args: str) -> subprocess.CompletedProcess:
        """Runs the script with the fixture data, its report in the temp folder."""
        env = dict(os.environ, PYTHONDONTWRITEBYTECODE="1")
        return subprocess.run(
            [sys.executable, str(SCRIPT), f"--data={self.data}",
             f"--report={self.folder / 'out' / 'report.txt'}", *args],
            capture_output=True, text=True, env=env, check=False)

    def players(self, *paths: Path, one_player: bool = False,
                include_debug: bool = False) -> list[ls.Player]:
        players, _ = ls.load_players(
            ls.resolve_players([str(p) for p in paths], one_player), one_player,
            include_debug, None)
        return players


class CatalogueTest(LogTestCase):
    def test_reads_resource_section_only(self) -> None:
        self.assertEqual(self.catalogue.kind("multipack"), ls.KIND_COUPON)
        self.assertEqual(self.catalogue.kind("banana"), ls.KIND_PRODUCT)
        self.assertEqual(self.catalogue.card_name("multipack"), "Multipack")
        self.assertNotIn("not_the_card", self.catalogue.cards)
        self.assertEqual(self.catalogue.upgrade_name("coupon_engine"), "Coupon engine")
        self.assertEqual(self.catalogue.aisle_name("dairy"), "Dairy")

    def test_unknown_ids(self) -> None:
        self.assertIsNone(self.catalogue.kind("caviar"))
        self.assertEqual(self.catalogue.card_name("caviar"), "caviar (unknown)")

    def test_game_data_has_a_kind_for_every_card(self) -> None:
        catalogue = ls.load_catalogue(ls.DEFAULT_DATA)
        self.assertTrue(catalogue.cards)
        for card_id in catalogue.cards:
            self.assertIn(catalogue.kind(card_id), (ls.KIND_PRODUCT, ls.KIND_COUPON), card_id)
        self.assertEqual(catalogue.kind("multipack"), ls.KIND_COUPON)
        self.assertEqual(catalogue.kind("banana"), ls.KIND_PRODUCT)


class ReadingTest(LogTestCase):
    def test_malformed_lines_are_counted_and_skipped(self) -> None:
        s = Session("s1")
        s.run_start("r1")
        path = self.write("p.jsonl", "not json", "[1, 2]", '{"no_type": 1}', "", s,
                          '{"type": "checkout", "shift": "x"')
        summary = self.summary(path)
        self.assertEqual(summary["inputs"]["malformed_lines"], 4)
        self.assertEqual(summary["inputs"]["events"], 1)
        self.assertEqual(summary["runs"]["runs"], 1)

    def test_unknown_types_are_ignored(self) -> None:
        s = Session("s1")
        s.run_start("r1")
        s.log("future_event", "r1", value=3)
        summary = self.summary(self.write("p.jsonl", s))
        self.assertEqual(summary["inputs"]["unknown_event_types"], {"future_event": 1})

    def test_duplicate_events_are_dropped(self) -> None:
        s = Session("s1")
        s.run_start("r1")
        s.shift("r1", 1)
        first = self.write("a.jsonl", s)
        second = self.write("b.jsonl", s)
        summary = self.summary(first, second, first, one_player=True)
        self.assertEqual(summary["inputs"]["duplicate_events"], 6)
        self.assertEqual(summary["checkouts"]["checkouts"], 1)
        self.assertEqual(summary["inputs"]["players"], 1)

    def test_files_sharing_a_session_are_one_player(self) -> None:
        s = Session("s1")
        s.run_start("r1")
        summary = self.summary(self.write("a.jsonl", s), self.write("b.jsonl", s))
        self.assertEqual(summary["inputs"]["players"], 1)
        self.assertEqual(summary["players"][0]["player"], "a.jsonl + b.jsonl")
        self.assertEqual(summary["inputs"]["merged_players"], [["a.jsonl", "b.jsonl"]])
        self.assertIn("Joined into one player: a.jsonl, b.jsonl", ls.render(summary))

    def test_a_testers_two_exports_never_split_a_run(self) -> None:
        # Finding 5: export1 is taken while run B is in progress; the session then goes on.
        s = Session("s1")
        s.run_start("A")
        s.shift("A", 1, passed=False)
        s.run_end("A", False, 1)
        s.log("restart", "A", since_run_end_ms=900, screen="results")
        s.run_start("B")
        s.shift("B", 1)
        s.log("log_export", "B", screen="shift", files=1)
        export1 = self.write("export1.jsonl", s)
        s.run_end("B", True, 8)
        s.log("restart", "B", since_run_end_ms=900, screen="results")
        s.run_start("C")
        s.run_end("C", True, 8)
        export2 = self.write("export2.jsonl", s)
        for order in ((export1, export2), (export2, export1)):
            players = self.players(*order)
            self.assertEqual(len(players), 1)
            runs = players[0].runs
            self.assertEqual([(r.run_id, r.outcome, r.index) for r in runs],
                             [("A", "lost", 1), ("B", "won", 2), ("C", "won", 3)])
            self.assertIsNotNone(runs[1].start)
            summary = self.summary(*order)
            self.assertEqual(summary["runs"]["without_run_start"], 0)
            self.assertEqual(summary["runs"]["restart_rate"], {"count": 2, "n": 3, "rate": 2 / 3})

    def test_byte_order_mark_and_odd_field_types(self) -> None:
        s = Session("s1")
        s.run_start("r1", deck="banana", shift_count=None)  # type: ignore[arg-type]
        s.log("checkout", "r1", shift="1", final_order=None, rearrangements=True)
        path = self.logs / "bom.jsonl"
        path.write_text("\ufeff" + "\n".join(s.lines()), encoding="utf-8")
        summary = self.summary(path)
        self.assertEqual(summary["inputs"]["malformed_lines"], 0)
        self.assertEqual(summary["checkouts"]["rearrangements"]["n"], 0)
        ls.render(summary)

    def test_old_prototype_logs_without_newer_fields(self) -> None:
        s = Session("s1", build="proto-r0")
        s.log("run_start", "r1", seed=4, starting_deck=["banana", "repeat"])
        s.log("shift_start", "r1", shift=1, quota=10, cards_drawn=[])
        s.log("checkout", "r1", shift=1, final_order=["banana"], score=4, quota=10,
              passed=False, placements=1, removals=0, rearrangements=0,
              distinct_projected_totals=1, planning_ms=100, count_up_ms=900,
              fast_forward_used=False)
        s.log("reward", "r1", shift=1, offered=["multipack"], picked="", skipped=True,
              replaced="", decide_ms=500, deck_view_opened=False)
        s.log("run_end", "r1", result="loss", shift_reached=1, last_score=4, run_ms=100)
        summary = self.summary(self.write("p.jsonl", s))
        self.assertEqual(summary["shifts"][0]["shift_count"], None)
        self.assertEqual(summary["lists"][0]["list"], "(not logged: before v0.17)")
        self.assertEqual(summary["impulse_rack"]["racks"], 0)
        times = summary["offer_times"]["reward"]["times"]
        self.assertEqual(times["armed_ms"]["not_logged"], 1)
        self.assertEqual(times["decide_ms"]["dist"]["n"], 1)
        self.assertEqual(summary["second_run"]["all_runs"]["presentation_skipped"]["n"], 0)
        self.assertIn("unknown length", ls.render(summary))


class RunsTest(LogTestCase):
    def test_outcomes_resumes_and_restart_rate(self) -> None:
        a = Session("a", "2026-10-08T10:00:00")
        a.run_start("won")
        a.run_end("won", True, 8)
        a.log("restart", "won", since_run_end_ms=3000, screen="results")
        a.run_start("resumed")
        a.shift("resumed", 1)
        b = Session("b", "2026-10-08T11:00:00")
        b.log("run_resume", "resumed", shift=2, phase="planning", run_ms=9000)
        b.shift("resumed", 2, passed=False)
        b.run_end("resumed", False, 2)
        b.run_start("abandoned")
        c = Session("c", "2026-10-08T12:00:00")
        c.log("run_abandon", "abandoned", shift=1, phase="planning", run_ms=100)
        c.run_start("unfinished")
        c.log("log_export", "", screen="title", files=3)
        runs = self.summary(self.write("p.jsonl", a, b, c))["runs"]
        self.assertEqual(runs["runs"], 4)
        self.assertEqual((runs["won"], runs["lost"], runs["abandoned"], runs["unfinished"]),
                         (1, 1, 1, 1))
        self.assertEqual(runs["win_rate"]["rate"], 0.5)
        self.assertEqual(runs["restart_rate"], {"count": 1, "n": 2, "rate": 0.5})
        self.assertEqual(runs["restarts_by_screen"], {"results": 1})
        self.assertEqual((runs["resumed_runs"], runs["resumes"]), (1, 1))

    def test_runs_are_ordered_by_first_event_across_sessions(self) -> None:
        late = Session("late", "2026-10-09T09:00:00")
        late.run_start("third")
        early = Session("early", "2026-10-08T09:00:00")
        early.run_start("first")
        early.run_start("second")
        player = self.players(self.write("late.jsonl", late), self.write("early.jsonl", early),
                              one_player=True)[0]
        self.assertEqual([run.run_id for run in player.runs], ["first", "second", "third"])
        self.assertEqual([run.index for run in player.runs], [1, 2, 3])

    def test_each_file_is_a_player_and_one_player_joins_them(self) -> None:
        a, b = Session("a"), Session("b")
        a.run_start("r1")
        b.run_start("r2")
        paths = (self.write("a.jsonl", a), self.write("b.jsonl", b))
        self.assertEqual(len(self.players(*paths)), 2)
        self.assertEqual(len(self.players(*paths, one_player=True)), 1)
        self.assertEqual(len(self.players(self.logs)), 2)

    def test_debug_runs_are_excluded(self) -> None:
        s = Session("s")
        s.run_start("plain")
        s.run_start("cheated")
        s.log("debug", "cheated", action="add_card", card="repeat")
        s.log("debug", "cheated", action="set_seed", seed=5)
        s.run_start("replayed")
        s.run_start("after")
        path = self.write("p.jsonl", s)
        player = self.players(path)[0]
        self.assertEqual([run.run_id for run in player.runs], ["plain", "after"])
        self.assertEqual(player.debug_runs, 2)
        self.assertEqual(len(self.players(path, include_debug=True)[0].runs), 4)

    def test_shift_jump_marks_the_next_run_only_after_a_run_end(self) -> None:
        s = Session("s")
        s.run_start("live")
        s.log("debug", "live", action="skip_to_shift", shift=3)
        s.run_end("live", False, 3)
        s.run_start("normal")
        s.run_end("normal", True, 8)
        s.log("debug", "normal", action="skip_to_shift", shift=2)
        s.run_start("jumped")
        s.run_start("later")
        player = self.players(self.write("p.jsonl", s))[0]
        self.assertEqual([run.run_id for run in player.runs], ["later"])

    def test_build_filter(self) -> None:
        old, new = Session("old", build="proto-r0"), Session("new", build="fb-p1")
        old.run_start("r1")
        new.run_start("r2")
        new.run_start("r3")
        summary = self.summary(self.write("p.jsonl", old, new), builds=["fb-p1"])
        self.assertEqual(summary["runs"]["runs"], 2)
        self.assertEqual(summary["inputs"]["builds_present"], {"fb-p1": 2, "proto-r0": 1})
        self.assertEqual(summary["inputs"]["events_of_other_builds"], 1)


class CheckoutTest(LogTestCase):
    def test_high_and_low(self) -> None:
        a = Session("a")
        a.run_start("r1")
        a.shift("r1", 1, rearrangements=6)  # 3 cards, 6 >= 2 x 3: High
        a.shift("r1", 2, rearrangements=5)  # Low
        a.shift("r1", 3, rearrangements=14, order=("banana", "bread"))  # 2 cards: not counted
        a.shift("r1", 4, rearrangements=8, order=("banana", "bread", "milk", "eggs"))  # High
        b = Session("b")
        b.run_start("r2")
        b.shift("r2", 1, rearrangements=6, method="drag")
        b.shift("r2", 2, rearrangements=0, method="both")
        summary = self.summary(self.write("a.jsonl", a), self.write("b.jsonl", b))
        checkouts = summary["checkouts"]
        self.assertEqual(checkouts["high_checkouts"], {"count": 3, "n": 5, "rate": 0.6})
        classes = {row["player"]: row["class"] for row in checkouts["players"]}
        self.assertEqual(classes, {"a.jsonl": "High", "b.jsonl": "Low"})  # 1 of 2 isn't most
        self.assertEqual(checkouts["rearrangements"]["median"], 6)
        buckets = {row["bucket"]: row["count"] for row in checkouts["rearrangement_buckets"]}
        self.assertEqual(buckets, {"0": 1, "1": 0, "2": 0, "3-5": 1, "6-9": 3, "10-13": 0,
                                   "14+": 1})
        self.assertEqual(checkouts["input_methods"]["click"]["count"], 4)
        self.assertEqual(checkouts["input_methods"]["drag"]["count"], 1)


class RewardTest(LogTestCase):
    def test_first_offer_is_reported_apart(self) -> None:
        s = Session("s")
        s.run_start("r1", pick="milk")
        s.reward("r1", 2, ("repeat", "banana", "bread"), picked="repeat")
        s.reward("r1", 1, ("multipack", "banana", "milk"), picked="multipack")
        s.reward("r1", 3, ("multipack", "bread", "milk"), picked="eggs")  # not offered
        s.run_start("r2")
        s.reward("r2", 1, ("multipack", "repeat", "bread"))
        rewards = self.summary(self.write("p.jsonl", s))["rewards"]
        rows = {row["id"]: row for row in rewards["cards"]}
        self.assertEqual(rows["multipack"]["first"], {"count": 1, "n": 2, "rate": 0.5})
        self.assertEqual(rows["multipack"]["later"], {"count": 0, "n": 1, "rate": 0.0})
        self.assertEqual(rows["repeat"]["later"]["rate"], 1.0)
        self.assertEqual(rows["repeat"]["first"]["n"], 1)
        self.assertEqual(rows["multipack"]["kind"], "coupon")
        self.assertEqual(rewards["cards"][0]["kind"], "coupon")
        self.assertEqual(rewards["skip_rate"]["first"]["rate"], 0.5)
        self.assertEqual(rewards["rewards"], {"first": 2, "later": 2})

    def test_impulse_rack_and_product_picks(self) -> None:
        s = Session("s")
        s.run_start("r1", rack=("milk", "eggs", "bread"), pick="milk")
        s.reward("r1", 1, ("multipack", "milk", "bread"), picked="milk")
        s.run_start("r2", rack=("milk", "eggs", "bread"))
        s.run_start("r3", rack=())
        summary = self.summary(self.write("p.jsonl", s))
        rack = summary["impulse_rack"]
        self.assertEqual(rack["racks"], 2)
        self.assertEqual(rack["pick_rate"]["rate"], 0.5)
        self.assertEqual(rack["skip_rate"]["count"], 1)
        self.assertEqual(summary["products_picked"][0],
                         {"id": "milk", "name": "Milk", "reward": 1, "rack": 1, "total": 2})


class BuildTest(LogTestCase):
    def test_final_deck_and_build(self) -> None:
        s = Session("s")
        s.run_start("r1", deck=("banana", "bread", "repeat", "caviar"), pick="milk",
                    replaced="bread")
        s.reward("r1", 1, ("multipack", "banana", "milk"), picked="multipack")
        s.reward("r1", 2, ("multipack", "banana", "milk"), picked="multipack", replaced="banana")
        s.upgrade("r1", 2, "extra_redraw")
        s.run_end("r1", True, 8, upgrades=("extra_redraw", "coupon_engine"))
        s.run_start("r2", deck=("banana", "repeat"))
        s.run_end("r2", False, 1)
        s.run_start("r3", deck=("banana", "repeat"))
        s.run_end("r3", True, 8)
        s.run_start("unfinished", deck=("multipack",))
        runs = self.players(self.write("p.jsonl", s))[0].runs
        self.assertEqual(ls.final_deck(runs[0]),
                         {"repeat": 1, "caviar": 1, "milk": 1, "multipack": 2})
        builds = self.summary(self.write("p.jsonl", s))["builds"]
        self.assertEqual(builds["runs"], 3)
        self.assertEqual(builds["unknown_cards"], {"caviar": 1})
        self.assertEqual(builds["builds"][0], {
            "coupons": "Repeat", "runs": 2, "win_rate": {"count": 1, "n": 2, "rate": 0.5},
            "upgrades": "(no upgrades)"})
        self.assertEqual(builds["builds"][1]["coupons"], "Multipack x2 + Repeat")
        self.assertEqual(builds["builds"][1]["upgrades"], "Coupon engine, Extra redraw")
        self.assertEqual([row["coupons"] for row in builds["coupon_sets"]],
                         ["Repeat", "Multipack x2 + Repeat"])

    def test_upgrades_fall_back_to_upgrade_events(self) -> None:
        s = Session("s")
        s.run_start("r1")
        s.upgrade("r1", 2, "coupon_engine")
        s.log("run_end", "r1", result="loss", shift_reached=3)
        self.assertEqual(ls.run_upgrades(self.players(self.write("p.jsonl", s))[0].runs[0]),
                         ["coupon_engine"])


class ShiftAndListTest(LogTestCase):
    def test_win_rate_per_shift_and_per_list(self) -> None:
        s = Session("s")
        s.run_start("r1", aisles=("placeholder", "dairy"))
        s.shift("r1", 1)
        s.shift("r1", 2, passed=False)
        s.run_end("r1", False, 2)
        s.run_start("r2", aisles=("dairy", "placeholder"))
        s.shift("r2", 1)
        s.log("shift_start", "r2", shift=2, quota=13, cards_drawn=[])
        s.run_start("r3", aisles=(), shift_count=5)
        s.shift("r3", 1, passed=False)
        s.run_end("r3", False, 1)
        summary = self.summary(self.write("p.jsonl", s))
        eight = summary["shifts"][1]
        self.assertEqual(eight["shift_count"], 8)
        self.assertEqual(eight["runs"], 2)
        self.assertEqual(len(eight["shifts"]), 8)
        self.assertEqual(eight["shifts"][0]["pass_rate"], {"count": 2, "n": 2, "rate": 1.0})
        self.assertEqual(eight["shifts"][1]["runs_reached"], 2)
        self.assertEqual(eight["shifts"][1]["pass_rate"], {"count": 0, "n": 1, "rate": 0.0})
        self.assertEqual(eight["shifts"][2]["pass_rate"]["rate"], None)
        self.assertEqual(summary["shifts"][0]["shift_count"], 5)
        lists = {row["list"]: row for row in summary["lists"]}
        both = lists["Dairy + Placeholder aisle"]
        self.assertEqual((both["runs"], both["lost"], both["not_ended"]), (2, 1, 1))
        self.assertEqual(lists["(no aisles)"]["win_rate"]["rate"], 0.0)


class TimesTest(LogTestCase):
    def test_offer_times_skip_replays_and_not_reached(self) -> None:
        s = Session("s")
        s.run_start("r1", times=(0, 0, 0))  # a debug replay: never shown
        s.reward("r1", 1, ("repeat",), picked="repeat", times=(-1, 350, 1200))
        s.reward("r1", 2, ("repeat",), times=(200, 400, 2000))
        s.upgrade("r1", 2, "coupon_engine", times=(210, 360, 800))
        s.run_end("r1", False, 2)
        s.run_start("r2", times=(220, 15001, 16000))
        s.run_end("r2", False, 1)
        summary = self.summary(self.write("p.jsonl", s))
        times = summary["offer_times"]
        self.assertEqual(times["rack"]["replays_excluded"], 1)
        self.assertEqual(times["rack"]["times"]["armed_ms"]["dist"]["n"], 1)
        reward = times["reward"]["times"]
        self.assertEqual(reward["presented_ms"]["not_reached"], 1)
        self.assertEqual(reward["presented_ms"]["dist"]["n"], 1)
        self.assertEqual(reward["armed_ms"]["dist"]["median"], 375)
        self.assertEqual(ls.non_interactive_ms(self.players(self.logs)[0].runs[0]), 1110)
        ni = {row["group"]: row for row in summary["non_interactive"]}
        self.assertEqual(ni["all runs"]["within_target"], {"count": 1, "n": 2, "rate": 0.5})
        self.assertEqual(ni["run 2"]["ms"]["median"], 15001)

    def test_count_up_and_second_run_skip_rate(self) -> None:
        a = Session("a")
        a.run_start("a1")
        a.count_up("a1", 1, skip_used=True, skip_at=300)
        a.run_start("a2", skipped=True)
        a.reward("a2", 1, ("repeat",))
        a.upgrade("a2", 2, "coupon_engine")
        a.count_up("a2", 1, skip_used=True, skip_at=500, dessert=True)
        a.count_up("a2", 2, fast_forward=True)
        b = Session("b")
        b.run_start("b1")
        summary = self.summary(self.write("a.jsonl", a), self.write("b.jsonl", b))
        count_up = summary["count_up"]
        self.assertEqual(count_up["skip_used"], {"count": 2, "n": 3, "rate": 2 / 3})
        self.assertEqual(count_up["skip_at_ms"]["median"], 400)
        self.assertEqual(count_up["fast_forward_used"]["count"], 1)
        second = summary["second_run"]["run_2"]
        self.assertEqual(second["runs"], 1)
        self.assertEqual(second["presentation_skipped"], {"count": 1, "n": 3, "rate": 1 / 3})
        self.assertEqual(second["count_up_tap"], {"count": 1, "n": 2, "rate": 0.5})
        self.assertEqual(second["dessert_skipped"]["count"], 1)
        self.assertEqual(summary["second_run"]["all_runs"]["presentation_skipped"]["n"], 5)


class SameNamedExportsTest(LogTestCase):
    """Findings 1 and 7: every desktop export is playtest_export.jsonl."""

    def test_players_with_the_same_file_name_keep_their_own_class(self) -> None:
        high, low = Session("sa"), Session("sb")
        high.run_start("ra")
        high.shift("ra", 1, rearrangements=6)  # 3 cards, 6 >= 2 x 3: High
        low.run_start("rb")
        low.shift("rb", 1, rearrangements=0)
        paths = []
        for folder, session in (("tester_a", high), ("tester_b", low)):
            (self.logs / folder).mkdir()
            paths.append(self.write(f"{folder}/playtest_export.jsonl", session))
        summary = self.summary(self.logs / "tester_a", self.logs / "tester_b")
        names = [row["player"] for row in summary["players"]]
        self.assertEqual(names, ["tester_a/playtest_export.jsonl",
                                 "tester_b/playtest_export.jsonl"])
        classes = [(row["player"], row["class"], row["high"], row["counted"])
                   for row in summary["checkouts"]["players"]]
        self.assertEqual(classes, [("tester_a/playtest_export.jsonl", "High", 1, 1),
                                   ("tester_b/playtest_export.jsonl", "Low", 0, 1)])
        report = ls.render(summary)
        players = report.split("\nPlayers\n")[1].split("\nRuns\n")[0]
        self.assertRegex(players, r"tester_a/playtest_export\.jsonl .* High \(1/1\)")
        self.assertRegex(players, r"tester_b/playtest_export\.jsonl .* Low \(0/1\)")
        files = report.split("\nFiles read\n")[1]
        self.assertIn("tester_a/playtest_export.jsonl", files)
        self.assertIn("tester_b/playtest_export.jsonl", files)

    def test_names_stay_distinct_when_folder_and_name_repeat(self) -> None:
        self.assertEqual(
            ls.player_names([Path("x/a/p.jsonl"), Path("y/a/p.jsonl"), Path("q.jsonl")]),
            ["a/p.jsonl", "a/p.jsonl #2", "q.jsonl"])


class OddNumbersTest(LogTestCase):
    """Finding 2: json accepts NaN, Infinity and 1e400; huge shifts must not hang."""

    def test_non_finite_and_huge_numbers_are_missing(self) -> None:
        self.assertIsNone(ls.num({"v": float("nan")}, "v"))
        self.assertIsNone(ls.num({"v": float("inf")}, "v"))
        self.assertIsNone(ls.num({"v": 10 ** 400}, "v"))
        self.assertEqual(ls.num({"v": 1500}, "v"), 1500)
        for value in (0, 1e9, 2.5, -1, float("nan"), "3"):
            self.assertIsNone(ls.shift_number({"shift": value}, "shift"), value)
        self.assertEqual(ls.shift_number({"shift": 3.0}, "shift"), 3)

    def test_the_script_survives_them(self) -> None:
        s = Session("s")
        s.run_start("r", shift_count=None)
        s.shift("r", 1)
        lines = s.lines() + [
            '{"type":"shift_start","run_id":"r","session_id":"s","seq":101,"shift":1e400}',
            '{"type":"shift_start","run_id":"r","session_id":"s","seq":102,"shift":NaN}',
            '{"type":"checkout","run_id":"r","session_id":"s","seq":103,"shift":Infinity,'
            '"rearrangements":1e400,"planning_ms":-Infinity,"final_order":["a","b","c"]}',
            '{"type":"shift_start","run_id":"r","session_id":"s","seq":104,"shift":1e9}',
            '{"type":"checkout","run_id":"r","session_id":"s","seq":105,"shift":1e9,'
            '"planning_ms":1e308}',
            '{"type":"checkout","run_id":"r","session_id":"s","seq":106,"shift":2,'
            '"planning_ms":1e308}',
            '{"type":"run_start","run_id":"big","session_id":"s","seq":107,"shift_count":1e9}',
            '{"type":"reward","run_id":"big","session_id":"s","seq":108,"shift":1e400,'
            '"offered":["repeat"],"picked":"repeat"}',
            '{"type":"count_up","run_id":"big","session_id":"s","seq":109,'
            f'"count_up_ms":{"9" * 400}}}',
        ]
        path = self.logs / "odd.jsonl"
        path.write_text("\n".join(lines) + "\n", encoding="utf-8")
        result = self.run_script(str(path))
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertLess(len(result.stdout), 20000)
        summary = self.summary(path)
        shifts = {group["shift_count"]: group for group in summary["shifts"]}
        self.assertEqual(set(shifts), {None})  # shift_count 1e9 is missing, like no field
        self.assertEqual([row["shift"] for row in shifts[None]["shifts"]], [1, 2])
        self.assertEqual(summary["checkouts"]["planning_ms"]["n"], 1)  # only the 5000 ms one


class BuildFilterTest(LogTestCase):
    """Finding 3: --build keeps whole runs, by the build they started on."""

    def resumed_across_builds(self) -> Path:
        old = Session("old", "2026-10-08T10:00:00", build="fb-p1")
        old.run_start("A")
        old.shift("A", 1)
        old.reward("A", 1, ("multipack", "banana"), picked="multipack")
        old.shift("A", 2)
        old.reward("A", 2, ("repeat", "banana"), picked="repeat")
        new = Session("new", "2026-10-08T11:00:00", build="fb-p2")
        new.log("run_resume", "A", shift=3, phase="planning", run_ms=9000)
        new.shift("A", 3)
        new.reward("A", 3, ("multipack", "bread"), picked="bread")
        new.run_end("A", True, 8)
        new.log("restart", "", since_run_end_ms=500, screen="results")
        return self.write("p.jsonl", old, new)

    def test_a_run_resumed_on_a_new_build_belongs_to_its_first_build(self) -> None:
        path = self.resumed_across_builds()
        new_only = self.summary(path, builds=["fb-p2"])
        self.assertEqual(new_only["runs"]["runs"], 0)
        self.assertEqual(new_only["rewards"]["rewards"], {"first": 0, "later": 0})
        self.assertEqual(new_only["inputs"]["runs_of_other_builds"], 1)
        self.assertEqual(new_only["runs"]["restarts"], 1)  # loose: filtered by its own label
        old_only = self.summary(path, builds=["fb-p1"])
        self.assertEqual(old_only["runs"]["runs"], 1)
        self.assertEqual(old_only["runs"]["won"], 1)
        self.assertEqual(old_only["rewards"]["rewards"], {"first": 1, "later": 2})
        rows = {row["id"]: row for row in old_only["rewards"]["cards"]}
        self.assertEqual(rows["multipack"]["first"], {"count": 1, "n": 1, "rate": 1.0})
        self.assertEqual(old_only["runs"]["restarts"], 0)
        self.assertIn("whole runs kept by the build they started on", ls.render(old_only))

    def test_run_numbers_count_the_runs_of_other_builds(self) -> None:
        old = Session("old", "2026-10-08T10:00:00", build="fb-p1")
        old.run_start("one", skipped=True)
        new = Session("new", "2026-10-08T11:00:00", build="fb-p2")
        new.run_start("two", times=(220, 4000, 5000))
        new.run_end("two", False, 1)
        new.run_start("three", skipped=True)
        path = self.write("p.jsonl", old, new)
        players, _ = ls.load_players(ls.resolve_players([str(path)], False), False, False,
                                     ["fb-p2"])
        self.assertEqual([(run.run_id, run.index) for run in players[0].runs],
                         [("two", 2), ("three", 3)])
        summary = self.summary(path, builds=["fb-p2"])
        second = summary["second_run"]["run_2"]
        self.assertEqual(second["runs"], 1)
        self.assertEqual(second["presentation_skipped"], {"count": 0, "n": 1, "rate": 0.0})
        ni = {row["group"]: row for row in summary["non_interactive"]}
        self.assertEqual(ni["run 1"]["ms"]["n"], 0)
        self.assertEqual(ni["run 2"]["ms"]["median"], 4000)


class DebugAcrossSessionsTest(LogTestCase):
    """Findings 4 and 6: a debug run quit at its impulse rack is resumed in a later session."""

    def first_session(self, action: str = "set_seed") -> Session:
        s1 = Session("s1", "2026-10-08T10:00:00")
        s1.run_start("A", seed=11)
        if action == "set_seed":
            s1.log("debug", "A", action="set_seed", seed=777)
        else:
            s1.run_end("A", False, 2)
            s1.log("debug", "A", action="skip_to_shift", shift=3)
        return s1

    def check(self, *paths: Path, excluded: list[str], kept: list[str]) -> None:
        player = self.players(*paths, one_player=True)[0]
        self.assertEqual([run.run_id for run in player.runs], kept)
        self.assertEqual(player.debug_runs, len(excluded))
        runs = self.summary(*paths, one_player=True)["runs"]
        self.assertEqual(runs["debug_runs_excluded"], len(excluded))

    def test_set_seed_run_resumed_at_the_rack(self) -> None:
        s2 = Session("s2", "2026-10-08T11:00:00")
        s2.log("run_resume", "X", shift=1, phase="impulse_rack", run_ms=4000)
        s2.run_start("X", seed=5)  # Not the set_seed's seed: the carried mark alone finds it.
        s2.shift("X", 1)
        s2.run_end("X", False, 1)
        s2.run_start("Y")
        first = self.write("s1.jsonl", self.first_session())
        second = self.write("s2.jsonl", s2)
        self.check(first, second, excluded=["A", "X"], kept=["Y"])
        self.check(second, first, excluded=["A", "X"], kept=["Y"])  # s2's file given first

    def test_set_seed_run_abandoned_at_the_rack(self) -> None:
        s2 = Session("s2", "2026-10-08T11:00:00")
        s2.log("run_abandon", "X", shift=1, phase="impulse_rack", run_ms=4000)
        s2.run_start("Y")
        self.check(self.write("p.jsonl", self.first_session(), s2), excluded=["A", "X"],
                   kept=["Y"])

    def test_shift_jump_from_an_ended_run_quit_at_the_deck_full_chooser(self) -> None:
        s2 = Session("s2", "2026-10-08T11:00:00")
        s2.log("run_resume", "X", shift=1, phase="impulse_rack", run_ms=4000)
        s2.run_start("X", seed=11)  # The ended run's seed, replayed.
        s2.run_start("Y")
        self.check(self.write("p.jsonl", self.first_session("skip_to_shift"), s2),
                   excluded=["A", "X"], kept=["Y"])

    def test_a_carried_mark_ends_at_an_unrelated_resume(self) -> None:
        s2 = Session("s2", "2026-10-08T11:00:00")
        s2.log("run_resume", "Z", shift=2, phase="planning", run_ms=4000)
        s2.run_start("Y")
        self.check(self.write("p.jsonl", self.first_session(), s2), excluded=["A"],
                   kept=["Z", "Y"])

    def test_a_later_run_with_the_set_seed_seed_is_a_debug_run(self) -> None:
        s0 = Session("s0", "2026-10-08T09:00:00")
        s0.run_start("R", seed=777)  # The seed's original run, before the debug action: kept.
        s2 = Session("s2", "2026-10-08T11:00:00")
        s2.run_start("X", seed=777)
        s2.run_start("Y")
        self.check(self.write("p.jsonl", s0, self.first_session(), s2), excluded=["A", "X"],
                   kept=["R", "Y"])


class ReviewFindingsTest(LogTestCase):
    """Second review: never-shown racks, runs without run_start, partial offer times and bad
    output or data paths."""

    def main(self, *args: str) -> tuple[int, str, str]:
        with contextlib.redirect_stdout(io.StringIO()) as out, \
                contextlib.redirect_stderr(io.StringIO()) as err:
            code = ls.main(list(args))
        return code, out.getvalue(), err.getvalue()

    def test_never_shown_racks_are_left_out_of_rack_rates(self) -> None:
        s = Session("s")
        s.run_start("normal", rack=("milk", "eggs", "bread"), pick="milk", times=(220, 350, 900))
        s.log("debug", "", action="demo_row")
        s.run_start("demo", rack=("milk", "eggs", "bread"), times=(0, 0, 0))
        s.log("debug", "demo", action="set_seed", seed=5)
        s.run_start("replayed", rack=("milk", "eggs", "bread"), pick="eggs", times=(0, 0, 0))
        summary = self.summary(self.write("p.jsonl", s), include_debug=True)
        rack = summary["impulse_rack"]
        self.assertEqual(rack["racks"], 1)
        self.assertEqual(rack["never_shown_excluded"], 2)
        self.assertEqual(rack["pick_rate"], {"count": 1, "n": 1, "rate": 1.0})
        self.assertEqual(rack["skip_rate"], {"count": 0, "n": 1, "rate": 0.0})
        rows = {row["id"]: row for row in rack["cards"]}
        self.assertEqual(rows["milk"]["rack"], {"count": 1, "n": 1, "rate": 1.0})
        self.assertEqual([(row["id"], row["rack"]) for row in summary["products_picked"]],
                         [("milk", 1)])
        self.assertIn("racks: 1 (2 never-shown excluded)", ls.render(summary))

    def test_runs_without_run_start_are_not_pre_v0_12_runs(self) -> None:
        s1 = Session("s1", "2026-10-08T10:00:00")
        s1.run_start("A")
        s1.run_end("A", True, 8)
        s2 = Session("s2", "2026-10-08T11:00:00")
        s2.log("run_abandon", "B", shift=1, phase="impulse_rack", run_ms=3000)
        s2.log("run_resume", "M", shift=3, phase="planning", run_ms=9000)  # began elsewhere
        s2.shift("M", 3)
        s2.run_start("C")
        s2.shift("C", 1)
        summary = self.summary(self.write("p.jsonl", s1, s2))
        self.assertEqual([group["shift_count"] for group in summary["shifts"]], [8])
        self.assertEqual(summary["shifts"][0]["runs"], 2)
        runs = summary["runs"]
        self.assertEqual((runs["without_run_start"], runs["without_run_start_at_rack"]), (2, 1))
        report = ls.render(summary)
        self.assertNotIn("unknown length", report)
        self.assertIn("1 abandoned or unfinished at the impulse rack", report)
        self.assertIn("1 started in a session not given", report)
        self.assertIn("runs without run_start (left out; see Runs): 2", report)

    def test_non_interactive_time_counts_only_ended_runs_fully_logged(self) -> None:
        s = Session("s")
        # Started before v0.20 and resumed after it: only the later offers log armed_ms.
        s.log("run_start", "mixed", seed=1, starting_deck=["banana"],
              impulse_offer=["milk", "eggs"], impulse_pick="milk", impulse_decide_ms=900)
        s.log("reward", "mixed", shift=1, offered=["repeat"], picked="repeat", skipped=False,
              decide_ms=800)
        s.reward("mixed", 2, ("repeat",), times=(220, 353, 900))
        s.upgrade("mixed", 2, "coupon_engine", times=(220, 352, 900))
        s.run_end("mixed", False, 3)
        s.run_start("unfinished", times=(220, 351, 900))
        s.reward("unfinished", 1, ("repeat",), times=(220, 353, 900))
        s.run_start("won", times=(220, 350, 900))
        s.reward("won", 1, ("repeat",), times=(220, 350, 900))
        s.run_end("won", True, 8)
        path = self.write("p.jsonl", s)
        runs = {run.run_id: run for run in self.players(path)[0].runs}
        self.assertIsNone(ls.non_interactive_ms(runs["mixed"]))
        self.assertEqual(ls.non_interactive_ms(runs["won"]), 700)
        ni = {row["group"]: row for row in self.summary(path)["non_interactive"]}
        self.assertEqual(ni["all runs"]["within_target"], {"count": 1, "n": 1, "rate": 1.0})
        self.assertEqual(ni["all runs"]["not_ended_excluded"], 1)
        self.assertEqual(ni["all runs"]["partial_excluded"], 1)
        self.assertEqual(ni["run 1"]["partial_excluded"], 1)
        self.assertEqual(ni["run 1"]["ms"]["n"], 0)
        self.assertEqual(ni["run 2"]["not_ended_excluded"], 1)
        self.assertEqual(ni["won runs"]["ms"]["median"], 700)

    def test_an_output_path_that_cant_be_written_exits_with_2(self) -> None:
        s = Session("s")
        s.run_start("r1")
        log = self.write("p.jsonl", s)
        blocker = self.folder / "a_file"
        blocker.write_text("x", encoding="utf-8")
        for option in (f"--report={self.folder}", f"--json={blocker / 'x.json'}"):
            args = [f"--data={self.data}", f"--report={self.folder / 'out' / 'r.txt'}", option,
                    str(log)]
            code, out, err = self.main(*args)
            self.assertEqual(code, 2, option)
            self.assertIn("error: cannot write", err)
            self.assertNotIn("Traceback", err)
            self.assertEqual(out, "")  # Checked before the report goes to stdout.
        with mock.patch.object(ls, "write_text", side_effect=PermissionError(13, "Denied")):
            code, _, err = self.main(f"--data={self.data}",
                                     f"--report={self.folder / 'out' / 'r.txt'}", str(log))
        self.assertEqual(code, 2)
        self.assertIn("error: cannot write", err)

    def test_a_data_folder_without_cards_exits_with_2(self) -> None:
        s = Session("s")
        s.run_start("r1")
        log = self.write("p.jsonl", s)
        empty = self.folder / "empty_data"
        empty.mkdir()
        for data in (empty, self.folder / "no_such_folder"):
            code, out, err = self.main(f"--data={data}",
                                       f"--report={self.folder / 'out' / 'r.txt'}", str(log))
            self.assertEqual(code, 2, data)
            self.assertIn("error: no card data in", err)
            self.assertEqual(out, "")


class RenderTest(LogTestCase):
    def test_empty_rates_print_a_dash(self) -> None:
        s = Session("s")
        s.log("log_export", "", screen="title", files=1)
        report = ls.render(self.summary(self.write("p.jsonl", s)))
        self.assertIn("win rate (won / (won + lost)): - (0/0)", report)
        for title in ("Runs", "Rearrangements per checkout", "Reward pick rates", "Builds",
                      "Win rate per shift", "Win rate per list", "Second-run skip rate",
                      "Files read"):
            self.assertIn("\n" + title + "\n", report)

    def test_rates_and_tables(self) -> None:
        self.assertEqual(ls.fmt_rate(ls.rate(1, 3)), "33% (1/3)")
        self.assertEqual(ls.table(["a", "b"], [["x", "10"], ["long", "2"]]),
                         ["  a      b", "  ----  --", "  x     10", "  long   2"])


class CommandLineTest(LogTestCase):
    def test_writes_the_report_and_json(self) -> None:
        s = Session("20261008T100000_aaaa")
        s.run_start("r1")
        self.write("20261008T100000_aaaa.jsonl", s)
        json_path = self.folder / "out" / "summary.json"
        result = self.run_script(str(self.logs), f"--json={json_path}")
        self.assertEqual(result.returncode, 0, result.stderr)
        report = (self.folder / "out" / "report.txt").read_text(encoding="utf-8")
        self.assertEqual(report.replace("\r\n", "\n"), result.stdout.replace("\r\n", "\n"))
        self.assertIn("look like the game's own session files", report)
        self.assertEqual(json.loads(json_path.read_text(encoding="utf-8"))["runs"]["runs"], 1)

    def test_bad_input_exits_with_2(self) -> None:
        self.assertEqual(self.run_script("--no-such-option").returncode, 2)
        self.assertEqual(self.run_script(str(self.folder / "missing.jsonl")).returncode, 2)
        self.assertEqual(self.run_script(str(self.logs)).returncode, 2)  # no .jsonl in it
        self.write("junk.jsonl", "not json")
        self.assertEqual(self.run_script(str(self.logs)).returncode, 2)  # no events

    def test_no_path_reads_the_default_folder_as_one_player(self) -> None:
        a, b = Session("a"), Session("b")
        a.run_start("r1")
        b.run_start("r2")
        self.write("a.jsonl", a)
        self.write("b.jsonl", b)
        json_path = self.folder / "out" / "summary.json"
        args = [f"--data={self.data}", f"--report={self.folder / 'out' / 'report.txt'}",
                f"--json={json_path}"]
        with mock.patch.object(ls, "default_log_folder", return_value=self.logs), \
                contextlib.redirect_stdout(io.StringIO()), \
                contextlib.redirect_stderr(io.StringIO()) as err:
            self.assertEqual(ls.main(args), 0)
        self.assertIn("as one player", err.getvalue())
        summary = json.loads(json_path.read_text(encoding="utf-8"))
        self.assertEqual((summary["inputs"]["players"], summary["runs"]["runs"]), (1, 2))

    def test_default_folder_is_the_games_user_folder(self) -> None:
        with mock.patch.dict(os.environ, {"APPDATA": str(self.folder)}):
            self.assertEqual(ls.default_log_folder(), self.folder / "Godot" / "app_userdata"
                             / "Next Customer" / "playtest_logs")


if __name__ == "__main__":
    unittest.main()
