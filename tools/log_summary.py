"""Summarises the playtest event logs (docs/PROTOTYPE_PLAN.md section 8, "Log summary").
Python 3.11+ standard library only. Run from the repo root:

    python tools/log_summary.py [options] [path ...]

Each path is a .jsonl file or a folder (every *.jsonl file directly in it). By default every
input file is one player: each tester sends one exported file (Export log joins all of their
sessions into it). Files that share a session (a tester's two exports) are joined into one.
The game's own playtest_logs folder holds one file per session instead, so --one-player treats
every file given as the same player. With no path, the desktop game's log folder
(%APPDATA%/Godot/app_userdata/Next Customer/playtest_logs) is read as one player.

Options:
    --one-player      every input file belongs to the same player
    --include-debug   keep runs that used the debug panel (excluded by default)
    --build=LABEL     only runs that started on this build label (repeat for several)
    --json=PATH       also write the numbers as JSON
    --report=PATH     the text report's file (default reports/log_summary/report.txt)
    --data=PATH       the game's data folder, read for card kinds and names (default data/)

The report goes to stdout and to the report file. Exit code 0 on success, 2 on bad arguments
(including a --report or --json path that can't be written, or a --data folder without
cards/*.tres) or no readable input. Tests: python tools/log_summary_test.py
"""

from __future__ import annotations

import argparse
import json
import math
import os
import re
import statistics
import sys
import textwrap
from collections import Counter, defaultdict
from dataclasses import dataclass, field
from pathlib import Path
from typing import Any, Iterable

REPO = Path(__file__).resolve().parent.parent
DEFAULT_REPORT = REPO / "reports" / "log_summary" / "report.txt"
DEFAULT_DATA = REPO / "data"

# CardDefinition.Kind { UNSET, PRODUCT, COUPON } (core/card_definition.gd).
KIND_PRODUCT = 1
KIND_COUPON = 2

KNOWN_TYPES = frozenset({
    "run_start", "shift_start", "redraw", "checkout", "count_up", "reward", "upgrade",
    "run_end", "run_resume", "run_abandon", "restart", "log_export", "debug",
})
# Events that make a run_id a run; the others (restart, log_export, debug) only attach to one.
RUN_TYPES = KNOWN_TYPES - {"restart", "log_export", "debug"}

# Section 8, "How to read the numbers": checkouts of 3+ cards are High when their
# rearrangements are at least twice the cards committed.
HIGH_MIN_CARDS = 3
HIGH_FACTOR = 2
REARRANGEMENT_BUCKETS = [(0, 0), (1, 1), (2, 2), (3, 5), (6, 9), (10, 13), (14, None)]
# Full build plan section 9 targets.
NON_INTERACTIVE_TARGET_MS = 15000
SECOND_RUN_SKIP_TARGET = 0.70

SESSION_FILE = re.compile(r"^\d{8}T\d{6}_[0-9a-f]+\.jsonl$")
OFFER_KINDS = ("rack", "reward", "upgrade")
OFFER_TIMES = ("presented_ms", "armed_ms", "decide_ms")
REPORT_WIDTH = 96
# Numbers beyond this (or NaN and infinities, which Python's json accepts) count as missing:
# no logged time or count comes near it, and it keeps sums and means finite.
MAX_MAGNITUDE = 1e15
# A shift number (shift, shift_count) outside 1..MAX_SHIFT, or not whole, counts as missing.
MAX_SHIFT = 99


# --- Field access (older builds lack fields; never trust a field's type) -------------------


def num(event: dict | None, key: str) -> float | None:
    """The field as a number, or None when missing, not a number, not finite or beyond
    MAX_MAGNITUDE."""
    value = event.get(key) if event else None
    if isinstance(value, bool) or not isinstance(value, (int, float)):
        return None
    if isinstance(value, float) and not math.isfinite(value):
        return None
    return value if abs(value) <= MAX_MAGNITUDE else None


def shift_number(event: dict | None, key: str) -> int | None:
    """The field as a shift number (a whole number from 1 to MAX_SHIFT), or None."""
    value = num(event, key)
    if value is None or value != int(value) or not 1 <= value <= MAX_SHIFT:
        return None
    return int(value)


def flag(event: dict | None, key: str) -> bool | None:
    value = event.get(key) if event else None
    return value if isinstance(value, bool) else None


def text(event: dict | None, key: str) -> str | None:
    value = event.get(key) if event else None
    return value if isinstance(value, str) else None


def id_list(event: dict | None, key: str) -> list[str] | None:
    value = event.get(key) if event else None
    if not isinstance(value, list):
        return None
    return [item for item in value if isinstance(item, str)]


# --- Game data -----------------------------------------------------------------------------


@dataclass
class Catalogue:
    """Card kinds and names, upgrade and aisle names, read from the game's .tres files."""

    cards: dict[str, tuple[str, int]] = field(default_factory=dict)
    upgrades: dict[str, str] = field(default_factory=dict)
    aisles: dict[str, str] = field(default_factory=dict)

    def kind(self, card_id: str) -> int | None:
        """KIND_PRODUCT or KIND_COUPON, or None for an unknown id (or a card without a kind)."""
        kind = self.cards[card_id][1] if card_id in self.cards else None
        return kind if kind in (KIND_PRODUCT, KIND_COUPON) else None

    def card_name(self, card_id: str) -> str:
        return self.cards[card_id][0] if card_id in self.cards else f"{card_id} (unknown)"

    def upgrade_name(self, upgrade_id: str) -> str:
        return self.upgrades.get(upgrade_id, f"{upgrade_id} (unknown)")

    def aisle_name(self, aisle_id: str) -> str:
        return self.aisles.get(aisle_id, f"{aisle_id} (unknown)")


def _tres_value(raw: str) -> Any:
    raw = raw.strip()
    if raw.startswith("&"):
        raw = raw[1:]
    if raw.startswith('"'):
        try:
            return json.loads(raw)
        except ValueError:
            return raw.strip('"')
    try:
        return int(raw)
    except ValueError:
        return raw


def read_tres_fields(path: Path) -> dict[str, Any]:
    """The key = value lines of a .tres file's [resource] section."""
    fields: dict[str, Any] = {}
    in_resource = False
    for line in path.read_text(encoding="utf-8", errors="replace").splitlines():
        if line.startswith("["):
            in_resource = line.strip() == "[resource]"
        elif in_resource and " = " in line:
            key, raw = line.split(" = ", 1)
            fields[key.strip()] = _tres_value(raw)
    return fields


def load_catalogue(data_dir: Path) -> Catalogue:
    catalogue = Catalogue()
    for path in sorted((data_dir / "cards").glob("*.tres")):
        fields = read_tres_fields(path)
        card_id = str(fields.get("id", path.stem))
        kind = fields.get("kind", 0)
        catalogue.cards[card_id] = (
            str(fields.get("display_name", card_id)), kind if isinstance(kind, int) else 0
        )
    for folder, names in (("upgrades", catalogue.upgrades), ("aisles", catalogue.aisles)):
        for path in sorted((data_dir / folder).glob("*.tres")):
            fields = read_tres_fields(path)
            item_id = str(fields.get("id", path.stem))
            names[item_id] = str(fields.get("display_name", item_id))
    return catalogue


# --- Reading the logs ----------------------------------------------------------------------


@dataclass
class LogFile:
    path: str
    readable: bool = True
    events: int = 0
    malformed: int = 0


def read_log_file(path: Path) -> tuple[list[dict], int] | None:
    """The file's events and its number of malformed lines, or None when it can't be read.
    A malformed line is not JSON, not an object, or has no string `type`."""
    events: list[dict] = []
    malformed = 0
    try:
        with open(path, encoding="utf-8-sig", errors="replace") as handle:
            for line_number, line in enumerate(handle, 1):
                if not line.strip():
                    continue
                try:
                    event = json.loads(line)
                except (ValueError, RecursionError):
                    malformed += 1
                    continue
                if not isinstance(event, dict) or not isinstance(event.get("type"), str):
                    malformed += 1
                    continue
                event["_line"] = line_number
                events.append(event)
    except OSError:
        return None
    return events, malformed


