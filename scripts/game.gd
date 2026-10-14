extends Node3D
## Gameplay: a 3x3x3 invisible grid, a neon cube player and incoming hazards.
##
## Controls: swipe left/right/up/down moves along X/Y, the two bottom buttons
## move in depth. On desktop: WASD / arrows + Q/E, Esc pauses.

enum State { COUNTDOWN, PLAYING, DEAD }

const CELL := 1.2
const HALF := 1.8
const PLAYER_R := 0.36
const MOVE_TIME := 0.085
const MAX_OBSTACLES := 6

var state := State.COUNTDOWN
var grid_pos := Vector3i(1, 1, 1)
var rng := RandomNumberGenerator.new()

var time_alive := 0.0
var score := 0.0
var countdown := 3.0
var spawn_timer := 1.0
var pickup_timer := 5.0
var freeze_time := 0.0
var mult_time := 0.0
var mult_factor := 1
var has_armor := false
var invuln_time := 0.0
var shake := 0.0

var obstacles: Array[Obstacle] = []
var pickups: Array[Pickup] = []

# Scene nodes
var env: Environment
var cam: Camera3D
var player: Node3D
var player_body: Node3D
var armor_shell: Node3D
var shadows: Array[MeshInstance3D] = []
var obstacles_root: Node3D
var fx_root: Node3D
var deco_ring: Node3D
var _move_tween: Tween

# HUD
var hud: CanvasLayer
var score_label: Label
var best_label: Label
var effects_box: HBoxContainer
var freeze_chip: Label
var armor_chip: Label
var mult_chip: Label
var countdown_label: Label
var hint_label: Label
var popup_anchor: Control
var frost: ColorRect
var flash: ColorRect
var fps_label: Label
var depth_pips: Array[Panel] = []
var pause_overlay: Control
var _last_count := 4

# Touch tracking: index -> start position
var _touches := {}


func _ready() -> void:
	rng.randomize()
	_build_world()
	_build_player()
	_build_hud()
	_place_player_instant()
	get_viewport().size_changed.connect(_fit_camera)
	_fit_camera()


# =========================================================================
# World
# =========================================================================

func _build_world() -> void:
	env = Neon.make_environment(bool(GameData.settings["glow"]))
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)

	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-50, 30, 0)
	sun.light_energy = 0.5
	sun.light_color = Color(0.7, 0.6, 1.0)
	add_child(sun)

	cam = Camera3D.new()
	cam.position = Vector3(2.0, 2.4, 5.7)
	add_child(cam)
	cam.look_at(Vector3(0, -0.2, 0))

	add_child(Neon.make_floor(-3.4, Neon.MAGENTA))

	# Decorative rings straight behind the arena from the camera's point of view.
	deco_ring = Node3D.new()
	add_child(deco_ring)
	var view_dir := -cam.global_transform.basis.z
	deco_ring.position = cam.position + view_dir * 34.0 + Vector3(0, 4.0, 0)
	deco_ring.look_at(cam.position)
	for i in 3:
		var ring := MeshInstance3D.new()
		var tm := TorusMesh.new()
		tm.inner_radius = 7.0 + i * 2.2
		tm.outer_radius = 7.15 + i * 2.2
		tm.rings = 64
		ring.mesh = tm
		ring.rotation = Vector3(PI / 2.0, 0, 0)
		ring.material_override = Neon.glow([Neon.MAGENTA, Neon.PURPLE, Neon.CYAN][i], 2.5 - i * 0.6)
		deco_ring.add_child(ring)

	# Arena frame and faint guides on the far faces.
	var frame := Neon.wire_box(Vector3.ONE * HALF, 0.04, Neon.glow(Neon.PURPLE, 3.0))
	add_child(frame)
	var guide_mat := Neon.ghost(Neon.PURPLE, 0.22, 1.2, true)
	for k in [-0.5, 0.5]:
		var o: float = k * CELL
		# bottom face (y = -HALF)
		add_child(Neon.bar(Vector3(o, -HALF, -HALF), Vector3(o, -HALF, HALF), 0.015, guide_mat))
		add_child(Neon.bar(Vector3(-HALF, -HALF, o), Vector3(HALF, -HALF, o), 0.015, guide_mat))
		# back face (z = -HALF)
		add_child(Neon.bar(Vector3(o, -HALF, -HALF), Vector3(o, HALF, -HALF), 0.015, guide_mat))
		add_child(Neon.bar(Vector3(-HALF, o, -HALF), Vector3(HALF, o, -HALF), 0.015, guide_mat))
		# left face (x = -HALF)
		add_child(Neon.bar(Vector3(-HALF, -HALF, o), Vector3(-HALF, HALF, o), 0.015, guide_mat))
		add_child(Neon.bar(Vector3(-HALF, o, -HALF), Vector3(-HALF, o, HALF), 0.015, guide_mat))

	# Projections of the player on the far faces help reading depth.
	var shadow_mat := Neon.ghost(Neon.CYAN, 0.35, 1.6, true)
	var rotations: Array[Vector3] = [Vector3(-PI / 2.0, 0, 0), Vector3.ZERO, Vector3(0, PI / 2.0, 0)]
	for r in rotations:
		var q := MeshInstance3D.new()
		var qm := QuadMesh.new()
		qm.size = Vector2(0.72, 0.72)
		q.mesh = qm
		q.rotation = r
		q.material_override = shadow_mat
		add_child(q)
		shadows.append(q)

	obstacles_root = Node3D.new()
	add_child(obstacles_root)
	fx_root = Node3D.new()
	add_child(fx_root)


