## The one next thing to do, read from the game's state (intent/04-guide-the-player.md): a pure function of the
## GameFlow state and its guard facts, so the chain of goals cannot break the way a script could.
## A goal is {id, hint_key, place, action}: `place` is a spot of Spark Harbour (harbour.gd HARBOUR_SPOTS), `action`
## the GameFlow.State the goal leads to, or NONE when the goal is done inside the current state.
class_name Goals
extends RefCounted

const NONE := -1

## Goal ids; `id` in a goal is the name (Id.keys()). An enum, not string literals: test_i18n reads quoted
## "PLAN_…" strings in scripts as translation keys.
enum Id { BUY_PROVISIONS, PLAN_WITH_MARA, FIRST_ORDER, SET_ANCHOR, SAIL_OR_STAY, READ_CHRONICLE, NEW_DAY, EXPLORE }

static var IDS: Array = Id.keys()

## Spark Harbour spots the goals point at — the keys of harbour.gd HARBOUR_SPOTS (the Ladder is in the exchange hall).
const PLACES := ["provisions", "mara", "exchange", "ship", "chronicler", "ferry"]

const _S := GameFlow.State


## ctx: the guard facts of GameFlow.refusal (cushion, approved, holding, anchored) plus day (1 = the first day) and
## traded_today. Missing facts count as false / day 1.
static func next(state: int, ctx: Dictionary) -> Dictionary:
	var cushion: bool = ctx.get("cushion", false)
	var approved: bool = ctx.get("approved", false)
	var exposed: bool = ctx.get("holding", false) and not ctx.get("anchored", false)
	var traded: bool = ctx.get("traded_today", false)
	var first_day: bool = int(ctx.get("day", 1)) <= 1
	match state:
		_S.PORT:
			if not cushion:
				return _goal(Id.BUY_PROVISIONS, "provisions", NONE)
			if not approved:
				return _goal(Id.PLAN_WITH_MARA, "mara", _S.PLAN)
			if exposed:
				return _goal(Id.SET_ANCHOR, "exchange", _S.TRADING)
			if traded:
				return _goal(Id.READ_CHRONICLE, "chronicler", _S.CHRONICLE)
			if first_day:
				return _goal(Id.FIRST_ORDER, "exchange", _S.TRADING)
			return _goal(Id.EXPLORE, "ferry", NONE)
		_S.PLAN:
			if not approved:
				return _goal(Id.PLAN_WITH_MARA, "mara", NONE)
			return _goal(Id.FIRST_ORDER, "exchange", _S.TRADING)
		_S.TRADING:
			if exposed:
				return _goal(Id.SET_ANCHOR, "exchange", NONE)
			if not traded and first_day:
				return _goal(Id.FIRST_ORDER, "exchange", NONE)
			return _goal(Id.SAIL_OR_STAY, "ship", _S.SAILING)
		_S.SAILING:
			return _goal(Id.SAIL_OR_STAY, "ship", _S.PORT)
		_S.CHRONICLE:
			return _goal(Id.NEW_DAY, "chronicler", _S.PORT)
	push_error("Goals.next: unknown state %d" % state)
	return _goal(Id.EXPLORE, "ferry", NONE)


static func _goal(goal: Id, place: String, action: int) -> Dictionary:
	var id: String = Id.keys()[goal]
	return {"id": id, "hint_key": "GOAL_" + id, "place": place, "action": action}
