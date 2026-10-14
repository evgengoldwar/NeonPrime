extends Node
## Headless smoke test: plays the game with a random bot (with god mode via
## permanent armor), then lets it die and opens every menu panel.
## Run: godot --headless --fixed-fps 60 --path . res://tests/smoke_test.tscn

var game: Node
var frames := 0
var hits := 0
var stats := {}


func _ready() -> void:
	GameData.persist = false
	game = load("res://scenes/game.tscn").instantiate()
	add_child(game)


func _process(_delta: float) -> void:
	frames += 1
	if frames < 60 * 100:
		if game.state == game.State.PLAYING:
			if not game.has_armor:
				hits += 1
				game.has_armor = true
			if frames % 20 == 0:
				var dirs := [Vector3i(1,0,0), Vector3i(-1,0,0), Vector3i(0,1,0), Vector3i(0,-1,0), Vector3i(0,0,1), Vector3i(0,0,-1)]
				game.try_move(dirs[randi() % dirs.size()])
			for o in game.obstacles:
				stats[o.get_script().get_global_name()] = true
	elif frames == 60 * 100:
		print("score=", int(game.score), " time=", snapped(game.time_alive, 0.1), " armor_saves=", hits, " kinds=", stats.keys(), " freeze=", game.freeze_time, " mult=", game.mult_factor)
		game.has_armor = false
		game.invuln_time = 0.0
		game._on_hit()
	elif frames == 60 * 103:
		print("state=", game.state, " leaderboard=", GameData.leaderboard.size(), " coins=", GameData.coins)
		game.queue_free()
		var menu = load("res://scenes/main_menu.tscn").instantiate()
		add_child(menu)
		game = menu
	elif frames == 60 * 104:
		game._open_settings()
	elif frames == 60 * 105:
		game._open_upgrades()
	elif frames == 60 * 106:
		game._open_leaderboard()
	elif frames == 60 * 107:
		print("SMOKE OK")
		get_tree().quit()