func _fit_camera() -> void:
	var s := get_viewport().get_visible_rect().size
	if s.y > s.x:
		cam.keep_aspect = Camera3D.KEEP_WIDTH
		cam.fov = 66.0
	else:
		cam.keep_aspect = Camera3D.KEEP_HEIGHT
		cam.fov = 60.0


func _build_player() -> void:
	player = Node3D.new()
	add_child(player)
	player_body = Node3D.new()
	player.add_child(player_body)
	var core := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3.ONE * 0.6
	core.mesh = bm
	core.material_override = Neon.glow(Neon.CYAN, 1.6)
	player_body.add_child(core)
	player_body.add_child(Neon.wire_box(Vector3.ONE * 0.33, 0.05, Neon.glow(Color(0.7, 1.0, 1.0), 6.0)))
	var light := OmniLight3D.new()
	light.light_color = Neon.CYAN
	light.light_energy = 1.5
	light.omni_range = 2.6
	player.add_child(light)

	armor_shell = Node3D.new()
	armor_shell.add_child(Neon.wire_box(Vector3.ONE * 0.5, 0.035, Neon.glow(Neon.LIME, 4.0)))
	var shell := MeshInstance3D.new()
	var sm := BoxMesh.new()
	sm.size = Vector3.ONE * 1.0
	shell.mesh = sm
	shell.material_override = Neon.ghost(Neon.LIME, 0.12, 1.2, true)
	armor_shell.add_child(shell)
	armor_shell.visible = false
	player.add_child(armor_shell)


func cell_to_world(c: Vector3i) -> Vector3:
	return Vector3(c.x - 1, c.y - 1, c.z - 1) * CELL


func _place_player_instant() -> void:
	player.position = cell_to_world(grid_pos)


# =========================================================================
# Input
# =========================================================================

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_ESCAPE, KEY_P:
				if state == State.PLAYING:
					_set_paused(true)
				return
			KEY_A, KEY_LEFT:
				try_move(Vector3i(-1, 0, 0))
			KEY_D, KEY_RIGHT:
				try_move(Vector3i(1, 0, 0))
			KEY_W, KEY_UP:
				try_move(Vector3i(0, 1, 0))
			KEY_S, KEY_DOWN:
				try_move(Vector3i(0, -1, 0))
			KEY_Q:
				try_move(Vector3i(0, 0, -1))
			KEY_E:
				try_move(Vector3i(0, 0, 1))
		return

	if event is InputEventScreenTouch:
		if event.pressed:
			_touches[event.index] = event.position
		else:
			_touches.erase(event.index)
	elif event is InputEventScreenDrag:
		if not _touches.has(event.index):
			return
		var start: Vector2 = _touches[event.index]
		var d: Vector2 = event.position - start
		var threshold := lerpf(110.0, 28.0, float(GameData.settings["swipe_sensitivity"]))
		if d.length() >= threshold:
			if absf(d.x) > absf(d.y):
				try_move(Vector3i(1 if d.x > 0 else -1, 0, 0))
			else:
				try_move(Vector3i(0, -1 if d.y > 0 else 1, 0))
			# Restart from here so one long drag can chain several moves.
			_touches[event.index] = event.position


