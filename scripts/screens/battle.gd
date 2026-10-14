extends Control
## Экран боя. Отрисовка отделена от движка: экран зовёт battle.tick()
## и проигрывает полученные события как анимацию.

const UI := preload("res://scripts/ui/ui.gd")
const RunMenus := preload("res://scripts/ui/run_menus.gd")

const CELL_H := 92
const STRIP := 40
const TICK := 0.4
const LONG_PRESS_MS := 450

var b                          # объект Battle
var speed := 1
var walking := false
var paused := false
var acc := 0.0
var selected := -1
var _press := {}

var top_treasury: Label
var top_hall: Label
var heroes_box: HBoxContainer
var corridor: Control
var cell_panels := []
var tokens := {}
var dark_box: HBoxContainer
var dark_label: Label
var hint: Label
var hand_box: HBoxContainer
var launch_btn: Button
var return_btn: Button
var speed_btn: Button
var skip_btn: Button
var fx_layer: Control
var root_box: VBoxContainer
var _intro: Control = null


func _ready() -> void:
	b = Game.battle
	if b == null:
		Game.main.goto("map")
		return
	speed = int(Game.setting("speed"))
	var loc: Dictionary = Data.locations.get(Game.run.get("location", ""), {})
	if b.is_boss:
		Sfx.music(0.7)
	else:
		Sfx.music(0.9)
	_build(loc)
	if b.phase == "walk":
		walking = true
	_refresh()
	Game.save_run()
	if b.hall == 0 and b.tick_no == 0 and (b.is_boss or b.node_type == "chosen"):
		_boss_intro()


# ================================================================ построение

func _build(loc: Dictionary) -> void:
	var m := UI.margin(10)
	UI.full(m)
	add_child(m)
	root_box = UI.vbox(8)
	m.add_child(root_box)
	# Верхняя панель
	var top := UI.panel(UI.PANEL, 12, 8)
	var th := UI.hbox(14)
	top.add_child(th)
	top_treasury = UI.label("", 26, UI.GOLD, HORIZONTAL_ALIGNMENT_LEFT, false)
	th.add_child(top_treasury)
	top_hall = UI.label("", 24, UI.TEXT, HORIZONTAL_ALIGNMENT_CENTER, false)
	top_hall.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	th.add_child(top_hall)
	var pb := UI.button("II", _pause, 24, 54)
	pb.custom_minimum_size = Vector2(70, 54)
	pb.size_flags_horizontal = Control.SIZE_SHRINK_END
	th.add_child(pb)
	root_box.add_child(top)
	# Герои
	heroes_box = UI.hbox(8)
	heroes_box.custom_minimum_size = Vector2(0, 170)
	root_box.add_child(heroes_box)
	# Коридор
	corridor = Control.new()
	corridor.custom_minimum_size = Vector2(0, STRIP * 2 + CELL_H * 6)
	corridor.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	root_box.add_child(corridor)
	var bgc := ColorRect.new()
	bgc.color = Color(loc.get("bg", "#1c1426"))
	UI.full(bgc)
	bgc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	corridor.add_child(bgc)
	var entry := UI.label("Вход", 18, UI.DIM, HORIZONTAL_ALIGNMENT_CENTER, false)
	entry.position = Vector2(0, 8)
	entry.anchor_right = 1.0
	corridor.add_child(entry)
	var exit := UI.label("Казна", 18, UI.GOLD, HORIZONTAL_ALIGNMENT_CENTER, false)
	exit.anchor_right = 1.0
	exit.anchor_top = 1.0
	exit.anchor_bottom = 1.0
	exit.offset_top = -32
	corridor.add_child(exit)
	cell_panels = []
	for i in 6:
		var cp := Panel.new()
		cp.anchor_right = 1.0
		cp.offset_top = STRIP + i * CELL_H + 3
		cp.offset_bottom = STRIP + (i + 1) * CELL_H - 3
		cp.offset_left = 0
		cp.offset_right = 0
		cp.mouse_filter = Control.MOUSE_FILTER_STOP
		cp.set_drag_forwarding(_cell_drag.bind(i), _cell_can_drop.bind(i), _cell_drop.bind(i))
		cp.gui_input.connect(_input_press.bind("cell", i))
		corridor.add_child(cp)
		cell_panels.append(cp)
	# Тьма и подсказка
	var dp := UI.hbox(10)
	dark_box = UI.hbox(6)
	dp.add_child(dark_box)
	dark_label = UI.label("", 22, UI.DARK.lightened(0.3), HORIZONTAL_ALIGNMENT_LEFT, false)
	dp.add_child(dark_label)
	hint = UI.label("", 17, UI.DIM, HORIZONTAL_ALIGNMENT_RIGHT)
	hint.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	dp.add_child(hint)
	root_box.add_child(dp)
	# Рука
	var hand_area := PanelContainer.new()
	hand_area.add_theme_stylebox_override("panel", UI.style(Color("#0e0b14"), 12, UI.PANEL3, 1, 4))
	hand_area.custom_minimum_size = Vector2(0, 168)
	hand_area.set_drag_forwarding(Callable(), _hand_can_drop, _hand_drop)
	root_box.add_child(hand_area)
	hand_box = UI.hbox(4)
	hand_box.alignment = BoxContainer.ALIGNMENT_CENTER
	hand_box.mouse_filter = Control.MOUSE_FILTER_PASS
	hand_area.add_child(hand_box)
	# Кнопки
	var bh := UI.hbox(8)
	return_btn = UI.button("Вернуть всё", _return_all, 18, 76)
	return_btn.custom_minimum_size = Vector2(130, 76)
	return_btn.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	bh.add_child(return_btn)
	speed_btn = UI.button("x%d" % speed, _toggle_speed, 22, 76)
	speed_btn.custom_minimum_size = Vector2(90, 76)
	speed_btn.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	bh.add_child(speed_btn)
	skip_btn = UI.button("Пропустить", _skip, 18, 76)
	skip_btn.custom_minimum_size = Vector2(130, 76)
	skip_btn.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	bh.add_child(skip_btn)
	launch_btn = UI.button("ВПУСТИТЬ", _launch, 30, 76)
	UI.tint_button(launch_btn, UI.RED)
	bh.add_child(launch_btn)
	root_box.add_child(bh)
	fx_layer = Control.new()
	UI.full(fx_layer)
	fx_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(fx_layer)