def default_log_folder() -> Path:
    """The desktop game's playtest_logs folder (Godot's user:// for "Next Customer")."""
    if os.environ.get("APPDATA"):
        base = Path(os.environ["APPDATA"]) / "Godot"
    elif sys.platform == "darwin":
        base = Path.home() / "Library" / "Application Support" / "Godot"
    else:
        data_home = os.environ.get("XDG_DATA_HOME") or str(Path.home() / ".local" / "share")
        base = Path(data_home) / "godot"
    return base / "app_userdata" / "Next Customer" / "playtest_logs"


class InputError(Exception):
    """Bad input paths: the script exits with code 2."""


def resolve_players(paths: list[str], one_player: bool) -> list[tuple[str, list[Path]]]:
    """Each player's name and files. A folder means every *.jsonl file directly in it."""
    files: list[Path] = []
    for raw in paths:
        path = Path(raw)
        if path.is_dir():
            found = sorted(path.glob("*.jsonl"))
            if not found:
                raise InputError(f"no .jsonl files in {path}")
            files.extend(found)
        elif path.is_file():
            files.append(path)
        else:
            raise InputError(f"no such file or folder: {path}")
    if one_player:
        return [("all inputs (one player)", files)]
    return list(zip(player_names(files), ([path] for path in files)))


def player_names(files: list[Path]) -> list[str]:
    """A distinct name for each file: its name, or folder/name when another input file has the
    same name (every desktop export is playtest_export.jsonl), then " #2" ... if still repeated."""
    basenames = Counter(path.name for path in files)
    names = [
        path.name if basenames[path.name] == 1 else f"{path.parent.name}/{path.name}"
        for path in files
    ]
    totals = Counter(names)
    seen: Counter = Counter()
    unique = []
    for name in names:
        seen[name] += 1
        unique.append(name if totals[name] == 1 or seen[name] == 1 else f"{name} #{seen[name]}")
    return unique


# --- Players and runs ----------------------------------------------------------------------


@dataclass
class Offer:
    """One offer's choice and times (section 8, "Offer presentation times")."""

    kind: str
    decide: float | None
    presented: float | None
    armed: float | None
    skipped: bool | None

    @property
    def never_shown(self) -> bool:
        """A debug replay or --demo-row rack applied at once logs 0 for every time."""
        return self.decide == 0 and not self.presented and not self.armed


@dataclass
class Run:
    run_id: str
    events: list[dict]
    debug: bool = False
    index: int = 0

    def of_type(self, event_type: str) -> list[dict]:
        return [event for event in self.events if event["type"] == event_type]

    @property
    def start(self) -> dict | None:
        starts = self.of_type("run_start")
        return starts[0] if starts else None

    @property
    def end(self) -> dict | None:
        ends = self.of_type("run_end")
        return ends[-1] if ends else None

    @property
    def outcome(self) -> str:
        """won or lost (run_end), abandoned (run_abandon) or unfinished."""
        if self.end is not None:
            return "won" if text(self.end, "result") == "win" else "lost"
        if self.of_type("run_abandon"):
            return "abandoned"
        return "unfinished"

    @property
    def shift_count(self) -> int | None:
        return shift_number(self.start, "shift_count")

    @property
    def build(self) -> str:
        """The build the run started on: its run_start's label, else its first event's."""
        return build_label(self.start or self.events[0])

    def rack(self) -> Offer | None:
        """The impulse rack, when run_start offers one (shown or not: see Offer.never_shown)."""
        start = self.start
        if start is None or not id_list(start, "impulse_offer"):
            return None
        return Offer(
            "rack", num(start, "impulse_decide_ms"), num(start, "impulse_presented_ms"),
            num(start, "impulse_armed_ms"), flag(start, "impulse_presentation_skipped"),
        )

    def offers(self) -> list[Offer]:
        """The impulse rack (when run_start offers one), then the rewards and upgrades."""
        rack = self.rack()
        offers: list[Offer] = [rack] if rack is not None else []
        for event in self.events:
            if event["type"] in ("reward", "upgrade"):
                offers.append(Offer(
                    event["type"], num(event, "decide_ms"), num(event, "presented_ms"),
                    num(event, "armed_ms"), flag(event, "presentation_skipped"),
                ))
        return offers


@dataclass
class Player:
    name: str
    files: list[LogFile]
    sessions: int = 0
    runs: list[Run] = field(default_factory=list)
    debug_runs: int = 0
    restarts: list[dict] = field(default_factory=list)
    other_build_runs: int = 0
    other_build_events: int = 0
    kept_loose: int = 0

    def run_number(self, number: int) -> Run | None:
        """The player's run `number` (1 = their first run), when it is kept."""
        return next((run for run in self.runs if run.index == number), None)

    @property
    def has_data(self) -> bool:
        """Anything left after the build filter (a debug run counts: it is reported)."""
        return bool(self.runs or self.debug_runs or self.kept_loose)


def build_label(event: dict) -> str:
    return text(event, "build") or "(none)"


def _session_key(event: dict) -> str:
    session = text(event, "session_id")
    return session if session else f"file{event['_file']}"


def _seq(event: dict) -> float:
    value = num(event, "seq")
    return value if value is not None else event["_line"]


def _marks_next(event: dict, ended: set[str]) -> bool:
    """A debug action that starts a new run: set_seed, or skip_to_shift from an ended run."""
    action = text(event, "action")
    return action == "set_seed" or (action == "skip_to_shift" and text(event, "run_id") in ended)


def debug_run_ids(sessions: list[list[dict]]) -> set[str]:
    """Runs that used the debug panel, from the player's sessions in order (events sorted, with
    `_order`). A debug event carries its run's run_id. "New run with this seed" (set_seed) and
    the shift jump from an ended run (skip_to_shift) are logged under the old run just before
    they start a new one, so they also mark the next run: the next run_start in that session,
    or a run resumed or abandoned at its impulse rack in that session or a later one (the rack
    is a save point, and run_start is only logged once it is picked). A run whose run_start
    seed is the seed of an earlier such action (set_seed's seed, the ended run's) is marked
    too."""
    marked: set[str] = set()
    ended: set[str] = set()
    seeds: dict[str, float] = {}
    first_order: dict[str, tuple] = {}
    for event in (event for events in sessions for event in events):
        run_id = text(event, "run_id") or ""
        first_order.setdefault(run_id, event["_order"])
        if event["type"] == "run_start" and (seed := num(event, "seed")) is not None:
            seeds.setdefault(run_id, seed)
    debug_seeds: list[tuple[float, tuple]] = []
    pending = False
    for events in sessions:
        carried = pending  # A mark left by an earlier session: its new run waits at the rack.
        for event in events:
            run_id = text(event, "run_id") or ""
            if event["type"] == "run_end":
                ended.add(run_id)
            elif event["type"] == "debug":
                if run_id:
                    marked.add(run_id)
                if _marks_next(event, ended):
                    pending, carried = True, False
                    seed = (num(event, "seed") if text(event, "action") == "set_seed"
                            else seeds.get(run_id))
                    if seed is not None:
                        debug_seeds.append((seed, event["_order"]))
            elif pending and event["type"] in ("run_start", "run_resume", "run_abandon"):
                if event["type"] == "run_start":
                    marks = not carried
                else:
                    marks = text(event, "phase") == "impulse_rack"
                if marks:
                    marked.add(run_id)
                pending = carried = False
    for run_id, seed in seeds.items():
        if any(seed == s and first_order[run_id] > order for s, order in debug_seeds):
            marked.add(run_id)
    return marked


