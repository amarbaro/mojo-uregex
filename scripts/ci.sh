#!/usr/bin/env bash
# CI entry: the full offline gate.
set -euo pipefail
cd "$(dirname "$0")/.."
exec bash tools/gate.sh
