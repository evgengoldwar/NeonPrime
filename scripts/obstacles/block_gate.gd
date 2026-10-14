class_name BlockGate
extends Obstacle
## Separate neon cubes standing in some of the 9 cells.
## Static: at least one free cell. Rotating: centre is always free.

const SIZE := 0.95

var blocks: Array[Vector2i] = []
var _mat: StandardMaterial3D
var _color := Neon.PURPLE


func build(rng: RandomNumberGenerator, difficulty: float) -> void:
	roll_spin(rng, difficulty)
	depth = SIZE
	_color = [Neon.PURPLE, Neon.CYAN, Neon.ORANGE][rng.randi_range(0, 2)]
	var cells := all_cells()
	shuffle(cells, rng)
	var free := Vector2i.ZERO if is_rotating() else cells[0]
	cells.erase(free)
	var count := clampi(3 + int(difficulty * 0.8) + rng.randi_range(0, 1), 3, 7 if is_rotating() else 8)
	for i in count:
		blocks.append(cells[i])
	_mat = Neon.glow(_color, 2.2)
	var edge := Neon.glow(Color.WHITE.lerp(_color, 0.4), 5.0)
	for b in blocks:
		var mi := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = Vector3.ONE * SIZE * 0.92
		mi.mesh = bm
		mi.material_override = _mat
		mi.position = Vector3(b.x * CELL, b.y * CELL, 0)
		pivot.add_child(mi)
		var wire := Neon.wire_box(Vector3.ONE * SIZE * 0.5, 0.04, edge)
		wire.position = mi.position
		pivot.add_child(wire)


func set_tint(frozen_look: bool) -> void:
	_mat.emission = Neon.ICE if frozen_look else _color


func hits_local(p: Vector2, radius: float) -> bool:
	var reach := SIZE * 0.5 + radius * 0.6
	for b in blocks:
		if absf(p.x - b.x * CELL) < reach and absf(p.y - b.y * CELL) < reach:
			return true
	return false
