#!/usr/bin/env python3
# Copyright 2026 amarbaro.org. Licensed under the Apache License, Version 2.0.
"""Oracle check for src/uregex/unicode_tables.mojo (written by tools/gen_unicode.mojo).

Every category and escape table must equal the set of codepoints Python `regex`
matches for \\p{Xx}, \\d, \\w and \\s, and every case pair must match under (?i:...).
Exit 1 on any difference. Usage: tools/check_unicode.py [TABLE]
"""
import re
import sys
from pathlib import Path

import regex

table = Path(sys.argv[1] if len(sys.argv) > 1 else "src/uregex/unicode_tables.mojo").read_text()
tables = dict(re.findall(r'comptime (_\w+) = "([^"]*)"', table))
ALL = "".join(chr(c) for c in range(0x110000) if not 0xD800 <= c <= 0xDFFF)


def expand(spec):
    out = set()
    for r in filter(None, spec.split(";")):
        a, b = r.split("-")
        out.update(range(int(a, 16), int(b, 16) + 1))
    return out


fails = []
for name, spec in tables.items():
    if name.startswith("_CAT_") or name.startswith("_ESC_"):
        key = name[5:]
        pat = rf"\p{{{key}}}" if name.startswith("_CAT_") else "\\" + key
        if expand(spec) != {ord(c) for c in regex.findall(pat, ALL)}:
            fails.append(name)
for name in ("_LOWER", "_UPPER"):
    spec = tables[name]
    for i in range(0, len(spec), 12):
        c, t = int(spec[i:i + 6], 16), int(spec[i + 6:i + 12], 16)
        if not regex.fullmatch("(?i:" + regex.escape(chr(c)) + ")", chr(t)):
            fails.append(f"{name} {c:04x}->{t:04x}")
print(f"check_unicode: {len(tables)} tables, regex {regex.__version__}: " + ("PASS" if not fails else f"FAIL {fails[:10]}"))
sys.exit(1 if fails else 0)
