extends Node
## QA: drives the game with real key events and captures screenshots of every UI screen.
var player: Player
var hud: Hud

func key(code: int, shifted: bool = false) -> void:
	for pressed in [true, false]:
		var e := InputEventKey.new()
		e.keycode = code
		e.physical_keycode = code
		e.pressed = pressed
		Input.parse_input_event(e)
		await get_tree().process_frame
		await get_tree().physics_frame
	await get_tree().create_timer(0.35).timeout

func shot(name: String) -> void:
	await get_tree().create_timer(0.25).timeout
	get_viewport().get_texture().get_image().save_png("/home/claude/shots/ui_%s.png" % name)
	print("shot ", name)

func _ready() -> void:
	var main: Node = load("res://scences/main.tscn").instantiate()
	add_child(main)
	await get_tree().create_timer(0.6).timeout
	hud = get_tree().get_first_node_in_group("hud")
	player = get_tree().get_first_node_in_group("player")
	# --- title: Enter starts the game (real key)
	await key(KEY_ENTER)
	print("playing after Enter: ", GameState.playing)
	await shot("hud")
	# --- controls via pause
	await key(KEY_ESCAPE)
	print("paused: ", get_tree().paused)
	await shot("pause")
	await key(KEY_ESCAPE)
	print("paused after 2nd Esc: ", get_tree().paused)
	# --- talk to the NPC with E
	player.global_position = Vector2(528, 545)
	await get_tree().create_timer(0.5).timeout
	await key(KEY_E)
	print("dialogue open: ", hud.dialogue.is_open())
	await shot("dialogue")
	for i in 6:
		await key(KEY_E)
		await key(KEY_E)
	print("dialogue open after advancing: ", hud.dialogue.is_open(), " accepted=", GameState.quest_accepted)
	await shot("quest_tracker")
	# --- status window (Tab) with some gear
	GameState.add_item("wood", 6, false)
	GameState.add_item("stone", 4, false)
	GameState.add_item("gumamela", 3, false)
	GameState.add_item("slime_gel", 3, false)
	GameState.add_item("wolf_fang", 2, false)
	await key(KEY_TAB)
	print("status visible: ", hud.status.visible)
	await shot("status")
	await key(KEY_TAB)
	# --- bench (E near the bench) and craft
	player.global_position = Vector2(392, 630)
	await get_tree().create_timer(0.5).timeout
	await key(KEY_E)
	print("craft visible: ", hud.craft.visible)
	await shot("craft")
	await key(KEY_ENTER)   # craft the wooden sword
	print("weapon: ", GameState.equipment["weapon"])
	await shot("craft2")
	await key(KEY_ESCAPE)
	print("craft visible after Esc: ", hud.craft.visible)
	# --- sleep in the bed
	GameState.damage_player(40)
	player.global_position = Vector2(124, 535)
	await get_tree().create_timer(0.5).timeout
	await key(KEY_E)
	await get_tree().create_timer(1.0).timeout
	await shot("sleep")
	await get_tree().create_timer(2.5).timeout
	print("after sleep: hp=", GameState.hp, " day=", GameState.day)
	# --- death flow
	GameState.add_item("wood", 3, true)
	GameState.damage_player(999)
	await get_tree().create_timer(2.6).timeout
	await shot("death")
	await get_tree().create_timer(3.0).timeout
	print("after respawn: hp=", GameState.hp, " pos=", player.global_position, " state=", player.state, " deaths=", GameState.deaths)
	# --- victory screen
	GameState.win_game()
	await get_tree().create_timer(2.5).timeout
	await shot("victory")
	get_tree().quit()
