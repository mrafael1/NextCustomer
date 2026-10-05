# Next Customer

A single-player 2D roguelike about a supermarket cashier. Players draft grocery and coupon cards, arrange their scanning order, and meet a sales quota each shift. Windows (mouse) with a browser build for playtests.

**Current phase: prototype.** Read `docs/PROTOTYPE_PLAN.md` before starting work. `docs/FULL_BUILD_PLAN.md` describes later phases; don't implement anything from it unless asked.

## Engine and language

- Godot 4.7.2, GDScript only, with static typing everywhere. The engine version is pinned here (and in the table below); the plans just say Godot 4.
- Static typing is enforced by the project setting `debug/gdscript/warnings/untyped_declaration`, set to **Error** on `chore/project-setup`. Without it, "no warnings" doesn't catch missing types.
- Godot 4 syntax only. Never use Godot 3 forms: `yield` (use `await`), `export var` (use `@export`), `onready var` (use `@onready`), `KinematicBody2D` (use `CharacterBody2D`), `Tween.new()` nodes (use `create_tween()`), `instance()` (use `instantiate()`), `connect("signal", obj, "method")` with strings (use `signal_name.connect(callable)`), `setget` (use property `set:` and `get:` blocks).
- Follow the official GDScript style guide: `snake_case` file and folder names, member order signals → enums → constants → `@export` → variables → methods.

## Commands

> **Pending verification.** These are filled in on `chore/project-setup`, after each one has run successfully on this project. Until then, don't guess commands or add unverified ones here.

| Purpose | Command | Exact version |
|---|---|---|
| Run tests (GdUnit4) | *pending* | *pending* |
| Parse and type-check a script | *pending* | Godot 4.7.2 |
| Lint (gdlint) | *pending* | *pending* |
| Format (gdformat) | *pending* | *pending* |
| Re-import after editing scenes or resources | *pending* | Godot 4.7.2 |
| Export the web build | *pending* | Godot 4.7.2 |

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

## Working agreement

- Complete the requested task and its necessary checks. Fix routine implementation problems along the way.
- Ask before expanding features, adding anything outside the request, or changing agreed game rules.
- Fix code that violates an unambiguous agreed rule. Ask when specifications conflict or the intended behaviour is unclear.

## Definition of done

- All tests pass, including the golden scoring examples in `core/AGENTS.md`.
- Changed scripts parse with no warnings or errors.
- Lint and format are clean.
- If a playtest-facing change was made, the plan's changelog is updated or the change is flagged for it.
