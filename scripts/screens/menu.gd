extends Control
## Главное меню в стиле Clash Royale: верхняя панель (уровень, золото, кристаллы),
## вкладки внизу (Магазин · Колода · Бой · Замок · Трофеи), сундуки с таймерами.

const UI := preload("res://scripts/ui/ui.gd")
const TABS := [
	["shop", "Магазин", "icons/tab_shop"],
	["deck", "Колода", "icons/tab_deck"],
	["home", "Бой", "icons/tab_battle"],
	["castle", "Замок", "icons/tab_castle"],
	["trophies", "Трофеи", "icons/tab_trophy"],
]
const RARITY_ORDER := {"legendary": 0, "epic": 1, "rare": 2, "common": 3}

static var tab := "home"

var _top: Control
var _content: Control
var _tabbar: HBoxContainer
var _top_sig := ""
var _timers := []          # [{"label": Label, "kind": String, "slot": int, "state": String}]
var _swap_id := ""         # карта, которую кладём в колоду (ждём выбора слота)
var _master_idx := 0


func _ready() -> void:
	Sfx.music(1.0)
	Progress.ensure()
	_master_idx = maxi(0, _master_ids().find(str(Game.meta.master_pick)))
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
	h.add_child(lv)
	var sp := UI.spacer(0)
	sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(sp)
	h.add_child(UI.stat("coin", str(int(Game.meta.gold)), UI.GOLD, 32))
	h.add_child(UI.stat("gem", str(int(Game.meta.gems)), UI.GREEN, 32))
	h.add_child(UI.stat("soul", str(int(Game.meta.souls)), UI.SOUL, 32))
	h.add_child(UI.icon_button("icons/gear", func(): Game.main.goto("settings"), 5, 64))


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
	_swap_id = ""
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
	body.add_child(_master_panel())
	if Game.has_run():
		var cont := UI.button("Продолжить забег", func(): Game.main.goto(Game.resume_screen()), 28, 80)
		UI.tint_button(cont, UI.GREEN)
		body.add_child(cont)
	var m: Dictionary = Data.master_list[_master_idx]
	var go := UI.button("В БОЙ!", _battle, 44, 116)
	go.add_theme_font_override("font", UI.pixel_font())
	go.add_theme_font_size_override("font_size", UI.pfs(36))
	go.disabled = not Game.master_unlocked(m.id)
	UI.tint_button(go, UI.GOLD)
	body.add_child(go)
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
	var p := UI.framed("popup" if unlocked else "panel", 12)
	var v := UI.vbox(8)
	p.add_child(v)
	var nav := UI.hbox(8)
	v.add_child(nav)
	var prev := UI.button("<", _shift_master.bind(-1), 34, 80)
	prev.custom_minimum_size = Vector2(72, 80)
	prev.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	prev.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	nav.add_child(prev)
	var mid := UI.vbox(4)
	mid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var spr := UI.icon("masters/" + str(m.id), 11)
	if not unlocked:
		spr.modulate = Color(0, 0, 0, 0.85)
	mid.add_child(UI.center(spr))
	mid.add_child(UI.title(m.name, 32))
	nav.add_child(mid)
	var nxt := UI.button(">", _shift_master.bind(1), 34, 80)
	nxt.custom_minimum_size = Vector2(72, 80)
	nxt.size_flags_horizontal = Control.SIZE_SHRINK_END
	nxt.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	nav.add_child(nxt)
	if not unlocked:
		var wing: Dictionary = {}
		for w in Data.wings:
			if w.id == m.unlock:
				wing = w
		v.add_child(UI.label("Закрыт. Открой крыло «%s» во вкладке Замок (%d Душ)." % [wing.get("name", "?"), int(wing.get("cost", 0))], 20, UI.RED, HORIZONTAL_ALIGNMENT_CENTER))
	v.add_child(UI.label(m.passive_text, 20, UI.TEXT, HORIZONTAL_ALIGNMENT_CENTER))
	# Фирменная карта и тема Хозяина
	var info := UI.hbox(10)
	var sig: String = Data.prog.signature.get(m.id, "")
	if sig != "":
		var mc := UI.mini_card({"id": sig, "lvl": Game.card_level_for(sig, m.id)}, 96, 128)
		mc.mouse_filter = Control.MOUSE_FILTER_STOP
		mc.gui_input.connect(_tap_card.bind(sig))
		info.add_child(mc)
	var iv := UI.vbox(4)
	iv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if sig != "":
		iv.add_child(UI.label("Фирменная карта: %s ×2" % Data.card_name(sig), 20, UI.GOLD))
		iv.add_child(UI.label(Data.card_text(sig, false, Game.card_level_for(sig, m.id)), 18, UI.TEXT))
		iv.add_child(UI.label("Всегда добавляется в колоду забега этого Хозяина", 16, UI.DIM))
	iv.add_child(UI.label(Data.prog.affinity.get(m.id, {}).get("text", ""), 18, UI.GREEN))
	iv.add_child(UI.stat("coin", "Казна %d (+%d за уровень игрока)" % [int(m.treasury), Progress.treasury_bonus()], UI.GOLD, 18))
	info.add_child(iv)
	v.add_child(info)
	v.add_child(_notoriety_box())
	return p


