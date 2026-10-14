class_name InvertGate
extends Obstacle
## "Gravity shift" portal: harmless, but flying through it inverts the controls
## for a few seconds.

var _rings: Array[MeshInstance3D] = []


func build(_cfg: Dictionary) -> void:
	effect = "invert"
	depth = 0.3
	var mat := Neon.glow(Neon.PURPLE, 4.0)
	var mat2 := Neon.glow(Neon.MAGENTA, 3.0)
	for i in 3:
		var ring := MeshInstance3D.new()
		var tm := TorusMesh.new()
		tm.inner_radius = 2.3 + i * 0.25
		tm.outer_radius = 2.38 + i * 0.25
		ring.mesh = tm
		ring.rotation = Vector3(PI / 2.0, 0, 0)
		ring.material_override = mat if i % 2 == 0 else mat2
		pivot.add_child(ring)
		_rings.append(ring)
	var veil := MeshInstance3D.new()
	var qm := QuadMesh.new()
	qm.size = Vector2(4.4, 4.4)
	veil.mesh = qm
	veil.material_override = Neon.ghost(Neon.PURPLE, 0.12, 1.5, true)
	pivot.add_child(veil)
	var lbl := Label3D.new()
	lbl.text = "ИНВЕРСИЯ"
	lbl.font_size = 64
	lbl.outline_size = 10
	lbl.modulate = Color(1.6, 0.8, 2.0)
	lbl.pixel_size = 0.008
	lbl.position = Vector3(0, 2.75, 0)
	pivot.add_child(lbl)


func step(delta: float) -> void:
	super.step(delta)
	for i in _rings.size():
		_rings[i].rotate_object_local(Vector3.UP, delta * (1.5 + i) * (1 if i % 2 == 0 else -1))
