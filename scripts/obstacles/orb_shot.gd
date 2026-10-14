class_name OrbShot
extends Obstacle
## An energy orb that flies straight through a row of cells.
## Its path is telegraphed with a flickering line first.

const RADIUS := 0.24
const RANGE := 7.0

var speed := 6.0
var warn_time := 0.9
var _dir := Vector3.FORWARD
var _start := Vector3.ZERO
var _t := 0.0
var _travel := 0.0
var _launched := false
var _line_mat: StandardMaterial3D
var _orb: MeshInstance3D
var _orb_mat: StandardMaterial3D


func build(rng: RandomNumberGenerator, difficulty: float) -> void:
	var axis := rng.randi_range(0, 2)
	var a := rng.randi_range(-1, 1) * CELL
	var b := rng.randi_range(-1, 1) * CELL
	var sgn := 1.0 if rng.randf() < 0.5 else -1.0
	match axis:
		0:
			_dir = Vector3(sgn, 0, 0)
			_start = Vector3(-sgn * RANGE, a, b)
		1:
			_dir = Vector3(0, sgn, 0)
			_start = Vector3(a, -sgn * RANGE, b)
		_:
			# Along Z always comes from the far side so it is easy to read.
			_dir = Vector3(0, 0, 1)
			_start = Vector3(a, b, -RANGE)
	speed = minf(5.5 + difficulty * 0.5, 10.0)
	warn_time = maxf(0.55, 1.0 - difficulty * 0.05)

	_line_mat = Neon.ghost(Neon.ORANGE, 0.0, 2.0, true)
	var line := Neon.bar(_start, _start + _dir * RANGE * 2.0, 0.05, _line_mat)
	add_child(line)

	_orb_mat = Neon.glow(Neon.ORANGE, 5.0)
	_orb = MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = RADIUS
	sm.height = RADIUS * 2.0
	sm.radial_segments = 12
	sm.rings = 6
	_orb.mesh = sm
	_orb.material_override = _orb_mat
	_orb.visible = false
	_orb.position = _start
	add_child(_orb)
	var halo := MeshInstance3D.new()
	var hm := SphereMesh.new()
	hm.radius = RADIUS * 2.0
	hm.height = RADIUS * 4.0
	halo.mesh = hm
	halo.material_override = Neon.ghost(Neon.ORANGE, 0.25, 1.2, true)
	_orb.add_child(halo)


func step(delta: float) -> void:
	_t += delta
	if not _launched:
		_line_mat.albedo_color = Color(Neon.ORANGE * 2.0, 0.15 + 0.3 * absf(sin(_t * 18.0)))
		if _t >= warn_time:
			_launched = true
			_orb.visible = true
		return
	_travel += speed * delta
	_orb.position = _start + _dir * _travel
	_orb.rotate_y(delta * 6.0)
	_line_mat.albedo_color = Color(Neon.ORANGE * 2.0, maxf(0.0, 0.3 - _travel * 0.04))
	if _travel > RANGE + HALF + 0.5:
		survived = true
	if _travel > RANGE * 2.0:
		finished = true


func hits(world_point: Vector3, radius: float) -> bool:
	if not _launched:
		return false
	return _orb.global_position.distance_to(world_point) < radius + RADIUS
