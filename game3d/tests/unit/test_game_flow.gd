## ADR-0023: the day loop as a state machine — edges and guards.
extends GutTest

const S := GameFlow.State
const READY := {"cushion": true, "approved": true, "holding": true, "anchored": true}


func test_full_day_loop() -> void:
	var f := GameFlow.new()
	assert_eq(f.state, S.PORT)
	for to: int in [S.PLAN, S.TRADING, S.SAILING, S.PORT, S.CHRONICLE, S.PORT]:
		assert_eq(f.go(to, READY), "", "to " + GameFlow.name_of(to))
	assert_eq(f.state, S.PORT)
	assert_eq(f.history.size(), 6)
	assert_eq(f.history[0], [S.PORT, S.PLAN])


func test_no_plan_without_provisions() -> void:
	var f := GameFlow.new()
	assert_eq(f.go(S.PLAN, {"cushion": false}), "FLOW_NEED_PROVISIONS")
	assert_eq(f.state, S.PORT)


func test_mara_must_approve_before_trading() -> void:
	var f := GameFlow.new()
	f.go(S.PLAN, READY)
	assert_eq(f.go(S.TRADING, {"approved": false}), "FLOW_NEED_PLAN")
	assert_eq(f.state, S.PLAN)
	assert_eq(f.go(S.TRADING, {"approved": true}), "")


func test_port_to_trading_needs_an_approved_plan() -> void:
	var f := GameFlow.new()
	assert_eq(f.go(S.TRADING, {}), "FLOW_NEED_PLAN")
	assert_eq(f.go(S.TRADING, {"approved": true}), "")


func test_no_sailing_with_cargo_and_no_anchor() -> void:
	var f := GameFlow.new()
	f.go(S.TRADING, {"approved": true})
	assert_eq(f.go(S.SAILING, {"holding": true, "anchored": false}), "FLOW_NEED_ANCHOR")
	assert_eq(f.go(S.SAILING, {"holding": false}), "", "an empty hold may sail")


func test_edges_not_in_the_table_are_refused() -> void:
	var f := GameFlow.new()
	f.go(S.TRADING, {"approved": true})
	assert_eq(f.go(S.CHRONICLE, READY), "FLOW_NO_EDGE", "evening only from port")
	f.go(S.SAILING, READY)
	assert_eq(f.go(S.TRADING, READY), "FLOW_NO_EDGE", "no trading at sea")
	assert_eq(f.go(S.SAILING, READY), "FLOW_NO_SAME")


func test_changed_signal_fires_once_per_move() -> void:
	var f := GameFlow.new()
	watch_signals(f)
	f.go(S.CHRONICLE, {})
	f.go(S.TRADING, {})  # refused: no edge from the chronicle
	assert_signal_emit_count(f, "changed", 1)
	assert_signal_emitted_with_parameters(f, "changed", [S.PORT, S.CHRONICLE])
