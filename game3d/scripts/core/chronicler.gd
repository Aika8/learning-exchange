## Pattern: Port & Adapter + Fallback — the evening chronicle narrates SessionFacts and never computes a number
## (ADR-0013). This is the port and the template adapter; the LLM adapter comes in M4 and falls back to this one.
## Lines are message keys with typed arguments, rendered at display time so ru/en switch on the fly.
## See docs/adr/0013-assistant-llm-with-fallback.md, docs/adr/0023-game3d-day-loop-and-client-session-facts.md
class_name Chronicler
extends RefCounted


## Port. Each line: {key: String, args: Array} where an arg is {m: money, minor units} | {d: signed money result} |
## {p: price} | {r: R × 100, signed} | {bps: rate} | {dbps: signed change, bps} | {t: translation key} | int | String.
func review(_facts: SessionFacts) -> Array[Dictionary]:
	return []


static func line(key: String, args: Array = []) -> Dictionary:
	return {"key": key, "args": args}


## Template adapter (no key, offline, deterministic).
class Template:
	extends Chronicler

	func review(f: SessionFacts) -> Array[Dictionary]:
		var out: Array[Dictionary] = [Chronicler.line("CHR_INTRO")]
		var traded := f.traded()
		if traded.is_empty():
			out.append(Chronicler.line("CHR_NO_TRADES"))
		for v in traded:
			out.append(Chronicler.line("CHR_VOYAGE_OPEN" if v["open"] else "CHR_VOYAGE",
				[v["n"], v["instrument"], {"d": v["pnl"]}, {"r": v["r_x100"]}, {"m": v["risk"]}]))
		if not traded.is_empty():
			out.append(Chronicler.line("CHR_EXPECTANCY", [{"r": f.expectancy_x100}, traded.size()]))
			if traded.size() < 20:
				out.append(Chronicler.line("CHR_FEW_TRADES"))
			out.append(Chronicler.line("CHR_COSTS", [{"d": -f.fees}, {"d": -f.spread}, {"d": -f.costs()}]))
		for g in f.gaps:
			out.append(Chronicler.line("CHR_GAP_THROUGH" if g["through"] else "CHR_SLIP",
				[g["instrument"], {"p": g["trigger"]}, {"p": g["trade"]}, {"d": -int(g["slip"])}]))
		if f.basket_start > 0:
			out.append(Chronicler.line("CHR_BASKET", [{"d": f.pnl}, {"dbps": f.return_bps()}, {"d": f.basket_pnl()}, {"dbps": f.basket_bps()}]))
			out.append(Chronicler.line("CHR_BASKET_AHEAD" if f.basket_pnl() > f.pnl else "CHR_BASKET_BEHIND"))
		if f.storms > 0:
			out.append(Chronicler.line("CHR_STORM", [f.storms]))
		for r in f.reports:
			out.append(Chronicler.line("CHR_REPORT", [str(r.get("instrument", "")), {"dbps": int(r.get("surpriseBps", 0))},
				{"dbps": int(r.get("gapBps", 0))}, {"t": "QUEST_OUTCOME_" + str(r.get("outcome", ReportSeason.OTHER))}]))
		for id in f.lessons:
			out.append(Chronicler.line("CHR_LESSON", [{"t": Lessons.title_key(id)}, {"t": Lessons.real_key(id)}]))
		out.append(Chronicler.line("CHR_DISCLAIMER"))
		return out


## Renders a line with the current translations (`tr` from a node) and money/price scale.
static func render(l: Dictionary, translate: Callable, locale: String, scale: int = 2) -> String:
	var parts: Array = []
	for a: Variant in l["args"]:
		parts.append(arg_text(a, translate, locale, scale))
	var fmt: String = translate.call(l["key"])
	return fmt % parts if not parts.is_empty() else fmt


static func arg_text(a: Variant, translate: Callable, locale: String, scale: int = 2) -> String:
	if a is Dictionary:
		var d: Dictionary = a
		if d.has("m"):
			return Money.format(int(d["m"]), scale, locale) + " ✦"
		if d.has("d"):
			var m := int(d["d"])
			return ("+" if m > 0 else "") + Money.format(m, scale, locale) + " ✦"
		if d.has("p"):
			return Money.format(int(d["p"]), scale, locale)
		if d.has("r"):
			var r := int(d["r"])
			return ("+" if r > 0 else "") + Money.format(r, 2, locale) + " R"
		if d.has("bps"):
			return Money.format(int(d["bps"]), 2, locale) + "%"
		if d.has("dbps"):
			var b := int(d["dbps"])
			return ("+" if b > 0 else "") + Money.format(b, 2, locale) + "%"
		if d.has("t"):
			return str(translate.call(str(d["t"])))
	return str(a)
