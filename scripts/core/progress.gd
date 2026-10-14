extends Node
## Коллекция карт как в Clash Royale: карты открываются и прокачиваются копиями из
## сундуков и золотом (остаток Казны после забега). Всё хранится в Game.meta.
## Таблицы — в data/meta.json (Data.prog).

signal changed

var rng := RandomNumberGenerator.new()
var opening := {}          # содержимое сундука для экрана открытия


func _ready() -> void:
	rng.randomize()
	ensure()


func P() -> Dictionary:
	return Data.prog


func now() -> int:
	return int(Time.get_unix_time_from_system())


## Добавляет в meta недостающие поля (старые сохранения тоже работают).
func ensure() -> void:
	var m: Dictionary = Game.meta
	var defaults := {
		"gold": 0, "gems": 0, "xp": 0, "plevel": 1, "collection": {}, "deck": [], "decks": {},
		"chests": [], "free_chest_at": 0, "shop": {}, "master_pick": "dark_lord", "notoriety_pick": 0,
	}
	for k in defaults.keys():
		if not m.has(k):
			m[k] = defaults[k]
	if m.collection.is_empty():
		# Первый сундук — сразу готов, чтобы новичок увидел, как всё работает.
		m.chests = [{"type": "wood", "unlock_at": 1}]
	# Все обычные базовые карты есть с самого начала: из них собирают первую колоду.
	for id in P().get("starter_collection", P().starter_cards):
		if not m.collection.has(id):
			m.collection[id] = {"lvl": 1, "copies": 0}
	# Старое сохранение с одной колодой: она становится колодой выбранного Хозяина.
	if m.decks.is_empty() and m.deck.size() == int(P().deck_size):
		m.decks[str(m.master_pick)] = m.deck.duplicate()
	while m.chests.size() < int(P().slots):
		m.chests.append(null)
	for w in m.get("wings", []):
		on_wing(w, false)


func save() -> void:
	Game.save_meta()
	changed.emit()


# ================================================================ коллекция

## Карты, которые вообще можно собирать (без особых и местных карт локаций).
func collectible_ids() -> Array:
	var out := []
	for c in Data.card_list:
		var s: String = c.set
		if s != "special" and not s.begins_with("loc_"):
			out.append(c.id)
	return out


## Карты, которые могут выпасть из сундуков: базовые и из открытых крыльев Замка.
func droppable_ids() -> Array:
	var out := []
	for id in collectible_ids():
		var s: String = Data.cards[id].set
		if s == "base" or s in Game.meta.get("wings", []):
			out.append(id)
	return out


func owned(id: String) -> bool:
	return Game.meta.collection.has(id)


func level_of(id: String) -> int:
	if not owned(id):
		return 0
	return int(Game.meta.collection[id].lvl)


func copies(id: String) -> int:
	return int(Game.meta.collection[id].copies) if owned(id) else 0


func max_level() -> int:
	return int(P().max_level)


## Сколько копий нужно до следующего уровня (-1 — максимум).
func need(id: String) -> int:
	var lvl := level_of(id)
	if lvl <= 0 or lvl >= max_level():
		return -1
	var table: Array = P().copies.get(Data.cards[id].rarity, P().copies.common)
	return int(table[lvl - 1])


func gold_cost(id: String) -> int:
	var lvl := level_of(id)
	if lvl <= 0 or lvl >= max_level():
		return -1
	return int(P().gold_cost[lvl - 1])


func can_upgrade(id: String) -> bool:
	var n := need(id)
	return n > 0 and copies(id) >= n and int(Game.meta.gold) >= gold_cost(id)


func ready_to_upgrade(id: String) -> bool:
	var n := need(id)
	return n > 0 and copies(id) >= n


func upgrade(id: String) -> bool:
	if not can_upgrade(id):
		return false
	var lvl := level_of(id)
	Game.meta.gold = int(Game.meta.gold) - gold_cost(id)
	Game.meta.collection[id].copies = copies(id) - need(id)
	Game.meta.collection[id].lvl = lvl + 1
	add_xp(int(P().upgrade_xp[lvl - 1]))
	save()
	return true


