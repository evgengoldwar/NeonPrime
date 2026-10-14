extends Control
## Итоги забега: победа или поражение, путь, лучшее комбо, убитые герои, Души, открытия.

const UI := preload("res://scripts/ui/ui.gd")


func _ready() -> void:
	var r: Dictionary = Game.pending
	var won: bool = r.get("won", false)
	Sfx.stop_music()
	Sfx.play("kill" if won else "lose")
	var lay := UI.screen_layout(self, "Победа!" if won else "Поражение")
	var body: VBoxContainer = lay.body
	var m: Dictionary = Data.masters.get(r.get("master", "dark_lord"), {})
	body.add_child(UI.label(("Подземелье выстояло. " if won else "Казна опустела. ") + "Хозяин: " + m.get("name", ""), 24, UI.TEXT, HORIZONTAL_ALIGNMENT_CENTER))
	var p := UI.panel(UI.PANEL2, 14, 16)
	var v := UI.vbox(8)
	p.add_child(v)
	var path := []
	for step in r.get("path", []):
		path.append("Этаж %d: %s" % [int(step.floor), Data.locations[step.location].name])
	v.add_child(UI.label("Пройденный путь:\n" + "\n".join(path), 22))
	v.add_child(UI.label("Убито героев: %d" % int(r.get("kills", 0)), 22))
	v.add_child(UI.label("Лучшее комбо: ×%d" % int(r.get("best_combo", 0)), 22))
	if won:
		v.add_child(UI.label("Осталось в Казне: %d" % int(r.get("treasury", 0)), 22, UI.GOLD))
	v.add_child(UI.label("Заработано Душ: %d" % int(r.get("souls", 0)), 28, UI.SOUL))
	body.add_child(p)
	var unlocked: Array = r.get("unlocked", [])
	if not unlocked.is_empty():
		body.add_child(UI.label("Открыто:", 24, UI.GOLD))
		for u in unlocked:
			body.add_child(UI.label(u, 22, UI.GREEN))
	body.add_child(UI.label("Всего Душ: %d. Потратьте их в Замке." % int(Game.meta.souls), 20, UI.DIM, HORIZONTAL_ALIGNMENT_CENTER))
	lay.footer.add_child(UI.button("В меню", func(): Game.main.goto("menu"), 26, 76))
	if not r.get("daily", false):
		var again := UI.button("Ещё раз", func(): Game.main.goto("master_select"), 26, 76)
		UI.tint_button(again, UI.ACCENT)
		lay.footer.add_child(again)
