## Self-run M3 demo that produces the screenshots of docs/demo/M3.md (`--demo=<dir>`). It plays one game day through
## the real scenes and the real exchange: Act I, Mara's plan, trading, the storm, Silk Reach, the Кузня report night
## with the Anchor, the evening chronicle and its replay. Not used in normal play.
class_name Demo
extends RefCounted

static var stage := 0
static var _shots := 0


static func shot(node: Node, name: String) -> void:
	_shots += 1
	await Session.shot(node, "%02d-%s" % [_shots, name])


static func close_cards(hud: GameHud) -> void:
	for i in 6:
		if not hud.is_modal():
			return
		hud._next_card()
		await Session.wait(0.2)


## Waits until `cond` is true (polled every 0.5 s) or `seconds` pass.
static func until(cond: Callable, seconds: float) -> bool:
	var t := 0.0
	while t < seconds:
		if cond.call():
			return true
		await Session.wait(0.5)
		t += 0.5
	return false


static func harbour(h: Node3D) -> void:
	var hud: GameHud = h.hud()
	stage += 1
	print("demo: harbour stage ", stage, " island ", Game.island)
	await Session.wait(2.0)
	match stage:
		1:
			Input.action_press("move_forward")
			await Session.wait(0.7)
			await shot(h, "harbour-captain-walks")
			Input.action_release("move_forward")
			await h.demo_go("debt", -PI / 2)
			await Session.wait(0.8)
			await shot(h, "act1-debt")
			await close_cards(hud)
			await h.demo_go("provisions", -PI / 2)
			await Session.wait(0.8)
			await shot(h, "act1-provisions")
			await close_cards(hud)
			await h.demo_go("garden", PI)
			await Session.wait(0.8)
			await shot(h, "act1-garden")
			await close_cards(hud)
			Locale.set_locale("en")
			await h.demo_go("fog", PI)
			await Session.wait(0.8)
			await shot(h, "act1-fog-en")
			await close_cards(hud)
			Locale.set_locale("ru")
			hud.toggle_book()
			await Session.wait(0.6)
			await shot(h, "glossary")
			hud.toggle_book()
			await h.demo_go("mara", -PI / 2)
			var plan: PlanPanel = h.plan_panel()
			await until(func() -> bool: return plan.plan.entry > 0, 10.0)
			plan.set_qty(plan.plan.max_qty() * 3)
			await plan.submit()
			await Session.wait(0.6)
			await shot(h, "mara-refuses")
			plan.fill_max()
			await plan.submit()
			await Session.wait(0.5)
			await shot(h, "mara-approves")
			await Session.wait(1.0)
			await close_cards(hud)
			await h.demo_go("exchange", PI)
		2:  # back from the hall with cargo and the Anchor
			await h.demo_go("ship", PI / 2)
		3:  # Silk Reach
			await h.demo_go("post", PI)
			await Session.wait(1.0)
			await shot(h, "silk-liquidity")
			await close_cards(hud)
			await Session.wait(0.4)
			await shot(h, "silk-post")
			await h.sell_cargo()
			await Session.wait(1.0)
			await close_cards(hud)
			await shot(h, "silk-sold")
			h._post.visible = false
			await h.demo_go("ship", -PI / 2)
		4:  # home again: the Кузня report season
			await Game.set_speed(60)
			# seed 42: FORGE misses badly in seasons 4, 8 and 10 (DECISIONS.md → M3); the demo knows it, the game does not
			for i in 4800:  # until Ольва Перо publishes the consensus of one of them (≈5 bank days before the night)
				var r: Dictionary = await ExchangeApi.call_api(HTTPClient.METHOD_GET, "/companies/" + Game.FORGE)
				var c: Variant = r["data"].get("consensus") if r["ok"] else null
				if c is Dictionary and int(c["season"]) in [4, 8, 10]:
					break
				await Session.wait(0.25)
			await Game.set_speed(1)
			print("demo: miss-season consensus")
			await close_cards(hud)
			await h.demo_go("olva", -PI * 0.2)
			await Session.wait(1.0)
			await shot(h, "olva-consensus")
			await close_cards(hud)
			Game.approved = false
			await h.demo_go("mara", -PI / 2)
			var plan: PlanPanel = h.plan_panel()
			await plan.pick(Game.FORGE)
			plan.fill_max()
			await plan.submit()
			await Session.wait(1.6)
			await close_cards(hud)
			await h.demo_go("exchange", PI)
		5:  # FORGE bought and anchored: the report night
			h.demo_view(Vector3(70, 22, 40), Vector3(0, 2, -6))
			await Game.set_speed(60)
			await until(func() -> bool: return Game.report["phase"] == ReportSeason.Phase.NIGHT, 120.0)
			await Game.set_speed(2)
			Archipelago.weather(h, 0.2, 1.0)
			await Session.wait(1.5)
			await shot(h, "report-night")
			await Game.set_speed(60)
			await until(func() -> bool: return Game.report["phase"] == ReportSeason.Phase.OPENED, 120.0)
			await Game.set_speed(1)
			Archipelago.weather(h, 0.0, 0.0)
			await Game.sync()
			await Session.wait(2.0)
			await shot(h, "report-open-gap")
			await close_cards(hud)
			await Session.wait(0.5)
			await shot(h, "anchor-through-gap")
			await close_cards(hud)
			h.demo_walk()
			await h.demo_go("chronicler", 0.6)
		6:  # next day: wait for the record-but-fell season (FORGE season 15 of seed 42)
			await Game.set_speed(60)
			await until(func() -> bool:
				var r := Game.daylog.last_of("REPORT")
				return not r.is_empty() and r["data"]["outcome"] == ReportSeason.RECORD_BUT_FELL, 1500.0)
			await Game.set_speed(1)
			await Session.wait(1.5)
			await shot(h, "quest-record-but-fell")
			print("demo: done")
			h.get_tree().quit()


