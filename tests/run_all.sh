#!/usr/bin/env bash
# sciDatabase — run every acceptance suite and print a combined OK/FAIL summary.
#
# Requires the local test servers: PostgreSQL :5433, MySQL :3307, MongoDB :27018,
# Redis :6380 (SQLite needs nothing). Point SCILAB at your scilab-cli if it is not
# on PATH:  SCILAB=/path/to/scilab-cli  tests/run_all.sh
set -u
SCILAB="${SCILAB:-scilab-cli}"
DIR="$(cd "$(dirname "$0")" && pwd)"

suites=(test_prepared test_wave1 test_wave2 test_wave3 test_wave4 test_wave5)
fail=0
echo "######## sciDatabase — full acceptance run ########"
for s in "${suites[@]}"; do
    out="$("$SCILAB" -nb -f "$DIR/$s.sce" 2>&1)"
    echo "$out" | grep -E '(-> (OK|FAIL))|ERROR'
    if echo "$out" | grep -qE '(-> FAIL)|ERROR'; then fail=1; fi
done
echo "##################################################"
if [ "$fail" -eq 0 ]; then echo "ALL SUITES OK"; else echo "SOME SUITES FAILED"; fi
exit "$fail"
