class_name LaserRig
extends Obstacle
## A set of laser beams that can stand still, spin around an axis or swing back
## and forth. Beams are telegraphed (thin and flickering) before they turn lethal.
##
## Pattern rules keep at least one layer free from "blades", so the centre cell
## of that layer is always a safe spot.

enum Phase { WARN, ACTIVE, FADE }

const BEAM_LENGTH := 9.0
const BEAM_RADIUS := 0.055

var warn_time := 1.1
var active_time := 4.0
var phase := Phase.WARN
var color := Neon.RED

## Each beam: {"p": Vector3, "d": Vector3} in pivot-local space.
var beams: Array[Dictionary] = []
var _t := 0.0
var _core_mat: StandardMaterial3D
var _halo_mat: StandardMaterial3D
var _emitter_mat: StandardMaterial3D
var _beam_nodes: Array[Node3D] = []


func build(rng: RandomNumberGenerator, difficulty: float) -> void:
	base_basis = random_axis_basis(rng)
	spin_local_axis = Vector3.UP
	configure_spin(rng, difficulty)
	warn_time = maxf(0.6, 1.2 - difficulty * 0.06)
	active_time = rng.randf_range(3.5, 5.0 + difficulty * 0.3)
	color = [Neon.RED, Neon.MAGENTA, Neon.ORANGE][rng.randi_range(0, 2)]

	if spin_mode == Spin.STATIC:
		_pattern_static(rng, difficulty)
	else:
		_pattern_rotating(rng, difficulty)

	_core_mat = Neon.ghost(color, 0.0, 4.0)
	_halo_mat = Neon.ghost(color, 0.0, 1.5, true)
	_emitter_mat = Neon.glow(color, 4.0)
	for b in beams:
		_add_beam_visual(b["p"], b["d"])
	_apply_phase_look(0.0)


## Static rigs: lines parallel to the axis through several of the 9 columns.
func _pattern_static(rng: RandomNumberGenerator, difficulty: float) -> void:
	var cols: Array[Vector2i] = []
	for x in [-1, 0, 1]:
		for z in [-1, 0, 1]:
			cols.append(Vector2i(x, z))
	_shuffle(cols, rng)
	var count := clampi(3 + int(difficulty * 0.7) + rng.randi_range(0, 1), 3, 7)
	for i in count:
		beams.append({"p": Vector3(cols[i].x * CELL, 0, cols[i].y * CELL), "d": Vector3.UP})
	# Some static rigs also get a cross beam along another direction.
	if difficulty > 1.5 and rng.randf() < 0.5:
		var free := cols[count]
		var layer := rng.randi_range(-1, 1)
		var along_x := rng.randf() < 0.5
		var p := Vector3(0, layer * CELL, free.y * CELL) if along_x else Vector3(free.x * CELL, layer * CELL, 0)
		beams.append({"p": p, "d": Vector3.RIGHT if along_x else Vector3.BACK})


## Rotating rigs: "blades" sweep whole layers, "pillars" sweep a ring.
func _pattern_rotating(rng: RandomNumberGenerator, difficulty: float) -> void:
	var layers: Array[int] = [-1, 0, 1]
	_shuffle(layers, rng)
	var blade_layers := 1 if difficulty < 2.0 else rng.randi_range(1, 2)
	for i in blade_layers:
		var h := layers[i] * CELL
		var arms := rng.randi_range(1, 2 if difficulty < 3.0 else 3)
		var start := rng.randf() * PI
		for a in arms:
			var ang := start + a * PI / arms
			beams.append({"p": Vector3(0, h, 0), "d": Vector3(cos(ang), 0, sin(ang))})
	var pillars := rng.randi_range(0, 1 + int(difficulty * 0.5))
	pillars = mini(pillars, 3)
	for i in pillars:
		var corner := rng.randf() < 0.4
		var ang := rng.randi_range(0, 3) * PI / 2.0 + (PI / 4.0 if corner else 0.0)
		var r := CELL * (sqrt(2.0) if corner else 1.0)
		beams.append({"p": Vector3(cos(ang) * r, 0, sin(ang) * r), "d": Vector3.UP})


