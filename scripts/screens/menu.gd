extends Control
## Главное меню в стиле Clash Royale: верхняя панель (уровень, золото, кристаллы),
## вкладки внизу (Магазин · Колода · Бой · Замок · Трофеи), сундуки с таймерами.

const UI := preload("res://scripts/ui/ui.gd")
const Battle := preload("res://scripts/core/battle.gd")
const TABS := [
	["shop", "Магазин", "icons/tab_shop"],
	["deck", "Карты", "icons/tab_deck"],
	["home", "Бой", "icons/tab_battle"],
	["castle", "Замок", "icons/tab_castle"],
	["trophies", "Трофеи", "icons/tab_trophy"],
]
const RARITY_ORDER := {"legendary": 0, "epic": 1, "rare": 2, "common": 3}

static var tab := "home"

const TIPS := [
	"Слизь перед Шипами: каждое Замедление удваивает урон Шипов.",
	"Призрак повторяет «Вход» карты на клетке перед ним.",
	"Яд и Горение на одном герое дают Взрыв — Яд бьёт ещё раз.",
	"Комбо ×4 даёт +1 Тьму в следующем зале, ×6 — лишнюю карту.",
	"Ловушка на Ловчей яме срабатывает дважды — ставь туда самую сильную.",
	"Источник лечит героя: не оставляй на его пути слабые карты.",
	"Что осталось в Казне после победы — твоё золото для прокачки.",
	"Сундуки открываются по одному: ставь на ночь самый долгий.",
	"Коснись карты или клетки в бою, чтобы прочитать описание.",
	"Хозяин даёт +1 уровень картам своего крыла.",
]

var _top: Control
var _content: Control
var _tabbar: HBoxContainer
var _top_sig := ""
var _timers := []          # [{"label": Label, "kind": String, "slot": int, "state": String}]
var _master_idx := 0


func _ready() -> void:
	Sfx.music(1.0)
	Progress.ensure()
	_master_idx = Data.master_list.size() if str(Game.meta.master_pick) == "final" \
		else maxi(0, _master_ids().find(str(Game.meta.master_pick)))
	UI.backdrop(self, "tiles/wall_menu", 0.35)
	var m := MarginContainer.new()
	m.anchor_left = 0.5
	m.anchor_right = 0.5
	m.anchor_bottom = 1.0
	m.offset_left = -UI.COLUMN / 2.0
	m.offset_right = UI.COLUMN / 2.0
	for side in ["left", "right", "top", "bottom"]:
		m.add_theme_constant_override("margin_" + side, 10)
	add_child(m)
	var v := UI.vbox(8)
	m.add_child(v)
	_top = UI.vbox(0)
	v.add_child(_top)
	_content = Control.new()
	_content.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_content.clip_contents = true
	v.add_child(_content)
	_tabbar = UI.hbox(4)
	v.add_child(_tabbar)
	_build_top()
	_show(tab)
	var t := Timer.new()
	t.wait_time = 1.0
	t.autostart = true
	t.timeout.connect(_tick)
	add_child(t)
	if CrashLog.crashed_last_time and not CrashLog.report_shown:
		CrashLog.report_shown = true
		_show_crash_report.call_deferred()


# ================================================================ верхняя панель

func _sig() -> String:
	return "%d|%d|%d|%d|%d" % [int(Game.meta.gold), int(Game.meta.gems), int(Game.meta.souls), int(Game.meta.plevel), int(Game.meta.xp)]


func _build_top() -> void:
	for ch in _top.get_children():
		ch.queue_free()
	_top_sig = _sig()
	var p := UI.framed("panel_dark", 8)
	_top.add_child(p)
	var h := UI.hbox(14)
	p.add_child(h)
	var lv := UI.vbox(2)
	var badge := PanelContainer.new()
	badge.add_theme_stylebox_override("panel", UI.style(Color("#2a6fb8"), 0, UI.INK, 3, 6))
	badge.add_child(UI.label("Ур. %d" % int(Game.meta.plevel), 24, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER, false))
	lv.add_child(badge)
	lv.add_child(UI.progress_bar(int(Game.meta.xp), Progress.xp_need(), 110, UI.SOUL, "%d/%d" % [int(Game.meta.xp), Progress.xp_need()], 20))
	UI.ignore_mouse(lv)
	lv.mouse_filter = Control.MOUSE_FILTER_STOP
	lv.gui_input.connect(_level_input)
	h.add_child(lv)
	var sp := UI.spacer(0)
	sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(sp)
	h.add_child(UI.stat("coin", str(int(Game.meta.gold)), UI.GOLD, 32))
	h.add_child(UI.stat("gem", str(int(Game.meta.gems)), UI.GREEN, 32))
	h.add_child(UI.stat("soul", str(int(Game.meta.souls)), UI.SOUL, 32))
	h.add_child(UI.icon_button("icons/gear", func(): Game.main.goto("settings"), 5, 64))


func _level_input(ev: InputEvent) -> void:
	if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
		Sfx.play("click")
		_level_help()


## Что даёт уровень игрока и как его поднять.
func _level_help() -> void:
	var lvl := int(Game.meta.plevel)
	var per := int(Data.prog.player_level_treasury)
	var p := UI.popup(self, "Уровень игрока %d" % lvl)
	p.box.add_child(UI.label("Каждый уровень после первого: +%d к стартовой Казне в каждом забеге." % per, 22, UI.TEXT))
	p.box.add_child(UI.stat("coin", "Сейчас: +%d к Казне" % Progress.treasury_bonus(), UI.GOLD, 26))
	p.box.add_child(UI.stat("coin", "На уровне %d: +%d к Казне" % [lvl + 1, Progress.treasury_bonus() + per], UI.GREEN, 22))
	p.box.add_child(UI.center(UI.progress_bar(int(Game.meta.xp), Progress.xp_need(), 520, UI.SOUL, "Опыт: %d/%d" % [int(Game.meta.xp), Progress.xp_need()], 32)))
	var xp: Array = Data.prog.upgrade_xp
	var parts := []
	for i in xp.size():
		parts.append("до ур.%d — %d" % [i + 2, int(xp[i])])
	p.box.add_child(UI.label("Опыт дают улучшения карт во вкладке «Карты»:\n" + ", ".join(parts) + ".", 20, UI.DIM))


