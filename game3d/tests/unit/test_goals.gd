## intent/04-guide-the-player.md: from every state and every set of guard facts there is a next goal the player can do.
extends GutTest

const S := GameFlow.State
const HARBOUR := preload("res://scripts/harbour.gd")


func _contexts() -> Array:
	var out := []
	for bits in range(32):
		for day: int in [1, 2]:
			out.append({"cushion": bits & 1 != 0, "approved": bits & 2 != 0, "holding": bits & 4 != 0,
				"anchored": bits & 8 != 0, "traded_today": bits & 16 != 0, "day": day})
	return out


func _flow_at(state: int) -> GameFlow:
	var f := GameFlow.new()
	f.state = state as GameFlow.State
	return f


func test_never_stuck() -> void:
	var checked := 0
	for state: int in S.values():
		for ctx: Dictionary in _contexts():
			var g := Goals.next(state, ctx)
			var where := "%s %s" % [GameFlow.name_of(state), ctx]
			assert_has(Goals.IDS, g.get("id"), where)
			if int(g["action"]) != Goals.NONE:
				assert_eq(_flow_at(state).refusal(g["action"], ctx), "", "%s → %s" % [where, g["id"]])
			checked += 1
	assert_eq(checked, S.size() * 64)


func test_goal_shape() -> void:
	for state: int in S.values():
		for ctx: Dictionary in _contexts():
			var g := Goals.next(state, ctx)
			assert_eq(g["hint_key"], "GOAL_" + str(g["id"]))
			assert_has(Goals.PLACES, g["place"])
			var a := int(g["action"])
			assert_true(a == Goals.NONE or S.values().has(a), "action %d" % a)


func test_places_exist_in_spark_harbour() -> void:
	for p: String in Goals.PLACES:
		assert_has(HARBOUR.HARBOUR_SPOTS, p, p)


func test_every_goal_id_is_reachable() -> void:
	var seen := {}
	for state: int in S.values():
		for ctx: Dictionary in _contexts():
			seen[Goals.next(state, ctx)["id"]] = true
	for id: String in Goals.IDS:
		assert_has(seen, id, id)


func test_new_game_starts_with_provisions() -> void:
	var g := Goals.next(S.PORT, {"day": 1})
	assert_eq(g["id"], "BUY_PROVISIONS")
	assert_eq(g["place"], "provisions")
	assert_eq(g["action"], Goals.NONE)


func test_open_position_without_anchor_comes_first() -> void:
	var ctx := {"cushion": true, "approved": true, "holding": true, "anchored": false, "traded_today": true, "day": 1}
	assert_eq(Goals.next(S.PORT, ctx)["id"], "SET_ANCHOR")
	assert_eq(Goals.next(S.TRADING, ctx)["id"], "SET_ANCHOR")