# ================================================================ обновление

func _refresh() -> void:
	top_treasury.text = "Казна: %d" % int(Game.run.treasury)
	top_hall.text = "Зал %d/3" % mini(b.hall + 1, 3)
	if Game.run.get("location", "") != "":
		top_hall.text += " · " + Data.locations[Game.run.location].name
	_refresh_heroes()
	_refresh_cells()
	_refresh_dark()
	_refresh_hand()
	var prep: bool = b.phase == "prep"
	launch_btn.disabled = not prep
	return_btn.disabled = not prep
	skip_btn.disabled = not walking
	_update_tokens(false)
	_update_hint()


func _refresh_heroes() -> void:
	for ch in heroes_box.get_children():
		ch.queue_free()
	for h in b.heroes:
		heroes_box.add_child(_hero_panel(h))


func _hero_panel(h: Dictionary) -> Control:
	var dead: bool = h.state == "dead"
	var fled: bool = h.state == "fled"
	var col := Color(h.get("color", "#cccccc"))
	var border := UI.RED if h.get("boss", false) else (UI.GOLD if h.kind == "elite" else col)
	var p := UI.panel(UI.PANEL, 12, 8, border, 3)
	p.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if dead or fled:
		p.modulate = Color(1, 1, 1, 0.4)
	var hb := UI.hbox(8)
	p.add_child(hb)
	var portrait := UI.panel(col.darkened(0.4), 34, 4, col, 2)
	portrait.custom_minimum_size = Vector2(68, 68)
	portrait.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	var pl := UI.label(h.name.substr(0, 1), 34, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER, false)
	pl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	portrait.add_child(pl)
	hb.add_child(portrait)
	var v := UI.vbox(2)
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hb.add_child(v)
	var title_text: String = h.name
	if h.kind == "elite":
		title_text = "Элита: " + title_text
	if h.get("boss", false) and h.phase == 2:
		title_text += " (фаза 2)"
	if dead:
		title_text += " — погиб"
	elif fled:
		title_text += " — сбежал"
	v.add_child(UI.label(title_text, 20, UI.GOLD if h.get("boss", false) else UI.TEXT))
	var bar := ProgressBar.new()
	bar.max_value = h.max_hp
	bar.value = maxi(0, h.hp)
	bar.show_percentage = false
	bar.custom_minimum_size = Vector2(0, 18)
	v.add_child(bar)
	var stats := "HP %d/%d  Атк %d  Жадн %d" % [maxi(0, h.hp), h.max_hp, h.atk + h.rage, h.greed]
	if h.armor > 0:
		stats += "  Броня %d" % h.armor
	v.add_child(UI.label(stats, 17, UI.TEXT, HORIZONTAL_ALIGNMENT_LEFT, false))
	var st := _status_text(h)
	if st != "":
		v.add_child(UI.label(st, 16, UI.ACCENT.lightened(0.4)))
	var trait_line := _trait_short(h)
	if trait_line != "" and b.heroes.size() == 1:
		v.add_child(UI.label(trait_line, 15, UI.DIM))
	if b.heroes.size() == 1:
		v.add_child(UI.label("Слабость: " + Data.hero_def(h.id).get("weakness", ""), 15, UI.GREEN))
	UI.ignore_mouse(p)
	p.mouse_filter = Control.MOUSE_FILTER_STOP
	p.gui_input.connect(_hero_input.bind(int(h.uid)))
	return p


