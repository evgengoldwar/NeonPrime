extends Node
## Загружает все игровые таблицы из data/*.json и даёт к ним быстрый доступ.

const TYPE_NAMES := {"trap": "Ловушка", "monster": "Монстр", "room": "Комната", "spell": "Заклинание"}
const TYPE_COLORS := {"trap": Color("#8a8a8a"), "monster": Color("#c03a3a"), "room": Color("#8a4ac0"), "spell": Color("#3a6ac8")}
const RARITY_NAMES := {"common": "Обычная", "rare": "Редкая", "epic": "Эпическая", "legendary": "Легендарная", "special": "Особая"}
const RARITY_COLORS := {"common": Color("#b0b0b0"), "rare": Color("#4a9ae0"), "epic": Color("#b060e0"), "legendary": Color("#f0a020"), "special": Color("#60c0a0")}
const RARITY_PRICE := {"common": 80, "rare": 140, "epic": 220, "legendary": 350, "special": 80}
const FLOOR_MULT := [1.0, 1.6, 2.4]
const KEYWORDS := {
	"Вход": "Срабатывает, когда герой заходит на клетку",
	"Выход": "Срабатывает, когда герой покидает клетку",
	"Аура": "Срабатывает каждый тик, пока герой на этой или соседней клетке",
	"Засада": "Монстр бьёт героя 1 раз сразу при входе, до обмена ударами",
	"Смерть": "Срабатывает, когда погибает этот Монстр",
	"Однократно": "Срабатывает 1 раз за зал",
	"Постоянная": "Не уходит в сброс в конце зала, остаётся на клетке до конца боя",
	"Сжечь": "После розыгрыша удаляется из колоды до конца забега",
	"Замедление": "Герой проводит на каждой клетке 1 + N тиков. Снимается в конце зала",
	"Страх": "Герой отходит на 1 клетку назад и снова активирует её «Вход»",
	"Яд": "В начале тика N урона, затем N уменьшается на 1. Переходит между залами",
	"Горение": "В начале тика N урона, не уменьшается. Снимается в конце зала",
	"Уязвимость": "Следующий удар по герою наносит +50% урона",
	"Оглушение": "Черта героя не работает до конца зала",
	"Проклятие": "Если герой сбежит, следующий герой начнёт с −N HP",
}

var cards := {}
var card_list := []
var classes := {}
var locals := {}
var bosses := {}
var chosen := {}
var elite_mods := []
var squads := []
var locations := {}
var location_list := []
var relics := {}
var relic_list := []
var masters := {}
var master_list := []
var events := {}
var event_list := []
var wings := []
var upgrades := []
var collections := []
var notoriety := []
var achievements := []
var prog := {}            # прогрессия коллекции: data/meta.json

var _cdef_cache := {}


func _ready() -> void:
	card_list = load_json("res://data/cards.json")
	for c in card_list:
		cards[c.id] = c
	var h = load_json("res://data/heroes.json")
	for x in h.classes:
		x["kind"] = "class"
		classes[x.id] = x
	for x in h.locals:
		x["kind"] = "local"
		locals[x.id] = x
	for x in h.bosses:
		x["kind"] = "boss"
		bosses[x.id] = x
	chosen = h.chosen
	chosen["kind"] = "boss"
	elite_mods = h.elite_mods
	squads = h.squads
	var w = load_json("res://data/world.json")
	location_list = w.locations
	for x in location_list:
		locations[x.id] = x
	relic_list = w.relics
	for x in relic_list:
		relics[x.id] = x
	master_list = w.masters
	for x in master_list:
		masters[x.id] = x
	event_list = w.events
	for x in event_list:
		events[x.id] = x
	wings = w.wings
	upgrades = w.upgrades
	collections = w.collections
	notoriety = w.notoriety
	achievements = w.achievements
	prog = load_json("res://data/meta.json")


func load_json(path: String):
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		push_error("Не удалось открыть " + path)
		return null
	var parsed = JSON.parse_string(f.get_as_text())
	if parsed == null:
		push_error("Ошибка JSON в " + path)
	return normalize(parsed)


