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
	body.add_child(UI.center(UI.icon("masters/" + str(r.get("master", "dark_lord")), 12)))
	var p := UI.framed("panel", 16)
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
	v.add_child(UI.stat("soul", "+%d Душ" % int(r.get("souls", 0)), UI.SOUL, 32))
	body.add_child(p)
	body.add_child(_rewards(r, won))
	var unlocked: Array = r.get("unlocked", [])
	if not unlocked.is_empty():
		body.add_child(UI.label("Открыто:", 24, UI.GOLD))
		for u in unlocked:
			body.add_child(UI.label(u, 22, UI.GREEN))
	body.add_child(UI.label("Всего Душ: %d. Потратьте их в Замке." % int(Game.meta.souls), 20, UI.DIM, HORIZONTAL_ALIGNMENT_CENTER))
	var ok := UI.button("В меню", func(): Game.main.goto("menu"), 28, 84)
	UI.tint_button(ok, UI.GOLD)
	lay.footer.add_child(ok)


## Награды для коллекции: золото (остаток Казны), кристаллы и сундук.
func _rewards(r: Dictionary, won: bool) -> Control:
	var p := UI.framed("popup", 14)
	var v := UI.vbox(8)
	p.add_child(v)
	v.add_child(UI.label("Награда", 28, UI.GOLD, HORIZONTAL_ALIGNMENT_CENTER))
	var h := UI.hbox(16)
	h.alignment = BoxContainer.ALIGNMENT_CENTER
	var gold := int(r.get("reward_gold", 0))
	h.add_child(UI.stat("coin", "+%d" % gold, UI.GOLD, 32))
	h.add_child(UI.stat("gem", "+%d" % int(r.get("reward_gems", 0)), UI.GREEN, 32))
	v.add_child(h)
	if won:
		v.add_child(UI.label("Всё, что осталось в Казне, стало золотом для прокачки карт.", 18, UI.DIM, HORIZONTAL_ALIGNMENT_CENTER))
	else:
		v.add_child(UI.label("Казна разграблена — золота нет. Но сундук твой.", 18, UI.DIM, HORIZONTAL_ALIGNMENT_CENTER))
	var chest: String = r.get("reward_chest", "")
	if chest != "":
		var ch := UI.hbox(12)
		ch.alignment = BoxContainer.ALIGNMENT_CENTER
		ch.add_child(UI.icon("chests/" + chest, 6))
		var slot := int(r.get("reward_slot", -1))
		var txt := Progress.chest_name(chest) + ("\nждёт в слоте %d" % (slot + 1) if slot >= 0 else "\nВсе слоты заняты — сундук потерян!")
		ch.add_child(UI.label(txt, 22, UI.TEXT if slot >= 0 else UI.RED, HORIZONTAL_ALIGNMENT_LEFT, false))
		v.add_child(ch)
	return p