func _status_text(h: Dictionary) -> String:
	var s := []
	if h.slow > 0:
		s.append("Замедл. %d" % h.slow)
	if h.poison > 0:
		s.append("Яд %d" % h.poison)
	if h.burn > 0:
		s.append("Горение %d" % h.burn)
	if h.vuln > 0:
		s.append("Уязвим.")
	if h.stun > 0:
		s.append("Оглушён")
	if h.curse > 0:
		s.append("Прокл. %d" % h.curse)
	if h.bless_left > 0:
		s.append("Благосл. %d" % h.bless_left)
	return ", ".join(s)


func _trait_short(h: Dictionary) -> String:
	var t: String = Data.hero_def(h.id).get("trait_text", "")
	for mid in h.mods:
		t += " · " + Data.elite_mod(mid).get("name", "")
	return t


func _refresh_cells() -> void:
	for i in 6:
		var cp: Panel = cell_panels[i]
		for ch in cp.get_children():
			ch.queue_free()
		var closed: bool = i >= b.corridor_len
		var even: bool = i % 2 == 0
		var base := Color(0, 0, 0, 0.25) if even else Color(0, 0, 0, 0.4)
		var border := UI.PANEL3
		if selected >= 0 and selected < b.hand.size() and b.phase == "prep" and not closed:
			if b.can_place(selected, i):
				border = UI.GREEN
		cp.add_theme_stylebox_override("panel", UI.style(Color("#050308") if closed else base, 10, border, 2, 0))
		var num := UI.label(str(i + 1), 22, UI.DIM, HORIZONTAL_ALIGNMENT_LEFT, false)
		num.position = Vector2(8, 4)
		cp.add_child(num)
		if closed:
			var cl := UI.label("Обрушено", 20, UI.DIM, HORIZONTAL_ALIGNMENT_CENTER, false)
			UI.full(cl)
			cl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			cp.add_child(cl)
			continue
		var c = b.cells[i]
		if c == null:
			continue
		var view := _cell_card(c, i)
		view.anchor_right = 1.0
		view.anchor_bottom = 1.0
		view.offset_left = 150
		view.offset_right = -4
		view.offset_top = 4
		view.offset_bottom = -4
		cp.add_child(view)


func _cell_card(c: Dictionary, idx: int) -> Control:
	var up: bool = b.card_up(c)
	var d: Dictionary = Data.cdef(c.id, up)
	var tc := UI.card_color(c.id)
	var p := UI.panel(tc.darkened(0.6), 8, 6, tc if not c.locked else tc.lightened(0.3), 2)
	var h := UI.hbox(8)
	p.add_child(h)
	var cost := UI.label(str(int(c.paid)) if not c.get("innate", false) else "-", 22, UI.DARK.lightened(0.3), HORIZONTAL_ALIGNMENT_CENTER, false)
	cost.custom_minimum_size = Vector2(26, 0)
	h.add_child(cost)
	var v := UI.vbox(0)
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(v)
	var name_text: String = Data.card_name(c.id, up)
	if c.disabled:
		name_text += " [разобрана]"
	elif c.frozen:
		name_text += " [заморожена]"
	elif c.once_used:
		name_text += " [сработала]"
	elif c.locked and "permanent" in d.kw:
		name_text += " [постоянная]"
	v.add_child(UI.label(name_text, 18, Color.WHITE if not up else UI.GREEN, HORIZONTAL_ALIGNMENT_LEFT, false))
	var txt := UI.label(Data.card_text(c.id, up).split("\n")[0], 14, UI.DIM)
	txt.clip_text = true
	txt.autowrap_mode = TextServer.AUTOWRAP_OFF
	txt.custom_minimum_size = Vector2(200, 0)
	v.add_child(txt)
	if d.type == "monster":
		var target = null
		for hh in b.heroes:
			if hh.state in ["wait", "walk"]:
				target = hh
				break
		var st := UI.label("HP %d/%d\nАтк %d" % [maxi(0, c.hp), c.max_hp, b.monster_atk(idx, target)], 17, UI.RED, HORIZONTAL_ALIGNMENT_RIGHT, false)
		h.add_child(st)
	if c.disabled or c.frozen or c.once_used:
		p.modulate = Color(0.6, 0.75, 1.0, 0.7) if c.frozen else Color(0.6, 0.6, 0.6, 0.7)
	if c.id == "dragon_egg":
		v.add_child(UI.label("Рост %d/%d" % [int(Game.run.get("egg_growth", 0)), int(d.p)], 14, UI.GOLD, HORIZONTAL_ALIGNMENT_LEFT, false))
	UI.ignore_mouse(p)
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return p


