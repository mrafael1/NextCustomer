"""Builds ../count_rhythm_v<n>.html from its template (template.html for v1, template_v<n>.html after), inlining every {{img:...}} and {{font:...}}
(paths from the repo root) as data URIs, so the page is one self-contained file."""
import base64
import pathlib
import re

HERE = pathlib.Path(__file__).resolve().parent
ROOT = HERE.parents[3]
TYPES = {"png": "image/png", "ttf": "font/ttf"}


def inline(match: re.Match) -> str:
    path = ROOT / match.group(2)
    data = base64.b64encode(path.read_bytes()).decode()
    return f"data:{TYPES[path.suffix[1:]]};base64,{data}"


for source, target in [("template.html", "count_rhythm_v1.html"), ("template_v2.html", "count_rhythm_v2.html"), ("template_v3.html", "count_rhythm_v3.html")]:
    page = re.sub(r"\{\{(img|font):([^}]+)\}\}", inline, (HERE / source).read_text())
    (HERE.parent / target).write_text(page)
    print(f"{target}: {len(page) // 1024} KiB")