def build_player(
    name: str, files: list[LogFile], events: list[dict], include_debug: bool,
    builds: list[str] | None = None,
) -> Player:
    """Joins a player's runs across sessions by run_id, in order of their first event (time,
    then session order), and numbers them (run 2 is the player's second run). Runs that used
    the debug panel are dropped unless include_debug. With `builds`, whole runs are kept by
    the build they started on (Run.build), after numbering, so the numbers count every run."""
    player = Player(name, files)
    sessions: dict[str, list[dict]] = defaultdict(list)
    for event in events:
        sessions[_session_key(event)].append(event)
    for session_events in sessions.values():
        session_events.sort(key=_seq)
    ranked = sorted(
        sessions,
        key=lambda key: (
            min((t for e in sessions[key] if (t := text(e, "time"))), default=""),
            min((e["_file"], e["_line"]) for e in sessions[key]),
        ),
    )
    for rank, key in enumerate(ranked):
        for event in sessions[key]:
            event["_order"] = (rank, _seq(event))
    player.sessions = len(sessions)
    debug_ids = debug_run_ids([sessions[key] for key in ranked])
    by_run: dict[str, list[dict]] = defaultdict(list)
    loose: list[dict] = []
    for event in events:
        run_id = text(event, "run_id")
        (by_run[run_id] if run_id else loose).append(event)
    runs: list[Run] = []
    for run_id, run_events in by_run.items():
        run_events.sort(key=lambda e: e["_order"])
        if any(event["type"] in RUN_TYPES for event in run_events):
            runs.append(Run(run_id, run_events, debug=run_id in debug_ids))
        else:
            loose.extend(run_events)
    runs.sort(key=lambda run: (text(run.events[0], "time") or "", run.events[0]["_order"]))
    number = 0
    for run in runs:
        in_builds = not builds or run.build in builds
        if run.debug and not include_debug:
            if in_builds:
                player.debug_runs += 1
            else:
                player.other_build_runs += 1
                player.other_build_events += len(run.events)
            continue
        number += 1
        run.index = number
        if not in_builds:
            player.other_build_runs += 1
            player.other_build_events += len(run.events)
            continue
        player.runs.append(run)
        player.restarts.extend(run.of_type("restart"))
    for event in loose:
        if builds and build_label(event) not in builds:
            player.other_build_events += 1
            continue
        player.kept_loose += 1
        if event["type"] == "restart":
            player.restarts.append(event)
    return player


@dataclass
class Inputs:
    files: int = 0
    unreadable: list[str] = field(default_factory=list)
    events: int = 0
    malformed: int = 0
    duplicates: int = 0
    unknown_types: Counter = field(default_factory=Counter)
    builds: Counter = field(default_factory=Counter)
    build_filter: list[str] = field(default_factory=list)
    dropped_by_build: int = 0
    runs_of_other_builds: int = 0
    session_files_as_players: int = 0
    merged_players: list[list[str]] = field(default_factory=list)
    file_list: list[tuple[str, LogFile]] = field(default_factory=list)


@dataclass
class PlayerInput:
    """One player's files and events as read, before de-duplication."""

    names: list[str]
    files: list[LogFile]
    events: list[dict]

    @property
    def name(self) -> str:
        return " + ".join(dict.fromkeys(self.names))


def merge_shared_sessions(groups: list[PlayerInput]) -> list[PlayerInput]:
    """Joins players whose files share a session_id: an export holds every session of its
    install, so two such files are the same tester's exports (e.g. a later one that grew).
    The joined player takes the first file's place, so a run or a session is never split
    across players, whatever the input order."""
    parent = list(range(len(groups)))

    def root(index: int) -> int:
        while parent[index] != index:
            parent[index] = parent[parent[index]]
            index = parent[index]
        return index

    owner: dict[str, int] = {}
    for index, group in enumerate(groups):
        for event in group.events:
            session = text(event, "session_id")
            if not session:
                continue
            if session in owner:
                first, other = sorted((root(owner[session]), root(index)))
                parent[other] = first
            else:
                owner[session] = index
    merged: dict[int, PlayerInput] = {}
    for index, group in enumerate(groups):
        target = merged.setdefault(root(index), PlayerInput([], [], []))
        target.names += group.names
        target.files += group.files
        target.events += group.events
    return list(merged.values())


def load_players(
    player_files: list[tuple[str, list[Path]]], one_player: bool, include_debug: bool,
    builds: list[str] | None,
) -> tuple[list[Player], Inputs]:
    """Reads every file, joins players whose files share a session (merge_shared_sessions),
    drops duplicate events (same session_id and seq, first one kept) and unknown event types,
    then builds each player's runs (the build filter keeps whole runs: build_player)."""
    inputs = Inputs(build_filter=sorted(builds or []))
    groups: list[PlayerInput] = []
    file_index = 0
    for name, paths in player_files:
        group = PlayerInput([name], [], [])
        for path in paths:
            log_file = LogFile(str(path))
            group.files.append(log_file)
            inputs.files += 1
            if not one_player and SESSION_FILE.match(path.name):
                inputs.session_files_as_players += 1
            read = read_log_file(path)
            if read is None:
                log_file.readable = False
                inputs.unreadable.append(str(path))
                continue
            events, log_file.malformed = read
            log_file.events = len(events)
            inputs.malformed += log_file.malformed
            for event in events:
                event["_file"] = file_index
            group.events += events
            file_index += 1
        groups.append(group)
    seen: set[tuple[str, float]] = set()
    players: list[Player] = []
    for group in merge_shared_sessions(groups):
        if len(group.names) > 1:
            inputs.merged_players.append(group.names)
        inputs.file_list += [(group.name, log_file) for log_file in group.files]
        kept = [event for event in group.events if _keep(event, inputs, seen)]
        player = build_player(group.name, group.files, kept, include_debug, builds)
        inputs.dropped_by_build += player.other_build_events
        inputs.runs_of_other_builds += player.other_build_runs
        players.append(player)
    return [player for player in players if player.sessions and player.has_data], inputs


def _keep(event: dict, inputs: Inputs, seen: set) -> bool:
    """False for a duplicate (same session_id and seq as an earlier event) or an unknown type;
    counts the event's build label."""
    session, seq = text(event, "session_id"), num(event, "seq")
    if session and seq is not None:
        if (session, seq) in seen:
            inputs.duplicates += 1
            return False
        seen.add((session, seq))
    inputs.events += 1
    inputs.builds[build_label(event)] += 1
    if event["type"] not in KNOWN_TYPES:
        inputs.unknown_types[event["type"]] += 1
        return False
    return True


# --- Numbers -------------------------------------------------------------------------------


def rate(count: int, total: int) -> dict:
    return {"count": count, "n": total, "rate": count / total if total else None}


def dist(values: Iterable[float]) -> dict:
    ordered = sorted(values)
    if not ordered:
        return {"n": 0, "mean": None, "median": None, "p90": None, "min": None, "max": None}
    return {
        "n": len(ordered),
        "mean": statistics.fmean(ordered),
        "median": statistics.median(ordered),
        "p90": ordered[math.ceil(0.9 * len(ordered)) - 1],
        "min": ordered[0],
        "max": ordered[-1],
    }


def _bucket_label(low: int, high: int | None) -> str:
    if high is None:
        return f"{low}+"
    return str(low) if low == high else f"{low}-{high}"


def ended_at_rack(run: Run) -> bool:
    """A run_resume or run_abandon at the impulse rack: run_start is only logged once the
    rack is picked or skipped, so a run quit there and abandoned (or never picked up) has
    none."""
    return any(text(event, "phase") == "impulse_rack"
               for event in run.events if event["type"] in ("run_resume", "run_abandon"))


