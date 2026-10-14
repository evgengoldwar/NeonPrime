extends RefCounted
## Общие окна забега: Колода (с фильтрами), Реликвии, Пауза.

const UI := preload("res://scripts/ui/ui.gd")


static func deck(parent: Node, cards: Array = [], heading: String = "Колода") -> void:
	if cards.is_empty():
		cards = Game.run.deck
	var p := UI.popup(parent, "%s (%d)" % [heading, cards.size()])
	var state := {"type": "", "cost": -1}
	var filters := UI.hbox(6)
	p.box.add_child(filters)
	var costs := UI.hbox(6)
	p.box.add_child(costs)
	var sc := UI.scroll()
	sc.custom_minimum_size = Vector2(0, 760)
	p.box.add_child(sc)
	var grid := GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 8)
	sc.add_child(grid)
	var on_tap := func(ev: InputEvent, id: String, up: bool):
		if ev is InputEventMouseButton and ev.pressed:
			UI.card_popup(parent, id, up)
	var refill := func():
		for ch in grid.get_children():
			ch.queue_free()
		var sorted := cards.duplicate()
		sorted.sort_custom(func(a, b): return Data.cards[a.id].name < Data.cards[b.id].name)
		for c in sorted:
			var d: Dictionary = Data.cdef(c.id, c.up)
			if state.type != "" and d.type != state.type:
				continue
			if state.cost >= 0 and mini(int(d.cost), 3) != state.cost:
				continue
			var cv := UI.card_view(c.id, c.up, 190)
			cv.mouse_filter = Control.MOUSE_FILTER_STOP
			cv.gui_input.connect(on_tap.bind(c.id, c.up))
			grid.add_child(cv)
	var set_type := func(tp: String):
		state.type = tp
		refill.call()
	var set_cost := func(cst: int):
		state.cost = cst
		refill.call()
	for t in [["", "Все"], ["trap", "Ловушки"], ["monster", "Монстры"], ["room", "Комнаты"], ["spell", "Закл."]]:
		filters.add_child(UI.button(t[1], set_type.bind(t[0]), 16, 52))
	for cst in [[-1, "Любая"], [0, "0"], [1, "1"], [2, "2"], [3, "3+"]]:
		costs.add_child(UI.button("Тьма " + cst[1], set_cost.bind(cst[0]), 16, 52))
	refill.call()


## Выбор n карт из колоды. filter(card) -> bool, on_done(Array of cards).
static func pick_cards(parent: Node, heading: String, n: int, filter: Callable, on_done: Callable) -> void:
	var p := UI.popup(parent, heading, "Отмена")
	var chosen := []
	var info := UI.label("Выбрано: 0/%d" % n, 22, UI.GOLD, HORIZONTAL_ALIGNMENT_CENTER)
	p.box.add_child(info)
	var sc := UI.scroll()
	sc.custom_minimum_size = Vector2(0, 760)
	p.box.add_child(sc)
	var grid := GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 8)
	sc.add_child(grid)
	var ok := UI.button("Подтвердить", Callable(), 26, 76)
	ok.disabled = true
	UI.tint_button(ok, UI.ACCENT)
	var ov: Control = p.overlay
	var toggle := func(ev: InputEvent, c: Dictionary, view: Control):
		if not (ev is InputEventMouseButton and ev.pressed):
			return
		if c in chosen:
			chosen.erase(c)
			view.modulate = Color.WHITE
		elif chosen.size() < n:
			chosen.append(c)
			view.modulate = Color(0.6, 1.4, 0.6)
		info.text = "Выбрано: %d/%d" % [chosen.size(), n]
		ok.disabled = chosen.size() != n
	var confirm := func():
		ov.queue_free()
		on_done.call(chosen)
	ok.pressed.connect(confirm)
	var count := 0
	for c in Game.run.deck:
		if filter.is_valid() and not filter.call(c):
			continue
		var cv := UI.card_view(c.id, c.up, 190)
		cv.mouse_filter = Control.MOUSE_FILTER_STOP
		cv.gui_input.connect(toggle.bind(c, cv))
		grid.add_child(cv)
		count += 1
	if count == 0:
		p.box.add_child(UI.label("Подходящих карт нет.", 20, UI.DIM, HORIZONTAL_ALIGNMENT_CENTER))
	p.root.add_child(ok)
	p.root.move_child(ok, p.root.get_child_count() - 2)


static func relics(parent: Node) -> void:
	var p := UI.popup(parent, "Реликвии")
	if Game.run.relics.is_empty():
		p.box.add_child(UI.label("Пока нет реликвий. Их дают элиты, боссы, магазин и события.", 20, UI.DIM))
	for id in Game.run.relics:
		p.box.add_child(UI.relic_view(id))
	var m: Dictionary = Data.masters[Game.run.master]
	p.box.add_child(UI.label("Хозяин: %s — %s" % [m.name, m.passive_text], 18, UI.DIM))
	if Game.run.location != "":
		var l: Dictionary = Data.locations[Game.run.location]
		p.box.add_child(UI.label("%s. %s" % [l.name, l.rule_text], 18, UI.DIM))
	if int(Game.run.get("egg_growth", 0)) > 0:
		p.box.add_child(UI.label("Рост яйца дракона: %d" % int(Game.run.egg_growth), 18, UI.GOLD))


static func pause(parent: Node, on_resume: Callable = Callable()) -> void:
	var p := UI.popup(parent, "Пауза", "")
	var ov: Control = p.overlay
	var resume := func():
		ov.queue_free()
		if on_resume.is_valid():
			on_resume.call()
	var to_menu := func():
		Game.save_run()
		Game.main.goto("menu")
	var music_toggle := func(on: bool):
		Game.set_setting("music", on)
		Sfx.refresh_music()
	p.box.add_child(UI.button("Продолжить", resume))
	p.box.add_child(UI.button("Колода", func(): deck(parent)))
	p.box.add_child(UI.button("Реликвии", func(): relics(parent)))
	var snd := CheckButton.new()
	snd.text = "Звук"
	snd.add_theme_font_size_override("font_size", 24)
	snd.button_pressed = bool(Game.setting("sound"))
	snd.toggled.connect(func(on): Game.set_setting("sound", on))
	p.box.add_child(snd)
	var mus := CheckButton.new()
	mus.text = "Музыка"
	mus.add_theme_font_size_override("font_size", 24)
	mus.button_pressed = bool(Game.setting("music"))
	mus.toggled.connect(music_toggle)
	p.box.add_child(mus)
	p.box.add_child(UI.button("Сохранить и выйти в меню", to_menu))
	p.box.add_child(UI.tint_button(UI.button("Сдаться", func(): Game.end_run(false)), UI.RED))
