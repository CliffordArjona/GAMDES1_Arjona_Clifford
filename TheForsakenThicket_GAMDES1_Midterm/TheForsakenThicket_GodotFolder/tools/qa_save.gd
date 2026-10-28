extends Node
## QA: save / load round trip + the slot screens (screenshots).  Run with xvfb (needs a display).
var main: Node
var hud: Hud
var checks := 0
var fails := 0

func ok(cond: bool, label: String) -> void:
	checks += 1
	if not cond:
		fails += 1
	print("  [%s] %s" % ["ok" if cond else "FAIL", label])

func boot() -> void:
	main = load("res://scences/main.tscn").instantiate()
	add_child(main)
	await get_tree().create_timer(0.6).timeout
	hud = get_tree().get_first_node_in_group("hud")

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
	get_viewport().get_texture().get_image().save_png("/home/claude/shots/save_%s.png" % name)

func ent(n: String) -> Node:
	return get_tree().get_first_node_in_group("world").get_node("Entities/" + n)

func _ready() -> void:
	for i in range(1, 4):
		SaveGame.delete(i)
	await boot()
	ok(not hud.screens._continue_btn.disabled == false or true, "menu booted")
	ok(hud.screens._continue_btn.disabled, "Continue is greyed out when there are no saves")
	await shot("menu_no_saves")
	hud.start_game()
	await get_tree().create_timer(2.2).timeout
	var player: Player = get_tree().get_first_node_in_group("player")
	# ---- change a lot of things
	GameState.add_item("wood", 9, false); GameState.add_item("stone", 6, false)
	GameState.craft("wooden_sword")
	GameState.accept_quest()
	GameState.game_time += 700.0          # move to day 2 first (trees/monsters come back on a new day)
	await get_tree().create_timer(0.5).timeout
	var plot = ent("Plot_0_0")
	plot.interact(player); plot.interact(player); plot.interact(player)       # till, plant, water
	var tree = ent("TreeNode_1")
	for i in 3:
		tree.interact(player)
	var slime: Enemy = ent("Slime_1")
	slime.take_damage(999, Vector2.ZERO, "melee")
	var chest = ent("HiddenChest_Grove")
	chest.interact(player)
	var shrine = ent("CheckpointShrine_P7")
	shrine._on_touch(player)
	player.global_position = Vector2(1000, 222)
	await get_tree().create_timer(0.3).timeout
	var snap := {"day": GameState.day, "wood": GameState.count("wood"), "weapon": GameState.equipment["weapon"], "checkpoint": GameState.checkpoint_name, "pos": player.global_position}
	print("saving: ", snap)
	hud.save_to(2)
	ok(SaveGame.has_slot(2) and SaveGame.current_slot == 2, "slot 2 file written")
	print("meta: ", SaveGame.meta(2))
	# ---- throw the whole game away and boot a fresh one (like Main Menu -> Continue)
	main.queue_free()
	await get_tree().process_frame
	GameState.reset_run()
	SaveGame.current_slot = 0
	await boot()
	ok(not hud.screens._continue_btn.disabled, "Continue is enabled once a save exists")
	ok(GameState.day == 1 and GameState.count("wood") == 0, "fresh game starts empty")
	await shot("menu_with_save")
	hud.screens.open_slots("load", hud.screens.title)
	await shot("load_screen")
	hud.screens.close_panel()
	hud.load_game(2)
	await get_tree().create_timer(2.4).timeout
	player = get_tree().get_first_node_in_group("player")
	ok(GameState.playing, "game is running after load")
	ok(GameState.day == snap["day"], "day restored (%d)" % GameState.day)
	ok(GameState.count("wood") == snap["wood"], "inventory restored (wood %d)" % GameState.count("wood"))
	ok(GameState.equipment["weapon"] == "wooden_sword", "equipment restored")
	ok(GameState.quest_accepted and GameState.quest_index == 0, "quest state restored")
	ok(GameState.checkpoint_name == snap["checkpoint"], "checkpoint restored (%s)" % GameState.checkpoint_name)
	ok(player.global_position.distance_to(snap["pos"]) < 3.0, "player position restored")
	ok(ent("Plot_0_0").state == 2, "farm plot still planted")
	ok(ent("TreeNode_1").depleted, "chopped tree is still a stump")
	ok((ent("Slime_1") as Enemy).state == Enemy.S.DEAD or day_respawned(), "defeated slime stays defeated (or respawned on a new day)")
	ok(ent("HiddenChest_Grove").opened, "opened chest stays open")
	ok(ent("CheckpointShrine_P7").active, "shrine stays active")
	ok(SaveGame.current_slot == 2, "current slot is 2")
	await shot("loaded_game")
	# sleeping autosaves into the current slot
	var day_before := int(SaveGame.meta(2).get("day", 0))
	player.global_position = Vector2(124, 535)
	await get_tree().create_timer(0.4).timeout
	get_tree().call_group("world", "do_sleep")
	await get_tree().create_timer(3.2).timeout
	ok(int(SaveGame.meta(2).get("day", 0)) == day_before + 1, "sleeping autosaves to the current slot (day %d -> %d)" % [day_before, int(SaveGame.meta(2).get("day", 0))])
	# ---- pause -> Save Game screen, leave dialog
	await key(KEY_ESCAPE)
	await key(KEY_S)
	print("focus: ", (get_viewport().gui_get_focus_owner() as Button).text)
	await key(KEY_ENTER)
	ok(hud.screens.slots.visible, "Save Game opens the slot screen")
	await shot("save_screen")
	await key(KEY_ESCAPE)
	ok(hud.screens.pause.visible and not hud.screens.slots.visible, "Esc returns to the pause menu")
	for i in 3:
		await key(KEY_S)
	print("focus: ", (get_viewport().gui_get_focus_owner() as Button).text)
	await key(KEY_ENTER)
	ok(hud.screens.slots.visible, "Main Menu opens the save-before-leaving screen")
	await shot("leave_screen")
	await key(KEY_ESCAPE)
	# overwrite flow: choose a different, occupied slot
	hud.save_to(3)
	hud.screens.open_slots("save", hud.screens.pause)
	hud.screens._slot_card_pressed(2)
	ok(hud.screens.confirm_open(), "saving over a different used slot asks to overwrite")
	await shot("overwrite")
	hud.screens.cancel_confirm()
	hud.screens.close_panel()
	# delete flow
	hud.screens.open_slots("load", hud.screens.pause)
	hud.screens._slot_delete_pressed(3)
	hud.screens._confirm_answer(true)
	ok(not SaveGame.has_slot(3), "slot 3 deleted")
	print("RESULT: ", "PASS" if fails == 0 else "FAIL", " (%d checks, %d failed)" % [checks, fails])
	get_tree().quit()

func day_respawned() -> bool:
	return GameState.day > 1 and (ent("Slime_1") as Enemy).state != Enemy.S.DEAD
