extends Node
## Балансный прогон: бот играет забеги при разных уровнях карт коллекции и печатает
## процент побед, этаж, остаток Казны (= золото для прокачки) и Души.
## Запуск: godot --headless --path . res://tools/balance_sim.tscn -- levels=1,4,8 runs=6 notoriety=0
## Не запускайте два прогона одновременно: они пишут в одно сохранение.
## Бот слабее человека: смотрите на разницу между уровнями, а не на абсолютные числа.

const Smoke := preload("res://tools/smoke_test.gd")

var main
var bot


func _ready() -> void:
	var args := {"levels": "1,4,8", "runs": "4", "notoriety": "0", "masters": ""}
	for a in OS.get_cmdline_user_args():
		var kv: PackedStringArray = a.split("=")
		if kv.size() == 2:
			args[kv[0]] = kv[1]
	main = load("res://scenes/main.tscn").instantiate()
	get_tree().root.add_child.call_deferred(main)
	await get_tree().process_frame
	await get_tree().process_frame
	bot = Smoke.new()
	bot.auto = false
	bot.main = main
	add_child(bot)
	var masters: Array = []
	for m in Data.master_list:
		if args.masters == "" or m.id in args.masters.split(","):
			masters.append(m.id)
	print("BAL: уровень | победы | ср.этаж | Казна при победе (мин–макс) | Души | убийств")
	for lv_s in args.levels.split(","):
		var lvl := int(lv_s)
		var wins := 0
		var floors := 0
		var gold := []
		var souls := 0
		var kills := 0
		var n := 0
		for mid in masters:
			for r in int(args.runs):
				_setup(lvl)
				Game.new_run(mid, int(args.notoriety))
				if args.has("verbose"):
					print("RUN ", lvl, " ", mid, " ", r, " t=", Time.get_ticks_msec() / 1000, " seed ", Game.run.seed)
				main.goto(Game.run.screen)
				await get_tree().process_frame
				var mf := {"v": 1}
				bot.floor_cb = func(): mf.v = maxi(int(mf.v), int(Game.run.get("floor", 1)))
				await bot._drive(2000)
				var max_floor := int(mf.v)
				var res: Dictionary = Game.pending
				n += 1
				floors += max_floor
				souls += int(res.get("souls", 0))
				kills += int(res.get("kills", 0))
				if res.get("won", false):
					wins += 1
					gold.append(int(res.get("treasury", 0)))
		gold.sort()
		var avg_gold := 0.0
		for g in gold:
			avg_gold += g
		avg_gold /= maxf(1.0, gold.size())
		print("BAL: ур.%d | %d/%d (%d%%) | %.2f | %.0f (%s–%s) | %.0f | %.1f" % [lvl, wins, n, 100 * wins / maxi(1, n),
			float(floors) / n, avg_gold, str(gold.front()) if gold.size() > 0 else "-", str(gold.back()) if gold.size() > 0 else "-",
			float(souls) / n, float(kills) / n])
	get_tree().quit()


## Все крылья открыты, все карты коллекции на уровне lvl.
func _setup(lvl: int) -> void:
	Game.clear_run()
	Game.meta.tutorial_done = true
	for w in Data.wings:
		if not w.id in Game.meta.wings:
			Game.meta.wings.append(w.id)
	for id in Progress.collectible_ids():
		Game.meta.collection[id] = {"lvl": lvl, "copies": 0}
	Game.meta.plevel = 1