def runs_summary(players: list[Player]) -> dict:
    runs = [run for player in players for run in player.runs]
    outcomes = Counter(run.outcome for run in runs)
    run_ends = sum(len(run.of_type("run_end")) for run in runs)
    restarts = [event for player in players for event in player.restarts]
    return {
        "runs": len(runs),
        "with_run_start": sum(1 for run in runs if run.start is not None),
        "without_run_start": sum(1 for run in runs if run.start is None),
        "without_run_start_at_rack": sum(
            1 for run in runs if run.start is None and ended_at_rack(run)),
        "won": outcomes["won"],
        "lost": outcomes["lost"],
        "abandoned": outcomes["abandoned"],
        "unfinished": outcomes["unfinished"],
        "win_rate": rate(outcomes["won"], outcomes["won"] + outcomes["lost"]),
        "debug_runs_excluded": sum(player.debug_runs for player in players),
        "resumed_runs": sum(1 for run in runs if run.of_type("run_resume")),
        "resumes": sum(len(run.of_type("run_resume")) for run in runs),
        "restarts": len(restarts),
        "run_ends": run_ends,
        "restart_rate": rate(len(restarts), run_ends),
        "restarts_by_screen": dict(Counter(text(e, "screen") or "(none)" for e in restarts)),
        "shift_counts": {
            str(key) if key is not None else "unknown": value
            for key, value in sorted(
                Counter(run.shift_count for run in runs if run.start is not None).items(),
                key=lambda item: (item[0] is None, item[0] or 0),
            )
        },
    }


def _counted_checkout(event: dict) -> bool | None:
    """High (True) or Low (False) for a checkout of 3+ cards, None when not counted."""
    order = id_list(event, "final_order")
    rearrangements = num(event, "rearrangements")
    if order is None or rearrangements is None or len(order) < HIGH_MIN_CARDS:
        return None
    return rearrangements >= HIGH_FACTOR * len(order)


def player_class(high: int, counted: int) -> str:
    """A player is High when most (more than half) of their counted checkouts are High."""
    if counted == 0:
        return "-"
    return "High" if high * 2 > counted else "Low"


def checkout_summary(players: list[Player]) -> dict:
    checkouts = [e for p in players for run in p.runs for e in run.of_type("checkout")]
    rearrangements = [v for e in checkouts if (v := num(e, "rearrangements")) is not None]
    buckets = []
    for low, high in REARRANGEMENT_BUCKETS:
        count = sum(1 for v in rearrangements if v >= low and (high is None or v <= high))
        buckets.append({"bucket": _bucket_label(low, high), "count": count})
    classes = [c for e in checkouts if (c := _counted_checkout(e)) is not None]
    per_player = []
    for player in players:
        own = [_counted_checkout(e) for run in player.runs for e in run.of_type("checkout")]
        counted = [c for c in own if c is not None]
        high = sum(counted)
        per_player.append({
            "player": player.name, "high": high, "counted": len(counted),
            "class": player_class(high, len(counted)),
        })
    methods = Counter(text(e, "input_method") or "(not logged)" for e in checkouts)
    return {
        "checkouts": len(checkouts),
        "rearrangements": dist(rearrangements),
        "rearrangement_buckets": buckets,
        "high_checkouts": rate(sum(classes), len(classes)),
        "players": per_player,
        "placements": dist(v for e in checkouts if (v := num(e, "placements")) is not None),
        "removals": dist(v for e in checkouts if (v := num(e, "removals")) is not None),
        "distinct_projected_totals": dist(
            v for e in checkouts if (v := num(e, "distinct_projected_totals")) is not None
        ),
        "planning_ms": dist(v for e in checkouts if (v := num(e, "planning_ms")) is not None),
        "input_methods": {k: rate(v, len(checkouts)) for k, v in sorted(methods.items())},
    }


def _first_reward(rewards: list[dict]) -> dict:
    """The run's first reward offer: its lowest shift (the shift identifies it)."""
    return min(rewards, key=lambda e: (shift_number(e, "shift") or math.inf, e["_order"]))


def _card_rows(offered: dict[str, Counter], picked: dict[str, Counter], catalogue: Catalogue,
               groups: tuple[str, ...]) -> list[dict]:
    card_ids = set()
    for group in groups:
        card_ids.update(offered[group])
    rows = []
    for card_id in card_ids:
        row: dict[str, Any] = {
            "id": card_id, "name": catalogue.card_name(card_id),
            "kind": _kind_name(catalogue.kind(card_id)),
        }
        for group in groups:
            row[group] = rate(picked[group][card_id], offered[group][card_id])
        rows.append(row)
    return sorted(rows, key=lambda row: (_KIND_ORDER[row["kind"]], row["name"]))


_KIND_ORDER = {"coupon": 0, "product": 1, "unknown": 2}


def _kind_name(kind: int | None) -> str:
    return {KIND_COUPON: "coupon", KIND_PRODUCT: "product"}.get(kind, "unknown")


def reward_summary(runs: list[Run], catalogue: Catalogue) -> dict:
    """Pick rate = picks / times offered, over reward events; each run's first reward offer
    (its lowest shift) is reported apart from the later ones."""
    offered: dict[str, Counter] = {"first": Counter(), "later": Counter(), "all": Counter()}
    picked: dict[str, Counter] = {"first": Counter(), "later": Counter(), "all": Counter()}
    rewards = {"first": 0, "later": 0}
    skipped = {"first": 0, "later": 0}
    for run in runs:
        events = run.of_type("reward")
        if not events:
            continue
        first = _first_reward(events)
        for event in events:
            group = "first" if event is first else "later"
            rewards[group] += 1
            cards = id_list(event, "offered") or []
            pick = text(event, "picked") or ""
            is_skip = flag(event, "skipped")
            skipped[group] += int(is_skip if is_skip is not None else pick == "")
            for card_id in cards:
                offered[group][card_id] += 1
                offered["all"][card_id] += 1
            if pick and pick in cards:
                picked[group][pick] += 1
                picked["all"][pick] += 1
    return {
        "rewards": {"first": rewards["first"], "later": rewards["later"]},
        "skip_rate": {
            "first": rate(skipped["first"], rewards["first"]),
            "later": rate(skipped["later"], rewards["later"]),
            "all": rate(skipped["first"] + skipped["later"], rewards["first"] + rewards["later"]),
        },
        "cards": _card_rows(offered, picked, catalogue, ("first", "later", "all")),
    }


def rack_summary(runs: list[Run], catalogue: Catalogue) -> dict:
    """The impulse rack (run_start): shown when impulse_offer is not empty, leaving out (and
    counting) never-shown racks: a debug replay or --demo-row rack, all times 0."""
    offered: dict[str, Counter] = {"rack": Counter()}
    picked: dict[str, Counter] = {"rack": Counter()}
    shown = picks = never_shown = 0
    for run in runs:
        rack = run.rack()
        if rack is None:
            continue
        if rack.never_shown:
            never_shown += 1
            continue
        cards = id_list(run.start, "impulse_offer") or []
        shown += 1
        offered["rack"].update(cards)
        pick = text(run.start, "impulse_pick") or ""
        if pick and pick in cards:
            picks += 1
            picked["rack"][pick] += 1
    return {
        "racks": shown,
        "never_shown_excluded": never_shown,
        "pick_rate": rate(picks, shown),
        "skip_rate": rate(shown - picks, shown),
        "cards": _card_rows(offered, picked, catalogue, ("rack",)),
    }


def product_picks(runs: list[Run], catalogue: Catalogue) -> list[dict]:
    """Products picked from rewards and the shown impulse racks, most picked first."""
    reward: Counter = Counter()
    rack: Counter = Counter()
    for run in runs:
        for event in run.of_type("reward"):
            pick = text(event, "picked") or ""
            if pick and catalogue.kind(pick) == KIND_PRODUCT:
                reward[pick] += 1
        offer = run.rack()
        if offer is None or offer.never_shown:
            continue
        pick = text(run.start, "impulse_pick") or ""
        if pick and catalogue.kind(pick) == KIND_PRODUCT:
            rack[pick] += 1
    rows = [
        {"id": card_id, "name": catalogue.card_name(card_id), "reward": reward[card_id],
         "rack": rack[card_id], "total": reward[card_id] + rack[card_id]}
        for card_id in set(reward) | set(rack)
    ]
    return sorted(rows, key=lambda row: (-row["total"], row["name"]))


