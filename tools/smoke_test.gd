extends Node
## Автотест: проходит обучение и несколько забегов через настоящие экраны.
## Запуск: godot --headless --path . res://tools/smoke_test.tscn
## Ошибки скриптов Godot печатает в stderr; в конце — сводка.

const SCREENS := ["loading", "menu", "castle", "trophies", "daily", "settings", "chest_open"]

var main
var steps := 0
var battles := 0
var runs_done := 0
var auto := true            # false — только бот, без самого теста
var floor_cb := Callable()   # вызывается на каждом шаге (для balance_sim)


func _ready() -> void:
	if not auto:
		return
	main = load("res://scenes/main.tscn").instantiate()
	get_tree().root.add_child.call_deferred(main)
	await _frames(3)
	Game.reset_progress()
	for s in SCREENS:
		main.goto(s)
		await _frames(2)
	print("SMOKE: экраны меню открылись")
	await _meta_test()
	# Обучение
	Game.start_tutorial()
	main.goto("battle")
	await _frames(2)
	await _drive(400)
	print("SMOKE: обучение пройдено, экран: ", _screen())
	# Полный прогресс, чтобы проверить всех Хозяев и все карты
	Game.meta.souls = 9999
	for w in Data.wings:
		if not w.id in Game.meta.wings:
			Game.meta.wings.append(w.id)
	for u in Data.upgrades:
		Game.meta.upgrades[u.id] = u.costs.size()
	Game.meta.notoriety_max = 10
	for s in ["castle", "trophies"]:
		main.goto(s)
		await _frames(2)
	var notoriety := [0, 5, 10, 2, 7, 0]
	for i in Data.master_list.size():
		var m: Dictionary = Data.master_list[i]
		Game.clear_run()
		Game.new_run(m.id, notoriety[i])
		main.goto(Game.run.screen)
		await _frames(2)
		await _drive(1500)
		runs_done += 1
		print("SMOKE: забег за ", m.name, " завершён, экран: ", _screen())
	Game.start_daily()
	main.goto(Game.run.screen)
	await _drive(1500)
	print("SMOKE: ежедневное подземелье завершено")
	print("SMOKE: сундуки после забегов: ", Game.meta.chests, " золото ", Game.meta.gold, " кристаллы ", Game.meta.gems)
	print("SMOKE ИТОГ: забегов %d, боёв %d, шагов %d" % [runs_done + 1, battles, steps])
	get_tree().quit()


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func _screen() -> String:
	if main.screen == null:
		return ""
	return main.screen.get_script().resource_path.get_file().get_basename()


## Ходит по экранам, пока забег не закончится.
func _drive(limit: int) -> void:
	for i in limit:
		steps += 1
		if floor_cb.is_valid() and Game.has_run():
			floor_cb.call()
		var s := _screen()
		var scr = main.screen
		match s:
			"results", "tutorial_done":
				if s == "tutorial_done":
					return
				return
			"location":
				scr._choose(Game.run.location_options[Game.rint(0, Game.run.location_options.size() - 1)])
			"relic_pick":
				scr._take(Game.pending.relics[0])
			"map":
				var avail: Array = Game.available_nodes()
				Game.enter_node(int(Game.rpick(avail)))
			"battle":
				await _battle(scr)
			"reward":
				if not Game.pending.get("relics", []).is_empty() and not Game.pending.get("relic_taken", false):
					scr._sel_relic = Game.pending.relics[0]
					scr._take_relic()
				elif Game.pending.get("cards", []).size() > 0 and Game.rchance(0.7):
					scr._sel_card = Game.pending.cards[0]
					scr._take_card()
				else:
					scr._skip()
			"shop":
				for k in Game.pending.cards.size():
					if Game.rchance(0.4):
						scr._buy_card(k)
				if Game.pending.relics.size() > 0:
					scr._buy_relic(0)
				scr._on_remove_chosen([Game.run.deck[0]])
				Game.node_done()
			"altar":
				var ups: Array = Game.upgradable_cards()
				if ups.is_empty():
					Game.node_done()
				else:
					scr._upgrade(ups[0])
			"event":
				if Game.pending.has("result"):
					Game.node_done()
				else:
					var e: Dictionary = Data.events[scr.ev_id]
					var opt: String = e.options[0].id
					for o in e.options:
						if scr._possible(scr.ev_id + ":" + o.id) and Game.rchance(0.5):
							opt = o.id
					if scr.ev_id == "mirror" and opt == "copy":
						scr._on_copy([Game.run.deck[0]])
					elif scr.ev_id == "witch" and opt == "trade":
						scr._on_trade([Game.run.deck[0], Game.run.deck[1]])
					else:
						scr._choose(opt)
			"treasure":
				Game.node_done()
			_:
				push_error("SMOKE: неожиданный экран " + s)
				return
		await _frames(1)
	push_error("SMOKE: превышен лимит шагов на экране " + _screen())


