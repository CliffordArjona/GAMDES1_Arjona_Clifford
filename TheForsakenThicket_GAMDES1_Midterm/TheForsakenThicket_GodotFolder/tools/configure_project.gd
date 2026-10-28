extends SceneTree
## One-off: writes the project settings (autoloads, input map, display, layers).
## Run:  godot --headless --path . -s tools/configure_project.gd

func _key(code: int) -> InputEventKey:
	var e := InputEventKey.new()
	e.physical_keycode = code
	return e

func _mouse(btn: int) -> InputEventMouseButton:
	var e := InputEventMouseButton.new()
	e.button_index = btn
	return e

func _action(name: String, events: Array) -> void:
	ProjectSettings.set_setting("input/" + name, {"deadzone": 0.2, "events": events})

func _init() -> void:
	ProjectSettings.set_setting("application/config/name", "The Forsaken Thicket")
	ProjectSettings.set_setting("application/config/description", "GAMDES1 prototype - AG ARC Interactive")
	ProjectSettings.set_setting("application/run/main_scene", "res://scences/main.tscn")
	# (re-add in order: Settings first, because Sfx reads it)
	for n in ["GameState", "Sfx", "Settings", "SaveGame"]:
		ProjectSettings.set_setting("autoload/" + n, null)
	ProjectSettings.set_setting("autoload/Settings", "*res://scripts/settings.gd")
	ProjectSettings.set_setting("autoload/GameState", "*res://scripts/game_state.gd")
	ProjectSettings.set_setting("autoload/Sfx", "*res://scripts/sfx.gd")
	ProjectSettings.set_setting("autoload/SaveGame", "*res://scripts/save_game.gd")
	# pixel font for every Label / Button
	ProjectSettings.set_setting("gui/theme/custom_font", "res://resources/pixel_font.res")
	ProjectSettings.set_setting("gui/theme/default_font_size", 22)
	# window + pixel art
	ProjectSettings.set_setting("display/window/size/viewport_width", 1152)
	ProjectSettings.set_setting("display/window/size/viewport_height", 648)
	ProjectSettings.set_setting("display/window/stretch/mode", "canvas_items")
	ProjectSettings.set_setting("display/window/stretch/aspect", "expand")
	ProjectSettings.set_setting("rendering/textures/canvas_textures/default_texture_filter", 0)
	ProjectSettings.set_setting("rendering/renderer/rendering_method", "gl_compatibility")
	ProjectSettings.set_setting("rendering/renderer/rendering_method.mobile", "gl_compatibility")
	ProjectSettings.set_setting("rendering/environment/defaults/default_clear_color", Color(0.05, 0.1, 0.07))
	# physics layer names
	var names := ["world", "player", "enemy", "interact", "player_attack", "enemy_attack", "enemy_hurtbox", "player_hurtbox", "low_wall"]
	for i in names.size():
		ProjectSettings.set_setting("layer_names/2d_physics/layer_%d" % (i + 1), names[i])
	# input map
	_action("move_up", [_key(KEY_W), _key(KEY_UP)])
	_action("move_down", [_key(KEY_S), _key(KEY_DOWN)])
	_action("move_left", [_key(KEY_A), _key(KEY_LEFT)])
	_action("move_right", [_key(KEY_D), _key(KEY_RIGHT)])
	_action("attack", [_key(KEY_SPACE), _mouse(MOUSE_BUTTON_LEFT)])
	_action("skill", [_key(KEY_Q), _mouse(MOUSE_BUTTON_RIGHT)])
	_action("dodge", [_key(KEY_SHIFT)])
	_action("interact", [_key(KEY_E)])
	_action("potion_health", [_key(KEY_1)])
	_action("potion_mana", [_key(KEY_2)])
	var err := ProjectSettings.save()
	print("project saved: ", err)
	quit()