def final_deck(run: Run) -> Counter | None:
    """The run's final deck: run_start's starting_deck, its impulse pick (removing
    impulse_replaced), then every reward's pick (removing its replaced card)."""
    deck_ids = id_list(run.start, "starting_deck")
    if deck_ids is None:
        return None
    deck = Counter(deck_ids)
    changes = [(text(run.start, "impulse_pick"), text(run.start, "impulse_replaced"))]
    changes += [(text(e, "picked"), text(e, "replaced")) for e in run.of_type("reward")]
    for pick, replaced in changes:
        if replaced and deck[replaced] > 0:
            deck[replaced] -= 1
        if pick:
            deck[pick] += 1
    return +deck


def coupon_label(deck: Counter, catalogue: Catalogue) -> str:
    coupons = sorted(
        (catalogue.card_name(card_id), count)
        for card_id, count in deck.items() if catalogue.kind(card_id) == KIND_COUPON
    )
    if not coupons:
        return "(no coupons)"
    return " + ".join(name if count == 1 else f"{name} x{count}" for name, count in coupons)


def run_upgrades(run: Run) -> list[str]:
    """run_end's upgrades when logged, else the upgrade events' picks."""
    logged = id_list(run.end, "upgrades")
    if logged is not None:
        return logged
    return [pick for e in run.of_type("upgrade") if (pick := text(e, "picked"))]


def upgrade_label(upgrade_ids: list[str], catalogue: Catalogue) -> str:
    if not upgrade_ids:
        return "(no upgrades)"
    return ", ".join(sorted(catalogue.upgrade_name(u) for u in upgrade_ids))


def build_summary(runs: list[Run], catalogue: Catalogue) -> dict:
    """Over won and lost runs with a run_start: the build is the final deck's coupons plus
    the upgrades taken."""
    builds: dict[tuple[str, str], list[Run]] = defaultdict(list)
    coupon_sets: dict[str, list[Run]] = defaultdict(list)
    unknown: Counter = Counter()
    for run in runs:
        if run.outcome not in ("won", "lost"):
            continue
        deck = final_deck(run)
        if deck is None:
            continue
        coupons = coupon_label(deck, catalogue)
        builds[(coupons, upgrade_label(run_upgrades(run), catalogue))].append(run)
        coupon_sets[coupons].append(run)
        unknown.update({c: n for c, n in deck.items() if catalogue.kind(c) is None})

    def rows(groups: dict[Any, list[Run]]) -> list[dict]:
        result = []
        for key, group in groups.items():
            won = sum(1 for run in group if run.outcome == "won")
            coupons, upgrades = key if isinstance(key, tuple) else (key, None)
            row = {"coupons": coupons, "runs": len(group), "win_rate": rate(won, len(group))}
            if upgrades is not None:
                row["upgrades"] = upgrades
            result.append(row)
        return sorted(result, key=lambda row: (-row["runs"], row["coupons"],
                                               row.get("upgrades", "")))

    return {
        "runs": sum(len(group) for group in builds.values()),
        "builds": rows(builds),
        "coupon_sets": rows(coupon_sets),
        "unknown_cards": dict(sorted(unknown.items())),
    }


def shift_summary(runs: list[Run]) -> list[dict]:
    """Win rate per shift: checkouts at shift n that passed / checkouts at shift n, grouped by
    run_start's shift_count (unknown for logs before v0.12; proto-r1 had 5 shifts). Runs
    without a run_start are left out (runs_summary counts them)."""
    groups: dict[int | None, list[Run]] = defaultdict(list)
    for run in runs:
        if run.start is not None:
            groups[run.shift_count].append(run)
    result = []
    for shift_count in sorted(groups, key=lambda key: (key is None, key or 0)):
        reached: dict[int, set[str]] = defaultdict(set)
        checkouts: Counter = Counter()
        passed: Counter = Counter()
        for run in groups[shift_count]:
            for event in run.events:
                shift = shift_number(event, "shift")
                if shift is None or event["type"] not in ("shift_start", "checkout"):
                    continue
                reached[shift].add(run.run_id)
                if event["type"] == "checkout":
                    checkouts[shift] += 1
                    passed[shift] += int(flag(event, "passed") is True)
        last = max([shift_count or 0, *reached])
        result.append({
            "shift_count": shift_count,
            "runs": len(groups[shift_count]),
            "shifts": [
                {"shift": n, "runs_reached": len(reached[n]),
                 "pass_rate": rate(passed[n], checkouts[n])}
                for n in range(1, last + 1)
            ],
        })
    return result


def list_summary(runs: list[Run], catalogue: Catalogue) -> list[dict]:
    """Runs grouped by run_start's listed_aisles (sorted); win rate = won / (won + lost)."""
    groups: dict[str, list[Run]] = defaultdict(list)
    for run in runs:
        if run.start is None:
            continue
        aisles = id_list(run.start, "listed_aisles")
        if aisles is None:
            label = "(not logged: before v0.17)"
        elif not aisles:
            label = "(no aisles)"
        else:
            label = " + ".join(sorted(catalogue.aisle_name(a) for a in aisles))
        groups[label].append(run)
    result = []
    for label, group in groups.items():
        outcomes = Counter(run.outcome for run in group)
        result.append({
            "list": label, "runs": len(group), "won": outcomes["won"], "lost": outcomes["lost"],
            "not_ended": outcomes["abandoned"] + outcomes["unfinished"],
            "win_rate": rate(outcomes["won"], outcomes["won"] + outcomes["lost"]),
        })
    return sorted(result, key=lambda row: (-row["runs"], row["list"]))


def offer_time_summary(runs: list[Run]) -> dict:
    """presented_ms, armed_ms and decide_ms per offer type, without -1 ("not reached") values
    and without never-shown offers (debug or --demo-row rack replays, all times 0)."""
    result = {}
    for kind in OFFER_KINDS:
        offers = [o for run in runs for o in run.offers() if o.kind == kind]
        shown = [o for o in offers if not o.never_shown]
        times = {}
        for name, attribute in zip(OFFER_TIMES, ("presented", "armed", "decide")):
            values = [getattr(o, attribute) for o in shown]
            times[name] = {
                "dist": dist(v for v in values if v is not None and v >= 0),
                "not_reached": sum(1 for v in values if v is not None and v < 0),
                "not_logged": sum(1 for v in values if v is None),
            }
        result[kind] = {
            "offers": len(offers), "replays_excluded": len(offers) - len(shown), "times": times,
        }
    return result


def non_interactive_ms(run: Run) -> float | None:
    """The sum of armed_ms over the run's shown offers (rack, rewards, upgrades), or None
    (partial) when it has no shown offer or one of them lacks armed_ms (logged before v0.20)
    or logged -1."""
    values = [o.armed for o in run.offers() if not o.never_shown]
    if not values or any(v is None or v < 0 for v in values):
        return None
    return sum(v for v in values if v is not None)


def numbered_runs(players: list[Player], number: int) -> list[Run]:
    """Each player's run `number` (counted over all their runs, whatever the build filter)."""
    return [run for p in players if (run := p.run_number(number)) is not None]


