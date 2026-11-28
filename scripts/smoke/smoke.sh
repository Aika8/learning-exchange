#!/usr/bin/env bash
# Smoke test: one order through the engine, over HTTP only (curl + jq).
#   scripts/smoke/smoke.sh BASE_URL        e.g. http://localhost:8091
# health → dev-login (buyer, seller) → deposit → seller rests a limit sell inside the spread → buyer's limit buy
# crosses it → the buyer's statement shows the trade → "smoke: ok", exit 0. Any failed step: message, exit 1.
# Bots trade on the same book, so the sell goes strictly inside the spread and a step a bot
# spoiled is retried with fresh users (SMOKE_ATTEMPTS, default 5).
set -uo pipefail

base="${1:?usage: $0 BASE_URL (e.g. http://localhost:8091)}"
api="${base%/}/api/v1"
instrument="${SMOKE_INSTRUMENT:-SILK-SPARK}"
attempts="${SMOKE_ATTEMPTS:-5}"

fail() { echo "smoke: FAIL — $*" >&2; exit 1; }
for tool in curl jq; do command -v "$tool" >/dev/null || fail "$tool is not installed"; done

# call METHOD PATH [TOKEN] [JSON] — prints the body; non-2xx → empty output and status 1.
call() {
  local method="$1" path="$2" token="${3:-}" body="${4:-}"
  local args=(-sS -X "$method" -w '\n%{http_code}')
  [[ -n "$token" ]] && args+=(-H "Authorization: Bearer $token")
  [[ -n "$body" ]] && args+=(-H 'Content-Type: application/json' --data "$body")
  local out code
  out="$(curl "${args[@]}" "$api$path")" || return 1
  code="${out##*$'\n'}"; out="${out%$'\n'*}"
  [[ "$code" == 2* ]] || { echo "smoke: $method $path → HTTP $code: $out" >&2; return 1; }
  printf '%s' "$out"
}

login() { # name → token
  call POST /auth/dev-login "" "$(jq -nc --arg n "$1" '{name:$n}')" | jq -er .token
}

health="$(call GET /health)" || fail "health check did not answer"
[[ "$(jq -r .status <<<"$health")" == UP ]] || fail "health is not UP: $health"
echo "smoke: health UP"

try_once() { # attempt number → 0 ok, 1 hard failure, 2 bots got in the way (retry)
  local tag; tag="$(date +%s)-$RANDOM"
  local buyer seller book bid ask price sell buy statement trade orders filled
  buyer="$(login "smoke-b-$tag")" || fail "dev-login of the buyer failed"
  seller="$(login "smoke-s-$tag")" || fail "dev-login of the seller failed"
  echo "smoke: logged in smoke-b-$tag and smoke-s-$tag"

  call POST /me/deposits "$buyer" '{"asset":"SPARK","amount":100000}' >/dev/null || fail "deposit failed"
  echo "smoke: deposited 1000.00 SPARK"

  book="$(call GET "/instruments/$instrument/book?depth=1")" || fail "book of $instrument did not answer"
  bid="$(jq -r '.bids[0].price // 0' <<<"$book")"
  ask="$(jq -r '.asks[0].price // empty' <<<"$book")"
  if [[ -z "$ask" ]]; then price=$((bid + 1)); else
    (( ask - bid >= 2 )) || { echo "smoke: spread $bid..$ask has no room, retrying" >&2; return 2; }
    price=$(((bid + ask) / 2))
  fi

  sell="$(call POST /orders "$seller" "$(jq -nc --arg i "$instrument" --argjson p "$price" \
    '{instrument:$i, side:"SELL", type:"LIMIT", price:$p, qty:1}')")" || fail "seller's limit sell was refused"
  [[ "$(jq -r .status <<<"$sell")" == NEW ]] || { echo "smoke: the sell did not rest ($sell), retrying" >&2; return 2; }
  echo "smoke: seller rests SELL 1 $instrument @ $price (order $(jq -r .orderId <<<"$sell"))"

  buy="$(call POST /orders "$buyer" "$(jq -nc --arg i "$instrument" --argjson p "$price" \
    '{instrument:$i, side:"BUY", type:"LIMIT", price:$p, qty:1}')")" || fail "buyer's limit buy was refused"
  [[ "$(jq -r .status <<<"$buy")" == FILLED ]] \
    || { echo "smoke: the buy did not fill, a bot took the sell first ($buy), retrying" >&2; return 2; }
  echo "smoke: buyer BUY 1 $instrument @ $price → FILLED (order $(jq -r .orderId <<<"$buy"))"

  orders="$(call GET /orders "$seller")" || fail "seller's orders did not answer"
  filled="$(jq -r --argjson id "$(jq .orderId <<<"$sell")" '.[] | select(.orderId == $id) | .filledQty' <<<"$orders")"
  [[ "$filled" == 1 ]] || { echo "smoke: a bot took the buy before the seller's order (filled=$filled), retrying" >&2; return 2; }

  statement="$(call GET /statement "$buyer")" || fail "buyer's statement did not answer"
  trade="$(jq -c --arg i "$instrument" --argjson p "$price" \
    '[.lines[] | select(.kind == "TRADE" and .instrument == $i and .side == "BUY" and .price == $p and .qty == 1)] | first // empty' \
    <<<"$statement")"
  [[ -n "$trade" ]] || fail "the buyer's statement has no TRADE line for the buy: $statement"
  echo "smoke: statement shows $trade"
  return 0
}

for ((n = 1; n <= attempts; n++)); do
  try_once; rc=$?
  [[ $rc == 0 ]] && { echo "smoke: ok"; exit 0; }
  [[ $rc == 2 ]] || exit 1
done
fail "bots kept getting in the way after $attempts attempts"
