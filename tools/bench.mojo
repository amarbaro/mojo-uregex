# Copyright 2026 amarbaro.org. Licensed under the Apache License, Version 2.0.
# Benchmark Mojo arm: reads .work/bench/{corpus.txt,patterns.tsv} (tools/bench.py writes them).
# Output TSV: arm, name, matches, best_seconds, MB/s; then compile time and type sizes.
from std.sys import size_of
from std.time import perf_counter_ns
from uregex import Pattern
from uregex.vm import Inst
from uregex.classes import CharClass
from uregex.pattern import Match


def bench_one(src: String, text: String) raises -> Tuple[Int, Float64, Int]:
    var t0 = perf_counter_ns()
    var p = Pattern(src)
    var compile_ns = Int(perf_counter_ns() - t0)
    var best = Float64(1e18)
    var n = 0
    for _ in range(5):
        var s = perf_counter_ns()
        n = len(p.findall(text))
        var dt = Float64(perf_counter_ns() - s) / 1e9
        if dt < best:
            best = dt
    return (n, best, compile_ns)


def main() raises:
    var text: String
    with open(".work/bench/corpus.txt", "r") as f:
        text = f.read()
    var spec: String
    with open(".work/bench/patterns.tsv", "r") as f:
        spec = f.read()
    var mb = Float64(text.byte_length()) / 1e6
    var compile_ns = 0
    for line in spec.split("\n"):
        if line.byte_length() == 0:
            continue
        var cols = line.split("\t")
        var r = bench_one(String(cols[1]), text)
        compile_ns += r[2]
        print("mojo\t" + String(cols[0]) + "\t" + String(r[0]) + "\t" + String(r[1]) + "\t" + String(mb / r[1]))
    print("compile_ms_total\t" + String(Float64(compile_ns) / 1e6))
    print("sizeof\tInst=" + String(size_of[Inst]()) + " Match=" + String(size_of[Match]()) + " CharClass=" + String(size_of[CharClass]()))
