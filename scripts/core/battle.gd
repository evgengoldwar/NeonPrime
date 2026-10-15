extends RefCounted
## Боевой движок «Я — подземелье».
## Ничего не знает об отрисовке: каждое действие складывает события в `events`,
## экран боя проигрывает их как анимацию. Всё состояние — простые словари и массивы,
## поэтому бой целиком сохраняется в JSON (to_dict / from_dict).

const HALLS := 3
const MAX_HAND := 7
const MAX_HALL_TICKS := 400
## Все HP, урон и золото в игре ×10 (чтобы +15% за уровень всегда давали прибавку).
## Яд за тик убывает на столько же — длительность Яда прежняя.
const POISON_STEP := 10
const SAVE_PROPS := [
	"heroes", "cells", "corridor_len", "hand", "draw_pile", "discard", "exhausted",
	"dark", "hall", "phase", "tick_no", "discount", "next_discount", "combo", "best_combo",
	"souls", "killed", "escaped", "gold_delta", "mine_cell", "hall_state", "zombie_revived",
	"tutorial", "tutorial_hands", "result", "is_boss", "node_type",
	"cell_mods", "next_dark_bonus", "next_draw_bonus",
]
## Награды за комбо в зале: порог → что даёт (каждая 1 раз за зал).
const COMBO_REWARDS := [[4, "dark"], [6, "draw"], [9, "gold"]]
const COMBO_GOLD := 50
## Особые клетки коридора: [название, коротко на клетке, описание, цвет].
const CELL_MODS := {
	"dark": ["Тёмная клетка", "ТЬМА −1", "Карта на этой клетке стоит на 1 Тьму меньше", "#9d6bff"],
	"blood": ["Алтарь крови", "КРОВЬ +10", "Монстр на этой клетке получает +10 к Атаке", "#e43b44"],
	"pit": ["Ловчая яма", "ЯМА ×2", "Ловушка на этой клетке срабатывает дважды", "#c47b25"],
	"chest": ["Сундук", "СУНДУК", "Герой задерживается на 1 тик и получает +10 Жадности", "#feae34"],
	"draft": ["Сквозняк", "СКВОЗНЯК", "Гасит Горение героя, который сюда вошёл", "#b9aed2"],
	"lava": ["Лава", "ЛАВА", "Герой, вошедший сюда, получает Горение 10", "#f77622"],
	"ice": ["Лёд", "ЛЁД", "Герой, вошедший сюда, получает Замедление 1", "#2ce8f5"],
	# Клетки на стороне героев: их надо обходить расстановкой.
	"spring": ["Источник", "ИСТОЧНИК", "Герой, вошедший сюда, лечит 40 HP", "#63c74d"],
	"holy": ["Святая земля", "СВЯТАЯ", "Ловушка на этой клетке наносит вдвое меньше урона", "#f4f0ff"],
}

var heroes := []
var cells := []
var corridor_len := 6
var hand := []
var draw_pile := []
var discard := []
var exhausted := []
var dark := 0
var hall := 0
var phase := "prep"          # prep — выкладка, walk — проход героя, done — бой окончен
var tick_no := 0
var discount := 0
var next_discount := 0
var combo := 0
var best_combo := 0
var souls := 0
var killed := []
var escaped := []
var gold_delta := 0
var mine_cell := -1
var hall_state := {}
var zombie_revived := {}
var tutorial := false
var tutorial_hands := []
var result := ""             # win / escaped / lose
var is_boss := false
var node_type := "battle"
var cell_mods := ["", "", "", "", "", ""]
var next_dark_bonus := 0
var next_draw_bonus := 0

var events := []
var _depth := 0
var _tick_triggers := 0


# ---------------------------------------------------------------- создание

func setup(hero_list: Array, deck: Array, opts: Dictionary = {}) -> void:
	heroes = hero_list
	for i in heroes.size():
		_init_hero(heroes[i])
	cells = []
	for i in 6:
		cells.append(null)
	tutorial = opts.get("tutorial", false)
	tutorial_hands = opts.get("tutorial_hands", [])
	node_type = opts.get("node_type", "battle")
	is_boss = node_type == "boss"
	draw_pile = []
	for c in deck:
		draw_pile.append({"uid": c.uid, "id": c.id, "up": c.up, "lvl": int(c.get("lvl", 1))})
	Game.shuffle(draw_pile)
	if Game.has_relic("dark_throne"):
		_gold(-20, "Тёмный трон")
	if Game.run.get("master", "") == "dragoness" and not tutorial:
		var id := "dragon" if Game.run.get("dragon_hatched", false) else "dragon_egg"
		var b := _make_board({"uid": -1, "id": id, "up": Game.run.get("dragon_up", false), "lvl": Game.card_level(id)}, 0)
		b["locked"] = true
		b["innate"] = true
		cells[5] = b
	_begin_prep()


func _init_hero(h: Dictionary) -> void:
	var defaults := {
		"armor": 0, "slow": 0, "poison": 0, "burn": 0, "vuln": 0, "stun": 0, "curse": 0,
		"pos": -1, "tick_on": 0, "hold": 0, "delay": 0, "state": "wait", "rage": 0,
		"first_hit_done": false, "trap_skipped": false, "sapper_used": false, "disarm_used": false,
		"ignore_cards": 0, "smoke_used": false, "bless_left": 0, "bless_used": false,
		"phase": 1, "extra_trait": "", "fast": false, "last_src": "", "src_uids": {}, "mods": [],
	}
	for k in defaults.keys():
		if not h.has(k):
			h[k] = defaults[k]


func to_dict() -> Dictionary:
	var d := {}
	for p in SAVE_PROPS:
		d[p] = get(p)
	return d.duplicate(true)


func from_dict(d: Dictionary) -> void:
	for p in SAVE_PROPS:
		if d.has(p):
			set(p, d[p])


func take_events() -> Array:
	var e := events
	events = []
	return e


# ---------------------------------------------------------------- подготовка зала

func hand_size() -> int:
	var n := 5
	if Game.has_relic("night_cloak"):
		n += 1
	if Game.run.get("master", "") == "goblin_king":
		n += 1
	return mini(n, MAX_HAND)