func try_move(dir: Vector3i) -> void:
	if state != State.PLAYING:
		return
	var target := grid_pos + dir
	if target.x < 0 or target.x > 2 or target.y < 0 or target.y > 2 or target.z < 0 or target.z > 2:
		# Bump against the arena edge.
		var bump := player_body.create_tween()
		bump.tween_property(player_body, "position", Vector3(dir) * 0.12, 0.05)
		bump.tween_property(player_body, "position", Vector3.ZERO, 0.08)
		return
	grid_pos = target
	if _move_tween and _move_tween.is_valid():
		_move_tween.kill()
	_move_tween = create_tween()
	_move_tween.tween_property(player, "position", cell_to_world(grid_pos), MOVE_TIME) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	# Little squash in the direction of travel.
	var squash := Vector3.ONE - Vector3(absi(dir.x), absi(dir.y), absi(dir.z)) * 0.25
	player_body.scale = squash
	var st := player_body.create_tween()
	st.tween_property(player_body, "scale", Vector3.ONE, 0.14).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	Sfx.play("depth" if dir.z != 0 else "move", rng.randf_range(0.95, 1.05))
	GameData.vibrate(12)
	_update_depth_pips()
	_check_pickups()


# =========================================================================
# Main loop
# =========================================================================

func _process(delta: float) -> void:
	deco_ring.rotation.z += delta * 0.05
	_update_shadows()
	_update_camera(delta)
	if fps_label.visible:
		fps_label.text = "FPS %d" % Engine.get_frames_per_second()

	match state:
		State.COUNTDOWN:
			_process_countdown(delta)
		State.PLAYING:
			_process_playing(delta)
		State.DEAD:
			for o in obstacles:
				o.step(delta * 0.25)


func _process_countdown(delta: float) -> void:
	countdown -= delta
	var n := ceili(countdown)
	if n != _last_count:
		_last_count = n
		if n > 0:
			countdown_label.text = str(n)
			Sfx.play("count")
		else:
			countdown_label.text = "СТАРТ!"
			Sfx.play("go")
		countdown_label.scale = Vector2.ONE * 1.6
		countdown_label.pivot_offset = countdown_label.size / 2.0
		create_tween().tween_property(countdown_label, "scale", Vector2.ONE, 0.25)
	if countdown <= 0.0:
		state = State.PLAYING
		var t := create_tween()
		t.tween_interval(0.4)
		t.tween_property(countdown_label, "modulate:a", 0.0, 0.3)


func difficulty() -> float:
	return minf(time_alive / 22.0, 9.0)


func _process_playing(delta: float) -> void:
	time_alive += delta
	score += delta * 10.0 * mult_factor

	# Effects
	var frozen := freeze_time > 0.0
	if frozen:
		freeze_time -= delta
	if mult_time > 0.0:
		mult_time -= delta
		if mult_time <= 0.0:
			mult_factor = 1
	if invuln_time > 0.0:
		invuln_time -= delta
		player_body.visible = fmod(invuln_time * 12.0, 1.0) < 0.6 or invuln_time <= 0.0

	# Spawning
	spawn_timer -= delta
	if spawn_timer <= 0.0:
		_spawn_obstacle()
		spawn_timer = maxf(1.25, 3.3 - difficulty() * 0.3) * rng.randf_range(0.85, 1.15)
	pickup_timer -= delta
	if pickup_timer <= 0.0:
		_spawn_pickup()
		pickup_timer = GameData.pickup_interval() * rng.randf_range(0.8, 1.2)

	# Hazards
	for o in obstacles:
		o.set_frozen(freeze_time > 0.0)
		o.step(delta)
		if o.survived and not o.has_meta("counted"):
			o.set_meta("counted", true)
			var bonus := 20 * mult_factor
			score += bonus
			_popup("+%d" % bonus, Neon.CYAN)
	for o in obstacles.duplicate():
		if o.finished:
			obstacles.erase(o)
			o.queue_free()
	if invuln_time <= 0.0:
		for o in obstacles:
			if o.hits(player.position, PLAYER_R):
				_on_hit()
				break

	# Pickups
	for p in pickups.duplicate():
		if p.finished:
			pickups.erase(p)
			p.queue_free()

	# Visuals
	player_body.rotation.y = sin(time_alive * 1.7) * 0.12
	player_body.rotation.x = sin(time_alive * 1.3) * 0.08
	armor_shell.visible = has_armor
	if has_armor:
		armor_shell.rotation.y += delta * 1.2
		armor_shell.rotation.x += delta * 0.7
	_update_hud()


