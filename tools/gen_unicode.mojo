# Copyright 2026 amarbaro.org. Licensed under the Apache License, Version 2.0.
# Generate src/uregex/unicode_tables.mojo from the Unicode Character Database.
#
# Reads UnicodeData.txt, PropList.txt, DerivedCoreProperties.txt, CaseFolding.txt and
# SpecialCasing.txt from UCD_DIR (download: see README, "Verification").
#   \p{Xx}   general category from UnicodeData; one-letter classes are the union.
#   \d       Nd.  \w  Alphabetic | M | Nd | Pc | Join_Control.  \s  White_Space.
#   case     (c, t) where t is c's single-codepoint lower/upper mapping (SpecialCasing
#            unconditional entries first, then UnicodeData) and c, t share a case-fold
#            class (CaseFolding C, S and T edges). Python regex matches these under (?i).
# Surrogates are excluded. tools/check_unicode.py checks the output against Python regex.
# Usage: mojo run tools/gen_unicode.mojo UCD_DIR [OUT]

from std.sys import argv

comptime MAXCP = 0x110000


def cats() -> List[String]:
    return [
        "L", "Lu", "Ll", "Lt", "Lm", "Lo", "M", "Mn", "Mc", "Me", "N", "Nd", "Nl", "No",
        "P", "Pc", "Pd", "Ps", "Pe", "Pi", "Pf", "Po", "S", "Sm", "Sc", "Sk", "So",
        "Z", "Zs", "Zl", "Zp", "C", "Cc", "Cf", "Co", "Cn",
    ]


def hexval(s: StringSlice) raises -> Int:
    var v = 0
    var t = s.strip()
    if t.byte_length() == 0:
        raise Error("empty hex field")
    for b in t.as_bytes():
        var c = Int(b)
        if c >= 48 and c <= 57:
            v = v * 16 + c - 48
        elif c >= 97 and c <= 102:
            v = v * 16 + c - 87
        elif c >= 65 and c <= 70:
            v = v * 16 + c - 55
        else:
            raise Error("bad hex: " + String(t))
    return v


def hexs(n: Int, width: Int = 0) -> String:
    comptime DIGITS = "0123456789abcdef"
    var out = String()
    var x = n
    while True:
        out = String(DIGITS[byte = x % 16]) + out
        x //= 16
        if x == 0:
            break
    while out.byte_length() < width:
        out = "0" + out
    return out


def is_surrogate(c: Int) -> Bool:
    return c >= 0xD800 and c <= 0xDFFF


def data_lines(path: String) raises -> List[String]:
    """Non-empty lines with `#` comments removed."""
    var out = List[String]()
    with open(path, "r") as f:
        for line in f.read().splitlines():
            var body = String(line.split("#")[0].strip())
            if body.byte_length() > 0:
                out.append(body)
    return out^


def prop(path: String, name: String) raises -> List[Bool]:
    var has = List[Bool](length=MAXCP, fill=False)
    for line in data_lines(path):
        var f = line.split(";")
        if String(f[1].strip()) != name:
            continue
        var r = f[0].strip()
        var dots = r.find("..")
        var lo: Int
        var hi: Int
        if dots < 0:
            lo = hexval(r)
            hi = lo
        else:
            lo = hexval(r[byte=0:dots])
            hi = hexval(r[byte = dots + 2 :])
        for c in range(lo, hi + 1):
            has[c] = True
    return has^


def ranges(member: List[Bool]) -> String:
    var out = String()
    var c = 0
    while c < MAXCP:
        if not member[c]:
            c += 1
            continue
        var lo = c
        while c + 1 < MAXCP and member[c + 1]:
            c += 1
        if out.byte_length() > 0:
            out += ";"
        out += hexs(lo) + "-" + hexs(c)
        c += 1
    return out^


def find_root(mut par: List[Int], c: Int) -> Int:
    var r = c
    while par[r] != r:
        r = par[r]
    return r