func _refresh_dark() -> void:
	for ch in dark_box.get_children():
		ch.queue_free()
	var total := maxi(b.base_dark(), b.dark)
	for i in total:
		var cr := Panel.new()
		cr.custom_minimum_size = Vector2(30, 30)
		var lit: bool = i < b.dark
		cr.add_theme_stylebox_override("panel", UI.style(UI.DARK if lit else Color("#2a2238"), 15, UI.DARK.lightened(0.3) if lit else UI.PANEL3, 2, 0))
		cr.mouse_filter = Control.MOUSE_FILTER_IGNORE
		dark_box.add_child(cr)
	dark_label.text = "Тьма %d" % b.dark
	if b.discount > 0:
		dark_label.text += " (скидка −%d)" % b.discount


func _refresh_hand() -> void:
	for ch in hand_box.get_children():
		ch.queue_free()
	var n: int = b.hand.size()
	var w := 96
	if n > 0:
		w = mini(120, int((690 - 4 * n) / float(n)))
	for i in n:
		var c = b.hand[i]
		var cost: int = b.card_cost(c)
		var mc := UI.mini_card(c, w, 156, cost)
		mc.mouse_filter = Control.MOUSE_FILTER_STOP
		var affordable: bool = cost <= b.dark
		if not affordable or b.phase != "prep":
			mc.modulate = Color(0.6, 0.6, 0.6)
		if i == selected:
			mc.add_theme_stylebox_override("panel", UI.style(UI.card_color(c.id).darkened(0.5), 10, Color.WHITE, 4, 6))
			mc.position.y -= 12
		mc.set_drag_forwarding(_hand_drag.bind(i), _hand_can_drop, _hand_drop)
		mc.gui_input.connect(_input_press.bind("hand", i))
		hand_box.add_child(mc)


func _update_hint() -> void:
	var text := ""
	if b.tutorial:
		match b.hall:
			0:
				text = "Перетащи Шипы на клетку коридора и нажми «Впустить»."
			1:
				text = "Положи Слизь на клетку ВЫШЕ Шипов: Замедление удваивает урон Шипов!"
			_:
				text = "Слизь, затем Призрак (повторит Слизь), затем Шипы: урон ×4!"
		hint.add_theme_color_override("font_color", UI.GOLD)
	elif selected >= 0 and selected < b.hand.size():
		var c = b.hand[selected]
		if Data.cards[c.id].type == "spell":
			text = "Нажми на карту ещё раз или брось на коридор, чтобы разыграть"
		else:
			text = "Нажми на клетку, чтобы выложить"
	elif b.phase == "prep":
		text = "Тяни карты на клетки. Долгое нажатие — описание"
	else:
		text = ""
	hint.text = text


# ================================================================ жетоны героев

func _token_pos(h: Dictionary, order: int) -> Vector2:
	var x := 70.0 + order * 40.0
	var y := 0.0
	if h.pos < 0:
		y = 4
	elif h.pos >= b.corridor_len:
		y = STRIP + b.corridor_len * CELL_H + 4
	else:
		y = STRIP + h.pos * CELL_H + (CELL_H - 40) / 2.0
	return Vector2(x, y)


