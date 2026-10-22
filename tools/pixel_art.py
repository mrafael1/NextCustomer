"""Builds the game's pixel art from text sources (docs/FULL_BUILD_PLAN.md section 6.1).
Python 3.11+ standard library only. Run from the repo root:

    python tools/pixel_art.py build    # write every PNG from its source
    python tools/pixel_art.py check    # lint the sources; fail if a PNG is missing or stale
    python tools/pixel_art.py sheet    # write review previews to reports/art/

Each sprite is a text file under art/src/ (ignored by Godot): directives, then one row of
palette keys per pixel row. art/src/items/milk.txt becomes art/items/milk.png, and any folder
works the same way (art/src/items_v2/milk.txt becomes art/items_v2/milk.png): @kind, not the
folder, picks the lint. Lines starting with ';' are comments, and blank lines are skipped.

    ; Milk, a gable-top carton.
    @size 32x32
    @kind item
    ....##....
    ...#cc#...

Directives:
    @size WxH   the grid's size (required); every row must match it
    @kind K     item, perk, frame, icon or scenery (required); items get the strictest lint
    @scale N    write the PNG N times larger (default 1), for frames a StyleBoxTexture stretches

A derived source holds no grid and no other directive, only (after its comments)

    @derive <source> golden=<map>

which renders another source's pixels through a GOLDEN palette map (#77's item tiers:
art/src/items_v2/milk_golden.txt holds "@derive milk_big golden=rank"). <source> is named
relative to the derived source's folder and must be a drawn source (not a derived one); the
derived sprite takes its size, kind and scale. The maps (GOLDEN_MAPS) are ported from the
approved prep script docs/art/mockups/machine_77_src/upgrades/gen_upgrades.py:
    rank    the source's colours sorted by luminance, spread over GOLDEN_RANK_STEPS (brass
            darkest to gold), then a 1 px paper glint on every 19th diagonal of the lit gold
    yellow  GOLDEN_YELLOW_MAP for a yellow item (one step darker and shiny), plus a paper rim
            on the lit top edge (a mustard pale pixel right under the outline)
    egg     GOLDEN_EGG_MAP for the eggs (the carton keeps its greys), a brass dark rim where
            an egg meets the carton, and one paper highlight per egg
Each map then re-inks: rows 0-1 cleared and every opaque pixel on the outline made ink. A
derived source is linted, built, checked (missing or stale) and previewed like any other.

art/src/palette.txt lists the palette, one colour per line: a single-character key, a hex
colour and a name. The key '.' is transparent. The PNGs are indexed (PLTE + tRNS) and hold the
whole palette, so recolouring the palette and rebuilding changes every sprite at once.

Lint (check): rows match @size, keys are in the palette, an item is its folder's size
(ITEM_SIZE_BY_FOLDER: 48x48 for the style frame v2 items in art/src/items_v2/, 32x32 for the
game's items everywhere else) at @scale 1, leaves its top
ITEM_EMPTY_TOP_ROWS rows transparent (the card crops them), uses at most MAX_ITEM_COLOURS colours
and has an ink ('#') outline: every opaque pixel that touches a transparent pixel or the edge
(4-neighbours) is ink. A PNG is stale when its decoded pixels or
palette differ from a fresh build (not its bytes, since zlib's output varies between versions);
build rewrites only those. A PNG under art/ (outside art/src/) without a source is an orphan.

sheet writes reports/art/preview/<name>.png for each sprite: 8x on cream and teal, then 1x, 2x
and 4x on cream and teal, then a greyscale and a silhouette at 4x. It also writes
reports/art/contact_sheet.png with every sprite at 1x and 2x, in the order listed in
reports/art/contact_sheet.txt.

Exit code 0 on success; 1 when check finds a problem, or when build or sheet meets a source with
errors (the sources that parse are still written); 2 on bad arguments or an unreadable palette.
Tests: python tools/pixel_art_test.py
"""

from __future__ import annotations

import argparse
import struct
import sys
import zlib
from dataclasses import dataclass
from pathlib import Path

REPO = Path(__file__).resolve().parent.parent
DEFAULT_SRC = REPO / "art" / "src"
DEFAULT_OUT = REPO / "art"
DEFAULT_REPORTS = REPO / "reports" / "art"
PALETTE_FILE = "palette.txt"

TRANSPARENT = "."
INK = "#"
KINDS = frozenset({"item", "perk", "frame", "icon", "scenery"})
# The first items were 32x32 (the retired card view's sprite box); every item is now drawn on a
# 48x48 grid in art/src/items_v2/ (#75, decision 3A), until #57 retires the 32x32 Milk. An
# item's size follows its top folder.
ITEM_SIZE = (32, 32)
ITEM_SIZE_BY_FOLDER = {"items_v2": (48, 48)}
# An item stands on its bottom row and its top rows stay empty (the card view cropped them).
ITEM_EMPTY_TOP_ROWS = 2
# Keys that can't be palette keys: they start a directive or a comment in a source.
RESERVED_KEYS = frozenset({"@", ";"})
MAX_ITEM_COLOURS = 12
# Preview backgrounds: the palette's cream paper and dark teal (keys 'c' and '2').
PREVIEW_BACKGROUND_KEYS = ("c", "2")
PREVIEW_GAP = 8

