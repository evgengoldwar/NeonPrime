extends Node
## Снимает скриншоты всех экранов в типичных состояниях (для проверки интерфейса).
## Запуск (нужна отрисовка): xvfb-run godot --path . --resolution 720x1280 res://tools/ui_shots.tscn -- out=/путь
## Пишет в сохранение — не запускать вместе с другими тестами.

var main
var out := "user://shots"


func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("out="):
			out = a.substr(4)
	DirAccess.make_dir_recursive_absolute(out)
	Game.reset_progress()
	Game.meta.tutorial_done = true
	Game.meta.gold = 640
	Game.meta.gems = 35
	Game.meta.souls = 120
	Game.meta.notoriety_max = 2
	for m in Data.master_list:
		Game.meta.notoriety_by[m.id] = 2
	Game.meta.wings = ["crypt"]
	Progress.ensure()
	Progress.add_copies("bats", 6)
	Progress.add_copies("spikes", 3)
	Progress.upgrade("spikes")
	Progress.grant_chest("silver")
	Progress.grant_chest("gold")
	Progress.start_unlock(1)
	main = load("res://scenes/main.tscn").instantiate()
	add_child(main)
	await _wait(3.0)
	await _menu()
	await _run()
	get_tree().quit()


func _wait(t: float) -> void:
	await get_tree().create_timer(t).timeout


func _shot(n: String) -> void:
	await _wait(0.35)
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(out + "/" + n + ".png")


func _close_popups() -> void:
	for ch in main.screen.get_children():
		if ch is ColorRect:
			ch.queue_free()
	await get_tree().process_frame


func _menu() -> void:
	main.goto("menu")
	await _shot("01_home")
	main.screen._slot_tap(2)
	await _shot("02_chest_popup")
	await _close_popups()
	for t in ["deck", "shop", "castle", "trophies"]:
		main.screen._show(t)
		await _shot("03_tab_" + t)
	main.screen._show("deck")
	main.screen.card_detail("bats")
	await _shot("04_card_detail")
	main.goto("menu")
	await get_tree().process_frame
	main.screen._slot_tap(0)
	await _wait(0.3)
	await _shot("05_chest_closed")
	main.screen._next()
	await _shot("06_chest_gold")
	main.screen._next()
	await _shot("07_chest_card")
	main.screen._summary()
	await _shot("08_chest_summary")
	for s in ["settings", "daily"]:
		main.goto(s)
		await _shot("09_" + s)


func _run() -> void:
	Game.new_run("dark_lord", 0)
	main.goto(Game.run.screen)
	await _shot("10_location")
	main.screen._choose(Game.run.location_options[0])
	await get_tree().process_frame
	main.goto(Game.run.screen)
	await _shot("11_map")
	Game.start_battle("battle", 0)
	main.goto("battle")
	await _wait(0.5)
	await _shot("12_battle_prep")
	var b = Game.battle
	var scr = main.screen
	for h in range(b.hand.size() - 1, -1, -1):
		for c in b.corridor_len:
			if h < b.hand.size() and b.cells[c] == null and b.can_place(h, c):
				scr._cell_drop(Vector2.ZERO, {"from": "hand", "idx": h}, c)
				break
	scr.selected = 0 if b.hand.size() > 0 else -1
	scr._refresh()
	await _shot("13_battle_placed")
	scr._launch()
	for i in 6:
		scr._do_tick()
	await _shot("14_battle_walk")
	scr._show_hero(int(b.heroes[0].uid))
	await _shot("15_hero_popup")
	await _close_popups()
	var RunMenus = load("res://scripts/ui/run_menus.gd")
	RunMenus.pause(scr)
	await _shot("16_pause")
	await _close_popups()
	RunMenus.rules(scr)
	await _shot("17_rules")
	await _close_popups()
	var guard := 0
	while b.phase != "done" and guard < 20:
		guard += 1
		if b.phase == "prep":
			scr._launch()
		scr._skip()
	Game.battle_finished()
	await _wait(0.5)
	await _shot("18_after_battle_" + str(Game.run.get("screen", "")))
	Game.pending = Game.gen_reward("boss")
	Game.run.screen = "reward"
	main.goto("reward")
	await _shot("19_reward_relic")
	main.screen._sel_relic = Game.pending.relics[0]
	main.screen._take_relic()
	await _shot("20_reward_card")
	Game.pending = Game.gen_shop()
	Game.run.screen = "shop"
	main.goto("shop")
	await _shot("21_shop")
	Game.run.screen = "altar"
	main.goto("altar")
	await _shot("22_altar")
	Game.pending = {"event": "witch"}
	Game.run.screen = "event"
	main.goto("event")
	await _shot("23_event")
	Game.pending = {"kind": "treasure", "gold": 120, "relic": ""}
	Game.run.screen = "treasure"
	main.goto("treasure")
	await _shot("24_treasure")
	Game.run.treasury = 1450
	Game.run.kills_count = 9
	Game.end_run(true)
	await _shot("25_results")
