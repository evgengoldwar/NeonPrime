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
		800: _shot("game3")
		1000: _shot("game4")
		1300: _shot("game5")
		1301: get_tree().quit()
	if frames > 110 and frames < 1300 and node.state == node.State.PLAYING:
		node.has_armor = true
		if frames % 40 == 0:
			var dirs := [Vector3i(1,0,0), Vector3i(-1,0,0), Vector3i(0,1,0), Vector3i(0,-1,0), Vector3i(0,0,1), Vector3i(0,0,-1)]
			node.try_move(dirs[randi() % dirs.size()])
