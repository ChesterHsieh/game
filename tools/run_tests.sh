#!/usr/bin/env bash
# gdUnit4 runner with timeout + full stderr capture.
# Usage: tools/run_tests.sh [-t SECONDS] [--] <gdunit args>
#   tools/run_tests.sh -t 10 -a tests/unit/smoke_test.gd
#   tools/run_tests.sh -- -a tests/unit/interaction_template_framework/

set -u
TIMEOUT=10
while getopts "t:" opt; do
    case $opt in
        t) TIMEOUT="$OPTARG" ;;
        *) echo "Usage: $0 [-t SECONDS] [--] <gdunit args>" >&2; exit 2 ;;
    esac
done
shift $((OPTIND-1))
[ "${1:-}" = "--" ] && shift

: "${GODOT_BIN:?Set GODOT_BIN to the Godot binary path}"
[ -x "$GODOT_BIN" ] || { echo "GODOT_BIN not executable: $GODOT_BIN" >&2; exit 1; }

mkdir -p reports
LOG="reports/last_run.log"
: > "$LOG"

if command -v gtimeout >/dev/null 2>&1; then
    TIMEOUT_CMD=(gtimeout --kill-after=2 "$TIMEOUT")
elif command -v timeout >/dev/null 2>&1; then
    TIMEOUT_CMD=(timeout --kill-after=2 "$TIMEOUT")
else
    TIMEOUT_CMD=(perl -e 'my $t=shift; $SIG{ALRM}=sub{kill 9,-$$;exit 124}; alarm $t; exec @ARGV' "$TIMEOUT")
fi

{
    echo "[run_tests] $(date '+%Y-%m-%d %H:%M:%S')"
    echo "[run_tests] timeout=${TIMEOUT}s"
    echo "[run_tests] args: $*"
    echo "[run_tests] log: $LOG"
    echo "---"
} | tee -a "$LOG"

# No -d: in debug mode, parser/runtime errors drop into an interactive
# `debug>` prompt and hang until killed. We want fast-fail with stack trace.
"${TIMEOUT_CMD[@]}" "$GODOT_BIN" --path . --headless -s \
    res://addons/gdUnit4/bin/GdUnitCmdTool.gd --ignoreHeadlessMode "$@" </dev/null 2>&1 | tee -a "$LOG"
ec=${PIPESTATUS[0]}

echo "---" | tee -a "$LOG"
case $ec in
    0)           echo "[run_tests] tests passed (exit 0)" | tee -a "$LOG" ;;
    100)         echo "[run_tests] tests ran, some FAILED (gdUnit4 exit 100) — see reports/report_*/index.html" | tee -a "$LOG" ;;
    124|137|142) echo "[run_tests] TIMED OUT after ${TIMEOUT}s (exit $ec) — see $LOG" | tee -a "$LOG" ;;
    *)           echo "[run_tests] CRASHED or infrastructure error (exit $ec) — see $LOG" | tee -a "$LOG" ;;
esac
exit "$ec"
