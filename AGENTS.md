# Next Customer

A single-player 2D roguelike about a supermarket cashier. Players draft grocery and coupon cards, arrange their scanning order, and meet a sales quota each shift. Windows (mouse) with a browser build for playtests.

**Current phase: prototype.** Read `docs/PROTOTYPE_PLAN.md` before starting work. `docs/FULL_BUILD_PLAN.md` describes later phases; don't implement anything from it unless asked.

## Engine and language

- Godot 4.7 (4.7.stable), GDScript only, with static typing everywhere. The engine version is pinned here (and in the table below); the plans just say Godot 4.
- Static typing is enforced by the project setting `debug/gdscript/warnings/untyped_declaration`, set to **Error** in `project.godot`. Without it, "no warnings" doesn't catch missing types.
- Every enabled GDScript warning is set to **Error** so `tools/check.sh` rejects warnings. Disabled warnings stay disabled, and third-party addons use Godot's default warning exclusion.
- Godot 4 syntax only. Never use Godot 3 forms: `yield` (use `await`), `export var` (use `@export`), `onready var` (use `@onready`), `KinematicBody2D` (use `CharacterBody2D`), `Tween.new()` nodes (use `create_tween()`), `instance()` (use `instantiate()`), `connect("signal", obj, "method")` with strings (use `signal_name.connect(callable)`), `setget` (use property `set:` and `get:` blocks).
- Follow the official GDScript style guide: `snake_case` file and folder names, member order signals → enums → constants → `@export` → variables → methods.

## Commands

Run these from the repo root in a POSIX shell (Git Bash on Windows). `godot` must be on the `PATH`, or set `GODOT_BIN` to the Godot executable. Install the Python tools once with `python -m pip install -r tools/requirements.txt`.

| Purpose | Command | Exact version |
|---|---|---|
| Run tests (GdUnit4) | `sh tools/test.sh` (one suite: `sh tools/test.sh -a res://tests/path_test.gd`) | GdUnit4 6.2.1 |
| Parse and type-check a script, then lint and format-check it | `sh tools/check.sh path/to/script.gd` (no arguments: every script outside `addons/`) | Godot 4.7.stable |
| Lint (gdlint) | `python -m gdtoolkit.linter <paths>` | gdtoolkit 4.5.0 |
| Format (gdformat) | `python -m gdtoolkit.formatter <paths>` | gdtoolkit 4.5.0 |
| Re-import after editing scenes or resources | `godot --headless --path . --import` | Godot 4.7.stable |
| Export the web build | `sh tools/export_web.sh` (output in `build/web/`) | Godot 4.7.stable |
| Export the Windows build | `sh tools/export_windows.sh` (output in `build/windows/`) | Godot 4.7.stable |

Test reports are written to `reports/` (ignored by git). The build label shown to players and in the log (`proto-r1` …) is the project setting `next_customer/build_label`; `application/config/version` stays numeric because Windows requires it.

What each check covers:
- **Tests** verify the behaviour they cover. Passing tests don't prove that every rule is correct.
- **Godot's parser and warnings** check syntax and types. A check of one script covers only that script, not the whole game.
- **gdlint** checks its configured lint rules only. It is not a type checker.
- **gdformat** formats; don't hand-format against it.

## Architecture

- `core/` holds pure game logic. See `core/AGENTS.md` before changing anything there.
- Card, deck and balance values live only in `data/` (`.tres` resources). Never hard-code card values in scripts. This includes the numbers inside rules (bonuses, multipliers, charges): they are `@export` fields on rule resources.
- UI and presentation display a `ScoreResult`; they never calculate scores themselves.
- Expose a scene's behaviour through its root node; keep references to internal nodes encapsulated. Communicate upward with signals and downward with method calls.
- Keep autoloads to genuinely global services (e.g. the event log). Run state is passed explicitly, never stored in an autoload.
- Don't modify third-party source in `addons/`. Installing or updating pinned dependencies is allowed when requested as part of project setup.
- Don't edit `.godot/` (generated).
- `.tscn` and `.tres` files are text and may be edited, but re-import and run the tests afterwards: UIDs and resource IDs break easily.

## Git

- Branch names: `type/short-description` in lowercase, with `type` one of `feature`, `fix`, `docs`, `chore`, `refactor`, `test`. Never put agent or tool names in branch names.
- Commit `.uid` and `.import` files. Never add them to `.gitignore`.
- When moving or renaming a script, move its `.uid` file with it (`git mv a.gd b.gd` and `git mv a.gd.uid b.gd.uid`).
- Commit `export_presets.cfg` (web and Windows). Godot keeps export credentials in `.godot/`, which is never committed. Never set a script encryption key in a committed preset: that key is stored in the preset file.
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