func base_dark() -> int:
	var d := 3
	if hall == 0 and Game.run.get("notoriety", 0) >= 7:
		d = 2
	if hall == 0 and Game.has_relic("tyrant_crown"):
		d += 1
	if Game.run.get("master", "") == "goblin_king":
		d += 1
	if Game.has_relic("dark_throne"):
		d += 1
	d += int(Game.run.get("floor_flags", {}).get("pact_dark", 0))
	if Game.run.get("daily_mod", "") == "dark_first" and hall == 0:
		d += 1
	return d


func _begin_prep() -> void:
	phase = "prep"
	discount = next_discount
	next_discount = 0
	dark = base_dark() + next_dark_bonus
	var extra_draw := next_draw_bonus
	var bonus := []
	if next_dark_bonus > 0:
		bonus.append("+%d Тьма" % next_dark_bonus)
	if next_draw_bonus > 0:
		bonus.append("+%d карта" % next_draw_bonus)
	if not bonus.is_empty():
		events.append({"t": "msg", "text": "Награда за комбо: " + ", ".join(bonus)})
	next_dark_bonus = 0
	next_draw_bonus = 0
	hall_state = {"resin_used": false, "necro_used": false, "circle": {}, "combo_got": [], "once": {}}
	_roll_cell_mods()
	if tutorial and hall < tutorial_hands.size():
		for c in hand:
			discard.append(c)
		hand = []
		for id in tutorial_hands[hall]:
			hand.append({"uid": Game.next_uid(), "id": id, "up": false})
	else:
		draw(hand_size() - hand.size() + extra_draw)
	if Game.run.get("master", "") == "smith":
		var traps := []
		for c in hand:
			if Data.cards[c.id].type == "trap" and not c.up:
				traps.append(c)
		if traps.size() > 0:
			var t = Game.rpick(traps)
			t["temp_up"] = true
	var order := 0
	for h in heroes:
		if h.state in ["dead", "fled"]:
			continue
		h.state = "wait"
		h.pos = -1
		h.tick_on = 0
		h.hold = 0
		h.delay = order * 2
		order += 1
	events.append({"t": "prep", "hall": hall})


## Особые клетки зала: 1 в первом зале, 1–2 в следующих. Набор зависит от локации.
func _roll_cell_mods() -> void:
	cell_mods = ["", "", "", "", "", ""]
	if tutorial or off("cells"):
		return
	var pool: Array = Data.locations.get(str(Game.run.get("location", "")), {}).get("cell_mods", [])
	if pool.is_empty():
		return
	var n := 1 if hall == 0 else Game.rint(1, 2)
	var free := []
	for i in corridor_len:
		free.append(i)
	Game.shuffle(free)
	for k in mini(n, free.size()):
		cell_mods[free[k]] = Game.rpick(pool)


## Отключённые механики боя (для балансовых прогонов: balance_sim off=combo,cells).
static var disabled := []


static func off(feature: String) -> bool:
	return feature in disabled


func cell_mod(idx: int) -> String:
	return cell_mods[idx] if idx >= 0 and idx < cell_mods.size() else ""


func draw(n: int) -> void:
	for i in n:
		if hand.size() >= MAX_HAND:
			return
		if draw_pile.is_empty():
			if discard.is_empty():
				return
			draw_pile = discard
			discard = []
			Game.shuffle(draw_pile)
			events.append({"t": "msg", "text": "Сброс перемешан в колоду"})
		hand.append(draw_pile.pop_back())


func card_up(c) -> bool:
	return bool(c.get("up", false)) or bool(c.get("temp_up", false))


func def_of(c) -> Dictionary:
	return Data.cdef(c.id, card_up(c), card_lvl(c))


## Уровень карты в бою: уровень коллекции + бонус темы Хозяина.
func card_lvl(c) -> int:
	return int(c.get("lvl", 1))


func card_cost(c) -> int:
	return maxi(0, int(def_of(c).cost) - discount)


## Стоимость карты на конкретной клетке (Тёмная клетка дешевле на 1).
func card_cost_at(c, cell_idx: int) -> int:
	return maxi(0, card_cost(c) - (1 if cell_mod(cell_idx) == "dark" else 0))


func can_place(hand_idx: int, cell_idx: int) -> bool:
	if phase != "prep" or hand_idx < 0 or hand_idx >= hand.size():
		return false
	if cell_idx < 0 or cell_idx >= corridor_len:
		return false
	var c = hand[hand_idx]
	if def_of(c).type == "spell":
		return false
	var budget := dark
	var old = cells[cell_idx]
	if old != null:
		if old.locked:
			return false
		budget += int(old.paid)
	return budget >= card_cost_at(c, cell_idx)


func place(hand_idx: int, cell_idx: int) -> bool:
	if not can_place(hand_idx, cell_idx):
		return false
	var c = hand[hand_idx]
	var cost := card_cost_at(c, cell_idx)
	hand.remove_at(hand_idx)
	var old = cells[cell_idx]
	if old != null:
		dark += int(old.paid)
		hand.append(_strip(old))
	dark -= cost
	cells[cell_idx] = _make_board(c, cost)
	if Data.cards[c.id].type == "monster":
		Game.run.floor_flags["monster_placed"] = true
	return true


func can_unplace(cell_idx: int) -> bool:
	var c = cells[cell_idx] if cell_idx < cells.size() else null
	return phase == "prep" and c != null and not c.locked


func unplace(cell_idx: int) -> bool:
	if not can_unplace(cell_idx):
		return false
	var c = cells[cell_idx]
	dark += int(c.paid)
	hand.append(_strip(c))
	cells[cell_idx] = null
	return true


func move_on_board(from_idx: int, to_idx: int) -> bool:
	if not can_unplace(from_idx) or to_idx < 0 or to_idx >= corridor_len or from_idx == to_idx:
		return false
	var other = cells[to_idx]
	if other != null and other.locked:
		return false
	cells[to_idx] = cells[from_idx]
	cells[from_idx] = other
	return true


func return_all() -> void:
	for i in cells.size():
		if can_unplace(i):
			unplace(i)


func can_play_spell(hand_idx: int) -> bool:
	if phase != "prep" or hand_idx < 0 or hand_idx >= hand.size():
		return false
	var c = hand[hand_idx]
	return def_of(c).type == "spell" and dark >= card_cost(c)


func play_spell(hand_idx: int) -> bool:
	if not can_play_spell(hand_idx):
		return false
	var c = hand[hand_idx]
	var d := def_of(c)
	dark -= card_cost(c)
	hand.remove_at(hand_idx)
	if "burn" in d.kw:
		exhausted.append(_strip(c))
	else:
		discard.append(_strip(c))
	events.append({"t": "spell", "id": c.id, "name": d.name})
	for a in d.get("play", []):
		_spell_action(a)
	return true


