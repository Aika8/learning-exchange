## Money is integer minor units underneath (CLAUDE.md); only formatting and parsing touch decimals, never with floats.
class_name Money
extends RefCounted


## 1234567 with scale 2 → "12 345,67" (ru) or "12,345.67" (en).
static func format(minor: int, scale: int, locale: String) -> String:
	var negative := minor < 0
	var digits := str(absi(minor)).lpad(scale + 1, "0")
	var whole := digits.substr(0, digits.length() - scale)
	var frac := digits.substr(digits.length() - scale) if scale > 0 else ""
	var group := " " if locale == "ru" else ","
	var decimal := "," if locale == "ru" else "."
	var grouped := ""
	for i in whole.length():
		if i > 0 and (whole.length() - i) % 3 == 0:
			grouped += group
		grouped += whole[i]
	return ("−" if negative else "") + grouped + ((decimal + frac) if scale > 0 else "")


## "100.5" or "100,50" with scale 2 → 10050. Returns -1 for anything that is not a positive amount.
static func parse(text: String, scale: int) -> int:
	var t := text.strip_edges().replace(" ", "").replace(",", ".")
	var re := RegEx.create_from_string("^(\\d+)(?:\\.(\\d*))?$")
	var m := re.search(t)
	if m == null:
		return -1
	var frac := m.get_string(2)
	if frac.length() > scale:
		return -1
	var all := m.get_string(1) + frac.rpad(scale, "0")
	if all.length() > 18:
		return -1
	var minor := all.to_int()
	return minor if minor > 0 else -1


## Fee in minor units, rounded down like the engine (Instrument.fee): notional × bps / 10 000.
static func fee(notional: int, fee_bps: int) -> int:
	@warning_ignore("integer_division")
	return notional * fee_bps / 10000
