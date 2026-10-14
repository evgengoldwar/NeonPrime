class_name Obstacle
extends Node3D
## Base for every gate on the track. Gates lie in the XY plane (the 3x3 field)
## and are moved towards the player along +Z by the game.
## They can stand still, spin around the track axis or swing back and forth.
## Freezing stops the rotation in whatever state it currently is.

enum Spin { STATIC, SPIN, SWING }

const CELL := 1.2
const HALF := 1.8

var spin_mode := Spin.STATIC
var spin_speed := 1.0  ## rad/s for SPIN, angular frequency for SWING (signed)
var swing_amplitude := 0.9
## Thickness along Z used for collision.
var depth := 0.2
var passed := false

var pivot := Node3D.new()
var _spin_t := 0.0
var _frozen := false


func _init() -> void:
	add_child(pivot)


## Picks static / spin / swing. Rotating gates must keep the centre cell safe.
func roll_spin(rng: RandomNumberGenerator, difficulty: float) -> void:
	var static_chance := clampf(0.6 - difficulty * 0.07, 0.25, 0.6)
	var roll := rng.randf()
	if roll < static_chance:
		spin_mode = Spin.STATIC
	elif roll < static_chance + (1.0 - static_chance) * 0.55:
		spin_mode = Spin.SPIN
		spin_speed = rng.randf_range(0.7, 1.1 + difficulty * 0.15) * (1.0 if rng.randf() < 0.5 else -1.0)
	else:
		spin_mode = Spin.SWING
		spin_speed = rng.randf_range(1.5, 2.2 + difficulty * 0.15)
		swing_amplitude = rng.randf_range(0.5, 1.3)
	_spin_t = rng.randf() * 10.0
	_update_pivot()


func is_rotating() -> bool:
	return spin_mode != Spin.STATIC


func set_frozen(frozen: bool) -> void:
	_frozen = frozen


func step(delta: float) -> void:
	if spin_mode != Spin.STATIC and not _frozen:
		_spin_t += delta
		_update_pivot()


func _update_pivot() -> void:
	var angle := 0.0
	match spin_mode:
		Spin.SPIN:
			angle = _spin_t * spin_speed
		Spin.SWING:
			angle = sin(_spin_t * spin_speed) * swing_amplitude
	pivot.rotation = Vector3(0, 0, angle)


## world_point is tested only while the gate overlaps the player's Z.
func hits(world_point: Vector3, radius: float) -> bool:
	var lp := pivot.global_transform.affine_inverse() * world_point
	if absf(lp.z) > depth * 0.5 + radius:
		return false
	return hits_local(Vector2(lp.x, lp.y), radius)


func hits_local(_p: Vector2, _radius: float) -> bool:
	return false


## Cells used by the generator: index -1..1 on each axis.
static func all_cells() -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	for x in [-1, 0, 1]:
		for y in [-1, 0, 1]:
			cells.append(Vector2i(x, y))
	return cells


static func shuffle(arr: Array, rng: RandomNumberGenerator) -> void:
	for i in range(arr.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var tmp = arr[i]
		arr[i] = arr[j]
		arr[j] = tmp


func set_tint(_frozen_look: bool) -> void:
	pass
