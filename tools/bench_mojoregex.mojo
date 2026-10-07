# Copyright 2026 amarbaro.org. Licensed under the Apache License, Version 2.0.
# Optional comparison arm: msaelices/mojo-regex (checked out under .work/bench/mojo-regex)
# on the ASCII pattern from patterns-ascii.tsv; it has no \p{} classes or lookahead.
from std.time import perf_counter_ns
from regex import findall


def main() raises:
    var text: String
    with open(".work/bench/corpus.txt", "r") as f:
        text = f.read()
    var spec: String
    with open(".work/bench/patterns-ascii.tsv", "r") as f:
        spec = f.read()
    var mb = Float64(text.byte_length()) / 1e6
    for line in spec.split("\n"):
        if line.byte_length() == 0:
            continue
        var cols = line.split("\t")
        var pat = String(cols[1])
        var best = Float64(1e18)
        var n = 0
        for _ in range(5):
            var s = perf_counter_ns()
            n = len(findall(pat, text))
            var dt = Float64(perf_counter_ns() - s) / 1e9
            if dt < best:
                best = dt
        print("mojo-regex\t" + String(cols[0]) + "\t" + String(n) + "\t" + String(best) + "\t" + String(mb / best))