func _spell_action(a: Dictionary) -> void:
	match a.a:
		"dark":
			dark += int(a.n)
		"draw":
			draw(int(a.n))
		"return_monster":
			for i in range(discard.size() - 1, -1, -1):
				if Data.cards[discard[i].id].type == "monster":
					hand.append(discard[i])
					discard.remove_at(i)
					break
		"double_poison":
			for h in _active_heroes():
				if h.poison > 0:
					h.poison *= 2
					events.append({"t": "status", "hero": h.uid, "text": "Яд ×2"})
		"curse":
			for h in _active_heroes():
				h.curse += int(a.n)
				events.append({"t": "status", "hero": h.uid, "text": "Проклятие %d" % int(a.n)})
		"gold":
			_gold(int(a.n), "Заклинание")
		"monsters_hp":
			for c in cells:
				if c != null and Data.cards[c.id].type == "monster":
					c.hp += int(a.n)
					c.max_hp += int(a.n)


func _make_board(c: Dictionary, paid: int) -> Dictionary:
	var d: Dictionary = def_of(c)
	return {
		"uid": c.uid, "id": c.id, "up": c.get("up", false), "temp_up": c.get("temp_up", false),
		"lvl": card_lvl(c),
		"paid": paid, "locked": false, "once_used": false, "once_actions": {},
		"frozen": false, "disabled": false, "freeze_ticks": 0, "hall_atk": 0,
		"hp": int(d.get("hp", 0)), "max_hp": int(d.get("hp", 0)), "buffed": false,
		"innate": c.get("innate", false),
	}


func _strip(c: Dictionary) -> Dictionary:
	return {"uid": c.uid, "id": c.id, "up": c.get("up", false), "lvl": card_lvl(c)}


# ---------------------------------------------------------------- запуск зала

func launch() -> void:
	if phase != "prep":
		return
	phase = "walk"
	tick_no = 0
	combo = 0
	for c in cells:
		if c != null:
			c.locked = true
	# Вожак стаи усиливает соседних Волков и Крыс.
	for i in corridor_len:
		var c = cells[i]
		if c != null and c.id == "pack_leader":
			for j in [i - 1, i + 1]:
				if j >= 0 and j < corridor_len and cells[j] != null and cells[j].id in ["wolf", "rat_swarm"] and not cells[j].buffed:
					cells[j].buffed = true
					cells[j].hp += 20
					cells[j].max_hp += 20
	# Правило шахты: одна случайная пустая клетка обвалится.
	mine_cell = -1
	if Game.location_rule() == "mine":
		var empties := []
		for i in corridor_len:
			if cells[i] == null:
				empties.append(i)
		if empties.is_empty():
			_gold(-20, "Обвал бьёт по Казне")
		else:
			mine_cell = Game.rpick(empties)
	for h in _active_heroes():
		_before_hall(h)
	events.append({"t": "launch", "hall": hall})


func _before_hall(h: Dictionary) -> void:
	if Game.location_rule() == "temple":
		_apply_slow(h, 1, false)
	if _has_trait(h, "cleanse"):
		for o in _active_heroes():
			o.poison = 0
			o.burn = 0
			o.curse = 0
		_msg(h, "Очищение")
	if _has_trait(h, "light"):
		_heal(h, 30 if Game.has_collection("paladin") else 40)
	if _has_trait(h, "marksman"):
		var m := _first_monster()
		if m >= 0:
			_msg(h, "Меткий выстрел")
			_hurt_monster(m, 40, h)
	if _has_trait(h, "tomb_raider"):
		var empty := 0
		for i in corridor_len:
			if cells[i] == null:
				empty += 1
		if empty > 0:
			_gold(-10 * empty, h.name + " крадёт золото")
	if _has_trait(h, "tide"):
		for i in corridor_len - 1:
			if cells[i] != null:
				var tmp = cells[i + 1]
				cells[i + 1] = cells[i]
				cells[i] = tmp
				_msg(h, "Прилив сдвигает карту")
				break
	if _has_trait(h, "freezer"):
		var m := _first_monster()
		if m >= 0:
			cells[m].freeze_ticks = 2
			_msg(h, "Монстр заморожен")
	if _has_trait(h, "rune_armor") or "armored" in h.mods:
		h.armor = maxi(h.armor, 60)
	# Боссы
	if _has_trait(h, "boss_fearless") and h.phase == 2:
		h.slow = 0
	if _has_trait(h, "boss_dismantle"):
		var n: int = 2 if h.phase == 2 else 1
		for k in n:
			var best := -1
			for i in corridor_len:
				var c = cells[i]
				if c != null and not c.disabled and (best < 0 or def_of(c).cost > def_of(cells[best]).cost):
					best = i
			if best >= 0:
				cells[best].disabled = true
				_msg(h, "Разобрал: " + Data.card_name(cells[best].id))
	if _has_trait(h, "boss_shuffle"):
		var occ := _occupied()
		if occ.size() >= 2:
			Game.shuffle(occ)
			var a: int = occ[0]
			var b: int = occ[1]
			var tmp = cells[a]
			cells[a] = cells[b]
			cells[b] = tmp
			_msg(h, "Ольвен меняет карты %d и %d" % [a + 1, b + 1])
	if _has_trait(h, "boss_king"):
		_heal(h, 100)
	if _has_trait(h, "boss_ice"):
		var cand := []
		for i in _occupied():
			if not _has_burn_effect(cells[i]):
				cand.append(i)
		Game.shuffle(cand)
		for k in mini(2, cand.size()):
			cells[cand[k]].frozen = true
		if cand.size() > 0:
			_msg(h, "Ирса замораживает карты")
		if h.phase == 2:
			var m := _first_monster()
			if m >= 0:
				_msg(h, "Ледяная стрела!")
				_kill_monster(m, h)
	if h.trait == "boss_chosen":
		var traits: Array = Game.run.get("killed_traits", [])
		if traits.size() > 0:
			h.extra_trait = Game.rpick(traits)
			_msg(h, "Наследие павших: " + h.extra_trait)


# ---------------------------------------------------------------- тик