## Добавить копии. Первая копия открывает карту. Возвращает true, если карта новая.
func add_copies(id: String, n: int) -> bool:
	if not owned(id):
		Game.meta.collection[id] = {"lvl": 1, "copies": n - 1}
		return true
	Game.meta.collection[id].copies = copies(id) + n
	return false


## Крыло Замка открыто: фирменная карта и карты темы из стартовой колоды Хозяина
## сразу попадают в коллекцию — новым Хозяином можно играть в его стиле с первого забега.
func on_wing(wing_id: String, notify: bool = true) -> void:
	for m in Data.master_list:
		if m.unlock != wing_id:
			continue
		var ids := [P().signature.get(m.id, "")]
		for id in m.deck:
			if Data.cards[id].set == wing_id and not id in ids:
				ids.append(id)
		var got := []
		for id in ids:
			if id != "" and not owned(id):
				add_copies(id, 1)
				got.append(Data.card_name(id))
		if notify and Game.main and not got.is_empty():
			Game.main.toast("Новые карты: " + ", ".join(got))


## Есть ли среди выпадающих карт карты этой редкости.
func has_rarity(rarity: String) -> bool:
	for id in droppable_ids():
		if Data.cards[id].rarity == rarity:
			return true
	return false


# ================================================================ колода

## У каждого Хозяина своя боевая колода: Некроманту — нежить, Алхимику — яды.
func deck(master_id: String = "") -> Array:
	if master_id == "":
		master_id = str(Game.meta.master_pick)
	var decks: Dictionary = Game.meta.decks
	if not decks.has(master_id) or decks[master_id].size() != int(P().deck_size):
		decks[master_id] = default_deck(master_id)
	return decks[master_id]


## Колода по умолчанию: найденные карты из стартовой колоды Хозяина, остальное — стартовые.
func default_deck(master_id: String) -> Array:
	var size := int(P().deck_size)
	var out := []
	var sig: String = P().signature.get(master_id, "")
	var src: Array = Data.masters.get(master_id, {}).get("deck", []).duplicate()
	src.append_array(P().starter_cards)
	src.append_array(P().get("starter_collection", []))
	for id in src:
		if out.size() < size and owned(id) and id != sig and not id in out:
			out.append(id)
	for id in Game.meta.collection.keys():
		if out.size() < size and not id in out and id != sig:
			out.append(id)
	return out


func in_deck(id: String) -> bool:
	return id in deck()


func set_deck_slot(i: int, id: String) -> void:
	var d := deck()
	if not owned(id) or i < 0 or i >= d.size():
		return
	var j: int = d.find(id)
	if j >= 0:
		d[j] = d[i]
	d[i] = id
	save()


func avg_cost() -> float:
	var d := deck()
	var total := 0
	for id in d:
		total += int(Data.cards[id].cost)
	return float(total) / maxi(1, d.size())


# ================================================================ уровень игрока

func xp_need() -> int:
	var t: Array = P().player_xp
	var lvl := int(Game.meta.plevel)
	return int(t[mini(lvl - 1, t.size() - 1)])


func add_xp(n: int) -> void:
	Game.meta.xp = int(Game.meta.xp) + n
	while int(Game.meta.xp) >= xp_need():
		Game.meta.xp = int(Game.meta.xp) - xp_need()
		Game.meta.plevel = int(Game.meta.plevel) + 1
		if Game.main:
			Game.main.toast("Уровень игрока %d! Стартовая Казна +%d" % [int(Game.meta.plevel), int(P().player_level_treasury)])


## Бонус к стартовой Казне за уровень игрока.
func treasury_bonus() -> int:
	return (int(Game.meta.plevel) - 1) * int(P().player_level_treasury)


# ================================================================ сундуки

