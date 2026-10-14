extends Node
## Autoload: procedurally synthesised sound effects and a looping synthwave track.
## No audio files are needed - everything is generated at startup.

const RATE := 22050
const VOICES := 8

var _streams := {}
var _players: Array[AudioStreamPlayer] = []
var _next := 0
var _music: AudioStreamPlayer


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for i in VOICES:
		var p := AudioStreamPlayer.new()
		add_child(p)
		_players.append(p)
	_music = AudioStreamPlayer.new()
	add_child(_music)

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

	_music.stream = _make_music()
	_apply_volume()
	GameData.settings_changed.connect(_apply_volume)
	_music.play()


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
	var mv := float(GameData.settings["music_volume"])
	_music.volume_db = linear_to_db(maxf(mv * 0.6, 0.0001))


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


func _make_music() -> AudioStreamWAV:
	# 8 bars of a minor synthwave arpeggio with a pulsing bass and soft kick.
	var bpm := 112.0
	var step := 60.0 / bpm / 4.0  # sixteenth note
	var steps := 128
	var n := int(step * steps * RATE)
	var data := PackedByteArray()
	data.resize(n * 2)
	var roots := [45, 45, 41, 41, 48, 48, 43, 43]  # A, F, C, G (midi)
	var arp := [0, 7, 12, 15, 12, 7, 3, 7]
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
		var lead := _osc("square", phase_a) * 0.08 * pow(1.0 - in_step, 2.0)
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
