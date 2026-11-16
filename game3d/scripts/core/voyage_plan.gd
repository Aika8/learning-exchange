## A voyage plan checked by Mara (Орден Якоря): long only in the slice; entry, Anchor (stop-loss) and size.
## Risk = loss if the Anchor fills at its price, fees on both legs included; Mara allows at most 1% of the trading
## capital (treasury minus provisions). Money is integer minor units; division rounds toward zero.
class_name VoyagePlan
extends RefCounted

const LIMIT_BPS := 100  ## 1%

var instrument := "SILK-SPARK"
var entry := 0  ## planned entry price, quote minor units per unit
var stop := 0  ## the Anchor
var qty := 0
var capital := 0  ## trading capital, quote minor units
var fee_bps := 10


func budget() -> int:
	@warning_ignore("integer_division")
	return capital * LIMIT_BPS / 10000


## Loss in quote minor units if bought at `entry` and sold at `stop`, both fees included.
func risk_for(q: int) -> int:
	if q <= 0 or stop <= 0 or stop >= entry:
		return 0
	return (entry - stop) * q + Money.fee(entry * q, fee_bps) + Money.fee(stop * q, fee_bps)


func risk() -> int:
	return risk_for(qty)


## Risk as a share of capital, basis points.
func risk_bps() -> int:
	if capital <= 0:
		return 0
	@warning_ignore("integer_division")
	return risk() * 10000 / capital


## Largest size whose risk fits the 1% budget.
func max_qty() -> int:
	if stop <= 0 or stop >= entry or capital <= 0:
		return 0
	@warning_ignore("integer_division")
	var q := budget() / (entry - stop)
	while q > 0 and risk_for(q) > budget():
		q -= 1
	return q


## Mara's verdict: empty array = approved; otherwise refusal keys, most important first.
func check() -> Array[String]:
	var out: Array[String] = []
	if capital <= 0:
		out.append("MARA_NO_CAPITAL")
	if stop <= 0:
		out.append("MARA_NO_ANCHOR")
	elif stop >= entry:
		out.append("MARA_ANCHOR_ABOVE")
	if qty <= 0:
		out.append("MARA_NO_QTY")
	elif out.is_empty() and risk() > budget():
		out.append("MARA_TOO_MUCH_RISK")
	return out


## Mara puts the Anchor two waves (2 × ATR) under the entry (M2c); without ATR, 2% under.
static func suggest_stop(entry_price: int, atr: int) -> int:
	if atr > 0:
		return maxi(1, entry_price - 2 * atr)
	@warning_ignore("integer_division")
	return maxi(1, entry_price - entry_price / 50)


## Limit price of the stop-limit order the Anchor becomes: a quarter of the stop distance lower, so a small slip still
## fills but a gap through it leaves the order hanging out of the market (world bible, Act III).
func anchor_limit() -> int:
	@warning_ignore("integer_division")
	return maxi(1, stop - maxi(1, (entry - stop) / 4))


func to_dict() -> Dictionary:
	return {"instrument": instrument, "entry": entry, "stop": stop, "qty": qty, "capital": capital, "feeBps": fee_bps, "risk": risk()}


static func from_dict(d: Dictionary) -> VoyagePlan:
	var p := VoyagePlan.new()
	p.instrument = str(d.get("instrument", "SILK-SPARK"))
	p.entry = int(d.get("entry", 0))
	p.stop = int(d.get("stop", 0))
	p.qty = int(d.get("qty", 0))
	p.capital = int(d.get("capital", 0))
	p.fee_bps = int(d.get("feeBps", 10))
	return p
