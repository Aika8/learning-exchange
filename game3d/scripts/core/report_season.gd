## One report season of a Кузня workshop (world bible §5a), read from `GET /companies/{id}` (M2b CorporateEvents):
## consensus from Ольва Перо → report at night while the stock is halted → gap at the open by the surprise.
## Pure: the scene feeds it company snapshots and prices; it says what happened and which quest outcome it is.
class_name ReportSeason
extends RefCounted

enum Phase { WAITING, CONSENSUS, NIGHT, OPENED }

## Quest «Рекорд, а акция упала» outcomes.
const RECORD_BUT_FELL := "RECORD_BUT_FELL"
const BEAT_ROSE := "BEAT_ROSE"
const MISS_FELL := "MISS_FELL"
const OTHER := "OTHER"


## Surprise = (EPS − consensus) / |consensus|, bps.
static func surprise_bps(eps: int, consensus: int) -> int:
	if consensus == 0:
		return 0
	@warning_ignore("integer_division")
	return (eps - consensus) * 10000 / absi(consensus)


## Gap at the open, bps of the last close.
static func gap_bps(close: int, open: int) -> int:
	@warning_ignore("integer_division")
	return (open - close) * 10000 / close if close > 0 else 0


## A record = net profit above every earlier report (needs at least one).
static func is_record(report: Dictionary, earlier: Array) -> bool:
	if earlier.is_empty():
		return false
	for r: Dictionary in earlier:
		if int(r["netProfit"]) >= int(report["netProfit"]):
			return false
	return true


## The quest outcome from the report and the move at the open.
static func outcome(report: Dictionary, earlier: Array, gap: int) -> String:
	var s := surprise_bps(int(report["eps"]), int(report["consensusEps"]))
	if is_record(report, earlier) and gap < 0:
		return RECORD_BUT_FELL
	if s > 0 and gap > 0:
		return BEAT_ROSE
	if s < 0 and gap < 0:
		return MISS_FELL
	return OTHER


## Did the open gap through the Anchor? A stop-limit sell is skipped over when the open is below its limit price.
static func through_anchor(open: int, trigger: int, limit: int) -> bool:
	return open < trigger and open < limit


## Phase from a company snapshot (`Company` in api/openapi.yaml) and the season we last saw reported.
static func phase(company: Dictionary, seen_season: int) -> Phase:
	if not bool(company.get("tradingOpen", true)):
		return Phase.NIGHT
	var last: Variant = company.get("lastReport")
	if last is Dictionary and int(last["season"]) > seen_season:
		return Phase.OPENED
	if company.get("consensus") is Dictionary:
		return Phase.CONSENSUS
	return Phase.WAITING


## Reports before `report` (the company lists them newest or oldest first — order does not matter here).
static func earlier(company: Dictionary, report: Dictionary) -> Array:
	var out: Array = []
	for r: Dictionary in company.get("reports", []):
		if int(r["season"]) < int(report["season"]):
			out.append(r)
	return out