func _build_tabs() -> void:
	for ch in _tabbar.get_children():
		ch.queue_free()
	for t in TABS:
		var sel: bool = t[0] == tab
		var b := UI.button("", _on_tab.bind(t[0]), 16, 104 if sel else 92)
		b.size_flags_stretch_ratio = 1.4 if sel else 1.0
		b.size_flags_vertical = Control.SIZE_SHRINK_END
		if sel:
			UI.tint_button(b, UI.GOLD)
		var bv := UI.vbox(0)
		UI.full(bv)
		bv.alignment = BoxContainer.ALIGNMENT_CENTER
		bv.add_child(UI.center(UI.icon(t[2], 6 if sel else 5)))
		bv.add_child(UI.label(t[1], 16, UI.GOLD if sel else UI.TEXT, HORIZONTAL_ALIGNMENT_CENTER, false))
		UI.ignore_mouse(bv)
		bv.mouse_filter = Control.MOUSE_FILTER_IGNORE
		b.add_child(bv)
		if t[0] == "deck" and _upgradable_count() > 0:
			var dot := UI.label("!", 24, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER, false)
			dot.add_theme_color_override("font_outline_color", UI.RED)
			dot.add_theme_constant_override("outline_size", 12)
			dot.position = Vector2(8, 2)
			dot.mouse_filter = Control.MOUSE_FILTER_IGNORE
			b.add_child(dot)
		_tabbar.add_child(b)


func _on_tab(id: String) -> void:
	_show(id)


func _show(id: String) -> void:
	tab = id
	_timers = []
	for ch in _content.get_children():
		ch.queue_free()
	match id:
		"home":
			_home()
		"deck":
			_deck()
		"shop":
			_shop()
		"castle", "trophies":
			var s: Control = load("res://scripts/screens/%s.gd" % id).new()
			s.set("embedded", true)
			UI.full(s)
			_content.add_child(s)
	_build_tabs()


## Прокручиваемая страница во вкладке.
func _page() -> VBoxContainer:
	var sc := UI.scroll()
	UI.full(sc)
	_content.add_child(sc)
	var body := UI.vbox(12)
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	sc.add_child(body)
	return body


func _section(text: String, color: Color = UI.GOLD) -> Label:
	var l := UI.label(text, 24, color)
	l.add_theme_font_override("font", UI.pixel_font())
	l.add_theme_font_size_override("font_size", UI.pfs(20))
	return l


func _tick() -> void:
	if _sig() != _top_sig:
		_build_top()
	for t in _timers:
		var l: Label = t.label
		if not is_instance_valid(l):
			continue
		match t.kind:
			"slot":
				var st := Progress.chest_state(int(t.slot))
				if st != t.state:
					_show(tab)
					return
				if st == "unlocking":
					l.text = Progress.format_time(Progress.time_left(int(t.slot)))
			"free":
				var left := Progress.free_chest_left()
				if (left == 0) != (t.state == "ready"):
					_show(tab)
					return
				l.text = "Бесплатный сундук" if left == 0 else "Бесплатный через " + Progress.format_time(left)
			"shop":
				l.text = "Обновится через " + Progress.format_time(Progress.shop_seconds_left())


# ================================================================ вкладка «Бой»

func _master_ids() -> Array:
	var out := []
	for m in Data.master_list:
		out.append(m.id)
	return out


func _home() -> void:
	var body := _page()
	var final := _is_final()
	body.add_child(_final_panel() if final else _master_panel())
	if Game.has_run():
		var cont := UI.button("Продолжить забег", func(): Game.main.goto(Game.resume_screen()), 28, 80)
		UI.tint_button(cont, UI.GREEN)
		body.add_child(cont)
	var go := UI.button("В БОЙ!", _final_battle if final else _battle, 44, 116)
	go.add_theme_font_override("font", UI.pixel_font())
	go.add_theme_font_size_override("font_size", UI.pfs(36))
	go.disabled = not Game.final_unlocked() if final else not Game.master_unlocked(Data.master_list[_master_idx].id)
	UI.tint_button(go, UI.RED if final else UI.GOLD)
	body.add_child(go)
	var tip := UI.label("Совет: " + TIPS[int(Time.get_unix_time_from_system() / 20) % TIPS.size()], 18, UI.DIM, HORIZONTAL_ALIGNMENT_CENTER)
	body.add_child(tip)
	body.add_child(UI.spacer(0, true))
	body.add_child(_section("Сундуки"))
	var slots := UI.hbox(6)
	for i in Game.meta.chests.size():
		slots.add_child(_slot_view(i))
	body.add_child(slots)
	var row := UI.hbox(8)
	var free_ready := Progress.free_chest_left() == 0
	var fb := UI.button("", _claim_free, 20, 72)
	if free_ready:
		UI.tint_button(fb, UI.GREEN)
	var fl := UI.label("", 20, UI.TEXT, HORIZONTAL_ALIGNMENT_CENTER)
	UI.full(fl)
	fl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	fl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fl.text = "Бесплатный сундук" if free_ready else "Бесплатный через " + Progress.format_time(Progress.free_chest_left())
	fb.add_child(fl)
	_timers.append({"label": fl, "kind": "free", "slot": -1, "state": "ready" if free_ready else "wait"})
	row.add_child(fb)
	row.add_child(UI.button("Ежедневное подземелье", func(): Game.main.goto("daily"), 20, 72))
	body.add_child(row)
	body.add_child(UI.label("ЗАБЕГОВ %d · ПОБЕД %d · УБИТО %d" % [int(Game.meta.runs), int(Game.meta.wins), int(Game.meta.kills)], 16, UI.DIM, HORIZONTAL_ALIGNMENT_CENTER))


func _master_panel() -> Control:
	var m: Dictionary = Data.master_list[_master_idx]
	var unlocked: bool = Game.master_unlocked(m.id)
	var p := UI.framed("popup" if unlocked else "panel", 10)
	var v := UI.vbox(8)
	p.add_child(v)
	# Шапка: стрелки, портрет, имя и правила Хозяина.
	var nav := UI.hbox(8)
	v.add_child(nav)
	nav.add_child(_arrow("<", -1))
	var spr := UI.icon("masters/" + str(m.id), 10)
	spr.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	if not unlocked:
		spr.modulate = Color(0, 0, 0, 0.85)
	nav.add_child(spr)
	var info := UI.vbox(2)
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var nm := UI.label(m.name, 28, UI.GOLD, HORIZONTAL_ALIGNMENT_LEFT)
	nm.add_theme_font_override("font", UI.pixel_font())
	nm.add_theme_font_size_override("font_size", UI.pfs(24))
	info.add_child(nm)
	info.add_child(UI.label("%d / %d" % [_master_idx + 1, Data.master_list.size() + 1], 16, UI.DIM))
	if unlocked:
		info.add_child(UI.label(m.passive_text, 18, UI.TEXT))
		info.add_child(UI.label(Data.prog.affinity.get(m.id, {}).get("text", ""), 16, UI.GREEN))
	else:
		var wing: Dictionary = {}
		for w in Data.wings:
			if w.id == m.unlock:
				wing = w
		info.add_child(UI.label("Закрыт: открой крыло «%s» во вкладке Замок за %d Душ" % [wing.get("name", "?"), int(wing.get("cost", 0))], 18, UI.RED))
	nav.add_child(info)
	nav.add_child(_arrow(">", 1))
	# Колода Хозяина одной строкой значков.
	var dh := UI.hbox(8)
	var dl := UI.label("Колода Хозяина · коснись карты", 16, UI.DIM)
	dl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	dh.add_child(dl)
	dh.add_child(UI.stat("coin", "Казна %d" % (int(m.treasury) + Progress.treasury_bonus()), UI.GOLD, 18))
	v.add_child(dh)
	var row := UI.hbox(4)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	for id in m.deck:
		row.add_child(_deck_tile(id, Game.card_level_for(id, m.id)))
	v.add_child(row)
	if unlocked:
		v.add_child(_notoriety_row(m.id))
	return p


