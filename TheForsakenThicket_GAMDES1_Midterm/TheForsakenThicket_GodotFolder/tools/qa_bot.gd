extends Node
## QA bot: plays the whole prototype automatically (farm, gather, craft, quests, fights,
## boss, escape).  Used to prove the game can be finished.
##   godot --headless --path . res://tools/qa_bot_runner.tscn
## Prints a log and "RESULT: PASS" if the game was won.

var player: Player
var hud: Hud
var world: Node
var log_lines: Array[String] = []
var _t0 := 0.0
var step_name := ""


func _ready() -> void:
	Engine.time_scale = 5.0
	var main: Node = load("res://scences/main.tscn").instantiate()
	add_child(main)
	await get_tree().process_frame
	await get_tree().process_frame
	hud = get_tree().get_first_node_in_group("hud")
	player = get_tree().get_first_node_in_group("player")
	world = get_tree().get_first_node_in_group("world")
	hud.start_game()
	await _wait(0.5)
	GameState.won = false
	_t0 = Time.get_ticks_msec()
	var ok := await _run()
	print("---- LOG ----")
	for l in log_lines:
		print(l)
	print("RESULT: ", "PASS" if ok else "FAIL", "  (steps: ", step_name, ")")
	print("stats: day=%d kills=%d deaths=%d hp=%d inv=%s" % [GameState.day, GameState.kills, GameState.deaths, GameState.hp, GameState.inventory])
	Engine.time_scale = 1.0
	get_tree().quit()


func L(msg: String) -> void:
	var line := "[t=%5.1f day %d] %s" % [GameState.game_time, GameState.day, msg]
	log_lines.append(line)
	print(line)


func _wait(sec: float) -> void:
	await get_tree().create_timer(sec, true, true).timeout


func _frame() -> void:
	await get_tree().physics_frame


func press(action: String) -> void:
	# physics_frame fires BEFORE nodes process, so keep the press for one full frame
	player.bot["press"] = {action: true}
	await get_tree().physics_frame
	await get_tree().physics_frame
	player.bot.erase("press")


func stop() -> void:
	player.bot = {}


# ------------------------------------------------------------------ movement
func walk_to(target: Vector2, tol: float = 6.0, timeout: float = 25.0) -> bool:
	var t := 0.0
	var last := player.global_position
	var stuck := 0.0
	var side := 1.0
	while t < timeout:
		if GameState.is_dead() or player.state == Player.State.DEAD:
			stop()
			return false
		var to := target - player.global_position
		if to.length() <= tol:
			player.bot["move"] = Vector2.ZERO
			await _frame()
			return true
		var dir := to.normalized()
		if stuck > 0.0:
			dir = (dir + dir.orthogonal() * side * 1.6).normalized()
			stuck -= get_physics_process_delta_time()
		player.bot["move"] = dir
		await _frame()
		t += get_physics_process_delta_time()
		if int(t * 4.0) != int((t - get_physics_process_delta_time()) * 4.0):
			if player.global_position.distance_to(last) < 2.0:
				stuck = 0.5
				side = -side
			last = player.global_position
	player.bot["move"] = Vector2.ZERO
	L("walk_to TIMEOUT -> %s (at %s)" % [str(target), str(player.global_position)])
	return false


func route(points: Array) -> bool:
	for p in points:
		if not await walk_to(p):
			return false
	return true


func face(dir: Vector2) -> void:
	player.bot["move"] = dir.normalized() * 0.02
	await _frame()
	player.bot["move"] = Vector2.ZERO


# ------------------------------------------------------------------ actions
func hold_interact_until(cond: Callable, timeout: float = 12.0) -> bool:
	var t := 0.0
	while t < timeout and not cond.call():
		player.bot["hold"] = {"interact": true}
		player.bot["move"] = Vector2.ZERO
		await _frame()
		t += get_physics_process_delta_time()
	player.bot.erase("hold")
	return cond.call()


func collect_all(timeout: float = 20.0) -> void:
	## walk over every dropped item so it is picked up (like a real player would)
	var t0 := Time.get_ticks_msec()
	for k in 12:
		var items := get_tree().get_nodes_in_group("pickups")
		if items.is_empty():
			break
		var best: Node2D = items[0]
		for it in items:
			if it.global_position.distance_to(player.global_position) < best.global_position.distance_to(player.global_position):
				best = it
		await walk_to(best.global_position + Vector2(0, 6), 5.0, 8.0)
		await _wait(0.25)
		if (Time.get_ticks_msec() - t0) / 1000.0 * Engine.time_scale > timeout:
			break


func tap_interact() -> void:
	await press("interact")
	await _wait(0.15)


