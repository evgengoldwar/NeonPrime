class_name Obstacle
extends Node3D
## Base for every hazard. The game calls step() each frame and hits() to test
## the player. Rotation is handled here so freezing works the same everywhere.

enum Spin { STATIC, SPIN, SWING }

const CELL := 1.2
const HALF := 1.8

var spin_mode := Spin.STATIC
var spin_speed := 1.0  ## rad/s for SPIN, angular frequency for SWING (signed)
var swing_amplitude := 0.9
var spin_local_axis := Vector3.UP
var base_basis := Basis()
var finished := false
## True once the hazard has been dodged and should award points.
var survived := false

var pivot := Node3D.new()
var _spin_t := 0.0
var _frozen := false


func _init() -> void:
	add_child(pivot)


## Random basis that maps local +Y onto one of the world axes.
static func random_axis_basis(rng: RandomNumberGenerator) -> Basis:
	var options: Array[Basis] = [
		Basis(),
		Basis(Vector3.BACK, -PI / 2.0),
		Basis(Vector3.RIGHT, PI / 2.0),
	]
	var b := options[rng.randi_range(0, options.size() - 1)]
	return b * Basis(Vector3.UP, rng.randi_range(0, 3) * PI / 2.0)


func configure_spin(rng: RandomNumberGenerator, difficulty: float, allow_static := true) -> void:
	var roll := rng.randf()
	var static_chance := clampf(0.45 - difficulty * 0.06, 0.1, 0.45) if allow_static else 0.0
	if roll < static_chance:
		spin_mode = Spin.STATIC
	elif roll < static_chance + (1.0 - static_chance) * 0.55:
		spin_mode = Spin.SPIN
		spin_speed = rng.randf_range(0.5, 0.9 + difficulty * 0.12) * (1.0 if rng.randf() < 0.5 else -1.0)
	else:
		spin_mode = Spin.SWING
		spin_speed = rng.randf_range(1.2, 1.8 + difficulty * 0.15)
		swing_amplitude = rng.randf_range(0.6, 1.4)
	_update_pivot()


func set_frozen(frozen: bool) -> void:
	_frozen = frozen


func step(delta: float) -> void:
	if spin_mode != Spin.STATIC and not _frozen:
		_spin_t += delta
		_update_pivot()


func hits(_world_point: Vector3, _radius: float) -> bool:
	return false


func _update_pivot() -> void:
	var angle := 0.0
	match spin_mode:
		Spin.SPIN:
			angle = _spin_t * spin_speed
		Spin.SWING:
			angle = sin(_spin_t * spin_speed) * swing_amplitude
	pivot.basis = base_basis * Basis(spin_local_axis, angle)


func to_pivot_local(world_point: Vector3) -> Vector3:
	return pivot.global_transform.affine_inverse() * world_point