func _update_shadows() -> void:
	var p := player.position
	shadows[0].position = Vector3(p.x, -HALF + 0.01, p.z)
	shadows[1].position = Vector3(p.x, p.y, -HALF + 0.01)
	shadows[2].position = Vector3(-HALF + 0.01, p.y, p.z)
	for s in shadows:
		s.visible = player.visible


func _update_camera(delta: float) -> void:
	shake = maxf(0.0, shake - delta * 2.5)
	cam.h_offset = rng.randf_range(-1.0, 1.0) * shake * 0.25
	cam.v_offset = rng.randf_range(-1.0, 1.0) * shake * 0.25


# =========================================================================
# Spawning
# =========================================================================

func _spawn_obstacle() -> void:
	if obstacles.size() >= MAX_OBSTACLES:
		return
	var diff := difficulty()
	var has_laser := false
	var has_wall := false
	for o in obstacles:
		if o is LaserRig:
			has_laser = true
		elif o is WallObstacle:
			has_wall = true
	var kinds: Array[String] = []
	var weights: Array[float] = []
	if not has_laser:
		kinds.append("laser")
		weights.append(5.0)
	if not has_wall and time_alive > 4.0:
		kinds.append("wall")
		weights.append(3.0)
	if time_alive > 6.0:
		kinds.append("orb")
		weights.append(2.0 + diff * 0.3)
	if kinds.is_empty():
		return
	match kinds[rng.rand_weighted(PackedFloat32Array(weights))]:
		"laser":
			var rig := LaserRig.new()
			obstacles_root.add_child(rig)
			rig.build(rng, diff)
			obstacles.append(rig)
			Sfx.play("warn")
		"wall":
			var wall := WallObstacle.new()
			obstacles_root.add_child(wall)
			wall.build(rng, diff)
			obstacles.append(wall)
		"orb":
			var count := mini(1 + rng.randi_range(0, int(diff / 2.0)), 4)
			for i in count:
				var orb := OrbShot.new()
				obstacles_root.add_child(orb)
				orb.build(rng, diff)
				orb.warn_time += i * 0.35
				obstacles.append(orb)
			Sfx.play("warn", 1.4)


func _spawn_pickup() -> void:
	if pickups.size() >= 2:
		return
	var free_cells: Array[Vector3i] = []
	for x in 3:
		for y in 3:
			for z in 3:
				var c := Vector3i(x, y, z)
				if c == grid_pos:
					continue
				var taken := false
				for p in pickups:
					if p.cell == c:
						taken = true
				if not taken:
					free_cells.append(c)
	var cell := free_cells[rng.randi_range(0, free_cells.size() - 1)]
	var weights := PackedFloat32Array([
		1.0,
		0.15 if has_armor else GameData.armor_weight(),
		1.1,
	])
	var kind: Pickup.Kind = rng.rand_weighted(weights) as Pickup.Kind
	var p := Pickup.new()
	add_child(p)
	p.build(kind, cell, cell_to_world(cell))
	pickups.append(p)


func _check_pickups() -> void:
	for p in pickups.duplicate():
		if p.cell == grid_pos and not p.finished:
			_collect(p)
			pickups.erase(p)
			p.queue_free()


