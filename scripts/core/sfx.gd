extends Node
## Звуки и музыка без ассетов: короткие тоны и фоновый гул синтезируются на лету.

const RATE := 22050
const PAD_FRAMES := 2048

var _sounds := {}
var _players := []
var _music: AudioStreamPlayer
var _music_pitch := 1.0


func _ready() -> void:
	_sounds["click"] = _tone([660.0], 0.05, 0.25)
	_sounds["place"] = _tone([330.0, 440.0], 0.08, 0.3)
	_sounds["step"] = _tone([110.0], 0.05, 0.2)
	_sounds["hit"] = _noise(0.12, 0.45)
	_sounds["big"] = _noise(0.3, 0.7)
	_sounds["kill"] = _tone([523.0, 659.0, 784.0], 0.1, 0.4)
	_sounds["coin"] = _tone([988.0, 1319.0], 0.07, 0.3)
	_sounds["lose"] = _tone([392.0, 330.0, 262.0], 0.15, 0.4)
	_sounds["combo"] = _tone([440.0, 554.0, 659.0, 880.0], 0.06, 0.35)
	_sounds["boss"] = _tone([98.0, 92.0, 87.0], 0.25, 0.5)
	for i in 6:
		var p := AudioStreamPlayer.new()
		add_child(p)
		_players.append(p)
	_music = AudioStreamPlayer.new()
	_music.stream = _drone()
	_music.volume_db = -14.0
	# Повтор музыки делаем сами, а не петлёй AudioStreamWAV.
	_music.finished.connect(_on_music_finished)
	add_child(_music)


func play(name: String, pitch: float = 1.0) -> void:
	if not Game.setting("sound") or not _sounds.has(name):
		return
	for p in _players:
		if not p.playing:
			p.stream = _sounds[name]
			p.pitch_scale = pitch
			p.play()
			return


func music(pitch: float = 1.0) -> void:
	_music_pitch = pitch
	if not Game.setting("music"):
		_music.stop()
		return
	_music.pitch_scale = pitch
	if not _music.playing:
		CrashLog.event("музыка")
		_music.play()


func _on_music_finished() -> void:
	if Game.setting("music"):
		CrashLog.event("музыка: повтор")
		_music.play()


func stop_music() -> void:
	_music.stop()


func refresh_music() -> void:
	music(_music_pitch)


## Звук без петли движка и с «подушкой» тишины в конце: смешивание звука
## не должно читать за краем данных. Ровно в точке петли музыки игра падала
## на Pixel 9 (Android с аппаратной защитой памяти).
func _wav(samples: PackedFloat32Array) -> AudioStreamWAV:
	var bytes := PackedByteArray()
	bytes.resize((samples.size() + PAD_FRAMES) * 2)
	bytes.fill(0)
	for i in samples.size():
		var v := int(clampf(samples[i], -1.0, 1.0) * 32767.0)
		bytes.encode_s16(i * 2, v)
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = RATE
	w.stereo = false
	w.data = bytes
	w.loop_mode = AudioStreamWAV.LOOP_DISABLED
	return w


func _tone(freqs: Array, each: float, vol: float) -> AudioStreamWAV:
	var s := PackedFloat32Array()
	for f in freqs:
		var n := int(each * RATE)
		for i in n:
			var t := float(i) / RATE
			var env := 1.0 - float(i) / n
			s.append(sin(TAU * f * t) * env * vol)
	return _wav(s)


func _noise(len_s: float, vol: float) -> AudioStreamWAV:
	var s := PackedFloat32Array()
	var n := int(len_s * RATE)
	var r := RandomNumberGenerator.new()
	r.seed = 7
	for i in n:
		var env := pow(1.0 - float(i) / n, 2.0)
		s.append((r.randf() * 2.0 - 1.0) * env * vol + sin(TAU * 70.0 * i / RATE) * env * vol * 0.6)
	return _wav(s)


func _drone() -> AudioStreamWAV:
	var s := PackedFloat32Array()
	var n := RATE * 8
	for i in n:
		var t := float(i) / RATE
		var lfo := 0.5 + 0.5 * sin(TAU * t / 8.0)
		var v := sin(TAU * 55.0 * t) * 0.35 + sin(TAU * 82.5 * t) * 0.2 * lfo + sin(TAU * 110.0 * t + sin(TAU * 0.25 * t)) * 0.1
		s.append(v * 0.5)
	return _wav(s)