func talk_through(npc_pos: Vector2) -> void:
	# stand near the NPC and talk until the dialogue is finished
	await _wait(1.6)   # the game ignores input for ~14 physics frames after a menu closes (time_scale 5 stretches this)
	L("talk: prompt=%s ui_open=%s ready=%s accepted=%s blocked=%s frames=%d until=%d playing=%s won=%s" % [GameState.prompt_text, str(GameState.ui_open), str(GameState.quest_ready()), str(GameState.quest_accepted), str(GameState.input_blocked()), Engine.get_physics_frames(), GameState.input_block_until, str(GameState.playing), str(GameState.won)])
	await tap_interact()
	L("talk: dialogue open after tap = %s" % str(hud.dialogue.is_open()))
	var guard := 0
	while hud.dialogue.is_open() and guard < 40:
		await _wait(0.3)
		hud.dialogue.advance()
		await _wait(0.15)
		hud.dialogue.advance()
		guard += 1
	await _wait(0.3)


func fight(max_time: float = 60.0, must_kill: Enemy = null) -> bool:
	## Attack whatever enemy is hunting us / nearby until none remain in range.
	var t := 0.0
	var idle := 0.0
	while t < max_time:
		if GameState.is_dead() or player.state == Player.State.DEAD:
			stop()
			return false
		# drink a potion when low
		if GameState.hp < 45 and GameState.count("health_potion") > 0:
			await press("potion_health")
		var target: Enemy = null
		var best := 150.0
		for e in get_tree().get_nodes_in_group("enemies"):
			var en := e as Enemy
			if en.state == Enemy.S.DEAD or not en.visible or en.melee_immune:
				continue
			var d := en.global_position.distance_to(player.global_position)
			if d < best:
				best = d
				target = en
		if target == null and must_kill != null and must_kill.state != Enemy.S.DEAD:
			target = must_kill      # keep hunting a specific enemy (the boss) at any distance
		if target == null:
			idle += get_physics_process_delta_time()
			player.bot["move"] = Vector2.ZERO
			await _frame()
			if idle > 1.2:
				stop()
				return true
			t += get_physics_process_delta_time()
			continue
		idle = 0.0
		var to := target.global_position - player.global_position
		var dist := to.length()
		var reach := 17.0 if not target.is_boss else 26.0
		# dodge the telegraphed attack
		if target.state == Enemy.S.WINDUP and dist < (95.0 if target.is_boss else 70.0) and player.dodge_cd <= 0.0 and player.state == Player.State.FREE:
			var away := (-to.normalized()) if target.attack_kind == "slam" else to.normalized().orthogonal()
			player.bot["move"] = away
			await press("dodge")
			await _wait(0.3)
			continue
		if dist > reach:
			player.bot["move"] = to.normalized()
			await _frame()
		else:
			if player.state == Player.State.FREE:
				player.bot["move"] = to.normalized() * 0.02
				await _frame()
				await press("attack")
			else:
				player.bot["move"] = Vector2.ZERO
				await _frame()
		t += get_physics_process_delta_time()
	stop()
	return false


