## Mara's check: risk ≤ 1% of the trading capital with fees on both legs, the Anchor below the entry.
extends GutTest


func _plan(entry: int, stop: int, qty: int, capital: int = 10000000) -> VoyagePlan:
	var p := VoyagePlan.new()
	p.entry = entry
	p.stop = stop
	p.qty = qty
	p.capital = capital
	return p


func test_risk_includes_both_fees() -> void:
	var p := _plan(10000, 9800, 100)  # 100.00 → 98.00, 100 units
	# 2.00 × 100 = 200.00 + fee 10.00 (0.1% of 10 000.00) + fee 9.80 = 219.80
	assert_eq(p.risk(), 20000 + 1000 + 980)
	assert_eq(p.budget(), 100000)  # 1% of 100 000.00
	assert_eq(p.risk_bps(), 21)


func test_max_qty_fits_the_budget_and_one_more_does_not() -> void:
	var p := _plan(10000, 9800, 0)
	var q := p.max_qty()
	assert_gt(q, 0)
	assert_true(p.risk_for(q) <= p.budget())
	assert_true(p.risk_for(q + 1) > p.budget())


func test_mara_approves_within_one_percent() -> void:
	var p := _plan(10000, 9800, 400)
	assert_eq(p.check(), [] as Array[String])


func test_mara_refuses_too_much_risk() -> void:
	var p := _plan(10000, 9800, 5000)
	assert_eq(p.check(), ["MARA_TOO_MUCH_RISK"] as Array[String])


func test_mara_refuses_no_anchor_or_anchor_above_entry() -> void:
	assert_has(_plan(10000, 0, 10).check(), "MARA_NO_ANCHOR")
	assert_has(_plan(10000, 10100, 10).check(), "MARA_ANCHOR_ABOVE")
	assert_has(_plan(10000, 9800, 0).check(), "MARA_NO_QTY")


func test_suggested_stop_is_two_waves_under() -> void:
	assert_eq(VoyagePlan.suggest_stop(10000, 60), 9880)
	assert_eq(VoyagePlan.suggest_stop(10000, 0), 9800, "2% without ATR")


func test_anchor_limit_sits_a_quarter_of_the_distance_lower() -> void:
	var p := _plan(10000, 9800, 10)
	assert_eq(p.anchor_limit(), 9750)


func test_round_trip() -> void:
	var p := VoyagePlan.from_dict(_plan(24900, 24400, 30).to_dict())
	assert_eq([p.entry, p.stop, p.qty, p.capital], [24900, 24400, 30, 10000000])
