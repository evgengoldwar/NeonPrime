class_name LevelGen
extends RefCounted
## Endless level generator. Produces gate configs (dictionaries) one by one.
## Mixes single random gates with hand-shaped patterns ("snake", "ladder",
## "mirror", tunnel traps, rhythm lasers, ...) whose mix depends on the zone.
##
## Every config has "type" (laser / wall / blocks / tunnel / invert) and either
## "gap" (seconds until the next gate) or "gap_units" (world units).
##
## Anti-camping: the safe cell is rarely the centre, and rotating lasers pass
## through the centre, so standing still in the middle does not work.

const CELL := 1.2
const E := 2.3  ## half-length of straight beams (a bit beyond the field)

const ZONES := [
	{
		"name": "НЕОН-СИТИ",
		"floor": Color(1.0, 0.1, 0.85),
		"rail": Color(0.55, 0.2, 1.0),
		"frames": [Color(0.55, 0.2, 1.0), Color(1.0, 0.1, 0.85)],
		"rings": [Color(1.0, 0.1, 0.85), Color(0.55, 0.2, 1.0), Color(0.0, 0.95, 1.0)],
		"bg": Color(0.012, 0.0, 0.04),
		"fog": Color(0.12, 0.0, 0.2),
		"gates": [Color(1.0, 0.12, 0.25), Color(1.0, 0.1, 0.85), Color(0.55, 0.2, 1.0), Color(0.0, 0.95, 1.0)],
		"kinds": {"laser": 4.0, "wall": 3.0, "blocks": 3.0},
		"patterns": {"single": 5.0, "snake": 1.6, "ladder": 1.4, "mirror": 1.2, "trap": 0.6, "rhythm": 0.6, "sweep": 0.6, "invert": 0.3},
	},
	{
		"name": "КИБЕРПУСТОТА",
		"floor": Color(0.0, 0.7, 1.0),
		"rail": Color(0.1, 0.4, 1.0),
		"frames": [Color(0.0, 0.95, 1.0), Color(0.2, 0.35, 1.0)],
		"rings": [Color(0.0, 0.95, 1.0), Color(0.2, 0.35, 1.0), Color(0.6, 1.0, 1.0)],
		"bg": Color(0.0, 0.01, 0.04),
		"fog": Color(0.0, 0.06, 0.16),
		"gates": [Color(0.0, 0.95, 1.0), Color(0.35, 1.0, 0.3), Color(0.6, 0.4, 1.0), Color(1.0, 1.0, 1.0)],
		"kinds": {"laser": 5.0, "wall": 2.0, "blocks": 3.0},
		"patterns": {"single": 4.0, "snake": 1.2, "ladder": 1.2, "mirror": 1.0, "trap": 0.8, "rhythm": 1.8, "sweep": 1.4, "invert": 0.7},
	},
	{
		"name": "КРАСНАЯ ЗОНА",
		"floor": Color(1.0, 0.15, 0.1),
		"rail": Color(1.0, 0.45, 0.05),
		"frames": [Color(1.0, 0.2, 0.1), Color(1.0, 0.55, 0.0)],
		"rings": [Color(1.0, 0.15, 0.1), Color(1.0, 0.5, 0.0), Color(1.0, 0.85, 0.2)],
		"bg": Color(0.03, 0.0, 0.01),
		"fog": Color(0.12, 0.01, 0.02),
		"gates": [Color(1.0, 0.12, 0.2), Color(1.0, 0.5, 0.0), Color(1.0, 0.85, 0.1), Color(1.0, 0.2, 0.7)],
		"kinds": {"laser": 3.0, "wall": 3.0, "blocks": 4.0},
		"patterns": {"single": 3.5, "snake": 1.6, "ladder": 1.0, "mirror": 1.0, "trap": 1.6, "rhythm": 1.0, "sweep": 1.0, "invert": 1.0},
	},
]

var rng: RandomNumberGenerator
var _queue: Array[Dictionary] = []
var _last_safe := Vector2i(1, 1)


func _init(r: RandomNumberGenerator) -> void:
	rng = r


static func zone_for(distance: float) -> int:
	return int(distance / 500.0)


func next(diff: float, zone_index: int) -> Dictionary:
	if _queue.is_empty():
		_fill(diff, ZONES[zone_index % ZONES.size()])
	return _queue.pop_front()


# =========================================================================
# Helpers
# =========================================================================

func _pick(weights: Dictionary) -> String:
	var keys := weights.keys()
	var w := PackedFloat32Array()
	for k in keys:
		w.append(float(weights[k]))
	return keys[rng.rand_weighted(w)]


func _color(zone: Dictionary) -> Color:
	var list: Array = zone["gates"]
	return list[rng.randi_range(0, list.size() - 1)]


