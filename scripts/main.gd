extends Control
## Корневой узел: переключает экраны, показывает всплывающие сообщения.

const UI := preload("res://scripts/ui/ui.gd")

var screen: Control = null
var _layer: Control
var _toasts: VBoxContainer


func _ready() -> void:
	Game.main = self
	theme = UI.make_theme()
	UI.full(self)
	var bg := ColorRect.new()
	bg.color = UI.BG
	UI.full(bg)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)
	_layer = Control.new()
	UI.full(_layer)
	_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_layer)
	_toasts = UI.vbox(8)
	_toasts.position = Vector2(60, 90)
	_toasts.custom_minimum_size = Vector2(600, 0)
	_toasts.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_toasts)
	goto("loading")


func goto(name: String) -> void:
	if screen != null:
		screen.queue_free()
		screen = null
	var path := "res://scripts/screens/%s.gd" % name
	if not ResourceLoader.exists(path):
		push_error("Нет экрана " + name)
		path = "res://scripts/screens/menu.gd"
	var s: Control = load(path).new()
	UI.full(s)
	_layer.add_child(s)
	screen = s


func toast(text: String) -> void:
	var p := UI.panel(Color(0.1, 0.06, 0.16, 0.92), 12, 12, UI.ACCENT, 2)
	p.add_child(UI.label(text, 22, UI.TEXT, HORIZONTAL_ALIGNMENT_CENTER))
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_toasts.add_child(p)
	var tw := p.create_tween()
	tw.tween_interval(2.2)
	tw.tween_property(p, "modulate:a", 0.0, 0.5)
	tw.tween_callback(p.queue_free)


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST or what == NOTIFICATION_APPLICATION_PAUSED:
		Game.save_run()
		Game.save_meta()
