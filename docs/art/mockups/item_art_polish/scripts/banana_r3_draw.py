"""Banana round 3: three alternative tops (V1 short thick stem, V2 curved stalk, V3 tips only).

Starts from the committed art/src/items_v2/banana.txt and banana_big.txt (160c5837), clears the
long stalk and the crown, and pastes a new top. The fingers' bodies below the crown are kept
pixel for pixel. Writes docs/art/mockups/item_art_polish/banana_r3/banana_v{1,2,3}{,_big,_golden}.txt
(art/src is never touched). Then render with banana_r3.py.

    python docs/art/mockups/item_art_polish/scripts/banana_r3_draw.py
"""
from pathlib import Path

R = Path(__file__).resolve().parents[5]
SRC = R / "art/src/items_v2"
OUT = Path(__file__).resolve().parents[1] / "banana_r3"

# Patches: {row: text starting at column 24}; '_' keeps the pixel underneath, '.' clears it.
# Rows 0..CLEAR_TO-1 right of CLEAR_X are cleared first (the old stalk and crown). "shift": BIG's
# crown sits one row higher than the plain one, so BIG takes the plain patch one row up.
PLAIN_CLEAR = (18, 30)
BIG_CLEAR = (13, 33)

V = {}

# ---- V1: short thick stem on a stubby crown, dark cut tip
V["v1"] = {
    "plain": {
        11: "___________####_________",
        12: "__________#feee#________",
        13: "__________#zGGg#________",
        14: "_________#zGGgg#________",
        15: "________#FzGGgf#________",
        16: "_______#FFfGgfe#________",
        17: "_______#ffffee#_________",
    },
    "big": "shift",
}

# ---- V2: compact crown, a shorter stalk curving up and back, thick base, tapered tip
V["v2"] = {
    "plain": {
        8:  "___________##___________",
        9:  "__________#fe#__________",
        10: "___________#Gg#_________",
        11: "___________#zGg#________",
        12: "___________#zGg#________",
        13: "__________#zGGg#________",
        14: "_________#zGGgg#________",
        15: "________#FzGGgf#________",
        16: "_______#FFfGgfe#________",
        17: "_______#ffffee#_________",
    },
    "big": "shift",
}

# ---- V3: no stalk, each finger's neck ends in its own dark brown tip at a small crown
V["v3"] = {
    "plain": {
        13: "____________##__________",
        14: "_________###fe#_________",
        15: "______###fe#fe#_________",
        16: "_____#fe#fe#Gg#_________",
        17: "_____#fe#Gg#Gg#_________",
        18: "__####Gg#GgGg#__________",
        19: "_________Gg_____________",
    },
    "big": {
        11: "___________##___________",
        12: "_____##...#fe#__________",
        13: "_____fe####fe#__________",
        14: "___GGfe#fe#Gg#__________",
        15: "_____Gg#fe#Gg#._________",
        16: "_______GGguGg#.________",
        17: "______GGguGGg#._________",
        18: "_________Gg_____________",
    },
}


def grid(name):
    lines = (SRC / f"{name}.txt").read_text(encoding="utf-8").splitlines()
    return [list(line) for line in lines if line and line[0] not in ";@"]


def apply(rows, clear, patch):
    to, cx = clear
    for y in range(to):
        for x in range(cx, 48):
            rows[y][x] = "."
    for y, text in patch.items():
        for i, c in enumerate(text):
            if c != "_":
                rows[y][24 + i] = c
    return rows


NOTES = {
    "v1": "V1 short thick stem: the necks meet in one stubby crown under a short, 4 px thick green stem with a dark cut tip.",
    "v2": "V2 curved stalk: a compact crown, the stalk shorter, thick at the base and tapering as it curves up and back.",
    "v3": "V3 tips only: no stalk; each finger's neck ends in its own dark brown tip where they meet at a small crown.",
}


def write(name, rows, note):
    body = "\n".join("".join(r) for r in rows)
    text = (f"; Banana {note}\n; Banana round 3 mock-up (scripts/banana_r3_draw.py), from art/src/items_v2 at 160c5837;"
            f" the fingers' bodies are unchanged.\n@size 48x48\n@kind item\n{body}\n")
    (OUT / f"{name}.txt").write_text(text, encoding="utf-8")


def main():
    OUT.mkdir(exist_ok=True)
    for v, p in V.items():
        write(f"banana_{v}", apply(grid("banana"), PLAIN_CLEAR, p["plain"]), NOTES[v])
        big = p["big"] if p["big"] != "shift" else {y - 1: t for y, t in p["plain"].items()}
        write(f"banana_{v}_big", apply(grid("banana_big"), BIG_CLEAR, big), "BIG " + NOTES[v])
        (OUT / f"banana_{v}_golden.txt").write_text(
            f"; Banana GOLDEN {NOTES[v]} Derived from BIG like art/src/items_v2/banana_golden.txt.\n"
            f"@derive banana_{v}_big golden=yellow\n", encoding="utf-8")
    print("ok")


if __name__ == "__main__":
    main()
