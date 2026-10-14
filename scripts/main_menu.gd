extends Node3D
## Main menu: big PLAY button, and Settings / Upgrades / Leaderboard below,
## over an animated neon 3D background.

var env: Environment
var hero: Node3D
var orbiters: Node3D
var beams: Node3D
var ui_root: Control
var coins_label: Label
var best_label: Label
var _overlay: Control
var _t := 0.0


func _ready() -> void:
	get_tree().paused = false
	_build_background()
	_build_ui()
	GameData.coins_changed.connect(func(_v): _refresh_header())
	GameData.settings_changed.connect(func(): env.glow_enabled = bool(GameData.settings["glow"]))


# --- 3D background --------------------------------------------------------

func _build_background() -> void:
	env = Neon.make_environment(bool(GameData.settings["glow"]))
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)

	var cam := Camera3D.new()
	cam.position = Vector3(0, 1.4, 7.5)
	cam.keep_aspect = Camera3D.KEEP_WIDTH
	cam.fov = 70.0
	add_child(cam)
	cam.look_at(Vector3(0, 0.6, 0))

	add_child(Neon.make_floor(-2.6, Neon.MAGENTA))

	var ring_root := Node3D.new()
	ring_root.position = Vector3(0, 1.0, -24)
	add_child(ring_root)
	for i in 3:
		var ring := MeshInstance3D.new()
		var tm := TorusMesh.new()
		tm.inner_radius = 6.0 + i * 2.0
		tm.outer_radius = 6.15 + i * 2.0
		tm.rings = 64
		ring.mesh = tm
		ring.rotation = Vector3(PI / 2.0, 0, 0)
		ring.material_override = Neon.glow([Neon.MAGENTA, Neon.PURPLE, Neon.CYAN][i], 2.5 - i * 0.6)
		ring_root.add_child(ring)

	# Hero cube in the middle of the screen.
	hero = Node3D.new()
	hero.position = Vector3(0, -0.35, 0)
	add_child(hero)
	var core := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3.ONE * 1.1
	core.mesh = bm
	core.material_override = Neon.glow(Neon.CYAN, 1.4)
	hero.add_child(core)
	hero.add_child(Neon.wire_box(Vector3.ONE * 0.6, 0.06, Neon.glow(Color(0.7, 1.0, 1.0), 6.0)))
	hero.add_child(Neon.wire_box(Vector3.ONE * 1.1, 0.03, Neon.glow(Neon.PURPLE, 3.0)))

	orbiters = Node3D.new()
	hero.add_child(orbiters)
	var colors := [Neon.MAGENTA, Neon.LIME, Neon.GOLD, Neon.ICE]
	for i in 4:
		var mi := MeshInstance3D.new()
		var m := BoxMesh.new()
		m.size = Vector3.ONE * 0.22
		mi.mesh = m
		mi.material_override = Neon.glow(colors[i], 4.0)
		var a := i * TAU / 4.0
		mi.position = Vector3(cos(a) * 2.0, sin(a * 2.0) * 0.3, sin(a) * 2.0)
		orbiters.add_child(mi)

	beams = Node3D.new()
	beams.position = hero.position
	add_child(beams)
	for i in 2:
		var mi := MeshInstance3D.new()
		var cm := CylinderMesh.new()
		cm.top_radius = 0.035
		cm.bottom_radius = 0.035
		cm.height = 14.0
		mi.mesh = cm
		mi.material_override = Neon.ghost(Neon.RED, 0.9, 4.0)
		mi.rotation = Vector3(0, 0, PI / 2.0 + i * 0.5)
		beams.add_child(mi)

	var light := OmniLight3D.new()
	light.light_color = Neon.CYAN
	light.omni_range = 5.0
	hero.add_child(light)


func _process(delta: float) -> void:
	_t += delta
	hero.rotation = Vector3(_t * 0.35, _t * 0.5, 0)
	hero.position.y = -0.35 + sin(_t * 1.4) * 0.12
	orbiters.rotation = Vector3(-_t * 0.35, _t * 0.4, 0)
	beams.rotation = Vector3(sin(_t * 0.6) * 0.3, _t * 0.3, cos(_t * 0.4) * 0.6)


# --- UI ------------------------------------------------------------------

