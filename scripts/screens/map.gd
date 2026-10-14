extends Control
## Карта этажа: граф узлов снизу вверх.

const UI := preload("res://scripts/ui/ui.gd")
const RunMenus := preload("res://scripts/ui/run_menus.gd")

const ROW_H := 165
const NODE_COLORS := {"battle": Color("#c05050"), "elite": Color("#e08030"), "shop": Color("#50b060"),
	"altar": Color("#9060e0"), "event": Color("#4a90d0"), "treasure": Color("#e0c040"), "boss": Color("#ff3060")}
const NODE_ICONS := {"battle": "Бой", "elite": "Элита", "shop": "Лавка", "altar": "Алтарь",
	"event": "?", "treasure": "Клад", "boss": "БОСС"}

var canvas: Control
var positions := {}


func _ready() -> void:
	var loc: Dictionary = Data.locations[Game.run.location]
	Sfx.music(0.85 + 0.05 * Data.location_list.find(loc))
	var m := UI.margin(14)
	UI.full(m)
	add_child(m)
	var v := UI.vbox(10)
	m.add_child(v)
	v.add_child(UI.top_bar())
	var buttons := UI.hbox(8)
	buttons.add_child(UI.button("Колода (%d)" % Game.run.deck.size(), func(): RunMenus.deck(self), 20, 60))
	buttons.add_child(UI.button("Реликвии (%d)" % Game.run.relics.size(), func(): RunMenus.relics(self), 20, 60))
	buttons.add_child(UI.button("Пауза", func(): RunMenus.pause(self), 20, 60))
	v.add_child(buttons)
	var head := UI.panel(Color(loc.bg), 12, 10, Color(loc.light), 2)
	var hv := UI.vbox(2)
	head.add_child(hv)
	hv.add_child(UI.label(loc.name, 26, Color(loc.light)))
	hv.add_child(UI.label(loc.rule_text, 16, UI.DIM))
	v.add_child(head)
	var sc := UI.scroll()
	v.add_child(sc)
	canvas = Control.new()
	canvas.custom_minimum_size = Vector2(680, ROW_H * 7 + 60)
	canvas.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sc.add_child(canvas)
	_layout_nodes()
	canvas.draw.connect(_draw_links)
	# Карта читается снизу вверх: прокручиваем к текущему ряду.
	await get_tree().process_frame
	var cur := int(Game.run.current)
	var row := 0 if cur < 0 else int(Game.map_node(cur).row)
	sc.scroll_vertical = int(maxf(0.0, canvas.custom_minimum_size.y - ROW_H * (row + 4)))


func _node_pos(n: Dictionary) -> Vector2:
	var w := 680.0
	var x := w * (int(n.col) + 1) / float(int(n.count) + 1)
	var y := canvas.custom_minimum_size.y - 80 - int(n.row) * ROW_H
	return Vector2(x, y)


func _layout_nodes() -> void:
	var avail: Array = Game.available_nodes()
	var cartographer: bool = Game.upgrade_level("cartographer") > 0
	for n in Game.run.map.nodes:
		var pos := _node_pos(n)
		positions[int(n.id)] = pos
		var is_avail: bool = int(n.id) in avail
		var visited: bool = n.get("visited", false)
		var col: Color = NODE_COLORS.get(n.type, Color.GRAY)
		var sz := 116.0 if n.type == "boss" else 92.0
		var b := Button.new()
		b.size = Vector2(sz, sz)
		b.position = pos - b.size / 2
		var txt: String = NODE_ICONS.get(n.type, "?")
		if n.type == "event" and cartographer and n.event != "":
			txt = Data.events[n.event].name.substr(0, 7) + "…"
		if n.type == "boss":
			txt = "БОСС\n" + Data.hero_def(Data.locations[Game.run.location].boss).name.split(" ")[0]
		b.text = txt
		b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		b.add_theme_font_size_override("font_size", 16 if txt.length() > 6 else 20)
		var bg := col.darkened(0.55)
		if visited:
			bg = col.darkened(0.2)
		elif not is_avail:
			bg = col.darkened(0.8)
		var border := Color.WHITE if is_avail else col.darkened(0.3)
		var st := UI.style(bg, int(sz / 2), border, 4 if is_avail else 2, 4)
		b.add_theme_stylebox_override("normal", st)
		b.add_theme_stylebox_override("hover", UI.style(bg.lightened(0.2), int(sz / 2), border, 4, 4))
		b.add_theme_stylebox_override("pressed", UI.style(col, int(sz / 2), Color.WHITE, 4, 4))
		b.add_theme_stylebox_override("disabled", st)
		b.disabled = not is_avail
		b.tooltip_text = Game.NODE_NAMES.get(n.type, "")
		var nid := int(n.id)
		b.pressed.connect(func(): _enter(nid))
		canvas.add_child(b)
		if is_avail:
			var tw := b.create_tween().set_loops()
			tw.tween_property(b, "modulate", Color(1.3, 1.3, 1.3), 0.6)
			tw.tween_property(b, "modulate", Color.WHITE, 0.6)


func _draw_links() -> void:
	for n in Game.run.map.nodes:
		var a: Vector2 = positions[int(n.id)]
		for l in n.links:
			var b: Vector2 = positions[int(l)]
			var on_path: bool = n.get("visited", false) and Game.map_node(int(l)).get("visited", false)
			var col := UI.GOLD if on_path else Color(1, 1, 1, 0.22)
			canvas.draw_line(a, b, col, 5.0 if on_path else 3.0, true)


func _enter(id: int) -> void:
	Sfx.play("place")
	Game.enter_node(id)
