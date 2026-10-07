# Copyright 2026 amarbaro.org. Licensed under the Apache License, Version 2.0.
from std.sys import argv
from uregex import Pattern, FullPattern, PatternT


def main() raises:
    var args = argv()
    var bytes_mode = len(args) == 4 and String(args[1]) == "--bytes"
    var a = 2 if bytes_mode else 1
    if len(args) < a + 2:
        print("usage: uregex-cli [--bytes] PATTERN TEXTS_FILE   (texts separated by NUL)")
        return
    var src = String(args[a])
    var data: String
    with open(String(args[a + 1]), "r") as f:
        data = f.read()
    # Plain engine (the tokenizer path) whenever the pattern needs nothing more.
    var plain = FullPattern(src).groups() == 0
    if plain:
        try:
            _ = Pattern(src)
        except:
            plain = False
    if plain:
        run(Pattern(src), data, bytes_mode)
    else:
        run(FullPattern(src), data, bytes_mode)


def run[full: Bool](pat: PatternT[full], data: String, bytes_mode: Bool) raises:
    var texts = data.split("\0")
    for t in texts:
        var text = String(t)
        var line = String("")
        if pat.groups() > 0:
            # byte offset -> codepoint index
            var cpi = List[Int](length=text.byte_length() + 1, fill=0)
            var k = 0
            var b = 0
            for c in text.codepoints():
                cpi[b] = k
                b += c.utf8_byte_length()
                k += 1
            cpi[b] = k
            for row in pat.findall_groups(text):
                var cells = List[String]()
                for m in row:
                    if m.start < 0 or bytes_mode:
                        cells.append(String(m.start) + "," + String(m.end))
                    else:
                        cells.append(String(cpi[m.start]) + "," + String(cpi[m.end]))
                line += "|".join(cells) + " "
        elif bytes_mode:
            for m in pat.findall_spans(text):
                line += String(m.start) + "," + String(m.end) + " "
        else:
            for m in pat.findall_cps_offsets(text):
                line += String(m.start) + "," + String(m.end) + " "
        print(line)