## JSON отдаёт все числа как float. Целые превращаем обратно в int.
static func normalize(v):
	if v is Dictionary:
		for k in v.keys():
			v[k] = normalize(v[k])
		return v
	if v is Array:
		for i in v.size():
			v[i] = normalize(v[i])
		return v
	if v is float and is_equal_approx(v, round(v)) and absf(v) < 1e15:
		return int(v)
	return v


## Определение карты с учётом улучшения «+».
## Определение карты с учётом улучшения «+» и уровня коллекции.
func cdef(id: String, up: bool = false, lvl: int = 1) -> Dictionary:
	var key := "%s%s@%d" % [id, "+" if up else "", lvl]
	if _cdef_cache.has(key):
		return _cdef_cache[key]
	var base: Dictionary = cards.get(id, {})
	var d := base.duplicate(true)
	if up and base.has("up"):
		for k in base.up.keys():
			d[k] = base.up[k].duplicate(true) if base.up[k] is Array or base.up[k] is Dictionary else base.up[k]
	d["is_up"] = up
	d["lvl"] = lvl
	if not d.has("kw"):
		d["kw"] = []
	if lvl > 1:
		_scale_def(d, lvl)
		if is_utility(id):
			_utility_bonus(d, lvl)
	_cdef_cache[key] = d
	return d


## Утилитарная карта (Замедление, Страх, добор…) растёт иначе: каждый уровень
## добавляет урон при Входе (Ловушки и Комнаты) или золото в Казну (Заклинания).
func _utility_bonus(d: Dictionary, lvl: int) -> void:
	var ub: Dictionary = prog.get("utility_bonus", {"damage": 5, "gold": 10})
	if d.type == "spell":
		var g := int(ub.gold) * (lvl - 1)
		d["play"] = d.get("play", []) + [{"a": "gold", "n": g}]
		d["lvl_bonus"] = {"a": "gold", "n": g}
	else:
		var n := int(ub.damage) * (lvl - 1)
		d["enter"] = d.get("enter", []) + [{"a": "damage", "n": n}]
		d["lvl_bonus"] = {"a": "damage", "n": n}


## Действия, числа которых растут с уровнем. Замедление, Страх, Тьма и добор не растут:
## иначе экспоненциальные комбо (Шипы ×2 за стак) ломаются.
const SCALED_ACTIONS := ["damage", "poison", "burn", "curse", "greed", "gold", "monsters_hp"]


func level_factor(lvl: int) -> float:
	return 1.0 + float(prog.get("level_bonus", 0.15)) * (lvl - 1)


func _scaled(n: int, lvl: int) -> int:
	return maxi(n, int(round(n * level_factor(lvl))))


func _scale_def(d: Dictionary, lvl: int) -> void:
	for k in ["hp", "atk"]:
		if int(d.get(k, 0)) > 0:
			d[k] = _scaled(int(d[k]), lvl)
	if d.get("special", "") in ["dark_altar", "cauldron"]:
		d["p"] = _scaled(int(d.p), lvl)
	for key in ["enter", "exit", "aura", "play", "on_hit", "ambush", "death"]:
		for a in d.get(key, []):
			if a.a in SCALED_ACTIONS and int(a.get("n", 0)) > 0:
				a["n"] = _scaled(int(a.n), lvl)


func card_name(id: String, up: bool = false) -> String:
	return cards.get(id, {}).get("name", id) + ("+" if up else "")