func _collect(p: Pickup) -> void:
	var col := Pickup.color_of(p.kind)
	_burst(p.global_position, col, 24, 0.08)
	GameData.vibrate(25)
	match p.kind:
		Pickup.Kind.FREEZE:
			freeze_time = maxf(freeze_time, 0.0) + GameData.freeze_duration()
			Sfx.play("freeze")
			_popup("ЗАМОРОЗКА!", Neon.ICE)
		Pickup.Kind.ARMOR:
			Sfx.play("pickup", 0.8)
			if has_armor:
				# Armor does not stack: convert into points instead.
				var bonus := 50 * mult_factor
				score += bonus
				_popup("БРОНЯ УЖЕ ЕСТЬ  +%d" % bonus, Neon.LIME)
			else:
				has_armor = true
				_popup("БРОНЯ!", Neon.LIME)
		Pickup.Kind.MULTIPLIER:
			Sfx.play("pickup", 1.2)
			mult_factor = mini(mult_factor + 1, 5) if mult_time > 0.0 else 2
			mult_time = GameData.multiplier_duration()
			_popup("ОЧКИ x%d!" % mult_factor, Neon.GOLD)


# =========================================================================
# Damage
# =========================================================================

func _on_hit() -> void:
	if has_armor:
		has_armor = false
		invuln_time = GameData.armor_invulnerability()
		shake = 0.6
		Sfx.play("armor_break")
		GameData.vibrate(90)
		_burst(player.position, Neon.LIME, 40, 0.1)
		_flash(Neon.LIME)
		_popup("БРОНЯ СПАСЛА!", Neon.LIME)
		return
	_die()


func _die() -> void:
	state = State.DEAD
	player.visible = false
	shake = 1.0
	Sfx.play("death")
	GameData.vibrate(350)
	_burst(player.position, Neon.CYAN, 70, 0.14)
	_burst(player.position, Color.WHITE, 20, 0.06)
	_flash(Neon.RED)
	var final_score := int(score)
	var old_best := GameData.best_score
	var earned := GameData.submit_score(final_score)
	get_tree().create_timer(1.1).timeout.connect(
		func(): _show_game_over(final_score, final_score > old_best and final_score > 0, earned))


func _burst(pos: Vector3, color: Color, amount: int, size: float) -> void:
	var p := CPUParticles3D.new()
	var mesh := BoxMesh.new()
	mesh.size = Vector3.ONE * size
	p.mesh = mesh
	p.material_override = Neon.glow(color, 5.0)
	p.amount = amount
	p.one_shot = true
	p.explosiveness = 1.0
	p.lifetime = 1.1
	p.direction = Vector3.UP
	p.spread = 180.0
	p.initial_velocity_min = 2.5
	p.initial_velocity_max = 6.5
	p.gravity = Vector3(0, -5.0, 0)
	p.angular_velocity_min = -360.0
	p.angular_velocity_max = 360.0
	p.damping_min = 1.0
	p.damping_max = 2.5
	var curve := Curve.new()
	curve.add_point(Vector2(0, 1))
	curve.add_point(Vector2(1, 0))
	p.scale_amount_curve = curve
	p.position = pos
	fx_root.add_child(p)
	p.emitting = true
	p.finished.connect(p.queue_free)


# =========================================================================
# HUD
# =========================================================================