# ---------------------------------------------------------------- финальный бой

func _conquered_count() -> int:
	var n := 0
	for m in Data.master_list:
		if Game.master_conquered(m.id):
			n += 1
	return n


func _is_final() -> bool:
	return _master_idx >= Data.master_list.size()


## Седьмая страница карусели: Солнечный Император, что нужно для открытия и колода финала.
func _final_panel() -> Control:
	var open := Game.final_unlocked()
	var p := UI.framed("card_selected" if open else "panel", 10)
	var v := UI.vbox(8)
	p.add_child(v)
	var nav := UI.hbox(8)
	v.add_child(nav)
	nav.add_child(_arrow("<", -1))
	var spr := UI.hero_icon("emperor", 10)
	spr.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	if not open:
		spr.modulate = Color(0, 0, 0, 0.85)
	nav.add_child(spr)
	var info := UI.vbox(2)
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var nm := UI.label("Финальный бой", 28, UI.GOLD, HORIZONTAL_ALIGNMENT_LEFT)
	nm.add_theme_font_override("font", UI.pixel_font())
	nm.add_theme_font_size_override("font_size", UI.pfs(24))
	info.add_child(nm)
	info.add_child(UI.label("%d / %d" % [_master_idx + 1, Data.master_list.size() + 1], 16, UI.DIM))
	info.add_child(UI.label("%s: один бой из %d этапов и 3 фаз" % [Data.final_boss.name, Battle.FINAL_STAGES.size()], 18, UI.TEXT))
	if open:
		var wins := int(Game.meta.get("final_wins", 0))
		info.add_child(UI.label("Открыт! " + ("Побед: %d" % wins if wins > 0 else "Рассвет ждёт тебя"), 16, UI.GREEN))
	else:
		info.add_child(UI.label("Закрыт: победи на Дурной славе 10 за каждого Хозяина (%d/%d)" % [_conquered_count(), Data.master_list.size()], 16, UI.RED))
	nav.add_child(info)
	nav.add_child(_arrow(">", 1))
	# Прогресс открытия: по плашке на Хозяина
	var grid := GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 6)
	grid.add_theme_constant_override("v_separation", 6)
	for m in Data.master_list:
		var done := Game.master_conquered(m.id)
		var cell := UI.framed("panel_dark", 4)
		cell.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var h := UI.hbox(6)
		cell.add_child(h)
		var mi := UI.icon("masters/" + str(m.id), 3)
		if not Game.master_unlocked(m.id):
			mi.modulate = Color(0, 0, 0, 0.85)
		h.add_child(mi)
		var txt := "ГОТОВО" if done else ("закрыт" if not Game.master_unlocked(m.id) else "%d/10" % maxi(0, Game.notoriety_won(m.id)))
		var l := UI.label(txt, 20, UI.GREEN if done else (UI.RED if txt == "закрыт" else UI.DIM), HORIZONTAL_ALIGNMENT_LEFT, false)
		l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		h.add_child(l)
		grid.add_child(cell)
	v.add_child(grid)
	# Колода финала: 20 лучших карт в две строки
	var dh := UI.hbox(8)
	var dl := UI.label("Колода финала · все карты «+» · коснись карты", 16, UI.DIM)
	dl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	dh.add_child(dl)
	dh.add_child(UI.stat("coin", "Казна %d" % Game.FINAL_TREASURY, UI.GOLD, 18))
	v.add_child(dh)
	var half: int = (Game.FINAL_DECK.size() + 1) / 2
	for r in 2:
		var row := UI.hbox(4)
		row.alignment = BoxContainer.ALIGNMENT_CENTER
		for k in range(r * half, mini((r + 1) * half, Game.FINAL_DECK.size())):
			var id: String = Game.FINAL_DECK[k]
			row.add_child(_deck_tile(id, Game.card_level_for(id, "")))
		v.add_child(row)
	var more := UI.button("Этапы, фазы и условия", _final_popup, 22, 60)
	v.add_child(more)
	return p


func _final_battle() -> void:
	if Game.has_run():
		var p := UI.popup(self, "Начать финальный бой?", "Отмена")
		p.box.add_child(UI.label("Текущий забег будет потерян.", 22))
		p.box.add_child(UI.tint_button(UI.button("Сразиться", _start_final), UI.RED))
		return
	_start_final()


func _final_popup() -> void:
	var open := Game.final_unlocked()
	var p := UI.popup(self, "Финальный бой")
	var box: VBoxContainer = p.box
	var head := UI.hbox(14)
	var port := UI.framed("card_monster", 8)
	var ic := UI.hero_icon("emperor", 8)
	if not open:
		ic.modulate = Color(0.35, 0.3, 0.4)
	port.add_child(ic)
	port.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	head.add_child(port)
	var hv := UI.vbox(6)
	hv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var nm := UI.label(Data.final_boss.name, 24, UI.GOLD)
	nm.add_theme_font_override("font", UI.pixel_font())
	nm.add_theme_font_size_override("font_size", 24)
	hv.add_child(nm)
	hv.add_child(UI.label("«%s»" % Data.final_boss.quote, 20, UI.DIM))
	head.add_child(hv)
	box.add_child(head)
	# Условия открытия по каждому Хозяину
	box.add_child(UI.tag("УСЛОВИЕ ОТКРЫТИЯ", UI.GOLD, 16))
	box.add_child(UI.label("Выиграй забег на Дурной славе 10 за каждого Хозяина. Открыть 10-й уровень мало — на нём нужно победить.", 20, UI.TEXT))
	for m in Data.master_list:
		var row := UI.hbox(10)
		var mi := UI.icon("masters/" + str(m.id), 4)
		mi.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(mi)
		var rv := UI.vbox(0)
		rv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		rv.add_child(UI.label(m.name, 22, UI.TEXT, HORIZONTAL_ALIGNMENT_LEFT, false))
		var st := ""
		var col := UI.DIM
		if Game.master_conquered(m.id):
			st = "Покорено: победа на славе 10"
			col = UI.GREEN
		elif not Game.master_unlocked(m.id):
			st = "Хозяин ещё закрыт — открой его крыло в Замке"
			col = UI.RED
		else:
			var won := Game.notoriety_won(m.id)
			st = "Открыта слава %d · лучшая победа: %s" % [Game.notoriety_open(m.id), "нет" if won < 0 else "слава %d" % won]
			col = Color("#f6757a")
		rv.add_child(UI.label(st, 18, col))
		row.add_child(rv)
		var mark := UI.label("ГОТОВО" if Game.master_conquered(m.id) else "%d/10" % maxi(0, Game.notoriety_won(m.id)), 20,
			UI.GREEN if Game.master_conquered(m.id) else UI.DIM, HORIZONTAL_ALIGNMENT_RIGHT, false)
		mark.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(mark)
		box.add_child(row)
	# Как устроен бой
	box.add_child(UI.tag("КАК УСТРОЕН БОЙ", UI.RED, 16))
	box.add_child(UI.label("Один бой из %d этапов. Колода — %d лучших карт игры (легендарные и эпические), все в версии «+» и на твоём уровне. Казна %d. Если Император переживёт последний этап — унесёт всё." % [Battle.FINAL_STAGES.size(), Game.FINAL_DECK.size(), Game.FINAL_TREASURY], 20, UI.TEXT))
	for i in Battle.FINAL_STAGES.size():
		var stg: Array = Battle.FINAL_STAGES[i]
		box.add_child(UI.label("%d. %s — %s" % [i + 1, stg[0], stg[1]], 18, UI.DIM))
	var more := UI.button("Подробнее об Императоре", func(): UI.hero_popup(self, "emperor"), 22, 64)
	box.add_child(more)
	if open:
		box.add_child(UI.label("Начать бой — кнопка «В БОЙ!» на этой странице.", 18, UI.GREEN, HORIZONTAL_ALIGNMENT_CENTER))


