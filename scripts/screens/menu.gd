extends Control
## Главное меню с анимированным залом, по которому бродят герои.

const UI := preload("res://scripts/ui/ui.gd")


func _ready() -> void:
	Sfx.music(1.0)
	_build_background()
	var m := UI.margin(24)
	UI.full(m)
	add_child(m)
	var v := UI.vbox(16)
	m.add_child(v)
	var top := UI.hbox()
	v.add_child(top)
	top.add_child(UI.spacer(0))
	var souls := UI.label("Души: %d" % int(Game.meta.souls), 26, UI.SOUL, HORIZONTAL_ALIGNMENT_RIGHT, false)
	souls.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(souls)
	v.add_child(UI.spacer(60))
	v.add_child(UI.title("Я — ПОДЗЕМЕЛЬЕ", 60))
	v.add_child(UI.label("Не дай героям добраться до Казны", 24, UI.DIM, HORIZONTAL_ALIGNMENT_CENTER))
	v.add_child(UI.spacer(0, true))
	if Game.has_run():
		var b := UI.button("Продолжить забег", func(): Game.main.goto(Game.resume_screen()), 30, 90)
		UI.tint_button(b, UI.GREEN)
		v.add_child(b)
	v.add_child(UI.tint_button(UI.button("Новый забег", _new_run, 30, 90), UI.ACCENT))
	var row := UI.hbox()
	row.add_child(UI.button("Замок", func(): Game.main.goto("castle")))
	row.add_child(UI.button("Трофейный зал", func(): Game.main.goto("trophies")))
	v.add_child(row)
	var row2 := UI.hbox()
	row2.add_child(UI.button("Ежедневное подземелье", func(): Game.main.goto("daily")))
	row2.add_child(UI.button("Настройки", func(): Game.main.goto("settings")))
	v.add_child(row2)
	v.add_child(UI.label("Забегов: %d · Побед: %d · Убито героев: %d" % [int(Game.meta.runs), int(Game.meta.wins), int(Game.meta.kills)], 18, UI.DIM, HORIZONTAL_ALIGNMENT_CENTER))


func _new_run() -> void:
	if Game.has_run():
		var p := UI.popup(self, "Новый забег?", "Отмена")
		p.box.add_child(UI.label("Текущий забег будет потерян.", 22))
		p.box.add_child(UI.tint_button(UI.button("Начать заново", _confirm_new), UI.RED))
		return
	_go_new()


func _confirm_new() -> void:
	Game.clear_run()
	_go_new()


func _go_new() -> void:
	if not Game.meta.tutorial_done:
		Game.start_tutorial()
		Game.main.goto("battle")
	else:
		Game.main.goto("master_select")


func _build_background() -> void:
	var hall := ColorRect.new()
	hall.color = Color("#1c1426")
	hall.anchor_left = 0.5
	hall.anchor_right = 0.5
	hall.anchor_bottom = 1.0
	hall.offset_left = -150
	hall.offset_right = 150
	hall.clip_contents = true
	hall.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(hall)
	for i in 7:
		var tile := ColorRect.new()
		tile.color = Color("#251b33") if i % 2 == 0 else Color("#1f172b")
		tile.position = Vector2(0, i * 190)
		tile.size = Vector2(300, 180)
		tile.mouse_filter = Control.MOUSE_FILTER_IGNORE
		hall.add_child(tile)
	var colors := ["#b5651d", "#3d5fc4", "#d4b84a", "#4a7d4a"]
	for i in colors.size():
		var hero := Panel.new()
		hero.add_theme_stylebox_override("panel", UI.style(Color(colors[i]), 30))
		hero.size = Vector2(46, 46)
		hero.mouse_filter = Control.MOUSE_FILTER_IGNORE
		hall.add_child(hero)
		var x := 40.0 + i * 60.0
		hero.position = Vector2(x, -60 - i * 300)
		var tw := hero.create_tween().set_loops()
		tw.tween_property(hero, "position:y", 1300.0, 9.0 + i).from(-60.0 - i * 120.0)
