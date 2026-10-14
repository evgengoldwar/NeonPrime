extends Control
## Выбор Хозяина подземелья: карусель, пассивка, стартовая колода, уровень Дурной славы.

const UI := preload("res://scripts/ui/ui.gd")

var idx := 0
var notoriety := 0
var lay := {}


func _ready() -> void:
	notoriety = int(Game.meta.notoriety_max)
	_build()


func _build() -> void:
	for ch in get_children():
		ch.queue_free()
	lay = UI.screen_layout(self, "Выбор Хозяина")
	var m: Dictionary = Data.master_list[idx]
	var unlocked: bool = Game.master_unlocked(m.id)
	var body: VBoxContainer = lay.body
	var nav := UI.hbox()
	body.add_child(nav)
	var prev := UI.button("<", func(): _shift(-1), 34)
	prev.custom_minimum_size = Vector2(90, 90)
	prev.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	nav.add_child(prev)
	var portrait := UI.framed("popup" if unlocked else "panel_dark", 12)
	portrait.custom_minimum_size = Vector2(0, 240)
	portrait.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var spr := UI.icon("masters/" + str(m.id), 16)
	if not unlocked:
		spr.modulate = Color(0, 0, 0, 0.85)
	portrait.add_child(UI.center(spr))
	nav.add_child(portrait)
	var nxt := UI.button(">", func(): _shift(1), 34)
	nxt.custom_minimum_size = Vector2(90, 90)
	nxt.size_flags_horizontal = Control.SIZE_SHRINK_END
	nav.add_child(nxt)
	body.add_child(UI.title(m.name, 36))
	body.add_child(UI.label("%d / %d" % [idx + 1, Data.master_list.size()], 18, UI.DIM, HORIZONTAL_ALIGNMENT_CENTER))
	if not unlocked:
		var wing: Dictionary = {}
		for w in Data.wings:
			if w.id == m.unlock:
				wing = w
		body.add_child(UI.label("Закрыт. Откройте крыло Замка «%s» за %d Душ." % [wing.get("name", "?"), int(wing.get("cost", 0))], 24, UI.RED, HORIZONTAL_ALIGNMENT_CENTER))
	var info := UI.panel(UI.PANEL, 14, 14)
	var iv := UI.vbox(8)
	info.add_child(iv)
	iv.add_child(UI.label("Пассивка: " + m.passive_text, 22))
	iv.add_child(UI.label("Стиль: " + m.style, 20, UI.DIM))
	iv.add_child(UI.stat("coin", "Казна %d" % int(m.treasury), UI.GOLD, 24))
	body.add_child(info)
	body.add_child(UI.label("Стартовая колода (10 карт)", 22, UI.GOLD))
	var grid := GridContainer.new()
	grid.columns = 5
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 8)
	for id in m.deck:
		var mc := UI.mini_card({"id": id, "up": false}, 124, 150)
		mc.mouse_filter = Control.MOUSE_FILTER_STOP
		mc.gui_input.connect(_card_input.bind(id))
		grid.add_child(mc)
	body.add_child(grid)
	# Дурная слава
	var nbox := UI.panel(UI.PANEL, 14, 12)
	var nv := UI.vbox(8)
	nbox.add_child(nv)
	var nh := UI.hbox()
	nv.add_child(nh)
	var minus := UI.button("−", func(): _set_notoriety(notoriety - 1), 30, 64)
	minus.custom_minimum_size = Vector2(80, 64)
	minus.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	nh.add_child(minus)
	var nl := UI.label("Дурная слава: %d" % notoriety, 26, UI.ACCENT.lightened(0.3), HORIZONTAL_ALIGNMENT_CENTER)
	nl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	nl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	nh.add_child(nl)
	var plus := UI.button("+", func(): _set_notoriety(notoriety + 1), 30, 64)
	plus.custom_minimum_size = Vector2(80, 64)
	plus.size_flags_horizontal = Control.SIZE_SHRINK_END
	nh.add_child(plus)
	if notoriety == 0:
		nv.add_child(UI.label("Без надбавок. Победа открывает следующий уровень.", 18, UI.DIM))
	else:
		var lines := []
		for i in notoriety:
			lines.append("%d. %s" % [i + 1, Data.notoriety[i]])
		nv.add_child(UI.label("\n".join(lines) + "\nДуши +%d%%" % (notoriety * 10), 18, UI.DIM))
	body.add_child(nbox)
	var start := UI.button("Начать", _start, 32, 96)
	start.disabled = not unlocked
	UI.tint_button(start, UI.ACCENT)
	lay.footer.add_child(start)
	lay.footer.add_child(UI.button("Назад", func(): Game.main.goto("menu"), 24, 64))


func _card_input(ev: InputEvent, id: String) -> void:
	if ev is InputEventMouseButton and ev.pressed:
		UI.card_popup(self, id, false)


func _shift(d: int) -> void:
	idx = posmod(idx + d, Data.master_list.size())
	_build()


func _set_notoriety(n: int) -> void:
	notoriety = clampi(n, 0, int(Game.meta.notoriety_max))
	_build()


func _start() -> void:
	var m: Dictionary = Data.master_list[idx]
	Game.new_run(m.id, notoriety)
	Game.main.goto(Game.run.screen)
