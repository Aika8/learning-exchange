## LE-095: FLOW_NO_EDGE says «First go back to port» — this pins why that is always true:
## every state but PORT may go to PORT with no guard facts, and PORT itself never meets FLOW_NO_EDGE.
extends GutTest

const S := GameFlow.State


func _flow_at(s: int) -> GameFlow:
	var f := GameFlow.new()
	f.state = s
	return f


func test_every_state_but_port_may_go_back_to_port_with_an_empty_context() -> void:
	for s: int in S.values():
		if s == S.PORT:
			continue
		var f := _flow_at(s)
		assert_eq(f.refusal(S.PORT, {}), "", GameFlow.name_of(s) + " -> PORT")
		assert_eq(f.go(S.PORT, {}), "")
		assert_eq(f.state, S.PORT)


func test_from_port_no_move_is_refused_for_a_missing_edge() -> void:
	for ctx: Dictionary in [{}, {"cushion": true, "approved": true, "holding": true, "anchored": true}]:
		for to: int in S.values():
			var f := GameFlow.new()
			assert_ne(f.refusal(to, ctx), "FLOW_NO_EDGE", "PORT -> " + GameFlow.name_of(to))


func test_no_edge_refusals_only_happen_outside_port() -> void:
	for s: int in S.values():
		for to: int in S.values():
			if _flow_at(s).refusal(to, {}) == "FLOW_NO_EDGE":
				assert_ne(s, S.PORT, GameFlow.name_of(s) + " -> " + GameFlow.name_of(to))
				assert_eq(_flow_at(s).refusal(S.PORT, {}), "", "the way back from " + GameFlow.name_of(s))
