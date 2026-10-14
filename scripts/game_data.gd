extends Node
## Autoload: progress, settings, upgrades and the local leaderboard.

signal coins_changed(value: int)
signal settings_changed

const SAVE_PATH := "user://neonprime_save.cfg"
const MAX_LEADERS := 10
const MAX_UPGRADE_LEVEL := 5
## Coins are rare pickups on the track, so upgrades are priced in tens.
const UPGRADE_COSTS: Array[int] = [10, 25, 50, 90, 150]

const UPGRADES := {
	"freeze": {
		"title": "Заморозка",
		"desc": "Ворота замирают: не крутятся, не двигаются, не мигают. +1 сек за уровень",
		"color": Color(0.55, 0.85, 1.0),
	},
	"armor": {
		"title": "Броня",
		"desc": "Спасает от 1 смерти. Чаще выпадает, дольше неуязвимость",
		"color": Color(0.35, 1.0, 0.3),
	},
	"multiplier": {
		"title": "Множитель очков",
		"desc": "Умножает очки. +2 сек длительности за уровень",
		"color": Color(1.0, 0.78, 0.1),
	},
	"luck": {
		"title": "Удача",
		"desc": "Бонусы появляются чаще",
		"color": Color(1.0, 0.1, 0.85),
	},
}

var coins := 0
var best_score := 0
var games_played := 0
var settings := {
	"player_name": "Игрок",
	"sfx_volume": 0.8,
	"music_volume": 0.5,
	"vibration": true,
	"swipe_sensitivity": 0.5,
	"glow": true,
	"show_fps": false,
}
var upgrades := {"freeze": 0, "armor": 0, "multiplier": 0, "luck": 0}
## Array of {"name": String, "score": int, "date": String}, best first.
var leaderboard: Array = []
## Turned off by automated tests so they never touch the real save file.
var persist := true


func _ready() -> void:
	load_game()


# --- Effect values --------------------------------------------------------

func freeze_duration() -> float:
	return 3.0 + 1.0 * upgrades["freeze"]


func armor_weight() -> float:
	return 0.8 + 0.35 * upgrades["armor"]


func armor_invulnerability() -> float:
	return 1.2 + 0.3 * upgrades["armor"]


func multiplier_duration() -> float:
	return 6.0 + 2.0 * upgrades["multiplier"]


func pickup_interval() -> float:
	return maxf(4.0, 9.0 - 1.0 * upgrades["luck"])


# --- Upgrades -------------------------------------------------------------

func upgrade_cost(id: String) -> int:
	var lvl: int = upgrades[id]
	if lvl >= MAX_UPGRADE_LEVEL:
		return -1
	return UPGRADE_COSTS[lvl]


func buy_upgrade(id: String) -> bool:
	var cost := upgrade_cost(id)
	if cost < 0 or coins < cost:
		return false
	coins -= cost
	upgrades[id] += 1
	coins_changed.emit(coins)
	save_game()
	return true


# --- Results --------------------------------------------------------------

## Called for every coin picked up on the track.
func add_coin(amount := 1) -> void:
	coins += amount
	coins_changed.emit(coins)


## Stores a finished run (coins are already added during the run).
func submit_score(score: int) -> void:
	games_played += 1
	if score > best_score:
		best_score = score
	if score > 0:
		leaderboard.append({
			"name": str(settings["player_name"]),
			"score": score,
			"date": Time.get_date_string_from_system(),
		})
		leaderboard.sort_custom(func(a, b): return int(a["score"]) > int(b["score"]))
		if leaderboard.size() > MAX_LEADERS:
			leaderboard.resize(MAX_LEADERS)
	save_game()


func set_setting(key: String, value) -> void:
	settings[key] = value
	settings_changed.emit()
	save_game()


func reset_progress() -> void:
	coins = 0
	best_score = 0
	games_played = 0
	for k in upgrades.keys():
		upgrades[k] = 0
	leaderboard.clear()
	coins_changed.emit(coins)
	save_game()


func vibrate(ms: int) -> void:
	if settings["vibration"]:
		Input.vibrate_handheld(ms)


# --- Persistence ----------------------------------------------------------

func save_game() -> void:
	if not persist:
		return
	var cfg := ConfigFile.new()
	cfg.set_value("progress", "coins", coins)
	cfg.set_value("progress", "best_score", best_score)
	cfg.set_value("progress", "games_played", games_played)
	cfg.set_value("progress", "upgrades", upgrades)
	cfg.set_value("progress", "leaderboard", leaderboard)
	cfg.set_value("settings", "values", settings)
	cfg.save(SAVE_PATH)


func load_game() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(SAVE_PATH) != OK:
		return
	coins = int(cfg.get_value("progress", "coins", 0))
	best_score = int(cfg.get_value("progress", "best_score", 0))
	games_played = int(cfg.get_value("progress", "games_played", 0))
	var saved_upgrades: Dictionary = cfg.get_value("progress", "upgrades", {})
	for k in saved_upgrades.keys():
		if upgrades.has(k):
			upgrades[k] = clampi(int(saved_upgrades[k]), 0, MAX_UPGRADE_LEVEL)
	leaderboard = cfg.get_value("progress", "leaderboard", [])
	var saved_settings: Dictionary = cfg.get_value("settings", "values", {})
	for k in saved_settings.keys():
		if settings.has(k):
			settings[k] = saved_settings[k]