func _build_hud() -> void:
	hud = CanvasLayer.new()
	hud.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(hud)

	frost = ColorRect.new()
	frost.set_anchors_preset(Control.PRESET_FULL_RECT)
	frost.color = Color(0.4, 0.75, 1.0, 0.0)
	frost.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud.add_child(frost)

	flash = ColorRect.new()
	flash.set_anchors_preset(Control.PRESET_FULL_RECT)
	flash.color = Color(1, 1, 1, 0)
	flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud.add_child(flash)

	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_theme_constant_override("margin_left", 28)
	margin.add_theme_constant_override("margin_right", 28)
	margin.add_theme_constant_override("margin_top", 56)
	margin.add_theme_constant_override("margin_bottom", 44)
	hud.add_child(margin)

	var col := VBoxContainer.new()
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_theme_constant_override("separation", 12)
	margin.add_child(col)

	# Top bar
	var top := HBoxContainer.new()
	top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(top)
	var score_box := VBoxContainer.new()
	score_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	score_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	score_box.add_theme_constant_override("separation", 0)
	top.add_child(score_box)
	score_label = UI.label("0", 72, Neon.CYAN, HORIZONTAL_ALIGNMENT_LEFT)
	score_box.add_child(score_label)
	best_label = UI.label("РЕКОРД %d" % GameData.best_score, 26, Neon.PURPLE, HORIZONTAL_ALIGNMENT_LEFT)
	score_box.add_child(best_label)
	var pause_btn := UI.button("II", Neon.MAGENTA, 40, 96)
	pause_btn.custom_minimum_size = Vector2(96, 96)
	pause_btn.pressed.connect(func(): if state == State.PLAYING: _set_paused(true))
	top.add_child(pause_btn)

	effects_box = HBoxContainer.new()
	effects_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	effects_box.add_theme_constant_override("separation", 12)
	col.add_child(effects_box)
	freeze_chip = _chip(Neon.ICE)
	armor_chip = _chip(Neon.LIME)
	mult_chip = _chip(Neon.GOLD)
	armor_chip.text = "БРОНЯ"

	fps_label = UI.label("", 22, Neon.LIME, HORIZONTAL_ALIGNMENT_LEFT)
	fps_label.visible = bool(GameData.settings["show_fps"])
	col.add_child(fps_label)

	popup_anchor = Control.new()
	popup_anchor.mouse_filter = Control.MOUSE_FILTER_IGNORE
	popup_anchor.custom_minimum_size = Vector2(0, 60)
	col.add_child(popup_anchor)

	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(spacer)

	hint_label = UI.label("Свайп — двигаться\nКнопки — вглубь / ближе", 28, Neon.CYAN)
	col.add_child(hint_label)
	if GameData.games_played > 2:
		hint_label.visible = false

	# Bottom controls: depth buttons and a depth indicator between them.
	var bottom := HBoxContainer.new()
	bottom.add_theme_constant_override("separation", 18)
	bottom.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(bottom)
	var far_btn := UI.button("ВГЛУБЬ", Neon.MAGENTA, 30, 120, false)
	far_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	far_btn.button_down.connect(func(): try_move(Vector3i(0, 0, -1)))
	bottom.add_child(far_btn)
	var pips := VBoxContainer.new()
	pips.alignment = BoxContainer.ALIGNMENT_CENTER
	pips.add_theme_constant_override("separation", 8)
	pips.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bottom.add_child(pips)
	for i in 3:
		var pip := Panel.new()
		pip.custom_minimum_size = Vector2(70 - (2 - i) * 12, 22)
		pip.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		pip.mouse_filter = Control.MOUSE_FILTER_IGNORE
		pips.add_child(pip)
		depth_pips.append(pip)
	var near_btn := UI.button("БЛИЖЕ", Neon.CYAN, 30, 120, false)
	near_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	near_btn.button_down.connect(func(): try_move(Vector3i(0, 0, 1)))
	bottom.add_child(near_btn)

	countdown_label = UI.label("", 160, Neon.MAGENTA)
	countdown_label.set_anchors_preset(Control.PRESET_CENTER)
	countdown_label.custom_minimum_size = Vector2(600, 220)
	countdown_label.position = Vector2(-300, -110)
	countdown_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud.add_child(countdown_label)

	_update_depth_pips()


func _chip(color: Color) -> Label:
	var l := UI.label("", 26, color)
	var s := UI.box(color, 0.1, 16, 2, 8)
	s.content_margin_left = 16
	s.content_margin_right = 16
	s.content_margin_top = 6
	s.content_margin_bottom = 6
	l.add_theme_stylebox_override("normal", s)
	l.visible = false
	effects_box.add_child(l)
	return l


func _update_depth_pips() -> void:
	# Top pip = far layer (z = 0), bottom pip = near layer (z = 2).
	for i in depth_pips.size():
		var on := i == grid_pos.z
		var color := Neon.CYAN if on else Neon.PURPLE
		var s := UI.box(color, 0.0, 6, 2, 10 if on else 0)
		s.bg_color = Color(color, 0.9 if on else 0.1)
		depth_pips[i].add_theme_stylebox_override("panel", s)


