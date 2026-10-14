extends Node
## Headless smoke test.
## 1. Generates thousands of gates and checks each one is passable
##    (at least one safe cell at every moment of its rotation).
## 2. Plays the runner with a random bot (permanent armor), then dies.
## 3. Opens every menu panel.
## Run: godot --headless --fixed-fps 60 --path . res://tests/smoke_test.tscn

var game: Node
var frames := 0
var hits := 0
var stats := {}


func _ready() -> void:
	GameData.persist = false
	_check_gates()
	game = load("res://scenes/game.tscn").instantiate()
	add_child(game)


func _check_gates() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 1234
	var bad := 0
	var total := 0
	for i in 3000:
		var gate: Obstacle = [LaserGate, WallObstacle, BlockGate][i % 3].new()
		add_child(gate)
		gate.call("build", rng, rng.randf_range(0.0, 10.0))
		for t in 40:
			var any_safe := false
			for c in Obstacle.all_cells():
				if not gate.hits(Vector3(c.x * 1.2, c.y * 1.2, 0), 0.34):
					any_safe = true
					break
			if not any_safe:
				bad += 1
				break
			gate.step(0.1)
		total += 1
		gate.free()
	print("gates checked=", total, " impassable=", bad)
	if bad > 0:
		push_error("Found impassable gates")


func _process(_delta: float) -> void:
	frames += 1
	if frames < 60 * 100:
		if game.state == game.State.PLAYING:
			if not game.has_armor:
				hits += 1
				game.has_armor = true
			if frames % 20 == 0:
				var dirs := [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]
				game.try_move(dirs[randi() % dirs.size()])
			for o in game.obstacles:
				stats[o.get_script().get_global_name()] = true
	elif frames == 60 * 100:
		print("score=", int(game.score), " dist=", int(game.distance), " speed=", snapped(game.speed, 0.1),
			" gates=", game.gates_passed, " armor_saves=", hits, " kinds=", stats.keys())
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