func _build_ui() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	ui_root = Control.new()
	ui_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	ui_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(ui_root)

	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_theme_constant_override("margin_left", 32)
	margin.add_theme_constant_override("margin_right", 32)
	margin.add_theme_constant_override("margin_top", 60)
	margin.add_theme_constant_override("margin_bottom", 56)
	ui_root.add_child(margin)

	var col := VBoxContainer.new()
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_theme_constant_override("separation", 20)
	margin.add_child(col)

	var header := HBoxContainer.new()
	header.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(header)
	coins_label = UI.label("", 32, Neon.GOLD, HORIZONTAL_ALIGNMENT_LEFT)
	coins_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(coins_label)
	best_label = UI.label("", 32, Neon.CYAN, HORIZONTAL_ALIGNMENT_RIGHT)
	best_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(best_label)
	_refresh_header()

	col.add_child(_spacer(0.3))
	var title := UI.label("NEON", 120, Neon.MAGENTA)
	col.add_child(title)
	var title2 := UI.label("PRIME", 120, Neon.CYAN)
	col.add_child(title2)
	var tagline := UI.label("уклоняйся  •  выживай  •  свети", 26, Neon.PURPLE)
	col.add_child(tagline)
	col.add_child(_spacer(1.6))

	var play := UI.button("ИГРАТЬ", Neon.CYAN, 64, 170)
	play.pressed.connect(_on_play)
	col.add_child(play)
	var pulse := play.create_tween().set_loops()
	pulse.tween_property(play, "modulate", Color(1.25, 1.25, 1.25), 0.8).set_trans(Tween.TRANS_SINE)
	pulse.tween_property(play, "modulate", Color.WHITE, 0.8).set_trans(Tween.TRANS_SINE)

	col.add_child(_spacer(0.25))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)
	col.add_child(row)
	var settings_btn := UI.button("НАСТРОЙКИ", Neon.PURPLE, 24, 110)
	settings_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	settings_btn.pressed.connect(_open_settings)
	row.add_child(settings_btn)
	var upgrades_btn := UI.button("ПРОКАЧКА", Neon.GOLD, 24, 110)
	upgrades_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	upgrades_btn.pressed.connect(_open_upgrades)
	row.add_child(upgrades_btn)
	var leaders_btn := UI.button("ЛИДЕРЫ", Neon.MAGENTA, 24, 110)
	leaders_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	leaders_btn.pressed.connect(_open_leaderboard)
	row.add_child(leaders_btn)


func _spacer(ratio: float) -> Control:
	var c := Control.new()
	c.size_flags_vertical = Control.SIZE_EXPAND_FILL
	c.size_flags_stretch_ratio = ratio
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return c


func _refresh_header() -> void:
	coins_label.text = "МОНЕТЫ %d" % GameData.coins
	best_label.text = "РЕКОРД %d" % GameData.best_score


func _on_play() -> void:
	get_tree().change_scene_to_file("res://scenes/game.tscn")


func _close_overlay() -> void:
	if _overlay:
		_overlay.queue_free()
		_overlay = null


func _open(color: Color, title: String) -> VBoxContainer:
	_close_overlay()
	var parts := UI.overlay(ui_root, color)
	_overlay = parts[0]
	var vb: VBoxContainer = parts[1]
	vb.add_child(UI.label(title, 52, color))
	return vb


func _back_button(vb: VBoxContainer) -> void:
	var back := UI.button("НАЗАД", Neon.MAGENTA, 32, 96)
	back.pressed.connect(_close_overlay)
	vb.add_child(back)


# --- Settings -------------------------------------------------------------

func _open_settings() -> void:
	var vb := _open(Neon.PURPLE, "НАСТРОЙКИ")

	vb.add_child(UI.label("Имя в рейтинге", 26, Neon.CYAN, HORIZONTAL_ALIGNMENT_LEFT))
	var name_edit := LineEdit.new()
	name_edit.text = str(GameData.settings["player_name"])
	name_edit.max_length = 14
	name_edit.custom_minimum_size = Vector2(0, 76)
	name_edit.add_theme_font_size_override("font_size", 32)
	name_edit.add_theme_color_override("font_color", Color.WHITE)
	name_edit.add_theme_stylebox_override("normal", UI.box(Neon.CYAN, 0.0, 14, 2, 6))
	name_edit.add_theme_stylebox_override("focus", UI.box(Neon.MAGENTA, 0.0, 14, 2, 10))
	name_edit.text_changed.connect(func(t: String):
		var clean := t.strip_edges()
		GameData.set_setting("player_name", clean if clean != "" else "Игрок"))
	vb.add_child(name_edit)

	_slider_row(vb, "Звуки", "sfx_volume", Neon.CYAN)
	_slider_row(vb, "Музыка", "music_volume", Neon.MAGENTA)
	_slider_row(vb, "Чувствительность свайпа", "swipe_sensitivity", Neon.GOLD)
	_toggle_row(vb, "Вибрация", "vibration")
	_toggle_row(vb, "Неоновое свечение", "glow")
	_toggle_row(vb, "Показывать FPS", "show_fps")

	var reset := UI.button("СБРОСИТЬ ПРОГРЕСС", Neon.RED, 26, 80)
	var armed := [false]
	reset.pressed.connect(func():
		if not armed[0]:
			armed[0] = true
			reset.text = "ТОЧНО? НАЖМИ ЕЩЁ РАЗ"
		else:
			GameData.reset_progress()
			reset.text = "ПРОГРЕСС СБРОШЕН"
			reset.disabled = true
			_refresh_header())
	vb.add_child(reset)
	_back_button(vb)


