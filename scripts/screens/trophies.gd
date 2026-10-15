extends Control
## Трофейный зал: портреты убитых героев, коллекции и достижения.

const UI := preload("res://scripts/ui/ui.gd")

var embedded := false   # встроен во вкладку главного меню


func _ready() -> void:
	var lay := UI.screen_layout(self, "Трофейный зал")
	var body: VBoxContainer = lay.body
	body.add_child(UI.label("Общие классы (обычный и элитный)", 26, UI.GOLD))
	var g := _grid(4)
	for id in Data.classes.keys():
		g.add_child(_portrait(id, id, ""))
		g.add_child(_portrait(id, id + "_elite", "Элита"))
	body.add_child(g)
	body.add_child(UI.label("Коллекции", 26, UI.GOLD))
	for c in Data.collections:
		var done: bool = Game.has_collection(c.id)
		body.add_child(UI.label(("[+] " if done else "[ ] ") + c.name + ": " + c.text, 20, UI.GREEN if done else UI.DIM))
	body.add_child(UI.label("Местные герои", 26, UI.GOLD))
	var g2 := _grid(4)
	for id in Data.locals.keys():
		g2.add_child(_portrait(id, id, Data.locations[Data.locals[id].location].name))
	body.add_child(g2)
	body.add_child(UI.label("Боссы", 26, UI.GOLD))
	var g3 := _grid(4)
	for id in Data.bosses.keys():
		g3.add_child(_portrait(id, id, Data.locations[Data.bosses[id].location].name))
	g3.add_child(_portrait("chosen", "chosen", "Финал"))
	body.add_child(g3)
	var all_bosses := true
	for id in Data.bosses.keys():
		if not Game.meta.trophies.has(id):
			all_bosses = false
	body.add_child(UI.label(("[+] " if all_bosses else "[ ] ") + "Все боссы: новая рамка для портрета Хозяина", 20, UI.GREEN if all_bosses else UI.DIM))
	body.add_child(UI.label("Достижения", 26, UI.GOLD))
	for a in Data.achievements:
		var got: bool = a.id in Game.meta.achievements
		var p := UI.panel(UI.PANEL2 if got else UI.PANEL, 12, 10)
		var v := UI.vbox(2)
		p.add_child(v)
		v.add_child(UI.label(("[+] " if got else "") + a.name, 22, UI.GOLD if got else UI.TEXT))
		v.add_child(UI.label(a.text + " → " + a.reward, 18, UI.DIM))
		body.add_child(p)
	if not embedded:
		lay.footer.add_child(UI.button("Назад", func(): Game.main.goto("menu"), 24, 70))


func _grid(cols: int) -> GridContainer:
	var g := GridContainer.new()
	g.columns = cols
	g.add_theme_constant_override("h_separation", 10)
	g.add_theme_constant_override("v_separation", 10)
	return g


func _portrait(hero_id: String, key: String, sub: String) -> Control:
	var d: Dictionary = Data.hero_def(hero_id)
	var got: bool = Game.meta.trophies.has(key)
	var p := UI.framed("popup" if got else "panel_dark", 8)
	p.custom_minimum_size = Vector2(160, 168)
	var v := UI.vbox(2)
	p.add_child(v)
	var spr := UI.hero_icon(hero_id, 7)
	if not got:
		spr.modulate = Color(0, 0, 0, 0.8)
	v.add_child(UI.center(spr))
	v.add_child(UI.label(d.name if got else "???", 16, UI.TEXT if got else UI.DIM, HORIZONTAL_ALIGNMENT_CENTER))
	if sub != "":
		v.add_child(UI.label(sub, 14, UI.DIM, HORIZONTAL_ALIGNMENT_CENTER))
	UI.ignore_mouse(p)
	p.gui_input.connect(_portrait_input.bind(hero_id, got))
	return p


func _portrait_input(ev: InputEvent, hero_id: String, got: bool) -> void:
	if ev is InputEventMouseButton and ev.pressed:
		_show(hero_id, got)


func _show(id: String, got: bool) -> void:
	if not got:
		UI.info_popup(self, "???", "Этот герой ещё не убит. Убей его, чтобы повесить портрет на стену.")
		return
	var extra := ""
	for c in Data.collections:
		if c.id == id:
			extra = c.text + (" (собрана)" if Game.has_collection(id) else " (нужны обычный и элитный)")
	UI.hero_popup(self, id, {}, extra)