PNG_SIGNATURE = b"\x89PNG\r\n\x1a\n"

# GOLDEN palette maps (#77 item tiers; art data, not game balance), ported exactly from
# docs/art/mockups/machine_77_src/upgrades/gen_upgrades.py. The rank map's steps, dark to light:
# brass darkest, brass dark, brass, gold, mustard pale.
GOLDEN_RANK_STEPS = ("k", "l", "L", "n", "Y")
GOLDEN_RANK_GLINT_KEYS = frozenset({"n", "Y", "L"})
GOLDEN_RANK_GLINT_PERIOD = 19
# A yellow item goes one step darker and shiny: body brass, lit side gold, shade brass dark,
# seams and tips brass darkest, the green crown and brown stem brass too.
GOLDEN_YELLOW_MAP = {"Y": "n", "y": "L", "M": "l", "m": "k", "u": "k", "e": "k", "f": "l",
                     "z": "n", "G": "L", "g": "l"}
GOLDEN_YELLOW_RIM_FROM = "Y"
# Paper: the rank map's glint, the yellow map's rim and the egg map's highlights.
GOLDEN_PAPER = "w"
# Only the eggs go gold (light side mustard pale, body gold, shade brass, dark brass dark).
GOLDEN_EGG_MAP = {"b": "L", "c": "n", "w": "Y", "a": "l"}
GOLDEN_EGG_KEYS = ("w", "c", "b")
GOLDEN_EGG_SHADE = "a"
GOLDEN_EGG_RIM = "l"
DERIVE_DIRECTIVE = "@derive"
GOLDEN_PREFIX = "golden="

RGBA = tuple[int, int, int, int]
Grid = list[list[str]]


class ArtError(Exception):
    """A source or palette that can't be read."""


@dataclass
class Palette:
    keys: list[str]
    colours: dict[str, RGBA]

    def index(self, key: str) -> int:
        return self.keys.index(key)


@dataclass
class Sprite:
    source: Path
    name: str
    width: int
    height: int
    kind: str
    scale: int
    rows: list[str]

    def pixels(self, palette: Palette) -> list[list[RGBA]]:
        grid = [[palette.colours[key] for key in row] for row in self.rows]
        return scale_grid(grid, self.scale)


@dataclass
class Derivation:
    """A derived source: another source's pixels through a GOLDEN map (no grid of its own)."""
    source: Path
    name: str
    base: str
    golden: str

    def base_name(self) -> str:
        """The base source's name, relative to the derived source's folder."""
        folder = self.name.rpartition("/")[0]
        return f"{folder}/{self.base}" if folder else self.base


def parse_palette(path: Path) -> Palette:
    keys: list[str] = []
    colours: dict[str, RGBA] = {}
    try:
        lines = path.read_text(encoding="utf-8").splitlines()
    except OSError as error:
        raise ArtError(f"{path}: can't read the palette ({error})") from error
    for number, line in enumerate(lines, 1):
        stripped = line.strip()
        if not stripped or stripped.startswith(";"):
            continue
        parts = stripped.split(maxsplit=2)
        key = parts[0]
        if len(key) != 1:
            raise ArtError(f"{path}:{number}: a key is one character, got {key!r}")
        if key in RESERVED_KEYS:
            raise ArtError(f"{path}:{number}: {key!r} starts a directive or a comment in a "
                           "source, so it can't be a key")
        if key in colours:
            raise ArtError(f"{path}:{number}: key {key!r} is listed twice")
        if key == TRANSPARENT:
            colours[key] = (0, 0, 0, 0)
        else:
            if len(parts) < 2:
                raise ArtError(f"{path}:{number}: key {key!r} has no colour")
            colours[key] = parse_hex(parts[1], f"{path}:{number}")
        keys.append(key)
    if TRANSPARENT not in colours:
        raise ArtError(f"{path}: the palette has no transparent key {TRANSPARENT!r}")
    if INK not in colours:
        raise ArtError(f"{path}: the palette has no ink key {INK!r}")
    if len(keys) > 256:
        raise ArtError(f"{path}: an indexed PNG holds at most 256 colours, got {len(keys)}")
    # The transparent key is always index 0, so tRNS needs a single entry.
    keys.remove(TRANSPARENT)
    keys.insert(0, TRANSPARENT)
    return Palette(keys, colours)


