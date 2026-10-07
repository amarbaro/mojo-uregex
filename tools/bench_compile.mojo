# Copyright 2026 amarbaro.org. Licensed under the Apache License, Version 2.0.
# Compile cost: each pattern in .work/bench/patterns.tsv compiled 50 times and kept alive.
# Output: compile_us_per_pattern, rss_kb_per_pattern (VmRSS delta / count).
from std.time import perf_counter_ns
from uregex import Pattern


def rss_kb() raises -> Int:
    var s: String
    with open("/proc/self/status", "r") as f:
        s = f.read()
    for line in s.split("\n"):
        if line.startswith("VmRSS:"):
            return Int(String(line[byte=6:].strip().split(" ")[0]))
    raise Error("no VmRSS")


def main() raises:
    var spec: String
    with open(".work/bench/patterns.tsv", "r") as f:
        spec = f.read()
    var srcs = List[String]()
    for line in spec.split("\n"):
        if line.byte_length() > 0:
            srcs.append(String(line.split("\t")[1]))
    var kept = List[Pattern]()
    var r0 = rss_kb()
    var t0 = perf_counter_ns()
    for _ in range(50):
        for s in srcs:
            kept.append(Pattern(s))
    var dt = Float64(perf_counter_ns() - t0) / 1e3
    var n = len(kept)
    print("compile_us_per_pattern\t" + String(dt / Float64(n)))
    print("rss_kb_per_pattern\t" + String(Float64(rss_kb() - r0) / Float64(n)))
