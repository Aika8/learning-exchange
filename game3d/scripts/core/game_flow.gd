## Pattern: State machine — the day's loop as explicit states and guarded transitions, so no scene can skip Mara's
## check or leave port with cargo and no Anchor. See docs/adr/0011-game-engine-godot.md, docs/adr/0023-game3d-day-loop-and-client-session-facts.md
## Port → Plan voyage → Trading on the Ladder → Sailing → Evening chronicle → (next day) Port.
class_name GameFlow
extends RefCounted

signal changed(from: int, to: int)

enum State { PORT, PLAN, TRADING, SAILING, CHRONICLE }

const KEYS := ["FLOW_PORT", "FLOW_PLAN", "FLOW_TRADING", "FLOW_SAILING", "FLOW_CHRONICLE"]
const LORE_KEYS := ["FLOW_PORT_LORE", "FLOW_PLAN_LORE", "FLOW_TRADING_LORE", "FLOW_SAILING_LORE", "FLOW_CHRONICLE_LORE"]

## Allowed edges; the guards below can still refuse one.
const EDGES := {
	State.PORT: [State.PLAN, State.TRADING, State.SAILING, State.CHRONICLE],
	State.PLAN: [State.PORT, State.TRADING],
	State.TRADING: [State.PORT, State.SAILING],
	State.SAILING: [State.PORT],
	State.CHRONICLE: [State.PORT],
}

var state: State = State.PORT
var history: Array = []  ## [[from, to], …] — the replay shows it


## Guard facts the flow needs (all bools): cushion (provisions bought), approved (Mara approved the plan),
## holding (an open position), anchored (a stop protects it).
## Returns "" when the move is allowed, otherwise a refusal key for the HUD.
func refusal(to: State, ctx: Dictionary) -> String:
	if to == state:
		return "FLOW_NO_SAME"
	if not (EDGES[state] as Array).has(to):
		return "FLOW_NO_EDGE"
	match to:
		State.PLAN:
			if not ctx.get("cushion", false):
				return "FLOW_NEED_PROVISIONS"
		State.TRADING:
			if not ctx.get("approved", false):
				return "FLOW_NEED_PLAN"
		State.SAILING:
			if ctx.get("holding", false) and not ctx.get("anchored", false):
				return "FLOW_NEED_ANCHOR"
	return ""


## Moves if allowed; returns "" or the refusal key.
func go(to: State, ctx: Dictionary) -> String:
	var why := refusal(to, ctx)
	if not why.is_empty():
		return why
	var from := state
	state = to
	history.append([from, to])
	changed.emit(from, to)
	return ""


func can(to: State, ctx: Dictionary) -> bool:
	return refusal(to, ctx).is_empty()


static func name_of(s: int) -> String:
	return State.keys()[s]
