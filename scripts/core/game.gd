extends Node
## Состояние забега и мета-прогресса, генерация этажей, наград, сохранения.

signal gold_changed(value)

const META_PATH := "user://meta.json"
const RUN_PATH := "user://run.json"
const BATTLE_SCRIPT := "res://scripts/core/battle.gd"

const NODE_WEIGHTS := {"battle": 45, "elite": 12, "shop": 12, "altar": 10, "event": 16, "treasure": 5}
const NODE_NAMES := {"battle": "Бой", "elite": "Элита", "shop": "Магазин гоблина", "altar": "Алтарь тьмы",
	"event": "Событие", "treasure": "Сокровищница", "boss": "Босс"}
const DAILY_MODS := {
	"none": "Без модификатора",
	"hp10": "Все герои +10% HP",
	"dark_first": "+1 Тьма в первом зале каждого боя",
	"cheap_shop": "Цены в магазине −20%",
	"greedy": "Все герои +2 Жадности",
}

var meta := {}
var run := {}
var rng := RandomNumberGenerator.new()
var main: Node = null
var battle = null      # текущий объект боя (Battle)
var pending := {}      # данные экрана, на который идём (награда, магазин и т.п.)


func _ready() -> void:
	load_meta()
	load_run()


# ================================================================ случайность

func rint(a: int, b: int) -> int:
	return rng.randi_range(a, b)


func rchance(p: float) -> bool:
	return rng.randf() < p


func rpick(arr: Array):
	if arr.is_empty():
		return null
	return arr[rng.randi_range(0, arr.size() - 1)]