func _update_tokens(animate: bool) -> void:
	var order := 0
	for h in b.heroes:
		var key := str(h.uid)
		var t: Panel = tokens.get(key)
		if t == null:
			t = Panel.new()
			t.size = Vector2(38, 38)
			var col := Color(h.get("color", "#cccccc"))
			t.add_theme_stylebox_override("panel", UI.style(col, 19, Color.WHITE, 2, 0))
			var l := UI.label(h.name.substr(0, 1), 20, Color.BLACK, HORIZONTAL_ALIGNMENT_CENTER, false)
			UI.full(l)
			l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			t.add_child(l)
			t.mouse_filter = Control.MOUSE_FILTER_IGNORE
			t.z_index = 5
			corridor.add_child(t)
			tokens[key] = t
			t.position = _token_pos(h, order)
		var target := _token_pos(h, order)
		if h.state in ["dead", "fled"]:
			t.visible = false
		else:
			t.visible = true
			if animate and t.position != target:
				var tw := t.create_tween()
				tw.tween_property(t, "position", target, TICK / speed * 0.8).set_trans(Tween.TRANS_QUAD)
			else:
				t.position = target
		order += 1


# ================================================================ ввод

func _input_press(ev: InputEvent, kind: String, idx: int) -> void:
	if ev is InputEventMouseButton and ev.button_index == MOUSE_BUTTON_LEFT:
		if ev.pressed:
			_press = {"kind": kind, "idx": idx, "t": Time.get_ticks_msec()}
		elif not _press.is_empty() and _press.kind == kind and _press.idx == idx:
			var held := Time.get_ticks_msec() - int(_press.t)
			_press = {}
			if held < LONG_PRESS_MS:
				_tap(kind, idx)


func _process(delta: float) -> void:
	if not _press.is_empty() and Time.get_ticks_msec() - int(_press.t) >= LONG_PRESS_MS:
		var p := _press
		_press = {}
		_long_press(p.kind, p.idx)
	if walking and not paused:
		acc += delta
		var step := TICK / speed
		while acc >= step and walking:
			acc -= step
			_do_tick()


func _notification(what: int) -> void:
	if what == NOTIFICATION_DRAG_BEGIN:
		_press = {}


func _tap(kind: String, idx: int) -> void:
	if b.phase != "prep":
		if kind == "cell" and b.cells[idx] != null:
			UI.card_popup(self, b.cells[idx].id, b.card_up(b.cells[idx]))
		return
	if kind == "hand":
		if idx >= b.hand.size():
			return
		var c = b.hand[idx]
		if selected == idx and Data.cards[c.id].type == "spell":
			_play_spell(idx)
			return
		selected = -1 if selected == idx else idx
		Sfx.play("click")
		_refresh()
		return
	if kind == "cell":
		if selected >= 0 and selected < b.hand.size():
			var c = b.hand[selected]
			if Data.cards[c.id].type == "spell":
				_play_spell(selected)
			elif b.place(selected, idx):
				Sfx.play("place")
				selected = -1
			else:
				Game.main.toast("Не хватает Тьмы" if b.cells[idx] == null or not b.cells[idx].locked else "Клетка занята")
			_refresh()
		elif b.cells[idx] != null:
			UI.card_popup(self, b.cells[idx].id, b.card_up(b.cells[idx]))


func _long_press(kind: String, idx: int) -> void:
	if kind == "hand" and idx < b.hand.size():
		var c = b.hand[idx]
		UI.card_popup(self, c.id, b.card_up(c))
	elif kind == "cell" and b.cells[idx] != null:
		var c = b.cells[idx]
		UI.card_popup(self, c.id, b.card_up(c))


func _hero_input(ev: InputEvent, uid: int) -> void:
	if ev is InputEventMouseButton and ev.pressed:
		_show_hero(uid)


func _show_hero(uid: int) -> void:
	var h: Dictionary = b.hero_by_uid(uid)
	if h.is_empty():
		return
	var d: Dictionary = Data.hero_def(h.id)
	var lines := []
	lines.append("HP %d/%d · Атака %d · Жадность %d · Броня %d" % [maxi(0, h.hp), h.max_hp, h.atk + h.rage, h.greed, h.armor])
	lines.append("Черта: " + d.get("trait_text", ""))
	if d.has("phase2_text"):
		lines.append("Фаза 2 (HP < 50%): " + d.phase2_text)
	for mid in h.mods:
		var md: Dictionary = Data.elite_mod(mid)
		lines.append(md.get("name", "") + ": " + md.get("text", ""))
	lines.append("Слабость: " + d.get("weakness", ""))
	var st := _status_text(h)
	if st != "":
		lines.append("Статусы: " + st)
	UI.info_popup(self, h.name, "\n".join(lines))


# ---------------------------------------------------------------- перетаскивание

