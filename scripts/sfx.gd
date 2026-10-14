extends Node
## Autoload: procedurally synthesised sound effects and looping synthwave
## tracks (one per zone). No audio files are needed - everything is generated
## at startup; the extra tracks are rendered on worker threads.
## beat_index() lets gates blink in time with the music.

const RATE := 22050
const VOICES := 8

var _streams := {}
var _players: Array[AudioStreamPlayer] = []
var _next := 0
## Per-zone tracks: bpm, chord roots (midi, one per bar), arpeggio, lead wave.
const TRACKS := [
	{"bpm": 112.0, "roots": [45, 45, 41, 41, 48, 48, 43, 43], "arp": [0, 7, 12, 15, 12, 7, 3, 7], "lead": "square"},
	{"bpm": 120.0, "roots": [38, 38, 34, 34, 41, 41, 36, 36], "arp": [0, 3, 7, 10, 12, 10, 7, 3], "lead": "tri"},
	{"bpm": 128.0, "roots": [40, 40, 40, 40, 43, 43, 38, 38], "arp": [0, 12, 7, 12, 3, 12, 7, 12], "lead": "saw"},
]

var _music: AudioStreamPlayer
var _music_b: AudioStreamPlayer
var _tracks: Array = [null, null, null]
var _track := 0
var _clock := 0.0
var _tasks: Array[int] = []


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for i in VOICES:
		var p := AudioStreamPlayer.new()
		add_child(p)
		_players.append(p)
	_music = AudioStreamPlayer.new()
	add_child(_music)
	_music_b = AudioStreamPlayer.new()
	add_child(_music_b)

	_streams["move"] = _tone([[660.0, 990.0]], 0.07, "square", 0.25)
	_streams["depth"] = _tone([[440.0, 660.0]], 0.09, "square", 0.25)
	_streams["click"] = _tone([[1200.0, 900.0]], 0.05, "sine", 0.4)
	_streams["pickup"] = _tone([[660.0, 660.0], [880.0, 880.0], [1320.0, 1320.0]], 0.24, "square", 0.25)
	_streams["freeze"] = _tone([[1800.0, 600.0]], 0.45, "sine", 0.35)
	_streams["armor_break"] = _noise(0.35, 0.5)
	_streams["death"] = _tone([[440.0, 55.0]], 0.8, "saw", 0.4)
	_streams["warn"] = _tone([[220.0, 220.0]], 0.12, "square", 0.15)
	_streams["count"] = _tone([[520.0, 520.0]], 0.12, "sine", 0.4)
	_streams["go"] = _tone([[1040.0, 1040.0]], 0.25, "sine", 0.4)
	_streams["buy"] = _tone([[523.0, 523.0], [659.0, 659.0], [784.0, 784.0], [1046.0, 1046.0]], 0.3, "sine", 0.35)
	_streams["laser"] = _tone([[1400.0, 300.0]], 0.18, "saw", 0.12)

	_tracks[0] = _make_music(TRACKS[0])
	for i in range(1, TRACKS.size()):
		var data: Dictionary = TRACKS[i]
		_tasks.append(WorkerThreadPool.add_task(func():
			var wav := _make_music(data)
			_store_track.call_deferred(i, wav)))
	_music.stream = _tracks[0]
	_apply_volume()
	GameData.settings_changed.connect(_apply_volume)
	_music.play()


func _store_track(index: int, wav: AudioStreamWAV) -> void:
	_tracks[index] = wav


func _exit_tree() -> void:
	for id in _tasks:
		WorkerThreadPool.wait_for_task_completion(id)


func _process(delta: float) -> void:
	_clock += delta


## Switches to another zone track with a short crossfade.
func set_track(index: int) -> void:
	index = index % TRACKS.size()
	if index == _track or _tracks[index] == null:
		return
	_track = index
	var old := _music
	_music = _music_b
	_music_b = old
	_music.stream = _tracks[index]
	_music.volume_db = -40.0
	_music.play()
	var t := create_tween().set_parallel(true)
	t.tween_property(_music, "volume_db", _music_volume_db(), 1.2)
	t.tween_property(old, "volume_db", -60.0, 1.2)
	t.chain().tween_callback(old.stop)


## Current beat number of the playing track (falls back to a clock).
func beat_index() -> int:
	var bpm: float = TRACKS[_track]["bpm"]
	var pos := _clock
	if _music.playing:
		pos = _music.get_playback_position() + AudioServer.get_time_since_last_mix()
	return int(floorf(pos * bpm / 60.0))


func _music_volume_db() -> float:
	return linear_to_db(maxf(float(GameData.settings["music_volume"]) * 0.6, 0.0001))