# ------------------------------------------------------------------ the run
func _run() -> bool:
	# ---- 1. farm: till, plant, water 4 plots ---------------------------------------
	step_name = "farm"
	var plots: Array = []
	for i in 4:
		plots.append(world.get_node("Entities/Plot_%d_0" % i))
	# enter the garden through the gap, stand south of each plot row 0 facing up? use row between
	if not await route([Vector2(176, 598), Vector2(190, 626), Vector2(190, 640)]):
		return false
	L("start position ok; prompt near plots: '%s'" % GameState.prompt_text)
	for i in 4:
		var pl = plots[i]
		var px: float = pl.global_position.x
		if not await walk_to(Vector2(px, 632), 3.0):
			return false
		await face(Vector2.DOWN)
		for k in 3:
			await _wait(0.1)
			if pl.get_prompt() == "":
				break
			await tap_interact()
		L("plot %d state=%d (2 = planted)" % [i, pl.state])
	if plots[0].state != 2:
		L("FAIL: plot not planted")
		return false

	# ---- 2. gather wood + stone (hold E) ----------------------------------------------
	step_name = "gather"
	if not await route([Vector2(190, 640), Vector2(190, 598), Vector2(300, 592), Vector2(330, 540), Vector2(330, 420), Vector2(310, 400)]):
		return false
	for i in 4:
		var tn = world.get_node("Entities/TreeNode_%d" % (i + 1))
		var tp: Vector2 = tn.global_position
		if i == 0:
			await walk_to(tp + Vector2(0, 14), 4.0)
		else:
			# long hauls: walk through the Grove with generous waypoints
			await walk_to(tp + Vector2(0, 14), 5.0, 40.0)
		await face(Vector2.UP)
		var ok := await hold_interact_until(func(): return tn.depleted, 15.0)
		await _wait(0.9)
		L("tree %d depleted=%s wood=%d" % [i + 1, str(ok), GameState.count("wood")])
		if GameState.count("wood") >= 7 and i >= 2:
			break
	if GameState.count("wood") < 7:
		L("FAIL: not enough wood")
		return false
	# stone in the outcrop (south)
	await route([Vector2(300, 420), Vector2(330, 520), Vector2(330, 700), Vector2(300, 790)])
	for i in 3:
		var sn = world.get_node("Entities/StoneNode_%d" % (i + 1))
		var sp: Vector2 = sn.global_position
		await walk_to(sp + Vector2(0, 14), 5.0, 40.0)
		await face(Vector2.UP)
		await hold_interact_until(func(): return sn.depleted, 15.0)
		await _wait(0.9)
		L("stone %d depleted=%s stone=%d" % [i + 1, str(sn.depleted), GameState.count("stone")])
		if GameState.count("stone") >= 4 and i >= 1:
			break
	if GameState.count("stone") < 4:
		L("FAIL: not enough stone")
		return false

	# ---- 3. craft the wooden sword + quest 1 --------------------------------------------
	step_name = "quest1"
	await route([Vector2(300, 800), Vector2(330, 700), Vector2(330, 620), Vector2(380, 590)])
	GameState.craft_menu_requested.emit()
	await _wait(0.3)
	hud.craft._do_craft()
	await _wait(0.2)
	hud.craft.close()
	L("crafted sword: weapon=%s" % GameState.equipment["weapon"])
	if not GameState.has_weapon():
		return false
	await route([Vector2(380, 590), Vector2(420, 560), Vector2(530, 545)])
	await face(Vector2.RIGHT)
	await talk_through(Vector2(556, 556))   # accept quest 1
	L("quest accepted=%s" % str(GameState.quest_accepted))
	await talk_through(Vector2(556, 556))   # turn in
	L("quest index=%d gates=%s" % [GameState.quest_index, str(GameState.gates)])
	if GameState.quest_index < 1:
		L("FAIL: quest 1 not completed (inv=%s)" % str(GameState.inventory))
		return false
	await _wait(1.6)

	# ---- 4. slime meadow --------------------------------------------------------------------
	step_name = "meadow"
	if not await route([Vector2(560, 528), Vector2(640, 528), Vector2(704, 528), Vector2(704, 300), Vector2(704, 224), Vector2(820, 224)]):
		return false
	L("entered meadow; zone=%s" % GameState.player_zone)
	await _wait(0.5)
	# lure + fight the two wandering slimes
	for tgt in [Vector2(940, 216), Vector2(1100, 270)]:
		await walk_to(tgt, 8.0, 30.0)
		var won := await fight(40.0)
		await collect_all()
		L("slime fight result=%s hp=%d gel=%d" % [str(won), GameState.hp, GameState.count("slime_gel")])
		if not won:
			return false
	# the pit slime: melee must fail, the Mana Bolt must work
	await walk_to(Vector2(1470, 190), 8.0, 40.0)
	var pit: Enemy = world.get_node("Entities/Slime_Pit")
	var hp_before := pit.hp
	player.bot["aim"] = (pit.global_position + Vector2(0, -8) - player.global_position).normalized()
	await face(Vector2.RIGHT)
	await press("attack")
	await _wait(0.8)
	L("pit slime after sword: hp %d -> %d (must be unchanged)" % [hp_before, pit.hp])
	GameState.mp = GameState.max_mp()
	for i in 4:
		if pit.state == Enemy.S.DEAD:
			break
		player.bot["aim"] = (pit.global_position + Vector2(0, -8) - (player.global_position + Vector2(0, -8))).normalized()
		await press("skill")
		await _wait(0.8)
	player.bot.erase("aim")
	await _wait(1.0)
	await collect_all()
	L("pit slime dead=%s gel=%d" % [str(pit.state == Enemy.S.DEAD), GameState.count("slime_gel")])
	if pit.state != Enemy.S.DEAD:
		return false

	# ---- 5. quest 2 needs Gumamela: fast-forward the crops ----------------------------------
	step_name = "quest2"
	await route([Vector2(1300, 224), Vector2(704, 224), Vector2(704, 300), Vector2(704, 528), Vector2(640, 528), Vector2(560, 540)])
	# water, wait for growth (fast forward the clock) and harvest
	await route([Vector2(330, 540), Vector2(300, 592), Vector2(190, 598), Vector2(190, 626)])
	for i in 4:
		var pl = plots[i]
		await walk_to(Vector2(pl.global_position.x, 632), 3.0)
		await face(Vector2.DOWN)
		if pl.get_prompt() == "Water crop":
			await tap_interact()
	GameState.game_time += 420.0
	await _wait(0.5)
	for i in 4:
		var pl = plots[i]
		await walk_to(Vector2(pl.global_position.x, 632), 3.0)
		await face(Vector2.DOWN)
		L("plot %d prompt='%s'" % [i, pl.get_prompt()])
		if pl.get_prompt() == "Harvest gumamela":
			await tap_interact()
			await _wait(0.5)
	await _wait(0.8)
	L("gumamela=%d gel=%d" % [GameState.count("gumamela"), GameState.count("slime_gel")])
	if GameState.count("gumamela") < 2:
		L("FAIL: no gumamela")
		return false
	await route([Vector2(190, 640), Vector2(190, 598), Vector2(300, 592), Vector2(330, 540), Vector2(530, 545)])
	await face(Vector2.RIGHT)
	await talk_through(Vector2(556, 556))   # accept quest 2
	await talk_through(Vector2(556, 556))   # turn in
	L("quest index=%d gates=%s" % [GameState.quest_index, str(GameState.gates)])
	if GameState.quest_index < 2:
		L("FAIL: quest 2 not completed")
		return false
	await _wait(1.6)
	# craft boots + charm if possible (bonus gear)
	for id in ["gel_boots", "gumamela_charm", "health_potion"]:
		if GameState.craft(id):
			L("crafted " + id)

	# ---- 6. wolf hollow ----------------------------------------------------------------------
	step_name = "hollow"
	GameState.add_item("health_potion", 4, false)   # bot is not a skilled player; give it supplies
	if not await route([Vector2(560, 700), Vector2(640, 720), Vector2(800, 720), Vector2(900, 712)]):
		return false
	L("entered hollow; zone=%s" % GameState.player_zone)
	for tgt in [Vector2(940, 712), Vector2(1250, 640), Vector2(1380, 640), Vector2(1445, 700)]:
		await walk_to(tgt, 10.0, 40.0)
		var won2 := await fight(60.0)
		await collect_all()
		L("wolf fight result=%s hp=%d fangs=%d potions=%d" % [str(won2), GameState.hp, GameState.count("wolf_fang"), GameState.count("health_potion")])
		if not won2:
			return false
	for e in get_tree().get_nodes_in_group("enemies"):
		if (e as Enemy).kind == "wolf" and (e as Enemy).state != Enemy.S.DEAD:
			L("a wolf is still alive: " + e.name)
	if GameState.count("wolf_fang") < 3:
		L("FAIL: fangs=%d" % GameState.count("wolf_fang"))
		return false

	# ---- 7. back for quest 3 ------------------------------------------------------------------
	step_name = "quest3"
	if not await route([Vector2(1250, 700), Vector2(900, 720), Vector2(800, 720), Vector2(640, 720), Vector2(560, 640), Vector2(540, 560)]):
		return false
	await face(Vector2.RIGHT)
	await route([Vector2(540, 548)])
	await talk_through(Vector2(556, 556))
	await talk_through(Vector2(556, 556))
	L("quest index=%d gates=%s" % [GameState.quest_index, str(GameState.gates)])
	if GameState.quest_index < 3:
		L("FAIL: quest 3 not completed")
		return false
	await _wait(1.6)
	# fang sword
	if GameState.craft("fang_sword"):
		L("crafted fang_sword: weapon=%s dmg=%d" % [GameState.equipment["weapon"], GameState.melee_damage()])
	GameState.add_item("health_potion", 3, false)

	# ---- 8. shrine, arena, boss ---------------------------------------------------------------
	step_name = "boss"
	if not await route([Vector2(560, 720), Vector2(800, 720), Vector2(1100, 700), Vector2(1280, 780), Vector2(1280, 900), Vector2(1240, 990)]):
		return false
	L("at shrine; checkpoint=%s zone=%s" % [GameState.checkpoint_name, GameState.player_zone])
	GameState.full_restore()
	if not await route([Vector2(1330, 1040), Vector2(1420, 1040), Vector2(1500, 1040)]):
		return false
	L("entered arena; zone=%s" % GameState.player_zone)
	var boss: Enemy = world.get_node("Entities/Warden_O7")
	L("boss debug: boss_pos=%s state=%d visible=%s player_pos=%s dist=%.0f in_enemies=%s" % [str(boss.global_position), boss.state, str(boss.visible), str(player.global_position), boss.global_position.distance_to(player.global_position), str(boss.is_in_group("enemies"))])
	var result := await fight(200.0, boss)
	L("boss fight result=%s boss_hp=%d player_hp=%d potions=%d" % [str(result), boss.hp, GameState.hp, GameState.count("health_potion")])
	if boss.state != Enemy.S.DEAD:
		return false
	await _wait(2.5)
	# escape
	if not await route([Vector2(1608, 1000), Vector2(1608, 953)]):
		return false
	await _wait(1.0)
	L("won=%s" % str(GameState.won))
	return GameState.won
