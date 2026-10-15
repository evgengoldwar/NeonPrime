extends Control
## Карта этажа: граф узлов снизу вверх, пиксельные значки и пунктирные тропы.

const UI := preload("res://scripts/ui/ui.gd")
const RunMenus := preload("res://scripts/ui/run_menus.gd")

const ROW_H := 160
const NODE := 84

var canvas: Control
var positions := {}


func _ready() -> void:
	var loc: Dictionary = Data.locations[Game.run.location]
	Sfx.music(0.85 + 0.05 * Data.location_list.find(loc))
	UI.backdrop(self, "tiles/floor_" + str(loc.id), 0.6)
	var m := UI.margin(12)
	UI.full(m)
	add_child(m)
	var v := UI.vbox(10)
	m.add_child(v)
	v.add_child(UI.top_bar())
	var head := UI.framed("panel", 12)
	var hh := UI.hbox(12)
	head.add_child(hh)
	hh.add_child(UI.hero_icon(loc.boss, 5))
	var hv := UI.vbox(2)
	hv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hh.add_child(hv)
	hv.add_child(UI.label(loc.name, 32, Color(loc.light)))
	hv.add_child(UI.label(loc.rule_text, 16, UI.DIM))
	v.add_child(head)
	v.add_child(_legend())
	var sc := UI.scroll()
	v.add_child(sc)
	canvas = Control.new()
	canvas.custom_minimum_size = Vector2(680, ROW_H * 7 + 40)
	canvas.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sc.add_child(canvas)
	_layout_nodes()
	canvas.draw.connect(_draw_links)
	var buttons := UI.hbox(8)
	buttons.add_child(UI.button("Колода %d" % Game.run.deck.size(), func(): RunMenus.deck(self), 24, 64))
	buttons.add_child(UI.button("Реликвии %d" % Game.run.relics.size(), func(): RunMenus.relics(self), 24, 64))
	var pause := UI.button("II", func(): RunMenus.pause(self), 24, 64)
	pause.custom_minimum_size = Vector2(72, 64)
	pause.size_flags_horizontal = Control.SIZE_SHRINK_END
	buttons.add_child(pause)
	v.add_child(buttons)
	# Карта читается снизу вверх: прокручиваем к текущему ряду.
	await get_tree().process_frame
	if not is_inside_tree() or Game.run.is_empty():
		return
	var cur := int(Game.run.current)
	var row := 0 if cur < 0 else int(Game.map_node(cur).row)
	sc.scroll_vertical = int(maxf(0.0, canvas.custom_minimum_size.y - ROW_H * (row + 4)))


func _node_pos(n: Dictionary) -> Vector2:
	var w := 680.0
	var x := w * (int(n.col) + 1) / float(int(n.count) + 1)
	var y := canvas.custom_minimum_size.y - 70 - int(n.row) * ROW_H
	return Vector2(x, y)


func _layout_nodes() -> void:
	var avail: Array = Game.available_nodes()
	var cartographer: bool = Game.upgrade_level("cartographer") > 0
	for n in Game.run.map.nodes:
		var pos := _node_pos(n)
		positions[int(n.id)] = pos
		var is_avail: bool = int(n.id) in avail
		var visited: bool = n.get("visited", false)
		var is_boss: bool = n.type == "boss"
		var sz: float = 116.0 if is_boss else float(NODE)
		var b := Button.new()
		b.size = Vector2(sz, sz)
		b.position = pos - b.size / 2
		var fr := "btn"
		if is_boss:
			fr = "card_monster"
		elif is_avail:
			fr = "btn_gold"
		b.add_theme_stylebox_override("normal", UI.frame(fr, 4))
		b.add_theme_stylebox_override("hover", UI.frame("btn_gold_hover" if is_avail else fr, 4))
		b.add_theme_stylebox_override("pressed", UI.frame("btn_pressed", 4))
		b.add_theme_stylebox_override("disabled", UI.frame("card_monster" if is_boss else "panel_dark", 4))
		b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
		var ic := UI.icon("nodes/" + str(n.type), 7 if is_boss else 5)
		UI.full(ic)
		b.add_child(ic)
		if visited:
			ic.modulate = Color(0.45, 0.45, 0.5)
		elif not is_avail and not is_boss:
			ic.modulate = Color(0.75, 0.72, 0.8)
		b.disabled = not is_avail
		var tip: String = Game.NODE_NAMES.get(n.type, "")
		if n.type == "event" and cartographer and n.event != "":
			tip = Data.events[n.event].name
			var cap := UI.label(Data.events[n.event].name, 16, UI.SOUL, HORIZONTAL_ALIGNMENT_CENTER)
			cap.size = Vector2(150, 40)
			cap.position = Vector2((sz - 150) / 2.0, sz)
			b.add_child(cap)
		b.tooltip_text = tip
		# Подпись под доступными узлами и боссом: сразу видно, куда идёшь.
		if (is_avail or is_boss) and not (n.type == "event" and cartographer and n.event != ""):
			var nm := UI.label(tip, 16, UI.GOLD if is_avail else UI.RED, HORIZONTAL_ALIGNMENT_CENTER, false)
			nm.add_theme_color_override("font_outline_color", UI.INK)
			nm.add_theme_constant_override("outline_size", 6)
			nm.size = Vector2(150, 24)
			nm.position = Vector2((sz - 150) / 2.0, sz + 2)
			b.add_child(nm)
		var nid := int(n.id)
		b.pressed.connect(func(): _enter(nid))
		canvas.add_child(b)
		if is_avail:
			b.pivot_offset = b.size / 2
			var tw := b.create_tween().set_loops()
			tw.tween_property(b, "scale", Vector2(1.08, 1.08), 0.5)
			tw.tween_property(b, "scale", Vector2.ONE, 0.5)
	if int(Game.run.current) >= 0:
		var here := UI.icon("masters/" + str(Game.run.master), 4)
		here.size = here.custom_minimum_size
		var at: Vector2 = positions[int(Game.run.current)]
		here.position = at - here.size / 2 + Vector2(44, -40)
		here.z_index = 2
		canvas.add_child(here)


## Легенда значков карты.
func _legend() -> Control:
	var p := UI.framed("panel_dark", 6)
	var g := GridContainer.new()
	g.columns = 4
	g.add_theme_constant_override("h_separation", 10)
	g.add_theme_constant_override("v_separation", 2)
	p.add_child(g)
	for t in ["battle", "elite", "shop", "altar", "event", "treasure", "boss"]:
		var h := UI.hbox(4)
		h.add_child(UI.icon("nodes/" + t, 3))
		h.add_child(UI.label(Game.NODE_NAMES.get(t, t), 16, UI.DIM, HORIZONTAL_ALIGNMENT_LEFT, false))
		g.add_child(h)
	return p


## Пунктирные пиксельные тропы между узлами.
func _draw_links() -> void:
	for n in Game.run.map.nodes:
		var a: Vector2 = positions[int(n.id)]
		for l in n.links:
			var b: Vector2 = positions[int(l)]
			var on_path: bool = n.get("visited", false) and Game.map_node(int(l)).get("visited", false)
			var col := UI.GOLD if on_path else Color(0.95, 0.9, 1.0, 0.35)
			var dist := a.distance_to(b)
			var steps := int(dist / 14.0)
			for i in range(1, steps):
				var p := a.lerp(b, float(i) / steps).round()
				canvas.draw_rect(Rect2(p - Vector2(3, 3), Vector2(6, 6)), col)


func _enter(id: int) -> void:
	Sfx.play("place")
	Game.enter_node(id)