def non_interactive_summary(players: list[Player]) -> list[dict]:
    groups = {
        "all runs": [run for p in players for run in p.runs],
        "won runs": [run for p in players for run in p.runs if run.outcome == "won"],
        "run 1": numbered_runs(players, 1),
        "run 2": numbered_runs(players, 2),
    }
    """Over ended (won or lost) runs whose every shown offer logged armed_ms; the others are
    counted as not ended or partial."""
    result = []
    for label, group in groups.items():
        ended = [run for run in group if run.outcome in ("won", "lost")]
        totals = [t for run in ended if (t := non_interactive_ms(run)) is not None]
        result.append({
            "group": label, "ms": dist(totals),
            "within_target": rate(sum(1 for t in totals if t <= NON_INTERACTIVE_TARGET_MS),
                                  len(totals)),
            "not_ended_excluded": len(group) - len(ended),
            "partial_excluded": len(ended) - len(totals),
        })
    return result


def _flag_rate(events: list[dict], key: str) -> dict:
    values = [v for e in events if (v := flag(e, key)) is not None]
    return rate(sum(values), len(values))


def count_up_summary(runs: list[Run]) -> dict:
    events = [e for run in runs for e in run.of_type("count_up")]
    skip_at = [
        v for e in events
        if flag(e, "skip_used") and (v := num(e, "skip_at_ms")) is not None and v >= 0
    ]
    return {
        "count_ups": len(events),
        "count_up_ms": dist(v for e in events if (v := num(e, "count_up_ms")) is not None),
        "fast_forward_used": _flag_rate(events, "fast_forward_used"),
        "skip_used": _flag_rate(events, "skip_used"),
        "skip_at_ms": dist(skip_at),
        "dessert_skipped": _flag_rate(events, "dessert_skipped"),
    }


def skip_rates(runs: list[Run]) -> dict:
    """presentation_skipped over the runs' shown offers; skip_used (a tap) and dessert_skipped
    over their count_up events."""
    offers = [
        o for run in runs for o in run.offers() if not o.never_shown and o.skipped is not None
    ]
    count_ups = [e for run in runs for e in run.of_type("count_up")]
    return {
        "runs": len(runs),
        "presentation_skipped": rate(sum(o.skipped for o in offers), len(offers)),
        "count_up_tap": _flag_rate(count_ups, "skip_used"),
        "dessert_skipped": _flag_rate(count_ups, "dessert_skipped"),
    }


def second_run_summary(players: list[Player]) -> dict:
    """Each player's second run (their runs in order of first event)."""
    return {
        "run_2": skip_rates(numbered_runs(players, 2)),
        "all_runs": skip_rates([run for p in players for run in p.runs]),
        "target": SECOND_RUN_SKIP_TARGET,
    }


def summarise(players: list[Player], inputs: Inputs, catalogue: Catalogue,
              include_debug: bool) -> dict:
    runs = [run for player in players for run in player.runs]
    return {
        "inputs": {
            "players": len(players),
            "files": inputs.files,
            "unreadable_files": inputs.unreadable,
            "events": inputs.events,
            "malformed_lines": inputs.malformed,
            "duplicate_events": inputs.duplicates,
            "unknown_event_types": dict(sorted(inputs.unknown_types.items())),
            "builds_present": dict(sorted(inputs.builds.items())),
            "build_filter": inputs.build_filter,
            "runs_of_other_builds": inputs.runs_of_other_builds,
            "events_of_other_builds": inputs.dropped_by_build,
            "merged_players": inputs.merged_players,
            "include_debug": include_debug,
            "session_files_as_players": inputs.session_files_as_players,
            "file_list": [
                {"player": name, "path": f.path, "readable": f.readable, "events": f.events,
                 "malformed": f.malformed}
                for name, f in inputs.file_list
            ],
        },
        "players": [
            {"player": p.name, "files": len(p.files), "sessions": p.sessions,
             "runs": len(p.runs), "debug_runs_excluded": p.debug_runs,
             "outcomes": dict(Counter(run.outcome for run in p.runs)),
             "restarts": len(p.restarts)}
            for p in players
        ],
        "runs": runs_summary(players),
        "checkouts": checkout_summary(players),
        "rewards": reward_summary(runs, catalogue),
        "impulse_rack": rack_summary(runs, catalogue),
        "products_picked": product_picks(runs, catalogue),
        "builds": build_summary(runs, catalogue),
        "shifts": shift_summary(runs),
        "lists": list_summary(runs, catalogue),
        "offer_times": offer_time_summary(runs),
        "non_interactive": non_interactive_summary(players),
        "count_up": count_up_summary(runs),
        "second_run": second_run_summary(players),
    }


# --- Text report ---------------------------------------------------------------------------


def fmt_rate(value: dict) -> str:
    if not value["n"]:
        return "- (0/0)"
    return f"{value['rate'] * 100:.0f}% ({value['count']}/{value['n']})"


def fmt_num(value: float | None, digits: int = 0) -> str:
    return "-" if value is None else f"{value:.{digits}f}"


def table(headers: list[str], rows: list[list[str]], indent: str = "  ") -> list[str]:
    """Aligned columns: the first left-aligned, the others right-aligned."""
    if not rows:
        return [indent + "(none)"]
    widths = [max(len(str(row[i])) for row in [headers, *rows]) for i in range(len(headers))]

    def line(cells: list[str]) -> str:
        parts = [str(cells[0]).ljust(widths[0])]
        parts += [str(cell).rjust(width) for cell, width in zip(cells[1:], widths[1:])]
        return (indent + "  ".join(parts)).rstrip()

    return [line(headers), indent + "  ".join("-" * w for w in widths), *map(line, rows)]


def dist_row(label: str, value: dict, digits: int = 0, scale: float = 1.0) -> list[str]:
    def scaled(key: str) -> str:
        v = value[key]
        return fmt_num(v / scale if v is not None else None, digits)

    return [label, str(value["n"]), scaled("median"), scaled("mean"), scaled("p90"),
            scaled("min"), scaled("max")]


DIST_HEADERS = ["", "n", "median", "mean", "p90", "min", "max"]


def heading(title: str, definition: str = "") -> list[str]:
    lines = ["", title, "-" * len(title)]
    if definition:
        lines += textwrap.wrap(definition, REPORT_WIDTH)
    return lines


def render_inputs(s: dict) -> list[str]:
    i = s["inputs"]
    builds = ", ".join(f"{k} ({v} events)" for k, v in i["builds_present"].items()) or "-"
    unknown = ", ".join(f"{k} ({v})" for k, v in i["unknown_event_types"].items()) or "none"
    lines = [
        "Next Customer log summary",
        "=========================",
        f"Players: {i['players']}; files: {i['files']}; events: {i['events']}",
        f"Skipped: {i['malformed_lines']} malformed lines, {i['duplicate_events']} duplicate "
        f"events (same session_id and seq), {len(i['unreadable_files'])} unreadable files",
        f"Unknown event types ignored: {unknown}",
        f"Build labels present: {builds}",
        "Build filter: " + _build_filter_text(i),
        "Debug runs: " + ("included (--include-debug)" if i["include_debug"] else
                          f"{s['runs']['debug_runs_excluded']} excluded (development play; "
                          "--include-debug keeps them)"),
    ]
    for names in i["merged_players"]:
        lines.append(
            f"Joined into one player: {', '.join(names)} share sessions (an export holds every "
            "session of its install, so they are the same tester's exports)."
        )
    if i["session_files_as_players"]:
        lines.append(
            f"Note: {i['session_files_as_players']} input files look like the game's own "
            "session files and each counted as a player; pass --one-player if they are one "
            "player's playtest_logs folder."
        )
    return lines


def _build_filter_text(i: dict) -> str:
    if not i["build_filter"]:
        return "none"
    labels = ", ".join(i["build_filter"])
    return (f"{labels}: whole runs kept by the build they started on (run_start's label); "
            f"{i['runs_of_other_builds']} runs of other builds dropped "
            f"({i['events_of_other_builds']} events, with other builds' loose events); run "
            "numbers count every run")


