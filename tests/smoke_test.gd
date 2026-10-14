extends Node
## Headless smoke test.
## 1. Generates thousands of gates from LevelGen (all zones) and checks each is
##    passable: at every moment at least one cell is safe.
## 2. "Camper" bot that never leaves the centre: should get hit often.
## 3. "Dodger" bot that moves to a safe cell of the nearest gate.
## 4. Death, game over and every menu panel.
## Run: godot --headless --fixed-fps 60 --path . res://tests/smoke_test.tscn

const CAMP_FRAMES := 60 * 60
const DODGE_FRAMES := 60 * 120

var game: Node
var frames := 0
var phase := "camp"
var hits := 0
var kinds := {}
var move_cooldown := 0
var hit_by := {}


func _ready() -> void:
	GameData.persist = false
	_check_generator()
	_start_game()


func _start_game() -> void:
	if game:
		game.queue_free()
	game = load("res://scenes/game.tscn").instantiate()
	add_child(game)
	frames = 0
	hits = 0


func _check_generator() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 99
	var gen := LevelGen.new(rng)
	var bad := 0
	var total := 0
	var center_safe := 0
	var types := {}
	for i in 4000:
		var cfg := gen.next(rng.randf_range(0.0, 10.0), i % 3)
		types[cfg["type"]] = int(types.get(cfg["type"], 0)) + 1
		var gate: Obstacle = {
			"laser": LaserGate, "wall": WallObstacle, "blocks": BlockGate,
			"tunnel": TrapTunnel, "invert": InvertGate,
		}[cfg["type"]].new()
		add_child(gate)
		gate.always_lit = true
		gate.configure(cfg)
		gate.position = Vector3.ZERO
		gate.step(0.0)
		if not gate.hits(Vector3.ZERO, 0.34):
			center_safe += 1
		for t in 40:
			gate.step(0.1)
			# In game a STEP never runs while the gate reaches the player.
			var stepping: bool = gate.motion == Obstacle.Motion.STEP or gate.motion == Obstacle.Motion.STEP_SLIDE
			if stepping and gate._turn_frac(gate._t) > 0.0:
				continue
			var any_safe := false
			for c in Obstacle.all_cells():
				if not gate.hits(Vector3(c.x * 1.2, c.y * 1.2, 0), 0.34):
					any_safe = true
					break
			if not any_safe:
				bad += 1
				print("IMPASSABLE: ", cfg)
				break
		total += 1
		gate.free()
	print("gates=", total, " impassable=", bad, " centre safe=", snapped(100.0 * center_safe / total, 0.1), "% types=", types)
	if bad > 0:
		push_error("Found impassable gates")


func _dodge() -> void:
	if move_cooldown > 0:
		move_cooldown -= 1
		return
	# Nearest gate in front of the player.
	var target_gate: Obstacle = null
	for o in game.obstacles:
		# Skip gates already behind the player and harmless portals.
		if o.position.z - o.depth * 0.5 > -0.1 or o.effect != "":
			continue
		if target_gate == null or o.position.z > target_gate.position.z:
			target_gate = o
	if target_gate == null:
		return
	var z: float = target_gate.position.z
	var safe: Array[Vector2i] = []
	for c in Obstacle.all_cells():
		if not target_gate.hits(Vector3(c.x * 1.2, c.y * 1.2, z), 0.34):
			safe.append(c)
	if safe.is_empty() or game.grid_pos in safe:
		return
	var best: Vector2i = safe[0]
	for c in safe:
		if (c - game.grid_pos).length_squared() < (best - game.grid_pos).length_squared():
			best = c
	var d: Vector2i = best - game.grid_pos
	var step := Vector2i(signi(d.x), 0) if d.x != 0 else Vector2i(0, signi(d.y))
	if game.invert_time > 0.0:
		step = -step
	game.try_move(step)
	move_cooldown = 6


func _process(_delta: float) -> void:
	frames += 1
	if phase == "camp" or phase == "dodge":
		if game.state == game.State.PLAYING:
			if not game.has_armor:
				hits += 1
				game.has_armor = true
				if phase == "dodge":
					for o in game.obstacles:
						if absf(o.position.z) < o.depth * 0.5 + 1.5:
							var key := "%s/%s%s" % [o.get_script().get_global_name(), Obstacle.Motion.keys()[o.motion], "/blink" if o.blink else ""]
							hit_by[key] = int(hit_by.get(key, 0)) + 1
			for o in game.obstacles:
				kinds[o.get_script().get_global_name()] = true
			if phase == "dodge":
				_dodge()
		var limit := CAMP_FRAMES if phase == "camp" else DODGE_FRAMES
		if frames >= limit:
			print(phase, ": hits=", hits, " in ", snapped(game.time_alive, 0.1), "s dist=", int(game.distance),
				" zone=", game.zone_index + 1, " coins=", game.run_coins, " gates=", game.gates_passed)
			if phase == "camp":
				phase = "dodge"
				_start_game()
			else:
				print("kinds seen=", kinds.keys())
				print("dodger hit by: ", hit_by)
				phase = "die"
				game.has_armor = false
				game.invuln_time = 0.0
				game._on_hit()
				frames = 0
	elif phase == "die":
		if frames == 180:
			print("state=", game.state, " leaderboard=", GameData.leaderboard.size())
			game.queue_free()
			game = load("res://scenes/main_menu.tscn").instantiate()
			add_child(game)
		elif frames == 240:
			game._open_settings()
		elif frames == 300:
			game._open_upgrades()
		elif frames == 360:
			game._open_leaderboard()
		elif frames == 420:
			print("SMOKE OK")
			get_tree().quit()