func tick() -> void:
	if phase != "walk":
		return
	tick_no += 1
	_tick_triggers = 0
	for h in heroes:
		if Game.run.treasury <= 0:
			break
		if h.state == "wait":
			if h.delay > 0:
				h.delay -= 1
				continue
			h.state = "walk"
			_step(h)
			_check_death(h)
			continue
		if h.state != "walk":
			continue
		_hero_tick(h)
	for c in cells:
		if c != null and c.freeze_ticks > 0:
			c.freeze_ticks -= 1
	if _tick_triggers > 0:
		combo += _tick_triggers
		if combo >= 3:
			events.append({"t": "combo", "n": combo})
		if combo > best_combo:
			best_combo = combo
			if combo >= 5:
				Game.unlock_achievement("combo5")
		_combo_rewards()
	else:
		combo = 0
	if Game.run.treasury <= 0:
		phase = "done"
		result = "lose"
		events.append({"t": "end", "result": result})
		return
	var busy := false
	for h in heroes:
		if h.state in ["wait", "walk"]:
			busy = true
	if not busy:
		_end_hall()


## Награды за длинное комбо: ×3 — Тьма в следующем зале, ×5 — карта, ×8 — золото.
func _combo_rewards() -> void:
	if off("combo"):
		return
	var got: Array = hall_state.get("combo_got", [])
	for r in COMBO_REWARDS:
		if combo < int(r[0]) or int(r[0]) in got:
			continue
		got.append(int(r[0]))
		match r[1]:
			"dark":
				next_dark_bonus += 1
				events.append({"t": "reward", "text": "Комбо ×%d: +1 Тьма в следующем зале" % int(r[0])})
			"draw":
				next_draw_bonus += 1
				events.append({"t": "reward", "text": "Комбо ×%d: +1 карта в следующем зале" % int(r[0])})
			"gold":
				_gold(COMBO_GOLD, "")
				events.append({"t": "reward", "text": "Цепная реакция! +%d золота" % COMBO_GOLD})
	hall_state["combo_got"] = got


## «Однократно за зал» для реакций и клеток: true, если ключ ещё не использован.
func _once(key: String) -> bool:
	var o: Dictionary = hall_state.get("once", {})
	if o.has(key):
		return false
	o[key] = true
	hall_state["once"] = o
	return true


func _react(h: Dictionary, text: String) -> void:
	events.append({"t": "react", "hero": h.uid, "text": text})


func _hero_tick(h: Dictionary) -> void:
	# 1. Урон от статусов
	if h.burn > 0 and Game.location_rule() != "temple":
		_damage(h, h.burn, "burn", -1)
	if _check_death(h):
		return
	if h.poison > 0:
		var times := 2 if _catalyst_near(h) else 1
		for t in times:
			_damage(h, h.poison, "poison", -1)
		if Game.run.get("master", "") != "alchemist":
			h.poison = maxi(0, h.poison - POISON_STEP)
	if _check_death(h):
		return
	# 2. Ауры
	for i in [h.pos - 1, h.pos, h.pos + 1]:
		if i >= 0 and i < corridor_len and cells[i] != null:
			var c = cells[i]
			var d := def_of(c)
			if d.has("aura") and not c.disabled and not c.frozen:
				_trigger_fx(i)
				_run_actions(d.aura, h, i, c)
	if _check_death(h):
		return
	# 3. Бой с монстром
	if _live_monster(h.pos):
		_fight(h, h.pos)
		_check_death(h)
		return
	# 4. Задержка. Страховка: если зал затянулся, Замедление больше не держит героя.
	if h.tick_on < 1 + h.slow + h.hold and tick_no < MAX_HALL_TICKS:
		h.tick_on += 1
		return
	# 5. Шаг
	_step(h)
	if _check_death(h):
		return
	var extra: bool = h.fast or ("swift" in h.mods and tick_no % 3 == 0)
	if extra and h.state == "walk" and not _live_monster(h.pos):
		_step(h)
		_check_death(h)


func _step(h: Dictionary) -> void:
	var old: int = h.pos
	if old >= 0 and old < corridor_len:
		_trigger_exit(h, old)
		if h.state != "walk" or h.hp <= 0:
			return
	var nxt := old + 1
	if h.phase == 2 and _has_trait(h, "boss_shuffle") and nxt == 2:
		nxt = 4
		_msg(h, "Телепорт!")
	if nxt >= corridor_len:
		h.pos = corridor_len
		h.state = "exit"
		events.append({"t": "move", "hero": h.uid, "pos": h.pos})
		events.append({"t": "hall_exit", "hero": h.uid})
		return
	h.pos = nxt
	h.tick_on = 1
	h.hold = 0
	events.append({"t": "move", "hero": h.uid, "pos": h.pos})
	_trigger_enter(h, nxt)


# ---------------------------------------------------------------- срабатывания

func _trigger_enter(h: Dictionary, idx: int) -> void:
	if _depth > 8 or idx < 0 or idx >= corridor_len:
		return
	_cell_enter(h, idx)
	if h.hp <= 0 or h.state != "walk":
		return
	var c = cells[idx]
	if c == null:
		if idx == mine_cell:
			mine_cell = -1
			_msg(h, "Обвал!")
			_damage(h, 40, "env", -1)
		return
	_depth += 1
	_enter_card(h, idx, c)
	_depth -= 1


## Особая клетка срабатывает, когда герой на неё входит (1 раз за зал на героя).
func _cell_enter(h: Dictionary, idx: int) -> void:
	var m := cell_mod(idx)
	if m == "" or m in ["dark", "blood", "pit", "holy"]:
		return
	if not _once("cell%d_%d" % [idx, int(h.uid)]):
		return
	match m:
		"chest":
			h.hold += 1
			h.greed += 10
			_status(h, "Сундук: Жадность +10")
		"draft":
			if h.burn > 0:
				h.burn = 0
				_status(h, "Сквозняк гасит огонь")
		"lava":
			_apply_burn(h, 10)
		"ice":
			_apply_slow(h, 1, false)
		"spring":
			_heal(h, 40)
			_status(h, "Источник: +40 HP")