func _battle(scr) -> void:
	battles += 1
	var b = Game.battle
	var guard := 0
	while b.phase != "done" and guard < 60:
		guard += 1
		if b.phase == "prep":
			# Разыгрываем заклинания и выкладываем карты как придётся
			var placed := true
			while placed:
				placed = false
				for h in range(b.hand.size() - 1, -1, -1):
					if h >= b.hand.size():
						continue
					if b.can_play_spell(h):
						scr._play_spell(h)
						placed = true
						break
					for c in b.corridor_len:
						if b.cells[c] == null and b.can_place(h, c):
							scr._cell_drop(Vector2.ZERO, {"from": "hand", "idx": h}, c)
							placed = true
							break
					if placed:
						break
			scr._launch()
		var ticks := 0
		while b.phase == "walk" and ticks < 3000:
			ticks += 1
			if ticks % 7 == 0:
				scr._skip()
			else:
				scr._do_tick()
		if ticks >= 3000:
			push_error("SMOKE: бой завис")
			for h in b.heroes:
				printerr("  герой ", h.name, " state=", h.state, " pos=", h.pos, " hp=", h.hp, " atk=", h.atk, " slow=", h.slow, " hold=", h.hold, " tick_on=", h.tick_on, " delay=", h.delay, " trait=", h.trait, " mods=", h.mods)
			for c in b.corridor_len:
				if b.cells[c] != null:
					printerr("  клетка ", c, ": ", b.cells[c].id, " hp=", b.cells[c].hp, " atk=", b.monster_atk(c, b.heroes[0]))
			printerr("  hall=", b.hall, " len=", b.corridor_len)
			return
		await _frames(1)
	Game.battle_finished()
	await _frames(1)


## Коллекция: вкладки меню, сундуки, открытие, прокачка, замена карты в колоде.
func _meta_test() -> void:
	main.goto("menu")
	await _frames(2)
	for t in ["shop", "deck", "castle", "trophies", "home"]:
		main.screen._show(t)
		await _frames(2)
	assert(Progress.chest_state(0) == "ready", "стартовый сундук должен быть готов")
	main.screen._slot_tap(0)
	await _frames(2)
	assert(_screen() == "chest_open")
	for i in 20:
		if _screen() != "chest_open":
			break
		main.screen._next()
		await _frames(1)
	assert(_screen() == "menu", "после открытия сундука — меню")
	Game.meta.gold = 5000
	Game.meta.gems = 500
	for k in Data.prog.chest_order:
		main.goto("menu")
		await _frames(1)
		main.screen._open(Progress.buy_chest(k, 0))
		await _frames(2)
		main.screen._summary()
		await _frames(1)
	main.goto("menu")
	await _frames(2)
	var up := 0
	for id in Game.meta.collection.keys():
		while Progress.can_upgrade(id):
			Progress.upgrade(id)
			up += 1
	main.screen._show("deck")
	await _frames(2)
	var some: String = Game.meta.collection.keys()[0]
	main.screen.card_detail(some)
	await _frames(1)
	assert(Progress.grant_chest("silver") >= 0)
	var slot := -1
	for i in Game.meta.chests.size():
		if Progress.chest_state(i) == "locked":
			slot = i
	Progress.start_unlock(slot)
	main.screen._show("home")
	await _frames(2)
	main.screen._tick()
	main.screen._shop()
	Progress.buy_offer(0)
	Progress.claim_gift()
	print("SMOKE: коллекция %d карт, улучшений %d, уровень игрока %d" % [Game.meta.collection.size(), up, int(Game.meta.plevel)])
	# Уровни должны попадать в забег
	Game.clear_run()
	Game.new_run("dark_lord", 0)
	var lv := []
	for c in Game.run.deck:
		lv.append("%s@%d" % [c.id, int(c.lvl)])
	print("SMOKE: стартовая колода забега ", lv)
	Game.clear_run()


func _click() -> InputEventMouseButton:
	var e := InputEventMouseButton.new()
	e.pressed = true
	e.button_index = MOUSE_BUTTON_LEFT
	return e
