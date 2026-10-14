class_name BlockGate
extends Obstacle
## Neon cubes in some of the cells. cfg.blocks: Array[Vector2i] (cells),
## cfg.size: cube size. Full-size cubes only step; small cubes (smaller than
## the player) may spin smoothly and leave gaps between them.

var blocks: Array = []
var size := 0.95
var _mat: StandardMaterial3D


func build(cfg: Dictionary) -> void:
	blocks = cfg["blocks"]
	size = cfg.get("size", 0.95)
	depth = size
	_mat = Neon.glow(color, 2.2)
	var edge := Neon.glow(Color.WHITE.lerp(color, 0.4), 5.0)
	for b in blocks:
		var mi := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = Vector3.ONE * size * 0.92
		mi.mesh = bm
		mi.material_override = _mat
		mi.position = Vector3(b.x * CELL, b.y * CELL, 0)
		pivot.add_child(mi)
		var wire := Neon.wire_box(Vector3.ONE * size * 0.5, 0.04, edge)
		wire.position = mi.position
		pivot.add_child(wire)


func set_tint(_frozen_look: bool) -> void:
	_mat.emission = _tint()


func hits_local(p: Vector2, radius: float) -> bool:
	var reach := size * 0.5 + radius * 0.6
	for b in blocks:
		if absf(p.x - b.x * CELL) < reach and absf(p.y - b.y * CELL) < reach:
			return true
	return false