func _enter_card(h: Dictionary, idx: int, c: Dictionary) -> void:
	var d := def_of(c)
	if h.ignore_cards > 0:
		h.ignore_cards -= 1
		_msg(h, "Игнорирует " + d.name)
		return
	if c.disabled or c.frozen:
		events.append({"t": "blocked", "cell": idx})
		return
	if c.once_used:
		return
	# Огненный щит Мага и Ольвен
	var burns_slime := _has_trait(h, "fire_shield") or _has_trait(h, "boss_shuffle")
	if burns_slime and (c.id == "slime" or (_has_trait(h, "fire_shield") and d.type == "monster" and c.hp > 0 and c.hp <= 30)):
		_msg(h, "Сжигает " + d.name)
		_remove_card(idx, false)
		return
	if d.type == "monster":
		# Засада бьёт каждого героя 1 раз за зал, иначе Страх из Засады зацикливает героя.
		var key := "ambush_" + str(h.uid)
		if c.hp > 0 and d.has("ambush") and not c.once_actions.has(key):
			c.once_actions[key] = true
			_trigger_fx(idx)
			_run_actions(d.ambush, h, idx, c)
		return
	if d.type == "trap":
		if _has_trait(h, "agile") and not h.trap_skipped:
			var allowed: bool = not (Game.has_collection("thief") and h.trait == "agile" and hall > 0)
			if allowed:
				h.trap_skipped = true
				_msg(h, "Перепрыгнул " + d.name)
				return
		if "sapper" in h.mods and not h.sapper_used:
			h.sapper_used = true
			_msg(h, "Сапёр: " + d.name + " не сработала")
			return
		if _has_trait(h, "disarm") and not h.disarm_used and _has_damage(d.get("enter", [])):
			h.disarm_used = true
			_msg(h, "Обезвредил " + d.name)
			return
	var actions: Array = d.get("enter", [])
	if actions.is_empty():
		return
	var times := _trigger_times(idx, d)
	if _has_trait(h, "prospector") and (c.id == "false_chest" or c.id == "treasure_lair"):
		times *= 2
	for t in times:
		if h.state != "walk" and h.state != "wait":
			break
		_trigger_fx(idx)
		_run_actions(actions, h, idx, c)
	if "once" in d.kw:
		c.once_used = true
	if d.type == "trap" and _has_trait(h, "boss_fearless"):
		h.armor += 10


func _trigger_exit(h: Dictionary, idx: int) -> void:
	var c = cells[idx]
	if c == null or c.disabled or c.frozen or c.once_used:
		return
	var d := def_of(c)
	if not d.has("exit"):
		return
	for t in _trigger_times(idx, d):
		_trigger_fx(idx)
		_run_actions(d.exit, h, idx, c)


func _trigger_times(idx: int, d: Dictionary) -> int:
	var times := 1
	if d.type == "trap" and _adjacent_has(idx, "gear"):
		times *= 2
	if idx == 0 and Game.has_relic("mirror_shard"):
		times *= 2
	if idx == 5 and corridor_len == 6 and Game.has_relic("hourglass"):
		times *= 2
	if d.type == "trap" and cell_mod(idx) == "pit":
		times *= 2
	return times


func _run_actions(actions: Array, h: Dictionary, idx: int, c) -> void:
	for a in actions:
		if h.hp <= 0 or h.state in ["dead", "fled", "exit"]:
			return
		if a.get("once", false) and c != null:
			var key := str(actions.find(a))
			if c.once_actions.has(key):
				continue
			c.once_actions[key] = true
		_action(a, h, idx, c)


func _action(a: Dictionary, h: Dictionary, idx: int, c) -> void:
	var is_trap: bool = c != null and Data.cards[c.id].type == "trap"
	match a.a:
		"damage":
			if a.get("if_burning", false) and h.burn <= 0:
				return
			var n := int(a.n)
			if a.has("cell_mult"):
				n = int(a.cell_mult) * (idx + 1)
			if is_trap:
				n += _trap_bonus(idx)
			if a.has("slow_mult") and h.slow > 0:
				n *= int(pow(int(a.slow_mult), h.slow))
			if a.has("adj_trap_mult") and _adjacent_type(idx, "trap"):
				n *= int(a.adj_trap_mult)
			if a.has("if_slowed_mult") and h.slow > 0:
				n *= int(a.if_slowed_mult)
			if is_trap and cell_mod(idx) == "holy":
				n /= 2
			_damage(h, n, "trap" if is_trap else "monster", c.uid if c != null else -1)
		"slow":
			if a.has("if_greed") and h.greed < int(a.if_greed):
				return
			var n := int(a.n)
			if c != null and c.id == "slime" and Game.location_rule() == "citadel":
				n += 1
			_apply_slow(h, n, true)
		"fear":
			_apply_fear(h)
		"poison":
			_apply_poison(h, int(a.n))
		"burn":
			var n := int(a.n)
			if is_trap and Game.location_rule() == "volcano":
				n += 10
			_apply_burn(h, n)
		"vuln":
			h.vuln = 1
			_status(h, "Уязвимость")
		"stun":
			if "fearless" in h.mods:
				_status(h, "Иммунитет")
				return
			h.stun = 1
			_status(h, "Оглушение")
		"curse":
			h.curse += int(a.n)
			_status(h, "Проклятие %d" % int(a.n))
		"greed":
			h.greed += int(a.n)
			_status(h, "Жадность +%d" % int(a.n))
		"hold":
			h.hold += int(a.n)
			_status(h, "Задержан на %d" % int(a.n))
		"knockback":
			if tick_no >= MAX_HALL_TICKS:
				return
			for k in int(a.n):
				if h.pos <= 0 or h.state != "walk":
					break
				h.pos -= 1
				h.tick_on = 1
				events.append({"t": "move", "hero": h.uid, "pos": h.pos})
				_trigger_enter(h, h.pos)
		"repeat_prev":
			var p := idx - 1
			if p >= 0 and cells[p] != null:
				var pc = cells[p]
				var pd := def_of(pc)
				if not pc.disabled and not pc.frozen and pd.has("enter") and _depth < 8:
					_depth += 1
					_trigger_fx(p)
					_run_actions(pd.enter, h, p, pc)
					_depth -= 1
					# Призрак, повторивший карту «Однократно», тоже срабатывает 1 раз за зал.
					if "once" in pd.kw and c != null:
						c.once_used = true
		"gold":
			_gold(int(a.n), "")


func _trap_bonus(idx: int) -> int:
	var b := 0
	for j in [idx - 1, idx + 1]:
		if j >= 0 and j < corridor_len and cells[j] != null:
			var d := def_of(cells[j])
			if d.get("special", "") == "dark_altar" and not cells[j].disabled:
				b += int(d.p)
	if Game.run.get("master", "") == "smith" and _adjacent_type(idx, "trap"):
		b += 10
	return b


