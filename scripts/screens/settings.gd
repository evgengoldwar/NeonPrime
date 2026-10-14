extends Control
## Настройки: звук, музыка, вибрация, скорость боя, язык, сброс прогресса.

const UI := preload("res://scripts/ui/ui.gd")


func _ready() -> void:
	var lay := UI.screen_layout(self, "Настройки")
	var body: VBoxContainer = lay.body
	body.add_child(_toggle("Звук", "sound"))
	body.add_child(_toggle("Музыка", "music"))
	body.add_child(_toggle("Вибрация", "vibration"))
	var sp := UI.panel(UI.PANEL, 12, 12)
	var sh := UI.hbox()
	sp.add_child(sh)
	var sl := UI.label("Скорость боя по умолчанию", 24)
	sl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sh.add_child(sl)
	for s in [1, 2, 4]:
		var b := UI.button("x%d" % s, func(): _set_speed(s), 24, 64)
		b.custom_minimum_size = Vector2(80, 64)
		b.size_flags_horizontal = Control.SIZE_SHRINK_END
		if int(Game.setting("speed")) == s:
			UI.tint_button(b, UI.ACCENT)
		sh.add_child(b)
	body.add_child(sp)
	var lp := UI.panel(UI.PANEL, 12, 12)
	var lh := UI.hbox()
	lp.add_child(lh)
	var ll := UI.label("Язык", 24)
	ll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lh.add_child(ll)
	var opt := OptionButton.new()
	opt.add_item("Русский")
	opt.add_theme_font_size_override("font_size", 24)
	opt.custom_minimum_size = Vector2(220, 64)
	lh.add_child(opt)
	body.add_child(lp)
	body.add_child(UI.spacer(30))
	body.add_child(UI.button("Отчёт об ошибке", _show_report, 24, 70))
	var reset := UI.button("Сбросить прогресс", _reset_1, 24, 70)
	UI.tint_button(reset, UI.RED)
	body.add_child(reset)
	lay.footer.add_child(UI.button("Назад", func(): Game.main.goto("menu"), 24, 70))


func _toggle(text: String, key: String) -> Control:
	var p := UI.panel(UI.PANEL, 12, 12)
	var h := UI.hbox()
	p.add_child(h)
	var l := UI.label(text, 24)
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	h.add_child(l)
	var cb := CheckButton.new()
	cb.button_pressed = bool(Game.setting(key))
	cb.toggled.connect(func(on): _apply_setting(key, on))
	h.add_child(cb)
	return p


func _apply_setting(key: String, on: bool) -> void:
	Game.set_setting(key, on)
	if key == "music":
		Sfx.refresh_music()


func _set_speed(s: int) -> void:
	Game.set_setting("speed", s)
	Game.main.goto("settings")


func _show_report() -> void:
	var p := UI.popup(self, "Отчёт об ошибке", "Закрыть")
	var text: String = CrashLog.latest_report()
	if CrashLog.report_path != "":
		p.box.add_child(UI.label("Файл: " + CrashLog.report_path, 16, UI.GOLD))
	var lines := text.split("\n")
	var tail := "\n".join(lines.slice(maxi(0, lines.size() - 14)))
	var sc := UI.scroll()
	sc.custom_minimum_size = Vector2(0, 420)
	sc.add_child(UI.label(tail, 16, UI.DIM))
	p.box.add_child(sc)
	var copy := UI.button("Скопировать отчёт", Callable(), 28, 80)
	copy.pressed.connect(_copy_report.bind(copy))
	UI.tint_button(copy, UI.GOLD)
	p.box.add_child(copy)


func _copy_report(btn: Button) -> void:
	CrashLog.copy_report()
	btn.text = "Скопировано!"


func _reset_1() -> void:
	var p := UI.popup(self, "Сбросить прогресс?", "Отмена")
	p.box.add_child(UI.label("Все Души, крылья, трофеи и текущий забег будут удалены.", 22))
	p.box.add_child(UI.tint_button(UI.button("Да, сбросить", _reset_2.bind(p.overlay)), UI.RED))


func _reset_2(prev: Control) -> void:
	prev.queue_free()
	var p := UI.popup(self, "Точно?", "Нет")
	p.box.add_child(UI.label("Это действие нельзя отменить.", 22, UI.RED))
	p.box.add_child(UI.tint_button(UI.button("Удалить всё", _reset_final), UI.RED))


func _reset_final() -> void:
	Game.reset_progress()
	Game.main.toast("Прогресс сброшен")
	Game.main.goto("menu")
