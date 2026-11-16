## Pattern: Event Sourcing (client-side) — one game day as an append-only list of events. The evening review and the
## replay are folds over it (SessionFacts). Money facts are copied from the exchange, keyed so a re-sync adds nothing
## twice (Idempotency key). See docs/adr/0023-game3d-day-loop-and-client-session-facts.md
class_name DayLog
extends RefCounted

## Event kinds. Data fields per kind are documented in SessionFacts.apply().
const KINDS := [
	"DAY_START", "STATE", "LESSON", "PLAN", "FILL", "ANCHOR", "STOP_FIRED", "MARK", "BASKET",
	"VOYAGE_START", "VOYAGE_END", "STORM", "REPORT", "NOTE",
]

var day := 1
var events: Array[Dictionary] = []
var _keys: Dictionary = {}


## Appends an event at sim time `t`. A non-empty `key` already seen makes it a no-op; returns whether it was added.
func append(kind: String, t: int, data: Dictionary = {}, key: String = "") -> bool:
	assert(kind in KINDS, "unknown day-log kind " + kind)
	if not key.is_empty():
		if _keys.has(key):
			return false
		_keys[key] = true
	events.append({"seq": events.size() + 1, "t": t, "kind": kind, "key": key, "data": data})
	return true


func size() -> int:
	return events.size()


## The first `n` events (the replay's cursor).
func upto(n: int) -> Array[Dictionary]:
	return events.slice(0, clampi(n, 0, events.size()))


func last_of(kind: String) -> Dictionary:
	for i in range(events.size() - 1, -1, -1):
		if events[i]["kind"] == kind:
			return events[i]
	return {}


func to_json() -> String:
	return JSON.stringify({"day": day, "events": events})


static func from_json(text: String) -> DayLog:
	var log := DayLog.new()
	var parsed: Variant = JSON.parse_string(text)
	if not parsed is Dictionary:
		return log
	log.day = int(parsed.get("day", 1))
	for e: Variant in parsed.get("events", []):
		if e is Dictionary:
			var d: Dictionary = e
			# JSON numbers come back as floats; money and time are ints again here
			log.append(str(d["kind"]), int(d["t"]), _ints(d.get("data", {})), str(d.get("key", "")))
	return log


static func _ints(v: Variant) -> Variant:
	if v is float and v == floorf(v):
		return int(v)
	if v is Dictionary:
		var out: Dictionary = {}
		for k: Variant in v:
			out[k] = _ints(v[k])
		return out
	if v is Array:
		var a: Array = []
		for x: Variant in v:
			a.append(_ints(x))
		return a
	return v
