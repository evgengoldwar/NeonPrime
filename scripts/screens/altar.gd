extends Control
## Алтарь тьмы: улучшить 1 карту до версии «+» бесплатно.

const UI := preload("res://scripts/ui/ui.gd")


func _ready() -> void:
	var lay := UI.screen_layout(self, "Алтарь тьмы")
	var tb := UI.top_bar()
	lay.root.add_child(tb)
	lay.root.move_child(tb, 0)
	var body: VBoxContainer = lay.body
	body.add_child(UI.label("Выбери карту, чтобы улучшить её до версии «+». Каждую карту можно улучшить только 1 раз.", 20, UI.DIM, HORIZONTAL_ALIGNMENT_CENTER))
	var grid := GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 8)
	var any := false
	for c in Game.upgradable_cards():
		any = true
		var v := UI.vbox(4)
		var cv := UI.card_view(c.id, false, 205)
		cv.mouse_filter = Control.MOUSE_FILTER_STOP
		cv.gui_input.connect(_card_input.bind(c.id))
		v.add_child(cv)
		v.add_child(UI.label("→ " + Data.card_text(c.id, true), 15, UI.GREEN))
		v.add_child(UI.button("Улучшить", func(): _upgrade(c), 20, 56))
		grid.add_child(v)
	body.add_child(grid)
	if not any:
		body.add_child(UI.label("Все карты уже улучшены.", 22, UI.DIM, HORIZONTAL_ALIGNMENT_CENTER))
	lay.footer.add_child(UI.button("Уйти", func(): Game.node_done(), 24, 70))


func _card_input(ev: InputEvent, id: String) -> void:
	if ev is InputEventMouseButton and ev.pressed:
		UI.card_popup(self, id, false)


func _upgrade(c: Dictionary) -> void:
	c.up = true
	Sfx.play("combo")
	Game.main.toast("Улучшено: " + Data.card_name(c.id, true))
	Game.node_done()