# ---------------------------------------------------------------- статусы

func _apply_slow(h: Dictionary, n: int, from_card: bool) -> void:
	if _has_trait(h, "boss_ice"):
		_status(h, "Иммунитет к Замедлению")
		return
	if from_card and Game.has_relic("resin_drop") and not hall_state.get("resin_used", false):
		hall_state["resin_used"] = true
		n += 1
	h.slow += n
	if _has_trait(h, "agile"):
		h.slow = mini(h.slow, 1)
	_status(h, "Замедление %d" % h.slow)
	# Реакция «Заморозка»: Замедление 3 и больше сковывает героя на 2 тика.
	if h.slow >= 3 and not off("reactions") and _once("freeze_%d" % int(h.uid)):
		h.hold += 2
		_react(h, "Заморозка!")


func _apply_fear(h: Dictionary) -> void:
	if h.state != "walk" or tick_no >= MAX_HALL_TICKS:
		return
	if _has_trait(h, "light") or _has_trait(h, "boss_fearless") or _has_trait(h, "boss_king") or "fearless" in h.mods:
		_status(h, "Не боится")
		return
	_status(h, "Страх")
	if h.pos <= 0:
		h.tick_on = 0
		return
	var back := 2 if Game.has_relic("fear_bell") else 1
	h.pos = maxi(0, h.pos - back)
	h.tick_on = 1
	h.hold = 0
	events.append({"t": "move", "hero": h.uid, "pos": h.pos})
	_trigger_enter(h, h.pos)


func _apply_poison(h: Dictionary, n: int) -> void:
	if "antidote" in h.mods or _has_trait(h, "poison_immune"):
		_status(h, "Иммунитет к Яду")
		return
	h.poison += n
	_status(h, "Яд %d" % h.poison)
	_check_boom(h)


func _apply_burn(h: Dictionary, n: int) -> void:
	if Game.location_rule() == "temple":
		_status(h, "Вода гасит огонь")
		return
	if "fireproof" in h.mods or _has_trait(h, "burn_immune"):
		_status(h, "Иммунитет к Горению")
		return
	h.burn += n
	if Game.location_rule() == "citadel" and h.slow > 0:
		h.slow = 0
		_status(h, "Лёд тает: Замедление снято")
	_status(h, "Горение %d" % h.burn)
	_check_boom(h)


## Реакция «Взрыв»: Яд и Горение на одном герое — Яд сразу наносит урон ещё раз.
func _check_boom(h: Dictionary) -> void:
	if h.poison > 0 and h.burn > 0 and h.hp > 0 and not off("reactions") and _once("boom_%d" % int(h.uid)):
		_react(h, "Взрыв!")
		_damage(h, h.poison, "poison", -1)


func _heal(h: Dictionary, n: int) -> void:
	var before: int = h.hp
	h.hp = mini(h.max_hp, h.hp + n)
	if h.hp > before:
		events.append({"t": "heal", "hero": h.uid, "n": h.hp - before})


# ---------------------------------------------------------------- урон

func _damage(h: Dictionary, n: int, kind: String, src_uid: int) -> int:
	if n <= 0 or h.hp <= 0:
		return 0
	var is_status := kind == "poison" or kind == "burn"
	if h.bless_left > 0 and not is_status:
		h.bless_left -= 1
		_status(h, "Благословение: 0 урона")
		return 0
	if h.vuln > 0 and not is_status:
		# Реакция «Пробой»: удар Монстра по Уязвимому герою — ×2 вместо ×1,5.
		if kind == "monster" and not off("reactions"):
			n *= 2
			_react(h, "Пробой ×2!")
		else:
			n = int(ceil(n * 1.5))
		h.vuln = 0
	if not h.first_hit_done:
		h.first_hit_done = true
		if _has_trait(h, "thick_skin"):
			n = maxi(0, n - (10 if Game.has_collection("warrior") else 20))
			_status(h, "Толстокожий")
	if not is_status and h.armor > 0:
		var absorbed := mini(h.armor, n)
		h.armor -= absorbed
		n -= absorbed
		if absorbed > 0:
			events.append({"t": "armor", "hero": h.uid, "n": absorbed})
	if n <= 0:
		return 0
	h.hp -= n
	h.last_src = kind
	if src_uid >= 0:
		h.src_uids[str(src_uid)] = true
	else:
		h.src_uids["status"] = true
	events.append({"t": "dmg", "hero": h.uid, "n": n, "kind": kind})
	if _has_trait(h, "rage"):
		h.rage += 1
	if h.phase == 2 and _has_trait(h, "boss_pirate") and not h.smoke_used:
		h.smoke_used = true
		h.ignore_cards = 2
		_msg(h, "Дымовая шашка!")
	if h.get("boss", false) and h.phase == 1 and h.hp > 0 and h.hp * 2 < h.max_hp:
		_phase_two(h)
	return n


func _phase_two(h: Dictionary) -> void:
	h.phase = 2
	var text: String = Data.hero_def(h.id).get("phase2_text", "")
	events.append({"t": "phase2", "hero": h.uid, "text": text})
	match h.trait:
		"boss_fearless":
			h.atk = maxi(h.atk, 60)
		"boss_king":
			if not h.bless_used:
				h.bless_used = true
				h.bless_left = 3
		"boss_chosen":
			corridor_len = 5
			var c = cells[5]
			if c != null:
				if not c.get("innate", false):
					hand.append(_strip(c))
				cells[5] = null
			for o in heroes:
				if o.state == "walk" and o.pos >= 5:
					o.pos = 4


func _check_death(h: Dictionary) -> bool:
	if h.hp > 0 or h.state in ["dead", "fled"]:
		return h.state == "dead"
	h.state = "dead"
	var gold: int = h.greed
	if Game.run.get("notoriety", 0) >= 10 and Game.run.floor == 3:
		gold = 0
	if Game.has_relic("coin_bag"):
		gold += 20
	var kind: String = h.get("kind", "normal")
	var s := 1
	if h.id == "chosen":
		s = 25
	elif h.get("boss", false):
		s = 10
	elif kind == "elite" or h.get("squad", false):
		s = 3
	souls += s
	if h.last_src == "poison":
		for c in cells:
			if c != null and def_of(c).get("special", "") == "cauldron":
				gold += int(def_of(c).p)
	_gold(gold, "")
	events.append({"t": "hdeath", "hero": h.uid, "gold": gold})
	killed.append({"id": h.id, "kind": kind, "name": h.name})
	Game.record_kill(h)
	if h.src_uids.size() == 1 and not h.src_uids.has("status"):
		Game.unlock_achievement("one_card_kill")
	if h.trait == "squire":
		Game.run["squire_bonus"] = true
	if h.trait == "boss_pirate":
		Game.return_stolen()
		if not Game.run.get("mika_stole", false):
			Game.unlock_achievement("mika_clean")
	if h.id == "chosen":
		Game.unlock_achievement("chosen_kill")
	if h.id == "mage":
		for o in heroes:
			if o.id == "bard" and o.state in ["wait", "walk"]:
				o.fast = true
				_msg(o, "Бард в панике бежит!")
	_grow_eggs()
	return true


