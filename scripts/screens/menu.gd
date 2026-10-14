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
	var sp := UI.spacer(0)
	sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(sp)
	var souls := UI.framed("panel_dark", 8)
	souls.add_child(UI.stat("soul", str(int(Game.meta.souls)), UI.SOUL, 32))
	top.add_child(souls)
	v.add_child(UI.spacer(40))
	var logo := UI.framed("popup", 18)
	var lv := UI.vbox(6)
	logo.add_child(lv)
	lv.add_child(UI.center(UI.icon("masters/dark_lord", 8)))
	lv.add_child(UI.title("Я — ПОДЗЕМЕЛЬЕ", 48))
	lv.add_child(UI.label("Не дай героям добраться до Казны", 16, UI.DIM, HORIZONTAL_ALIGNMENT_CENTER))
	v.add_child(logo)
	v.add_child(UI.spacer(0, true))
	if Game.has_run():
		var b := UI.button("Продолжить забег", func(): Game.main.goto(Game.resume_screen()), 32, 88)
		UI.tint_button(b, UI.GREEN)
		v.add_child(b)
	v.add_child(UI.tint_button(UI.button("Новый забег", _new_run, 32, 88), UI.RED))
	var row := UI.hbox()
	row.add_child(UI.button("Замок", func(): Game.main.goto("castle")))
	row.add_child(UI.button("Трофейный зал", func(): Game.main.goto("trophies")))
	v.add_child(row)
	var row2 := UI.hbox()
	row2.add_child(UI.button("Ежедневное подземелье", func(): Game.main.goto("daily")))
	row2.add_child(UI.button("Настройки", func(): Game.main.goto("settings")))
	v.add_child(row2)
	if CrashLog.crashed_last_time and not CrashLog.report_shown:
		CrashLog.report_shown = true
		_show_crash_report.call_deferred()
	v.add_child(UI.label("ЗАБЕГОВ %d · ПОБЕД %d · УБИТО %d" % [int(Game.meta.runs), int(Game.meta.wins), int(Game.meta.kills)], 16, UI.DIM, HORIZONTAL_ALIGNMENT_CENTER))


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
	UI.backdrop(self, "tiles/wall_menu", 0.2)
	var hall := Control.new()
	hall.anchor_left = 0.5
	hall.anchor_right = 0.5
	hall.anchor_bottom = 1.0
	hall.offset_left = -128
	hall.offset_right = 128
	hall.clip_contents = true
	hall.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(hall)
	hall.add_child(UI.tiled("tiles/floor_cellar"))
	var shade := ColorRect.new()
	shade.color = Color(0.09, 0.07, 0.11, 0.45)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	UI.full(shade)
	hall.add_child(shade)
	var ids := ["warrior", "thief", "mage", "paladin", "bard"]
	for i in ids.size():
		var hero := UI.hero_icon(ids[i], 5)
		hero.size = hero.custom_minimum_size
		hall.add_child(hero)
		hero.position = Vector2(20 + (i % 3) * 70, -80)
		var tw := hero.create_tween().set_loops()
		tw.tween_interval(i * 1.6)
		tw.tween_property(hero, "position:y", 1300.0, 10.0).from(-80.0)
	for y in [180, 520, 860]:
		for side in [0, 1]:
			var t := UI.icon("icons/torch", 4)
			t.size = Vector2(32, 32)
			t.anchor_left = 0.5
			t.anchor_right = 0.5
			t.offset_left = -164 if side == 0 else 132
			t.offset_right = t.offset_left + 32
			t.offset_top = y
			t.offset_bottom = y + 32
			add_child(t)
			var fl := t.create_tween().set_loops()
			fl.tween_property(t, "modulate", Color(1.3, 1.1, 0.85), 0.35)
			fl.tween_property(t, "modulate", Color.WHITE, 0.35)
