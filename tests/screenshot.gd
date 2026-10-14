extends Node
## Renders a few screenshots for visual checks (needs a display, e.g. xvfb-run).
## Run: godot --rendering-driver opengl3 --fixed-fps 60 --path . res://tests/screenshot.tscn -- <out_dir>

var out_dir := "user://"
var frames := 0
var node: Node


func _ready() -> void:
	GameData.persist = false
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		out_dir = args[0]
	node = load("res://scenes/main_menu.tscn").instantiate()
	add_child(node)


func _shot(name: String) -> void:
	get_viewport().get_texture().get_image().save_png(out_dir.path_join(name + ".png"))


func _process(_d: float) -> void:
	frames += 1
	match frames:
		60: _shot("menu")
		70: node._open_upgrades()
		80: _shot("upgrades")
		90: node._open_settings()
		100: _shot("settings")
		110:
			node.queue_free()
			node = load("res://scenes/game.tscn").instantiate()
			add_child(node)
		400:
			node.has_armor = true
			node.freeze_time = 0.0
			_shot("game1")
		600: _shot("game2")
		700: node.distance = 497.0
		760: _shot("game3")
		900: node.distance = 997.0
		1000: _shot("game4")
		1150: node._spawn_gate({"type": "tunnel", "color": Color(1, 0.3, 0.1), "free": Vector2i(1, 1), "length": 9.0})
		1255: _shot("game5")
		1256: get_tree().quit()
	if frames > 110 and frames < 1300 and node.state == node.State.PLAYING:
		node.has_armor = true
		if frames % 25 == 0:
			var dirs := [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]
			node.try_move(dirs[randi() % dirs.size()])
