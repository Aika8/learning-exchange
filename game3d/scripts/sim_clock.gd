## Pure model of the exchange's simulation clock (api `Clock`, ADR-0006). The server pushes it only when speed or
## pause changes, so between messages the client extrapolates: now + real elapsed × speed. Times are integer ms.
class_name SimClock
extends RefCounted

var now: int = 0  ## sim ms since epoch at the moment of receipt
var paused: bool = false
var speed: int = 1
var received_at: int = 0  ## local real ms (Time.get_ticks_msec) when `now` was received


static func from_dict(data: Dictionary, local_ms: int) -> SimClock:
	var c := SimClock.new()
	c.now = int(data.get("now", 0))
	c.paused = bool(data.get("paused", false))
	c.speed = clampi(int(data.get("speed", 1)), 1, 60)
	c.received_at = local_ms
	return c


## Simulation time at local real time `local_ms`.
func at(local_ms: int) -> int:
	if paused:
		return now
	return now + maxi(0, local_ms - received_at) * speed


## "HH:MM:SS" of a sim timestamp (UTC — the exchange has no time zone of its own).
static func format_time(ms: int) -> String:
	@warning_ignore("integer_division")
	var t := Time.get_datetime_dict_from_unix_time(ms / 1000)
	return "%02d:%02d:%02d" % [t["hour"], t["minute"], t["second"]]


## Duration in ms → "1:02:05" or "02:05".
static func format_duration(ms: int) -> String:
	@warning_ignore("integer_division")
	var s := maxi(0, ms) / 1000
	@warning_ignore("integer_division")
	var h := s / 3600
	@warning_ignore("integer_division")
	var m := (s % 3600) / 60
	if h > 0:
		return "%d:%02d:%02d" % [h, m, s % 60]
	return "%02d:%02d" % [m, s % 60]
