extends Node
## Журнал для поиска падений на телефоне.
##
## Пока игра работает, в user://crash/session.log построчно (с немедленной записью
## на диск) пишутся: сведения о телефоне, смена экранов, все ошибки движка и скриптов,
## и раз в полсекунды «пульс» (время, FPS, память). Если игра упадёт, журнал
## останется целым до последней строки.
##
## При следующем запуске игра замечает, что прошлый сеанс не закончился нормально,
## собирает отчёт, кладёт его в папку «Загрузки» телефона и показывает в меню
## окно с кнопкой «Скопировать отчёт».

const DIR := "user://crash"
const SESSION := "user://crash/session.log"
const PREVIOUS := "user://crash/previous.log"
const RUNNING := "user://crash/running.flag"
const BEAT := 0.5
const REPORT_LINES := 400

var crashed_last_time := false
var report := ""          # отчёт о прошлом падении
var report_path := ""     # куда он сохранён на телефоне
var report_shown := false

var _file: FileAccess
var _mutex := Mutex.new()
var _writing := false
var _t0 := 0
var _beat := 0.0
var _screen := ""
var _paused := false


class GameLogger extends Logger:
	var sink: Object

	func _log_error(function: String, file: String, line: int, code: String, rationale: String,
			_editor_notify: bool, error_type: int, script_backtraces: Array[ScriptBacktrace]) -> void:
		var kinds := ["ERROR", "WARNING", "SCRIPT ERROR", "SHADER ERROR"]
		var kind: String = kinds[error_type] if error_type >= 0 and error_type < kinds.size() else "ERROR"
		var text := "%s: %s" % [kind, rationale if rationale != "" else code]
		if code != "" and rationale != "":
			text += " [" + code + "]"
		text += " (%s:%d %s)" % [file, line, function]
		for bt in script_backtraces:
			if bt != null:
				text += "\n" + bt.format()
		sink.write(text)

	func _log_message(message: String, error: bool) -> void:
		sink.write(("stderr: " if error else "") + message.strip_edges())


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_t0 = Time.get_ticks_msec()
	DirAccess.make_dir_recursive_absolute(DIR)
	if FileAccess.file_exists(RUNNING) and FileAccess.file_exists(SESSION):
		_collect_previous()
	_file = FileAccess.open(SESSION, FileAccess.WRITE)
	_mark_running(true)
	write("=== Я — подземелье, запуск %s ===" % Time.get_datetime_string_from_system(false, true))
	write(device_info())
	var logger := GameLogger.new()
	logger.sink = self
	OS.add_logger(logger)


func _process(delta: float) -> void:
	_beat += delta
	if _beat < BEAT:
		return
	_beat = 0.0
	write("пульс: fps=%d память=%.1f МБ видео=%.1f МБ объектов=%d узлов=%d экран=%s" % [
		Engine.get_frames_per_second(),
		OS.get_static_memory_usage() / 1048576.0,
		Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED) / 1048576.0,
		Performance.get_monitor(Performance.OBJECT_COUNT),
		Performance.get_monitor(Performance.OBJECT_NODE_COUNT),
		_screen,
	])


## Отметка важного шага (смена экрана, запуск музыки и т.п.).
func event(text: String) -> void:
	write("> " + text)


func set_screen(name: String) -> void:
	_screen = name
	event("экран " + name)


## Запись строки в журнал. Потокобезопасна: Logger может звать её из любого потока.
func write(text: String) -> void:
	_mutex.lock()
	if _writing or _file == null:
		_mutex.unlock()
		return
	_writing = true
	var t := (Time.get_ticks_msec() - _t0) / 1000.0
	_file.store_line("[%7.2f] %s" % [t, text])
	_file.flush()
	_writing = false
	_mutex.unlock()