func _slider_row(vb: VBoxContainer, title: String, key: String, color: Color) -> void:
	vb.add_child(UI.label(title, 26, color, HORIZONTAL_ALIGNMENT_LEFT))
	var s := UI.slider(float(GameData.settings[key]), color)
	s.value_changed.connect(func(v: float): GameData.set_setting(key, v))
	if key == "sfx_volume":
		s.drag_ended.connect(func(_changed): Sfx.play("move"))
	vb.add_child(s)


func _toggle_row(vb: VBoxContainer, title: String, key: String) -> void:
	var row := HBoxContainer.new()
	var l := UI.label(title, 28, Neon.CYAN, HORIZONTAL_ALIGNMENT_LEFT)
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(l)
	var t := UI.toggle(bool(GameData.settings[key]), Neon.CYAN)
	t.toggled.connect(func(on: bool):
		Sfx.play("click")
		GameData.set_setting(key, on))
	row.add_child(t)
	vb.add_child(row)


# --- Upgrades -------------------------------------------------------------

func _open_upgrades() -> void:
	var vb := _open(Neon.GOLD, "ПРОКАЧКА")
	var wallet := UI.label("", 34, Neon.GOLD)
	vb.add_child(wallet)
	var rows := VBoxContainer.new()
	rows.add_theme_constant_override("separation", 18)
	vb.add_child(rows)

	var refresh := func(): pass
	refresh = func():
		wallet.text = "Монеты: %d" % GameData.coins
		for c in rows.get_children():
			c.queue_free()
		for id in GameData.UPGRADES.keys():
			rows.add_child(_upgrade_row(id, refresh))
	refresh.call()
	vb.add_child(UI.label("Монеты собираются на трассе", 22, Neon.PURPLE))
	_back_button(vb)


func _upgrade_row(id: String, refresh: Callable) -> Control:
	var info: Dictionary = GameData.UPGRADES[id]
	var color: Color = info["color"]
	var lvl: int = GameData.upgrades[id]
	var card := PanelContainer.new()
	var s := UI.box(color, 0.0, 18, 2, 6)
	card.add_theme_stylebox_override("panel", s)
	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 14)
	card.add_child(hb)
	var text := VBoxContainer.new()
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text.add_theme_constant_override("separation", 4)
	hb.add_child(text)
	text.add_child(UI.label(info["title"], 30, color, HORIZONTAL_ALIGNMENT_LEFT))
	var desc := UI.label(info["desc"], 20, Color(0.75, 0.75, 0.9), HORIZONTAL_ALIGNMENT_LEFT)
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc.custom_minimum_size = Vector2(300, 0)
	text.add_child(desc)
	var pips := HBoxContainer.new()
	pips.add_theme_constant_override("separation", 6)
	text.add_child(pips)
	for i in GameData.MAX_UPGRADE_LEVEL:
		var pip := Panel.new()
		pip.custom_minimum_size = Vector2(34, 14)
		var ps := UI.box(color, 0.0, 4, 2, 6 if i < lvl else 0)
		ps.bg_color = Color(color, 0.95 if i < lvl else 0.08)
		pip.add_theme_stylebox_override("panel", ps)
		pips.add_child(pip)

	var cost := GameData.upgrade_cost(id)
	var buy := UI.button("МАКС" if cost < 0 else "%d" % cost, color, 26, 84)
	buy.custom_minimum_size = Vector2(150, 84)
	buy.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	buy.disabled = cost < 0 or GameData.coins < cost
	buy.pressed.connect(func():
		if GameData.buy_upgrade(id):
			Sfx.play("buy")
			refresh.call())
	hb.add_child(buy)
	return card


# --- Leaderboard ----------------------------------------------------------

func _open_leaderboard() -> void:
	var vb := _open(Neon.MAGENTA, "ЛИДЕРЫ")
	if GameData.leaderboard.is_empty():
		vb.add_child(UI.label("Пока нет результатов.\nСыграй первую игру!", 30, Neon.CYAN))
	else:
		var list := VBoxContainer.new()
		list.add_theme_constant_override("separation", 8)
		vb.add_child(list)
		var medal := [Neon.GOLD, Color(0.8, 0.85, 1.0), Neon.ORANGE]
		for i in GameData.leaderboard.size():
			var e: Dictionary = GameData.leaderboard[i]
			var color: Color = medal[i] if i < 3 else Neon.CYAN
			var row := HBoxContainer.new()
			row.add_theme_constant_override("separation", 12)
			var place := UI.label("%d." % (i + 1), 30, color, HORIZONTAL_ALIGNMENT_LEFT)
			place.custom_minimum_size = Vector2(60, 0)
			row.add_child(place)
			var n := UI.label(str(e.get("name", "?")), 30, color, HORIZONTAL_ALIGNMENT_LEFT)
			n.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			n.clip_text = true
			row.add_child(n)
			row.add_child(UI.label(str(e.get("score", 0)), 30, color, HORIZONTAL_ALIGNMENT_RIGHT))
			list.add_child(row)
	vb.add_child(UI.label("Игр сыграно: %d" % GameData.games_played, 22, Neon.PURPLE))
	_back_button(vb)