func _hand_drag(_at: Vector2, idx: int):
	if b.phase != "prep" or idx >= b.hand.size():
		return null
	_press = {}
	var c = b.hand[idx]
	var prev := UI.mini_card(c, 96, 150, b.card_cost(c))
	prev.modulate = Color(1, 1, 1, 0.85)
	var holder := Control.new()
	holder.add_child(prev)
	prev.position = Vector2(-48, -75)
	set_drag_preview(holder)
	return {"from": "hand", "idx": idx}


func _cell_drag(_at: Vector2, idx: int):
	if not b.can_unplace(idx):
		return null
	_press = {}
	var c = b.cells[idx]
	var prev := UI.mini_card(c, 96, 150, int(c.paid))
	var holder := Control.new()
	holder.add_child(prev)
	prev.position = Vector2(-48, -75)
	set_drag_preview(holder)
	return {"from": "cell", "idx": idx}


func _cell_can_drop(_at: Vector2, data, idx: int) -> bool:
	if not data is Dictionary or b.phase != "prep":
		return false
	if data.from == "hand":
		var c = b.hand[data.idx] if data.idx < b.hand.size() else null
		if c == null:
			return false
		if Data.cards[c.id].type == "spell":
			return b.can_play_spell(data.idx)
		return b.can_place(data.idx, idx)
	if data.from == "cell":
		return data.idx != idx and idx < b.corridor_len and (b.cells[idx] == null or not b.cells[idx].locked)
	return false


func _cell_drop(_at: Vector2, data, idx: int) -> void:
	if data.from == "hand":
		var c = b.hand[data.idx]
		if Data.cards[c.id].type == "spell":
			_play_spell(data.idx)
			return
		if b.place(data.idx, idx):
			Sfx.play("place")
	elif data.from == "cell":
		b.move_on_board(data.idx, idx)
		Sfx.play("place")
	selected = -1
	_refresh()


func _hand_can_drop(_at: Vector2, data) -> bool:
	return data is Dictionary and data.from == "cell" and b.can_unplace(data.idx)


func _hand_drop(_at: Vector2, data) -> void:
	b.unplace(data.idx)
	Sfx.play("click")
	_refresh()


# ================================================================ действия

func _play_spell(idx: int) -> void:
	if b.play_spell(idx):
		Sfx.play("combo", 1.5)
		selected = -1
		_play_events(b.take_events())
	else:
		Game.main.toast("Не хватает Тьмы")
	_refresh()


func _return_all() -> void:
	b.return_all()
	selected = -1
	_refresh()


func _launch() -> void:
	if b.phase != "prep":
		return
	selected = -1
	b.launch()
	walking = true
	acc = TICK / speed
	Sfx.play("place", 0.7)
	_play_events(b.take_events())
	_refresh()


func _toggle_speed() -> void:
	speed = 2 if speed == 1 else (4 if speed == 2 else 1)
	speed_btn.text = "x%d" % speed


func _skip() -> void:
	if not walking:
		return
	b.skip_hall()
	var ev: Array = b.take_events()
	_play_events(ev, true)
	_after_tick()


func _do_tick() -> void:
	b.tick()
	_play_events(b.take_events())
	_after_tick()


func _after_tick() -> void:
	if b.phase == "walk":
		_refresh_cells_light()
		return
	walking = false
	_refresh()
	if b.phase == "prep":
		Game.save_run()
		if b.hall > 0:
			Game.main.toast("Зал %d. Готовь новую выкладку" % (b.hall + 1))
	elif b.phase == "done":
		_finish()


func _refresh_cells_light() -> void:
	top_treasury.text = "Казна: %d" % int(Game.run.treasury)
	_refresh_heroes()
	_refresh_cells()
	_update_tokens(true)


func _pause() -> void:
	paused = true
	RunMenus.pause(self, func(): paused = false)


# ================================================================ события → анимации

