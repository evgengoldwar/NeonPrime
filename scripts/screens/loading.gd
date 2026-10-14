extends Control

const UI := preload("res://scripts/ui/ui.gd")


func _ready() -> void:
	var c := CenterContainer.new()
	UI.full(c)
	add_child(c)
	var v := UI.vbox(30)
	v.custom_minimum_size = Vector2(560, 0)
	c.add_child(v)
	v.add_child(UI.title("Я —\nПОДЗЕМЕЛЬЕ", 64))
	v.add_child(UI.label("карточный рогалик", 24, UI.DIM, HORIZONTAL_ALIGNMENT_CENTER))
	var bar := ProgressBar.new()
	bar.custom_minimum_size = Vector2(0, 24)
	bar.show_percentage = false
	bar.add_theme_stylebox_override("fill", UI.style(UI.ACCENT, 8, Color.TRANSPARENT, 0, 0))
	v.add_child(bar)
	var tw := create_tween()
	tw.tween_property(bar, "value", 100.0, 1.0)
	tw.tween_callback(func(): Game.main.goto("menu"))
