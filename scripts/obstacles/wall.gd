class_name WallObstacle
extends Obstacle
## A 3x3 neon wall with holes (green frames). Rotating walls always have a
## hole in the centre.

var holes: Array[Vector2i] = []
var _edge_mat: StandardMaterial3D
var _color := Neon.MAGENTA


func build(rng: RandomNumberGenerator, difficulty: float) -> void:
	roll_spin(rng, difficulty * 0.8)
	depth = 0.25
	_color = [Neon.MAGENTA, Neon.PURPLE, Neon.CYAN][rng.randi_range(0, 2)]
	var hole_count := 3 if difficulty < 1.5 else (2 if difficulty < 4.0 else 1)
	if rng.randf() < 0.3:
		hole_count = maxi(1, hole_count - 1)
	var cells := all_cells()
	if is_rotating():
		cells.erase(Vector2i.ZERO)
		holes.append(Vector2i.ZERO)
		hole_count -= 1
	shuffle(cells, rng)
	for i in hole_count:
		holes.append(cells[i])

	var slab_mat := Neon.ghost(_color, 0.3, 1.4)
	_edge_mat = Neon.glow(_color, 4.0)
	var hole_mat := Neon.glow(Neon.LIME, 3.0)
	for c in all_cells():
		var center := Vector3(c.x * CELL, c.y * CELL, 0)
		if c in holes:
			_frame(center, CELL * 0.86, hole_mat, 0.035)
		else:
			var slab := MeshInstance3D.new()
			var bm := BoxMesh.new()
			bm.size = Vector3(CELL * 0.97, CELL * 0.97, depth)
			slab.mesh = bm
			slab.material_override = slab_mat
			slab.position = center
			pivot.add_child(slab)
			_frame(center, CELL * 0.97, _edge_mat, 0.05)


func _frame(center: Vector3, size: float, mat: Material, t: float) -> void:
	var h := size * 0.5
	var pts: Array[Vector3] = [
		center + Vector3(-h, -h, 0), center + Vector3(h, -h, 0),
		center + Vector3(h, h, 0), center + Vector3(-h, h, 0),
	]
	for i in 4:
		pivot.add_child(Neon.bar(pts[i], pts[(i + 1) % 4], t, mat))


func set_tint(frozen_look: bool) -> void:
	_edge_mat.emission = Neon.ICE if frozen_look else _color


func hits_local(p: Vector2, _radius: float) -> bool:
	if absf(p.x) > HALF or absf(p.y) > HALF:
		return false
	var ix := clampi(roundi(p.x / CELL), -1, 1)
	var iy := clampi(roundi(p.y / CELL), -1, 1)
	if Vector2i(ix, iy) in holes:
		if absf(p.x - ix * CELL) < 0.5 and absf(p.y - iy * CELL) < 0.5:
			return false
	return true
