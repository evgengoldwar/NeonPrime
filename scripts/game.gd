extends Node3D
## Endless neon runner.
##
## The player cube lives in a 3x3 field (one plane: left/right, up/down) and
## rushes forward down an endless track. Gates (lasers, walls with holes, blocks)
## are generated randomly ahead and come towards the player; they can stand
## still, spin or swing. Swipes move the cube one cell. Desktop: WASD / arrows,
## Esc pauses.

enum State { COUNTDOWN, PLAYING, DEAD }

const CELL := 1.2
const HALF := 1.8
const PLAYER_R := 0.34
const MOVE_TIME := 0.08
const SPAWN_Z := -80.0
const DESPAWN_Z := 6.0
## Gates disappear right behind the player so they never block the view.
const GATE_DESPAWN_Z := 1.5
const FRAME_SPACING := 6.0
const FRAME_COUNT := 15

var state := State.COUNTDOWN
var grid_pos := Vector2i.ZERO  ## -1..1 on each axis
var rng := RandomNumberGenerator.new()

var time_alive := 0.0
var distance := 0.0
var speed := 9.0
var score := 0.0
var countdown := 3.0
var gap_left := 30.0  ## distance until the next gate is generated
var pickup_timer := 4.0
var freeze_time := 0.0
var mult_time := 0.0
var mult_factor := 1
var has_armor := false
var invuln_time := 0.0
var shake := 0.0
var gates_passed := 0

var obstacles: Array[Obstacle] = []
var pickups: Array[Pickup] = []

# Scene nodes
var env: Environment
var cam: Camera3D
var player: Node3D
var player_body: Node3D
var armor_shell: Node3D
var shadow: MeshInstance3D
var track_root: Node3D
var frames: Array[Node3D] = []
var streaks: Array[MeshInstance3D] = []
var floor_mat: ShaderMaterial
var fx_root: Node3D
var deco_ring: Node3D
var _move_tween: Tween

# HUD
var hud: CanvasLayer
var score_label: Label
var best_label: Label
var distance_label: Label
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
var pause_overlay: Control
var _last_count := 4

var _touches := {}


func _ready() -> void:
	rng.randomize()
	_build_world()
	_build_player()
	_build_hud()
	get_viewport().size_changed.connect(_fit_camera)
	_fit_camera()


# =========================================================================
# World
# =========================================================================

func _build_world() -> void:
	env = Neon.make_environment(bool(GameData.settings["glow"]))
	env.fog_density = 0.022
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)

	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-40, 20, 0)
	sun.light_energy = 0.5
	sun.light_color = Color(0.7, 0.6, 1.0)
	add_child(sun)

	cam = Camera3D.new()
	cam.position = Vector3(0, 1.1, 6.2)
	add_child(cam)
	cam.look_at(Vector3(0, 0.55, -6.0))

	var floor_mesh := Neon.make_floor(-3.4, Neon.MAGENTA)
	floor_mat = floor_mesh.material_override
	floor_mat.set_shader_parameter("scroll_speed", 0.0)
	floor_mat.set_shader_parameter("fade_distance", 70.0)
	add_child(floor_mesh)

	# Decorative rings at the end of the track.
	deco_ring = Node3D.new()
	deco_ring.position = Vector3(0, 3.0, -95)
	add_child(deco_ring)
	for i in 3:
		var ring := MeshInstance3D.new()
		var tm := TorusMesh.new()
		tm.inner_radius = 14.0 + i * 4.0
		tm.outer_radius = 14.4 + i * 4.0
		tm.rings = 64
		ring.mesh = tm
		ring.rotation = Vector3(PI / 2.0, 0, 0)
		ring.material_override = Neon.glow([Neon.MAGENTA, Neon.PURPLE, Neon.CYAN][i], 3.0 - i * 0.7)
		deco_ring.add_child(ring)

	# Track: four rails along the corners of the 3x3 field and scrolling frames.
	var rail_mat := Neon.glow(Neon.PURPLE, 3.0)
	for sx in [-1.0, 1.0]:
		for sy in [-1.0, 1.0]:
			add_child(Neon.bar(Vector3(sx * HALF, sy * HALF, SPAWN_Z - 10.0),
					Vector3(sx * HALF, sy * HALF, 12.0), 0.04, rail_mat))
	var floor_guides := Neon.ghost(Neon.PURPLE, 0.25, 1.2, true)
	for k in [-0.5, 0.5]:
		var o: float = k * CELL
		add_child(Neon.bar(Vector3(o, -HALF, SPAWN_Z - 10.0), Vector3(o, -HALF, 12.0), 0.02, floor_guides))

	track_root = Node3D.new()
	add_child(track_root)
	var frame_mats := [Neon.ghost(Neon.PURPLE, 0.55, 2.0, true), Neon.ghost(Neon.MAGENTA, 0.45, 2.0, true)]
	for i in FRAME_COUNT:
		var f := Neon.wire_box(Vector3(HALF, HALF, 0.0), 0.03, frame_mats[i % 2])
		f.position.z = -i * FRAME_SPACING
		track_root.add_child(f)
		frames.append(f)

	# Speed streaks around the track.
	var streak_mat := Neon.ghost(Neon.CYAN, 0.5, 2.5, true)
	for i in 22:
		var s := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = Vector3(0.03, 0.03, 4.0)
		s.mesh = bm
		s.material_override = streak_mat
		_reset_streak(s, rng.randf_range(SPAWN_Z, DESPAWN_Z))
		track_root.add_child(s)
		streaks.append(s)

	# Projection of the player on the track floor helps reading position.
	shadow = MeshInstance3D.new()
	var qm := QuadMesh.new()
	qm.size = Vector2(0.72, 0.72)
	shadow.mesh = qm
	shadow.rotation = Vector3(-PI / 2.0, 0, 0)
	shadow.material_override = Neon.ghost(Neon.CYAN, 0.35, 1.6, true)
	add_child(shadow)

	fx_root = Node3D.new()
	add_child(fx_root)