def render_players(s: dict) -> list[str]:
    rows = []
    # Both lists are built from the same players in the same order: pair them by position.
    for p, h in zip(s["players"], s["checkouts"]["players"]):
        o = p["outcomes"]
        rows.append([p["player"], str(p["files"]), str(p["sessions"]), str(p["runs"]),
                     str(o.get("won", 0)), str(o.get("lost", 0)), str(o.get("abandoned", 0)),
                     str(o.get("unfinished", 0)), str(p["restarts"]),
                     f"{h['class']} ({h['high']}/{h['counted']})"])
    return heading("Players", "One input file is one player unless --one-player; files that "
                   "share a session (the same install's exports) are one player. Class: see "
                   "Rearrangements.") + table(
        ["player", "files", "sessions", "runs", "won", "lost", "aband.", "unfin.", "restarts",
         "class (High/counted)"], rows)


def render_runs(s: dict) -> list[str]:
    r = s["runs"]
    screens = ", ".join(f"{k} {v}" for k, v in sorted(r["restarts_by_screen"].items())) or "-"
    lengths = ", ".join(f"{k} shifts: {v}" for k, v in r["shift_counts"].items()) or "-"
    return heading(
        "Runs",
        "A run is one run_id, joined across sessions (run_resume continues it). Won or lost: "
        "its run_end; abandoned: run_abandon; unfinished: neither. run_start is only logged "
        "once the impulse rack is picked or skipped.",
    ) + [
        f"  runs: {r['runs']} ({r['with_run_start']} with run_start, {r['without_run_start']} "
        "without)",
        f"  without run_start: {r['without_run_start_at_rack']} abandoned or unfinished at the "
        f"impulse rack, {r['without_run_start'] - r['without_run_start_at_rack']} started in "
        "a session not given",
        f"  won {r['won']}; lost {r['lost']}; abandoned {r['abandoned']}; unfinished "
        f"{r['unfinished']}",
        f"  win rate (won / (won + lost)): {fmt_rate(r['win_rate'])}",
        f"  restart rate (restart events / run_end events): {fmt_rate(r['restart_rate'])}; "
        f"by screen: {screens}",
        f"  runs resumed: {r['resumed_runs']} ({r['resumes']} run_resume events)",
        f"  run length (run_start shift_count): {lengths}",
    ]


def render_checkouts(s: dict) -> list[str]:
    c = s["checkouts"]
    buckets = table(["rearrangements", "checkouts"],
                    [[b["bucket"], str(b["count"])] for b in c["rearrangement_buckets"]])
    measures = table(DIST_HEADERS, [
        dist_row("rearrangements", c["rearrangements"], 1),
        dist_row("placements", c["placements"], 1),
        dist_row("removals", c["removals"], 1),
        dist_row("distinct projected totals", c["distinct_projected_totals"], 1),
        dist_row("planning time (s)", c["planning_ms"], 1, 1000.0),
    ])
    methods = ", ".join(f"{k} {fmt_rate(v)}" for k, v in c["input_methods"].items()) or "-"
    return heading(
        "Rearrangements per checkout",
        "Checkout fields as logged (section 8, \"Checkout measures\"). High: a checkout of 3+ "
        "cards with rearrangements >= 2 x cards committed (final_order); a player is High when "
        "more than half of their counted checkouts are.",
    ) + [f"  checkouts: {c['checkouts']}; High: {fmt_rate(c['high_checkouts'])} of the "
         "checkouts of 3+ cards", ""] + measures + [""] + buckets + [
        f"  input method: {methods}"]


def render_rewards(s: dict) -> list[str]:
    w = s["rewards"]
    rows = [[row["name"], row["kind"], fmt_rate(row["first"]), fmt_rate(row["later"]),
             fmt_rate(row["all"])] for row in w["cards"]]
    k = s["impulse_rack"]
    rack_rows = [[row["name"], row["kind"], fmt_rate(row["rack"])] for row in k["cards"]]
    picks = [[row["name"], str(row["reward"]), str(row["rack"]), str(row["total"])]
             for row in s["products_picked"]]
    return heading(
        "Reward pick rates",
        "Per card: picks / times offered, over reward events. The first offer is each run's "
        "reward with the lowest shift (it always holds a combination coupon); later = the rest.",
    ) + [
        f"  reward offers: {w['rewards']['first']} first, {w['rewards']['later']} later",
        f"  skip rate (skipped rewards / rewards): first {fmt_rate(w['skip_rate']['first'])}, "
        f"later {fmt_rate(w['skip_rate']['later'])}, all {fmt_rate(w['skip_rate']['all'])}", "",
    ] + table(["card", "kind", "first offer", "later offers", "all offers"], rows) + heading(
        "Impulse rack",
        "From run_start: racks shown (non-empty impulse_offer, leaving out never-shown racks "
        "with all times 0, which are counted); pick rate = picks / racks shown.",
    ) + [
        f"  racks: {k['racks']} ({k['never_shown_excluded']} never-shown excluded); picked "
        f"{fmt_rate(k['pick_rate'])}; skipped {fmt_rate(k['skip_rate'])}", "",
    ] + table(["card", "kind", "picks / offered"], rack_rows) + heading(
        "Most-picked products", "Product picks from rewards and the shown impulse racks."
    ) + table(["product", "reward", "rack", "total"], picks)


def render_builds(s: dict) -> list[str]:
    b = s["builds"]
    rows = [[row["coupons"], row["upgrades"], str(row["runs"]), fmt_rate(row["win_rate"])]
            for row in b["builds"]]
    sets = [[row["coupons"], str(row["runs"]), fmt_rate(row["win_rate"])]
            for row in b["coupon_sets"]]
    unknown = ", ".join(f"{k} x{v}" for k, v in b["unknown_cards"].items()) or "none"
    return heading(
        "Builds",
        "Over won and lost runs with a run_start. Final deck = starting_deck + impulse_pick - "
        "impulse_replaced, then each reward's picked - replaced. Build = the final deck's "
        "coupons (kind from data/cards) + the upgrades taken (run_end's upgrades). Win rate = "
        "won / runs.",
    ) + [f"  runs: {b['runs']}; unknown card ids in final decks: {unknown}", ""] + table(
        ["coupons", "upgrades", "runs", "win rate"], rows
    ) + [""] + table(["coupons alone", "runs", "win rate"], sets)


def render_shifts(s: dict) -> list[str]:
    lines = heading(
        "Win rate per shift",
        "Checkouts at shift n that passed / checkouts at shift n; runs reached = runs with a "
        "shift_start or checkout at n. Grouped by run_start's shift_count; runs without a "
        "run_start are left out.",
    )
    without = s["runs"]["without_run_start"]
    if without:
        lines.append(f"  runs without run_start (left out; see Runs): {without}")
    for group in s["shifts"]:
        count = group["shift_count"]
        label = f"{count}-shift runs" if count is not None else (
            "runs of unknown length (no shift_count: before v0.12; proto-r1 had 5 shifts)")
        lines.append(f"  {label}: {group['runs']}")
        lines += table(["shift", "runs reached", "passed"],
                       [[str(row["shift"]), str(row["runs_reached"]), fmt_rate(row["pass_rate"])]
                        for row in group["shifts"]], indent="    ")
    if not s["shifts"]:
        lines.append("  (none)")
    return lines


def render_lists(s: dict) -> list[str]:
    rows = [[row["list"], str(row["runs"]), str(row["won"]), str(row["lost"]),
             str(row["not_ended"]), fmt_rate(row["win_rate"])] for row in s["lists"]]
    return heading(
        "Win rate per list",
        "Runs grouped by run_start's listed_aisles (every listable aisle when the list is "
        "skipped). Win rate = won / (won + lost).",
    ) + table(["listed aisles", "runs", "won", "lost", "not ended", "win rate"], rows)


