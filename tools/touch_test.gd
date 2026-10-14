extends Node
## Тест касаниями: шлёт в игру InputEventScreenTouch/ScreenDrag, как Android.
## Запуск: godot --path . res://tools/touch_test.tscn

var main


func _ready() -> void:
	Game.reset_progress()
	main = load("res://scenes/main.tscn").instantiate()
	get_tree().root.add_child.call_deferred(main)
	await _wait(2.0)
	print("TOUCH: экран ", _screen())
	_shot("menu")
	await _tap_button("В БОЙ!")
	await _wait(1.0)
	print("TOUCH: экран ", _screen())
	for hall in 3:
		var scr = main.screen
		if _screen() != "battle":
			break
		var b = Game.battle
		# Перетаскиваем каждую карту руки на свободную клетку
		var guard := 0
		while b.hand.size() > 0 and guard < 6:
			guard += 1
			var free := -1
			for c in b.corridor_len:
				if b.cells[c] == null:
					free = c
					break
			if free < 0:
				break
			var card: Control = scr.hand_box.get_child(0)
			var cell: Control = scr.cell_panels[free]
			await _drag(card.get_global_rect().get_center(), cell.get_global_rect().get_center())
			await _wait(0.3)
		_shot("battle_%d" % (hall + 1))
		# Долгое нажатие на клетку (подсказка) и закрытие
		await _long_press(scr.cell_panels[0].get_global_rect().get_center())
		await _wait(0.3)
		await _tap_button("Закрыть")
		await _tap_button("ВПУСТИТЬ")
		await _wait(6.0)
		print("TOUCH: зал ", hall + 1, " фаза ", b.phase, " экран ", _screen())
		if b.phase == "done":
			await _tap_button("Дальше")
			break
	await _wait(1.0)
	print("TOUCH: конец, экран ", _screen())
	get_tree().quit()


## Скриншот в user://shots (если запущено с отрисовкой).
func _shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	if img == null:
		return
	DirAccess.make_dir_recursive_absolute("user://shots")
	img.save_png("user://shots/%s.png" % name)


func _screen() -> String:
	if main.screen == null:
		return ""
	return main.screen.get_script().resource_path.get_file().get_basename()


func _wait(sec: float) -> void:
	await get_tree().create_timer(sec).timeout


func _find_button(n: Node, text: String) -> Button:
	if n is Button and n.text == text and n.is_visible_in_tree() and not n.disabled:
		return n
	for ch in n.get_children():
		var r := _find_button(ch, text)
		if r != null:
			return r
	return null


func _tap_button(text: String) -> void:
	var b := _find_button(get_tree().root, text)
	if b == null:
		print("TOUCH: кнопка не найдена: ", text)
		return
	await _tap(b.get_global_rect().get_center())


## Координаты игры (720×1280) → координаты окна, как у настоящего касания.
func _win(pos: Vector2) -> Vector2:
	return get_viewport().get_final_transform() * pos


func _touch(pos: Vector2, pressed: bool) -> void:
	var e := InputEventScreenTouch.new()
	e.index = 0
	e.position = _win(pos)
	e.pressed = pressed
	Input.parse_input_event(e)


func _tap(pos: Vector2) -> void:
	_touch(pos, true)
	await _wait(0.08)
	_touch(pos, false)
	await _wait(0.2)


func _long_press(pos: Vector2) -> void:
	_touch(pos, true)
	await _wait(0.7)
	_touch(pos, false)
	await _wait(0.2)


func _drag(from: Vector2, to: Vector2) -> void:
	_touch(from, true)
	await _wait(0.05)
	var steps := 12
	for i in range(1, steps + 1):
		var e := InputEventScreenDrag.new()
		e.index = 0
		e.position = _win(from.lerp(to, float(i) / steps))
		e.relative = _win(to) - _win(from.lerp(to, float(i - 1) / steps))
		Input.parse_input_event(e)
		await _wait(0.02)
	_touch(to, false)
	await _wait(0.1)
