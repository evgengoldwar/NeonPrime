class_name WallObstacle
extends Obstacle
## A 3x3 neon wall with one or more holes that flies through the arena.
## It can also rotate around its travel axis, so the holes move.

const START := 8.0
const THICKNESS := 0.2

var speed := 3.0
var holes: Array[Vector2i] = []
var _pos := -START
var _slab_mat: StandardMaterial3D
var _edge_mat: StandardMaterial3D
var _hole_mat: StandardMaterial3D
var _color := Neon.MAGENTA


func build(rng: RandomNumberGenerator, difficulty: float) -> void:
	# Mostly from the far side towards the camera, sometimes sideways or from above.
	var dirs: Array[Basis] = [
		Basis(),
		Basis(),
		Basis(Vector3.UP, PI / 2.0),
		Basis(Vector3.UP, -PI / 2.0),
		Basis(Vector3.RIGHT, PI / 2.0),
	]
	base_basis = dirs[rng.randi_range(0, dirs.size() - 1)]
	spin_local_axis = Vector3.BACK
	configure_spin(rng, difficulty * 0.8)
	if spin_mode == Spin.SPIN:
		spin_speed *= 0.7
	speed = minf(2.6 + difficulty * 0.45, 6.5) * rng.randf_range(0.9, 1.15)
	_color = [Neon.MAGENTA, Neon.PURPLE, Neon.CYAN][rng.randi_range(0, 2)]

	var hole_count := 3 if difficulty < 1.5 else (2 if difficulty < 4.0 else 1)
	if rng.randf() < 0.25:
		hole_count = maxi(1, hole_count - 1)
	var cells: Array[Vector2i] = []
	for x in [-1, 0, 1]:
		for y in [-1, 0, 1]:
			cells.append(Vector2i(x, y))
	for i in hole_count:
		holes.append(cells.pop_at(rng.randi_range(0, cells.size() - 1)))

	_slab_mat = Neon.ghost(_color, 0.28, 1.4)
	_edge_mat = Neon.glow(_color, 4.0)
	_hole_mat = Neon.glow(Neon.LIME, 3.0)
	for x in [-1, 0, 1]:
		for y in [-1, 0, 1]:
			var c := Vector3(x * CELL, y * CELL, 0)
			if Vector2i(x, y) in holes:
				_add_frame(c, CELL * 0.86, _hole_mat, 0.035)
			else:
				var slab := MeshInstance3D.new()
				var bm := BoxMesh.new()
				bm.size = Vector3(CELL * 0.97, CELL * 0.97, THICKNESS)
				slab.mesh = bm
				slab.material_override = _slab_mat
				slab.position = c
				pivot.add_child(slab)
				_add_frame(c, CELL * 0.97, _edge_mat, 0.05)
	_update_transform()


func _add_frame(center: Vector3, size: float, mat: Material, t: float) -> void:
	var h := size * 0.5
	var pts: Array[Vector3] = [
		center + Vector3(-h, -h, 0), center + Vector3(h, -h, 0),
		center + Vector3(h, h, 0), center + Vector3(-h, h, 0),
	]
	for i in 4:
		pivot.add_child(Neon.bar(pts[i], pts[(i + 1) % 4], t, mat))


func set_frozen(frozen: bool) -> void:
	super.set_frozen(frozen)
	_edge_mat.emission = Neon.ICE if frozen else _color


func step(delta: float) -> void:
	super.step(delta)
	_pos += speed * delta
	_update_transform()
	if _pos > HALF + 0.6 and not survived:
		survived = true
	if _pos > HALF + 0.6:
		var k := clampf(1.0 - (_pos - HALF - 0.6) / 2.0, 0.0, 1.0)
		pivot.scale = Vector3.ONE * (0.6 + 0.4 * k)
		_slab_mat.albedo_color.a = 0.28 * k
		_edge_mat.emission_energy_multiplier = 4.0 * k
		_hole_mat.emission_energy_multiplier = 3.0 * k
		if k <= 0.0:
			finished = true


func _update_transform() -> void:
	pivot.position = base_basis * Vector3(0, 0, _pos)


func hits(world_point: Vector3, radius: float) -> bool:
	var lp := to_pivot_local(world_point)
	if absf(lp.z) > THICKNESS * 0.5 + radius * 0.8:
		return false
	if absf(lp.x) > HALF or absf(lp.y) > HALF:
		return false
	var ix := clampi(roundi(lp.x / CELL), -1, 1)
	var iy := clampi(roundi(lp.y / CELL), -1, 1)
	if Vector2i(ix, iy) in holes:
		if absf(lp.x - ix * CELL) < 0.5 and absf(lp.y - iy * CELL) < 0.5:
			return false
	return true
