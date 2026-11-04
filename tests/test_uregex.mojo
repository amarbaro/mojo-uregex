# Copyright 2026 amarbaro.org. Licensed under the Apache License, Version 2.0.
from std.testing import assert_equal, assert_true, assert_raises, TestSuite
from uregex import Pattern, FullPattern, findall, search, split_keep
from uregex.vm import Inst
from std.sys import size_of
from std.time import perf_counter_ns


def test_unicode_classes() raises:
    assert_equal(len(findall(r"\p{L}+", "héllo 一二 world")), 3)
    assert_equal(findall(r"\p{N}{1,3}", "12345")[0], "123")
    assert_equal(len(findall(r"\P{L}+", "ab12cd")), 1)


def test_case_insensitive_group() raises:
    var r = findall(r"(?i:'s|'t|'ll)", "IT'S 'Ll 't")
    assert_equal(len(r), 3)
    assert_equal(r[0], "'S")


def test_lookahead() raises:
    var r = findall(r"\s+(?!\S)|\s+", "a   b  ")
    assert_equal(r[0], "  ")
    assert_equal(r[1], " ")
    assert_equal(r[2], "  ")


def test_alternation_is_leftmost_first() raises:
    assert_equal(findall("ab|abc", "abc")[0], "ab")


def test_dollar_matches_before_a_final_newline() raises:
    # Python re/regex: `$` is the text end and just before a final "\n"; `\Z` and `\z` only the very end
    assert_equal(len(findall("a$", "a\n")), 1)
    assert_equal(len(findall("a$", "a\n\n")), 0)
    assert_equal(len(findall("a$", "\n")), 0)
    assert_equal(len(findall("a$", "")), 0)
    assert_equal(len(findall("\n$", "\n")), 1)
    assert_equal(search("$", "a\n").value().start, 1)
    assert_equal(search("$", "a\n\n").value().start, 2)
    assert_equal(len(findall("$", "a\n")), 2)
    assert_equal(len(findall("a\\Z", "a\n")), 0)
    assert_equal(len(findall("a\\z", "a\n")), 0)
    assert_equal(len(findall("a\\Z", "a")), 1)
    assert_equal(search("\\z", "a\n").value().start, 2)


def test_split_keep_covers_text() raises:
    var pieces = split_keep(r"\p{N}+", "ab12cd3")
    assert_equal(len(pieces), 4)
    assert_equal(pieces[1], "12")


def test_search_offsets_are_bytes() raises:
    var m = search(r"\p{N}+", "一二三42").value()
    assert_equal(m.start, 9)
    assert_equal(m.end, 11)


def test_codepoint_offsets() raises:
    var r = Pattern(r"\p{N}+").findall_cps_offsets("一二三42 é7")
    assert_equal(len(r), 2)
    assert_equal(r[0].start, 3)
    assert_equal(r[1].start, 7)
    assert_equal(r[1].end, 8)


def test_rejects_unsupported() raises:
    with assert_raises():
        _ = Pattern(r"a*+")
    with assert_raises():
        _ = Pattern(r"(?:a?)*")
    with assert_raises():
        _ = Pattern(r"(?<=a+)b")
    with assert_raises():
        _ = Pattern(r"(?P<n>a)(?P<n>b)")


def test_trailing_property_escape_raises() raises:
    with assert_raises(contains="property"):
        _ = Pattern(r"\p")
    with assert_raises(contains="property"):
        _ = Pattern(r"a[\p")
    with assert_raises():
        _ = Pattern(r"\p{L")


def test_inverted_repeat_bounds_raise() raises:
    with assert_raises(contains="repeat"):
        _ = Pattern(r"a{3,1}")
    with assert_raises(contains="repeat"):
        _ = FullPattern(r"(?:ab){2,1}?")
    assert_equal(len(findall(r"a{2,2}", "aaaa")), 2)
    assert_equal(findall(r"a{1,3}", "aaaa")[0], "aaa")


def test_backreferences_are_rejected() raises:
    with assert_raises(contains="backreference"):
        _ = FullPattern(r"(a)\1")
    with assert_raises(contains="backreference"):
        _ = Pattern(r"\9")
    with assert_raises(contains="backreference"):
        _ = FullPattern(r"(?P<n>a)\k<n>")
    assert_equal(len(findall(r"\0", "a")), 0)  # \0 stays NUL


def test_huge_counts_are_capped_fast() raises:
    # bounded repeats are unrolled, so the program size is capped; past it compiling raises at once
    var t = perf_counter_ns()
    with assert_raises(contains="too large"):
        _ = Pattern(r"a{99999999999}")
    with assert_raises(contains="too large"):
        _ = Pattern(r"(?:a{2000}){1000}")
    with assert_raises(contains="too large"):
        _ = Pattern(r"a{1,99999999999}")
    assert_true(perf_counter_ns() - t < 1_000_000_000)
    assert_equal(len(findall(r"a{1000}", "a" * 2500)), 2)
    assert_equal(len(findall(r"a{1,5000}", "a" * 2500)), 1)


def test_plain_pattern_rejects_full_syntax() raises:
    with assert_raises():
        _ = Pattern(r"\bx")
    with assert_raises():
        _ = Pattern(r"(?<=a)b")
    with assert_raises():
        _ = Pattern(r"(?P<n>a)")
    assert_equal(Pattern(r"(ab)+").groups(), 0)
    assert_equal(Pattern(r"a+?").findall("aaa")[0], "a")


def test_lazy() raises:
    assert_equal(findall(r"<.+?>", "<a><b>")[0], "<a>")
    assert_equal(findall(r"a{2,4}?", "aaaaa")[0], "aa")


def test_word_boundary() raises:
    var r = findall(r"\bcat\b", "cat concat cat_ cat.")
    assert_equal(len(r), 2)
    assert_equal(len(findall(r"\Bé", "éé é")), 1)


def test_lookbehind() raises:
    var r = findall(r"(?<=\$)\d+|(?<!\w)x", "$12 3 x ax")
    assert_equal(len(r), 2)
    assert_equal(r[0], "12")


def test_groups() raises:
    var p = FullPattern(r"(?P<word>\p{L}+)(\d)?")
    assert_equal(p.groups(), 2)
    assert_equal(p.group_index("word"), 1)
    var rows = p.findall_groups("é1 b")
    assert_equal(len(rows), 2)
    assert_equal(rows[0][1].end, 2)
    assert_equal(rows[0][2].start, 2)
    assert_equal(rows[1][2].start, -1)


def test_inst_layout() raises:
    # op/ci/neg pack into 3 bytes + 1 pad, a/b are Int32: 12 bytes, was 32 with Int fields.
    assert_equal(size_of[Inst](), 12)


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
