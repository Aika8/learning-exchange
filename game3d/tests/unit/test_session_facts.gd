## ADR-0013/0023: SessionFacts are a fold over the day dl — R per voyage, expectancy, fees and spread, gaps through the
## Anchor, the basket, lessons; the replay is the same fold over a prefix.
extends GutTest


func _day() -> DayLog:
	var dl := DayLog.new()
	dl.append("DAY_START", 0, {"capital": 10000000, "basket": 10000})
	dl.append("LESSON", 1, {"id": "SPREAD"})
	# voyage 1: SILK 100 → 103, risk 219.80
	dl.append("PLAN", 2, {"instrument": "SILK-SPARK", "entry": 10000, "stop": 9800, "qty": 100, "risk": 21980})
	dl.append("FILL", 3, {"instrument": "SILK-SPARK", "side": "BUY", "price": 10010, "qty": 100, "fee": 1001, "spread": 500}, "f1")
	dl.append("FILL", 4, {"instrument": "SILK-SPARK", "side": "SELL", "price": 10300, "qty": 100, "fee": 1030, "spread": 400}, "f2")
	# voyage 2: FORGE, the Anchor fires through a gap
	dl.append("PLAN", 5, {"instrument": "FORGE-SPARK", "entry": 25000, "stop": 24000, "qty": 20, "risk": 20000})
	dl.append("FILL", 6, {"instrument": "FORGE-SPARK", "side": "BUY", "price": 25000, "qty": 20, "fee": 500, "spread": 100}, "f3")
	dl.append("STORM", 7)
	dl.append("STOP_FIRED", 8, {"instrument": "FORGE-SPARK", "trigger": 24000, "limit": 23750, "trade": 22000, "qty": 20, "filled": 0})
	dl.append("MARK", 9, {"instrument": "FORGE-SPARK", "price": 22000})
	dl.append("BASKET", 10, {"price": 10100})
	dl.append("LESSON", 11, {"id": "GAP"})
	dl.append("LESSON", 12, {"id": "SPREAD"})
	return dl


func test_r_per_voyage_and_expectancy() -> void:
	var f := SessionFacts.from_events(_day().events)
	var t := f.traded()
	assert_eq(t.size(), 2)
	# voyage 1: −1 001 000 − 1001 + 1 030 000 − 1030 = 26 968 → 26 968 / 21 980 = 1.22 R
	assert_eq(t[0]["pnl"], 26969)
	assert_eq(t[0]["r_x100"], 122)
	assert_false(t[0]["open"])
	# voyage 2 open, marked at 220.00: −500 500 + 440 000 = −60 500 → −3.02 R (the gap made it worse than −1 R)
	assert_eq(t[1]["pnl"], -60500)
	assert_eq(t[1]["r_x100"], -302)
	assert_true(t[1]["open"])
	assert_eq(f.expectancy_x100, (122 - 302) / 2)
	assert_eq(f.wins, 1)


func test_costs_are_summed_from_fills() -> void:
	var f := SessionFacts.from_events(_day().events)
	assert_eq(f.fees, 1001 + 1030 + 500)
	assert_eq(f.spread, 1000)
	assert_eq(f.costs(), 3531)


func test_gap_through_the_anchor_is_recorded() -> void:
	var f := SessionFacts.from_events(_day().events)
	assert_eq(f.stops_fired, 1)
	assert_eq(f.gaps.size(), 1)
	assert_true(f.gaps[0]["through"], "trade 220 is under the limit 237.50")
	assert_eq(f.gaps[0]["slip"], (24000 - 22000) * 20)


func test_basket_comparison() -> void:
	var f := SessionFacts.from_events(_day().events)
	assert_eq(f.basket_bps(), 100)  # 100.00 → 101.00
	assert_eq(f.basket_pnl(), 100000)  # 1% of 100 000.00
	assert_eq(f.pnl, 26969 - 60500)
	assert_eq(f.return_bps(), (26969 - 60500) * 10000 / 10000000)


func test_lessons_once_each_in_order() -> void:
	var f := SessionFacts.from_events(_day().events)
	assert_eq(f.lessons, ["SPREAD", "GAP"] as Array[String])
	assert_eq(f.storms, 1)


func test_replay_prefix_is_the_same_fold() -> void:
	var dl := _day()
	var half := SessionFacts.from_events(dl.upto(5))
	assert_eq(half.traded().size(), 1)
	assert_eq(half.traded()[0]["pnl"], 26969, "after the sell, voyage 1 is already closed")
	assert_eq(half.gaps.size(), 0)
	var all := SessionFacts.from_events(dl.upto(dl.size()))
	assert_eq(all.pnl, SessionFacts.from_events(dl.events).pnl)


func test_fills_are_idempotent_by_key() -> void:
	var dl := _day()
	var n := dl.size()
	assert_false(dl.append("FILL", 99, {"instrument": "SILK-SPARK", "side": "BUY", "price": 1, "qty": 1}, "f1"))
	assert_eq(dl.size(), n)


func test_day_log_survives_json_with_integers() -> void:
	var dl := _day()
	dl.append("NOTE", 1794805974331, {"big": 1794805974331})
	var back := DayLog.from_json(dl.to_json())
	assert_eq(back.size(), dl.size())
	assert_typeof(back.events[-1]["t"], TYPE_INT)
	assert_eq(back.events[-1]["data"]["big"], 1794805974331)
	assert_eq(SessionFacts.from_events(back.events).pnl, SessionFacts.from_events(dl.events).pnl)
	assert_false(back.append("FILL", 1, {}, "f2"), "keys are restored too")


func test_planned_but_not_traded_is_not_a_voyage() -> void:
	var dl := DayLog.new()
	dl.append("DAY_START", 0, {"capital": 100000})
	dl.append("PLAN", 1, {"instrument": "SILK-SPARK", "entry": 100, "stop": 90, "qty": 1, "risk": 10})
	var f := SessionFacts.from_events(dl.events)
	assert_eq(f.traded().size(), 0)
	assert_eq(f.expectancy_x100, 0)