static func _season(n: int) -> bool:
	var c: Variant = Game.report["company"].get("consensus")
	return c is Dictionary and int(c["season"]) >= n


static func hall(h: Node3D) -> void:
	var hud: GameHud = h.hud()
	print("demo: hall stage ", stage)
	await until(func() -> bool: return h.book().best_bid() > 0, 15.0)
	await Session.wait(1.0)
	if stage == 1:
		await shot(h, "hall-spread")
		await close_cards(hud)
	else:
		await close_cards(hud)
	await h.demo_order("BUY", "MARKET", Game.plan.qty)
	await Session.wait(1.0)
	if stage == 1:
		await shot(h, "hall-fees")
	await close_cards(hud)
	await h.demo_anchor()
	await Session.wait(0.8)
	if stage == 1:
		await shot(h, "hall-anchor")
	await close_cards(hud)
	h.demo_camera(-0.3, 13.0)
	await Session.wait(0.8)
	await shot(h, "hall-plan-realworld" if stage == 1 else "hall-forge-anchor")
	h.leave()


static func voyage(v: Node3D) -> void:
	var hud: GameHud = v.hud()
	await Session.wait(3.0)
	if stage == 2:
		await shot(v, "voyage-clock-x60")
		v.demo_progress(0.42, 0.9, -0.12, 30.0)
		await Session.wait(2.5)
		await shot(v, "storm-lesson")
		await close_cards(hud)
		await Session.wait(1.5)
		await shot(v, "storm")
	v.demo_progress(0.985, 3.6, -0.3, 34.0)
	await until(func() -> bool: return v.arrived(), 10.0)
	await Session.wait(2.0)
	if stage == 2:
		await shot(v, "silk-arrival")
	v.disembark()


static func chronicle(c: Node3D) -> void:
	await Session.wait(2.5)
	await close_cards(c.hud())
	await shot(c, "chronicle")
	Locale.set_locale("en")
	await Session.wait(0.6)
	await shot(c, "chronicle-en")
	Locale.set_locale("ru")
	c.start_replay()
	await Session.wait(0.6 * 8)
	c._playing = false
	await close_cards(c.hud())
	await Session.wait(0.4)
	await shot(c, "replay")
	c.next_day()