def render_offer_times(s: dict) -> list[str]:
    lines = heading(
        "Offer presentation times (ms)",
        "From the offer's show (section 8, \"Offer presentation times\"). -1 (not reached) "
        "values and never-shown offers (rack replays logging 0) are left out and counted.",
    )
    for kind in OFFER_KINDS:
        o = s["offer_times"][kind]
        lines.append(f"  {kind}: {o['offers']} offers, {o['replays_excluded']} never-shown "
                     "excluded")
        rows = []
        for name in OFFER_TIMES:
            t = o["times"][name]
            row = dist_row(name, t["dist"])
            rows.append(row + [str(t["not_reached"]), str(t["not_logged"])])
        lines += table(DIST_HEADERS + ["-1", "not logged"], rows, indent="    ")
    ni = s["non_interactive"]
    lines += heading(
        "Non-interactive offer time per run (s)",
        "Sum of armed_ms over a run's shown offers (rack, rewards, upgrades); target about "
        f"{NON_INTERACTIVE_TARGET_MS // 1000} s or less per run (full build plan section 9). "
        "Only ended (won or lost) runs whose every shown offer logged armed_ms are counted; "
        "runs not ended and partial runs (an offer without armed_ms, logged before v0.20, or "
        "with -1) are left out and counted.",
    )
    lines += table(DIST_HEADERS + ["<= 15 s", "not ended", "partial"],
                   [dist_row(row["group"], row["ms"], 1, 1000.0)
                    + [fmt_rate(row["within_target"]), str(row["not_ended_excluded"]),
                       str(row["partial_excluded"])]
                    for row in ni])
    return lines


def render_count_up(s: dict) -> list[str]:
    c = s["count_up"]
    return heading(
        "Count-up",
        "count_up events (section 8, \"Count-up input\"); rates over the events that log the "
        "field.",
    ) + [f"  count-ups: {c['count_ups']}", ""] + table(DIST_HEADERS, [
        dist_row("count_up_ms", c["count_up_ms"]),
        dist_row("skip_at_ms (taps)", c["skip_at_ms"]),
    ]) + [
        f"  fast_forward_used: {fmt_rate(c['fast_forward_used'])}",
        f"  skip_used (a tap): {fmt_rate(c['skip_used'])}",
        f"  dessert_skipped: {fmt_rate(c['dessert_skipped'])}",
    ]


def render_second_run(s: dict) -> list[str]:
    r = s["second_run"]
    target = f"{r['target'] * 100:.0f}%"
    rows = []
    for label, key in (("run 2", "run_2"), ("all runs", "all_runs")):
        v = r[key]
        rows.append([label, str(v["runs"]), fmt_rate(v["presentation_skipped"]),
                     fmt_rate(v["count_up_tap"]), fmt_rate(v["dessert_skipped"])])
    return heading(
        "Second-run skip rate",
        "Run 2 is each player's second run. Presentations skipped = presentation_skipped over "
        "the run's shown offers (rewards, upgrades, the impulse rack); target below about "
        f"{target} for run 2 (full build plan section 9). It stays 0% until phase 3 adds "
        "skippable presentations. The count-up tap (skip_used) and dessert_skipped are over "
        "the run's count_up events, reported apart.",
    ) + table(["", "runs", "presentations skipped", "count-up tap", "dessert skipped"], rows)


def render_files(s: dict) -> list[str]:
    """Every input file, by folder; with the player's name when it isn't the file's."""
    files = s["inputs"]["file_list"]
    named = any(f["player"] != Path(f["path"]).name for f in files)
    groups: dict[str, list[list[str]]] = defaultdict(list)
    for f in files:
        path = Path(f["path"])
        row = [path.name, str(f["events"]) if f["readable"] else "unreadable",
               str(f["malformed"])]
        groups[str(path.parent)].append(row + [f["player"]] if named else row)
    lines = heading("Files read")
    for folder, rows in groups.items():
        lines.append(f"  in {folder}:")
        headers = ["file", "events", "malformed"] + (["player"] if named else [])
        lines += table(headers, rows, indent="    ")
    return lines


def render(summary: dict) -> str:
    sections = [render_inputs, render_players, render_runs, render_checkouts, render_rewards,
                render_builds, render_shifts, render_lists, render_offer_times, render_count_up,
                render_second_run, render_files]
    lines: list[str] = []
    for section in sections:
        lines += section(summary)
    return "\n".join(lines) + "\n"


# --- Command line --------------------------------------------------------------------------


class _Parser(argparse.ArgumentParser):
    def error(self, message: str) -> None:  # Exit code 2, like argparse's own.
        self.print_usage(sys.stderr)
        self.exit(2, f"error: {message}\n")


def parse_args(argv: list[str]) -> argparse.Namespace:
    parser = _Parser(description="Summarises Next Customer playtest logs (plan section 8).")
    parser.add_argument("paths", nargs="*", help=".jsonl files or folders of them")
    parser.add_argument("--one-player", action="store_true",
                        help="every input file belongs to the same player")
    parser.add_argument("--include-debug", action="store_true",
                        help="keep runs that used the debug panel")
    parser.add_argument("--build", action="append", metavar="LABEL",
                        help="only runs that started on this build label (whole runs, by "
                        "their run_start's label; run numbers still count every run; "
                        "repeatable)")
    parser.add_argument("--json", metavar="PATH", help="also write the numbers as JSON")
    parser.add_argument("--report", metavar="PATH", default=str(DEFAULT_REPORT),
                        help="the text report's file")
    parser.add_argument("--data", metavar="PATH", default=str(DEFAULT_DATA),
                        help="the game's data folder (card kinds and names)")
    return parser.parse_args(argv)


def output_path_error(path: Path) -> str | None:
    """Why the report or JSON can't be written to `path` (its folder is created), else None."""
    if path.is_dir():
        return "it is a folder"
    try:
        path.parent.mkdir(parents=True, exist_ok=True)
    except OSError as error:
        return error.strerror or str(error)
    if not path.parent.is_dir():
        return f"{path.parent} is not a folder"
    return None


def write_text(path: Path, content: str) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    if path.resolve().is_relative_to(REPO / "reports"):
        (REPO / "reports" / ".gdignore").touch()  # Keeps Godot's import out of reports/.
    path.write_text(content, encoding="utf-8", newline="\n")


def write_outputs(outputs: list[tuple[Path, str]]) -> int:
    """Writes each (path, content); 2 with an error on stderr when one can't be written."""
    for path, content in outputs:
        try:
            write_text(path, content)
        except OSError as error:
            print(f"error: cannot write {path}: {error.strerror or error}", file=sys.stderr)
            return 2
    return 0


def main(argv: list[str] | None = None) -> int:
    if hasattr(sys.stdout, "reconfigure"):
        sys.stdout.reconfigure(errors="replace")
    args = parse_args(sys.argv[1:] if argv is None else argv)
    outputs = [Path(args.report)] + ([Path(args.json)] if args.json else [])
    for path in outputs:
        if (reason := output_path_error(path)) is not None:
            print(f"error: cannot write {path}: {reason}", file=sys.stderr)
            return 2
    catalogue = load_catalogue(Path(args.data))
    if not catalogue.cards:
        print(f"error: no card data in {Path(args.data) / 'cards'}", file=sys.stderr)
        return 2
    paths, one_player = args.paths, args.one_player
    if not paths:
        folder = default_log_folder()
        print(f"No path given: reading {folder} as one player.", file=sys.stderr)
        paths, one_player = [str(folder)], True
    try:
        player_files = resolve_players(paths, one_player)
    except InputError as error:
        print(f"error: {error}", file=sys.stderr)
        return 2
    players, inputs = load_players(player_files, one_player, args.include_debug, args.build)
    if inputs.events == 0:
        print("error: no readable events in the input.", file=sys.stderr)
        return 2
    summary = summarise(players, inputs, catalogue, args.include_debug)
    report = render(summary)
    sys.stdout.write(report)
    contents = [report] + ([json.dumps(summary, indent=2) + "\n"] if args.json else [])
    return write_outputs(list(zip(outputs, contents)))


if __name__ == "__main__":
    sys.exit(main())
