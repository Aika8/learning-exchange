#!/usr/bin/env bash
# Starts a throwaway exchange (`make dev PORT=8091 JOURNAL=memory`), waits for /health, runs smoke.sh against it,
# and always stops it again (`make stop PORT=8091`), whatever happens. Never touches Aika's 8080.
#   scripts/smoke/run-local.sh            (SMOKE_PORT, SMOKE_WAIT_SECONDS to override)
set -uo pipefail
root="$(cd "$(dirname "$0")/../.." && pwd)"
port="${SMOKE_PORT:-8091}"
wait_s="${SMOKE_WAIT_SECONDS:-240}"
[[ "$port" == 8080 ]] && { echo "smoke: refusing to use port 8080" >&2; exit 1; }
cd "$root" || exit 1
# The port must be free before anything starts and before the trap is set: otherwise the health loop would test a
# foreign server (code this run did not build) and the trap's `make stop` would kill a server this run never started.
scripts/exchange-procs.sh check "$port" >&2 || { echo "smoke: FAIL — port $port is busy; not starting" >&2; exit 1; }
if curl -s -o /dev/null --max-time 2 "http://localhost:$port/"; then
  echo "smoke: FAIL — something already answers on port $port; not starting" >&2; exit 1
fi
log="$(mktemp -t smoke-dev.XXXXXX.log)"

make -s dev PORT="$port" JOURNAL=memory >"$log" 2>&1 &
dev_pid=$!
cleanup() {
  make -s stop PORT="$port" >/dev/null 2>&1 || true
  kill "$dev_pid" 2>/dev/null || true   # the gradle client, if the server never came up
  wait "$dev_pid" 2>/dev/null || true
}
trap cleanup EXIT
trap 'exit 1' INT TERM

echo "smoke: starting the exchange on port $port (log $log)"
for ((i = 0; i < wait_s; i += 2)); do
  curl -sf "http://localhost:$port/api/v1/health" >/dev/null && break
  kill -0 "$dev_pid" 2>/dev/null || { echo "smoke: FAIL — make dev exited; last lines of $log:" >&2; tail -20 "$log" >&2; exit 1; }
  sleep 2
done
curl -sf "http://localhost:$port/api/v1/health" >/dev/null \
  || { echo "smoke: FAIL — no health after ${wait_s}s; last lines of $log:" >&2; tail -20 "$log" >&2; exit 1; }

"$root/scripts/smoke/smoke.sh" "http://localhost:$port"
