extends Control
## Открытие сундука: сундук трясётся → золото → карты по одной → итог.
## Касание в любом месте показывает следующее. Содержимое — Progress.opening
## (уже начислено в коллекцию).

const UI := preload("res://scripts/ui/ui.gd")

var c := {}
var step := -1          # -1 закрыт, 0 золото, 1..N карты, N+1 итог
var _stage: VBoxContainer
var _busy := false


func _ready() -> void:
	c = Progress.opening
	if c.is_empty():
		Game.main.goto("menu")
		return
	UI.backdrop(self, "tiles/wall_menu", 0.6)
	var m := UI.margin(24)
	UI.full(m)
	add_child(m)
	var v := UI.vbox(12)
	m.add_child(v)
	var top := UI.hbox()
	var t := UI.title(Progress.chest_name(c.type), 32)
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(t)
	v.add_child(top)
	var skip := UI.button("Пропустить", _summary, 20, 60)
	skip.custom_minimum_size = Vector2(180, 60)
	skip.size_flags_horizontal = Control.SIZE_SHRINK_END
	top.add_child(skip)
	_stage = UI.vbox(16)
	_stage.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_stage.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_child(_stage)
	gui_input.connect(_on_input)
	mouse_filter = Control.MOUSE_FILTER_STOP
	_closed()


func _on_input(ev: InputEvent) -> void:
	if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
		_next()


func _clear() -> void:
	for ch in _stage.get_children():
		ch.queue_free()


func _hint(text: String) -> void:
	_stage.add_child(UI.label(text, 20, UI.DIM, HORIZONTAL_ALIGNMENT_CENTER))


func _closed() -> void:
	_clear()
	var ic := UI.icon("chests/" + str(c.type), 20)
	ic.pivot_offset = ic.custom_minimum_size / 2
	_stage.add_child(UI.center(ic))
	var tw := ic.create_tween().set_loops()
	tw.tween_property(ic, "rotation", 0.08, 0.08)
	tw.tween_property(ic, "rotation", -0.08, 0.16)
	tw.tween_property(ic, "rotation", 0.0, 0.08)
	tw.tween_interval(0.6)
	_hint("Коснись, чтобы открыть")


func _next() -> void:
	if _busy:
		return
	step += 1
	var cards: Array = c.cards
	if step == 0:
		_gold()
	elif step <= cards.size():
		_card(cards[step - 1], cards.size() - step)
	elif step == cards.size() + 1:
		_summary()
	else:
		Game.main.goto("menu")


func _pop(n: Control) -> void:
	n.pivot_offset = n.custom_minimum_size / 2
	n.scale = Vector2(0.4, 0.4)
	var tw := n.create_tween()
	tw.tween_property(n, "scale", Vector2(1.08, 1.08), 0.15)
	tw.tween_property(n, "scale", Vector2.ONE, 0.08)


func _gold() -> void:
	_clear()
	Sfx.play("combo")
	var ic := UI.icon("chests/%s_open" % c.type, 20)
	_stage.add_child(UI.center(ic))
	_pop(ic)
	var g := UI.stat("coin", "+%d золота" % int(c.gold), UI.GOLD, 48)
	g.alignment = BoxContainer.ALIGNMENT_CENTER
	_stage.add_child(g)
	_hint("Карт внутри: %d" % _total_cards())


func _total_cards() -> int:
	var n := 0
	for s in c.cards:
		n += int(s.n)
	return n


func _card(s: Dictionary, left: int) -> void:
	_clear()
	var id: String = s.id
	var rar: String = Data.cards[id].rarity
	Sfx.play("coin" if rar == "common" else "combo")
	var lvl := maxi(1, Progress.level_of(id))
	var holder := UI.vbox(10)
	if s.get("new", false):
		var nl := UI.label("НОВАЯ КАРТА!", 40, UI.GOLD, HORIZONTAL_ALIGNMENT_CENTER)
		nl.add_theme_font_override("font", UI.pixel_font())
		holder.add_child(nl)
	var cv := UI.card_view(id, false, 320, lvl)
	holder.add_child(UI.center(cv))
	_pop(cv)
	holder.add_child(UI.label("×%d" % int(s.n), 48, Data.RARITY_COLORS.get(rar, UI.TEXT), HORIZONTAL_ALIGNMENT_CENTER))
	holder.add_child(UI.label(Data.RARITY_NAMES.get(rar, ""), 22, Data.RARITY_COLORS.get(rar, UI.DIM), HORIZONTAL_ALIGNMENT_CENTER))
	var n := Progress.need(id)
	if n > 0:
		var ready := Progress.copies(id) >= n
		holder.add_child(UI.center(UI.progress_bar(Progress.copies(id), n, 420, UI.GREEN if ready else Color("#2a6fb8"),
			("Можно улучшить! %d/%d" if ready else "До уровня %d: " % (lvl + 1) + "%d/%d") % [Progress.copies(id), n], 34)))
	_stage.add_child(holder)
	_hint("Осталось: %d · коснись, чтобы продолжить" % left if left > 0 else "Коснись, чтобы увидеть итог")


func _summary() -> void:
	step = c.cards.size() + 1
	_clear()
	var ic := UI.icon("chests/%s_open" % c.type, 10)
	_stage.add_child(UI.center(ic))
	var g := UI.stat("coin", "+%d золота" % int(c.gold), UI.GOLD, 36)
	g.alignment = BoxContainer.ALIGNMENT_CENTER
	_stage.add_child(g)
	var grid := GridContainer.new()
	grid.columns = 4
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 8)
	for s in c.cards:
		var v := UI.vbox(2)
		v.add_child(UI.mini_card({"id": s.id, "lvl": Progress.level_of(s.id)}, 150, 170))
		var txt := "×%d" % int(s.n)
		if s.get("new", false):
			txt = "НОВАЯ ×%d" % int(s.n)
		v.add_child(UI.label(txt, 22, UI.GOLD if s.get("new", false) else UI.TEXT, HORIZONTAL_ALIGNMENT_CENTER, false))
		grid.add_child(v)
	_stage.add_child(UI.center(grid))
	var ready := 0
	for s in c.cards:
		if Progress.can_upgrade(s.id):
			ready += 1
	if ready > 0:
		_stage.add_child(UI.label("Можно улучшить карт: %d — загляни во вкладку «Карты»" % ready, 22, UI.GREEN, HORIZONTAL_ALIGNMENT_CENTER))
	var row := UI.hbox(10)
	var ok := UI.button("Забрать", _to_menu.bind("home"), 28, 84)
	UI.tint_button(ok, UI.GOLD)
	row.add_child(ok)
	if ready > 0:
		var db := UI.button("К картам", _to_menu.bind("deck"), 28, 84)
		UI.tint_button(db, UI.GREEN)
		row.add_child(db)
	_stage.add_child(row)


func _to_menu(tab: String) -> void:
	Progress.opening = {}
	var menu_script = load("res://scripts/screens/menu.gd")
	menu_script.tab = tab
	Game.main.goto("menu")