func _start_final() -> void:
	Game.clear_run()
	Game.start_final()
	Game.main.goto("battle")


func _arrow(text: String, d: int) -> Button:
	var b := UI.button(text, _shift_master.bind(d), 30, 72)
	b.custom_minimum_size = Vector2(56, 96)
	b.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	b.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	return b


## Значок карты колоды: рамка типа, картинка, уровень.
func _deck_tile(id: String, lvl: int) -> Control:
	var t := UI.framed(UI.card_frame(id, true), 5)
	t.custom_minimum_size = Vector2(62, 74)
	var v := UI.vbox(0)
	t.add_child(v)
	v.add_child(UI.center(UI.card_icon(id, 4)))
	v.add_child(UI.label("Ур.%d" % lvl, 16, UI.SOUL if lvl > 1 else UI.DIM, HORIZONTAL_ALIGNMENT_CENTER, false))
	UI.ignore_mouse(t)
	t.mouse_filter = Control.MOUSE_FILTER_STOP
	t.gui_input.connect(_tap_card.bind(id))
	return t


## Дурная слава одной строкой; подробности — по кнопке «?».
func _notoriety_row(mid: String) -> Control:
	var cur := Game.notoriety_pick(mid)
	var top_max := Game.notoriety_open(mid)
	var h := UI.hbox(6)
	var minus := UI.button("−", _set_notoriety.bind(-1), 28, 56)
	minus.custom_minimum_size = Vector2(60, 56)
	minus.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	minus.disabled = cur <= 0
	h.add_child(minus)
	var text := "Дурная слава %d" % cur
	if Game.master_conquered(mid):
		text += " · покорена"
	elif cur > 0:
		text += " · Души +%d%%" % (cur * 10)
	var l := UI.label(text, 22, UI.ACCENT.lightened(0.3) if cur > 0 else UI.DIM, HORIZONTAL_ALIGNMENT_CENTER)
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	h.add_child(l)
	var plus := UI.button("+", _set_notoriety.bind(1), 28, 56)
	plus.custom_minimum_size = Vector2(60, 56)
	plus.size_flags_horizontal = Control.SIZE_SHRINK_END
	plus.disabled = cur >= top_max
	h.add_child(plus)
	var q := UI.button("?", _notoriety_help, 28, 56)
	q.custom_minimum_size = Vector2(60, 56)
	q.size_flags_horizontal = Control.SIZE_SHRINK_END
	h.add_child(q)
	return h


func _notoriety_help() -> void:
	var m: Dictionary = Data.master_list[_master_idx]
	var p := UI.popup(self, "Дурная слава")
	var cur := Game.notoriety_pick(m.id)
	var top_max := Game.notoriety_open(m.id)
	var won := Game.notoriety_won(m.id)
	p.box.add_child(UI.label("У каждого Хозяина своя Дурная слава. Победа на самом высоком открытом уровне открывает следующий. Чем выше слава, тем злее герои и больше награда: Души +10% за уровень, с 3-го уровня за победу — Магический сундук.", 20, UI.TEXT))
	p.box.add_child(UI.label("%s: открыт уровень %d, лучшая победа — %s" % [m.name, top_max, "нет" if won < 0 else "на уровне %d" % won], 20, UI.GOLD))
	p.box.add_child(UI.label("Выиграй на славе 10 за каждого Хозяина, чтобы открыть Финальный бой.", 20, UI.ACCENT.lightened(0.3)))
	for i in Data.notoriety.size():
		var col := Color("#f6757a") if i < cur else (UI.DIM if i < top_max else Color(0.45, 0.42, 0.5))
		var suffix := "  (действует)" if i < cur else ("" if i < top_max else "  (закрыт)")
		p.box.add_child(UI.label("%d. %s%s" % [i + 1, Data.notoriety[i], suffix], 20, col))


func _shift_master(d: int) -> void:
	_master_idx = posmod(_master_idx + d, Data.master_list.size() + 1)
	Game.meta.master_pick = "final" if _is_final() else Data.master_list[_master_idx].id
	Game.save_meta()
	_show("home")


func _set_notoriety(d: int) -> void:
	var mid: String = Data.master_list[_master_idx].id
	Game.set_notoriety_pick(mid, Game.notoriety_pick(mid) + d)
	_show("home")


func _battle() -> void:
	if not Game.meta.tutorial_done:
		Game.clear_run()
		Game.start_tutorial()
		Game.main.goto("battle")
		return
	if Game.has_run():
		var p := UI.popup(self, "Новый забег?", "Отмена")
		p.box.add_child(UI.label("Текущий забег будет потерян.", 22))
		p.box.add_child(UI.tint_button(UI.button("Начать заново", _start_run), UI.RED))
		return
	_start_run()


func _start_run() -> void:
	Game.clear_run()
	var m: Dictionary = Data.master_list[_master_idx]
	Game.new_run(m.id, Game.notoriety_pick(m.id))
	Game.main.goto(Game.run.screen)


# ---------------------------------------------------------------- сундуки

