extends Control
## Сокровищница: сундук с золотом или реликвией.

const UI := preload("res://scripts/ui/ui.gd")


func _ready() -> void:
	Sfx.play("coin")
	var lay := UI.screen_layout(self, "Сокровищница")
	var tb := UI.top_bar()
	lay.root.add_child(tb)
	lay.root.move_child(tb, 0)
	var body: VBoxContainer = lay.body
	var chest := UI.framed("popup", 16)
	var cv := UI.vbox(8)
	chest.add_child(cv)
	cv.add_child(UI.center(UI.icon("nodes/treasure", 16)))
	cv.add_child(UI.title("Сундук открыт!", 40))
	body.add_child(chest)
	var p: Dictionary = Game.pending
	if int(p.get("gold", 0)) > 0:
		body.add_child(UI.center(UI.stat("coin", "+%d в Казну" % int(p.gold), UI.GOLD, 40)))
	elif p.get("relic", "") != "":
		body.add_child(UI.label("Реликвия:", 24, UI.TEXT, HORIZONTAL_ALIGNMENT_CENTER))
		body.add_child(UI.relic_view(p.relic))
	else:
		body.add_child(UI.label("Сундук пуст... кто-то побывал здесь раньше.", 24, UI.DIM, HORIZONTAL_ALIGNMENT_CENTER))
	var next := UI.button("Дальше", func(): Game.node_done(), 28, 84)
	UI.tint_button(next, UI.ACCENT)
	lay.footer.add_child(next)