func _reset_streak(s: MeshInstance3D, z: float) -> void:
	var ang := rng.randf() * TAU
	var r := rng.randf_range(3.2, 7.0)
	s.position = Vector3(cos(ang) * r, sin(ang) * r * 0.8 + 0.5, z)


func _fit_camera() -> void:
	var s := get_viewport().get_visible_rect().size
	if s.y > s.x:
		cam.keep_aspect = Camera3D.KEEP_WIDTH
		cam.fov = 62.0
	else:
		cam.keep_aspect = Camera3D.KEEP_HEIGHT
		cam.fov = 62.0


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

	# Engine trail behind the cube.
	var trail := CPUParticles3D.new()
	var tm := BoxMesh.new()
	tm.size = Vector3.ONE * 0.08
	trail.mesh = tm
	trail.material_override = Neon.glow(Neon.CYAN, 4.0)
	trail.amount = 30
	trail.lifetime = 0.5
	trail.direction = Vector3(0, 0, 1)
	trail.spread = 12.0
	trail.initial_velocity_min = 5.0
	trail.initial_velocity_max = 8.0
	trail.gravity = Vector3.ZERO
	var curve := Curve.new()
	curve.add_point(Vector2(0, 1))
	curve.add_point(Vector2(1, 0))
	trail.scale_amount_curve = curve
	trail.position = Vector3(0, 0, 0.3)
	player.add_child(trail)

	armor_shell = Node3D.new()
	armor_shell.add_child(Neon.wire_box(Vector3.ONE * 0.5, 0.035, Neon.glow(Neon.LIME, 4.0)))
	var shell := MeshInstance3D.new()
	var sm := BoxMesh.new()
	sm.size = Vector3.ONE
	shell.mesh = sm
	shell.material_override = Neon.ghost(Neon.LIME, 0.12, 1.2, true)
	armor_shell.add_child(shell)
	armor_shell.visible = false
	player.add_child(armor_shell)
	player.position = cell_to_world(grid_pos)


func cell_to_world(c: Vector2i) -> Vector3:
	return Vector3(c.x * CELL, c.y * CELL, 0.0)


# =========================================================================
# Input
# =========================================================================

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_ESCAPE, KEY_P:
				if state == State.PLAYING:
					_set_paused(true)
			KEY_A, KEY_LEFT:
				try_move(Vector2i(-1, 0))
			KEY_D, KEY_RIGHT:
				try_move(Vector2i(1, 0))
			KEY_W, KEY_UP:
				try_move(Vector2i(0, 1))
			KEY_S, KEY_DOWN:
				try_move(Vector2i(0, -1))
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
				try_move(Vector2i(1 if d.x > 0 else -1, 0))
			else:
				try_move(Vector2i(0, -1 if d.y > 0 else 1))
			# Restart from here so one long drag can chain several moves.
			_touches[event.index] = event.position


