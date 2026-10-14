extends Control
## Ежедневное подземелье: общий сид на сутки, одна попытка, таблица рекордов.

const UI := preload("res://scripts/ui/ui.gd")

var _timer_label: Label


func _ready() -> void:
	var info: Dictionary = Game.daily_info()
	var lay := UI.screen_layout(self, "Ежедневное подземелье")
	var body: VBoxContainer = lay.body
	var m: Dictionary = Data.masters[info.master]
	var p := UI.panel(UI.PANEL2, 14, 16, UI.ACCENT, 2)
	var v := UI.vbox(8)
	p.add_child(v)
	v.add_child(UI.label("Правила на " + info.date, 26, UI.GOLD))
	v.add_child(UI.label("Хозяин: " + m.name + " — " + m.passive_text, 22))
	v.add_child(UI.label("Модификатор: " + Game.DAILY_MODS[info.mod], 22))
	v.add_child(UI.label("Все крылья и карты доступны. Карта этажей, герои и награды одинаковы для всех игроков.", 18, UI.DIM))
	v.add_child(UI.label("Награда: +10 Душ за попытку, +20 за победу", 20, UI.SOUL))
	body.add_child(p)
	_timer_label = UI.label("", 22, UI.DIM, HORIZONTAL_ALIGNMENT_CENTER)
	body.add_child(_timer_label)
	body.add_child(UI.label("Рекорды (по оставшейся Казне)", 26, UI.GOLD))
	var best: Array = Game.meta.daily.best
	if best.is_empty():
		body.add_child(UI.label("Пока нет результатов.", 20, UI.DIM))
	for i in best.size():
		var r = best[i]
		body.add_child(UI.label("%d. %s — Казна %d (%s)" % [i + 1, "Победа" if r.won else "Поражение", int(r.score), r.time], 20))
	var start := UI.button("Начать (1 попытка в день)", _start, 28, 90)
	UI.tint_button(start, UI.ACCENT)
	start.disabled = Game.meta.daily.done or Game.has_run()
	lay.footer.add_child(start)
	if Game.has_run():
		lay.footer.add_child(UI.label("Сначала завершите текущий забег.", 18, UI.RED, HORIZONTAL_ALIGNMENT_CENTER))
	elif Game.meta.daily.done:
		lay.footer.add_child(UI.label("Сегодняшняя попытка уже использована.", 18, UI.DIM, HORIZONTAL_ALIGNMENT_CENTER))
	lay.footer.add_child(UI.button("Назад", func(): Game.main.goto("menu"), 24, 70))
	_update_timer()


func _process(_d: float) -> void:
	_update_timer()


func _update_timer() -> void:
	var t := Time.get_time_dict_from_system()
	var left := 86400 - (int(t.hour) * 3600 + int(t.minute) * 60 + int(t.second))
	_timer_label.text = "До сброса: %02d:%02d:%02d" % [left / 3600, (left % 3600) / 60, left % 60]


func _start() -> void:
	Game.start_daily()
	Game.main.goto(Game.run.screen)