func _shuffle(arr: Array, rng: RandomNumberGenerator) -> void:
	for i in range(arr.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var tmp = arr[i]
		arr[i] = arr[j]
		arr[j] = tmp


func _add_beam_visual(p: Vector3, d: Vector3) -> void:
	var node := Node3D.new()
	node.transform = Transform3D(Neon.basis_from_y(d), p)
	pivot.add_child(node)
	var core := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = BEAM_RADIUS
	cm.bottom_radius = BEAM_RADIUS
	cm.height = BEAM_LENGTH
	cm.radial_segments = 8
	cm.rings = 1
	core.mesh = cm
	core.material_override = _core_mat
	node.add_child(core)
	var halo := MeshInstance3D.new()
	var hm := CylinderMesh.new()
	hm.top_radius = BEAM_RADIUS * 3.2
	hm.bottom_radius = BEAM_RADIUS * 3.2
	hm.height = BEAM_LENGTH
	hm.radial_segments = 10
	hm.rings = 1
	halo.mesh = hm
	halo.material_override = _halo_mat
	node.add_child(halo)
	for s in [-1.0, 1.0]:
		var em := MeshInstance3D.new()
		var sm := SphereMesh.new()
		sm.radius = 0.13
		sm.height = 0.26
		sm.radial_segments = 4
		sm.rings = 2
		em.mesh = sm
		em.material_override = _emitter_mat
		em.position = Vector3(0, s * 2.7, 0)
		node.add_child(em)
	_beam_nodes.append(node)


func step(delta: float) -> void:
	super.step(delta)
	_t += delta
	match phase:
		Phase.WARN:
			_apply_phase_look(_t)
			if _t >= warn_time:
				phase = Phase.ACTIVE
				_t = 0.0
				Sfx.play("laser", randf_range(0.9, 1.1))
				_apply_phase_look(0.0)
		Phase.ACTIVE:
			_apply_phase_look(_t)
			if _t >= active_time:
				phase = Phase.FADE
				_t = 0.0
				survived = true
		Phase.FADE:
			_apply_phase_look(_t)
			if _t >= 0.35:
				finished = true


func _apply_phase_look(t: float) -> void:
	var tint := Neon.ICE if _frozen else color
	match phase:
		Phase.WARN:
			var flicker := 0.25 + 0.25 * absf(sin(t * 22.0))
			_set_alpha(tint, flicker, 0.12, 0.35)
		Phase.ACTIVE:
			var pulse := 0.9 + 0.1 * sin(t * 30.0)
			var grow := minf(1.0, t * 10.0 + 0.3)
			_set_alpha(tint, pulse, 0.35 * pulse, grow)
		Phase.FADE:
			var k := 1.0 - t / 0.35
			_set_alpha(tint, k, 0.35 * k, k)


func _set_alpha(tint: Color, core_a: float, halo_a: float, width: float) -> void:
	_core_mat.albedo_color = Color(tint.r * 4.0, tint.g * 4.0, tint.b * 4.0, core_a)
	_halo_mat.albedo_color = Color(tint.r * 1.5, tint.g * 1.5, tint.b * 1.5, halo_a)
	_emitter_mat.emission = tint
	for n in _beam_nodes:
		for c in n.get_children():
			if c is MeshInstance3D and c.mesh is CylinderMesh:
				c.scale = Vector3(width, 1.0, width)


func hits(world_point: Vector3, radius: float) -> bool:
	if phase != Phase.ACTIVE:
		return false
	var lp := to_pivot_local(world_point)
	for b in beams:
		var p: Vector3 = b["p"]
		var d: Vector3 = b["d"]
		var v := lp - p
		var dist := (v - d * v.dot(d)).length()
		if dist < radius + BEAM_RADIUS:
			return true
	return false