func _grow_eggs() -> void:
	for o in heroes:
		if o.trait == "tamer" and o.state in ["wait", "walk", "exit"]:
			return
	var rate := 2 if Game.run.get("master", "") == "dragoness" else 1
	for i in corridor_len:
		var c = cells[i]
		if c == null or c.id != "dragon_egg":
			continue
		Game.run["egg_growth"] = int(Game.run.get("egg_growth", 0)) + rate
		var need := int(def_of(c).p)
		events.append({"t": "msg", "text": "Яйцо дракона: рост %d/%d" % [Game.run.egg_growth, need]})
		if Game.run.egg_growth >= need:
			Game.run["egg_growth"] = 0
			var up: bool = card_up(c)
			var dragon := _make_board({"uid": c.uid, "id": "dragon", "up": up, "lvl": card_lvl(c)}, 0)
			dragon["locked"] = true
			dragon["innate"] = c.get("innate", false)
			cells[i] = dragon
			events.append({"t": "msg", "text": "Из яйца вылупился Дракон!"})
			Game.hatch_dragon(c.uid, up)


func _gold(n: int, why: String) -> void:
	if n == 0:
		return
	Game.add_gold(n)
	gold_delta += n
	events.append({"t": "gold", "n": n, "text": why})


# ---------------------------------------------------------------- монстры

func _live_monster(idx: int) -> bool:
	if idx < 0 or idx >= corridor_len:
		return false
	var c = cells[idx]
	return c != null and Data.cards[c.id].type == "monster" and c.hp > 0 and not c.disabled and not c.frozen


func monster_atk(idx: int, h) -> int:
	var c = cells[idx]
	var d := def_of(c)
	var a := int(d.get("atk", 0))
	match d.get("special", ""):
		"mimic":
			a = int(h.greed) if h != null else 0
		"wolf":
			for j in corridor_len:
				if j != idx and cells[j] != null and cells[j].id == "wolf" and cells[j].hp > 0:
					a += 10
	for j in corridor_len:
		if j != idx and cells[j] != null and cells[j].id == "lich" and cells[j].hp > 0:
			a += 20
	if c.id in ["wolf", "rat_swarm"] and (_adjacent_has(idx, "pack_leader")):
		a += 10
	if Game.has_relic("blood_ruby"):
		a += 10
	a += int(c.hall_atk)
	if cell_mod(idx) == "blood":
		a += 10
	return a


func _hero_atk_vs(h: Dictionary, c: Dictionary) -> int:
	var a: int = h.atk + 10 * h.rage
	var d: Dictionary = Data.cards[c.id]
	if _has_trait(h, "ratcatcher") and c.id in ["wolf", "rat_swarm"]:
		a *= 2
	if _has_trait(h, "undead_hunter") and d.get("undead", false):
		a *= 2
	return a


func _fight(h: Dictionary, idx: int) -> void:
	var c = cells[idx]
	var d := def_of(c)
	var to_monster := _hero_atk_vs(h, c)
	var to_hero := 0
	if c.freeze_ticks > 0:
		events.append({"t": "blocked", "cell": idx})
	else:
		to_hero = monster_atk(idx, h)
		if _has_trait(h, "tamer") and d.get("draconic", false):
			to_hero = to_hero / 2
	events.append({"t": "fight", "hero": h.uid, "cell": idx})
	_trigger_fx(idx)
	if to_hero > 0:
		_damage(h, to_hero, "monster", c.uid)
		if h.hp > 0 and d.has("on_hit"):
			_run_actions(d.on_hit, h, idx, c)
	_hurt_monster(idx, to_monster, h)


func _hurt_monster(idx: int, n: int, h) -> void:
	var c = cells[idx]
	if c == null or n <= 0:
		return
	c.hp -= n
	events.append({"t": "mdmg", "cell": idx, "n": n})
	if c.hp <= 0:
		_kill_monster(idx, h)


func _kill_monster(idx: int, h) -> void:
	var c = cells[idx]
	if c == null:
		return
	c.hp = 0
	events.append({"t": "mdeath", "cell": idx})
	if Game.location_rule() == "catacombs":
		var n := _next_monster(idx)
		if n >= 0:
			cells[n].hall_atk += 10
	if Game.has_relic("blood_chalice"):
		var n := _next_monster(idx)
		if n >= 0:
			cells[n].hp += 30
			cells[n].max_hp += 30
	for o in _active_heroes():
		if "avenger" in o.mods:
			_heal(o, 30)
	# Возвращение к жизни
	if c.id == "zombie" and not zombie_revived.has(str(c.uid)):
		zombie_revived[str(c.uid)] = true
		c.hp = 30
		events.append({"t": "revive", "cell": idx})
		return
	for j in [idx - 1, idx + 1]:
		if j >= 0 and j < corridor_len and cells[j] != null and cells[j].id == "necro_circle":
			var key := str(cells[j].uid)
			var used := int(hall_state.circle.get(key, 0))
			if used < int(def_of(cells[j]).p):
				hall_state.circle[key] = used + 1
				c.hp = int(ceil(c.max_hp / 2.0))
				events.append({"t": "revive", "cell": idx})
				return
	if Game.run.get("master", "") == "necromancer" and not hall_state.get("necro_used", false):
		hall_state["necro_used"] = true
		c.hp = int(ceil(c.max_hp / 2.0))
		events.append({"t": "revive", "cell": idx})
		return
	var d := def_of(c)
	var to_hand := false
	for a in d.get("death", []):
		if a.a == "return_to_hand":
			to_hand = true
	_remove_card(idx, to_hand)
	if h != null:
		for a in d.get("death", []):
			if a.a == "return_to_hand":
				continue
			if a.a == "gold":
				_gold(int(a.n), d.name)
			elif h.state == "walk":
				_action(a, h, idx, null)


