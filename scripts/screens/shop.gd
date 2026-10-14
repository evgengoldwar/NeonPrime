extends Control
## Магазин гоблина: 5 карт, 2 реликвии, удаление карты. Платим золотом Казны — это риск.

const UI := preload("res://scripts/ui/ui.gd")
const RunMenus := preload("res://scripts/ui/run_menus.gd")


func _ready() -> void:
	_build()


func _build() -> void:
	for ch in get_children():
		ch.queue_free()
	var s: Dictionary = Game.pending
	var lay := UI.screen_layout(self, "Магазин гоблина")
	var tb := UI.top_bar()
	lay.root.add_child(tb)
	lay.root.move_child(tb, 0)
	var body: VBoxContainer = lay.body
	body.add_child(UI.label("«Золото — это жизнь, хозяин. Тратьте с умом, хе-хе.»", 20, UI.DIM, HORIZONTAL_ALIGNMENT_CENTER))
	var grid := GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 10)
	var cards: Array = s.get("cards", [])
	for i in cards.size():
		var it = cards[i]
		var v := UI.vbox(4)
		var cv := UI.card_view(it.id, false, 210)
		cv.mouse_filter = Control.MOUSE_FILTER_STOP
		cv.gui_input.connect(_card_input.bind(it.id))
		if it.sold:
			cv.modulate = Color(1, 1, 1, 0.3)
		v.add_child(cv)
		var b := UI.button("Продано" if it.sold else "%d золота" % int(it.price), func(): _buy_card(i), 20, 56)
		b.disabled = it.sold or not _affordable(int(it.price))
		v.add_child(b)
		grid.add_child(v)
	body.add_child(grid)
	body.add_child(UI.label("Реликвии", 26, UI.GOLD))
	var relics: Array = s.get("relics", [])
	for i in relics.size():
		var it = relics[i]
		var h := UI.hbox(10)
		var rv := UI.relic_view(it.id)
		rv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		if it.sold:
			rv.modulate = Color(1, 1, 1, 0.3)
		h.add_child(rv)
		var b := UI.button("Продано" if it.sold else "%d" % int(it.price), func(): _buy_relic(i), 22, 64)
		b.custom_minimum_size = Vector2(130, 64)
		b.size_flags_horizontal = Control.SIZE_SHRINK_END
		b.disabled = it.sold or not _affordable(int(it.price))
		h.add_child(b)
		body.add_child(h)
	var price: int = Game.removal_price()
	var rb := UI.button("Удалить карту из колоды — %d золота" % price, _remove, 22, 70)
	rb.disabled = s.get("removed", false) or not _affordable(price)
	if s.get("removed", false):
		rb.text = "Удаление уже использовано"
	body.add_child(rb)
	body.add_child(UI.label("Нельзя потратить последнее золото: Казна должна остаться больше 0.", 16, UI.DIM, HORIZONTAL_ALIGNMENT_CENTER))
	lay.footer.add_child(UI.button("Колода (%d)" % Game.run.deck.size(), func(): RunMenus.deck(self), 22, 64))
	var leave := UI.button("Уйти", func(): Game.node_done(), 26, 76)
	UI.tint_button(leave, UI.ACCENT)
	lay.footer.add_child(leave)


func _affordable(price: int) -> bool:
	return int(Game.run.treasury) > price


func _card_input(ev: InputEvent, id: String) -> void:
	if ev is InputEventMouseButton and ev.pressed:
		UI.card_popup(self, id, false)


func _buy_card(i: int) -> void:
	var it = Game.pending.cards[i]
	if it.sold or not _affordable(int(it.price)):
		return
	Game.add_gold(-int(it.price))
	Game.add_card(it.id)
	it.sold = true
	Sfx.play("coin")
	Game.save_run()
	_build()


func _buy_relic(i: int) -> void:
	var it = Game.pending.relics[i]
	if it.sold or not _affordable(int(it.price)):
		return
	Game.add_gold(-int(it.price))
	Game.add_relic(it.id)
	it.sold = true
	Sfx.play("coin")
	Game.save_run()
	_build()


func _remove() -> void:
	RunMenus.pick_cards(self, "Удалить карту", 1, Callable(), _on_remove_chosen)


func _on_remove_chosen(chosen: Array) -> void:
	var price: int = Game.removal_price()
	if chosen.is_empty() or not _affordable(price):
		return
	Game.add_gold(-price)
	Game.remove_deck_card(int(chosen[0].uid))
	Game.run.removal_count = int(Game.run.removal_count) + 1
	Game.pending["removed"] = true
	Game.save_run()
	_build()