def parse_hex(text: str, where: str) -> RGBA:
    value = text.removeprefix("#")
    if len(value) != 6 or any(c not in "0123456789abcdefABCDEF" for c in value):
        raise ArtError(f"{where}: {text!r} is not a #rrggbb colour")
    return (int(value[0:2], 16), int(value[2:4], 16), int(value[4:6], 16), 255)


def parse_sprite(path: Path, src_root: Path) -> tuple[Sprite | None, list[str]]:
    """Reads a drawn source. Returns the sprite (None if it can't be built) and its format errors;
    a derived source is reported as an error here (load_project resolves those)."""
    parsed, errors = parse_source(path, src_root)
    if isinstance(parsed, Derivation):
        return None, [f"{parsed.name}: a derived source has no grid of its own"]
    return parsed, errors


def parse_source(path: Path, src_root: Path) -> tuple[Sprite | Derivation | None, list[str]]:
    """Reads a source: a drawn sprite, or a derivation (@derive). None if it can't be used."""
    errors: list[str] = []
    name = path.relative_to(src_root).with_suffix("").as_posix()
    try:
        lines = path.read_text(encoding="utf-8").splitlines()
    except OSError as error:
        return None, [f"{name}: can't read the source ({error})"]
    size: tuple[int, int] | None = None
    kind = ""
    scale = 1
    rows: list[str] = []
    derive: tuple[str, str] | None = None
    derived = False
    other_directives = False
    for number, line in enumerate(lines, 1):
        stripped = line.strip()
        if not stripped or stripped.startswith(";"):
            continue
        if stripped.startswith("@"):
            if rows:
                errors.append(f"{name}:{number}: directives come before the grid")
                continue
            parts = stripped.split()
            directive, args = parts[0], parts[1:]
            if directive != DERIVE_DIRECTIVE:
                other_directives = True
            if directive == DERIVE_DIRECTIVE:
                if derived:
                    errors.append(f"{name}:{number}: {DERIVE_DIRECTIVE} is given twice")
                elif (len(args) == 2 and args[1].startswith(GOLDEN_PREFIX)
                        and args[1].removeprefix(GOLDEN_PREFIX) in GOLDEN_MAPS):
                    derive = (args[0], args[1].removeprefix(GOLDEN_PREFIX))
                else:
                    errors.append(f"{name}:{number}: {DERIVE_DIRECTIVE} takes <source> "
                                  f"golden=<map> (maps: {', '.join(sorted(GOLDEN_MAPS))}), "
                                  f"got {stripped!r}")
                derived = True
            elif directive == "@size" and len(args) == 1:
                size = parse_size(args[0])
                if size is None:
                    errors.append(f"{name}:{number}: @size takes WxH, got {args[0]!r}")
            elif directive == "@kind" and len(args) == 1:
                kind = args[0]
                if kind not in KINDS:
                    errors.append(f"{name}:{number}: unknown @kind {kind!r}")
            elif directive == "@scale" and len(args) == 1:
                if args[0].isdigit() and 1 <= int(args[0]) <= 16:
                    scale = int(args[0])
                else:
                    errors.append(f"{name}:{number}: @scale takes 1 to 16, got {args[0]!r}")
            else:
                errors.append(f"{name}:{number}: unknown directive {stripped!r}")
            continue
        rows.append(stripped)
    if derived:
        if rows:
            errors.append(f"{name}: a derived source holds no grid")
        if other_directives:
            errors.append(f"{name}: a derived source takes no other directive (its size, kind "
                          "and scale are its source's)")
        if errors or derive is None:
            return None, errors
        return Derivation(path, name, derive[0], derive[1]), []
    if size is None:
        errors.append(f"{name}: missing @size")
    if not kind:
        errors.append(f"{name}: missing @kind")
    if errors or size is None:
        return None, errors
    width, height = size
    if len(rows) != height:
        errors.append(f"{name}: @size says {height} rows, the grid has {len(rows)}")
    for index, row in enumerate(rows, 1):
        if len(row) != width:
            errors.append(f"{name}: grid row {index} is {len(row)} wide, @size says {width}")
    if errors:
        return None, errors
    return Sprite(path, name, width, height, kind, scale, rows), []


def parse_size(text: str) -> tuple[int, int] | None:
    parts = text.lower().split("x")
    if len(parts) != 2 or not all(part.isdigit() and int(part) > 0 for part in parts):
        return None
    return int(parts[0]), int(parts[1])


