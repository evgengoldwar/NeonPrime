extends Control
## Алтарь тьмы: улучшить 1 карту до версии «+» бесплатно.
## Одинаковые карты колоды собраны в одну с пометкой «×N».

const UI := preload("res://scripts/ui/ui.gd")


func _ready() -> void:
	var lay := UI.screen_layout(self, "Алтарь тьмы")
	var tb := UI.top_bar()
	lay.root.add_child(tb)
	lay.root.move_child(tb, 0)
	var body: VBoxContainer = lay.body
	body.add_child(UI.label("Выбери карту — одна её копия станет версией «+». Каждую копию можно улучшить только 1 раз.", 24, UI.DIM, HORIZONTAL_ALIGNMENT_CENTER))
	# Группируем одинаковые неулучшенные карты
	var groups := {}
	var order := []
	for c in Game.upgradable_cards():
		if not groups.has(c.id):
			groups[c.id] = []
			order.append(c.id)
		groups[c.id].append(c)
	var grid := GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 14)
	for id in order:
		var copies: Array = groups[id]
		var v := UI.vbox(4)
		# PanelContainer без рамки кладёт детей друг на друга и растягивается по карте.
		var holder := PanelContainer.new()
		holder.add_theme_stylebox_override("panel", StyleBoxEmpty.new())
		var cv := UI.card_view(id, false, 212, Game.card_level(id))
		cv.mouse_filter = Control.MOUSE_FILTER_STOP
		cv.gui_input.connect(_card_input.bind(id))
		holder.add_child(cv)
		if copies.size() > 1:
			var badge := UI.framed("popup", 4)
			badge.add_child(UI.label("×%d" % copies.size(), 24, UI.GOLD, HORIZONTAL_ALIGNMENT_CENTER, false))
			badge.size_flags_horizontal = Control.SIZE_SHRINK_END
			badge.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
			badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
			holder.add_child(badge)
		v.add_child(holder)
		var changes := UI.framed("panel_dark", 8)
		var cvb := UI.vbox(2)
		changes.add_child(cvb)
		cvb.add_child(UI.label("Улучшение:", 16, UI.DIM))
		for line in Data.upgrade_changes(id, Game.card_level(id)):
			cvb.add_child(UI.label(line, 24, UI.GREEN))
		v.add_child(changes)
		var first: Dictionary = copies[0]
		var b := UI.button("Улучшить", func(): _upgrade(first), 24, 60)
		UI.tint_button(b, UI.GREEN)
		v.add_child(b)
		grid.add_child(v)
	body.add_child(grid)
	if order.is_empty():
		body.add_child(UI.label("Все карты уже улучшены.", 24, UI.DIM, HORIZONTAL_ALIGNMENT_CENTER))
	lay.footer.add_child(UI.button("Уйти", func(): Game.node_done(), 24, 70))


func _card_input(ev: InputEvent, id: String) -> void:
	if ev is InputEventMouseButton and ev.pressed:
		UI.card_popup(self, id, false, Game.card_level(id))


func _upgrade(c: Dictionary) -> void:
	c.up = true
	Sfx.play("combo")
	Game.main.toast("Улучшено: " + Data.card_name(c.id, true))
	Game.node_done()