func _update_hud() -> void:
	score_label.text = str(int(score))
	freeze_chip.visible = freeze_time > 0.0
	if freeze_chip.visible:
		freeze_chip.text = "ЗАМОРОЗКА %.1f" % freeze_time
	armor_chip.visible = has_armor
	mult_chip.visible = mult_time > 0.0
	if mult_chip.visible:
		mult_chip.text = "x%d  %.1f" % [mult_factor, mult_time]
	frost.color.a = lerpf(frost.color.a, 0.09 if freeze_time > 0.0 else 0.0, 0.15)
	if hint_label.visible and time_alive > 6.0:
		hint_label.modulate.a = maxf(0.0, hint_label.modulate.a - 0.02)


func _popup(text: String, color: Color) -> void:
	var l := UI.label(text, 40, color)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.size = Vector2(popup_anchor.size.x, 60)
	popup_anchor.add_child(l)
	var t := l.create_tween().set_parallel(true)
	t.tween_property(l, "position:y", -50.0, 0.9).set_ease(Tween.EASE_OUT)
	t.tween_property(l, "modulate:a", 0.0, 0.9).set_delay(0.3)
	t.chain().tween_callback(l.queue_free)


func _flash(color: Color) -> void:
	flash.color = Color(color, 0.45)
	create_tween().tween_property(flash, "color:a", 0.0, 0.4)


# =========================================================================
# Pause / game over
# =========================================================================

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT or what == NOTIFICATION_APPLICATION_PAUSED:
		if state == State.PLAYING and not get_tree().paused:
			_set_paused(true)


func _set_paused(p: bool) -> void:
	get_tree().paused = p
	if p:
		var parts := UI.overlay(hud, Neon.MAGENTA)
		pause_overlay = parts[0]
		var vb: VBoxContainer = parts[1]
		vb.add_child(UI.label("ПАУЗА", 64, Neon.MAGENTA))
		var resume := UI.button("ПРОДОЛЖИТЬ", Neon.CYAN, 36, 110)
		resume.pressed.connect(func(): _set_paused(false))
		vb.add_child(resume)
		var restart := UI.button("ЗАНОВО", Neon.MAGENTA)
		restart.pressed.connect(_restart)
		vb.add_child(restart)
		var menu := UI.button("В МЕНЮ", Neon.PURPLE)
		menu.pressed.connect(_to_menu)
		vb.add_child(menu)
	elif pause_overlay:
		pause_overlay.queue_free()
		pause_overlay = null


func _show_game_over(final_score: int, new_record: bool, earned: int) -> void:
	var parts := UI.overlay(hud, Neon.RED)
	var vb: VBoxContainer = parts[1]
	vb.add_child(UI.label("ИГРА ОКОНЧЕНА", 52, Neon.RED))
	vb.add_child(UI.label(str(final_score), 110, Neon.CYAN))
	if new_record:
		var rec := UI.label("НОВЫЙ РЕКОРД!", 40, Neon.GOLD)
		vb.add_child(rec)
		var t := rec.create_tween().set_loops()
		t.tween_property(rec, "modulate:a", 0.4, 0.4)
		t.tween_property(rec, "modulate:a", 1.0, 0.4)
	else:
		vb.add_child(UI.label("Рекорд: %d" % GameData.best_score, 30, Neon.PURPLE))
	vb.add_child(UI.label("Время: %.1f с" % time_alive, 30, Neon.CYAN))
	vb.add_child(UI.label("+%d монет" % earned, 34, Neon.GOLD))
	var again := UI.button("ЕЩЁ РАЗ", Neon.CYAN, 38, 116)
	again.pressed.connect(_restart)
	vb.add_child(again)
	var menu := UI.button("В МЕНЮ", Neon.MAGENTA)
	menu.pressed.connect(_to_menu)
	vb.add_child(menu)


func _restart() -> void:
	get_tree().paused = false
	get_tree().reload_current_scene()


func _to_menu() -> void:
	get_tree().paused = false
	get_tree().change_scene_to_file("res://scenes/main_menu.tscn")