def lint_sprite(sprite: Sprite, palette: Palette) -> list[str]:
    errors: list[str] = []
    unknown = sorted({key for row in sprite.rows for key in row} - set(palette.colours))
    if unknown:
        errors.append(f"{sprite.name}: keys not in the palette: {' '.join(unknown)}")
        return errors
    if sprite.kind != "item":
        return errors
    folder = sprite.name.split("/")[0]
    expected = ITEM_SIZE_BY_FOLDER.get(folder, ITEM_SIZE)
    if (sprite.width, sprite.height) != expected:
        errors.append(f"{sprite.name}: an item is {expected[0]}x{expected[1]}, "
                      f"got {sprite.width}x{sprite.height}")
    if sprite.scale != 1:
        errors.append(f"{sprite.name}: an item is drawn at @scale 1, got {sprite.scale}")
    for y, row in enumerate(sprite.rows[:ITEM_EMPTY_TOP_ROWS]):
        if row.strip(TRANSPARENT):
            errors.append(f"{sprite.name}: row {y} must be transparent (the card crops the top "
                          f"{ITEM_EMPTY_TOP_ROWS} rows)")
    used = {key for row in sprite.rows for key in row} - {TRANSPARENT}
    if len(used) > MAX_ITEM_COLOURS:
        errors.append(f"{sprite.name}: an item uses at most {MAX_ITEM_COLOURS} colours, "
                      f"got {len(used)}")
    for y, row in enumerate(sprite.rows):
        for x, key in enumerate(row):
            if key in (TRANSPARENT, INK):
                continue
            if touches_outside(sprite.rows, x, y):
                errors.append(f"{sprite.name}: pixel ({x}, {y}) {key!r} is on the outline, "
                              f"which must be ink {INK!r}")
                if len(errors) >= 10:
                    errors.append(f"{sprite.name}: (more outline errors not listed)")
                    return errors
    return errors


def touches_outside(rows: list[str], x: int, y: int) -> bool:
    for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
        nx, ny = x + dx, y + dy
        if ny < 0 or ny >= len(rows) or nx < 0 or nx >= len(rows[ny]):
            return True
        if rows[ny][nx] == TRANSPARENT:
            return True
    return False


# --- GOLDEN maps (@derive) -------------------------------------------------------------------


def reink(grid: Grid) -> Grid:
    """Rows 0-1 cleared; every opaque pixel on the outline (4-neighbours) becomes ink."""
    height = len(grid)
    width = len(grid[0]) if grid else 0
    for y in range(min(ITEM_EMPTY_TOP_ROWS, height)):
        grid[y] = [TRANSPARENT] * width
    out = [row[:] for row in grid]
    for y in range(height):
        for x in range(width):
            if grid[y][x] in (TRANSPARENT, INK):
                continue
            for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                nx, ny = x + dx, y + dy
                if not (0 <= nx < width and 0 <= ny < height) or grid[ny][nx] == TRANSPARENT:
                    out[y][x] = INK
                    break
    return out


def _luma(palette: Palette, key: str) -> float:
    r, g, b, _ = palette.colours[key]
    return (0.299 * r + 0.587 * g + 0.114 * b) / 255


