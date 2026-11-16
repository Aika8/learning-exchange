## Game service (autoload): the day's state machine, the day daylog, the captain's glossary, the voyage plan and the
## report-season quest. Scenes ask it to move (`move`) and to record lessons (`lesson`); it talks to the exchange only
## through ExchangeApi. Money facts are copied into the day daylog by `sync()` (keyed, so idempotent).
## See docs/adr/0023-game3d-day-loop-and-client-session-facts.md
extends Node

signal flow_changed(state: int)
signal refused(key: String)
signal lesson_met(id: String, args: Array)
signal log_changed
signal report_event(kind: String, data: Dictionary)  ## kind: CONSENSUS | NIGHT | OPENED

const SAVE := "user://m3_day.json"
const BASKET := "IDX-SPARK"  ## Бабушка Ветла's basket = the index fund
const FORGE := "FORGE-SPARK"
const MONTHLY_COSTS := 500000  ## 5 000.00 ✦ a month for the crew; provisions = 6 moons

var flow := GameFlow.new()
var daylog := DayLog.new()
var glossary := CaptainGlossary.new()
var plan: VoyagePlan
var approved := false
var provisions := false
var island := "harbour"  ## harbour | silk — where the ship is
var anchor_id := -1
var anchor: Dictionary = {}
var day_start := 0  ## sim ms of DAY_START
var clock: SimClock
var report := {"phase": ReportSeason.Phase.WAITING, "season": 0, "close": 0, "company": {}}
var _syncing := false


func _ready() -> void:
	flow.changed.connect(func(_f: int, to: int) -> void: flow_changed.emit(to))
	MarketStream.clock_received.connect(func(c: SimClock) -> void: clock = c)
	if FileAccess.file_exists(SAVE) and not Session.active():
		daylog = DayLog.from_json(FileAccess.get_file_as_string(SAVE))


func now() -> int:
	return clock.at(Time.get_ticks_msec()) if clock != null else 0


func ctx() -> Dictionary:
	var f := facts()
	var holding := false
	for v in f.voyages:
		holding = holding or int(v["qty"]) > 0
	return {"cushion": provisions, "approved": approved, "holding": holding, "anchored": anchor_id > 0}


func facts(upto: int = -1) -> SessionFacts:
	return SessionFacts.from_events(daylog.events if upto < 0 else daylog.upto(upto))


## Moves the flow; on refusal tells the HUD why. Records every move in the day daylog.
func move(to: GameFlow.State) -> bool:
	var why := flow.go(to, ctx())
	if not why.is_empty():
		refused.emit(why)
		if Session.active():
			print("demo: refused ", GameFlow.name_of(to), " ", why)
		return false
	record("STATE", {"state": GameFlow.name_of(to)})
	return true


func record(kind: String, data: Dictionary = {}, key: String = "") -> void:
	if daylog.append(kind, now(), data, key):
		save()
		log_changed.emit()


func save() -> void:
	var f := FileAccess.open(SAVE, FileAccess.WRITE)
	if f != null:
		f.store_string(daylog.to_json())


## A lesson met for the first time: logged, its terms go to the glossary, the HUD shows the card. Returns false if
## already met today.
func lesson(id: String, args: Array = []) -> bool:
	if facts().lessons.has(id):
		return false
	record("LESSON", {"id": id})
	glossary.unlock_all(Lessons.terms(id))
	lesson_met.emit(id, args)
	return true


# ---------------------------------------------------------------- day

## Starts a day: clock, glossary terms, treasury, the basket price. Called after login.
func start_day() -> void:
	var c: Dictionary = await ExchangeApi.call_api(HTTPClient.METHOD_GET, "/clock")
	if c["ok"]:
		clock = SimClock.from_dict(c["data"], Time.get_ticks_msec())
	var g: Dictionary = await ExchangeApi.call_api(HTTPClient.METHOD_GET, "/bff/game/glossary")
	if g["ok"] and g["data"] is Array:
		glossary.load_terms(g["data"])
	var day := daylog.day + 1 if daylog.size() > 0 else 1
	daylog = DayLog.new()
	daylog.day = day
	flow = GameFlow.new()
	flow.changed.connect(func(_f: int, to: int) -> void: flow_changed.emit(to))
	approved = false
	plan = null
	anchor_id = -1
	anchor = {}
	day_start = now()
	record("DAY_START", {"capital": await trading_capital(), "basket": await last_price(BASKET)})
	flow_changed.emit(flow.state)


func spark() -> int:
	var me: Dictionary = await ExchangeApi.call_api(HTTPClient.METHOD_GET, "/me")
	if not me["ok"]:
		return 0
	for b: Dictionary in me["data"].get("balances", []):
		if b["asset"] == "SPARK":
			return int(b["available"]) + int(b["reserved"])
	return 0


