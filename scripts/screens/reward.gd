extends Control
## Награда после боя: золото, реликвия (элита/босс) и выбор 1 карты из 3.

const UI := preload("res://scripts/ui/ui.gd")
const RunMenus := preload("res://scripts/ui/run_menus.gd")


func _ready() -> void:
	_build()


func _build() -> void:
	for ch in get_children():
		ch.queue_free()
	var r: Dictionary = Game.pending
	var lay := UI.screen_layout(self, "Награда")
	var tb := UI.top_bar()
	lay.root.add_child(tb)
	lay.root.move_child(tb, 0)
	var body: VBoxContainer = lay.body
	var names := []
	for k in r.get("killed", []):
		names.append(k.name)
	if not names.is_empty():
		body.add_child(UI.label("Повержены: " + ", ".join(names), 22, UI.TEXT, HORIZONTAL_ALIGNMENT_CENTER))
	body.add_child(UI.label("Золото в Казну: %+d" % int(r.get("gold", 0)), 26, UI.GOLD, HORIZONTAL_ALIGNMENT_CENTER))
	if r.get("relic", "") != "":
		body.add_child(UI.label("Получена реликвия:", 22, UI.TEXT, HORIZONTAL_ALIGNMENT_CENTER))
		body.add_child(UI.relic_view(r.relic))
	var relics: Array = r.get("relics", [])
	if not relics.is_empty() and not r.get("relic_taken", false):
		body.add_child(UI.label("Выбери 1 реликвию из 3", 26, UI.GOLD, HORIZONTAL_ALIGNMENT_CENTER))
		for id in relics:
			body.add_child(UI.relic_view(id))
			body.add_child(UI.button("Взять «%s»" % Data.relics[id].name, func(): _take_relic(id), 22, 64))
		return
	if r.get("card_taken", false):
		_done()
		return
	body.add_child(UI.label("Выбери 1 карту в колоду", 26, UI.GOLD, HORIZONTAL_ALIGNMENT_CENTER))
	var row := UI.hbox(10)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	for id in r.get("cards", []):
		var v := UI.vbox(6)
		var cv := UI.card_view(id, false, 215)
		cv.mouse_filter = Control.MOUSE_FILTER_STOP
		cv.gui_input.connect(_card_input.bind(id))
		v.add_child(cv)
		v.add_child(UI.button("Взять", func(): _take_card(id), 22, 64))
		row.add_child(v)
	body.add_child(row)
	body.add_child(UI.label("Долгое нажатие или тап по карте — подробности", 16, UI.DIM, HORIZONTAL_ALIGNMENT_CENTER))
	if Game.can_reroll():
		lay.footer.add_child(UI.button("Перебросить (1 раз за этаж)", _reroll, 22, 64))
	lay.footer.add_child(UI.button("Колода (%d)" % Game.run.deck.size(), func(): RunMenus.deck(self), 22, 64))
	lay.footer.add_child(UI.button("Пропустить (+3 золота)", _skip, 22, 70))


func _card_input(ev: InputEvent, id: String) -> void:
	if ev is InputEventMouseButton and ev.pressed:
		UI.card_popup(self, id, false)


func _take_relic(id: String) -> void:
	Game.add_relic(id)
	Game.pending["relic_taken"] = true
	Game.save_run()
	Sfx.play("coin")
	_build()


func _take_card(id: String) -> void:
	Game.add_card(id)
	Sfx.play("place")
	_done()


func _skip() -> void:
	Game.add_gold(3)
	Sfx.play("coin")
	_done()


func _reroll() -> void:
	Game.reroll_reward()
	_build()


func _done() -> void:
	Game.node_done()
