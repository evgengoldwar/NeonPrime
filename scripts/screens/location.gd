extends Control
## Выбор локации текущего этажа.

const UI := preload("res://scripts/ui/ui.gd")


func _ready() -> void:
	Sfx.music(1.0)
	var lay := UI.screen_layout(self, "Этаж %d: выбери локацию" % int(Game.run.floor))
	var tb := UI.top_bar()
	lay.root.add_child(tb)
	lay.root.move_child(tb, 0)
	var body: VBoxContainer = lay.body
	for id in Game.run.location_options:
		var l: Dictionary = Data.locations[id]
		var p := UI.panel(Color(l.bg), 16, 16, Color(l.light), 3)
		var v := UI.vbox(8)
		p.add_child(v)
		v.add_child(UI.label(l.name, 32, Color(l.light)))
		v.add_child(UI.label(l.desc, 20, UI.TEXT))
		v.add_child(UI.label(l.rule_text, 20, UI.GOLD))
		var locals := []
		for h in l.locals:
			var hd: Dictionary = Data.hero_def(h)
			locals.append("%s — %s" % [hd.name, hd.trait_text])
		v.add_child(UI.label("Местные герои:\n" + "\n".join(locals), 18, UI.DIM))
		var cards := []
		for c in l.cards:
			cards.append(Data.card_name(c))
		v.add_child(UI.label("Карты в пул наград: " + ", ".join(cards), 18, UI.DIM))
		v.add_child(UI.label("Босс: " + Data.hero_def(l.boss).name, 22, UI.RED))
		var b := UI.button("Выбрать", func(): _choose(id), 26, 72)
		UI.tint_button(b, Color(l.light))
		v.add_child(b)
		body.add_child(p)


func _choose(id: String) -> void:
	Game.choose_location(id)
	Game.main.goto("map")
