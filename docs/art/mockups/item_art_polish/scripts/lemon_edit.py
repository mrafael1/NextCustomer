import pathlib
SRC = pathlib.Path(r"C:/dev/projects/NC-item-art/art/src/items_v2")
def grid(n):
    return [l.rstrip("\n") for l in open(SRC / f"{n}.txt") if not l.startswith((";", "@"))][:48]
PLAIN = {
 19: "......................#########.................",
 20: "..................####yyyyyyyyy###..........###.",
 21: "................##YYYYyyyyyyyyyMMM##.......#zGG#",
 22: "..............##YYYYYYyyyyyyMyyMMMMM##....#zGGg#",
 23: ".............#YYYYYYYYyyyyyyyyyMMMMMMm#..#GGgg#.",
 24: "............#YYYYYYYYyyyyyyyMyMMMMMMmm#..#Ggg#..",
 25: "..........##YYYYYYYYyyyyyyyyyyMMMMMMmmm##fg##...",
 26: "..........#YYYYYYYYyyyyyyyyyyMMMMMMMmmmmmme##...",
}
def apply(rows, patch):
    rows = list(rows)
    for y, r in patch.items():
        assert len(r) == 48, (y, len(r)); rows[y] = r
    return rows
if __name__ == "__main__":
    out = pathlib.Path(__file__).parent / "out"
    (out / "lemon.grid").write_text("\n".join(apply(grid("lemon"), PLAIN)))

def row(base, sets):
    r = list(base.ljust(48, "."))
    for x, c in sets.items(): r[x] = c
    return "".join(r)

BIG_BASE = {
  9: "",
 10: "............................#######",
 11: "........................####yyyyyyy###",
 12: "......................##YYYYMyyyyyyMM##",
 13: ".....................#YYYYYYyyyyMyyMMMM##",
 14: "...................##YYYYYYMyyyyyyyMMMMmm#",
 15: "..................#YYYYYYYyyyyyyyyMMMmMMmmm#",
}
BIG_LEAF = {
 10: {44: "#", 45: "#"},
 11: {43: "#", 44: "z", 45: "G", 46: "#"},
 12: {42: "#", 43: "z", 44: "G", 45: "g", 46: "#"},
 13: {42: "#", 43: "G", 44: "G", 45: "g", 46: "#"},
 14: {42: "#", 43: "G", 44: "g", 45: "#"},
 15: {43: "f", 44: "g", 45: "#"},
}
def big_patch(rows):
    p = {y: row(BIG_BASE[y], BIG_LEAF.get(y, {})) for y in BIG_BASE}
    r16 = list(rows[16]); r16[44] = "e"; p[16] = "".join(r16)
    return p

if __name__ == "__main__":
    g = grid("lemon_big")
    (out / "lemon_big.grid").write_text("\n".join(apply(g, big_patch(g))))
