## Lesson sums (Act I, Act II), the report season model and the template chronicle.
extends GutTest


func test_debt_compounds() -> void:
	# 10 000.00 at 36% a year, monthly, one year → more than 36% simple interest
	var d := Lessons.debt_after(1000000, 3600, 12, 12)
	assert_gt(d, 1360000)
	assert_eq(Lessons.debt_after(1000000, 3600, 12, 0), 1000000)


func test_cushion_and_garden() -> void:
	assert_eq(Lessons.cushion(150000), 900000)
	assert_eq(Lessons.compound(100000, 1000, 2), 121000)
	assert_eq(Lessons.years_to_double_x10(1400), 51)


func test_fog_takes_purchasing_power() -> void:
	assert_eq(Lessons.after_fog(110000, 1000, 1), 100000)
	assert_eq(Lessons.real_rate_bps(1400, 1100), 300)


func test_walk_book_shows_thin_liquidity() -> void:
	var bids := [[10000, 50], [9990, 30], [9950, 100]]
	var w := Lessons.walk_book(bids, 120)
	assert_eq(w["filled"], 120)
	assert_eq(w["notional"], 50 * 10000 + 30 * 9990 + 40 * 9950)
	assert_eq(w["worst"], 9950)
	assert_eq(w["cost"], 120 * 10000 - int(w["notional"]))
	assert_eq(Lessons.walk_book(bids, 500)["filled"], 180, "the book runs out")


func test_spread() -> void:
	assert_eq(Lessons.spread(9990, 10010), {"abs": 20, "bps": 20})


func test_every_lesson_has_terms() -> void:
	for id: String in Lessons.ALL:
		assert_false(Lessons.terms(id).is_empty(), id)


func test_report_season_record_but_fell() -> void:
	var earlier := [{"season": 1, "netProfit": 900, "eps": 90, "consensusEps": 85}]
	var report := {"season": 2, "netProfit": 1000, "eps": 100, "consensusEps": 110}
	assert_true(ReportSeason.is_record(report, earlier))
	assert_eq(ReportSeason.surprise_bps(100, 110), -909)
	assert_eq(ReportSeason.outcome(report, earlier, -450), ReportSeason.RECORD_BUT_FELL)
	assert_eq(ReportSeason.outcome({"season": 2, "netProfit": 800, "eps": 120, "consensusEps": 100}, earlier, 500), ReportSeason.BEAT_ROSE)
	assert_false(ReportSeason.is_record(report, []), "the first report is not a record")
	assert_eq(ReportSeason.record_kind(report, earlier), "PROFIT")
	# FORGE season 15 of seed 42: record revenue, EPS 2.56 vs consensus 2.83
	var rev_only := {"season": 15, "revenue": 2788820226, "netProfit": 256850342, "eps": 256, "consensusEps": 283}
	var before := [{"season": 14, "revenue": 2786734188, "netProfit": 296787191}, {"season": 9, "revenue": 2622570666, "netProfit": 382108546}]
	assert_eq(ReportSeason.record_kind(rev_only, before), "REVENUE")
	assert_eq(ReportSeason.outcome(rev_only, before, -300), ReportSeason.RECORD_BUT_FELL)


func test_report_season_phases_and_gap_through_anchor() -> void:
	assert_eq(ReportSeason.phase({"tradingOpen": false}, 0), ReportSeason.Phase.NIGHT)
	assert_eq(ReportSeason.phase({"tradingOpen": true, "consensus": {"eps": 1}}, 0), ReportSeason.Phase.CONSENSUS)
	assert_eq(ReportSeason.phase({"tradingOpen": true, "lastReport": {"season": 1}}, 0), ReportSeason.Phase.OPENED)
	assert_eq(ReportSeason.phase({"tradingOpen": true, "lastReport": {"season": 1}}, 1), ReportSeason.Phase.WAITING)
	assert_eq(ReportSeason.gap_bps(25000, 23750), -500)
	assert_true(ReportSeason.through_anchor(23000, 24000, 23750))
	assert_false(ReportSeason.through_anchor(23800, 24000, 23750), "slipped but still fillable")


func test_template_chronicle_names_every_lesson_and_ends_with_the_disclaimer() -> void:
	var dl := DayLog.new()
	dl.append("DAY_START", 0, {"capital": 10000000, "basket": 10000})
	dl.append("PLAN", 1, {"instrument": "SILK-SPARK", "entry": 10000, "stop": 9800, "qty": 10, "risk": 2198})
	dl.append("FILL", 2, {"instrument": "SILK-SPARK", "side": "BUY", "price": 10000, "qty": 10, "fee": 100, "spread": 50})
	dl.append("LESSON", 3, {"id": "FEES"})
	dl.append("LESSON", 4, {"id": "ANCHOR"})
	dl.append("BASKET", 5, {"price": 10050})
	var lines := Chronicler.Template.new().review(SessionFacts.from_events(dl.events))
	var keys := lines.map(func(l: Dictionary) -> String: return l["key"])
	assert_eq(keys[0], "CHR_INTRO")
	assert_has(keys, "CHR_VOYAGE_OPEN")
	assert_has(keys, "CHR_EXPECTANCY")
	assert_has(keys, "CHR_COSTS")
	assert_has(keys, "CHR_BASKET")
	assert_eq(keys.count("CHR_LESSON"), 2)
	assert_eq(keys[-1], "CHR_DISCLAIMER")
	var lesson: Dictionary = lines.filter(func(l: Dictionary) -> bool: return l["key"] == "CHR_LESSON")[0]
	assert_eq(lesson["args"][1], {"t": "LESSON_FEES_REAL"})


func test_render_formats_money_and_r() -> void:
	var id := func(k: String) -> String: return {"K": "%s / %s / %s"}.get(k, k)
	var txt := Chronicler.render({"key": "K", "args": [{"d": -60500}, {"r": 122}, {"dbps": 100}]}, id, "en")
	assert_eq(txt, "−605.00 ✦ / +1.22 R / +1.00%")
	assert_eq(Chronicler.arg_text({"m": 500000}, id, "ru"), "5 000,00 ✦", "amounts carry no plus sign")


func test_glossary_unlocks_once_and_keeps_order() -> void:
	var g := CaptainGlossary.new()
	g.load_terms([{"id": "spread", "real": {"ru": "Спред", "en": "Spread"}, "lore": {"ru": "Пропасть", "en": "the Gap"},
		"definition": {"ru": "р", "en": "d"}}])
	watch_signals(g)
	assert_eq(g.unlock_all(["spread", "fee", "spread"]), ["spread", "fee"] as Array[String])
	assert_signal_emit_count(g, "unlocked", 2)
	var rows := g.rows("en")
	assert_eq(rows.size(), 1, "terms the server has not sent yet are skipped")
	assert_eq(rows[0]["real"], "Spread")
	assert_eq(rows[0]["lore"], "the Gap")
