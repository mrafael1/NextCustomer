# Next Customer

A single-player 2D roguelike about a supermarket cashier. Players draft grocery and coupon cards, arrange their scanning order, and meet a sales quota each shift. Windows (mouse) with a browser build for playtests.

**Current phase: full build, phase 2.** Phase 1 closed on 2026-10-08; phase 2's tasks are the issues on the GitHub milestone "Phase 2", each starting with what to decide with the user. Read `docs/FULL_BUILD_PLAN.md` before starting work; build only the current phase, and ask before starting work from a later one. The prototype closed at proto-r1; `docs/PROTOTYPE_PLAN.md` stays the scoring-rule spec that `core/AGENTS.md` points to.

## Engine and language

- Godot 4.7 (4.7.stable), GDScript only, with static typing everywhere. The engine version is pinned here (and in the table below); the plans just say Godot 4.
- Static typing is enforced by the project setting `debug/gdscript/warnings/untyped_declaration`, set to **Error** in `project.godot`. Without it, "no warnings" doesn't catch missing types.
- Every enabled GDScript warning is set to **Error** so `tools/check.sh` rejects warnings. Disabled warnings stay disabled, and third-party addons use Godot's default warning exclusion.
- Godot 4 syntax only. Never use Godot 3 forms: `yield` (use `await`), `export var` (use `@export`), `onready var` (use `@onready`), `KinematicBody2D` (use `CharacterBody2D`), `Tween.new()` nodes (use `create_tween()`), `instance()` (use `instantiate()`), `connect("signal", obj, "method")` with strings (use `signal_name.connect(callable)`), `setget` (use property `set:` and `get:` blocks).
- Follow the official GDScript style guide: `snake_case` file and folder names, member order signals → enums → constants → `@export` → variables → methods.

## Commands

Run these from the repo root in a POSIX shell (Git Bash on Windows). `godot` must be on the `PATH`, or set `GODOT_BIN` to the Godot executable. Install the Python tools once with `python -m pip install -r tools/requirements.txt`. The scripts in `tools/` re-import the project before running, so new `class_name` scripts and resource UIDs are picked up. Godot exits 0 even when an import, export or test run hits errors, so the scripts scan its output for error lines, and the import also fails on any asset marked `valid=false` from an earlier import. Never rely on the exit code of a raw `godot` command. The import catches broken assets, but it is not a reliable check for broken links inside `.tres` or `.tscn` files (it only reports them for scenes the editor happens to load, such as the main scene). Those are caught by the resource-loading test from plan section 3.7 (it loads every `.tres` and `.tscn` in `data/`, `ui/`, `presentation/`, `debug/`, `telemetry/` and the golden fixture, and `tools/test.sh` fails on any Godot error printed while it runs) and by the exports, which skip `debug/` and `tests/`. The resource-loading test is written on day 1; until it exists, only the exports catch broken links. `tools/test.sh` also fails when no tests ran, e.g. after a mistyped suite path. The scripts keep `build/` and `reports/` out of Godot's import with `.gdignore` files.

