class_name Neon
extends RefCounted
## Neon palette, materials and environment shared by every scene.

const CYAN := Color(0.0, 0.95, 1.0)
const MAGENTA := Color(1.0, 0.1, 0.85)
const PURPLE := Color(0.55, 0.2, 1.0)
const LIME := Color(0.35, 1.0, 0.3)
const GOLD := Color(1.0, 0.78, 0.1)
const RED := Color(1.0, 0.12, 0.25)
const ORANGE := Color(1.0, 0.45, 0.05)
const ICE := Color(0.55, 0.85, 1.0)
const BG := Color(0.012, 0.0, 0.04)

const GRID_SHADER := preload("res://shaders/neon_grid.gdshader")


## Opaque glowing material.
static func glow(color: Color, energy := 3.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color.darkened(0.6)
	m.emission_enabled = true
	m.emission = color
	m.emission_energy_multiplier = energy
	m.roughness = 0.4
	return m


## Translucent glowing material (additive when `additive` is set).
static func ghost(color: Color, alpha := 0.35, energy := 2.0, additive := false) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.albedo_color = Color(color.r * energy, color.g * energy, color.b * energy, alpha)
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	if additive:
		m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.no_depth_test = false
	m.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
	return m


static func make_environment(glow_on: bool) -> Environment:
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = BG
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.25, 0.2, 0.4)
	env.ambient_light_energy = 0.6
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.glow_enabled = glow_on
	env.glow_intensity = 1.1
	env.glow_strength = 1.0
	env.glow_bloom = 0.08
	env.glow_hdr_threshold = 0.9
	env.glow_blend_mode = Environment.GLOW_BLEND_MODE_ADDITIVE
	env.set_glow_level(0, 0.0)
	env.set_glow_level(1, 1.0)
	env.set_glow_level(2, 1.0)
	env.set_glow_level(3, 0.6)
	env.set_glow_level(4, 0.3)
	env.fog_enabled = true
	env.fog_light_color = Color(0.12, 0.0, 0.2)
	env.fog_density = 0.012
	return env


## Thin glowing bar between two points.
static func bar(a: Vector3, b: Vector3, thickness: float, mat: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	var length := a.distance_to(b)
	mesh.size = Vector3(thickness, length, thickness)
	mi.mesh = mesh
	mi.material_override = mat
	mi.transform = Transform3D(basis_from_y((b - a).normalized()), (a + b) * 0.5)
	return mi


## Basis whose Y axis points along `dir`.
static func basis_from_y(dir: Vector3) -> Basis:
	var y := dir.normalized()
	var helper := Vector3.RIGHT if absf(y.dot(Vector3.RIGHT)) < 0.9 else Vector3.FORWARD
	var x := helper.cross(y).normalized()
	var z := x.cross(y).normalized()
	return Basis(x, y, z)


## Twelve edges of an axis-aligned box centred at the origin.
static func wire_box(half: Vector3, thickness: float, mat: Material) -> Node3D:
	var root := Node3D.new()
	var corners: Array[Vector3] = []
	for sx in [-1.0, 1.0]:
		for sy in [-1.0, 1.0]:
			for sz in [-1.0, 1.0]:
				corners.append(Vector3(sx * half.x, sy * half.y, sz * half.z))
	for i in corners.size():
		for j in range(i + 1, corners.size()):
			var d := corners[i] - corners[j]
			var diffs := 0
			if absf(d.x) > 0.001: diffs += 1
			if absf(d.y) > 0.001: diffs += 1
			if absf(d.z) > 0.001: diffs += 1
			if diffs == 1:
				root.add_child(bar(corners[i], corners[j], thickness, mat))
	return root


## Endless scrolling synthwave floor.
static func make_floor(y: float, color: Color) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(80, 80)
	mi.mesh = plane
	var sm := ShaderMaterial.new()
	sm.shader = GRID_SHADER
	sm.set_shader_parameter("line_color", color)
	mi.material_override = sm
	mi.position = Vector3(0, y, 0)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return mi