## Текст карты. С уровнем выше 1 числа в тексте уже усилены: «Яд 4» → «Яд 5».
func card_text(id: String, up: bool = false, lvl: int = 1) -> String:
	var t := _base_text(id, up)
	if lvl <= 1:
		return t
	var rest := []
	for ch in _level_pairs(cdef(id, up, 1), cdef(id, up, lvl)):
		var swapped := _swap_num(t, int(ch[1]), int(ch[2]), NUM_WORDS.get(ch[0], []))
		if swapped == "" and not ch[0] in ["hp", "atk"]:   # HP и Атака видны на значках монстра
			rest.append("%s %d" % [ACTION_NAMES.get(ch[0], ch[0]), int(ch[2])])
		elif swapped != "":
			t = swapped
	if not rest.is_empty():
		t += "\n(Ур.%d: %s)" % [lvl, ", ".join(rest)]
	var lb: Dictionary = cdef(id, up, lvl).get("lvl_bonus", {})
	if not lb.is_empty():
		t += ("\n+%d урона при Входе" if lb.a == "damage" else "\n+%d золота в Казну") % int(lb.n)
	return t


## Слова, рядом с которыми в тексте карты стоит число этого параметра.
const NUM_WORDS := {
	"damage": ["урона", "Засада"], "poison": ["Яд"], "burn": ["Горение"], "curse": ["Проклятие"],
	"greed": ["Жадность героя", "Жадность"], "gold": ["золота"], "monsters_hp": ["HP"],
	"hp": ["HP"], "atk": ["Атака"], "dark_altar": ["урона"], "cauldron": ["золота"],
}


## Пары [параметр, было, стало] для чисел, которые поменял уровень.
func _level_pairs(a: Dictionary, b: Dictionary) -> Array:
	var out := []
	for k in ["hp", "atk"]:
		if a.has(k) and a.get(k) != b.get(k):
			out.append([k, int(a[k]), int(b[k])])
	var sp: String = a.get("special", "")
	if sp in ["dark_altar", "cauldron"] and a.get("p") != b.get("p"):
		out.append([sp, int(a.p), int(b.p)])
	for key in ["enter", "exit", "aura", "play", "on_hit", "ambush", "death"]:
		var la: Array = a.get(key, [])
		var lb: Array = b.get(key, [])
		for i in mini(la.size(), lb.size()):
			if la[i].get("a") == lb[i].get("a") and la[i].get("n") != lb[i].get("n"):
				out.append([la[i].a, int(la[i].get("n", 0)), int(lb[i].get("n", 0))])
	return out


## Заменяет первое число old рядом с одним из слов на new. "" — не нашлось.
func _swap_num(text: String, old: int, new: int, words: Array) -> String:
	var o := str(old)
	for w in words:
		for pat in [w + " " + o, w + " +" + o, o + " " + w, "+" + o + " " + w]:
			var pt: String = pat
			var i := text.find(pt)
			while i >= 0:
				var before_ok := i == 0 or not text[i - 1].is_valid_int() or not pt[0].is_valid_int()
				var end := i + pt.length()
				var after_ok := end >= text.length() or not text[end].is_valid_int() or not pt[pt.length() - 1].is_valid_int()
				if before_ok and after_ok:
					return text.substr(0, i) + pt.replace(o, str(new)) + text.substr(end)
				i = text.find(pt, i + 1)
	return ""


func _base_text(id: String, up: bool) -> String:
	var c: Dictionary = cards.get(id, {})
	if up and c.get("text_up", "") != "":
		var t: String = c.text_up
		# Короткие пометки вроде «Стоит 0» дополняем основным текстом.
		if t.begins_with("Стоит"):
			return c.text
		if t.length() < 14:
			return c.text + "\n(+: " + t + ")"
		return t
	return c.get("text", "")


const ACTION_NAMES := {
	"damage": "Урон", "slow": "Замедление", "poison": "Яд", "burn": "Горение", "curse": "Проклятие",
	"greed": "Жадность", "hold": "Задержка", "dark": "Тьма", "draw": "Взять карт", "monsters_hp": "HP Монстрам",
	"gold": "Золото", "knockback": "Отбрасывание",
}


## Что меняет улучшение «+»: список строк вида «Стоимость: 1 → 0».
func upgrade_changes(id: String, lvl: int = 1) -> Array:
	var a := cdef(id, false, lvl)
	var b := cdef(id, true, lvl)
	var out := def_changes(a, b)
	var simple := _same_shape(a, b)
	var p_changed: bool = a.get("p") != b.get("p") and not a.get("special", "") in ["dark_altar", "cauldron"]
	if p_changed or not simple or out.is_empty():
		var t: String = cards.get(id, {}).get("text_up", "")
		if t != "" and not t.begins_with("Стоит"):
			out.append(t)
	return out


