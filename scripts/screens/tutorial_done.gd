extends Control
## Конец обучения: короткая памятка и переход в первый (сокращённый до 1 этажа) забег.

const UI := preload("res://scripts/ui/ui.gd")


func _ready() -> void:
	var lay := UI.screen_layout(self, "Обучение пройдено")
	var body: VBoxContainer = lay.body
	var tips := [
		"Герой идёт сверху вниз. Карта срабатывает, когда он на неё наступает.",
		"Порядок решает: Замедление перед Шипами удваивает урон за каждый стак.",
		"Казна — это и здоровье, и деньги. Сбежавший герой уносит свою Жадность.",
		"Убил героя — получил его Жадность и выбрал новую карту.",
		"Тьма — 3 за зал. Неистраченная сгорает.",
		"Долгое нажатие на карту или героя покажет подробности.",
	]
	for t in tips:
		var p := UI.panel(UI.PANEL2, 12, 12)
		p.add_child(UI.label(t, 22))
		body.add_child(p)
	body.add_child(UI.label("Первый забег сокращён до 1 этажа. Удачи, Тёмный владыка!", 22, UI.GOLD, HORIZONTAL_ALIGNMENT_CENTER))
	var b := UI.button("Начать забег", func(): Game.main.goto(Game.run.get("screen", "location")), 28, 90)
	UI.tint_button(b, UI.ACCENT)
	lay.footer.add_child(b)