def golden_rank(rows: Grid, palette: Palette) -> Grid:
    """The source's colours, dark to light, spread over GOLDEN_RANK_STEPS; ink kept; a 1 px paper
    glint on every GOLDEN_RANK_GLINT_PERIOD-th diagonal of the lit gold."""
    used = sorted({key for row in rows for key in row} - {TRANSPARENT, INK},
                  key=lambda key: (_luma(palette, key), key))
    steps = len(GOLDEN_RANK_STEPS)
    mapping = {key: GOLDEN_RANK_STEPS[min(steps - 1, i * steps // len(used))]
               for i, key in enumerate(used)}
    out = [[mapping.get(key, key) for key in row] for row in rows]
    for y, row in enumerate(out):
        for x, key in enumerate(row):
            if key in GOLDEN_RANK_GLINT_KEYS and (x + y) % GOLDEN_RANK_GLINT_PERIOD == 0:
                row[x] = GOLDEN_PAPER
    return reink(out)


def golden_yellow(rows: Grid, _palette: Palette) -> Grid:
    """GOLDEN_YELLOW_MAP, plus a paper rim where the lightest yellow sits right under the
    outline."""
    out = [[GOLDEN_YELLOW_MAP.get(key, key) for key in row] for row in rows]
    for y in range(1, len(rows)):
        for x, key in enumerate(rows[y]):
            if key == GOLDEN_YELLOW_RIM_FROM and rows[y - 1][x] == INK:
                out[y][x] = GOLDEN_PAPER
    return reink(out)


def golden_egg(rows: Grid, _palette: Palette) -> Grid:
    """GOLDEN_EGG_MAP; a brass dark rim where an egg meets anything but egg (left, up, right);
    one highlight per egg: the top-left inner pixel of its light patch, and the next one right."""
    height = len(rows)
    width = len(rows[0]) if rows else 0
    egg = GOLDEN_EGG_KEYS
    out = [[GOLDEN_EGG_MAP.get(key, key) for key in row] for row in rows]
    for y in range(1, height - 1):
        for x in range(1, width - 1):
            if rows[y][x] in egg and any(rows[y + dy][x + dx] not in egg + (GOLDEN_EGG_SHADE,)
                                         for dx, dy in ((-1, 0), (0, -1), (1, 0))):
                out[y][x] = GOLDEN_EGG_RIM
    light = egg[0]

    def inside_egg(x: int, y: int) -> bool:
        return 0 <= x < width and 0 <= y < height and rows[y][x] in egg

    seen: set[tuple[int, int]] = set()
    for y in range(height):
        for x in range(width):
            if rows[y][x] != light or (x, y) in seen:
                continue
            patch: list[tuple[int, int]] = []
            todo = [(x, y)]
            seen.add((x, y))
            while todo:
                cx, cy = todo.pop()
                patch.append((cx, cy))
                for nx, ny in ((cx + 1, cy), (cx - 1, cy), (cx, cy + 1), (cx, cy - 1)):
                    if (0 <= nx < width and 0 <= ny < height and rows[ny][nx] == light
                            and (nx, ny) not in seen):
                        seen.add((nx, ny))
                        todo.append((nx, ny))
            inner = [(cx, cy) for cx, cy in patch
                     if all(inside_egg(cx + dx, cy + dy)
                            for dx, dy in ((-1, 0), (0, -1), (1, 0), (0, 1)))]
            if not inner:
                continue
            hx, hy = min(inner, key=lambda p: (p[0] + p[1], p[1]))
            out[hy][hx] = GOLDEN_PAPER
            if (hx + 1, hy) in inner:
                out[hy][hx + 1] = GOLDEN_PAPER
    return reink(out)


GOLDEN_MAPS = {"rank": golden_rank, "yellow": golden_yellow, "egg": golden_egg}


def derive_sprite(derivation: Derivation, base: Sprite, palette: Palette) -> Sprite:
    rows = GOLDEN_MAPS[derivation.golden]([list(row) for row in base.rows], palette)
    return Sprite(derivation.source, derivation.name, base.width, base.height, base.kind,
                  base.scale, ["".join(row) for row in rows])


def scale_grid(grid: list[list[RGBA]], factor: int) -> list[list[RGBA]]:
    if factor == 1:
        return [list(row) for row in grid]
    result: list[list[RGBA]] = []
    for row in grid:
        wide = [pixel for pixel in row for _ in range(factor)]
        result.extend(list(wide) for _ in range(factor))
    return result


# --- PNG encoding and decoding ---------------------------------------------------------------


def _chunk(kind: bytes, data: bytes) -> bytes:
    return (struct.pack(">I", len(data)) + kind + data
            + struct.pack(">I", zlib.crc32(kind + data) & 0xFFFFFFFF))


def encode_indexed(sprite: Sprite, palette: Palette) -> bytes:
    """An 8-bit indexed PNG holding the whole palette (index 0 transparent)."""
    lookup = {key: palette.index(key) for key in palette.keys}
    width, height = sprite.width * sprite.scale, sprite.height * sprite.scale
    raw = bytearray()
    for row in sprite.rows:
        line = bytes(lookup[key] for key in row for _ in range(sprite.scale))
        for _ in range(sprite.scale):
            raw.append(0)
            raw.extend(line)
    plte = b"".join(bytes(palette.colours[key][:3]) for key in palette.keys)
    return (PNG_SIGNATURE
            + _chunk(b"IHDR", struct.pack(">IIBBBBB", width, height, 8, 3, 0, 0, 0))
            + _chunk(b"PLTE", plte)
            + _chunk(b"tRNS", b"\x00")
            + _chunk(b"IDAT", zlib.compress(bytes(raw), 9))
            + _chunk(b"IEND", b""))


def encode_rgba(grid: list[list[RGBA]]) -> bytes:
    height = len(grid)
    width = len(grid[0]) if grid else 0
    raw = bytearray()
    for row in grid:
        raw.append(0)
        for pixel in row:
            raw.extend(pixel)
    return (PNG_SIGNATURE
            + _chunk(b"IHDR", struct.pack(">IIBBBBB", width, height, 8, 6, 0, 0, 0))
            + _chunk(b"IDAT", zlib.compress(bytes(raw), 9))
            + _chunk(b"IEND", b""))


def decode_png(data: bytes) -> list[list[RGBA]]:
    """Decodes an 8-bit, non-interlaced PNG (indexed, greyscale, RGB or RGBA) to RGBA rows."""
    if not data.startswith(PNG_SIGNATURE):
        raise ArtError("not a PNG")
    position = len(PNG_SIGNATURE)
    header = b""
    plte = b""
    trns = b""
    idat = bytearray()
    while position + 8 <= len(data):
        length, kind = struct.unpack(">I4s", data[position:position + 8])
        body = data[position + 8:position + 8 + length]
        stored = data[position + 8 + length:position + 12 + length]
        if len(body) != length or len(stored) != 4:
            raise ArtError(f"truncated {kind!r} chunk")
        if struct.unpack(">I", stored)[0] != zlib.crc32(kind + body) & 0xFFFFFFFF:
            raise ArtError(f"bad CRC in the {kind!r} chunk")
        position += 12 + length
        if kind == b"IHDR":
            header = body
        elif kind == b"PLTE":
            plte = body
        elif kind == b"tRNS":
            trns = body
        elif kind == b"IDAT":
            idat.extend(body)
        elif kind == b"IEND":
            break
    if len(header) != 13:
        raise ArtError("PNG without a header")
    width, height, depth, colour_type, _, _, interlace = struct.unpack(">IIBBBBB", header)
    channels = {0: 1, 2: 3, 3: 1, 4: 2, 6: 4}.get(colour_type)
    if depth != 8 or interlace != 0 or channels is None:
        raise ArtError(f"unsupported PNG (depth {depth}, type {colour_type}, "
                       f"interlace {interlace})")
    raw = zlib.decompress(bytes(idat))
    stride = width * channels
    if len(raw) < height * (1 + stride):
        raise ArtError("PNG image data is shorter than its size")
    rows: list[bytearray] = []
    previous = bytearray(stride)
    offset = 0
    for _ in range(height):
        filter_type = raw[offset]
        line = bytearray(raw[offset + 1:offset + 1 + stride])
        offset += 1 + stride
        _unfilter(filter_type, line, previous, channels)
        rows.append(line)
        previous = line
    result: list[list[RGBA]] = []
    for line in rows:
        out: list[RGBA] = []
        for x in range(width):
            px = line[x * channels:(x + 1) * channels]
            if colour_type == 3:
                index = px[0]
                r, g, b = plte[index * 3:index * 3 + 3]
                a = trns[index] if index < len(trns) else 255
                out.append((r, g, b, a) if a else (0, 0, 0, 0))
            elif colour_type == 0:
                out.append((px[0], px[0], px[0], 255))
            elif colour_type == 4:
                out.append((px[0], px[0], px[0], px[1]) if px[1] else (0, 0, 0, 0))
            elif colour_type == 2:
                out.append((px[0], px[1], px[2], 255))
            else:
                out.append((px[0], px[1], px[2], px[3]) if px[3] else (0, 0, 0, 0))
        result.append(out)
    return result


def _unfilter(filter_type: int, line: bytearray, previous: bytearray, bpp: int) -> None:
    for i in range(len(line)):
        left = line[i - bpp] if i >= bpp else 0
        up = previous[i]
        up_left = previous[i - bpp] if i >= bpp else 0
        if filter_type == 1:
            line[i] = (line[i] + left) & 0xFF
        elif filter_type == 2:
            line[i] = (line[i] + up) & 0xFF
        elif filter_type == 3:
            line[i] = (line[i] + (left + up) // 2) & 0xFF
        elif filter_type == 4:
            line[i] = (line[i] + _paeth(left, up, up_left)) & 0xFF
        elif filter_type != 0:
            raise ArtError(f"unknown PNG filter {filter_type}")


def _paeth(a: int, b: int, c: int) -> int:
    p = a + b - c
    pa, pb, pc = abs(p - a), abs(p - b), abs(p - c)
    if pa <= pb and pa <= pc:
        return a
    return b if pb <= pc else c


def normalised(grid: list[list[RGBA]]) -> list[list[RGBA]]:
    """Every fully transparent pixel compares equal, whatever its colour."""
    return [[pixel if pixel[3] else (0, 0, 0, 0) for pixel in row] for row in grid]


# --- Project ---------------------------------------------------------------------------------


@dataclass
class Project:
    src: Path
    out: Path
    palette: Palette
    sprites: list[Sprite]
    errors: list[str]
    # Every source's name, including those with errors.
    source_names: set[str]

    def output_path(self, sprite: Sprite) -> Path:
        return self.out / f"{sprite.name}.png"


def load_project(src: Path, out: Path) -> Project:
    palette = parse_palette(src / PALETTE_FILE)
    sprites: list[Sprite] = []
    errors: list[str] = []
    names: set[str] = set()
    derivations: list[Derivation] = []
    drawn: dict[str, Sprite] = {}
    for path in sorted(src.rglob("*.txt")):
        if path.name == PALETTE_FILE and path.parent == src:
            continue
        names.add(path.relative_to(src).with_suffix("").as_posix())
        parsed, format_errors = parse_source(path, src)
        errors.extend(format_errors)
        if isinstance(parsed, Derivation):
            derivations.append(parsed)
            continue
        if parsed is None:
            continue
        drawn[parsed.name] = parsed
        _add_linted(parsed, palette, sprites, errors)
    derived_names = {d.name for d in derivations}
    for derivation in derivations:
        base_name = derivation.base_name()
        base = drawn.get(base_name)
        if base is None:
            if base_name in derived_names:
                why = "is itself derived; derive from a drawn source"
            elif base_name in names:
                why = "has errors"
            else:
                why = "doesn't exist"
            errors.append(f"{derivation.name}: can't derive from {base_name}: that source {why}")
            continue
        _add_linted(derive_sprite(derivation, base, palette), palette, sprites, errors)
    return Project(src, out, palette, sprites, errors, names)


def _add_linted(sprite: Sprite, palette: Palette, sprites: list[Sprite], errors: list[str]) -> None:
    lint = lint_sprite(sprite, palette)
    errors.extend(lint)
    if not any(e.startswith(f"{sprite.name}: keys not in the palette") for e in lint):
        sprites.append(sprite)


def output_pngs(project: Project) -> list[Path]:
    """Every PNG under the output folder, leaving out the sources' folder."""
    src = project.src.resolve()
    return sorted(png for png in project.out.rglob("*.png")
                  if src != png.resolve().parent and src not in png.resolve().parents)


def same_image(target: Path, data: bytes) -> bool:
    """Whether the PNG at target holds the same pixels and palette as data."""
    if not target.exists():
        return False
    existing = target.read_bytes()
    if existing == data:
        return True
    try:
        return (normalised(decode_png(existing)) == normalised(decode_png(data))
                and _chunk_body(existing, b"PLTE") == _chunk_body(data, b"PLTE"))
    except (ArtError, zlib.error, struct.error, ValueError, IndexError):
        return False


def _chunk_body(data: bytes, kind: bytes) -> bytes:
    position = len(PNG_SIGNATURE)
    while position + 8 <= len(data):
        length, found = struct.unpack(">I4s", data[position:position + 8])
        if found == kind:
            return data[position + 8:position + 8 + length]
        position += 12 + length
    return b""


def build(project: Project) -> list[Path]:
    written: list[Path] = []
    for sprite in project.sprites:
        target = project.output_path(sprite)
        data = encode_indexed(sprite, project.palette)
        if same_image(target, data):
            continue
        target.parent.mkdir(parents=True, exist_ok=True)
        target.write_bytes(data)
        written.append(target)
    return written


def check(project: Project) -> list[str]:
    problems = list(project.errors)
    expected: set[Path] = set()
    for sprite in project.sprites:
        target = project.output_path(sprite)
        expected.add(target.resolve())
        if not target.exists():
            problems.append(f"{sprite.name}: {_rel(target)} is missing; run build")
            continue
        try:
            decode_png(target.read_bytes())
        except (ArtError, zlib.error, struct.error, ValueError, IndexError) as error:
            problems.append(f"{sprite.name}: {_rel(target)} can't be decoded ({error})")
            continue
        if not same_image(target, encode_indexed(sprite, project.palette)):
            problems.append(f"{sprite.name}: {_rel(target)} is stale; run build")
    for png in output_pngs(project):
        if png.resolve() in expected:
            continue
        name = png.relative_to(project.out).with_suffix("").as_posix()
        if name in project.source_names:
            problems.append(f"{_rel(png)} not checked: its source has errors")
        else:
            problems.append(f"{_rel(png)} has no source in {_rel(project.src)}")
    return problems


def _rel(path: Path) -> str:
    try:
        return path.resolve().relative_to(REPO).as_posix()
    except ValueError:
        return path.as_posix()


# --- Review sheets ---------------------------------------------------------------------------


def blank(width: int, height: int, colour: RGBA) -> list[list[RGBA]]:
    return [[colour] * width for _ in range(height)]


def paste(target: list[list[RGBA]], grid: list[list[RGBA]], x: int, y: int) -> None:
    for dy, row in enumerate(grid):
        for dx, pixel in enumerate(row):
            if pixel[3]:
                target[y + dy][x + dx] = pixel


def greyscale(grid: list[list[RGBA]]) -> list[list[RGBA]]:
    result: list[list[RGBA]] = []
    for row in grid:
        out: list[RGBA] = []
        for r, g, b, a in row:
            luma = round(0.299 * r + 0.587 * g + 0.114 * b)
            out.append((luma, luma, luma, a))
        result.append(out)
    return result


def silhouette(grid: list[list[RGBA]], colour: RGBA) -> list[list[RGBA]]:
    return [[colour if pixel[3] else pixel for pixel in row] for row in grid]


def preview(sprite: Sprite, palette: Palette) -> list[list[RGBA]]:
    """8x on both backgrounds; 1x, 2x, 4x on both; greyscale and silhouette at 4x."""
    base = [[palette.colours[key] for key in row] for row in sprite.rows]
    backgrounds = [palette.colours[key] for key in PREVIEW_BACKGROUND_KEYS
                   if key in palette.colours] or [(255, 255, 255, 255)]
    ink = palette.colours[INK]
    gap = PREVIEW_GAP
    w, h = sprite.width, sprite.height
    big = [scale_grid(base, 8)] * len(backgrounds)
    small_row = [scale_grid(base, f) for f in (1, 2, 4)]
    checks = [scale_grid(greyscale(base), 4), scale_grid(silhouette(base, ink), 4)]
    panel_w = w + 2 * w + 4 * w + 3 * gap
    width = max(gap + len(backgrounds) * (w * 8 + gap),
                gap + len(backgrounds) * (panel_w + gap),
                gap + 2 * (w * 4 + gap))
    height = gap + h * 8 + gap + h * 4 + gap + h * 4 + gap
    sheet = blank(width, height, backgrounds[0])
    x = gap
    for grid, colour in zip(big, backgrounds):
        paste(sheet, blank(w * 8 + gap, h * 8 + gap, colour), x - gap // 2, gap // 2)
        paste(sheet, grid, x, gap)
        x += w * 8 + gap
    y = gap + h * 8 + gap
    x = gap
    for colour in backgrounds:
        paste(sheet, blank(panel_w, h * 4 + gap, colour), x - gap // 2, y - gap // 2)
        cx = x
        for grid in small_row:
            paste(sheet, grid, cx, y + h * 4 - len(grid))
            cx += len(grid[0]) + gap
        x += panel_w + gap
    y += h * 4 + gap
    x = gap
    for grid in checks:
        paste(sheet, grid, x, y)
        x += w * 4 + gap
    return sheet


def contact_sheet(sprites: list[Sprite], palette: Palette) -> list[list[RGBA]]:
    """Each sprite on one line: 1x and 2x on cream, then 1x and 2x on teal."""
    if not sprites:
        return blank(1, 1, (0, 0, 0, 0))
    backgrounds = [palette.colours[key] for key in PREVIEW_BACKGROUND_KEYS
                   if key in palette.colours] or [(255, 255, 255, 255)]
    gap = PREVIEW_GAP
    cell_w = max(s.width * s.scale for s in sprites)
    cell_h = max(s.height * s.scale for s in sprites)
    panel_w = gap + cell_w + gap + 2 * cell_w + gap
    width = len(backgrounds) * panel_w
    height = gap + len(sprites) * (2 * cell_h + gap)
    sheet = blank(width, height, backgrounds[0])
    for index, colour in enumerate(backgrounds):
        paste(sheet, blank(panel_w, height, colour), index * panel_w, 0)
    y = gap
    for sprite in sprites:
        grid = sprite.pixels(palette)
        for index in range(len(backgrounds)):
            x = index * panel_w + gap
            paste(sheet, grid, x, y + 2 * cell_h - len(grid))
            double = scale_grid(grid, 2)
            paste(sheet, double, x + cell_w + gap, y + 2 * cell_h - len(double))
        y += 2 * cell_h + gap
    return sheet


def write_sheets(project: Project, reports: Path) -> list[Path]:
    written: list[Path] = []
    # The tools keep reports/ out of Godot's import.
    repo_reports = REPO / "reports"
    if reports.resolve() == repo_reports or repo_reports in reports.resolve().parents:
        repo_reports.mkdir(parents=True, exist_ok=True)
        (repo_reports / ".gdignore").touch()
    preview_dir = reports / "preview"
    preview_dir.mkdir(parents=True, exist_ok=True)
    for sprite in project.sprites:
        target = preview_dir / f"{sprite.name.replace('/', '__')}.png"
        target.write_bytes(encode_rgba(preview(sprite, project.palette)))
        written.append(target)
    sheet = reports / "contact_sheet.png"
    sheet.write_bytes(encode_rgba(contact_sheet(project.sprites, project.palette)))
    legend = reports / "contact_sheet.txt"
    legend.write_text("".join(f"{s.name}\n" for s in project.sprites), encoding="utf-8")
    written.extend([sheet, legend])
    return written


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description="Build the pixel art from art/src/.")
    parser.add_argument("command", choices=["build", "check", "sheet"])
    parser.add_argument("--src", type=Path, default=DEFAULT_SRC)
    parser.add_argument("--out", type=Path, default=DEFAULT_OUT)
    parser.add_argument("--reports", type=Path, default=DEFAULT_REPORTS)
    args = parser.parse_args(argv)
    try:
        project = load_project(args.src, args.out)
    except ArtError as error:
        print(f"error: {error}", file=sys.stderr)
        return 2
    if args.command == "check":
        problems = check(project)
        for problem in problems:
            print(f"error: {problem}", file=sys.stderr)
        print(f"{len(project.sprites)} sprites checked, {len(problems)} problems")
        return 1 if problems else 0
    for error in project.errors:
        print(f"error: {error}", file=sys.stderr)
    if args.command == "build":
        written = build(project)
        for path in written:
            print(f"wrote {_rel(path)}")
        print(f"{len(project.sprites)} sprites, {len(written)} written")
    else:
        written = write_sheets(project, args.reports)
        print(f"wrote {len(written)} files to {_rel(args.reports)}")
    return 1 if project.errors else 0


if __name__ == "__main__":
    sys.exit(main())
