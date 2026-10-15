extends Control
## Корневой узел: переключает экраны, показывает всплывающие сообщения.

const UI := preload("res://scripts/ui/ui.gd")

var screen: Control = null
var _layer: Control
var _toasts: VBoxContainer
const MAX_TOASTS := 3


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
	_toasts = UI.vbox(6)
	_toasts.anchor_left = 0.5
	_toasts.anchor_right = 0.5
	_toasts.offset_left = -280
	_toasts.offset_right = 280
	_toasts.offset_top = 96
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
	CrashLog.set_screen(name)
	var s: Control = load(path).new()
	UI.full(s)
	_layer.add_child(s)
	screen = s


## Короткое сообщение сверху. kind: info, good (золотая рамка), bad (красная).
## Одновременно не больше 3, одинаковые не дублируются.
func toast(text: String, kind: String = "info") -> void:
	for ch in _toasts.get_children():
		if ch.has_meta("text") and ch.get_meta("text") == text and not ch.is_queued_for_deletion():
			return
	while _toasts.get_child_count() >= MAX_TOASTS:
		var old := _toasts.get_child(0)
		_toasts.remove_child(old)
		old.queue_free()
	var border: Color = {"good": UI.GOLD, "bad": UI.RED}.get(kind, UI.PANEL3)
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", UI.style(Color(0.09, 0.07, 0.12, 0.94), 0, border, 3, 10))
	p.set_meta("text", text)
	var l := UI.label(text, 20, UI.GOLD if kind == "good" else UI.TEXT, HORIZONTAL_ALIGNMENT_CENTER)
	p.add_child(l)
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_toasts.add_child(p)
	p.modulate.a = 0.0
	var tw := p.create_tween()
	tw.tween_property(p, "modulate:a", 1.0, 0.12)
	tw.tween_interval(2.0 if kind == "info" else 2.6)
	tw.tween_property(p, "modulate:a", 0.0, 0.35)
	tw.tween_callback(p.queue_free)


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST or what == NOTIFICATION_APPLICATION_PAUSED:
		Game.save_run()
		Game.save_meta()