## Дурная слава: выбор уровня и что он делает.
func _notoriety_box() -> Control:
	var p := UI.framed("panel_dark", 10)
	var v := UI.vbox(6)
	p.add_child(v)
	var cur := int(Game.meta.notoriety_pick)
	var top_max := int(Game.meta.notoriety_max)
	if top_max > 0:
		var nh := UI.hbox(8)
		var minus := UI.button("−", _set_notoriety.bind(-1), 28, 56)
		minus.custom_minimum_size = Vector2(64, 56)
		minus.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
		nh.add_child(minus)
		var nl := UI.label("Дурная слава: %d" % int(Game.meta.notoriety_pick), 22, UI.ACCENT.lightened(0.3), HORIZONTAL_ALIGNMENT_CENTER)
		nl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		nl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		nh.add_child(nl)
		var plus := UI.button("+", _set_notoriety.bind(1), 28, 56)
		plus.custom_minimum_size = Vector2(64, 56)
		plus.size_flags_horizontal = Control.SIZE_SHRINK_END
		nh.add_child(plus)
		v.add_child(nh)
	else:
		v.add_child(UI.label("Дурная слава: 0", 22, UI.ACCENT.lightened(0.3), HORIZONTAL_ALIGNMENT_CENTER))
	if cur == 0:
		v.add_child(UI.label("Обычная сложность. Победа открывает Дурную славу 1: герои злее, а награды больше.", 18, UI.DIM))
	else:
		var lines := []
		for i in cur:
			lines.append("%d. %s" % [i + 1, Data.notoriety[i]])
		v.add_child(UI.label("Усложнения:\n" + "\n".join(lines), 18, Color("#f6757a")))
		var reward := "Награда: Души +%d%%" % (cur * 10)
		if cur >= 3:
			reward += ", за победу — Магический сундук вместо Золотого"
		v.add_child(UI.label(reward, 18, UI.GREEN))
	if top_max < Data.notoriety.size():
		v.add_child(UI.label("Следующий уровень (%d): %s — откроется после победы на уровне %d" % [top_max + 1, Data.notoriety[top_max], top_max], 16, UI.DIM))
	return p


func _shift_master(d: int) -> void:
	_master_idx = posmod(_master_idx + d, Data.master_list.size())
	Game.meta.master_pick = Data.master_list[_master_idx].id
	Game.save_meta()
	_show("home")


func _set_notoriety(d: int) -> void:
	Game.meta.notoriety_pick = clampi(int(Game.meta.notoriety_pick) + d, 0, int(Game.meta.notoriety_max))
	Game.save_meta()
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
	Game.new_run(m.id, mini(int(Game.meta.notoriety_pick), int(Game.meta.notoriety_max)))
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
		Game.main.toast("Не хватает кристаллов")
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
		if ch >= 1.0:
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


