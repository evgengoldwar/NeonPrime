class_name LaserGate
extends Obstacle
## Laser beams across the 3x3 field. cfg.lines: Array of [Vector2 a, Vector2 b]
## in pivot space. Beams are thin, so they may spin smoothly.
## Blinking gates follow the music beat; when off they are harmless.

const BEAM_R := 0.06

var segments: Array = []
var _core_mat: StandardMaterial3D
var _halo_mat: StandardMaterial3D
var _emit_mat: StandardMaterial3D


func build(cfg: Dictionary) -> void:
	depth = 0.15
	segments = cfg["lines"]
	_core_mat = Neon.glow(color, 6.0)
	_halo_mat = Neon.ghost(color, 0.3, 1.5, true)
	_emit_mat = Neon.glow(color, 4.0)
	for s in segments:
		var a: Vector2 = s[0]
		var b: Vector2 = s[1]
		var a3 := Vector3(a.x, a.y, 0)
		var b3 := Vector3(b.x, b.y, 0)
		pivot.add_child(Neon.bar(a3, b3, BEAM_R * 2.0, _core_mat))
		pivot.add_child(Neon.bar(a3, b3, BEAM_R * 6.0, _halo_mat))
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
	if blink:
		# Beat marker ring so rhythm lasers are recognisable from afar.
		var ring := MeshInstance3D.new()
		var tm := TorusMesh.new()
		tm.inner_radius = 2.55
		tm.outer_radius = 2.62
		ring.mesh = tm
		ring.rotation = Vector3(PI / 2.0, 0, 0)
		ring.material_override = _emit_mat
		add_child(ring)


func set_tint(_frozen_look: bool) -> void:
	var c := _tint()
	_core_mat.emission = c
	_emit_mat.emission = c
	_halo_mat.albedo_color = Color(c.r * 1.5, c.g * 1.5, c.b * 1.5, _halo_mat.albedo_color.a)


func apply_lit(lit_now: bool) -> void:
	_core_mat.emission_energy_multiplier = 6.0 if lit_now else 0.35
	_halo_mat.albedo_color.a = 0.3 if lit_now else 0.03


func hits_local(p: Vector2, radius: float) -> bool:
	for s in segments:
		var a: Vector2 = s[0]
		var b: Vector2 = s[1]
		var ab := b - a
		var t := clampf((p - a).dot(ab) / ab.length_squared(), 0.0, 1.0)
		if p.distance_to(a + ab * t) < radius + BEAM_R:
			return true
	return false