func shuffle(arr: Array) -> void:
	for i in range(arr.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var t = arr[i]
		arr[i] = arr[j]
		arr[j] = t


func weighted(weights: Dictionary) -> String:
	var total := 0
	for k in weights.keys():
		total += int(weights[k])
	var roll := rng.randi_range(1, maxi(1, total))
	for k in weights.keys():
		roll -= int(weights[k])
		if roll <= 0:
			return k
	return weights.keys()[0]


# ================================================================ мета-прогресс

func default_meta() -> Dictionary:
	return {
		"souls": 0, "wings": [], "upgrades": {}, "trophies": {}, "notoriety_max": 0,
		"wins": 0, "runs": 0, "kills": 0, "tutorial_done": false, "achievements": [],
		"daily": {"date": "", "done": false, "best": []},
		"settings": {"sound": true, "music": true, "vibration": true, "speed": 1, "lang": "ru"},
	}


func load_meta() -> void:
	meta = default_meta()
	if FileAccess.file_exists(META_PATH):
		var f := FileAccess.open(META_PATH, FileAccess.READ)
		var d = JSON.parse_string(f.get_as_text())
		if d is Dictionary:
			d = Data.normalize(d)
			for k in d.keys():
				meta[k] = d[k]
	var defaults := default_meta()
	for k in defaults.settings.keys():
		if not meta.settings.has(k):
			meta.settings[k] = defaults.settings[k]


func save_meta() -> void:
	var f := FileAccess.open(META_PATH, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(meta))


func reset_progress() -> void:
	meta = default_meta()
	save_meta()
	clear_run()


func setting(key: String):
	return meta.settings.get(key)


func set_setting(key: String, value) -> void:
	meta.settings[key] = value
	save_meta()


func wing_unlocked(id: String) -> bool:
	return id == "" or id in meta.wings


func master_unlocked(id: String) -> bool:
	return wing_unlocked(Data.masters[id].unlock)


func upgrade_level(id: String) -> int:
	return int(meta.upgrades.get(id, 0))


func has_collection(class_id: String) -> bool:
	return meta.trophies.has(class_id) and meta.trophies.has(class_id + "_elite")


func unlock_achievement(id: String) -> void:
	if id in meta.achievements:
		return
	meta.achievements.append(id)
	save_meta()
	for a in Data.achievements:
		if a.id == id and main:
			main.toast("Достижение: " + a.name)


func record_kill(h: Dictionary) -> void:
	var key: String = h.id
	if h.get("kind", "") == "elite":
		key += "_elite"
	meta.trophies[key] = true
	meta.kills = int(meta.kills) + 1
	if int(meta.kills) >= 100:
		unlock_achievement("hundred_kills")
	run["kills_count"] = int(run.get("kills_count", 0)) + 1
	if not h.get("boss", false):
		var tr: String = Data.hero_def(h.id).get("trait", "")
		if tr != "" and not tr in run.killed_traits:
			run.killed_traits.append(tr)


# ================================================================ забег

func has_run() -> bool:
	return not run.is_empty()


func next_uid() -> int:
	run["next_uid"] = int(run.get("next_uid", 1)) + 1
	return int(run.next_uid)


func new_run(master_id: String, notoriety: int, opts: Dictionary = {}) -> void:
	battle = null
	pending = {}
	var seed_val: int = opts.get("seed", int(Time.get_unix_time_from_system() * 1000) ^ randi())
	rng.seed = seed_val
	var m: Dictionary = Data.masters[master_id]
	run = {
		"master": master_id, "notoriety": notoriety, "daily": opts.get("daily", false),
		"daily_mod": opts.get("daily_mod", "none"), "floors_total": opts.get("floors", 3),
		"seed": str(seed_val), "floor": 0, "location": "", "location_options": [],
		"map": {}, "current": -1, "treasury": 0, "souls": 0, "deck": [], "relics": [],
		"next_uid": 1, "egg_growth": 0, "dragon_hatched": false, "dragon_up": false,
		"removal_count": 0, "reroll_floor": -1, "floor_flags": {}, "next_hero_hp_mod": 0,
		"father_in": -1, "pending_curse": 0, "squire_bonus": false, "killed_traits": [],
		"stolen": [], "best_combo": 0, "kills_count": 0, "path": [], "battles_done": 0,
		"mika_stole": false, "screen": "location", "unlocked_now": [], "chosen_done": false,
	}
	var treasury: int = m.treasury + 3 * upgrade_level("deep_cellars")
	if notoriety >= 4:
		treasury -= 5
	run.treasury = treasury
	for id in m.deck:
		run.deck.append({"uid": next_uid(), "id": id, "up": false})
	if upgrade_level("dark_forge") > 0:
		var c = rpick(upgradable_cards())
		if c != null:
			c.up = true
	meta.runs = int(meta.runs) + 1
	save_meta()
	start_floor()


func clear_run() -> void:
	run = {}
	battle = null
	pending = {}
	if FileAccess.file_exists(RUN_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(RUN_PATH))


func save_run() -> void:
	if run.is_empty():
		return
	run["rng_state"] = str(rng.state)
	run["battle"] = battle.to_dict() if battle != null and battle.phase != "done" else null
	run["pending"] = pending
	var f := FileAccess.open(RUN_PATH, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(run))


func load_run() -> void:
	run = {}
	if not FileAccess.file_exists(RUN_PATH):
		return
	var f := FileAccess.open(RUN_PATH, FileAccess.READ)
	var d = JSON.parse_string(f.get_as_text())
	if not d is Dictionary:
		return
	run = Data.normalize(d)
	rng.seed = str(run.get("seed", "0")).to_int()
	rng.state = str(run.get("rng_state", "0")).to_int()
	pending = run.get("pending", {}) if run.get("pending") is Dictionary else {}
	battle = null
	if run.get("battle") is Dictionary:
		battle = load(BATTLE_SCRIPT).new()
		battle.from_dict(run.battle)


func resume_screen() -> String:
	if battle != null:
		return "battle"
	return run.get("screen", "map")


func has_relic(id: String) -> bool:
	return not run.is_empty() and id in run.get("relics", [])


func location_rule() -> String:
	if run.is_empty() or run.location == "":
		return "none"
	return Data.locations[run.location].rule


func add_gold(n: int) -> void:
	run.treasury = int(run.treasury) + n
	gold_changed.emit(run.treasury)


func add_relic(id: String) -> void:
	if id in run.relics:
		return
	run.relics.append(id)
	if id == "old_key":
		add_gold(10)


func add_card(id: String, up: bool = false) -> void:
	run.deck.append({"uid": next_uid(), "id": id, "up": up})


func remove_deck_card(uid: int) -> void:
	for i in run.deck.size():
		if int(run.deck[i].uid) == uid:
			run.deck.remove_at(i)
			return


func deck_card(uid: int):
	for c in run.deck:
		if int(c.uid) == uid:
			return c
	return null


func upgradable_cards() -> Array:
	var out := []
	for c in run.deck:
		if not c.up and Data.cards[c.id].has("up"):
			out.append(c)
	return out


func steal_card():
	if run.deck.size() <= 1:
		return null
	var c = rpick(run.deck)
	remove_deck_card(int(c.uid))
	run.stolen.append(c)
	run["mika_stole"] = true
	return c


func return_stolen() -> void:
	for c in run.stolen:
		run.deck.append(c)
	run.stolen = []


func hatch_dragon(uid: int, up: bool) -> void:
	if run.floor == 1:
		unlock_achievement("dragon_floor1")
	if uid < 0:
		run["dragon_hatched"] = true
		run["dragon_up"] = up
		return
	var c = deck_card(uid)
	if c != null:
		c.id = "dragon"
		c.up = up


func shop_price(base: int) -> int:
	var p := float(base)
	if has_relic("pact_scroll"):
		p *= 0.8
	if run.get("daily_mod", "") == "cheap_shop":
		p *= 0.8
	if int(run.notoriety) >= 3:
		p *= 1.25
	return int(ceil(p))


func removal_price() -> int:
	return shop_price(10 + 5 * int(run.removal_count))


# ================================================================ этажи и карта

func start_floor() -> void:
	run.floor = int(run.floor) + 1
	run.floor_flags = {}
	var opts := []
	for l in Data.location_list:
		if int(l.floor) == int(run.floor):
			opts.append(l.id)
	run.location_options = opts
	run.screen = "location"
	if int(run.floor) == 1 and upgrade_level("relic_chest") > 0 and not run.get("relic_chest_done", false):
		run["relic_chest_done"] = true
		var weak := []
		for r in Data.relic_list:
			if r.get("weak", false):
				weak.append(r.id)
		shuffle(weak)
		pending = {"kind": "relic_chest", "relics": weak.slice(0, 3)}
		run.screen = "relic_pick"
	save_run()


func choose_location(id: String) -> void:
	run.location = id
	run.map = gen_map()
	run.current = -1
	run.path.append({"floor": run.floor, "location": id})
	run.screen = "map"
	save_run()


func gen_map() -> Dictionary:
	var rows := []
	var nodes := []
	var nid := 0
	for r in 6:
		var count := rint(2, 4)
		var row := []
		for i in count:
			var n := {"id": nid, "row": r, "col": i, "count": count, "type": "battle", "links": [], "event": ""}
			nid += 1
			row.append(n.id)
			nodes.append(n)
		rows.append(row)
	var boss := {"id": nid, "row": 6, "col": 0, "count": 1, "type": "boss", "links": [], "event": ""}
	nodes.append(boss)
	# Связи без пересечений: узел i ряда r ведёт в отрезок узлов следующего ряда.
	for r in 5:
		var a: Array = rows[r]
		var b: Array = rows[r + 1]
		var incoming := {}
		var targets := []
		for i in a.size():
			var t := 0
			if a.size() > 1:
				t = int(round(float(i) * (b.size() - 1) / float(a.size() - 1)))
			targets.append(t)
		for i in a.size():
			var t: int = targets[i]
			nodes[a[i]].links.append(b[t])
			incoming[t] = true
			if t + 1 < b.size() and rchance(0.4) and (i + 1 >= a.size() or int(targets[i + 1]) >= t + 1):
				nodes[a[i]].links.append(b[t + 1])
				incoming[t + 1] = true
		for j in b.size():
			if incoming.has(j):
				continue
			# Сирота: подключаем к ближайшему родителю, не нарушая порядок.
			var best := 0
			for i in a.size():
				var lo := _first_link_idx(nodes, a[i], b)
				if lo <= j:
					best = i
			nodes[a[best]].links.append(b[j])
		for i in a.size():
			nodes[a[i]].links.sort()
	for id in rows[5]:
		nodes[id].links = [boss.id]
	# Типы узлов
	var weights := NODE_WEIGHTS.duplicate()
	if int(run.notoriety) >= 1:
		weights.elite = 20
	for r in 6:
		for id in rows[r]:
			var n: Dictionary = nodes[id]
			if r == 0:
				n.type = "battle"
				continue
			var w := weights.duplicate()
			if r == 5:
				w.erase("elite")
			n.type = weighted(w)
		if r == 3:
			var has_service := false
			for id in rows[r]:
				if nodes[id].type in ["shop", "altar"]:
					has_service = true
			if not has_service:
				nodes[rpick(rows[r])].type = "shop" if rchance(0.5) else "altar"
	# Два магазина подряд на одном пути не ставим.
	for n in nodes:
		if n.type == "shop":
			for l in n.links:
				if nodes[l].type == "shop":
					nodes[l].type = "battle"
	for n in nodes:
		if n.type == "event":
			n.event = rpick(Data.event_list).id
	return {"nodes": nodes, "rows": rows, "boss": boss.id}


func _first_link_idx(nodes: Array, node_id: int, row: Array) -> int:
	var links: Array = nodes[node_id].links
	if links.is_empty():
		return 999
	var lo := 999
	for l in links:
		lo = mini(lo, row.find(l))
	return lo


func available_nodes() -> Array:
	if run.map.is_empty():
		return []
	if int(run.current) < 0:
		return run.map.rows[0].duplicate()
	return run.map.nodes[int(run.current)].links.duplicate()


func map_node(id: int) -> Dictionary:
	return run.map.nodes[id]


func enter_node(id: int) -> void:
	var n := map_node(id)
	run.current = id
	n["visited"] = true
	match n.type:
		"battle", "elite", "boss":
			start_battle(n.type, int(n.row))
		"shop":
			pending = gen_shop()
			run.screen = "shop"
		"altar":
			run.screen = "altar"
		"event":
			pending = {"event": n.event}
			run.screen = "event"
		"treasure":
			if rchance(0.5):
				var g := rint(8, 15)
				add_gold(g)
				pending = {"kind": "treasure", "gold": g, "relic": ""}
			else:
				var r = random_relic()
				if r != "":
					add_relic(r)
				pending = {"kind": "treasure", "gold": 0, "relic": r}
			run.screen = "treasure"
	save_run()
	main.goto(resume_screen())


## Узел пройден: возвращаемся на карту или идём дальше.
func node_done() -> void:
	pending = {}
	if int(run.treasury) <= 0:
		end_run(false)
		return
	var n := map_node(int(run.current)) if int(run.current) >= 0 else {}
	if n.get("type", "") == "boss":
		if not run.floor_flags.get("monster_placed", false):
			unlock_achievement("no_monsters_floor")
		if int(run.floor) >= int(run.floors_total):
			if int(run.notoriety) >= 5 and not run.chosen_done and int(run.floors_total) == 3:
				run.chosen_done = true
				start_battle("chosen", 6)
				save_run()
				main.goto("battle")
				return
			end_run(true)
			return
		start_floor()
		save_run()
		main.goto(run.screen)
		return
	run.screen = "map"
	save_run()
	main.goto("map")


# ================================================================ бой

func start_battle(type: String, row: int) -> void:
	var list := make_encounter(type, row)
	battle = load(BATTLE_SCRIPT).new()
	battle.setup(list, run.deck, {"node_type": type})
	run.battles_done = int(run.battles_done) + 1
	if int(run.father_in) > 0:
		run.father_in = int(run.father_in) - 1
	run.screen = "battle"


func start_tutorial() -> void:
	new_run("dark_lord", 0, {"floors": 1})
	run["after_tutorial"] = run.screen
	run.location = "cellar"
	run.screen = "battle"
	var h := make_hero("warrior", 1, 0, {})
	h.name = "Воин-новобранец"
	h.hp = 20
	h.max_hp = 20
	h.trait = ""
	h.greed = 5
	battle = load(BATTLE_SCRIPT).new()
	battle.setup([h], [], {"tutorial": true, "node_type": "tutorial",
		"tutorial_hands": [["spikes"], ["slime", "spikes"], ["slime", "ghost", "spikes"]]})
	run["tutorial"] = true


func make_encounter(type: String, row: int) -> Array:
	var f := int(run.floor)
	var loc: Dictionary = Data.locations.get(run.location, {})
	var list := []
	if type == "boss":
		list.append(make_hero(loc.boss, f, row, {"boss": true}))
		return list
	if type == "chosen":
		list.append(make_hero("chosen", f, row, {"boss": true}))
		return list
	if int(run.father_in) == 0:
		run.father_in = -1
		var p := make_hero("paladin", f, row, {})
		p.name = "Отец-Паладин"
		p.hp = int(ceil(p.hp * 1.5))
		p.max_hp = p.hp
		list.append(p)
		return list
	var squad_ok := f >= 2 or int(run.notoriety) >= 8
	if type == "elite":
		if squad_ok and rchance(0.35):
			return make_squad(f, row)
		var mods := []
		var pool: Array = Data.elite_mods.duplicate()
		shuffle(pool)
		for i in (2 if f == 3 else 1):
			mods.append(pool[i].id)
		list.append(make_hero(random_class(), f, row, {"elite": true, "mods": mods}))
		return list
	if squad_ok and rchance(0.15):
		return make_squad(f, row)
	if not loc.is_empty() and rchance(0.4):
		list.append(make_hero(rpick(loc.locals), f, row, {}))
	else:
		list.append(make_hero(random_class(), f, row, {}))
	return list


func random_class() -> String:
	return rpick(Data.classes.keys())


func make_squad(f: int, row: int) -> Array:
	var s = rpick(Data.squads)
	var out := []
	for id in s.members:
		var h := make_hero(id, f, row, {"squad": true})
		out.append(h)
	if main:
		main.toast("Отряд: " + s.name)
	return out


func make_hero(id: String, f: int, row: int, opts: Dictionary) -> Dictionary:
	var d: Dictionary = Data.hero_def(id)
	var hp := float(d.hp)
	var greed := float(d.greed)
	var atk := int(d.atk)
	var kind: String = d.kind
	if kind == "class":
		hp *= Data.FLOOR_MULT[f - 1]
		greed *= Data.FLOOR_MULT[f - 1]
		atk += f - 1
		hp *= 1.0 + 0.05 * row
		kind = "normal"
	elif kind == "local":
		hp *= 1.0 + 0.05 * row
	if opts.get("elite", false):
		hp *= 1.3
		kind = "elite"
	var nt := int(run.get("notoriety", 0))
	if nt >= 2:
		hp *= 1.1
	if run.get("daily_mod", "") == "hp10":
		hp *= 1.1
	if nt >= 9:
		atk += 1
	var mods: Array = opts.get("mods", []).duplicate()
	if opts.get("boss", false) and nt >= 6 and id != "chosen":
		mods.append(rpick(["armored", "fearless", "antidote", "fireproof", "avenger"]))
	if "greedy" in mods:
		greed *= 2
	var h := {
		"uid": next_uid(), "id": id, "name": d.name, "kind": kind if not opts.get("boss", false) else "boss",
		"boss": opts.get("boss", false), "squad": opts.get("squad", false), "trait": d.trait,
		"hp": int(ceil(hp)), "atk": atk, "greed": int(ceil(greed)), "mods": mods, "color": d.get("color", "#cccccc"),
	}
	if id == "chosen":
		h.greed = maxi(1, int(run.treasury))
	if id == "mage" and has_collection("mage"):
		h.hp -= 2
	h.greed += int(run.floor_flags.get("greed_bonus", 0))
	if run.get("daily_mod", "") == "greedy":
		h.greed += 2
	h.hp += int(run.floor_flags.get("bard_bonus", 0))
	if int(run.next_hero_hp_mod) != 0:
		h.hp += int(run.next_hero_hp_mod)
		run.next_hero_hp_mod = 0
	if int(run.pending_curse) > 0:
		h.hp -= int(run.pending_curse)
		run.pending_curse = 0
	if id == "warrior" and run.get("squire_bonus", false):
		h.atk += 3
		run.squire_bonus = false
	h.hp = maxi(1, h.hp)
	h["max_hp"] = h.hp
	return h


## Бой закончен (вызывает экран боя).
func battle_finished() -> void:
	var b = battle
	battle = null
	run.souls = int(run.souls) + b.souls
	run.best_combo = maxi(int(run.best_combo), b.best_combo)
	if run.get("tutorial", false) and b.node_type == "tutorial":
		meta.tutorial_done = true
		save_meta()
		run.erase("tutorial")
		run.location = ""
		run.screen = run.get("after_tutorial", "location")
		save_run()
		main.goto("tutorial_done")
		return
	if b.result == "lose" or int(run.treasury) <= 0:
		end_run(false)
		return
	if b.result == "win":
		pending = gen_reward(b.node_type)
		pending["gold"] = b.gold_delta
		pending["killed"] = b.killed
		run.screen = "reward"
		save_run()
		main.goto("reward")
	else:
		pending = {}
		main.toast("Герой сбежал с золотом: %d" % b.gold_delta)
		node_done()


# ================================================================ награды

func card_pool(include_legendary: bool) -> Array:
	var out := []
	for c in Data.card_list:
		var s: String = c.set
		var ok := false
		if s == "base":
			ok = true
		elif s.begins_with("loc_"):
			ok = s == "loc_" + str(run.location)
		elif s != "special":
			ok = s in meta.wings or run.get("daily", false)
		if ok and (include_legendary or c.rarity != "legendary"):
			out.append(c.id)
	return out


func roll_cards(count: int, weights: Dictionary) -> Array:
	var pool := card_pool(true)
	var out := []
	var guard := 0
	while out.size() < count and guard < 200:
		guard += 1
		var rar := weighted(weights)
		var cand := []
		for id in pool:
			if Data.cards[id].rarity == rar and not id in out:
				cand.append(id)
		if cand.is_empty():
			continue
		out.append(rpick(cand))
	return out


func reward_weights(type: String) -> Dictionary:
	match type:
		"elite":
			return {"common": 45, "rare": 40, "epic": 15}
		"boss", "chosen":
			return {"rare": 60, "epic": 20, "legendary": 20}
	return {"common": 70, "rare": 25, "epic": 5}


func gen_reward(type: String) -> Dictionary:
	var r := {"kind": "reward", "type": type, "cards": roll_cards(3, reward_weights(type)), "relics": [], "relic": ""}
	if type == "elite":
		var rel := random_relic()
		if rel != "":
			add_relic(rel)
			r.relic = rel
	if type == "boss" or type == "chosen":
		var opts := []
		for i in 3:
			var rel := random_relic(opts)
			if rel != "":
				opts.append(rel)
		r.relics = opts
	return r


func reroll_reward() -> bool:
	if not can_reroll():
		return false
	run.reroll_floor = run.floor
	pending.cards = roll_cards(3, reward_weights(pending.get("type", "battle")))
	save_run()
	return true


func can_reroll() -> bool:
	return (has_relic("luck_bone") or upgrade_level("library") > 0) and int(run.reroll_floor) != int(run.floor)


func random_relic(exclude: Array = []) -> String:
	var cand := []
	for r in Data.relic_list:
		if r.id in run.relics or r.id in exclude:
			continue
		if r.set == "base" or r.set in meta.wings or run.get("daily", false):
			cand.append(r.id)
	if cand.is_empty():
		return ""
	return rpick(cand)


func gen_shop() -> Dictionary:
	var count := 5 + upgrade_level("goblin_market")
	var cards := roll_cards(count, {"common": 60, "rare": 28, "epic": 10, "legendary": 2})
	var items := []
	for id in cards:
		items.append({"id": id, "price": shop_price(Data.RARITY_PRICE[Data.cards[id].rarity]), "sold": false})
	var relics := []
	for i in 2:
		var r := random_relic(relics.map(func(x): return x.id))
		if r != "":
			relics.append({"id": r, "price": shop_price(rint(20, 30)), "sold": false})
	return {"kind": "shop", "cards": items, "relics": relics, "removed": false}


# ================================================================ события

func resolve_event(event_id: String, option: String) -> String:
	var text := ""
	match event_id + ":" + option:
		"lost_knight:release":
			run.next_hero_hp_mod = int(run.next_hero_hp_mod) - 5
			text = "Рыцарёнок убегает и рассказывает всем, как тут страшно. Следующий герой −5 HP."
		"lost_knight:lock":
			add_gold(10)
			run.father_in = 2
			text = "+10 золота выкупа. Через 2 боя за сыном придёт отец."
		"lost_knight:servant":
			add_card("coward_squire")
			text = "Новый слуга: Трусливый оруженосец добавлен в колоду."
		"goblin_gambler:play":
			if rchance(0.5):
				add_gold(10)
				text = "Шестёрки! Ты выиграл 10 золота."
			else:
				add_gold(-10)
				text = "Единицы... Гоблин забирает 10 золота."
		"mine_collapse:clear":
			add_gold(-5)
			text = "Камни убраны. −5 золота."
		"mine_collapse:leave":
			add_card("debris")
			add_card("debris")
			text = "В колоде появились 2 карты Обломки."
		"mirror:break":
			add_gold(-8)
			var r := random_relic()
			if r != "":
				add_relic(r)
				text = "Осколки складываются в реликвию: " + Data.relics[r].name + ". −8 золота."
			else:
				text = "Зеркало разбито. −8 золота."
		"empty_throne:sit":
			add_card("usurper_crown")
			run.floor_flags["greed_bonus"] = int(run.floor_flags.get("greed_bonus", 0)) + 2
			text = "Корона узурпатора твоя. Герои этажа стали жаднее."
		"witch:potion":
			add_gold(-12)
			var ups := upgradable_cards()
			shuffle(ups)
			var names := []
			for i in mini(2, ups.size()):
				ups[i].up = true
				names.append(Data.card_name(ups[i].id, true))
			text = "Улучшены: " + ", ".join(names)
		"rat_feast:feed":
			add_card("rat_swarm")
			text = "Крысы остаются с тобой. +1 Стая крыс."
		"rat_feast:chase":
			add_gold(4)
			text = "Под крысами нашлось 4 золота."
		"ancient_pact:sign":
			add_gold(-10)
			run.floor_flags["pact_dark"] = int(run.floor_flags.get("pact_dark", 0)) + 1
			text = "Договор подписан кровью. +1 Тьма в каждом зале до конца этажа."
		"ancient_pact:burn":
			run.souls = int(run.souls) + 2
			text = "Договор сгорает синим пламенем. +2 Души."
		_:
			text = "Ты уходишь."
	save_run()
	return text


# ================================================================ конец забега

func end_run(won: bool) -> void:
	var souls := int(run.souls)
	if won:
		souls = int(ceil(souls * 1.5))
	souls = int(ceil(souls * (1.0 + 0.1 * int(run.notoriety))))
	var unlocked := []
	if run.get("daily", false):
		souls += 20 if won else 10
		var score := maxi(0, int(run.treasury))
		meta.daily.done = true
		meta.daily.best.append({"score": score if won else 0, "time": Time.get_time_string_from_system(), "won": won})
		meta.daily.best.sort_custom(func(a, b): return a.score > b.score)
	if won:
		meta.wins = int(meta.wins) + 1
		unlock_achievement("first_win")
		if int(run.notoriety) >= int(meta.notoriety_max) and int(meta.notoriety_max) < 10:
			meta.notoriety_max = int(run.notoriety) + 1
			unlocked.append("Дурная слава: уровень %d" % int(meta.notoriety_max))
	meta.souls = int(meta.souls) + souls
	save_meta()
	pending = {
		"kind": "results", "won": won, "souls": souls, "path": run.path, "best_combo": run.best_combo,
		"kills": run.kills_count, "unlocked": unlocked, "master": run.master, "treasury": run.treasury,
		"daily": run.get("daily", false),
	}
	var res := pending
	clear_run()
	pending = res
	main.goto("results")


# ================================================================ ежедневное подземелье

func today() -> String:
	return Time.get_date_string_from_system()


func daily_info() -> Dictionary:
	var date := today()
	if meta.daily.date != date:
		meta.daily = {"date": date, "done": false, "best": []}
		save_meta()
	var seed_val := date.replace("-", "").to_int()
	var r := RandomNumberGenerator.new()
	r.seed = seed_val
	var masters: Array = Data.master_list.map(func(m): return m.id)
	var mods := DAILY_MODS.keys()
	return {"seed": seed_val, "master": masters[r.randi_range(0, masters.size() - 1)],
		"mod": mods[r.randi_range(0, mods.size() - 1)], "date": date}


func start_daily() -> void:
	var info := daily_info()
	new_run(info.master, 0, {"seed": info.seed, "daily": true, "daily_mod": info.mod})


# ================================================================ отклик

func vibrate(ms: int) -> void:
	if setting("vibration"):
		Input.vibrate_handheld(ms)
