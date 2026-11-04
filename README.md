# mojo-uregex

<!-- badges -->
[![latest release](https://img.shields.io/github/v/release/amarbaro/mojo-uregex)](https://github.com/amarbaro/mojo-uregex/releases/latest) [![license](https://img.shields.io/github/license/amarbaro/mojo-uregex)](https://github.com/amarbaro/mojo-uregex/blob/main/LICENSE)
<!-- /badges -->

<!-- install -->
Install: `pixi add mojo-uregex` once published. For now: `git clone https://github.com/amarbaro/mojo-uregex`, then `mojo run -I mojo-uregex/src app.mojo`.

```mojo
from uregex import findall


def main() raises:
    # a GPT-2 style pre-tokenizer: contractions, letters of any script, digit groups
    for tok in findall(r"(?i:'s|'t|'re)|\p{L}+|\p{N}{1,3}", "It's héllo 一二 12345"):
        print(tok)
```
<!-- /install -->

Unicode-aware regular expressions for Mojo, built for the pre-tokenizers of LLM
tokenizers (GPT-2, Llama 3, Qwen, DeepSeek, gpt-oss, Spark-X2.5) and verified
against Python's `regex` module by differential testing.

It is the complement of [`mojo-regex`](https://github.com/msaelices/mojo-regex),
which is a fast DFA/NFA engine for byte-class patterns. `uregex` exists for the
patterns that engine lists as missing:

| feature | example | in tokenizers |
|---|---|---|
| Unicode general categories | `\p{L}` `\P{N}` `[\p{L}\p{M}]` `\p{Lu}` | every BPE pre-tokenizer |
| negated shorthand classes | `\S` `\D` `\W` | `\s+(?!\S)` |
| lookahead | `(?!...)` `(?=...)` | `\s+(?!\S)` |
| case-insensitive groups | `(?i:'s\|'t\|'re)` | Llama 3, Qwen |
| bounded repeats | `\p{N}{1,3}` | Llama 3, Spark-X2.5 |
| PCRE leftmost-first alternation | `ab\|abc` matches `ab` | all of them |

Matching runs directly on the UTF-8 bytes of the input with a backtracking VM.
`Match` offsets (`search`, `findall_spans`) are byte offsets into the String;
`findall_cps_offsets` returns codepoint offsets. `findall` and `split_keep`
slice the input without copying it to codepoints.

## Performance

`tools/bench.sh`: `findall` over a 1.05 MB mixed-script corpus, best of 5,
Mojo 1.2.0, CPU. Match counts equal Python `regex` for every pattern.

| pattern | Python `regex` MB/s | uregex MB/s | uregex vs Python |
|---|---|---|---|
| gpt2 | 14.75 | 29.52 | 2.0x |
| ascii_gpt2 | 15.52 | 29.71 | 1.9x |
| qwen2 | 14.91 | 30.66 | 2.1x |
| qwen35 | 14.15 | 30.60 | 2.2x |
| llama3 | 16.36 | 33.11 | 2.0x |
| spark2_5_3 | 13.93 | 43.80 | 3.1x |

Plain-ASCII text gains least. Sparse patterns gain more from the
first-character filter: `\p{N}{1,3}` 94 → 137 MB/s, CJK runs 108 → 196 MB/s
(0.1.0 → current).

Against 0.1.0, same corpus:

| metric | 0.1.0 | 0.3.0 | change |
|---|---|---|---|
| speed | 9.4 to 14.3 MB/s | 29.5 to 43.8 MB/s | 2.1 to 3.5x per pattern |
| bench peak RSS | 68.3 MB | 55.2 MB | -19% |
| compiled pattern (`tools/bench_compile.mojo`) | 166 KB, 0.99 ms | 27.6 KB, 0.81 ms | 6x smaller |
| instruction size (pinned by `test_inst_layout`) | 32 B | 12 B | 2.7x smaller |
| character class size | 32 B | 48 B | +16 B (ASCII bitmap) |

## Setup

Mojo 1.2 in a project venv (the commands below use `./.venv/bin/mojo`):

```
python3 -m venv .venv && ./.venv/bin/pip install 'mojo==1.2.0' 'regex==2026.9.29'
```

## Usage

Two engines from one source. `Pattern` is the tokenizer engine: `(...)` does
not capture, and named groups, lookbehind and `\b` raise. `FullPattern` adds
them; that code is compiled only into `FullPattern`, so `Pattern` runs as fast
as if it did not exist. The one-shot helpers (`findall`, `search`,
`split_keep`, `compile`) use `FullPattern`.

Offsets are UTF-8 byte offsets into the String (`search`, `findall_spans`,
`findall_groups`); `findall_cps_offsets` gives codepoint offsets. `findall` and
`split_keep` return slices of the input.

## Supported syntax

Literals and escapes (`\n \t \xHH \x{H..} \uHHHH \UHHHHHHHH`), `.` (no newline),
`^` `$` (text start; text end or just before a final `\n`, as Python's `$` without MULTILINE), `\Z` `\z` (the very end only), classes `[...]` `[^...]` with ranges and `\p{}`/`\d\w\s`
inside, `\p{Xx}` `\P{Xx}` for the general categories (`Cs` and `LC` raise), `\d \w \s \D \W \S`,
greedy and lazy `* + ? {m} {m,} {m,n}` (`*?` ...), `(?:...)`, `(?i:...)`,
`(?=...)`, `(?!...)`, `|`. Counted repeats are unrolled at compile time, so a pattern that compiles to more than 1,048,576 instructions (`a{99999999999}`, `(?:a{2000}){1000}`) raises `pattern too large`.

`FullPattern` only: capture groups `(...)`, named groups `(?P<name>...)` and
`(?<name>...)`, word boundaries `\b` `\B`, fixed-length lookbehind `(?<=...)`
`(?<!...)`.

Rejected with a parse error: possessive quantifiers, backreferences,
variable-length lookbehind, unbounded repeats of a nullable expression.

Unicode tables (general categories, `\d \w \s`, case maps) are generated from
the Unicode Character Database 18.0 by `tools/gen_unicode.mojo`.

## Verification

`tools/gen_unicode.mojo` writes `src/uregex/unicode_tables.mojo` from the
Unicode Character Database; `tools/check_unicode.py` then checks every table
against Python `regex` (each class equals the codepoints `regex` matches, each
case pair matches under `(?i:...)`). `tools/difftest.py` matches every pattern
above, plus feature probes, against `regex.finditer` on random Unicode strings:

```
mkdir -p .work/ucd && for f in UnicodeData PropList DerivedCoreProperties CaseFolding SpecialCasing; do
  curl -sSfo .work/ucd/$f.txt https://www.unicode.org/Public/18.0.0/ucd/$f.txt; done
./.venv/bin/mojo run tools/gen_unicode.mojo .work/ucd   # regenerate (only when Unicode changes)
./.venv/bin/python3 tools/check_unicode.py
./.venv/bin/mojo build tools/uregex-cli.mojo -I src -o .work/uregex-cli
./.venv/bin/python3 tools/difftest.py --n 5000 --maxlen 80          # codepoint offsets
./.venv/bin/python3 tools/difftest.py --n 5000 --maxlen 80 --bytes  # byte offsets
./.venv/bin/mojo run -I src tests/test_uregex.mojo
```

A negative control (oracle fed a different pattern) fails, so the gate is live.
`tools/gate.sh` runs all of the above.

### Tokenizer patterns

The tokenizer patterns in `tools/difftest.py` are copied verbatim from the
models' own `tokenizer.json` (or llama.cpp's pre-tokenizer table): GPT-2,
Llama 3, Qwen2, Qwen3.5, DeepSeek-Coder, the o200k pattern (gpt-oss,
Phi-4-mini, MiniMax-M2) and Spark-X2.5. Each one runs through the same
differential test as every other pattern.

## Packaging

`recipe.yaml` (modular-community shape) builds a precompiled `.conda` and runs
the unit tests against it: `pixi run package` (needs `rattler-build`), output in
`.work/conda/`. Not published.

## License

Apache-2.0, copyright amarbaro.org. See LICENSE and NOTICE.