func play(sfx_name: String, pitch := 1.0) -> void:
	if not _streams.has(sfx_name) or float(GameData.settings["sfx_volume"]) <= 0.001:
		return
	var p := _players[_next]
	_next = (_next + 1) % VOICES
	p.stream = _streams[sfx_name]
	p.pitch_scale = pitch
	p.play()


func _apply_volume() -> void:
	var sv := float(GameData.settings["sfx_volume"])
	for p in _players:
		p.volume_db = linear_to_db(maxf(sv, 0.0001))
	_music.volume_db = _music_volume_db()


# --- Synthesis ------------------------------------------------------------

func _osc(kind: String, phase: float) -> float:
	match kind:
		"square":
			return 1.0 if fmod(phase, 1.0) < 0.5 else -1.0
		"saw":
			return fmod(phase, 1.0) * 2.0 - 1.0
		"tri":
			return absf(fmod(phase, 1.0) * 4.0 - 2.0) - 1.0
	return sin(phase * TAU)


## `segments` is a list of [start_hz, end_hz] played one after another.
func _tone(segments: Array, length: float, kind: String, volume: float) -> AudioStreamWAV:
	var n := int(length * RATE)
	var data := PackedByteArray()
	data.resize(n * 2)
	var phase := 0.0
	var seg_len := n / segments.size()
	for i in n:
		var si := mini(i / seg_len, segments.size() - 1)
		var seg: Array = segments[si]
		var k := float(i - si * seg_len) / float(seg_len)
		var hz := lerpf(float(seg[0]), float(seg[1]), k)
		phase += hz / RATE
		var t := float(i) / n
		var env := minf(1.0, t * 40.0) * pow(1.0 - t, 1.5)
		data.encode_s16(i * 2, int(clampf(_osc(kind, phase) * env * volume, -1.0, 1.0) * 32767.0))
	return _wav(data)


func _noise(length: float, volume: float) -> AudioStreamWAV:
	var n := int(length * RATE)
	var data := PackedByteArray()
	data.resize(n * 2)
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var last := 0.0
	for i in n:
		var t := float(i) / n
		last = lerpf(last, rng.randf_range(-1.0, 1.0), 0.35)
		var v := last * pow(1.0 - t, 2.0) * volume + sin(t * 900.0) * 0.2 * (1.0 - t)
		data.encode_s16(i * 2, int(clampf(v, -1.0, 1.0) * 32767.0))
	return _wav(data)


func _make_music(track: Dictionary) -> AudioStreamWAV:
	# 8 bars of a minor synthwave arpeggio with a pulsing bass and soft kick.
	var bpm: float = track["bpm"]
	var step := 60.0 / bpm / 4.0  # sixteenth note
	var steps := 128
	var n := int(step * steps * RATE)
	var data := PackedByteArray()
	data.resize(n * 2)
	var roots: Array = track["roots"]
	var arp: Array = track["arp"]
	var lead_wave: String = track["lead"]
	var phase_a := 0.0
	var phase_b := 0.0
	var phase_k := 0.0
	var samples_per_step := step * RATE
	for i in n:
		var s := int(i / samples_per_step)
		var in_step := (i - s * samples_per_step) / samples_per_step
		var bar := (s / 16) % roots.size()
		var root: int = roots[bar]
		var lead_hz := 440.0 * pow(2.0, (root + 12 + arp[s % arp.size()] - 69) / 12.0)
		var bass_hz := 440.0 * pow(2.0, (root - 12 - 69) / 12.0)
		phase_a += lead_hz / RATE
		phase_b += bass_hz / RATE
		var lead := _osc(lead_wave, phase_a) * 0.08 * pow(1.0 - in_step, 2.0)
		var bass := _osc("saw", phase_b) * 0.12 * (0.6 + 0.4 * (1.0 - in_step))
		var kick := 0.0
		if s % 4 == 0:
			var kt := in_step * step
			phase_k += lerpf(120.0, 45.0, minf(kt * 8.0, 1.0)) / RATE
			kick = sin(phase_k * TAU) * 0.35 * maxf(0.0, 1.0 - kt * 5.0)
		else:
			phase_k = 0.0
		var v := clampf(lead + bass + kick, -1.0, 1.0)
		data.encode_s16(i * 2, int(v * 32767.0))
	var wav := _wav(data)
	wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
	wav.loop_begin = 0
	wav.loop_end = n
	return wav


func _wav(data: PackedByteArray) -> AudioStreamWAV:
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = RATE
	wav.stereo = false
	wav.data = data
	return wav