func _remove_card(idx: int, to_hand: bool) -> void:
	var c = cells[idx]
	if c == null:
		return
	cells[idx] = null
	if c.get("innate", false):
		return
	if to_hand:
		hand.append(_strip(c))
		events.append({"t": "msg", "text": Data.card_name(c.id) + " возвращается в руку"})
	else:
		discard.append(_strip(c))


func _next_monster(idx: int) -> int:
	for j in range(idx + 1, corridor_len):
		if _live_monster(j):
			return j
	return -1


func _first_monster() -> int:
	for j in corridor_len:
		if _live_monster(j):
			return j
	return -1


# ---------------------------------------------------------------- конец зала и боя

func _end_hall() -> void:
	events.append({"t": "hall_end", "hall": hall})
	for i in cells.size():
		var c = cells[i]
		if c == null:
			continue
		if c.id == "usurper_crown":
			next_discount = 1
		var d := def_of(c)
		if "permanent" in d.kw and i < corridor_len:
			c.locked = true
			c.once_used = false
			c.once_actions = {}
			c.disabled = false
			c.frozen = false
			c.freeze_ticks = 0
			c.hall_atk = 0
			if d.get("special", "") != "no_heal" and c.hp > 0:
				c.hp = c.max_hp
		else:
			cells[i] = null
			if not c.get("innate", false):
				discard.append(_strip(c))
	for c in hand:
		c.erase("temp_up")
	for h in heroes:
		if h.state in ["dead", "fled"]:
			continue
		h.slow = 0
		if Game.location_rule() != "volcano":
			h.burn = 0
		h.stun = 0
		h.rage = 0
		h.hold = 0
		h.first_hit_done = false
		h.trap_skipped = false
		h.sapper_used = false
		h.disarm_used = false
		h.ignore_cards = 0
		h.smoke_used = false
		h.extra_trait = ""
		if Game.run.get("master", "") == "alchemist":
			h.poison = maxi(0, h.poison - POISON_STEP)
		if h.trait == "boss_pirate" and hall < HALLS - 1:
			var stolen = Game.steal_card()
			if stolen != null:
				_remove_everywhere(int(stolen.uid))
				events.append({"t": "msg", "text": "Мика крадёт карту: " + Data.card_name(stolen.id)})
	var alive := _active_heroes().size() + _count_state("exit")
	hall += 1
	if alive == 0:
		_finish()
		return
	if hall >= HALLS:
		for h in heroes:
			if h.state == "exit" or h.state == "walk" or h.state == "wait":
				_escape(h)
		_finish()
		return
	_begin_prep()


func _escape(h: Dictionary) -> void:
	h.state = "fled"
	var greed: int = h.greed
	var ff: Dictionary = Game.run.floor_flags
	if Game.has_relic("heart_stone") and not ff.get("heart_used", false):
		ff["heart_used"] = true
		greed = int(ceil(greed / 2.0))
	_gold(-greed, h.name + " уносит золото")
	escaped.append({"id": h.id, "name": h.name, "greed": greed})
	if h.curse > 0:
		Game.run["pending_curse"] = int(Game.run.get("pending_curse", 0)) + int(h.curse)
	if h.trait == "ballad":
		ff["bard_bonus"] = int(ff.get("bard_bonus", 0)) + 30
	events.append({"t": "escape", "hero": h.uid, "greed": greed})


func _finish() -> void:
	phase = "done"
	if Game.run.treasury <= 0:
		result = "lose"
	elif killed.size() > 0:
		result = "win"
	else:
		result = "escaped"
	for c in exhausted:
		Game.remove_deck_card(int(c.uid))
	events.append({"t": "end", "result": result})


func _remove_everywhere(uid: int) -> void:
	for pile in [hand, draw_pile, discard]:
		for i in range(pile.size() - 1, -1, -1):
			if int(pile[i].uid) == uid:
				pile.remove_at(i)


# ---------------------------------------------------------------- помощники

func skip_hall() -> void:
	var guard := 0
	var start_hall := hall
	while phase == "walk" and hall == start_hall and guard < 2000:
		tick()
		guard += 1


func _active_heroes() -> Array:
	var out := []
	for h in heroes:
		if h.state in ["wait", "walk"]:
			out.append(h)
	return out


func _count_state(s: String) -> int:
	var n := 0
	for h in heroes:
		if h.state == s:
			n += 1
	return n


func hero_by_uid(uid) -> Dictionary:
	for h in heroes:
		if int(h.uid) == int(uid):
			return h
	return {}


func _has_trait(h: Dictionary, t: String) -> bool:
	if h.stun > 0:
		return false
	return h.trait == t or h.extra_trait == t


func _occupied() -> Array:
	var out := []
	for i in corridor_len:
		if cells[i] != null:
			out.append(i)
	return out


func _adjacent_has(idx: int, id: String) -> bool:
	for j in [idx - 1, idx + 1]:
		if j >= 0 and j < corridor_len and cells[j] != null and cells[j].id == id and not cells[j].disabled:
			return true
	return false


func _adjacent_type(idx: int, type: String) -> bool:
	for j in [idx - 1, idx + 1]:
		if j >= 0 and j < corridor_len and cells[j] != null and Data.cards[cells[j].id].type == type:
			return true
	return false


func _catalyst_near(h: Dictionary) -> bool:
	for i in [h.pos - 1, h.pos, h.pos + 1]:
		if i >= 0 and i < corridor_len and cells[i] != null and cells[i].id == "catalyst" and not cells[i].disabled and not cells[i].frozen:
			return true
	return false


func _has_damage(actions: Array) -> bool:
	for a in actions:
		if a.a == "damage":
			return true
	return false


func _has_burn_effect(c: Dictionary) -> bool:
	var d := def_of(c)
	for key in ["enter", "ambush", "on_hit", "death"]:
		for a in d.get(key, []):
			if a.a == "burn":
				return true
	return false


func _trigger_fx(idx: int) -> void:
	_tick_triggers += 1
	events.append({"t": "trig", "cell": idx})


func _status(h: Dictionary, text: String) -> void:
	events.append({"t": "status", "hero": h.uid, "text": text})


func _msg(h: Dictionary, text: String) -> void:
	events.append({"t": "status", "hero": h.uid, "text": text})
