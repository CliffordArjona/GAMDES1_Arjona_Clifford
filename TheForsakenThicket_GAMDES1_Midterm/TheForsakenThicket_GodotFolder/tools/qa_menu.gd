extends Node
## QA: screenshots of the main menu, sub-panels, pause menu and confirmation dialogs (real key events).
var hud: Hud

func key(code: int) -> void:
	for pressed in [true, false]:
		var e := InputEventKey.new()
		e.keycode = code
		e.physical_keycode = code
		e.pressed = pressed
		Input.parse_input_event(e)
		await get_tree().process_frame
		await get_tree().physics_frame
	await get_tree().create_timer(0.3).timeout

func shot(name: String) -> void:
	await get_tree().create_timer(0.3).timeout
	get_viewport().get_texture().get_image().save_png("/home/claude/shots/menu_%s.png" % name)
	print("shot ", name)

func st() -> String:
	var sc: Screens = hud.screens
	return "playing=%s title=%s controls=%s options=%s credits=%s confirm=%s pause=%s focus=%s" % [GameState.playing, sc.title.visible, sc.controls.visible, sc.options.visible, sc.credits.visible, sc.confirm.visible, sc.pause.visible, focus_text()]

func focus_text() -> String:
	var f := get_viewport().gui_get_focus_owner()
	return (f as Button).text if f is Button else str(f)

func _ready() -> void:
	var main: Node = load("res://scences/main.tscn").instantiate()
	add_child(main)
	await get_tree().create_timer(1.0).timeout
	hud = get_tree().get_first_node_in_group("hud")
	print("focus at start: ", focus_text())
	await shot("main")
	await get_tree().create_timer(14.0).timeout
	await shot("main_later")
	# W/S navigation
	await key(KEY_S)
	await key(KEY_S)
	print("focus after S,S: ", focus_text())
	print("before enter: ", st())
	await key(KEY_ENTER)          # Options
	print("after enter: ", st())
	print("options visible: ", hud.screens.options.visible)
	await shot("options")
	await key(KEY_ESCAPE)
	print("after esc: ", st())
	print("options closed: ", not hud.screens.options.visible, " menu visible: ", hud.screens.title.visible)
	await key(KEY_S)
	await key(KEY_ENTER)          # Credits
	await shot("credits")
	await key(KEY_ESCAPE)
	await key(KEY_W)
	await key(KEY_W)
	await key(KEY_ENTER)          # How to play
	print("controls visible: ", hud.screens.controls.visible)
	await shot("controls")
	await key(KEY_ESCAPE)
	# Exit game -> confirm -> Cancel
	for i in 3:
		await key(KEY_S)
	print("focus before exit: ", focus_text())
	await key(KEY_ENTER)
	print("confirm open: ", hud.screens.confirm_open())
	await shot("exit_confirm")
	await key(KEY_ESCAPE)
	print("confirm closed: ", not hud.screens.confirm_open())
	# New Game
	print("focus after cancel: ", focus_text())
	for i in 4:
		await key(KEY_W)
	print("focus before play: ", focus_text())
	await key(KEY_ENTER)
	await get_tree().create_timer(2.2).timeout
	print("playing: ", GameState.playing, " menu hidden: ", not hud.screens.title.visible)
	await shot("ingame")
	# pause menu
	await key(KEY_ESCAPE)
	print("paused: ", get_tree().paused, " focus: ", focus_text())
	await shot("pause")
	await key(KEY_S)
	await key(KEY_ENTER)          # Options from pause
	await shot("pause_options")
	await key(KEY_ESCAPE)
	print("back at pause: ", hud.screens.pause.visible)
	# Main Menu -> confirm
	print("focus after options back: ", focus_text())
	for i in 2:
		await key(KEY_S)
	await key(KEY_ENTER)
	await shot("pause_confirm")
	await key(KEY_ESCAPE)
	await key(KEY_ESCAPE)
	print("resumed: ", not get_tree().paused)
	get_tree().quit()