## Treasury minus provisions (Act I): what Mara's 1% is counted from.
func trading_capital() -> int:
	var s: int = await spark()
	return maxi(0, s - (Lessons.cushion(MONTHLY_COSTS) if provisions else 0))


func last_price(instrument: String) -> int:
	var r: Dictionary = await ExchangeApi.call_api(HTTPClient.METHOD_GET, "/instruments/%s/trades?limit=1" % instrument)
	if r["ok"] and r["data"] is Array and not (r["data"] as Array).is_empty():
		return int(r["data"][0]["price"])
	return 0


func atr_of(instrument: String) -> int:
	var r: Dictionary = await ExchangeApi.call_api(HTTPClient.METHOD_GET, "/instruments/%s/atr" % instrument)
	if r["ok"] and r["data"] is Dictionary and r["data"].get("atr") != null:
		return int(r["data"]["atr"])
	return 0


func set_speed(speed: int, paused: bool = false) -> void:
	var r: Dictionary = await ExchangeApi.call_api(HTTPClient.METHOD_PUT, "/clock", {"paused": paused, "speed": speed})
	if r["ok"]:
		clock = SimClock.from_dict(r["data"], Time.get_ticks_msec())


# ---------------------------------------------------------------- plan and anchor

func approve(p: VoyagePlan) -> Array[String]:  # coroutine: await it
	var verdict := p.check()
	if not verdict.is_empty():
		record("NOTE", {"mara": verdict})
		return verdict
	await lift_anchor()
	plan = p
	approved = true
	record("PLAN", p.to_dict())
	lesson("RISK", [{"m": p.risk()}, {"bps": p.risk_bps()}])
	return verdict


## The Anchor: a stop-limit sell for what the plan bought (ADR-0008: kept by the exchange, watches the last trade).
func drop_anchor(qty: int) -> Dictionary:
	var body := {"instrument": plan.instrument, "kind": "STOP_LIMIT", "side": "SELL", "qty": qty,
		"triggerPrice": plan.stop, "limitPrice": plan.anchor_limit()}
	var key := "game-anchor-%d-%d" % [daylog.day, Time.get_ticks_usec()]
	var r: Dictionary = await ExchangeApi.call_api(HTTPClient.METHOD_POST, "/conditional-orders", body,
		PackedStringArray(["Idempotency-Key: " + key]))
	if r["ok"]:
		anchor_id = int(r["data"]["conditionalId"])
		anchor = {"instrument": plan.instrument, "trigger": plan.stop, "limit": plan.anchor_limit(), "qty": qty}
		record("ANCHOR", {"instrument": plan.instrument, "trigger": plan.stop, "limit": plan.anchor_limit(), "qty": qty})
		lesson("ANCHOR")
	return r


## Takes the Anchor up (the cargo was sold, or a new plan replaces the old one). A fired one is left as it is.
func lift_anchor() -> void:
	if anchor_id > 0:
		await ExchangeApi.call_api(HTTPClient.METHOD_DELETE, "/conditional-orders/%d" % anchor_id)
	anchor_id = -1
	anchor = {}


## A plan order with the plan's risk as the trade-journal note (M2c), so the exchange's own review sees 1 R too.
func place(body: Dictionary) -> Dictionary:
	if plan != null and str(body.get("side", "")) == "BUY":
		body["journal"] = {"why": "voyage plan, day %d" % daylog.day, "plannedRisk": maxi(1, plan.risk())}
	var r: Dictionary = await ExchangeApi.place_order(body)
	await sync()
	return r


# ---------------------------------------------------------------- sync with the exchange

