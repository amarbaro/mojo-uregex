#!/usr/bin/env python3
# Copyright 2026 amarbaro.org. Licensed under the Apache License, Version 2.0.
"""Benchmark reference arm + corpus/pattern generator.

Writes .work/bench/corpus.txt (deterministic ~1 MB mixed-script text) and
.work/bench/patterns.tsv (tokenizer patterns from difftest.py), then times
Python `regex.findall` on the corpus. tools/bench.mojo reads the same two files.
Output: one TSV line per pattern: arm, name, matches, best_seconds, MB/s.
"""
import random
import sys
import time
from pathlib import Path

import regex

sys.path.insert(0, str(Path(__file__).resolve().parent))
from difftest import TOKENIZER_PATTERNS  # noqa: E402

ROOT = Path(__file__).resolve().parent.parent
OUT = ROOT / ".work/bench"
BENCH = ["gpt2", "qwen2", "qwen35", "llama3", "spark2_5_3"]
# ASCII-only GPT-2 shape: the one pattern every arm (incl. mojo-regex, no \p{} / lookahead) can run.
ASCII = {"ascii_gpt2": r"'s|'t|'re|'ve|'m|'ll|'d| ?[A-Za-z]+| ?[0-9]+| ?[^\sA-Za-z0-9]+|\s+"}
WORDS = (["the", "model", "token", "Hello", "isn't", "we'll", "naïve", "café", "Straße", "über",
          "привет", "мир", "данные", "日本語", "東京", "テキスト", "ひらがな", "中文", "数据",
          "1234", "3.14159", "2026", "٣٤٥", "😀", "🚀✨", "é", "$9.99", "(x)", "foo_bar",
          "--flag", "a/b/c", "#tag", "@user"])
SEPS = [" "] * 12 + ["  ", "\n", "\n\n", "\t", ", ", ". ", "   \n"]


def corpus(nbytes=1 << 20, seed=7):
    rng = random.Random(seed)
    parts, size = [], 0
    while size < nbytes:
        w = rng.choice(WORDS) + rng.choice(SEPS)
        parts.append(w)
        size += len(w.encode())
    return "".join(parts)


def main():
    OUT.mkdir(parents=True, exist_ok=True)
    text = corpus()
    (OUT / "corpus.txt").write_text(text, encoding="utf-8")
    with open(OUT / "patterns.tsv", "w", encoding="utf-8") as f:
        for name in BENCH:
            f.write(f"{name}\t{TOKENIZER_PATTERNS[name]}\n")
        for name, pat in ASCII.items():
            f.write(f"{name}\t{pat}\n")
    with open(OUT / "patterns-ascii.tsv", "w", encoding="utf-8") as f:
        for name, pat in ASCII.items():
            f.write(f"{name}\t{pat}\n")
    mb = len(text.encode()) / 1e6
    for name, src in [*((n, TOKENIZER_PATTERNS[n]) for n in BENCH), *ASCII.items()]:
        pat = regex.compile(src)
        best, n = 1e9, 0
        for _ in range(5):
            t0 = time.perf_counter()
            n = len(pat.findall(text))
            best = min(best, time.perf_counter() - t0)
        print(f"python\t{name}\t{n}\t{best:.4f}\t{mb / best:.2f}")


if __name__ == "__main__":
    main()