func try_move(dir: Vector2i) -> void:
	if state != State.PLAYING:
		return
	var target := grid_pos + dir
	if absi(target.x) > 1 or absi(target.y) > 1:
		var bump := player_body.create_tween()
		bump.tween_property(player_body, "position", Vector3(dir.x, dir.y, 0) * 0.12, 0.05)
		bump.tween_property(player_body, "position", Vector3.ZERO, 0.08)
		return
	grid_pos = target
	if _move_tween and _move_tween.is_valid():
		_move_tween.kill()
	_move_tween = create_tween()
	_move_tween.tween_property(player, "position", cell_to_world(grid_pos), MOVE_TIME) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	# Quarter roll in the direction of travel.
	var axis := Vector3(-dir.y, dir.x, 0).normalized()
	player_body.quaternion = Quaternion(axis, -PI / 2.0)
	player_body.create_tween().tween_property(player_body, "quaternion", Quaternion.IDENTITY, 0.16) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	Sfx.play("move", rng.randf_range(0.95, 1.05))
	GameData.vibrate(12)


# =========================================================================
# Main loop
# =========================================================================

func _process(delta: float) -> void:
	deco_ring.rotation.z += delta * 0.08
	_update_camera(delta)
	shadow.position = Vector3(player.position.x, -HALF + 0.01, 0)
	shadow.visible = player.visible
	if fps_label.visible:
		fps_label.text = "FPS %d" % Engine.get_frames_per_second()

	match state:
		State.COUNTDOWN:
			_scroll(delta, 4.0)
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
	return minf(time_alive / 20.0, 10.0)


## Moves the decorative track towards the camera.
func _scroll(delta: float, spd: float) -> void:
	var dz := spd * delta
	distance += dz
	floor_mat.set_shader_parameter("offset", distance)
	for f in frames:
		f.position.z += dz
		if f.position.z > DESPAWN_Z:
			f.position.z -= FRAME_COUNT * FRAME_SPACING
	for s in streaks:
		s.position.z += dz * 1.6
		if s.position.z > DESPAWN_Z:
			_reset_streak(s, SPAWN_Z)


func _process_playing(delta: float) -> void:
	time_alive += delta
	speed = minf(9.0 + difficulty() * 1.4, 23.0)
	var dz := speed * delta
	_scroll(delta, speed)
	score += dz * mult_factor

	# Effects
	if freeze_time > 0.0:
		freeze_time -= delta
	var frozen := freeze_time > 0.0
	if mult_time > 0.0:
		mult_time -= delta
		if mult_time <= 0.0:
			mult_factor = 1
	if invuln_time > 0.0:
		invuln_time -= delta
		player_body.visible = fmod(invuln_time * 12.0, 1.0) < 0.6 or invuln_time <= 0.0

	# Level generation
	gap_left -= dz
	if gap_left <= 0.0:
		_spawn_gate()
		var gap_time := maxf(0.75, 1.55 - difficulty() * 0.09) * rng.randf_range(0.85, 1.3)
		gap_left = maxf(speed * gap_time, 9.0)
	pickup_timer -= delta
	if pickup_timer <= 0.0 and gap_left > 8.0:
		_spawn_pickup()
		pickup_timer = GameData.pickup_interval() * rng.randf_range(0.8, 1.2)

	# Gates
	for o in obstacles:
		o.position.z += dz
		o.set_frozen(frozen)
		o.set_tint(frozen)
		o.step(delta)
		if not o.passed and o.position.z > 0.9:
			o.passed = true
			gates_passed += 1
			var bonus := 20 * mult_factor
			score += bonus
			_popup("+%d" % bonus, Neon.CYAN)
	for o in obstacles.duplicate():
		if o.position.z > GATE_DESPAWN_Z:
			obstacles.erase(o)
			o.queue_free()
	if invuln_time <= 0.0:
		for o in obstacles:
			if absf(o.position.z) < 1.2 and o.hits(player.global_position, PLAYER_R):
				_on_hit()
				break

	# Pickups ride with the track.
	for p in pickups.duplicate():
		p.position.z += dz
		if p.cell == grid_pos and absf(p.position.z) < 0.5:
			_collect(p)
			pickups.erase(p)
			p.queue_free()
		elif p.position.z > GATE_DESPAWN_Z:
			pickups.erase(p)
			p.queue_free()

	# Visuals
	armor_shell.visible = has_armor
	if has_armor:
		armor_shell.rotation.y += delta * 1.2
		armor_shell.rotation.x += delta * 0.7
	_update_hud()