def main() raises:
    var args = argv()
    if len(args) < 2:
        raise Error("usage: mojo run tools/gen_unicode.mojo UCD_DIR [OUT]")
    var ucd = String(args[1]) + "/"
    var out_path = String(args[2]) if len(args) > 2 else "src/uregex/unicode_tables.mojo"

    # General category and simple case mappings.
    var cat = List[String](length=MAXCP, fill="Cn")
    var upper = List[Int](length=MAXCP, fill=-1)
    var lower = List[Int](length=MAXCP, fill=-1)
    var first = -1
    with open(ucd + "UnicodeData.txt", "r") as f:
        for line in f.read().splitlines():
            if line.byte_length() == 0:
                continue
            var fl = line.split(";")
            var cp = hexval(fl[0])
            var name = fl[1]
            var gc = String(fl[2])
            if name.endswith("First>"):
                first = cp
                continue
            if name.endswith("Last>"):
                for c in range(first, cp + 1):
                    cat[c] = gc
                continue
            cat[cp] = gc
            if fl[12].byte_length() > 0:
                upper[cp] = hexval(fl[12])
            if fl[13].byte_length() > 0:
                lower[cp] = hexval(fl[13])

    var version = String()
    with open(ucd + "DerivedCoreProperties.txt", "r") as f:
        var head = String(f.read().splitlines()[0])
        var dash = head.rfind("-")
        version = String(head[byte = dash + 1 : head.rfind(".txt")])

    var lines = List[String]()
    lines.append("# Copyright 2026 amarbaro.org. Licensed under the Apache License, Version 2.0.")
    lines.append("# Generated by tools/gen_unicode.mojo. Do not edit by hand; rerun the generator.")
    lines.append("# source: Unicode Character Database " + version)
    lines.append("")

    for name in cats():
        var member = List[Bool](length=MAXCP, fill=False)
        for c in range(MAXCP):
            if is_surrogate(c):
                continue
            if name.byte_length() == 2:
                member[c] = cat[c] == name
            else:
                member[c] = cat[c].startswith(name)
        lines.append("comptime _CAT_" + name + ' = "' + ranges(member) + '"')

    var alpha = prop(ucd + "DerivedCoreProperties.txt", "Alphabetic")
    var space = prop(ucd + "PropList.txt", "White_Space")
    var join = prop(ucd + "PropList.txt", "Join_Control")
    var d = List[Bool](length=MAXCP, fill=False)
    var w = List[Bool](length=MAXCP, fill=False)
    var s = List[Bool](length=MAXCP, fill=False)
    for c in range(MAXCP):
        if is_surrogate(c):
            continue
        var gc = cat[c]
        d[c] = gc == "Nd"
        w[c] = alpha[c] or gc.startswith("M") or gc == "Nd" or gc == "Pc" or join[c]
        s[c] = space[c]
    lines.append('comptime _ESC_d = "' + ranges(d) + '"')
    lines.append('comptime _ESC_w = "' + ranges(w) + '"')
    lines.append('comptime _ESC_s = "' + ranges(s) + '"')

    # Case-fold classes: union of single-codepoint C, S and T folds.
    var par = List[Int](capacity=MAXCP)
    for c in range(MAXCP):
        par.append(c)
    for line in data_lines(ucd + "CaseFolding.txt"):
        var f = line.split(";")
        var status = String(f[1].strip())
        var target = f[2].strip()
        if (status != "C" and status != "S" and status != "T") or target.find(" ") >= 0:
            continue
        var ra = find_root(par, hexval(f[0]))
        var rb = find_root(par, hexval(target))
        if ra != rb:
            par[max(ra, rb)] = min(ra, rb)

    # SpecialCasing unconditional entries override UnicodeData; multi-codepoint results drop the pair.
    for line in data_lines(ucd + "SpecialCasing.txt"):
        var f = line.split(";")
        if len(f) > 5 and f[4].strip().byte_length() > 0:
            continue  # conditional (language or context)
        var cp = hexval(f[0])
        var lo = f[1].strip()
        var up = f[3].strip()
        lower[cp] = hexval(lo) if lo.find(" ") < 0 else -1
        upper[cp] = hexval(up) if up.find(" ") < 0 else -1

    var lo_pairs = String()
    var up_pairs = String()
    for c in range(MAXCP):
        if is_surrogate(c):
            continue
        var rc = find_root(par, c)
        var t = lower[c]
        if t >= 0 and t != c and find_root(par, t) == rc:
            lo_pairs += hexs(c, 6) + hexs(t, 6)
        t = upper[c]
        if t >= 0 and t != c and find_root(par, t) == rc:
            up_pairs += hexs(c, 6) + hexs(t, 6)
    lines.append('comptime _LOWER = "' + lo_pairs + '"')
    lines.append('comptime _UPPER = "' + up_pairs + '"')

    lines.append("")
    lines.append("")
    lines.append("def category_table(name: String) -> StaticString:")
    for name in cats():
        lines.append('    if name == "' + name + '":')
        lines.append("        return _CAT_" + name)
    lines.append('    return ""')
    for line in [
        "", "", "def escape_table(c: String) -> StaticString:",
        '    if c == "d":', "        return _ESC_d",
        '    if c == "w":', "        return _ESC_w",
        '    if c == "s":', "        return _ESC_s",
        '    return ""',
        "", "", "def lower_table() -> StaticString:", "    return _LOWER",
        "", "", "def upper_table() -> StaticString:", "    return _UPPER", "",
    ]:
        lines.append(String(line))

    var text = String("\n").join(lines)
    with open(out_path, "w") as f:
        f.write(text)
    print(out_path, text.byte_length(), "bytes; Unicode", version)