## Copies the exchange's facts into the day daylog: statement trades since day start, fired anchors, marks, the basket.
func sync() -> void:
	if _syncing or day_start == 0:
		return
	_syncing = true
	var st: Dictionary = await ExchangeApi.call_api(HTTPClient.METHOD_GET, "/statement?from=%d" % day_start)
	if st["ok"] and st["data"] is Dictionary:
		var seen: Dictionary = {}
		for l: Dictionary in st["data"].get("lines", []):
			if str(l["kind"]) != "TRADE" or l.get("instrument") == null:
				continue
			# one order can fill several identical lines at once: the n-th identical line gets its own key
			var base := "st-%d-%s-%s-%d-%d" % [int(l["ts"]), str(l.get("refId")), str(l["side"]), int(l["price"]), int(l["qty"])]
			seen[base] = int(seen.get(base, 0)) + 1
			var key := "%s-%d" % [base, int(seen[base])]
			record("FILL", {"instrument": str(l["instrument"]), "side": str(l["side"]), "price": int(l["price"]),
				"qty": int(l["qty"]), "fee": int(l["fee"]), "spread": int(l["spreadPaid"])}, key)
	if anchor_id > 0:
		var c: Dictionary = await ExchangeApi.call_api(HTTPClient.METHOD_GET, "/conditional-orders")
		var mine: Dictionary = {}
		if c["ok"] and c["data"] is Array:
			for x: Dictionary in c["data"]:
				if int(x["conditionalId"]) == anchor_id:
					mine = x
		if mine.get("triggerTradePrice") != null and not mine.is_empty():
			var d: Dictionary = mine
			var fired := {"instrument": str(d["instrument"]), "trigger": int(d["triggerPrice"]), "limit": int(d["limitPrice"]),
				"trade": int(d["triggerTradePrice"]), "qty": int(d["qty"]), "filled": int(d.get("filledQty", 0)), "state": str(d["state"])}
			record("STOP_FIRED", fired, "anchor-%d" % anchor_id)
			if fired["trade"] < fired["limit"]:
				lesson("GAP", [{"p": fired["trigger"]}, {"p": fired["trade"]}])
	if plan != null:
		var p: int = await last_price(plan.instrument)
		if p > 0:
			record("MARK", {"instrument": plan.instrument, "price": p})
	var b: int = await last_price(BASKET)
	if b > 0:
		record("BASKET", {"price": b})
	_syncing = false


# ---------------------------------------------------------------- report season (Кузня, FORGE)

## Polls the company and moves the quest: consensus (Ольва Перо) → night (halted) → open with a gap.
func watch_report() -> void:
	var r: Dictionary = await ExchangeApi.call_api(HTTPClient.METHOD_GET, "/companies/" + FORGE)
	if not r["ok"] or not r["data"] is Dictionary:
		return
	var co: Dictionary = r["data"]
	if int(report["season"]) == 0 and co.get("lastReport") is Dictionary:
		report["season"] = int(co["lastReport"]["season"])  # seasons before the game started don't count
	var ph := ReportSeason.phase(co, int(report["season"]))
	var was: int = report["phase"]
	report["company"] = co
	if ph == was:
		return
	report["phase"] = ph
	match ph:
		ReportSeason.Phase.CONSENSUS:
			report_event.emit("CONSENSUS", co)
		ReportSeason.Phase.NIGHT:
			report["close"] = int(co.get("lastPrice", 0) if co.get("lastPrice") != null else 0)
			report_event.emit("NIGHT", co)
		ReportSeason.Phase.OPENED:
			var rep: Dictionary = co["lastReport"]
			report["season"] = int(rep["season"])
			var around: Array = await _trades_around(FORGE, int(rep["ts"]))
			var close: int = around[0] if around[0] > 0 else int(report["close"])
			# the open = mid of the book the market makers quote around the new fair value (an old resting order can
			# still print near yesterday's price, so the first trade is a noisy measure)
			var open: int = await _book_mid(FORGE)
			if open <= 0:
				open = around[1]
			var gap := ReportSeason.gap_bps(close, open) if close > 0 and open > 0 else 0
			var data := {"instrument": FORGE, "season": int(rep["season"]), "eps": int(rep["eps"]),
				"consensusEps": int(rep["consensusEps"]), "surpriseBps": ReportSeason.surprise_bps(int(rep["eps"]), int(rep["consensusEps"])),
				"close": close, "open": open, "gapBps": gap, "record": ReportSeason.record_kind(rep, ReportSeason.earlier(co, rep)),
				"outcome": ReportSeason.outcome(rep, ReportSeason.earlier(co, rep), gap)}
			record("REPORT", data, "report-%d" % int(rep["season"]))
			lesson("SURPRISE", [{"dbps": data["surpriseBps"]}, {"dbps": gap}])
			report_event.emit("OPENED", data)
			await sync()


func _book_mid(instrument: String) -> int:
	var r: Dictionary = await ExchangeApi.call_api(HTTPClient.METHOD_GET, "/instruments/%s/book" % instrument)
	if not r["ok"]:
		return 0
	var b := BookModel.from_snapshot(r["data"])
	@warning_ignore("integer_division")
	return (b.best_bid() + b.best_ask()) / 2 if b.best_bid() > 0 and b.best_ask() > 0 else 0


## [last price before ts, first price after ts] from the recent tape (0 when not in it).
func _trades_around(instrument: String, ts: int) -> Array:
	var r: Dictionary = await ExchangeApi.call_api(HTTPClient.METHOD_GET, "/instruments/%s/trades?limit=200" % instrument)
	var before := 0
	var after := 0
	if r["ok"] and r["data"] is Array:
		for t: Dictionary in r["data"]:  # newest first
			if int(t["ts"]) > ts:
				after = int(t["price"])
			elif before == 0:
				before = int(t["price"])
	return [before, after]
