class_name WallObstacle
extends Obstacle
## A 3x3 neon wall with holes (green frames). cfg.holes: Array[Vector2i].
## Walls only turn in 90° steps so the holes always line up with cells.

var holes: Array = []
var _edge_mat: StandardMaterial3D


func build(cfg: Dictionary) -> void:
	depth = 0.25
	holes = cfg["holes"]
	var slab_mat := Neon.ghost(color, 0.3, 1.4)
	_edge_mat = Neon.glow(color, 4.0)
	var hole_mat := Neon.glow(Neon.LIME, 3.0)
	for c in all_cells():
		var center := Vector3(c.x * CELL, c.y * CELL, 0)
		if c in holes:
			frame(pivot, center, CELL * 0.86, hole_mat, 0.035)
		else:
			var slab := MeshInstance3D.new()
			var bm := BoxMesh.new()
			bm.size = Vector3(CELL * 0.97, CELL * 0.97, depth)
			slab.mesh = bm
			slab.material_override = slab_mat
			slab.position = center
			pivot.add_child(slab)
			frame(pivot, center, CELL * 0.97, _edge_mat, 0.05)


func set_tint(_frozen_look: bool) -> void:
	_edge_mat.emission = _tint()


func hits_local(p: Vector2, _radius: float) -> bool:
	if absf(p.x) > HALF or absf(p.y) > HALF:
		return false
	var ix := clampi(roundi(p.x / CELL), -1, 1)
	var iy := clampi(roundi(p.y / CELL), -1, 1)
	if Vector2i(ix, iy) in holes:
		if absf(p.x - ix * CELL) < 0.5 and absf(p.y - iy * CELL) < 0.5:
			return false
	return true
