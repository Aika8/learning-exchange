## Lesson catalogue of the M3 slice (world bible §4: Act I shortened, first half of Act II, the first storm and the
## Anchor) and the small, exact sums behind each lesson. Every lesson has a lore title, a real-world name and the
## glossary terms it unlocks in «Словарь капитана». Money in integer minor units.
class_name Lessons
extends RefCounted

## id → [act, glossary ids]. Keys: LESSON_<ID> (lore title), LESSON_<ID>_REAL (real name), LESSON_<ID>_TEXT (scene text).
const ALL := {
	"DEBT": ["I", ["loan-interest"]],
	"CUSHION": ["I", ["financial-cushion"]],
	"GARDEN": ["I", ["deposit"]],
	"FOG": ["I", ["inflation", "policy-rate"]],
	"RISK": ["III", ["stop-loss", "risk-per-trade", "r-multiple"]],
	"SPREAD": ["II", ["order-book", "spread", "market-order", "limit-order"]],
	"FEES": ["II", ["fee"]],
	"LIQUIDITY": ["II", ["liquidity"]],
	"STORM": ["III", ["volatility"]],
	"ANCHOR": ["III", ["stop-loss", "slippage"]],
	"GAP": ["III", ["gap", "slippage"]],
	"CONSENSUS": ["V", ["earnings-season", "consensus", "eps"]],
	"SURPRISE": ["V", ["earnings-report", "gap"]],
	"CHRONICLE": ["III", ["expectancy", "index-fund"]],
}

const ACT_ONE := ["DEBT", "CUSHION", "GARDEN", "FOG"]


static func title_key(id: String) -> String:
	return "LESSON_%s" % id


static func real_key(id: String) -> String:
	return "LESSON_%s_REAL" % id


static func text_key(id: String) -> String:
	return "LESSON_%s_TEXT" % id


static func terms(id: String) -> Array:
	return ALL[id][1] if ALL.has(id) else []


# --- Act I sums -------------------------------------------------------------------------------------------------

## Grandfather's debt after `periods` compounding periods (`per_year` a year) at `rate_bps` a year.
static func debt_after(principal: int, rate_bps: int, per_year: int, periods: int) -> int:
	var d := principal
	for i in periods:
		@warning_ignore("integer_division")
		d += d * rate_bps / (10000 * per_year)
	return d


## Provisions for six moons: the emergency fund is months × monthly costs.
static func cushion(monthly: int, months: int = 6) -> int:
	return monthly * months


## The garden: a deposit compounding once a year for `years`.
static func compound(principal: int, rate_bps: int, years: int) -> int:
	var v := principal
	for i in years:
		@warning_ignore("integer_division")
		v += v * rate_bps / 10000
	return v


## Rule of 72: years to double, × 10 (one decimal). 14% → 51 (5.1 years).
static func years_to_double_x10(rate_bps: int) -> int:
	@warning_ignore("integer_division")
	return 7200 * 10 / rate_bps if rate_bps > 0 else 0


## The fog: what `amount` buys after `years` of `inflation_bps` (in today's coins).
static func after_fog(amount: int, inflation_bps: int, years: int) -> int:
	var v := amount
	for i in years:
		@warning_ignore("integer_division")
		v = v * 10000 / (10000 + inflation_bps)
	return v


## Real rate ≈ nominal − inflation (world bible §5b), bps.
static func real_rate_bps(nominal_bps: int, inflation_bps: int) -> int:
	return nominal_bps - inflation_bps


# --- Act II sums ------------------------------------------------------------------------------------------------

## Selling `qty` into the bids (best first): what you get and how far the last unit went down the Ladder.
## `levels` are [[price, qty], …] best first. Returns {filled, notional, worst, at_best, cost}: `at_best` = the same qty
## at the best price, `cost` = at_best − notional (what thin liquidity took).
static func walk_book(levels: Array, qty: int) -> Dictionary:
	var left := qty
	var notional := 0
	var worst := 0
	for lv: Array in levels:
		if left <= 0:
			break
		var take := mini(left, int(lv[1]))
		notional += take * int(lv[0])
		worst = int(lv[0])
		left -= take
	var filled := qty - left
	var best := int(levels[0][0]) if not levels.is_empty() else 0
	return {"filled": filled, "notional": notional, "worst": worst, "at_best": best * filled, "cost": best * filled - notional}


## Spread in minor units and in bps of the mid.
static func spread(bid: int, ask: int) -> Dictionary:
	if bid <= 0 or ask <= 0:
		return {"abs": 0, "bps": 0}
	@warning_ignore("integer_division")
	var mid := (bid + ask) / 2
	@warning_ignore("integer_division")
	return {"abs": ask - bid, "bps": (ask - bid) * 10000 / mid}


# --- Losses compound too (field guide A13) ----------------------------------------------------------------------

## A series of moves applied to the running balance: each move of `moves_bps` (−1000 = −10%) is one round trip, and
## `fee_bps` is charged on the balance after it. The result is the product of multipliers, not the sum of the moves:
## −10% then +10% leaves less than the start. Every step rounds down (integer division of non-negative numbers), so
## the result never flatters the trader. A move of −100% or worse empties the balance; it stays at 0.
static func series_after(start: int, moves_bps: Array, fee_bps: int) -> int:
	var v := maxi(start, 0)
	for m in moves_bps:
		var mult := maxi(10000 + int(m), 0)
		@warning_ignore("integer_division")
		v = v * mult / 10000
		@warning_ignore("integer_division")
		v = v * maxi(10000 - fee_bps, 0) / 10000
	return v


## The gain in bps that brings a loss of `loss_bps` back to the start: loss / (1 − loss). −10% needs +11.11%
## (1111), −50% needs +100% (10000). Rounds down, so the answer is at most 1 bp short of the exact gain.
## A loss of 100% or more cannot be recovered: returns -1. No loss (≤ 0) needs no gain: returns 0.
static func needed_to_recover_bps(loss_bps: int) -> int:
	if loss_bps <= 0:
		return 0
	if loss_bps >= 10000:
		return -1
	@warning_ignore("integer_division")
	return loss_bps * 10000 / (10000 - loss_bps)