| Purpose | Command | Exact version |
|---|---|---|
| Run tests (GdUnit4); fails on a failed test or any Godot error | `sh tools/test.sh` (one suite: `sh tools/test.sh -a res://tests/path_test.gd`; the full run also runs the Python tools' tests, `tools/*_test.py`, with `$PYTHON`, else `python3`, else `python`) | GdUnit4 6.2.1 |
| Re-import, parse and type-check a script, then lint and format-check it | `sh tools/check.sh path/to/script.gd` (no arguments: every script outside `addons/`) | Godot 4.7.stable |
| Lint (gdlint) | `python -m gdtoolkit.linter <paths>` | gdtoolkit 4.5.0 |
| Format (gdformat) | `python -m gdtoolkit.formatter <paths>` | gdtoolkit 4.5.0 |
| Re-import after editing scenes or resources | `sh tools/import.sh` | Godot 4.7.stable |
| Export the web build (fails on any Godot error) | `sh tools/export_web.sh` (output in `build/web/`) | Godot 4.7.stable |
| Export the Windows build (fails on any Godot error) | `sh tools/export_windows.sh` (output in `build/windows/`) | Godot 4.7.stable |
| Balance simulator (plan section 8); fails on any Godot error | `sh tools/balance_sim.sh --runs=200 --strategy=greedy,random,skip` (options in `tools/balance_sim/balance_sim.gd`; report in `reports/balance_sim/report.txt`) | Godot 4.7.stable |
| Pixel art (`docs/FULL_BUILD_PLAN.md` section 6.1): builds `art/**/*.png` from the text sources in `art/src/` | `python tools/pixel_art.py build` (then `sh tools/import.sh`); `check` lints the sources and fails on a missing or stale PNG; `sheet` writes review previews to `reports/art/`; its tests: `python tools/pixel_art_test.py` | Python 3.11+ (standard library only) |
| Log summary (`docs/PROTOTYPE_PLAN.md` section 8): summarises playtest logs; each file is one player | `python tools/log_summary.py <exported .jsonl files or folders>` (no path: the desktop game's `playtest_logs` folder as one player; options in the script's docstring; report in `reports/log_summary/report.txt`); its tests: `python tools/log_summary_test.py` | Python 3.11+ (standard library only) |

Test reports are written to `reports/` (ignored by git). The build label shown to players and in the log (`fb-p1` …) is the project setting `next_customer/build_label`; `application/config/version` stays numeric because Windows requires it.

What each check covers:
- **Tests** verify the behaviour they cover. Passing tests don't prove that every rule is correct.
- **Godot's parser and warnings** check syntax and types. A check of one script covers only that script, not the whole game.
- **gdlint** checks its configured lint rules only. It is not a type checker.
- **gdformat** formats; don't hand-format against it.
- **The Python tests** (`tools/*_test.py`, unittest) cover the Python tools, such as the log summary, on synthetic logs. They need no Godot.

## Architecture

- `core/` holds pure game logic. See `core/AGENTS.md` before changing anything there.
- Card, deck and balance values live only in `data/` (`.tres` resources). Never hard-code card values in scripts. This includes the numbers inside rules (bonuses, multipliers, charges): they are `@export` fields on rule resources.
- UI and presentation display a `ScoreResult`; they never calculate scores themselves.
- Expose a scene's behaviour through its root node; keep references to internal nodes encapsulated. Communicate upward with signals and downward with method calls.
- Keep autoloads to genuinely global services (e.g. the event log). Run state is passed explicitly, never stored in an autoload.
- Tests must not let an error reach Godot's output, even one they expect: `tools/test.sh` fails on any error line. Code that reports errors (e.g. the logger's `push_error` when a file can't be opened) takes its error reporter as an injectable `Callable` that defaults to `push_error`; tests pass a recorder and assert on what it received.
- Don't modify third-party source in `addons/`. Installing or updating pinned dependencies is allowed when requested as part of project setup.
- Don't edit `.godot/` (generated).
- `.tscn` and `.tres` files are text and may be edited, but run `sh tools/import.sh` and `sh tools/test.sh` afterwards: UIDs and resource IDs break easily, and the resource-loading test is what catches a broken link. A new folder of scenes or resources must be added to that test.

## Git

- Branch names: `type/short-description` in lowercase, with `type` one of `feature`, `fix`, `docs`, `chore`, `refactor`, `test`. Never put agent or tool names in branch names.
- Commit `.uid` and `.import` files. Never add them to `.gitignore`.
- When moving or renaming a script, move its `.uid` file with it (`git mv a.gd b.gd` and `git mv a.gd.uid b.gd.uid`).
- Commit `export_presets.cfg` (web and Windows). Godot keeps export credentials in `.godot/`, which is never committed. Don't enable PCK or script encryption for the prototype: the key would live only in `.godot/export_credentials.cfg`, so a fresh clone couldn't export.
- `.gitignore` covers `.godot/`, build output and generated test reports. It is set up on `chore/project-setup`.
- Don't commit or push without being asked.
- Never merge into `main`, push to `main` or commit on it, even when asked to push. Work happens on its own branch and reaches `main` only through a pull request that the user reviews and merges.

## Working agreement

- Complete the requested task and its necessary checks. Fix routine implementation problems along the way.
- Ask before expanding features, adding anything outside the request, or changing agreed game rules.
- Fix code that violates an unambiguous agreed rule. Ask when specifications conflict or the intended behaviour is unclear.

## Definition of done

- All tests pass, including the golden scoring examples in `core/AGENTS.md`.
- Changed scripts parse with no warnings or errors.
- Lint and format are clean.
- If a playtest-facing change was made, the plan's changelog is updated or the change is flagged for it.
