"""Builds docs/art/mockups/receipt_machine_da.html from template.html and machine.js.

Every __ASSET:<repo path>__ becomes a data: URI, so the page is one self-contained file that opens
from the repo or anywhere else. Standard library only. Run from anywhere:
    python docs/art/mockups/receipt_machine_da_src/build.py
"""

from __future__ import annotations

import base64
import mimetypes
import re
from pathlib import Path

SRC = Path(__file__).resolve().parent
ROOT = SRC.parents[3]
OUT = SRC.parent / "receipt_machine_da.html"


def data_uri(rel: str) -> str:
    path = ROOT / rel
    mime = mimetypes.guess_type(path.name)[0] or "application/octet-stream"
    if path.suffix == ".ttf":
        mime = "font/ttf"
    return f"data:{mime};base64,{base64.b64encode(path.read_bytes()).decode('ascii')}"


def main() -> None:
    page = (SRC / "template.html").read_text(encoding="utf-8")
    page = page.replace("__MACHINE_JS__", (SRC / "machine.js").read_text(encoding="utf-8"))
    page = re.sub(r"__ASSET:([^_][^\s'\"()]*?)__", lambda m: data_uri(m.group(1)), page)
    OUT.write_text(page, encoding="utf-8")
    print(f"wrote {OUT.relative_to(ROOT)} ({OUT.stat().st_size // 1024} KB)")


if __name__ == "__main__":
    main()
