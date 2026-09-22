#!/usr/bin/env python3
"""Inline prompts/*.md into src.html -> dist/10-0-coach.html.

Edit the markdown in prompts/, then run: python3 build.py
"""
import pathlib, re

root = pathlib.Path(__file__).parent
src = (root / "src.html").read_text()

def inline(m):
    text = (root / "prompts" / m.group(1)).read_text()
    return text.replace("</script", "<\\/script")

out = re.sub(r"<!--DOC:([\w.-]+)-->", inline, src)
(root / "dist").mkdir(exist_ok=True)
(root / "dist" / "10-0-coach.html").write_text(out)
print(f"dist/10-0-coach.html  {len(out.encode()):,} bytes")
