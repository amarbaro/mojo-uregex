#!/usr/bin/env bash
# Benchmark: Python regex arm vs uregex arm on .work/bench/corpus.txt. Writes .work/bench/results.tsv.
set -euo pipefail
cd "$(dirname "$0")/.."
mkdir -p .work/bench
./.venv/bin/python3 tools/bench.py > .work/bench/python.tsv || { echo "FAIL bench: python arm, see .work/bench/python.tsv"; exit 1; }
./.venv/bin/mojo build -O3 tools/bench.mojo -I src -o .work/bench/bench-mojo 2> .work/bench/build.log || { echo "FAIL bench: build, see .work/bench/build.log"; exit 1; }
./.venv/bin/python3 -c 'import resource, subprocess, sys
r = subprocess.run(["./.work/bench/bench-mojo"], stdout=open(".work/bench/mojo.tsv", "w"))
print("peak_rss_kb\t%d" % resource.getrusage(resource.RUSAGE_CHILDREN).ru_maxrss)
sys.exit(r.returncode)' > .work/bench/mojo.time || { echo "FAIL bench: mojo arm"; exit 1; }
: > .work/bench/mojo-regex.tsv
if [ -d .work/bench/mojo-regex/src/regex ]; then
  if ./.venv/bin/mojo build -O3 tools/bench_mojoregex.mojo -I .work/bench/mojo-regex/src -o .work/bench/bench-mojoregex 2> .work/bench/build-mojoregex.log; then
    ./.work/bench/bench-mojoregex > .work/bench/mojo-regex.tsv || { echo "FAIL bench: mojo-regex arm"; exit 1; }
  else echo "mojo-regex arm skipped: build failed, see .work/bench/build-mojoregex.log"; fi
else echo "mojo-regex arm skipped: no checkout at .work/bench/mojo-regex"; fi
cat .work/bench/python.tsv .work/bench/mojo.tsv .work/bench/mojo-regex.tsv .work/bench/mojo.time | tee .work/bench/results.tsv
fail=0
while IFS=$'\t' read -r _ name n _; do
  m=$(awk -F'\t' -v k="$name" '$1=="mojo" && $2==k {print $3}' .work/bench/mojo.tsv)
  [ "$m" = "$n" ] || { echo "FAIL bench: $name match count mojo=$m python=$n"; fail=1; }
done < .work/bench/python.tsv
[ $fail = 0 ] && echo "bench: match counts agree" || exit 1
