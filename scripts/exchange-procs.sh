#!/usr/bin/env bash
# Lists (or stops) the exchange servers and Gradle test workers of every checkout and worktree of this repo.
#   scripts/exchange-procs.sh ps            — pid, port, age, CPU, kind, folder
#   scripts/exchange-procs.sh stop [PORT]   — stops the exchange started from THIS folder (or the one on PORT)
#   scripts/exchange-procs.sh check PORT    — exit 1 with a message if something already listens on PORT
set -euo pipefail
here="$(cd "$(dirname "$0")/.." && pwd)"
repo="$(basename "$(git -C "$here" rev-parse --path-format=absolute --git-common-dir 2>/dev/null | xargs dirname)")"

procs() { # pid kind
  ps -Ao pid=,command= | while read -r pid cmd; do
    case "$cmd" in
      */bin/java\ *app.ExchangeApplication*) echo "$pid exchange" ;;
      */bin/java\ *GradleWorkerMain*) echo "$pid gradle-test" ;;
    esac
  done
}
cwd_of()  { lsof -a -p "$1" -d cwd -Fn 2>/dev/null | sed -n 's/^n//p'; }
port_of() { lsof -a -p "$1" -nP -iTCP -sTCP:LISTEN -Fn 2>/dev/null | sed -n 's/^n.*:\([0-9]*\)$/\1/p' | head -1; }

case "${1:-ps}" in
  ps)
    printf '%-7s %-6s %-12s %-6s %-12s %s\n' PID PORT AGE CPU% KIND FOLDER
    procs | while read -r pid kind; do
      read -r etime cpu < <(ps -o etime=,%cpu= -p "$pid")
      dir="$(cwd_of "$pid")"
      [[ "$dir" == *"$repo"* ]] || continue
      printf '%-7s %-6s %-12s %-6s %-12s %s\n' "$pid" "$(port_of "$pid")" "$etime" "$cpu" "$kind" "$dir"
    done ;;
  stop)
    port="${2:-}"; found=0
    while read -r pid kind; do
      [[ "$kind" == exchange ]] || continue
      if [[ -n "$port" && "$(port_of "$pid")" == "$port" ]] || [[ -z "$port" && "$(cwd_of "$pid")" == "$here" ]]; then
        echo "stopping exchange pid $pid (port $(port_of "$pid"), $(cwd_of "$pid"))"; kill "$pid"; found=1
      fi
    done < <(procs)
    [[ $found == 1 ]] || echo "no exchange to stop${port:+ on port $port} for $here" ;;
  check)
    pid="$(lsof -nP -iTCP:"$2" -sTCP:LISTEN -t 2>/dev/null | head -1 || true)"
    if [[ -n "$pid" ]]; then
      echo "port $2 is already used by pid $pid ($(cwd_of "$pid")). 'make ps' lists servers, 'make stop' stops this folder's one;"
      echo "or start on another port: make dev PORT=8091"; exit 1
    fi ;;
  *) echo "usage: $0 ps | stop [PORT] | check PORT" >&2; exit 2 ;;
esac