func _slot_view(i: int) -> Control:
	var st := Progress.chest_state(i)
	var p := UI.framed("card_selected" if st == "ready" else "panel_dark", 6)
	p.custom_minimum_size = Vector2(0, 176)
	p.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var v := UI.vbox(2)
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	p.add_child(v)
	if st == "empty":
		var e := UI.label("Пустой\nслот", 18, UI.DIM, HORIZONTAL_ALIGNMENT_CENTER)
		e.size_flags_vertical = Control.SIZE_EXPAND_FILL
		e.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		v.add_child(e)
	else:
		var type: String = Progress.chest_at(i).type
		var ic := UI.icon("chests/" + type, 6)
		v.add_child(UI.center(ic))
		v.add_child(UI.label(Progress.chest_name(type).split(" ")[0], 16, UI.TEXT, HORIZONTAL_ALIGNMENT_CENTER, false))
		var l := UI.label("", 20, UI.GOLD, HORIZONTAL_ALIGNMENT_CENTER, false)
		match st:
			"locked":
				l.text = Progress.format_time(Progress.time_left(i))
				l.add_theme_color_override("font_color", UI.DIM)
			"unlocking":
				l.text = Progress.format_time(Progress.time_left(i))
				l.add_theme_color_override("font_color", UI.SOUL)
			"ready":
				l.text = "ГОТОВ!"
				l.add_theme_color_override("font_color", UI.GREEN)
				var tw := ic.create_tween().set_loops()
				tw.tween_property(ic, "modulate", Color(1.4, 1.3, 1.0), 0.5)
				tw.tween_property(ic, "modulate", Color.WHITE, 0.5)
		v.add_child(l)
		_timers.append({"label": l, "kind": "slot", "slot": i, "state": st})
	UI.ignore_mouse(p)
	p.mouse_filter = Control.MOUSE_FILTER_STOP
	p.gui_input.connect(_slot_input.bind(i))
	return p


func _slot_input(ev: InputEvent, i: int) -> void:
	if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
		_slot_tap(i)


func _slot_tap(i: int) -> void:
	var st := Progress.chest_state(i)
	if st == "empty":
		Game.main.toast("Сундуки выдаются за каждый забег")
		return
	if st == "ready":
		_open(Progress.open_slot(i))
		return
	var type: String = Progress.chest_at(i).type
	var p := UI.popup(self, Progress.chest_name(type), "Закрыть")
	p.box.add_child(UI.center(UI.icon("chests/" + type, 12)))
	p.box.add_child(UI.label(chest_info(type), 22, UI.TEXT, HORIZONTAL_ALIGNMENT_CENTER))
	var ov: Control = p.overlay
	if st == "locked":
		if Progress.is_unlocking_any():
			p.box.add_child(UI.label("Сейчас открывается другой сундук — открывать можно по одному.", 18, UI.DIM, HORIZONTAL_ALIGNMENT_CENTER))
		else:
			var sb := UI.button("Начать открытие (%s)" % Progress.format_time(Progress.time_left(i)), _start_unlock.bind(i, ov), 24, 72)
			UI.tint_button(sb, UI.SOUL)
			p.box.add_child(sb)
	var cost := Progress.gems_to_open(i)
	var gb := UI.button("Открыть сейчас: %d кристаллов" % cost, _open_now.bind(i, ov), 24, 72)
	gb.disabled = int(Game.meta.gems) < cost
	UI.tint_button(gb, UI.GREEN)
	p.box.add_child(gb)


func _start_unlock(i: int, ov: Control) -> void:
	ov.queue_free()
	if Progress.start_unlock(i):
		Sfx.play("place")
	_show("home")


func _open_now(i: int, ov: Control) -> void:
	ov.queue_free()
	_open(Progress.open_slot(i))


func _claim_free() -> void:
	if Progress.free_chest_left() > 0:
		Game.main.toast("Следующий бесплатный сундук через " + Progress.format_time(Progress.free_chest_left()))
		return
	_open(Progress.claim_free_chest())


func _open(contents: Dictionary) -> void:
	if contents.is_empty():
		Game.main.toast("Не хватает кристаллов", "bad")
		return
	Progress.opening = contents
	Game.main.goto("chest_open")


## Краткое содержимое сундука: «Золото 10–20 · 6 карт · Редкая: 30%».
static func chest_info(type: String) -> String:
	var d := Progress.chest_def(type)
	var lines := ["Золото %d–%d · %d карт" % [int(d.gold[0]), int(d.gold[1]), int(d.cards)]]
	for pair in [["rare", "Редкие"], ["epic", "Эпическая"], ["legendary", "Легендарная"]]:
		var spec: Array = d.get(pair[0], [0, 0])
		var ch := float(spec[0])
		if ch > 0.0 and not Progress.has_rarity(pair[0]):
			lines.append("%s: пока нет — откройте крылья Замка (выпадет карта попроще)" % pair[1])
		elif ch >= 1.0:
			lines.append("%s: %d гарантированно" % [pair[1], int(spec[1])])
		elif ch > 0.0:
			lines.append("%s: шанс %d%%" % [pair[1], int(round(ch * 100))])
	lines.append("Время открытия: " + Progress.format_time(int(d.time)))
	return "\n".join(lines)


# ================================================================ вкладка «Колода»

func _upgradable_count() -> int:
	var n := 0
	for id in Game.meta.collection.keys():
		if Progress.can_upgrade(id):
			n += 1
	return n


const CARD_SORTS := [["sets", "Наборы"], ["up", "Улучшить"], ["level", "Уровень"], ["rarity", "Редкость"], ["cost", "Тьма"]]
const CARD_TYPES := [["", "Все"], ["trap", "Ловушки"], ["monster", "Монстры"], ["room", "Комнаты"], ["spell", "Закл."]]
static var cards_sort := "sets"
static var cards_type := ""


