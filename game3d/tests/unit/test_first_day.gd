## intent/04-guide-the-player.md: following only the goals, a new player gets through the first day to the evening
## chronicle — the chain is walked step by step, the way the hint would lead them.
extends GutTest

const S := GameFlow.State
const MAX_STEPS := 10
const MAX_REPEATS := 2


## What doing a goal that stays in the current state changes in the guard facts.
func _apply(goal_id: String, ctx: Dictionary) -> void:
	match goal_id:
		"BUY_PROVISIONS":
			ctx["cushion"] = true
		"PLAN_WITH_MARA":
			ctx["approved"] = true
		"FIRST_ORDER":
			ctx["traded_today"] = true
			ctx["holding"] = true
		"SET_ANCHOR":
			ctx["anchored"] = true
		_:
			fail_test("goal %s has no action and no effect" % goal_id)


func _walk_first_day() -> Dictionary:
	var flow := GameFlow.new()
	var ctx := {"day": 1}
	var trace: Array = []
	var counts := {}
	while flow.state != S.CHRONICLE and trace.size() < MAX_STEPS:
		var g := Goals.next(flow.state, ctx)
		var id: String = g["id"]
		trace.append("%s:%s" % [GameFlow.name_of(flow.state), id])
		counts[id] = int(counts.get(id, 0)) + 1
		var action := int(g["action"])
		if action == Goals.NONE:
			_apply(id, ctx)
		else:
			var why := flow.go(action as GameFlow.State, ctx)
			assert_eq(why, "", "refused %s → %s; trace %s" % [id, GameFlow.name_of(action), trace])
			if not why.is_empty():
				break
	return {"flow": flow, "trace": trace, "counts": counts}


func test_first_day_reaches_the_chronicle() -> void:
	var run := _walk_first_day()
	var flow: GameFlow = run["flow"]
	assert_eq(flow.state, S.CHRONICLE, "trace %s" % [run["trace"]])
	assert_lte((run["trace"] as Array).size(), MAX_STEPS, "trace %s" % [run["trace"]])


func test_no_goal_repeats_more_than_twice() -> void:
	var run := _walk_first_day()
	var counts: Dictionary = run["counts"]
	for id: String in counts:
		assert_lte(int(counts[id]), MAX_REPEATS, "%s ×%d; trace %s" % [id, counts[id], run["trace"]])


func test_first_day_passes_every_station() -> void:
	var run := _walk_first_day()
	var flow: GameFlow = run["flow"]
	var visited := {}
	for edge: Array in flow.history:
		visited[edge[1]] = true
	for s: int in [S.PLAN, S.TRADING, S.SAILING, S.CHRONICLE]:
		assert_has(visited, s, "%s not visited; trace %s" % [GameFlow.name_of(s), run["trace"]])
