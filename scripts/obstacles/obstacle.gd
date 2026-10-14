class_name Obstacle
extends Node3D
## Base for every gate on the track. Gates lie in the XY plane (the 3x3 field)
## and are moved towards the player along +Z by the game.
##
## Motion rules that keep gates fair:
## - only thin things (lasers, small blocks) rotate smoothly (SPIN / SWING);
## - big things (walls, full-size blocks) rotate or slide in 90° / 1-cell
##   STEPs, so their holes always line up with the cells again;
## - a STEP never starts right before the gate reaches the player (`locked`).
## Freezing stops every kind of motion (and blinking) in its current state.

enum Motion { STATIC, SPIN, SWING, STEP, SLIDE, STEP_SLIDE }

const CELL := 1.2
const HALF := 1.8
const TURN_TIME := 0.25
## Blinking gates are lit for 2 beats out of 4.
const BLINK_PERIOD := 4
const BLINK_ON := 2

var motion := Motion.STATIC
var speed := 1.0  ## SPIN rad/s (signed); SWING / SLIDE angular frequency
var amplitude := 0.9  ## SWING radians; SLIDE world units
var step_interval := 1.2
var step_dir := 1
var slide_axis := Vector2.RIGHT
var blink := false
var blink_phase := 0
## Thickness along Z used for collision.
var depth := 0.2
var color := Neon.MAGENTA
var passed := false
## Set by the game when the gate is about to reach the player: no new STEP starts.
var locked := false
## Tests force blinking gates to their dangerous state.
var always_lit := false
## Non-lethal special gates (e.g. "invert") report an effect when passed.
var effect := ""

var pivot := Node3D.new()
var _t := 0.0
var _frozen := false
var _lit := true
var _tint_frozen := false


func _init() -> void:
	add_child(pivot)


func configure(cfg: Dictionary) -> void:
	var m: Dictionary = cfg.get("motion", {})
	motion = m.get("type", Motion.STATIC)
	speed = m.get("speed", 1.0)
	amplitude = m.get("amplitude", 0.9)
	step_interval = m.get("interval", 1.2)
	step_dir = m.get("dir", 1)
	slide_axis = m.get("axis", Vector2.RIGHT)
	_t = m.get("t0", 0.0)
	blink = cfg.get("blink", false)
	blink_phase = cfg.get("blink_phase", 0)
	color = cfg.get("color", color)
	build(cfg)
	_update_pivot()
	_update_lit()
	set_tint(false)


## Subclasses create their visuals here.
func build(_cfg: Dictionary) -> void:
	pass


func set_frozen(frozen: bool) -> void:
	_frozen = frozen
	if frozen != _tint_frozen:
		_tint_frozen = frozen
		set_tint(frozen)


func step(delta: float) -> void:
	if _frozen:
		return
	var nt := _t + delta
	if locked and (motion == Motion.STEP or motion == Motion.STEP_SLIDE):
		if _turn_frac(nt) > 0.0 and _turn_frac(_t) <= 0.0:
			nt = _t  # Hold: never start turning right in front of the player.
	_t = nt
	if motion != Motion.STATIC:
		_update_pivot()
	_update_lit()


func is_lit() -> bool:
	return always_lit or not blink or _lit


func _update_lit() -> void:
	if not blink:
		return
	var lit := posmod(Sfx.beat_index() + blink_phase, BLINK_PERIOD) < BLINK_ON
	if lit != _lit:
		_lit = lit
		apply_lit(lit)


## 0 while holding, 0..1 during the quick turn at the end of each interval.
func _turn_frac(t: float) -> float:
	var f := fmod(t, step_interval) - (step_interval - TURN_TIME)
	return clampf(f / TURN_TIME, 0.0, 1.0)


func _update_pivot() -> void:
	var angle := 0.0
	var offset := Vector2.ZERO
	match motion:
		Motion.SPIN:
			angle = _t * speed
		Motion.SWING:
			angle = sin(_t * speed) * amplitude
		Motion.STEP:
			var k := floorf(_t / step_interval)
			angle = (k + smoothstep(0.0, 1.0, _turn_frac(_t))) * PI / 2.0 * step_dir
		Motion.SLIDE:
			offset = slide_axis * sin(_t * speed) * amplitude
		Motion.STEP_SLIDE:
			var seq := [0.0, 1.0, 0.0, -1.0]
			var k := int(floorf(_t / step_interval))
			var a: float = seq[k % 4]
			var b: float = seq[(k + 1) % 4]
			offset = slide_axis * lerpf(a, b, smoothstep(0.0, 1.0, _turn_frac(_t))) * CELL * step_dir
	pivot.position = Vector3(offset.x, offset.y, 0)
	pivot.rotation = Vector3(0, 0, angle)


## world_point is tested only while the gate overlaps the player's Z.
func hits(world_point: Vector3, radius: float) -> bool:
	if not is_lit():
		return false
	var lp := pivot.global_transform.affine_inverse() * world_point
	if absf(lp.z) > depth * 0.5 + radius:
		return false
	return hits_local(Vector2(lp.x, lp.y), radius)


func hits_local(_p: Vector2, _radius: float) -> bool:
	return false


func set_tint(_frozen_look: bool) -> void:
	pass


func apply_lit(_lit_now: bool) -> void:
	pass


func _tint() -> Color:
	return Neon.ICE if _tint_frozen else color


## Cells use index -1..1 on each axis.
static func all_cells() -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	for x in [-1, 0, 1]:
		for y in [-1, 0, 1]:
			cells.append(Vector2i(x, y))
	return cells


static func shuffle_array(arr: Array, rng: RandomNumberGenerator) -> void:
	for i in range(arr.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var tmp = arr[i]
		arr[i] = arr[j]
		arr[j] = tmp


static func frame(parent: Node3D, center: Vector3, size: float, mat: Material, t: float) -> void:
	var h := size * 0.5
	var pts: Array[Vector3] = [
		center + Vector3(-h, -h, 0), center + Vector3(h, -h, 0),
		center + Vector3(h, h, 0), center + Vector3(-h, h, 0),
	]
	for i in 4:
		parent.add_child(Neon.bar(pts[i], pts[(i + 1) % 4], t, mat))
