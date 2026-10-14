class_name LaserGate
extends Obstacle
## A gate of laser beams across the 3x3 field.
## Static gates use full rows / columns and always leave a free cell.
## Rotating gates use blades with an empty hub, so the centre cell is safe.

const BEAM_R := 0.06

var color := Neon.RED
## Segments in pivot space: [Vector2 a, Vector2 b]
var segments: Array = []
var _core_mat: StandardMaterial3D
var _emit_mat: StandardMaterial3D


func build(rng: RandomNumberGenerator, difficulty: float) -> void:
	roll_spin(rng, difficulty)
	depth = 0.15
	color = [Neon.RED, Neon.MAGENTA, Neon.ORANGE][rng.randi_range(0, 2)]
	if is_rotating():
		_pattern_rotating(rng, difficulty)
	else:
		_pattern_static(rng, difficulty)
	_core_mat = Neon.glow(color, 6.0)
	_emit_mat = Neon.glow(color, 4.0)
	var halo_mat := Neon.ghost(color, 0.3, 1.5, true)
	for s in segments:
		var a: Vector2 = s[0]
		var b: Vector2 = s[1]
		var a3 := Vector3(a.x, a.y, 0)
		var b3 := Vector3(b.x, b.y, 0)
		pivot.add_child(Neon.bar(a3, b3, BEAM_R * 2.0, _core_mat))
		pivot.add_child(Neon.bar(a3, b3, BEAM_R * 6.0, halo_mat))
		for e in [a3, b3]:
			var em := MeshInstance3D.new()
			var sm := SphereMesh.new()
			sm.radius = 0.12
			sm.height = 0.24
			sm.radial_segments = 4
			sm.rings = 2
			em.mesh = sm
			em.material_override = _emit_mat
			em.position = e
			pivot.add_child(em)


func _pattern_static(rng: RandomNumberGenerator, difficulty: float) -> void:
	var safe := Vector2i(rng.randi_range(-1, 1), rng.randi_range(-1, 1))
	var lines: Array = []
	for i in [-1, 0, 1]:
		if i != safe.y:
			lines.append(["row", i])
		if i != safe.x:
			lines.append(["col", i])
	shuffle(lines, rng)
	var count := clampi(1 + int(difficulty * 0.6) + rng.randi_range(0, 1), 1, 4)
	var e := HALF + 0.3
	for k in count:
		var l: Array = lines[k]
		var o: float = l[1] * CELL
		if l[0] == "row":
			segments.append([Vector2(-e, o), Vector2(e, o)])
		else:
			segments.append([Vector2(o, -e), Vector2(o, e)])


func _pattern_rotating(rng: RandomNumberGenerator, difficulty: float) -> void:
	var e := HALF * 1.45
	if rng.randf() < 0.65:
		# Blades with an empty hub.
		var blades := rng.randi_range(1, 2 if difficulty < 2.0 else 4)
		var start := rng.randf() * TAU
		for i in blades:
			var ang := start + i * TAU / blades
			var d := Vector2(cos(ang), sin(ang))
			segments.append([d * 0.8, d * e])
	else:
		# Parallel bars offset from the centre.
		var o := CELL
		segments.append([Vector2(-e, o), Vector2(e, o)])
		if rng.randf() < 0.5 + difficulty * 0.1:
			segments.append([Vector2(-e, -o), Vector2(e, -o)])


func set_tint(frozen_look: bool) -> void:
	var c := Neon.ICE if frozen_look else color
	_core_mat.emission = c
	_emit_mat.emission = c


func hits_local(p: Vector2, radius: float) -> bool:
	for s in segments:
		var a: Vector2 = s[0]
		var b: Vector2 = s[1]
		var ab := b - a
		var t := clampf((p - a).dot(ab) / ab.length_squared(), 0.0, 1.0)
		if p.distance_to(a + ab * t) < radius + BEAM_R:
			return true
	return false
