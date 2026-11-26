## intent/04-guide-the-player.md: every refusal of GameFlow names the goal that removes it.
extends GutTest

const S := GameFlow.State
const FLOW_SRC := "res://scripts/core/game_flow.gd"


## The refusal keys game_flow.gd can return, read from its source so a new key cannot be forgotten here.
func _refusal_keys() -> Array:
	var src := FileAccess.get_file_as_string(FLOW_SRC)
	var re := RegEx.create_from_string("return \"(FLOW_[A-Z0-9_]+)\"")
	var out := []
	for m in re.search_all(src):
		if not out.has(m.get_string(1)):
			out.append(m.get_string(1))
	return out


func _contexts() -> Array:
	var out := []
	for bits in range(16):
		out.append({"cushion": bits & 1 != 0, "approved": bits & 2 != 0, "holding": bits & 4 != 0,
			"anchored": bits & 8 != 0})
	return out


func _flow_at(state: int) -> GameFlow:
	var f := GameFlow.new()
	f.state = state as GameFlow.State
	return f


## What doing a fact goal changes in the guard facts (same effects as test_first_day).
func _apply(goal_id: String, ctx: Dictionary) -> bool:
	match goal_id:
		"BUY_PROVISIONS":
			ctx["cushion"] = true
		"PLAN_WITH_MARA":
			ctx["approved"] = true
		"SET_ANCHOR":
			ctx["anchored"] = true
		_:
			return false
	return true


func test_source_has_the_known_keys() -> void:
	var keys := _refusal_keys()
	for k: String in ["FLOW_NEED_PROVISIONS", "FLOW_NEED_PLAN", "FLOW_NEED_ANCHOR", "FLOW_NO_EDGE", "FLOW_NO_SAME"]:
		assert_has(keys, k, k)


func test_every_refusal_key_has_a_goal() -> void:
	for k: String in _refusal_keys():
		var g := Goals.for_refusal(k)
		assert_has(Goals.IDS, g.get("id"), k)
		assert_eq(g["hint_key"], "GOAL_" + str(g["id"]), k)
		assert_has(Goals.PLACES, g["place"], k)
		var a := int(g["action"])
		assert_true(a == Goals.NONE or S.values().has(a), "%s action %d" % [k, a])


## Every refusal the flow actually gives, from every state, move and set of facts: doing the goal removes it.
func test_doing_the_goal_removes_the_refusal() -> void:
	var refusals := 0
	for from: int in S.values():
		for to: int in S.values():
			for base: Dictionary in _contexts():
				var key := _flow_at(from).refusal(to, base)
				if key.is_empty() or key == "FLOW_NO_SAME":
					continue
				refusals += 1
				var g := Goals.for_refusal(key)
				var where := "%s → %s %s: %s" % [GameFlow.name_of(from), GameFlow.name_of(to), base, g["id"]]
				var ctx := base.duplicate()
				var action := int(g["action"])
				if action == Goals.NONE:
					assert_true(_apply(g["id"], ctx), "goal has no effect: " + where)
					assert_ne(_flow_at(from).refusal(to, ctx), key, where)
				else:
					var flow := _flow_at(from)
					assert_eq(flow.go(action as GameFlow.State, ctx), "", "goal's move refused: " + where)
					assert_ne(flow.refusal(to, ctx), key, where)
	assert_gt(refusals, 0)


## A fact refusal is the only thing in the way: after the goal the move is allowed.
func test_fact_goal_makes_the_move_allowed() -> void:
	var cases := [
		[S.PORT, S.PLAN, {}],
		[S.PORT, S.TRADING, {"cushion": true}],
		[S.PLAN, S.TRADING, {"cushion": true}],
		[S.TRADING, S.SAILING, {"cushion": true, "approved": true, "holding": true}],
		[S.PORT, S.SAILING, {"holding": true}],
	]
	for c: Array in cases:
		var ctx: Dictionary = (c[2] as Dictionary).duplicate()
		var flow := _flow_at(c[0])
		var key := flow.refusal(c[1], ctx)
		assert_ne(key, "", "%s should be refused" % [c])
		assert_true(_apply(Goals.for_refusal(key)["id"], ctx), key)
		assert_eq(flow.refusal(c[1], ctx), "", "%s still refused after %s" % [c, key])


func test_no_same_has_a_goal_away_from_the_move() -> void:
	var g := Goals.for_refusal("FLOW_NO_SAME")
	assert_eq(g["action"], Goals.NONE)
	assert_has(Goals.IDS, g["id"])