func _play_events(evs: Array, quiet: bool = false) -> void:
	var moved := false
	for e in evs:
		match e.t:
			"move":
				moved = true
			"trig":
				if not quiet:
					_flash_cell(int(e.cell))
			"dmg":
				if not quiet:
					_float_at_hero(int(e.hero), "-%d" % int(e.n), UI.RED if e.kind != "poison" else UI.GREEN, 30)
					if int(e.n) >= 10:
						_shake()
						Game.vibrate(60)
						Sfx.play("big")
					else:
						Sfx.play("hit", 0.9 + randf() * 0.3)
			"armor":
				if not quiet:
					_float_at_hero(int(e.hero), "Броня -%d" % int(e.n), UI.SOUL, 20)
			"heal":
				if not quiet:
					_float_at_hero(int(e.hero), "+%d" % int(e.n), UI.GREEN, 26)
			"mdmg":
				if not quiet:
					_float_at_cell(int(e.cell), "-%d" % int(e.n), UI.GOLD)
			"status":
				if not quiet:
					_float_at_hero(int(e.hero), str(e.text), UI.ACCENT.lightened(0.5), 18)
			"hdeath":
				Sfx.play("kill")
				Game.vibrate(80)
				_float_at_hero(int(e.hero), "+%d золота" % int(e.gold), UI.GOLD, 30)
				_fly_gold(int(e.hero))
			"gold":
				if int(e.n) < 0 and not quiet:
					_float_at(top_treasury.get_global_rect().get_center() + Vector2(0, 30), "%d" % int(e.n), UI.RED, 26)
				elif not quiet:
					Sfx.play("coin")
				if str(e.get("text", "")) != "" and not quiet:
					Game.main.toast(str(e.text))
			"escape":
				Sfx.play("lose")
				Game.main.toast("Герой сбежал и унёс %d золота" % int(e.greed))
			"combo":
				if not quiet:
					_combo(int(e.n))
			"phase2":
				_phase2(e)
			"msg":
				Game.main.toast(str(e.text))
			"spell":
				_float_at(get_global_rect().get_center(), str(e.name), UI.SOUL, 34)
			"revive":
				_float_at_cell(int(e.cell), "Встаёт!", UI.GREEN)
			"blocked":
				if not quiet:
					_float_at_cell(int(e.cell), "не срабатывает", UI.SOUL)
	if moved and not quiet:
		Sfx.play("step", 0.8 + randf() * 0.4)


func _hero_global(uid: int) -> Vector2:
	var t: Panel = tokens.get(str(uid))
	if t != null and t.visible:
		return t.get_global_rect().get_center()
	return heroes_box.get_global_rect().get_center()


func _float_at_hero(uid: int, text: String, col: Color, size: int) -> void:
	_float_at(_hero_global(uid) + Vector2(randf_range(-10, 30), -10), text, col, size)


func _float_at_cell(idx: int, text: String, col: Color) -> void:
	var cp: Panel = cell_panels[idx]
	_float_at(cp.get_global_rect().get_center() + Vector2(120, 0), text, col, 24)


func _float_at(gpos: Vector2, text: String, col: Color, size: int) -> void:
	var l := UI.label(text, size, col, HORIZONTAL_ALIGNMENT_CENTER, false)
	l.add_theme_color_override("font_outline_color", Color.BLACK)
	l.add_theme_constant_override("outline_size", 6)
	fx_layer.add_child(l)
	l.position = gpos - fx_layer.get_global_rect().position - Vector2(60, 20)
	l.custom_minimum_size = Vector2(120, 0)
	var dur := 0.9 / maxf(1.0, speed * 0.6)
	var tw := l.create_tween()
	tw.set_parallel(true)
	tw.tween_property(l, "position:y", l.position.y - 60, dur)
	tw.tween_property(l, "modulate:a", 0.0, dur).set_delay(dur * 0.4)
	tw.chain().tween_callback(l.queue_free)


func _flash_cell(idx: int) -> void:
	if idx < 0 or idx >= cell_panels.size():
		return
	var cp: Panel = cell_panels[idx]
	cp.pivot_offset = cp.size / 2
	var tw := cp.create_tween()
	tw.tween_property(cp, "modulate", Color(1.8, 1.6, 1.2), 0.05)
	tw.parallel().tween_property(cp, "scale", Vector2(1.04, 1.12), 0.06)
	tw.tween_property(cp, "modulate", Color.WHITE, 0.15)
	tw.parallel().tween_property(cp, "scale", Vector2.ONE, 0.15)


func _shake() -> void:
	var tw := root_box.create_tween()
	for i in 4:
		tw.tween_property(root_box, "position", Vector2(randf_range(-10, 10), randf_range(-8, 8)), 0.025)
	tw.tween_property(root_box, "position", Vector2.ZERO, 0.05)


func _fly_gold(uid: int) -> void:
	var from := _hero_global(uid)
	var to := top_treasury.get_global_rect().get_center()
	for i in 6:
		var coin := Panel.new()
		coin.size = Vector2(16, 16)
		coin.add_theme_stylebox_override("panel", UI.style(UI.GOLD, 8, Color.TRANSPARENT, 0, 0))
		coin.mouse_filter = Control.MOUSE_FILTER_IGNORE
		fx_layer.add_child(coin)
		coin.position = from - fx_layer.get_global_rect().position + Vector2(randf_range(-30, 30), randf_range(-30, 30))
		var tw := coin.create_tween()
		tw.tween_interval(i * 0.05)
		tw.tween_property(coin, "position", to - fx_layer.get_global_rect().position, 0.5).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		tw.tween_callback(coin.queue_free)


