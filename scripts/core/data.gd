extends Node
## Загружает все игровые таблицы из data/*.json и даёт к ним быстрый доступ.

const TYPE_NAMES := {"trap": "Ловушка", "monster": "Монстр", "room": "Комната", "spell": "Заклинание"}
const TYPE_COLORS := {"trap": Color("#8a8a8a"), "monster": Color("#c03a3a"), "room": Color("#8a4ac0"), "spell": Color("#3a6ac8")}
const RARITY_NAMES := {"common": "Обычная", "rare": "Редкая", "epic": "Эпическая", "legendary": "Легендарная", "special": "Особая"}
const RARITY_COLORS := {"common": Color("#b0b0b0"), "rare": Color("#4a9ae0"), "epic": Color("#b060e0"), "legendary": Color("#f0a020"), "special": Color("#60c0a0")}
const RARITY_PRICE := {"common": 8, "rare": 14, "epic": 22, "legendary": 35, "special": 8}
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
	_cdef_cache[key] = d
	return d


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


func card_text(id: String, up: bool = false) -> String:
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


## Что даёт следующий уровень коллекции: «Урон: 3 → 4».
func level_changes(id: String, from_lvl: int, to_lvl: int) -> Array:
	return def_changes(cdef(id, false, from_lvl), cdef(id, false, to_lvl))


## Короткая сводка силы карты на уровне: «Урон 4 · HP 8».
func level_summary(id: String, up: bool, lvl: int) -> String:
	if lvl <= 1:
		return ""
	var parts := []
	for line in def_changes(cdef(id, up, 1), cdef(id, up, lvl)):
		var s: String = line
		parts.append(s.split(":")[0] + " " + s.split("→ ")[-1])
	return " · ".join(parts)


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
