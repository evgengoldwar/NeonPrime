extends Control
## Ларец реликвий: в начале забега выбор 1 из 3 слабых реликвий.

const UI := preload("res://scripts/ui/ui.gd")


func _ready() -> void:
	var lay := UI.screen_layout(self, "Ларец реликвий")
	lay.body.add_child(UI.label("Выбери одну реликвию на весь забег.", 22, UI.DIM, HORIZONTAL_ALIGNMENT_CENTER))
	for id in Game.pending.get("relics", []):
		var p := UI.relic_view(id)
		lay.body.add_child(p)
		lay.body.add_child(UI.button("Взять «%s»" % Data.relics[id].name, func(): _take(id), 22, 64))
	lay.footer.add_child(UI.button("Пропустить", func(): _take(""), 22, 64))


func _take(id: String) -> void:
	if id != "":
		Game.add_relic(id)
	Game.pending = {}
	Game.run.screen = "location"
	Game.save_run()
	Game.main.goto("location")
