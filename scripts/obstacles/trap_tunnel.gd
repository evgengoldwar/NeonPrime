class_name TrapTunnel
extends Obstacle
## "Tunnel trap": walls slide in from the sides and close every cell except one
## for a stretch of track. cfg.free: Vector2i, cfg.length: world units.
## Several tunnels in a row make a twisting corridor.

const CLOSE_START := -48.0
const CLOSE_END := -22.0

var free_cell := Vector2i.ZERO
var _pieces: Array[Node3D] = []
var _targets: Array[Vector3] = []
var _outward: Array[Vector3] = []
var _closed := 0.0
var _edge_mat: StandardMaterial3D


func build(cfg: Dictionary) -> void:
	free_cell = cfg["free"]
	depth = cfg.get("length", 9.0)
	var body := Neon.ghost(color, 0.22, 1.2)
	_edge_mat = Neon.glow(color, 3.5)
	var free_mat := Neon.glow(Neon.LIME, 3.0)
	for c in all_cells():
		var center := Vector3(c.x * CELL, c.y * CELL, 0)
		if c == free_cell:
			frame(pivot, center + Vector3(0, 0, depth * 0.5), CELL * 0.86, free_mat, 0.04)
			continue
		var piece := Node3D.new()
		piece.position = center
		pivot.add_child(piece)
		var mi := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = Vector3(CELL * 0.96, CELL * 0.96, depth)
		mi.mesh = bm
		mi.material_override = body
		piece.add_child(mi)
		frame(piece, Vector3(0, 0, depth * 0.5), CELL * 0.96, _edge_mat, 0.05)
		frame(piece, Vector3(0, 0, -depth * 0.5), CELL * 0.96, _edge_mat, 0.05)
		_pieces.append(piece)
		_targets.append(center)
		# The centre piece drops in from above, the others slide in from the sides.
		_outward.append(Vector3.UP if c == Vector2i.ZERO else Vector3(c.x, c.y, 0).normalized())
	_apply_close()


func step(delta: float) -> void:
	super.step(delta)
	var front := position.z + depth * 0.5
	_closed = clampf((front - CLOSE_START) / (CLOSE_END - CLOSE_START), 0.0, 1.0)
	_apply_close()


func _apply_close() -> void:
	var k := 1.0 - smoothstep(0.0, 1.0, _closed)
	for i in _pieces.size():
		_pieces[i].position = _targets[i] + _outward[i] * 3.5 * k


func set_tint(_frozen_look: bool) -> void:
	_edge_mat.emission = _tint()


func hits_local(p: Vector2, radius: float) -> bool:
	if _closed < 0.999:
		return false
	var reach := CELL * 0.48 + radius * 0.5
	for c in all_cells():
		if c == free_cell:
			continue
		if absf(p.x - c.x * CELL) < reach and absf(p.y - c.y * CELL) < reach:
			return true
	return false