func device_info() -> String:
	var lines := []
	lines.append("Игра: версия %s, Godot %s" % [
		ProjectSettings.get_setting("application/config/version", "?"), Engine.get_version_info().string])
	lines.append("Устройство: %s, %s %s" % [OS.get_model_name(), OS.get_name(), OS.get_version()])
	lines.append("Процессор: %s, ядер %d, архитектура %s" % [
		OS.get_processor_name(), OS.get_processor_count(), Engine.get_architecture_name()])
	lines.append("Видео: %s / %s, API %s" % [
		RenderingServer.get_video_adapter_name(), RenderingServer.get_video_adapter_vendor(),
		RenderingServer.get_video_adapter_api_version()])
	lines.append("Отрисовка: %s (%s)" % [
		RenderingServer.get_current_rendering_method(), RenderingServer.get_current_rendering_driver_name()])
	lines.append("Экран: %s, окно %s, язык %s" % [
		DisplayServer.screen_get_size(), DisplayServer.window_get_size(), OS.get_locale()])
	return "\n".join(lines)


# ---------------------------------------------------------------- прошлое падение

func _collect_previous() -> void:
	var f := FileAccess.open(SESSION, FileAccess.READ)
	if f == null:
		return
	var lines := f.get_as_text().split("\n")
	f.close()
	if lines.size() > REPORT_LINES:
		lines = lines.slice(lines.size() - REPORT_LINES)
	var text := "ОТЧЁТ О ПАДЕНИИ «Я — подземелье»\n"
	text += "Прошлый сеанс оборвался без нормального выхода. Ниже его журнал (последние строки — момент падения).\n\n"
	text += "\n".join(lines)
	var engine_log := _engine_log_tail(60)
	if engine_log != "":
		text += "\n\n--- журнал движка ---\n" + engine_log
	report = text
	crashed_last_time = true
	var out := FileAccess.open(PREVIOUS, FileAccess.WRITE)
	if out:
		out.store_string(report)
		out.close()
	report_path = _save_public(report)


## Хвост предыдущего журнала движка (user://logs, файлы ротируются при запуске).
func _engine_log_tail(n: int) -> String:
	var dir := DirAccess.open("user://logs")
	if dir == null:
		return ""
	var files := []
	for name in dir.get_files():
		if name.ends_with(".log") and name != "godot.log":
			files.append(name)
	if files.is_empty():
		return ""
	files.sort()
	var f := FileAccess.open("user://logs/" + files[-1], FileAccess.READ)
	if f == null:
		return ""
	var lines := f.get_as_text().split("\n")
	return "\n".join(lines.slice(maxi(0, lines.size() - n)))


## Сохраняет отчёт туда, где его видно в файловом менеджере телефона.
func _save_public(text: String) -> String:
	var stamp := Time.get_datetime_string_from_system().replace(":", "-").replace("T", "_")
	var name := "ya-podzemelye-crash-%s.txt" % stamp
	for d in [OS.get_system_dir(OS.SYSTEM_DIR_DOWNLOADS), OS.get_system_dir(OS.SYSTEM_DIR_DOCUMENTS)]:
		if d == "":
			continue
		var path: String = d.path_join(name)
		var f := FileAccess.open(path, FileAccess.WRITE)
		if f:
			f.store_string(text)
			f.close()
			return path
	return ProjectSettings.globalize_path(PREVIOUS)


## Последний отчёт: прошлое падение, а если его не было — текущий сеанс.
func latest_report() -> String:
	if report != "":
		return report
	if FileAccess.file_exists(PREVIOUS):
		return FileAccess.get_file_as_string(PREVIOUS)
	return "Падений не было. Текущий сеанс:\n\n" + FileAccess.get_file_as_string(SESSION)


func copy_report() -> void:
	DisplayServer.clipboard_set(latest_report())


# ---------------------------------------------------------------- нормальный выход

func _mark_running(on: bool) -> void:
	if on:
		var f := FileAccess.open(RUNNING, FileAccess.WRITE)
		if f:
			f.store_string(str(Time.get_unix_time_from_system()))
			f.close()
	elif FileAccess.file_exists(RUNNING):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(RUNNING))


func _notification(what: int) -> void:
	match what:
		NOTIFICATION_WM_CLOSE_REQUEST, NOTIFICATION_PREDELETE:
			write("=== нормальный выход ===")
			_mark_running(false)
		NOTIFICATION_APPLICATION_PAUSED:
			# Свёрнутую игру Android может закрыть без предупреждения — это не падение.
			_paused = true
			write("> свёрнута")
			_mark_running(false)
		NOTIFICATION_APPLICATION_RESUMED:
			if _paused:
				_paused = false
				write("> развёрнута")
				_mark_running(true)