func _deck() -> void:
	var body := _page()
	var head := UI.hbox()
	var t := _section("Карты: найдено %d из %d" % [Game.meta.collection.size(), Progress.collectible_ids().size()])
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(t)
	body.add_child(head)
	body.add_child(UI.label("Кристалл в углу картинки — редкость: серый обычная, синий редкая, фиолетовый эпическая, золотой легендарная.", 16, UI.DIM))
	# Улучшить всё, на что хватает копий и золота.
	var plan := _upgrade_plan()
	if not plan.is_empty():
		var ub := UI.button("Улучшить всё: %d карт за %d золота" % [plan.size(), _plan_cost(plan)], _upgrade_all, 22, 64)
		UI.tint_button(ub, UI.GREEN)
		body.add_child(ub)
	# Сортировка и фильтр по типу.
	body.add_child(_segmented(CARD_SORTS, cards_sort, _set_sort))
	body.add_child(_segmented(CARD_TYPES, cards_type, _set_type))
	if cards_sort == "sets":
		_group(body, "Базовые · у всех Хозяев", "", _filtered(_ids_of_set("base")), false)
		for w in Data.wings:
			var open := Game.wing_unlocked(w.id)
			var title := "Крыло «%s» · Хозяин %s" % [w.name, Data.masters[w.master].name]
			var note := "" if open else "Закрыто: открой крыло во вкладке Замок за %d Душ" % int(w.cost)
			_group(body, title, note, _filtered(_ids_of_set(w.id)), not open)
		for l in Data.location_list:
			_group(body, "Локация «%s» · только в ней" % l.name, "", _filtered(_ids_of_set("loc_" + str(l.id))), false)
		return
	var ids := _filtered(Progress.collectible_ids())
	if cards_sort == "up":
		var ready := []
		for id in ids:
			if Progress.ready_to_upgrade(id):
				ready.append(id)
		ids = ready
		if ids.is_empty():
			body.add_child(UI.label("Пока нечего улучшать: не хватает копий. Открывай сундуки — копии выпадают из них.", 20, UI.DIM, HORIZONTAL_ALIGNMENT_CENTER))
			return
	ids.sort_custom(_sort_cmp)
	var g := _grid()
	for id in ids:
		g.add_child(_coll_card(id) if Progress.owned(id) else _hidden_card(id, not id in Progress.droppable_ids()))
	body.add_child(g)


## Ряд кнопок-переключателей; выбранная — золотая.
func _segmented(items: Array, current: String, cb: Callable) -> HBoxContainer:
	var h := UI.hbox(4)
	for it in items:
		var b := UI.button(it[1], cb.bind(it[0]), 18, 52)
		if it[0] == current:
			UI.tint_button(b, UI.GOLD)
		h.add_child(b)
	return h


func _set_sort(id: String) -> void:
	cards_sort = id
	_show("deck")


func _set_type(id: String) -> void:
	cards_type = id
	_show("deck")


func _filtered(ids: Array) -> Array:
	if cards_type == "":
		return ids
	var out := []
	for id in ids:
		if Data.cards[id].type == cards_type:
			out.append(id)
	return out


## Порядок для режимов «Уровень», «Редкость», «Тьма», «Улучшить». Ненайденные — в конце.
func _sort_cmp(a: String, b: String) -> bool:
	var oa := Progress.owned(a)
	var ob := Progress.owned(b)
	if oa != ob:
		return oa
	var ca: Dictionary = Data.cards[a]
	var cb: Dictionary = Data.cards[b]
	match cards_sort:
		"up":
			var aa := Progress.can_upgrade(a)
			var ab := Progress.can_upgrade(b)
			if aa != ab:
				return aa
			if Progress.gold_cost(a) != Progress.gold_cost(b):
				return Progress.gold_cost(a) < Progress.gold_cost(b)
		"level":
			if Progress.level_of(a) != Progress.level_of(b):
				return Progress.level_of(a) > Progress.level_of(b)
			var pa := float(Progress.copies(a)) / maxf(1.0, Progress.need(a))
			var pb := float(Progress.copies(b)) / maxf(1.0, Progress.need(b))
			if pa != pb:
				return pa > pb
		"rarity":
			var ra: int = RARITY_ORDER.get(ca.rarity, 9)
			var rb: int = RARITY_ORDER.get(cb.rarity, 9)
			if ra != rb:
				return ra < rb
		"cost":
			if int(ca.cost) != int(cb.cost):
				return int(ca.cost) < int(cb.cost)
	return str(ca.name) < str(cb.name)


## Какие улучшения можно сделать прямо сейчас (дешёвые первыми, с учётом общего золота).
func _upgrade_plan() -> Array:
	var cand := []
	for id in Game.meta.collection.keys():
		if Progress.ready_to_upgrade(id):
			cand.append(id)
	cand.sort_custom(func(a, b): return Progress.gold_cost(a) < Progress.gold_cost(b))
	var gold := int(Game.meta.gold)
	var out := []
	for id in cand:
		var c := Progress.gold_cost(id)
		if c <= gold:
			gold -= c
			out.append(id)
	return out


func _plan_cost(plan: Array) -> int:
	var total := 0
	for id in plan:
		total += Progress.gold_cost(id)
	return total


func _upgrade_all() -> void:
	var done := 0
	var changed := true
	while changed:
		changed = false
		for id in _upgrade_plan():
			if Progress.upgrade(id):
				done += 1
				changed = true
	if done > 0:
		Sfx.play("combo")
		Game.main.toast("Улучшено карт: %d" % done, "good")
	_build_top()
	_show("deck")


func _ids_of_set(set_id: String) -> Array:
	var out := []
	for c in Data.card_list:
		if c.set == set_id:
			out.append(c.id)
	out.sort_custom(_card_order)
	return out


func _group(body: VBoxContainer, title: String, note: String, ids: Array, locked: bool) -> void:
	if ids.is_empty():
		return
	var found := 0
	for id in ids:
		if Progress.owned(id):
			found += 1
	body.add_child(_section("%s  %d/%d" % [title, found, ids.size()], UI.SOUL if locked else UI.GOLD))
	if note != "":
		body.add_child(UI.label(note, 18, UI.DIM))
	var g := _grid()
	for id in ids:
		g.add_child(_coll_card(id) if Progress.owned(id) else _hidden_card(id, locked))
	body.add_child(g)


func _grid() -> GridContainer:
	var g := GridContainer.new()
	g.columns = 4
	g.add_theme_constant_override("h_separation", 8)
	g.add_theme_constant_override("v_separation", 10)
	return g


func _card_order(a: String, b: String) -> bool:
	var ra := Progress.ready_to_upgrade(a)
	var rb := Progress.ready_to_upgrade(b)
	if ra != rb:
		return ra
	var oa: int = RARITY_ORDER.get(Data.cards[a].rarity, 9)
	var ob: int = RARITY_ORDER.get(Data.cards[b].rarity, 9)
	if oa != ob:
		return oa < ob
	return int(Data.cards[a].cost) < int(Data.cards[b].cost)


## Карта коллекции: мини-карта + полоска копий до следующего уровня.
func _coll_card(id: String) -> Control:
	var v := UI.vbox(2)
	var lvl := Progress.level_of(id)
	v.add_child(UI.mini_card({"id": id, "lvl": lvl}, 160, 176))
	var n := Progress.need(id)
	if n < 0:
		v.add_child(UI.progress_bar(1, 1, 160, Color("#c47b25"), "Ур.%d · МАКС" % lvl))
	else:
		var ready := Progress.copies(id) >= n
		var txt := "Ур.%d · %d/%d" % [lvl, Progress.copies(id), n]
		if ready:
			txt = "Ур.%d · УЛУЧШИТЬ" % lvl
		v.add_child(UI.progress_bar(Progress.copies(id), n, 160, UI.GREEN if ready else Color("#2a6fb8"), txt))
	UI.ignore_mouse(v)
	v.mouse_filter = Control.MOUSE_FILTER_STOP
	v.gui_input.connect(_tap_card.bind(id))
	return v