func _single_gap(diff: float) -> float:
	return maxf(0.75, 1.45 - diff * 0.08) * rng.randf_range(0.9, 1.25)


func _pattern_gap(diff: float) -> float:
	return maxf(0.5, 0.78 - diff * 0.03)


## Safe cell that is rarely the centre and differs from the previous one.
func _safe_cell() -> Vector2i:
	var c := Vector2i.ZERO
	for i in 6:
		if rng.randf() < 0.08:
			c = Vector2i.ZERO
		else:
			c = Vector2i(rng.randi_range(-1, 1), rng.randi_range(-1, 1))
			if c == Vector2i.ZERO:
				continue
		if c != _last_safe:
			break
	_last_safe = c
	return c


func _neighbors(c: Vector2i) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
		var n: Vector2i = c + d
		if absi(n.x) <= 1 and absi(n.y) <= 1:
			out.append(n)
	return out


static func row(y: int) -> Array:
	return [Vector2(-E, y * CELL), Vector2(E, y * CELL)]


static func col(x: int) -> Array:
	return [Vector2(x * CELL, -E), Vector2(x * CELL, E)]


## Lines through rows / columns that block everything except `safe`.
## Always includes a line through the centre unless the centre is safe.
func _lines_except(safe: Vector2i, count: int) -> Array:
	var options: Array = []
	for i in [-1, 0, 1]:
		if i != safe.y:
			options.append(row(i))
		if i != safe.x:
			options.append(col(i))
	var lines: Array = []
	if safe != Vector2i.ZERO:
		lines.append(row(0) if safe.y != 0 else col(0))
		options.erase(lines[0])
	Obstacle.shuffle_array(options, rng)
	while lines.size() < count and not options.is_empty():
		lines.append(options.pop_back())
	return lines


func _motion_spin(diff: float) -> Dictionary:
	return {
		"type": Obstacle.Motion.SPIN,
		"speed": rng.randf_range(0.8, 1.2 + diff * 0.12) * (1.0 if rng.randf() < 0.5 else -1.0),
		"t0": rng.randf() * 10.0,
	}


func _motion_swing(diff: float) -> Dictionary:
	return {
		"type": Obstacle.Motion.SWING,
		"speed": rng.randf_range(1.6, 2.4 + diff * 0.12),
		"amplitude": rng.randf_range(0.5, 1.2),
		"t0": rng.randf() * 10.0,
	}


func _motion_step(diff: float) -> Dictionary:
	return {
		"type": Obstacle.Motion.STEP,
		"interval": maxf(0.75, rng.randf_range(1.0, 1.5) - diff * 0.04),
		"dir": 1 if rng.randf() < 0.5 else -1,
		"t0": rng.randf() * 3.0,
	}


func _motion_step_slide(diff: float) -> Dictionary:
	return {
		"type": Obstacle.Motion.STEP_SLIDE,
		"interval": maxf(0.7, rng.randf_range(0.9, 1.3) - diff * 0.04),
		"axis": Vector2.RIGHT if rng.randf() < 0.5 else Vector2.UP,
		"dir": 1 if rng.randf() < 0.5 else -1,
		"t0": rng.randf() * 3.0,
	}


func _mirror(cfg: Dictionary, axis_x: bool) -> Dictionary:
	var m := cfg.duplicate(true)
	var flip := func(c: Vector2i) -> Vector2i: return Vector2i(-c.x, c.y) if axis_x else Vector2i(c.x, -c.y)
	if m.has("holes"):
		m["holes"] = (m["holes"] as Array).map(flip)
	if m.has("blocks"):
		m["blocks"] = (m["blocks"] as Array).map(flip)
	if m.has("lines"):
		var lines: Array = []
		for l in m["lines"]:
			var a: Vector2 = l[0]
			var b: Vector2 = l[1]
			if axis_x:
				lines.append([Vector2(-a.x, a.y), Vector2(-b.x, b.y)])
			else:
				lines.append([Vector2(a.x, -a.y), Vector2(b.x, -b.y)])
		m["lines"] = lines
	return m


# =========================================================================
# Gate builders
# =========================================================================