func _update_camera(delta: float) -> void:
	shake = maxf(0.0, shake - delta * 2.5)
	# Lean slightly towards the player for a dynamic feel.
	var target := Vector3(player.position.x * 0.25, 1.1 + player.position.y * 0.15, 6.2)
	cam.position = cam.position.lerp(target, minf(1.0, delta * 6.0))
	cam.h_offset = rng.randf_range(-1.0, 1.0) * shake * 0.25
	cam.v_offset = rng.randf_range(-1.0, 1.0) * shake * 0.25


# =========================================================================
# Level generation
# =========================================================================

func _spawn_gate() -> void:
	var diff := difficulty()
	var weights := PackedFloat32Array([4.0, 3.0, 2.5 + diff * 0.2])
	var gate: Obstacle
	match rng.rand_weighted(weights):
		0:
			gate = LaserGate.new()
		1:
			gate = WallObstacle.new()
		_:
			gate = BlockGate.new()
	add_child(gate)
	gate.position = Vector3(0, 0, SPAWN_Z)
	gate.call("build", rng, diff)
	obstacles.append(gate)


func _spawn_pickup() -> void:
	var cell := Vector2i(rng.randi_range(-1, 1), rng.randi_range(-1, 1))
	var weights := PackedFloat32Array([
		1.0,
		0.15 if has_armor else GameData.armor_weight(),
		1.1,
	])
	var kind: Pickup.Kind = rng.rand_weighted(weights) as Pickup.Kind
	var p := Pickup.new()
	add_child(p)
	p.build(kind, cell, cell_to_world(cell) + Vector3(0, 0, SPAWN_Z + gap_left * 0.5))
	pickups.append(p)


func _collect(p: Pickup) -> void:
	var col := Pickup.color_of(p.kind)
	_burst(player.position, col, 24, 0.08)
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
	margin.add_theme_constant_override("margin_bottom", 60)
	hud.add_child(margin)

	var col := VBoxContainer.new()
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_theme_constant_override("separation", 12)
	margin.add_child(col)

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
	distance_label = UI.label("0 м", 26, Neon.MAGENTA, HORIZONTAL_ALIGNMENT_LEFT)
	score_box.add_child(distance_label)
	var pause_btn := UI.button("II", Neon.MAGENTA, 40, 96)
	pause_btn.custom_minimum_size = Vector2(96, 96)
	pause_btn.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
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

	hint_label = UI.label("Свайпай влево, вправо,\nвверх и вниз", 30, Neon.CYAN)
	col.add_child(hint_label)
	if GameData.games_played > 2:
		hint_label.visible = false

	countdown_label = UI.label("", 160, Neon.MAGENTA)
	countdown_label.set_anchors_preset(Control.PRESET_CENTER)
	countdown_label.custom_minimum_size = Vector2(600, 220)
	countdown_label.position = Vector2(-300, -110)
	countdown_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud.add_child(countdown_label)


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


func _update_hud() -> void:
	score_label.text = str(int(score))
	distance_label.text = "%d м" % int(distance)
	freeze_chip.visible = freeze_time > 0.0
	if freeze_chip.visible:
		freeze_chip.text = "ЗАМОРОЗКА %.1f" % freeze_time
	armor_chip.visible = has_armor
	mult_chip.visible = mult_time > 0.0
	if mult_chip.visible:
		mult_chip.text = "x%d  %.1f" % [mult_factor, mult_time]
	frost.color.a = lerpf(frost.color.a, 0.09 if freeze_time > 0.0 else 0.0, 0.15)
	if hint_label.visible and time_alive > 5.0:
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
	vb.add_child(UI.label("Дистанция: %d м   Ворот: %d" % [int(distance), gates_passed], 28, Neon.CYAN))
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