func chest_def(type: String) -> Dictionary:
	return P().chests.get(type, P().chests.wood)


func chest_name(type: String) -> String:
	return chest_def(type).name


## Содержимое сундука: золото и стопки копий карт разной редкости.
func gen_chest(type: String) -> Dictionary:
	var d := chest_def(type)
	var gold := rng.randi_range(int(d.gold[0]), int(d.gold[1]))
	var total := int(d.cards)
	var stacks := []
	var used := []
	var order := ["legendary", "epic", "rare", "common"]
	for r in 3:
		var rar: String = order[r]
		var spec: Array = d.get(rar, [0, 0])
		if float(spec[0]) > 0 and rng.randf() < float(spec[0]):
			# Нет карт этой редкости (крылья закрыты) — даём редкостью ниже, но больше копий.
			var n := int(spec[1])
			var k := r
			var id := _pick_card(order[k], used)
			while id == "" and k < 3:
				k += 1
				n *= 3
				id = _pick_card(order[k], used)
			if id != "":
				n = mini(n, total)
				stacks.append({"id": id, "n": n})
				used.append(id)
				total -= n
	var kinds := maxi(1, int(d.kinds) - stacks.size())
	for k in kinds:
		if total <= 0:
			break
		var n := total if k == kinds - 1 else maxi(1, int(round(total / float(kinds - k) * rng.randf_range(0.7, 1.3))))
		n = mini(n, total)
		var id := _pick_card("common", used)
		if id == "":
			break
		stacks.append({"id": id, "n": n})
		used.append(id)
		total -= n
	return {"type": type, "gold": gold, "cards": stacks}


func _pick_card(rarity: String, exclude: Array) -> String:
	var cand := []
	for id in droppable_ids():
		if Data.cards[id].rarity == rarity and not id in exclude:
			cand.append(id)
	if cand.is_empty():
		return ""
	return cand[rng.randi_range(0, cand.size() - 1)]


## Положить сундук в свободный слот. -1, если слоты заняты.
func grant_chest(type: String) -> int:
	for i in Game.meta.chests.size():
		if Game.meta.chests[i] == null:
			Game.meta.chests[i] = {"type": type, "unlock_at": 0}
			save()
			return i
	return -1


func chest_at(i: int):
	return Game.meta.chests[i]


func chest_state(i: int) -> String:
	var c = Game.meta.chests[i]
	if c == null:
		return "empty"
	if int(c.unlock_at) == 0:
		return "locked"
	return "ready" if now() >= int(c.unlock_at) else "unlocking"


func is_unlocking_any() -> bool:
	for i in Game.meta.chests.size():
		if chest_state(i) == "unlocking":
			return true
	return false


func start_unlock(i: int) -> bool:
	if chest_state(i) != "locked" or is_unlocking_any():
		return false
	Game.meta.chests[i].unlock_at = now() + int(chest_def(Game.meta.chests[i].type).time)
	save()
	return true


func time_left(i: int) -> int:
	var c = Game.meta.chests[i]
	if c == null:
		return 0
	if int(c.unlock_at) == 0:
		return int(chest_def(c.type).time)
	return maxi(0, int(c.unlock_at) - now())


func gems_to_open(i: int) -> int:
	return maxi(1, int(ceil(time_left(i) / 60.0 / float(P().gems.minutes_per_gem))))


## Открыть сундук из слота (готовый — бесплатно, иначе за кристаллы).
func open_slot(i: int) -> Dictionary:
	var st := chest_state(i)
	if st == "empty":
		return {}
	if st != "ready":
		var cost := gems_to_open(i)
		if int(Game.meta.gems) < cost:
			return {}
		Game.meta.gems = int(Game.meta.gems) - cost
	var type: String = Game.meta.chests[i].type
	Game.meta.chests[i] = null
	return open_contents(gen_chest(type))


