# Design

uregex is a backtracking VM that runs on UTF-8 bytes, compiled in two variants from one source.
It is 1.9 to 3.1x faster than Python `regex` on tokenizer patterns (README, Performance) and gives
the same matches, because the semantics it copies (PCRE leftmost-first) are the ones a backtracker
gets for free. A DFA would be faster on plain byte classes; [`mojo-regex`](https://github.com/msaelices/mojo-regex)
already covers that case.

## Backtracking because tokenizers need PCRE semantics

Every BPE pre-tokenizer depends on leftmost-first alternation (`ab|abc` matches `ab`) and on
lookahead (`\s+(?!\S)`). Both are natural in a backtracking VM and awkward in a DFA. Python
`regex` is the reference, and `tools/difftest.py` compares against it on every gate run.

## One source, two engines

`PatternT[full: Bool]`: `Pattern` (`full = False`) is the tokenizer engine, `FullPattern` adds
captures, named groups, `\b` and lookbehind. That code sits behind `comptime if` and in
`rare_op`, out of the hot loop, so `Pattern` pays nothing for it. Compiling a pattern that needs
the full machinery as a `Pattern` raises instead of silently running slower.

## Match on bytes, never decode the input

The VM walks the UTF-8 bytes of the String. Classes decode one codepoint at the current position
only when they need it; an ASCII bitmap per class answers the common case without decoding.
`findall` and `split_keep` return slices of the input, with no codepoint copy. Codepoint offsets
exist (`findall_cps_offsets`) for callers that need them.

## Small programs

- An instruction is 12 bytes (was 32 in 0.1.0), pinned by `test_inst_layout`.
- Counted repeats are unrolled at compile time; past 1,048,576 instructions (`MAX_PROGRAM`) a
  pattern raises `pattern too large` instead of eating memory.
- A first-character filter skips start positions that cannot match: `\p{N}{1,3}` went from
  94 to 137 MB/s with it.
- Unicode tables (categories, `\d \w \s`, case maps) are generated from UCD 18.0 by
  `tools/gen_unicode.mojo`, not read at run time.

## Rejected

Possessive quantifiers, backreferences, variable-length lookbehind and unbounded repeats of a
nullable expression raise a parse error: tokenizer patterns do not use them, and each would cost
the hot loop.

## How to prove it wrong

`tools/gate.sh` runs the tests, `check_unicode.py`, and `difftest.py` on 5,000 generated patterns
over text and over raw bytes, plus a negative control that must catch a broken engine. A pattern
where uregex and Python `regex` disagree is a bug.
