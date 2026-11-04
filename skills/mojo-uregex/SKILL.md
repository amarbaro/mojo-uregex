---
name: mojo-uregex
description: "Unicode regular expressions for Mojo: \\p{L} categories, lookahead, (?i:...) groups, bounded repeats, PCRE leftmost-first alternation, UTF-8 byte offsets. Use for LLM pre-tokenizer patterns or any regex that Mojo's byte-class engines cannot express."
metadata:
  short-description: "Unicode regex for Mojo, built for LLM pre-tokenizers; checked against Python's regex module"
---

# mojo-uregex

Backtracking regex VM over UTF-8 bytes, checked against Python's `regex` module by
differential testing. Built for GPT-2, Llama 3 and Qwen pre-tokenizers.

## When to use

A Mojo program needs `\p{L}` / `\p{N}` categories, lookahead, `(?i:...)` groups or bounded repeats
on UTF-8 text. Not for plain byte-class patterns where a DFA engine is faster.

## Install

`mojo run -I src app.mojo` from a clone (or `mojo build -I src ...`), or copy `src/uregex/`.

## The calls

```mojo
from uregex import Pattern, compile, findall, search, split_keep

def main() raises:
    var pre = r"(?i:'s|'t|'re)|\p{L}+|\p{N}{1,3}"
    for tok in findall(pre, "It's héllo 一二 12345"):   # List[String], one-shot
        print(tok)

    var p = Pattern(pre)                  # compile once, reuse for every text
    var spans = p.findall_spans("héllo 12")
    print(spans[0].start, spans[0].end)   # byte offsets: 0 6
    var m = search(r"\d+(?!\d)", "a12b")  # Optional[Match]
    if m:
        print(m.value().start, m.value().end)
    print(len(split_keep(r"\s+", "a b  c")))   # matches kept as pieces: 5

    var named = compile(r"(?P<k>\w+)=(\d+)")   # FullPattern: groups
    print(named.group_index("k"), len(named.findall_groups("a=1 b=2")))
```

## Gotchas

- Compile once: the module-level `findall`/`search`/`split_keep` parse the pattern on every call.
  Hold a `Pattern` and call its methods in a loop.
- `Match.start`/`end` are **byte** offsets into the `String`. `findall_cps_offsets` gives codepoint offsets.
- `Pattern` has no capture groups; `FullPattern` (from `compile`) adds them, `findall_groups`
  (`[0]` whole match, `(-1, -1)` for an unset group) and named groups. Named groups on a `Pattern` raise.
- Alternation is leftmost-first like PCRE: `ab|abc` matches `ab`.
- Compile raises `uregex: ...` for possessive quantifiers, an unbounded repeat of a nullable
  expression and a repeat with max below min. Catch it for patterns you do not control.
- Matching backtracks: a nested-quantifier pattern on adversarial text can be slow.

## Gate

`tools/gate.sh` from the repo, exit 0: tests, example, Unicode tables, and 10,500 differential cases
against Python's `regex`.