## Применить содержимое сундука. Возвращает его с пометками для экрана открытия.
func open_contents(contents: Dictionary) -> Dictionary:
	Game.meta.gold = int(Game.meta.gold) + int(contents.gold)
	for s in contents.cards:
		s["new"] = add_copies(s.id, int(s.n))
	save()
	return contents


func format_time(sec: int) -> String:
	if sec >= 3600:
		return "%dч %02dм" % [sec / 3600, (sec % 3600) / 60]
	if sec >= 60:
		return "%dм %02dс" % [sec / 60, sec % 60]
	return "%dс" % sec


# ---------------------------------------------------------------- бесплатный сундук

func free_chest_left() -> int:
	return maxi(0, int(Game.meta.free_chest_at) - now())


func claim_free_chest() -> Dictionary:
	if free_chest_left() > 0:
		return {}
	Game.meta.free_chest_at = now() + int(P().free_chest_hours) * 3600
	return open_contents(gen_chest("wood"))


# ================================================================ магазин дня

func shop() -> Dictionary:
	var day := Game.today()
	if Game.meta.shop.get("date", "") != day:
		var r := RandomNumberGenerator.new()
		r.seed = hash(day)
		var offers := []
		for o in P().shop.offers:
			var cand := []
			for id in droppable_ids():
				if Data.cards[id].rarity == o.rarity:
					cand.append(id)
			if cand.is_empty():
				continue
			offers.append({"id": cand[r.randi_range(0, cand.size() - 1)], "n": int(o.copies),
				"price": int(o.price), "bought": false})
		Game.meta.shop = {"date": day, "offers": offers, "gift": false}
		save()
	return Game.meta.shop


func shop_seconds_left() -> int:
	var t := Time.get_time_dict_from_system()
	return 86400 - (int(t.hour) * 3600 + int(t.minute) * 60 + int(t.second))


func buy_offer(i: int) -> bool:
	var o = shop().offers[i]
	if o.bought or int(Game.meta.gold) < int(o.price):
		return false
	Game.meta.gold = int(Game.meta.gold) - int(o.price)
	o.bought = true
	add_copies(o.id, int(o.n))
	save()
	return true


func claim_gift() -> bool:
	if shop().gift:
		return false
	Game.meta.shop.gift = true
	Game.meta.gold = int(Game.meta.gold) + int(P().shop.free_gold)
	save()
	return true


func buy_chest(type: String, gems: int) -> Dictionary:
	if int(Game.meta.gems) < gems:
		return {}
	Game.meta.gems = int(Game.meta.gems) - gems
	return open_contents(gen_chest(type))


# ================================================================ награды за забег

## Какой сундук даётся за забег: чем дальше прошёл, тем лучше.
func run_chest(won: bool, floor_reached: int, notoriety: int, chosen_killed: bool) -> String:
	if chosen_killed:
		return "legendary"
	if won:
		return "magic" if notoriety >= 3 else "gold"
	return "wood" if floor_reached <= 1 else "silver"


## Начисляет золото (остаток Казны), кристаллы и сундук. Возвращает сводку.
func run_rewards(won: bool, run_state: Dictionary) -> Dictionary:
	# Победа: всё, что осталось в Казне. Поражение: немного за каждого убитого героя.
	var gold := maxi(0, int(run_state.get("treasury", 0))) if won \
		else int(run_state.get("kills_count", 0)) * int(P().get("loss_gold_per_kill", 0))
	var gems := int(run_state.get("bosses", 0)) * int(P().gems.boss)
	if won:
		gems += int(P().gems.win)
	if run_state.get("daily", false):
		gems += int(P().gems.daily)
	var chest := run_chest(won, int(run_state.get("floor", 1)), int(run_state.get("notoriety", 0)),
		run_state.get("chosen_killed", false))
	if run_state.get("tutorial", false):
		chest = "wood"
	Game.meta.gold = int(Game.meta.gold) + gold
	Game.meta.gems = int(Game.meta.gems) + gems
	var slot := grant_chest(chest)
	save()
	return {"gold": gold, "gems": gems, "chest": chest, "slot": slot}