func _combo(n: int) -> void:
	Sfx.play("combo", 1.0 + 0.1 * mini(n, 10))
	var l := UI.title("Комбо ×%d" % n, 44 + mini(n, 10) * 2)
	fx_layer.add_child(l)
	l.custom_minimum_size = Vector2(720, 0)
	l.position = Vector2(0, 560)
	l.pivot_offset = Vector2(360, 30)
	l.scale = Vector2(0.6, 0.6)
	var tw := l.create_tween()
	tw.tween_property(l, "scale", Vector2(1.1, 1.1), 0.15)
	tw.tween_property(l, "modulate:a", 0.0, 0.5).set_delay(0.3)
	tw.tween_callback(l.queue_free)


func _phase2(e: Dictionary) -> void:
	Sfx.play("boss")
	Sfx.music(0.6)
	Game.vibrate(150)
	var flash := ColorRect.new()
	flash.color = Color(1, 1, 1, 0.8)
	UI.full(flash)
	flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fx_layer.add_child(flash)
	var tw := flash.create_tween()
	tw.tween_property(flash, "color:a", 0.0, 0.6)
	tw.tween_callback(flash.queue_free)
	var h: Dictionary = b.hero_by_uid(e.hero)
	Game.main.toast("%s: ФАЗА 2! %s" % [h.get("name", "Босс"), str(e.text)])


func _boss_intro() -> void:
	var h: Dictionary = b.heroes[0]
	var d: Dictionary = Data.hero_def(h.id)
	paused = true
	Sfx.play("boss")
	var ov := ColorRect.new()
	ov.color = Color(0, 0, 0, 0.9)
	UI.full(ov)
	add_child(ov)
	var c := CenterContainer.new()
	UI.full(c)
	ov.add_child(c)
	var v := UI.vbox(18)
	c.add_child(v)
	var portrait := UI.panel(Color(d.get("color", "#ffffff")).darkened(0.4), 100, 10, UI.RED, 5)
	portrait.custom_minimum_size = Vector2(200, 200)
	var pl := UI.label(h.name.substr(0, 1), 110, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER, false)
	pl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	portrait.add_child(pl)
	var pc := CenterContainer.new()
	pc.add_child(portrait)
	v.add_child(pc)
	v.add_child(UI.title(h.name, 44))
	v.add_child(UI.label("«%s»" % d.get("quote", ""), 26, UI.TEXT, HORIZONTAL_ALIGNMENT_CENTER))
	v.add_child(UI.label("HP %d · Атака %d · Жадность %d" % [h.hp, h.atk, h.greed], 22, UI.GOLD, HORIZONTAL_ALIGNMENT_CENTER))
	_intro = ov
	ov.gui_input.connect(_intro_input)
	get_tree().create_timer(3.0).timeout.connect(_close_intro)


func _intro_input(ev: InputEvent) -> void:
	if ev is InputEventMouseButton and ev.pressed:
		_close_intro()


func _close_intro() -> void:
	if is_instance_valid(_intro):
		_intro.queue_free()
	_intro = null
	paused = false


# ================================================================ конец боя

func _finish() -> void:
	var p := UI.popup(self, "", "")
	var text := ""
	var heading := ""
	match b.result:
		"win":
			heading = "Победа!"
			var names := []
			for k in b.killed:
				names.append(k.name)
			text = "Погибли: %s\nЗолото: %+d\nДуши: +%d" % [", ".join(names), b.gold_delta, b.souls]
			if b.escaped.size() > 0:
				text += "\nСбежали: %d" % b.escaped.size()
		"escaped":
			heading = "Герой сбежал"
			text = "Он унёс золото из Казны: %d" % b.gold_delta
		_:
			heading = "Казна пуста"
			text = "Подземелье разграблено. Забег окончен."
	if b.best_combo >= 3:
		text += "\nЛучшее комбо: ×%d" % b.best_combo
	p.box.add_child(UI.title(heading, 40))
	p.box.add_child(UI.label(text, 24, UI.TEXT, HORIZONTAL_ALIGNMENT_CENTER))
	var next := UI.button("Дальше", func(): Game.battle_finished(), 28, 84)
	UI.tint_button(next, UI.ACCENT)
	p.box.add_child(next)
	Sfx.play("kill" if b.result == "win" else "lose")
