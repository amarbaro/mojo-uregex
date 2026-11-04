# API

Everything is exported from `uregex` (`src/uregex/__init__.mojo`). Offsets are UTF-8 byte offsets
into the input String unless a name says `cps`.

## Types

| name | what |
|---|---|
| `Match` | `start: Int`, `end: Int`. `ImplicitlyCopyable`. |
| `PatternT[full: Bool]` | compiled pattern; use the two aliases below. |
| `Pattern` | `PatternT[False]`, the tokenizer engine. `(...)` does not capture; named groups, lookbehind and `\b` `\B` raise at compile time. |
| `FullPattern` | `PatternT[True]`: adds capture groups, named groups, `\b` `\B`, fixed-length lookbehind. |

## Constructor

`Pattern(pattern: String) raises`, `FullPattern(pattern: String) raises`. Raise on a parse error,
on syntax the engine does not have, and with `pattern too large` past 1,048,576 instructions.

## Methods (both engines)

| signature | returns | raises |
|---|---|---|
| `search(self, text: String) -> Optional[Match]` | first match | no |
| `findall(self, text: String) -> List[String]` | every match, sliced from the input | no |
| `findall_spans(self, text: String) -> List[Match]` | every match, byte spans | no |
| `findall_groups(self, text: String) -> List[List[Match]]` | per match: `[0]` whole, `[i]` group i, `(-1, -1)` unset | no |
| `findall_cps_offsets(self, text: String) -> List[Match]` | like `findall_spans`, codepoint offsets | no |
| `findall_cps(self, text: List[Int]) -> List[Match]` | codepoint input and offsets (compatibility) | no |
| `split_keep(self, text: String) -> List[String]` | the text cut at every match, matches and gaps kept, empty pieces dropped | no |
| `groups(self) -> Int` | number of capture groups | no |
| `group_index(self, name: String) raises -> Int` | index of a named group | `no group named <name>` |
| `new_stack(self) -> List[Int32]` | backtrack scratch with capture slots, all `-1` | no |
| `search_from(self, text: Span[Byte, _], mut stack: List[Int32], start: Int) -> Optional[Match]` | search from a byte offset, reusing `stack` from `new_stack`; group slots filled on a match | no |

## One-shot helpers

Each compiles a `FullPattern` per call; compile once for a loop.

| signature | raises |
|---|---|
| `compile(pattern: String) raises -> FullPattern` | as the constructor |
| `search(pattern: String, text: String) raises -> Optional[Match]` | as the constructor |
| `findall(pattern: String, text: String) raises -> List[String]` | as the constructor |
| `split_keep(pattern: String, text: String) raises -> List[String]` | as the constructor |

Syntax: README, "Supported syntax".