func _laser(diff: float, zone: Dictionary) -> Dictionary:
	var cfg := {"type": "laser", "color": _color(zone)}
	var roll := rng.randf()
	var moving_chance := clampf(0.3 + diff * 0.06, 0.3, 0.75)
	if roll > moving_chance:
		# Static rows / columns, at least two lines, centre usually blocked.
		cfg["lines"] = _lines_except(_safe_cell(), clampi(2 + int(diff * 0.5) + rng.randi_range(0, 1), 2, 4))
		if diff > 3.0 and rng.randf() < 0.3:
			cfg["motion"] = _motion_step(diff)
		return cfg
	match rng.randi_range(0, 3):
		0:
			# Propeller: full lines through the centre (centre is never safe).
			var n := 1 if diff < 2.0 else rng.randi_range(1, 2)
			var start := rng.randf() * PI
			var lines: Array = []
			for i in n:
				var a := start + i * PI / n
				var d := Vector2(cos(a), sin(a)) * E * 1.15
				lines.append([-d, d])
			cfg["lines"] = lines
			cfg["motion"] = _motion_spin(diff) if rng.randf() < 0.6 else _motion_swing(diff)
		1:
			# Clock arm from the centre outwards.
			var arms := 1 if diff < 3.0 else 2
			var lines: Array = []
			var start := rng.randf() * TAU
			for i in arms:
				var a := start + i * PI
				lines.append([Vector2.ZERO, Vector2(cos(a), sin(a)) * E * 1.15])
			cfg["lines"] = lines
			cfg["motion"] = _motion_spin(diff)
			cfg["motion"]["speed"] *= 1.4
		2:
			cfg = _sweeper(diff, zone)
		_:
			# Two parallel bars swinging around the centre (centre safe, edges not).
			cfg["lines"] = [row(1), row(-1)] if rng.randf() < 0.5 else [col(1), col(-1)]
			cfg["motion"] = _motion_swing(diff)
	return cfg


## A laser line that slides smoothly up/down or left/right across the field.
func _sweeper(diff: float, zone: Dictionary) -> Dictionary:
	var horizontal := rng.randf() < 0.5
	var lines: Array = [row(0) if horizontal else col(0)]
	return {
		"type": "laser",
		"color": _color(zone),
		"lines": lines,
		"motion": {
			"type": Obstacle.Motion.SLIDE,
			"axis": Vector2.UP if horizontal else Vector2.RIGHT,
			"amplitude": CELL * 1.25,
			"speed": rng.randf_range(2.0, 2.8 + diff * 0.15),
			"t0": rng.randf() * 10.0,
		},
	}


func _wall(diff: float, zone: Dictionary) -> Dictionary:
	var hole_count := 3 if diff < 1.5 else (2 if diff < 4.0 else 1)
	if rng.randf() < 0.3:
		hole_count = maxi(1, hole_count - 1)
	var holes: Array = [_safe_cell()]
	var cells := Obstacle.all_cells()
	cells.erase(Vector2i.ZERO)  # extra holes are never in the centre
	Obstacle.shuffle_array(cells, rng)
	for c in cells:
		if holes.size() >= hole_count:
			break
		if not c in holes:
			holes.append(c)
	var cfg := {"type": "wall", "color": _color(zone), "holes": holes}
	if diff > 1.5 and rng.randf() < 0.4:
		cfg["motion"] = _motion_step(diff)
	return cfg


func _blocks(diff: float, zone: Dictionary) -> Dictionary:
	var cfg := {"type": "blocks", "color": _color(zone)}
	var roll := rng.randf()
	if diff > 1.0 and roll < 0.35:
		# Small cubes (smaller than the player) orbiting a small centre cube.
		var blocks: Array = [Vector2i.ZERO]
		var ring: Array[Vector2i] = [Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 0), Vector2i(0, -1)]
		if rng.randf() < 0.5:
			ring = [Vector2i(1, 1), Vector2i(-1, 1), Vector2i(-1, -1), Vector2i(1, -1)]
		var n := clampi(2 + int(diff * 0.3), 2, 4)
		for i in n:
			blocks.append(ring[i * 4 / n])
		cfg["blocks"] = blocks
		cfg["size"] = 0.45
		cfg["motion"] = _motion_spin(diff) if rng.randf() < 0.6 else _motion_swing(diff)
		return cfg
	var free_count := 1 if diff > 3.5 else (2 if diff > 1.0 else 3)
	var free: Array = [_safe_cell()]
	var cells := Obstacle.all_cells()
	Obstacle.shuffle_array(cells, rng)
	for c in cells:
		if free.size() >= free_count:
			break
		if not c in free and c != Vector2i.ZERO:
			free.append(c)
	var blocks: Array = []
	for c in Obstacle.all_cells():
		if not c in free:
			blocks.append(c)
	cfg["blocks"] = blocks
	if diff > 2.0 and roll < 0.6:
		cfg["motion"] = _motion_step(diff) if rng.randf() < 0.5 else _motion_step_slide(diff)
	return cfg


func _single(diff: float, zone: Dictionary) -> Dictionary:
	var cfg: Dictionary
	match _pick(zone["kinds"]):
		"laser":
			cfg = _laser(diff, zone)
		"wall":
			cfg = _wall(diff, zone)
		_:
			cfg = _blocks(diff, zone)
	cfg["gap"] = _single_gap(diff)
	return cfg


