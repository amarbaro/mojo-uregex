#!/usr/bin/env bash
# CI entry: the full offline gate.
set -euo pipefail
cd "$(dirname "$0")/.."
export MOJO="${MOJO:-.venv/bin/mojo}"
exec bash tools/gate.sh