## Утилитарная карта: в ней нет чисел, которые растут с уровнем (Замедление, Страх, добор…).
func is_utility(id: String) -> bool:
	var c: Dictionary = cards.get(id, {})
	if c.is_empty() or int(c.get("hp", 0)) > 0 or int(c.get("atk", 0)) > 0:
		return false
	if c.get("special", "") in ["dark_altar", "cauldron"]:
		return false
	for key in ["enter", "exit", "aura", "play", "on_hit", "ambush", "death"]:
		for a in c.get(key, []):
			if a.a in SCALED_ACTIONS and int(a.get("n", 0)) > 0:
				return false
	return true


## Что даёт следующий уровень коллекции: «Урон: 3 → 4».
func level_changes(id: String, from_lvl: int, to_lvl: int) -> Array:
	return def_changes(cdef(id, false, from_lvl), cdef(id, false, to_lvl))


func _same_shape(a: Dictionary, b: Dictionary) -> bool:
	for key in ["enter", "exit", "aura", "play", "on_hit", "ambush", "death"]:
		var la: Array = a.get(key, [])
		var lb: Array = b.get(key, [])
		if la.size() != lb.size():
			return false
		for i in la.size():
			if la[i].get("a") != lb[i].get("a"):
				return false
	return true


## Разница двух определений карты в виде строк «Название: было → стало».
func def_changes(a: Dictionary, b: Dictionary) -> Array:
	var out := []
	var ba: Dictionary = a.get("lvl_bonus", {})
	var bb: Dictionary = b.get("lvl_bonus", {})
	if int(ba.get("n", 0)) != int(bb.get("n", 0)):
		var nm := "Урон при Входе" if bb.get("a", ba.get("a", "")) == "damage" else "Золото в Казну"
		out.append("%s: %d → %d" % [nm, int(ba.get("n", 0)), int(bb.get("n", 0))])
	for pair in [["cost", "Стоимость"], ["hp", "Здоровье"], ["atk", "Атака"]]:
		if a.has(pair[0]) and a.get(pair[0]) != b.get(pair[0]):
			out.append("%s: %d → %d" % [pair[1], int(a[pair[0]]), int(b[pair[0]])])
	if a.get("special", "") in ["dark_altar", "cauldron"] and a.get("p") != b.get("p"):
		out.append("%s: %d → %d" % ["Бонус" if a.special == "dark_altar" else "Золото", int(a.p), int(b.p)])
	for key in ["enter", "exit", "aura", "play", "on_hit", "ambush", "death"]:
		var la: Array = a.get(key, [])
		var lb: Array = b.get(key, [])
		if la.size() != lb.size():
			continue
		for i in la.size():
			var x: Dictionary = la[i]
			var y: Dictionary = lb[i]
			if x.get("a") != y.get("a"):
				continue
			if x.get("n") != y.get("n"):
				out.append("%s: %d → %d" % [ACTION_NAMES.get(x.a, x.a), int(x.get("n", 0)), int(y.get("n", 0))])
			elif x.get("if_greed") != y.get("if_greed"):
				out.append("Порог Жадности: %d → %d" % [int(x.if_greed), int(y.if_greed)])
	return out


func hero_def(id: String) -> Dictionary:
	if classes.has(id):
		return classes[id]
	if locals.has(id):
		return locals[id]
	if bosses.has(id):
		return bosses[id]
	if id == "chosen":
		return chosen
	return {}


func elite_mod(id: String) -> Dictionary:
	for m in elite_mods:
		if m.id == id:
			return m
	return {}


func keyword_help(text: String) -> String:
	var out := []
	for k in KEYWORDS.keys():
		if text.find(k) != -1:
			out.append(k + ": " + KEYWORDS[k])
	return "\n".join(out)