## A static gate of a random kind with a single safe cell (used by mirror).
func _static_one_hole(kind: String, safe: Vector2i, zone: Dictionary, color: Color) -> Dictionary:
	match kind:
		"wall":
			return {"type": "wall", "color": color, "holes": [safe]}
		"blocks":
			var blocks: Array = []
			for c in Obstacle.all_cells():
				if c != safe:
					blocks.append(c)
			return {"type": "blocks", "color": color, "blocks": blocks}
	return {"type": "laser", "color": color, "lines": _lines_except(safe, 4)}


# =========================================================================
# Patterns
# =========================================================================

func _fill(diff: float, zone: Dictionary) -> void:
	var gap := _pattern_gap(diff)
	var color := _color(zone)
	var pattern := _pick(zone["patterns"])
	# Patterns unlock gradually.
	if time_locked(pattern, diff):
		pattern = "single"
	match pattern:
		"snake":
			# The only hole wanders to a neighbouring cell gate after gate.
			var kind := "wall" if rng.randf() < 0.6 else "blocks"
			var cur := _safe_cell()
			var prev := cur
			var n := rng.randi_range(4, 6)
			for i in n:
				var cfg := _static_one_hole(kind, cur, zone, color)
				cfg["gap"] = gap
				if i == n - 1 and rng.randf() < 0.5:
					cfg["coin_cell"] = cur
				_queue.append(cfg)
				var options := _neighbors(cur)
				if options.size() > 1:
					options.erase(prev)
				prev = cur
				cur = options[rng.randi_range(0, options.size() - 1)]
			_last_safe = prev
		"ladder":
			# Free row (or column) climbs step by step: 0 -> 1 -> ... and back.
			var use_rows := rng.randf() < 0.5
			var pos := -1 if rng.randf() < 0.5 else 1
			var d := -pos
			for i in rng.randi_range(4, 6):
				var lines: Array = []
				for k in [-1, 0, 1]:
					if k != pos:
						lines.append(row(k) if use_rows else col(k))
				_queue.append({"type": "laser", "color": color, "lines": lines, "gap": gap})
				if absi(pos + d) > 1:
					d = -d
				pos += d
		"mirror":
			var kind := _pick(zone["kinds"])
			var safe := _safe_cell()
			if safe.x == 0:
				safe.x = 1
			var base := _static_one_hole(kind, safe, zone, color)
			var axis_x := rng.randf() < 0.7
			for i in 4:
				var cfg := base if i % 2 == 0 else _mirror(base, axis_x)
				cfg = cfg.duplicate(true)
				cfg["gap"] = gap * 1.1
				_queue.append(cfg)
		"trap":
			# Twisting corridor: 2-3 tunnels, the free cell moves to a neighbour.
			# A short open gap between tunnels gives time to switch cells.
			var cur := _safe_cell()
			var prev := cur
			var n := 2 if diff < 3.0 else 3
			var lengths: Array[float] = []
			for i in n:
				lengths.append(rng.randf_range(7.0, 10.0))
			for i in n:
				var cfg := {"type": "tunnel", "color": color, "free": cur, "length": lengths[i]}
				if i < n - 1:
					cfg["gap_units"] = (lengths[i] + lengths[i + 1]) * 0.5
					cfg["gap"] = maxf(0.4, 0.55 - diff * 0.02)
				else:
					cfg["gap_units"] = lengths[i] * 0.5
				_queue.append(cfg)
				var options := _neighbors(cur)
				if options.size() > 1:
					options.erase(prev)
				prev = cur
				cur = options[rng.randi_range(0, options.size() - 1)]
			_last_safe = prev
		"rhythm":
			# Lasers that blink to the beat: pass while they are dark.
			for i in rng.randi_range(3, 4):
				var cfg := {
					"type": "laser", "color": color, "blink": true, "blink_phase": rng.randi_range(0, 3),
					"lines": _lines_except(_safe_cell(), rng.randi_range(3, 4)), "gap": gap * 1.2,
				}
				_queue.append(cfg)
		"sweep":
			for i in rng.randi_range(2, 3):
				var cfg := _sweeper(diff, zone)
				cfg["gap"] = gap * 1.2
				_queue.append(cfg)
		"invert":
			_queue.append({"type": "invert", "gap": 0.9})
			for i in 3:
				var cfg := _static_one_hole(["wall", "laser", "blocks"][i], _safe_cell(), zone, color)
				if cfg["type"] == "laser":
					cfg["lines"] = _lines_except(_last_safe, 2)
				cfg["gap"] = 1.0
				_queue.append(cfg)
		_:
			_queue.append(_single(diff, zone))
			return
	# Breathing room after a pattern.
	_queue[-1]["gap"] = _single_gap(diff) * 1.2


func time_locked(pattern: String, diff: float) -> bool:
	match pattern:
		"mirror", "ladder", "snake":
			return diff < 0.5
		"rhythm", "sweep":
			return diff < 1.0
		"trap", "invert":
			return diff < 1.5
	return false
