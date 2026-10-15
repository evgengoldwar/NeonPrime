extends Control
## Выбор локации текущего этажа.

const UI := preload("res://scripts/ui/ui.gd")
const BattleScript := preload("res://scripts/core/battle.gd")


func _ready() -> void:
	Sfx.music(1.0)
	var lay := UI.screen_layout(self, "Этаж %d" % int(Game.run.floor))
	var tb := UI.top_bar()
	lay.root.add_child(tb)
	lay.root.move_child(tb, 0)
	var body: VBoxContainer = lay.body
	body.add_child(UI.label("Выбери, где встретить героев", 24, UI.DIM, HORIZONTAL_ALIGNMENT_CENTER))
	for id in Game.run.location_options:
		var l: Dictionary = Data.locations[id]
		var p := UI.framed("panel", 14)
		var v := UI.vbox(10)
		p.add_child(v)
		# Витрина: пол локации, местные герои и босс
		var scene := Control.new()
		scene.custom_minimum_size = Vector2(0, 112)
		scene.clip_contents = true
		scene.add_child(UI.tiled("tiles/floor_" + str(id)))
		var row := UI.hbox(18)
		row.alignment = BoxContainer.ALIGNMENT_CENTER
		UI.full(row)
		for h in l.locals:
			var hi := UI.hero_icon(h, 6)
			hi.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			row.add_child(hi)
		var boss := UI.hero_icon(l.boss, 8)
		boss.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(boss)
		scene.add_child(row)
		v.add_child(scene)
		v.add_child(UI.label(l.name, 32, Color(l.light)))
		v.add_child(UI.label(l.desc, 16, UI.DIM))
		v.add_child(UI.label(l.rule_text, 16, UI.GOLD))
		var mods := []
		for m in l.get("cell_mods", []):
			mods.append(BattleScript.CELL_MODS[m][0])
		if not mods.is_empty():
			v.add_child(UI.label("Особые клетки: " + ", ".join(mods), 16, UI.SOUL))
		var locals := []
		for h in l.locals:
			var hd: Dictionary = Data.hero_def(h)
			locals.append(hd.name + ": " + hd.trait_text)
		v.add_child(UI.label("\n".join(locals), 16, UI.TEXT))
		var cards := UI.hbox(10)
		cards.add_child(UI.label("Новые карты:", 16, UI.DIM, HORIZONTAL_ALIGNMENT_LEFT, false))
		for c in l.cards:
			cards.add_child(UI.card_icon(c, 3))
			cards.add_child(UI.label(Data.card_name(c), 16, UI.TEXT, HORIZONTAL_ALIGNMENT_LEFT, false))
		v.add_child(cards)
		v.add_child(UI.label("Босс: " + Data.hero_def(l.boss).name, 24, UI.RED))
		var b := UI.button("Выбрать", func(): _choose(id), 32, 72)
		UI.tint_button(b, UI.GOLD)
		v.add_child(b)
		body.add_child(p)


func _choose(id: String) -> void:
	Game.choose_location(id)
	Game.main.goto("map")