func _deck() -> void:
	var body := _page()
	var head := UI.hbox()
	var t := _section("Боевая колода")
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(t)
	head.add_child(UI.label("Средняя Тьма: %.1f" % Progress.avg_cost(), 20, UI.DARK, HORIZONTAL_ALIGNMENT_RIGHT, false))
	body.add_child(head)
	if _swap_id != "":
		var bp := UI.framed("popup", 10)
		var bh := UI.hbox(10)
		bp.add_child(bh)
		bh.add_child(UI.mini_card({"id": _swap_id, "lvl": Progress.level_of(_swap_id)}, 96, 128))
		var bl := UI.label("Коснись карты колоды, которую заменит «%s»" % Data.card_name(_swap_id), 22, UI.GOLD)
		bl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		bl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		bh.add_child(bl)
		var cancel := UI.button("Отмена", _cancel_swap, 20, 64)
		cancel.size_flags_horizontal = Control.SIZE_SHRINK_END
		cancel.custom_minimum_size = Vector2(130, 64)
		bh.add_child(cancel)
		body.add_child(bp)
	var dg := _grid()
	for i in Progress.deck().size():
		dg.add_child(_coll_card(Progress.deck()[i], i))
	body.add_child(dg)
	var m: Dictionary = Data.master_list[_master_idx]
	var sig: String = Data.prog.signature.get(m.id, "")
	if sig != "":
		body.add_child(UI.label("В забег за Хозяина «%s» к колоде добавятся 2 карты «%s»." % [m.name, Data.card_name(sig)], 18, UI.DIM))
	var owned := []
	for id in Game.meta.collection.keys():
		if not Progress.in_deck(id):
			owned.append(id)
	owned.sort_custom(_card_order)
	body.add_child(_section("Коллекция: найдено %d из %d" % [Game.meta.collection.size(), Progress.collectible_ids().size()]))
	if owned.is_empty():
		body.add_child(UI.label("Все найденные карты уже в колоде. Новые карты выпадают из сундуков.", 18, UI.DIM))
	var g := _grid()
	for id in owned:
		g.add_child(_coll_card(id, -1))
	body.add_child(g)
	var unknown := []
	var locked := []
	for id in Progress.collectible_ids():
		if Progress.owned(id):
			continue
		if id in Progress.droppable_ids():
			unknown.append(id)
		else:
			locked.append(id)
	if not unknown.is_empty():
		unknown.sort_custom(_card_order)
		body.add_child(_section("Ещё не найдены: %d" % unknown.size(), UI.DIM))
		var ug := _grid()
		for id in unknown:
			ug.add_child(_hidden_card(id, false))
		body.add_child(ug)
	if not locked.is_empty():
		body.add_child(_section("Закрыто крыльями Замка: %d" % locked.size(), UI.DIM))
		body.add_child(UI.label("Эти карты не выпадают из сундуков, пока не откроешь их крыло во вкладке Замок за Души. Открытое крыло даёт ещё и нового Хозяина.", 18, UI.DIM))
		for w in Data.wings:
			var ids := []
			for id in locked:
				if Data.cards[id].set == w.id:
					ids.append(id)
			if ids.is_empty():
				continue
			var wl := UI.label("Крыло «%s» · Хозяин %s · %d Душ" % [w.name, Data.masters[w.master].name, int(w.cost)], 22, UI.SOUL)
			body.add_child(wl)
			var lg := _grid()
			for id in ids:
				lg.add_child(_hidden_card(id, true))
			body.add_child(lg)
	var loc := 0
	for c in Data.card_list:
		if str(c.set).begins_with("loc_"):
			loc += 1
	body.add_child(UI.label("Ещё %d карт локаций в коллекцию не входят: их предлагают только в забеге, в своей локации." % loc, 16, UI.DIM))


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
func _coll_card(id: String, deck_slot: int) -> Control:
	var v := UI.vbox(2)
	var lvl := Progress.level_of(id)
	var mc := UI.mini_card({"id": id, "lvl": lvl}, 160, 176)
	if _swap_id != "" and deck_slot >= 0:
		mc.add_theme_stylebox_override("panel", UI.frame("card_selected", 6))
	v.add_child(mc)
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
	v.gui_input.connect(_coll_input.bind(id, deck_slot))
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
		v.add_child(UI.label(Data.RARITY_NAMES.get(Data.cards[id].rarity, ""), 16, Data.RARITY_COLORS.get(Data.cards[id].rarity, UI.DIM), HORIZONTAL_ALIGNMENT_CENTER, false))
	UI.ignore_mouse(v)
	v.mouse_filter = Control.MOUSE_FILTER_STOP
	v.gui_input.connect(_hidden_input.bind(id))
	return v


