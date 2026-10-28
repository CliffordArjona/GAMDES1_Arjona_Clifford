extends Node
## Settings (Autoload) - player options that are remembered between runs
## (volume, fullscreen).  Stored in user://settings.cfg.  This is NOT a game save:
## the GDD cuts the save system for the prototype (Section 1.4).

signal changed

const PATH := "user://settings.cfg"

var music := 0.8         # 0..1
var sfx := 0.9           # 0..1
var fullscreen := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	load_settings()
	apply()


func load_settings() -> void:
	var cf := ConfigFile.new()
	if cf.load(PATH) != OK:
		return
	music = clampf(float(cf.get_value("audio", "music", music)), 0.0, 1.0)
	sfx = clampf(float(cf.get_value("audio", "sfx", sfx)), 0.0, 1.0)
	fullscreen = bool(cf.get_value("video", "fullscreen", fullscreen))


func save_settings() -> void:
	var cf := ConfigFile.new()
	cf.set_value("audio", "music", music)
	cf.set_value("audio", "sfx", sfx)
	cf.set_value("video", "fullscreen", fullscreen)
	cf.save(PATH)


func apply() -> void:
	if DisplayServer.get_name() != "headless":
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN if fullscreen else DisplayServer.WINDOW_MODE_WINDOWED)
	changed.emit()


func set_music(v: float) -> void:
	music = clampf(v, 0.0, 1.0)
	changed.emit()

func set_sfx(v: float) -> void:
	sfx = clampf(v, 0.0, 1.0)
	changed.emit()

func set_fullscreen(on: bool) -> void:
	fullscreen = on
	apply()

func toggle_fullscreen() -> void:
	set_fullscreen(not fullscreen)
	save_settings()