func _hidden_card(id: String, locked: bool) -> Control:
	var v := UI.vbox(2)
	var mc := UI.mini_card({"id": id}, 160, 176)
	mc.modulate = Color(0.35, 0.3, 0.45)
	v.add_child(mc)
	if locked:
		var lh := UI.hbox(4)
		lh.alignment = BoxContainer.ALIGNMENT_CENTER
		lh.add_child(UI.icon("icons/lock", 2))
		lh.add_child(UI.label("Закрыто", 16, UI.DIM, HORIZONTAL_ALIGNMENT_CENTER, false))
		v.add_child(lh)
	else:
		v.add_child(UI.label("Не найдена", 16, Data.RARITY_COLORS.get(Data.cards[id].rarity, UI.DIM), HORIZONTAL_ALIGNMENT_CENTER, false))
	UI.ignore_mouse(v)
	v.mouse_filter = Control.MOUSE_FILTER_STOP
	v.gui_input.connect(_tap_card.bind(id))
	return v


func _tap_card(ev: InputEvent, id: String) -> void:
	if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
		card_detail(id)


## Окно карты: уровень, копии, что даст улучшение, кнопка «Улучшить».
func card_detail(id: String) -> void:
	var lvl := maxi(1, Progress.level_of(id))
	var p := UI.popup(self, "", "Закрыть")
	var ov: Control = p.overlay
	p.box.add_child(UI.center(UI.card_view(id, false, 300, lvl)))
	var c: Dictionary = Data.cards[id]
	p.box.add_child(UI.label(Data.card_text(id, false, lvl), 20, UI.TEXT, HORIZONTAL_ALIGNMENT_CENTER))
	p.box.add_child(UI.label("%s · %s · Уровень %d из %d" % [Data.TYPE_NAMES.get(c.type, ""), Data.RARITY_NAMES.get(c.rarity, ""), lvl, Progress.max_level()], 22, Data.RARITY_COLORS.get(c.rarity, UI.DIM), HORIZONTAL_ALIGNMENT_CENTER))
	p.box.add_child(UI.label(_where_used(id), 18, UI.DIM, HORIZONTAL_ALIGNMENT_CENTER))
	if not Progress.owned(id):
		var why := "Карта ещё не найдена. Выбей её из сундука."
		if not id in Progress.droppable_ids():
			why = "Сначала открой её крыло во вкладке Замок — потом она начнёт выпадать из сундуков."
		p.box.add_child(UI.label(why, 20, UI.GOLD, HORIZONTAL_ALIGNMENT_CENTER))
		return
	var mastery := int(Data.prog.get("mastery_level", 5))
	if c.has("up") and Data.is_utility(id):
		var mt := "Мастерство (ур. %d): в забеге сразу «+» — %s" % [mastery, ", ".join(Data.upgrade_changes(id, lvl))]
		p.box.add_child(UI.label(mt, 18, UI.GOLD if lvl >= mastery else UI.DIM, HORIZONTAL_ALIGNMENT_CENTER))
	var n := Progress.need(id)
	if n > 0:
		p.box.add_child(UI.center(UI.progress_bar(Progress.copies(id), n, 520, UI.GREEN if Progress.copies(id) >= n else Color("#2a6fb8"), "Копии: %d/%d" % [Progress.copies(id), n], 32)))
		var cp := UI.framed("panel_dark", 8)
		var cv := UI.vbox(2)
		cp.add_child(cv)
		cv.add_child(UI.label("Уровень %d:" % (lvl + 1), 18, UI.DIM))
		for line in Data.level_changes(id, lvl, lvl + 1):
			cv.add_child(UI.label(line, 24, UI.GREEN))
		if lvl + 1 == mastery and c.has("up") and Data.is_utility(id):
			cv.add_child(UI.label("Мастерство: в забеге карта сразу «+»", 24, UI.GOLD))
		cv.add_child(UI.label("Опыт игрока +%d" % int(Data.prog.upgrade_xp[lvl - 1]), 18, UI.SOUL))
		p.box.add_child(cp)
		var cost := Progress.gold_cost(id)
		var ub := UI.button("", _do_upgrade.bind(id, ov), 26, 76)
		if Progress.copies(id) < n:
			ub.text = "Нужно ещё %d копий" % (n - Progress.copies(id))
			ub.disabled = true
		else:
			ub.text = "Улучшить: %d золота" % cost
			ub.disabled = int(Game.meta.gold) < cost
			UI.tint_button(ub, UI.GREEN)
		p.box.add_child(ub)
	else:
		p.box.add_child(UI.label("Максимальный уровень!", 24, UI.GOLD, HORIZONTAL_ALIGNMENT_CENTER))


## Где карта встречается в забегах.
func _where_used(id: String) -> String:
	var s: String = Data.cards[id].set
	if s == "base":
		return "Базовая: в наградах у всех Хозяев"
	if s.begins_with("loc_"):
		var loc: Dictionary = Data.locations.get(s.substr(4), {})
		return "Локация «%s»: предлагается только там, у любого Хозяина" % loc.get("name", "?")
	for m in Data.master_list:
		if Data.prog.affinity.get(m.id, {}).get("set", "") == s:
			for w in Data.wings:
				if w.id == s:
					return "Крыло «%s»: в наградах у Хозяина «%s» (+1 уровень) и у Тёмного владыки" % [w.name, m.name]
	return ""


func _do_upgrade(id: String, ov: Control) -> void:
	var before := Progress.level_of(id)
	if not Progress.upgrade(id):
		return
	ov.queue_free()
	Sfx.play("combo")
	Game.vibrate(60)
	_build_top()
	_show(tab)
	card_detail(id)
	_level_up_fx(id, before, Progress.level_of(id))


