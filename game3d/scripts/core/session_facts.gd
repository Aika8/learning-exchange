## Pattern: Projection — SessionFacts are a pure fold over the day log (ADR-0013: numbers come from code, words from the
## chronicler). Folding only the first n events is the replay. See docs/adr/0023-game3d-day-loop-and-client-session-facts.md
## Money: quote minor units (SPARK). R × 100 and returns in basis points; integer division rounds toward zero.
class_name SessionFacts
extends RefCounted

var capital := 0  ## trading capital at the start of the day
var voyages: Array[Dictionary] = []  ## {n, instrument, risk, cash, qty, mark, fees, spread, pnl, r_x100, open}
var fees := 0
var spread := 0
var pnl := 0
var expectancy_x100 := 0  ## mean R × 100 over voyages with a risk
var wins := 0
var gaps: Array[Dictionary] = []  ## {instrument, trigger, limit, trade, qty, filled, slip}
var stops_fired := 0
var basket_start := 0  ## Бабушка Ветла's basket (IDX-SPARK) price at day start
var basket_end := 0
var lessons: Array[String] = []
var storms := 0
var voyages_sailed := 0
var reports: Array[Dictionary] = []
var marks: Dictionary = {}  ## instrument → last price


static func from_events(events: Array[Dictionary]) -> SessionFacts:
	var f := SessionFacts.new()
	for e in events:
		f.apply(e)
	f._finish()
	return f


## One event. Data per kind:
## DAY_START {capital, basket}            PLAN {instrument, entry, stop, qty, risk}
## FILL {instrument, side, price, qty, fee, spread}   ANCHOR {instrument, trigger, limit, qty}
## STOP_FIRED {instrument, trigger, limit, trade, qty, filled}   MARK {instrument, price}   BASKET {price}
## LESSON {id}   STORM {}   VOYAGE_START {from, to}   REPORT {instrument, surpriseBps, gapBps, …}
func apply(e: Dictionary) -> void:
	var d: Dictionary = e.get("data", {})
	match str(e["kind"]):
		"DAY_START":
			capital = int(d.get("capital", 0))
			basket_start = int(d.get("basket", 0))
			basket_end = basket_start
		"PLAN":
			voyages.append({"n": voyages.size() + 1, "instrument": str(d["instrument"]), "risk": int(d.get("risk", 0)),
				"cash": 0, "qty": 0, "mark": int(d.get("entry", 0)), "fees": 0, "spread": 0, "pnl": 0, "r_x100": 0, "open": false})
		"FILL":
			var v := _voyage_for(str(d["instrument"]))
			var notional := int(d["price"]) * int(d["qty"])
			var fee := int(d.get("fee", 0))
			fees += fee
			spread += int(d.get("spread", 0))
			if v.is_empty():
				return
			v["fees"] = int(v["fees"]) + fee
			v["spread"] = int(v["spread"]) + int(d.get("spread", 0))
			if str(d["side"]) == "BUY":
				v["cash"] = int(v["cash"]) - notional - fee
				v["qty"] = int(v["qty"]) + int(d["qty"])
			else:
				v["cash"] = int(v["cash"]) + notional - fee
				v["qty"] = int(v["qty"]) - int(d["qty"])
			v["mark"] = int(d["price"])
		"MARK":
			marks[str(d["instrument"])] = int(d["price"])
			for v in voyages:
				if v["instrument"] == str(d["instrument"]):
					v["mark"] = int(d["price"])
		"BASKET":
			basket_end = int(d["price"])
			if basket_start <= 0:
				basket_start = basket_end
		"STOP_FIRED":
			stops_fired += 1
			var trig := int(d["trigger"])
			var trade := int(d["trade"])
			var limit := int(d.get("limit", 0))
			# slipped: the trade that fired it was below the stop; "through" = even below the limit — a gap
			if trade < trig:
				gaps.append({"instrument": str(d["instrument"]), "trigger": trig, "limit": limit, "trade": trade,
					"qty": int(d.get("qty", 0)), "filled": int(d.get("filled", 0)), "through": limit > 0 and trade < limit,
					"slip": (trig - trade) * int(d.get("qty", 0))})
		"LESSON":
			var id := str(d["id"])
			if not lessons.has(id):
				lessons.append(id)
		"STORM":
			storms += 1
		"VOYAGE_START":
			voyages_sailed += 1
		"REPORT":
			reports.append(d)


## The voyage a fill belongs to: the latest plan for that instrument.
func _voyage_for(instrument: String) -> Dictionary:
	for i in range(voyages.size() - 1, -1, -1):
		if voyages[i]["instrument"] == instrument:
			return voyages[i]
	return {}


func _finish() -> void:
	pnl = 0
	wins = 0
	var r_sum := 0
	var counted := 0
	for v in voyages:
		v["open"] = int(v["qty"]) != 0
		v["pnl"] = int(v["cash"]) + int(v["qty"]) * int(v["mark"])
		if int(v["cash"]) == 0 and int(v["qty"]) == 0:
			continue  # planned, never traded: not a voyage in R
		pnl += int(v["pnl"])
		if int(v["risk"]) > 0:
			@warning_ignore("integer_division")
			v["r_x100"] = int(v["pnl"]) * 100 / int(v["risk"])
			r_sum += int(v["r_x100"])
			counted += 1
		if int(v["pnl"]) > 0:
			wins += 1
	@warning_ignore("integer_division")
	expectancy_x100 = r_sum / counted if counted > 0 else 0


func traded() -> Array[Dictionary]:
	return voyages.filter(func(v: Dictionary) -> bool: return int(v["cash"]) != 0 or int(v["qty"]) != 0)


## The day's result on the whole trading capital, bps.
func return_bps() -> int:
	@warning_ignore("integer_division")
	return pnl * 10000 / capital if capital > 0 else 0


## Бабушка Ветла's basket over the same day, bps.
func basket_bps() -> int:
	@warning_ignore("integer_division")
	return (basket_end - basket_start) * 10000 / basket_start if basket_start > 0 else 0


## What the same capital would have made in the basket, minor units.
func basket_pnl() -> int:
	@warning_ignore("integer_division")
	return capital * basket_bps() / 10000


## Fees and spread together, minor units — what trading cost before any price move.
func costs() -> int:
	return fees + spread
