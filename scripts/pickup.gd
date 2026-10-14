class_name Pickup
extends Node3D
## Floating bonus inside one of the 27 cells.

enum Kind { FREEZE, ARMOR, MULTIPLIER }

const LIFETIME := 7.0

var kind := Kind.FREEZE
var cell := Vector3i.ZERO
var finished := false
var _t := 0.0
var _body: Node3D


static func color_of(k: Kind) -> Color:
	match k:
		Kind.FREEZE:
			return Neon.ICE
		Kind.ARMOR:
			return Neon.LIME
	return Neon.GOLD


func build(k: Kind, c: Vector3i, world_pos: Vector3) -> void:
	kind = k
	cell = c
	position = world_pos
	var col := color_of(k)
	_body = Node3D.new()
	add_child(_body)
	var mat := Neon.glow(col, 4.5)
	match k:
		Kind.FREEZE:
			# Snowflake-ish crystal: three crossed prisms.
			for axis in [Vector3.RIGHT, Vector3.UP, Vector3.BACK]:
				var mi := MeshInstance3D.new()
				var bm := BoxMesh.new()
				bm.size = Vector3(0.09, 0.62, 0.09)
				mi.mesh = bm
				mi.material_override = mat
				mi.basis = Neon.basis_from_y(axis)
				_body.add_child(mi)
			var core := MeshInstance3D.new()
			var sm := SphereMesh.new()
			sm.radius = 0.16
			sm.height = 0.32
			sm.radial_segments = 4
			sm.rings = 2
			core.mesh = sm
			core.material_override = mat
			_body.add_child(core)
		Kind.ARMOR:
			var mi := MeshInstance3D.new()
			var tm := TorusMesh.new()
			tm.inner_radius = 0.2
			tm.outer_radius = 0.3
			mi.mesh = tm
			mi.material_override = mat
			mi.rotation = Vector3(PI / 2.0, 0, 0)
			_body.add_child(mi)
			var gem := MeshInstance3D.new()
			var pm := PrismMesh.new()
			pm.size = Vector3(0.22, 0.26, 0.08)
			gem.mesh = pm
			gem.material_override = mat
			_body.add_child(gem)
		Kind.MULTIPLIER:
			var mi := MeshInstance3D.new()
			var cm := CylinderMesh.new()
			cm.top_radius = 0.28
			cm.bottom_radius = 0.28
			cm.height = 0.08
			mi.mesh = cm
			mi.material_override = mat
			mi.rotation = Vector3(PI / 2.0, 0, 0)
			_body.add_child(mi)
			var lbl := Label3D.new()
			lbl.text = "x2"
			lbl.font_size = 64
			lbl.outline_size = 12
			lbl.modulate = Color(1.6, 1.3, 0.3)
			lbl.outline_modulate = Color(0.3, 0.15, 0.0)
			lbl.pixel_size = 0.005
			lbl.position = Vector3(0, 0, 0.06)
			lbl.billboard = BaseMaterial3D.BILLBOARD_ENABLED
			lbl.no_depth_test = true
			_body.add_child(lbl)
	var halo := MeshInstance3D.new()
	var hm := SphereMesh.new()
	hm.radius = 0.42
	hm.height = 0.84
	halo.mesh = hm
	halo.material_override = Neon.ghost(col, 0.12, 1.0, true)
	add_child(halo)
	scale = Vector3.ONE * 0.01


func _process(delta: float) -> void:
	_t += delta
	_body.rotation.y += delta * 2.2
	_body.position.y = sin(_t * 3.0) * 0.06
	var s := minf(1.0, _t * 5.0)
	scale = Vector3.ONE * s
	if _t > LIFETIME - 2.0:
		visible = fmod(_t * 8.0, 1.0) < 0.6
	if _t > LIFETIME:
		finished = true
