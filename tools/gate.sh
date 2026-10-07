#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
mkdir -p .work
./.venv/bin/mojo build tools/uregex-cli.mojo -I src -o .work/uregex-cli
# every tool must still build against the current API (bench_mojoregex needs an external checkout)
for t in tools/bench.mojo tools/bench_compile.mojo; do
  ./.venv/bin/mojo build "$t" -I src -o .work/gate-build || { echo "FAIL gate: $t does not build"; exit 1; }
done
./.venv/bin/mojo run -I src tests/test_uregex.mojo
./.venv/bin/python3 tools/check_unicode.py
./.venv/bin/python3 tools/difftest.py --n 5000 --maxlen 80
./.venv/bin/python3 tools/difftest.py --n 5000 --maxlen 80 --bytes
./.venv/bin/python3 tools/difftest.py --n 500 --maxlen 80 --negative