func _hidden_input(ev: InputEvent, id: String) -> void:
	if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
		UI.card_popup(self, id, false)


func _coll_input(ev: InputEvent, id: String, deck_slot: int) -> void:
	if not (ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT):
		return
	if _swap_id != "" and deck_slot >= 0:
		Progress.set_deck_slot(deck_slot, _swap_id)
		Sfx.play("place")
		Game.main.toast("В колоде: " + Data.card_name(_swap_id))
		_swap_id = ""
		_show("deck")
		return
	card_detail(id)


func _tap_card(ev: InputEvent, id: String) -> void:
	if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
		card_detail(id)


func _cancel_swap() -> void:
	_swap_id = ""
	_show("deck")


## Окно карты: уровень, копии, что даст улучшение, кнопки «Улучшить» и «В колоду».
func card_detail(id: String) -> void:
	var lvl := maxi(1, Progress.level_of(id))
	var p := UI.popup(self, "", "Закрыть")
	var ov: Control = p.overlay
	p.box.add_child(UI.center(UI.card_view(id, false, 300, lvl)))
	var c: Dictionary = Data.cards[id]
	p.box.add_child(UI.label("%s · Уровень %d из %d" % [Data.RARITY_NAMES.get(c.rarity, ""), lvl, Progress.max_level()], 22, Data.RARITY_COLORS.get(c.rarity, UI.DIM), HORIZONTAL_ALIGNMENT_CENTER))
	p.box.add_child(UI.label(_where_used(id), 18, UI.DIM, HORIZONTAL_ALIGNMENT_CENTER))
	if not Progress.owned(id):
		p.box.add_child(UI.label("Карта ещё не найдена. Выбей её из сундука.", 20, UI.GOLD, HORIZONTAL_ALIGNMENT_CENTER))
		return
	var mastery := int(Data.prog.get("mastery_level", 5))
	if c.has("up"):
		var mt := "Мастерство (ур. %d): в забеге сразу «+» — %s" % [mastery, ", ".join(Data.upgrade_changes(id, lvl))]
		p.box.add_child(UI.label(mt, 18, UI.GOLD if lvl >= mastery else UI.DIM, HORIZONTAL_ALIGNMENT_CENTER))
	var n := Progress.need(id)
	if n > 0:
		p.box.add_child(UI.center(UI.progress_bar(Progress.copies(id), n, 520, UI.GREEN if Progress.copies(id) >= n else Color("#2a6fb8"), "Копии: %d/%d" % [Progress.copies(id), n], 32)))
		var changes := Data.level_changes(id, lvl, lvl + 1)
		var cp := UI.framed("panel_dark", 8)
		var cv := UI.vbox(2)
		cp.add_child(cv)
		cv.add_child(UI.label("Уровень %d:" % (lvl + 1), 18, UI.DIM))
		for line in changes:
			cv.add_child(UI.label(line, 24, UI.GREEN))
		if lvl + 1 == mastery:
			cv.add_child(UI.label("Мастерство: в забеге карта сразу «+»", 24, UI.GOLD))
		elif changes.is_empty():
			cv.add_child(UI.label("Числа этой карты не растут — копите до %d уровня ради «+»." % mastery, 20, UI.TEXT))
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
	if not Progress.in_deck(id):
		var db := UI.button("В колоду", _begin_swap.bind(id, ov), 24, 68)
		UI.tint_button(db, UI.ACCENT)
		p.box.add_child(db)


func _where_used(id: String) -> String:
	var s: String = Data.cards[id].set
	if s == "base":
		return "Базовая карта: работает у всех Хозяев"
	for m in Data.master_list:
		if Data.prog.affinity.get(m.id, {}).get("set", "") == s:
			for w in Data.wings:
				if w.id == s:
					return "Крыло «%s»: у Хозяина «%s» +1 уровень в забеге" % [w.name, m.name]
	return ""


func _do_upgrade(id: String, ov: Control) -> void:
	if not Progress.upgrade(id):
		return
	ov.queue_free()
	Sfx.play("combo")
	Game.main.toast("%s: уровень %d!" % [Data.card_name(id), Progress.level_of(id)])
	_build_top()
	_show(tab)
	card_detail(id)


func _begin_swap(id: String, ov: Control) -> void:
	ov.queue_free()
	_swap_id = id
	_show("deck")


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
