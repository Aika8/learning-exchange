## Pattern: Template method / extension — the shared stream (game/scripts/market_stream.gd) handles the socket;
## this subclass adds the `clock` channel the 2D client ignores. See docs/adr/0017-game3d-stylised-lowpoly-godot.md
extends "res://shared/market_stream.gd"

signal clock_received(clock: SimClock)


func dispatch(m: Dictionary) -> void:
	if m["kind"] == "clock" and m["data"] is Dictionary:
		clock_received.emit(SimClock.from_dict(m["data"], Time.get_ticks_msec()))
		return
	super.dispatch(m)