## Праздник улучшения: вспышка, карта подпрыгивает, «УР 3 → УР 4», золотые искры.
func _level_up_fx(id: String, from_lvl: int, to_lvl: int) -> void:
	var layer := Control.new()
	UI.full(layer)
	layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.z_index = 60
	add_child(layer)
	var flash := ColorRect.new()
	flash.color = Color(1, 0.85, 0.4, 0.45)
	UI.full(flash)
	flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(flash)
	var box := UI.vbox(6)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var ic := UI.card_icon(id, 10)
	box.add_child(UI.center(ic))
	var l := Label.new()
	l.text = "УР %d → УР %d" % [from_lvl, to_lvl]
	l.add_theme_font_override("font", UI.pixel_font())
	l.add_theme_font_size_override("font_size", 40)
	l.add_theme_color_override("font_color", UI.GOLD)
	l.add_theme_color_override("font_outline_color", UI.INK)
	l.add_theme_constant_override("outline_size", 10)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(l)
	var cc := CenterContainer.new()
	UI.full(cc)
	cc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cc.add_child(box)
	layer.add_child(cc)
	box.pivot_offset = Vector2(160, 80)
	box.scale = Vector2(0.3, 0.3)
	var tw := layer.create_tween()
	tw.tween_property(box, "scale", Vector2(1.15, 1.15), 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(flash, "modulate:a", 0.0, 0.4)
	tw.tween_property(box, "scale", Vector2.ONE, 0.1)
	tw.tween_interval(0.6)
	tw.tween_property(layer, "modulate:a", 0.0, 0.3)
	tw.tween_callback(layer.queue_free)
	for i in 26:
		var px := ColorRect.new()
		px.size = Vector2(8, 8) if i % 2 else Vector2(6, 6)
		px.color = [UI.GOLD, Color("#ffe08a"), Color.WHITE][i % 3]
		px.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var c := get_viewport_rect().size / 2
		px.position = c
		layer.add_child(px)
		var ang := randf() * TAU
		var ptw := px.create_tween()
		ptw.tween_property(px, "position", c + Vector2(cos(ang), sin(ang)) * randf_range(140, 320), 0.7).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		ptw.parallel().tween_property(px, "modulate:a", 0.0, 0.7).set_delay(0.25)


# ================================================================ вкладка «Магазин»

func _shop() -> void:
	var body := _page()
	var s := Progress.shop()
	var head := UI.hbox()
	var t := _section("Магазин")
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(t)
	var tl := UI.label("", 18, UI.DIM, HORIZONTAL_ALIGNMENT_RIGHT, false)
	tl.text = "Обновится через " + Progress.format_time(Progress.shop_seconds_left())
	head.add_child(tl)
	_timers.append({"label": tl, "kind": "shop", "slot": -1, "state": ""})
	body.add_child(head)
	var gp := UI.framed("popup", 10)
	var gh := UI.hbox(12)
	gp.add_child(gh)
	gh.add_child(UI.icon("icons/coin", 7))
	var gl := UI.label("Подарок дня: %d золота" % int(Data.prog.shop.free_gold), 24, UI.GOLD)
	gl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	gl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	gh.add_child(gl)
	var gift := UI.button("Получено" if s.gift else "Забрать", _claim_gift, 22, 64)
	gift.custom_minimum_size = Vector2(170, 64)
	gift.size_flags_horizontal = Control.SIZE_SHRINK_END
	gift.disabled = s.gift
	if not s.gift:
		UI.tint_button(gift, UI.GREEN)
	gh.add_child(gift)
	body.add_child(gp)
	body.add_child(_section("Карты дня"))
	var row := UI.hbox(8)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	var offers: Array = s.offers
	for i in offers.size():
		var o: Dictionary = offers[i]
		var v := UI.vbox(4)
		var holder := PanelContainer.new()
		holder.add_theme_stylebox_override("panel", StyleBoxEmpty.new())
		var cv := UI.card_view(o.id, false, 212, maxi(1, Progress.level_of(o.id)))
		cv.mouse_filter = Control.MOUSE_FILTER_STOP
		cv.gui_input.connect(_tap_card.bind(o.id))
		if o.bought:
			cv.modulate = Color(1, 1, 1, 0.35)
		holder.add_child(cv)
		v.add_child(holder)
		v.add_child(UI.label(("НОВАЯ! ×%d" if not Progress.owned(o.id) else "×%d копий") % int(o.n), 22, UI.GOLD if not Progress.owned(o.id) else UI.TEXT, HORIZONTAL_ALIGNMENT_CENTER, false))
		var b := UI.button("Куплено" if o.bought else "%d золота" % int(o.price), _buy_offer.bind(i), 22, 64)
		b.disabled = o.bought or int(Game.meta.gold) < int(o.price)
		if not b.disabled:
			UI.tint_button(b, UI.GOLD)
		v.add_child(b)
		row.add_child(v)
	body.add_child(row)
	body.add_child(_section("Сундуки за кристаллы"))
	for sc in Data.prog.shop.chests:
		var cp := UI.framed("panel", 10)
		var ch := UI.hbox(12)
		cp.add_child(ch)
		ch.add_child(UI.icon("chests/" + str(sc.chest), 6))
		var cv := UI.vbox(2)
		cv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		cv.add_child(UI.label(Progress.chest_name(sc.chest), 24, UI.TEXT))
		cv.add_child(UI.label(chest_info(sc.chest).split("\nВремя")[0], 16, UI.DIM))
		ch.add_child(cv)
		var b := UI.button("%d кр." % int(sc.gems), _buy_chest.bind(str(sc.chest), int(sc.gems)), 22, 64)
		b.custom_minimum_size = Vector2(140, 64)
		b.size_flags_horizontal = Control.SIZE_SHRINK_END
		b.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		b.disabled = int(Game.meta.gems) < int(sc.gems)
		UI.tint_button(b, UI.GREEN)
		ch.add_child(b)
		body.add_child(cp)
	var gems: Dictionary = Data.prog.gems
	body.add_child(UI.label("Кристаллы: победа +%d, каждый босс +%d, достижение +%d, ежедневное подземелье +%d." % [int(gems.win), int(gems.boss), int(gems.achievement), int(gems.daily)], 18, UI.DIM))


func _claim_gift() -> void:
	if Progress.claim_gift():
		Sfx.play("coin")
		_build_top()
		_show("shop")


func _buy_offer(i: int) -> void:
	if Progress.buy_offer(i):
		Sfx.play("coin")
		var o: Dictionary = Progress.shop().offers[i]
		Game.main.toast("+%d × %s" % [int(o.n), Data.card_name(o.id)])
		_build_top()
		_show("shop")


func _buy_chest(type: String, gems: int) -> void:
	_open(Progress.buy_chest(type, gems))


# ================================================================ отчёт о падении

## Окно после падения: где лежит отчёт и кнопка, чтобы скопировать его.
func _show_crash_report() -> void:
	var p := UI.popup(self, "Игра упала в прошлый раз", "Закрыть")
	p.box.add_child(UI.label("Отчёт о падении сохранён в файл:", 24))
	p.box.add_child(UI.label(CrashLog.report_path, 24, UI.GOLD))
	p.box.add_child(UI.label("Нажми «Скопировать отчёт» и вставь его в сообщение разработчику. Отчёт можно найти и позже: Настройки → Отчёт об ошибке.", 24, UI.DIM))
	var copy := UI.button("Скопировать отчёт", Callable(), 28, 80)
	copy.pressed.connect(_copy_report.bind(copy))
	UI.tint_button(copy, UI.GOLD)
	p.box.add_child(copy)


func _copy_report(btn: Button) -> void:
	CrashLog.copy_report()
	btn.text = "Скопировано!"
