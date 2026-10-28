extends CanvasLayer
class_name Hud
## The whole user interface: HP/MP bars, day clock, quest tracker, inventory strip,
## action bar, interaction prompt, toasts, boss bar, dialogue, crafting, status
## window, pause menu, title, death and victory screens.

const ICON := "res://assets/generated/icons/"

var root: Control
var screens: Screens
var dialogue: DialogueBox
var craft: CraftMenu
var status: StatusPanel

var hp_bar: ProgressBar
var hp_label: Label
var mp_bar: ProgressBar
var mp_label: Label
var day_label: Label
var clock_label: Label
var day_bar: ProgressBar
var zone_label: Label
var quest_panel: PanelContainer
var quest_title: Label
var quest_body: VBoxContainer
var res_labels: Dictionary = {}
var pot_labels: Dictionary = {}
var prompt_panel: PanelContainer
var prompt_label: Label
var toast_box: VBoxContainer
var zone_banner: Label
var boss_panel: PanelContainer
var boss_bar: ProgressBar
var boss_name: Label
var skill_label: Label

var _paused := false
var _toast_last := ""
var _toast_last_t := 0.0


func _ready() -> void:
	layer = 10
	process_mode = Node.PROCESS_MODE_ALWAYS
	add_to_group("hud")
	root = Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)
	_build_top()
	_build_bottom()
	_build_center()
	dialogue = DialogueBox.new()
	root.add_child(dialogue)
	craft = CraftMenu.new()
	root.add_child(craft)
	status = StatusPanel.new()
	root.add_child(status)
	screens = Screens.new()
	add_child(screens)
	_connect_signals()
	_refresh_all()
	root.visible = false          # the HUD appears when Play is pressed
	screens.show_title()


func _connect_signals() -> void:
	GameState.stats_changed.connect(_refresh_stats)
	GameState.inventory_changed.connect(_refresh_inventory)
	GameState.equipment_changed.connect(_refresh_stats)
	GameState.quest_changed.connect(_refresh_quest)
	GameState.recipes_changed.connect(_refresh_quest)
	GameState.message.connect(_on_message)
	GameState.prompt_changed.connect(_on_prompt)
	GameState.zone_changed.connect(_on_zone)
	GameState.dialogue_requested.connect(func(who, lines, cb): dialogue.open(who, lines, cb))
	GameState.craft_menu_requested.connect(func(): craft.open())
	GameState.game_won.connect(_on_won)
	screens.resume_pressed.connect(func(): set_paused(false))
	screens.quit_pressed.connect(_exit_game)
	screens.title_pressed.connect(_go_title)
	screens.restart_pressed.connect(func(): _restart())
	screens.play_pressed.connect(start_game)
	screens.slot_chosen.connect(_on_slot_chosen)
	screens.leave_without_saving.connect(_on_leave_without_saving)


# ------------------------------------------------------------------ layout
func _build_top() -> void:
	var top := HBoxContainer.new()
	top.set_anchors_preset(Control.PRESET_TOP_WIDE)
	top.offset_left = 12
	top.offset_right = -12
	top.offset_top = 10
	top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(top)
	# --- bars (top-left)
	var left := UIKit.panel()
	left.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	top.add_child(left)
	var lv := VBoxContainer.new()
	lv.add_theme_constant_override("separation", 5)
	left.add_child(lv)
	var r1 := HBoxContainer.new()
	r1.add_child(UIKit.icon(ICON + "hud_hp.png", 24))
	hp_bar = UIKit.bar(Color(0.85, 0.2, 0.25), 230, 20)
	hp_label = UIKit.label("", 13, Color.WHITE, true)
	hp_label.set_anchors_preset(Control.PRESET_FULL_RECT)
	hp_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hp_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	hp_bar.add_child(hp_label)
	r1.add_child(hp_bar)
	lv.add_child(r1)
	var r2 := HBoxContainer.new()
	r2.add_child(UIKit.icon(ICON + "hud_mp.png", 24))
	mp_bar = UIKit.bar(Color(0.25, 0.45, 0.95), 230, 20)
	mp_label = UIKit.label("", 13, Color.WHITE, true)
	mp_label.set_anchors_preset(Control.PRESET_FULL_RECT)
	mp_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	mp_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	mp_bar.add_child(mp_label)
	r2.add_child(mp_bar)
	lv.add_child(r2)
	var r3 := HBoxContainer.new()
	r3.add_child(UIKit.key_cap("TAB"))
	r3.add_child(UIKit.label(" / ", 11, UIKit.COL_DIM))
	r3.add_child(UIKit.key_cap("C"))
	r3.add_child(UIKit.label("  Status", 12, UIKit.COL_DIM))
	lv.add_child(r3)
	# --- spacer
	var sp := Control.new()
	sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sp.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top.add_child(sp)
	# --- day + quest (top-right)
	var right := VBoxContainer.new()
	right.add_theme_constant_override("separation", 8)
	right.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top.add_child(right)
	var dp := UIKit.panel()
	dp.custom_minimum_size = Vector2(250, 0)
	right.add_child(dp)
	var dv := VBoxContainer.new()
	dp.add_child(dv)
	var dr := HBoxContainer.new()
	day_label = UIKit.label("Day 1", 18, UIKit.COL_GOLD)
	dr.add_child(day_label)
	var dsp := Control.new()
	dsp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	dr.add_child(dsp)
	clock_label = UIKit.label("06:00", 16, UIKit.COL_TEXT)
	dr.add_child(clock_label)
	dv.add_child(dr)
	day_bar = UIKit.bar(Color(0.95, 0.75, 0.3), 100, 6)
	dv.add_child(day_bar)
	zone_label = UIKit.label("", 13, UIKit.COL_DIM)
	dv.add_child(zone_label)
	quest_panel = UIKit.panel()
	quest_panel.custom_minimum_size = Vector2(250, 0)
	right.add_child(quest_panel)
	var qv := VBoxContainer.new()
	quest_panel.add_child(qv)
	quest_title = UIKit.label("Quest", 15, UIKit.COL_GOLD)
	qv.add_child(quest_title)
	quest_body = VBoxContainer.new()
	qv.add_child(quest_body)


func _build_bottom() -> void:
	var bottom := HBoxContainer.new()
	bottom.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	bottom.offset_left = 12
	bottom.offset_right = -12
	bottom.offset_bottom = -10
	bottom.offset_top = -64
	bottom.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bottom.alignment = BoxContainer.ALIGNMENT_BEGIN
	root.add_child(bottom)
	# --- resources (bottom-left)
	var rp := UIKit.panel()
	rp.size_flags_vertical = Control.SIZE_SHRINK_END
	bottom.add_child(rp)
	var rh := HBoxContainer.new()
	rh.add_theme_constant_override("separation", 12)
	rp.add_child(rh)
	for id in GameState.HUD_RESOURCES:
		var h := HBoxContainer.new()
		h.add_child(UIKit.icon(GameState.ITEMS[id]["icon"], 26))
		var l := UIKit.label("0", 16, UIKit.COL_TEXT)
		h.add_child(l)
		res_labels[id] = l
		rh.add_child(h)
	var sp1 := Control.new()
	sp1.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sp1.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bottom.add_child(sp1)
	# --- action bar (bottom-right)
	var ap := UIKit.panel()
	ap.size_flags_vertical = Control.SIZE_SHRINK_END
	bottom.add_child(ap)
	var ah := HBoxContainer.new()
	ah.add_theme_constant_override("separation", 14)
	ap.add_child(ah)
	_slot(ah, "hud_attack.png", "Space")
	skill_label = _slot(ah, "hud_skill.png", "Q", "%d MP" % int(GameState.SKILL_COST))
	_slot(ah, "hud_dodge.png", "Shift")
	pot_labels["health_potion"] = _slot(ah, "potion_health.png", "1", "x0")
	pot_labels["mana_potion"] = _slot(ah, "potion_mana.png", "2", "x0")


func _slot(parent: Control, icon_file: String, key: String, extra: String = "") -> Label:
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 0)
	v.add_child(UIKit.icon(ICON + icon_file, 28))
	var k := UIKit.key_cap(key)
	k.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	v.add_child(k)
	var l := UIKit.label(extra, 11, UIKit.COL_DIM)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	if extra != "":
		v.add_child(l)
	parent.add_child(v)
	return l


func _build_center() -> void:
	# interaction prompt
	var pc := CenterContainer.new()
	pc.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	pc.offset_bottom = -118
	pc.offset_top = -160
	pc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(pc)
	prompt_panel = UIKit.panel(Color(0.08, 0.07, 0.1, 0.92))
	prompt_panel.visible = false
	pc.add_child(prompt_panel)
	var ph := HBoxContainer.new()
	prompt_panel.add_child(ph)
	ph.add_child(UIKit.key_cap("E"))
	prompt_label = UIKit.label("", 17, UIKit.COL_TEXT)
	ph.add_child(prompt_label)
	# toasts
	var tc := CenterContainer.new()
	tc.set_anchors_preset(Control.PRESET_TOP_WIDE)
	tc.offset_top = 118
	tc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(tc)
	toast_box = VBoxContainer.new()
	toast_box.add_theme_constant_override("separation", 4)
	toast_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tc.add_child(toast_box)
	# zone banner
	zone_banner = UIKit.label("", 40, UIKit.COL_GOLD, true)
	zone_banner.set_anchors_preset(Control.PRESET_TOP_WIDE)
	zone_banner.offset_top = 56
	zone_banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	zone_banner.modulate.a = 0.0
	zone_banner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(zone_banner)
	# boss bar
	var bc := CenterContainer.new()
	bc.set_anchors_preset(Control.PRESET_TOP_WIDE)
	bc.offset_top = 12
	bc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(bc)
	boss_panel = UIKit.panel()
	boss_panel.visible = false
	bc.add_child(boss_panel)
	var bv := VBoxContainer.new()
	boss_panel.add_child(bv)
	boss_name = UIKit.label("The Warden  -  Mini-Boss (stands in for Benizaurus)", 14, UIKit.COL_GOLD)
	boss_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	bv.add_child(boss_name)
	boss_bar = UIKit.bar(Color(0.8, 0.2, 0.3), 420, 16)
	bv.add_child(boss_bar)


# ------------------------------------------------------------------ refresh
func _refresh_all() -> void:
	_refresh_stats()
	_refresh_inventory()
	_refresh_quest()


func _refresh_stats() -> void:
	hp_bar.max_value = GameState.max_hp()
	hp_bar.value = GameState.hp
	hp_label.text = "%d / %d" % [GameState.hp, GameState.max_hp()]
	mp_bar.max_value = GameState.max_mp()
	mp_bar.value = GameState.mp
	mp_label.text = "%d / %d" % [int(GameState.mp), int(GameState.max_mp())]
	if status and status.visible:
		status._refresh()


func _refresh_inventory() -> void:
	for id in res_labels:
		res_labels[id].text = str(GameState.count(id))
	for id in pot_labels:
		pot_labels[id].text = "x%d" % GameState.count(id)


func _refresh_quest() -> void:
	for c in quest_body.get_children():
		c.queue_free()
	var q := GameState.current_quest()
	if q.is_empty():
		quest_title.text = "Objective"
		var done := GameState.boss_dead
		quest_body.add_child(UIKit.label("Reach the Escape Gate!" if done else "Defeat the Warden in the arena.", 14, UIKit.COL_TEXT))
		return
	if not GameState.quest_accepted:
		quest_title.text = "Quest"
		quest_body.add_child(UIKit.label("Talk to Lola Pacita at the ranch.", 14, UIKit.COL_TEXT))
		return
	quest_title.text = q["title"]
	var ready := GameState.can_afford(q["need"])
	for id in q["need"]:
		var need: int = q["need"][id]
		var have := mini(GameState.count(id), need)
		var row := HBoxContainer.new()
		row.add_child(UIKit.icon(GameState.ITEMS[id]["icon"], 20))
		row.add_child(UIKit.label(" %s  %d / %d" % [GameState.ITEMS[id]["name"], have, need], 14, UIKit.COL_GOOD if have >= need else UIKit.COL_TEXT))
		quest_body.add_child(row)
	if ready:
		quest_body.add_child(UIKit.label("Return to Lola Pacita!", 14, UIKit.COL_GOLD))


func _process(delta: float) -> void:
	if GameState.playing:
		day_label.text = "Day %d" % GameState.day
		clock_label.text = GameState.time_text()
		day_bar.max_value = GameState.DAY_LENGTH
		day_bar.value = fmod(GameState.game_time, GameState.DAY_LENGTH)
	zone_label.text = GameState.player_zone
	# keep quest rows in sync with the inventory (cheap)
	if GameState.quest_accepted and not GameState.current_quest().is_empty():
		_refresh_quest_if_needed()
	skill_label.add_theme_color_override("font_color", UIKit.COL_TEXT if GameState.mp >= GameState.SKILL_COST else UIKit.COL_BAD)
	# boss bar
	var boss := get_tree().get_first_node_in_group("boss")
	var show_boss: bool = boss != null and boss.state != Enemy.S.DEAD and GameState.player_zone == "Mini-Boss Arena" and GameState.playing
	boss_panel.visible = show_boss
	if show_boss:
		boss_bar.max_value = boss.max_hp
		boss_bar.value = boss.hp


var _quest_sig := ""
func _refresh_quest_if_needed() -> void:
	var q := GameState.current_quest()
	var sig := ""
	for id in q["need"]:
		sig += "%s%d," % [id, GameState.count(id)]
	if sig != _quest_sig:
		_quest_sig = sig
		_refresh_quest()


# ------------------------------------------------------------------ toasts / prompt / zones
func _on_message(text: String, kind: String) -> void:
	var now := Time.get_ticks_msec() / 1000.0
	if text == _toast_last and now - _toast_last_t < 1.2:
		return
	_toast_last = text
	_toast_last_t = now
	while toast_box.get_child_count() >= 4:
		toast_box.get_child(0).queue_free()
		toast_box.remove_child(toast_box.get_child(0))
	var color := UIKit.COL_TEXT
	match kind:
		"good": color = UIKit.COL_GOOD
		"warn": color = UIKit.COL_BAD
		"pickup": color = UIKit.COL_GOLD
	var p := UIKit.panel(Color(0.07, 0.06, 0.09, 0.85))
	p.add_child(UIKit.label(text, 15, color))
	toast_box.add_child(p)
	var tw := p.create_tween()
	tw.tween_interval(2.6 if kind != "pickup" else 1.4)
	tw.tween_property(p, "modulate:a", 0.0, 0.6)
	tw.tween_callback(p.queue_free)


func _on_prompt(text: String) -> void:
	prompt_panel.visible = text != ""
	prompt_label.text = "  " + text


func _on_zone(zone_name: String) -> void:
	if zone_name == "":
		return
	zone_banner.text = zone_name
	var tw := create_tween()
	tw.tween_property(zone_banner, "modulate:a", 1.0, 0.4)
	tw.tween_interval(1.6)
	tw.tween_property(zone_banner, "modulate:a", 0.0, 0.8)


# ------------------------------------------------------------------ game flow
var _starting := false

func start_game() -> void:
	if GameState.playing or _starting:
		return
	_starting = true
	SaveGame.current_slot = 0          # a brand new game: the first save will ask for a slot
	Sfx.play("ui_click")
	await screens.fade_to(1.0, 0.45)
	screens.title.visible = false
	for p in [screens.controls, screens.options, screens.credits, screens.slots, screens.confirm]:
		p.visible = false
	root.visible = true
	GameState.playing = true
	GameState.input_block_until = Engine.get_physics_frames() + 15
	get_tree().call_group("world", "on_game_started")     # the world fades back in ("you wake up")
	_refresh_all()
	_starting = false


## Continue -> load a slot: restore GameState, then put every saved object back in the world.
func load_game(slot: int) -> void:
	if GameState.playing or _starting:
		return
	var data := SaveGame.read(slot)
	if data.is_empty():
		GameState.toast("That save could not be read.", "warn")
		return
	_starting = true
	Sfx.play("ui_click")
	await screens.fade_to(1.0, 0.45)
	screens.title.visible = false
	for p in [screens.controls, screens.options, screens.credits, screens.slots, screens.confirm]:
		p.visible = false
	GameState.apply_save(data["state"])
	root.visible = true
	GameState.playing = true
	GameState.input_block_until = Engine.get_physics_frames() + 15
	var world := get_tree().get_first_node_in_group("world")
	world.apply_save(data["world"])
	SaveGame.current_slot = slot
	world.on_game_started()
	_refresh_all()
	_starting = false
	GameState.toast("Loaded Slot %d." % slot, "good")


func save_to(slot: int) -> bool:
	var world := get_tree().get_first_node_in_group("world")
	var ok := SaveGame.save(slot, world.capture_save())
	if ok:
		Sfx.play("quest", -4)
		GameState.toast("Game saved to Slot %d." % slot, "good")
	else:
		Sfx.play("ui_deny")
		GameState.toast("Could not save the game!", "warn")
	return ok


func _on_slot_chosen(mode: String, slot: int) -> void:
	match mode:
		"load":
			load_game(slot)
		"save":
			if save_to(slot):
				screens.close_panel()
		"leave_title":
			if save_to(slot):
				await get_tree().create_timer(0.6, true, false, true).timeout
				_go_title()
		"leave_exit":
			if save_to(slot):
				await get_tree().create_timer(0.6, true, false, true).timeout
				_exit_game()


func _on_leave_without_saving(mode: String) -> void:
	if mode == "leave_title":
		_go_title()
	else:
		_exit_game()


func _pause_info() -> String:
	var q := GameState.current_quest()
	var goal: String = "Defeat the Warden."
	if not q.is_empty():
		goal = ("Quest: " + String(q["title"])) if GameState.quest_accepted else "Talk to Lola Pacita."
	return "Day %d   -   %s\n%s" % [GameState.day, GameState.player_zone, goal]


func set_paused(on: bool) -> void:
	_paused = on
	get_tree().paused = on
	screens.set_paused(on, _pause_info() if on else "")
	if on:
		GameState.open_ui()
	else:
		GameState.close_ui()
	Sfx.play("ui_click", -6)


func _go_title() -> void:
	## back to the main menu (the scene is reloaded, so everything starts fresh)
	get_tree().paused = false
	await screens.fade_to(1.0, 0.4)
	_restart()


func _exit_game() -> void:
	Settings.save_settings()
	get_tree().quit()


func _restart() -> void:
	get_tree().paused = false
	SaveGame.current_slot = 0
	GameState.reset_run()
	Sfx.stop_music()
	get_tree().reload_current_scene()


func _on_won() -> void:
	Sfx.play("win")
	await get_tree().create_timer(0.6).timeout
	await screens.fade_to(0.8, 0.8)
	screens.show_victory()
	await screens.fade_to(0.0, 0.5)


func fade_to(alpha: float, time: float) -> Signal:
	return screens.fade_to(alpha, time)


# ------------------------------------------------------------------ input
func _nav(step: int) -> void:
	## W / S move the keyboard focus through menu buttons (arrow keys already work)
	var f := get_viewport().gui_get_focus_owner()
	if f == null:
		return
	var n: Control = f.find_next_valid_focus() if step > 0 else f.find_prev_valid_focus()
	if n:
		n.grab_focus()


func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey and event.pressed and not event.echo):
		return
	var k: Key = event.keycode
	if k == KEY_F11:
		Settings.toggle_fullscreen()
		screens.sync_options()
		return
	if k == KEY_M:
		Sfx.toggle_mute()
		screens.update_mute_label()
		return
	var menu_up: bool = screens.title.visible or _paused
	# --- confirmation dialog sits on top of everything
	if screens.confirm_open():
		if k == KEY_ESCAPE:
			screens.cancel_confirm()
		elif k == KEY_W:
			_nav(-1)
		elif k == KEY_S:
			_nav(1)
		get_viewport().set_input_as_handled()
		return
	# --- main menu (and its sub-panels, which hide the menu itself while open)
	if not GameState.playing:
		if screens.panel_open():
			if k == KEY_ESCAPE:
				screens.close_panel()
			elif k == KEY_W:
				_nav(-1)
			elif k == KEY_S:
				_nav(1)
		else:
			if k == KEY_W:
				_nav(-1)
			elif k == KEY_S:
				_nav(1)
			elif (k == KEY_ENTER or k == KEY_KP_ENTER or k == KEY_SPACE) and get_viewport().gui_get_focus_owner() == null:
				start_game()      # fallback when no button has keyboard focus
		get_viewport().set_input_as_handled()
		return
	if screens.victory.visible or screens.death.visible:
		if screens.victory.visible and (k == KEY_W or k == KEY_S):
			_nav(-1 if k == KEY_W else 1)
		return
	# --- dialogue
	if dialogue.is_open():
		if k == KEY_E or k == KEY_ENTER or k == KEY_KP_ENTER or k == KEY_SPACE:
			dialogue.advance()
		get_viewport().set_input_as_handled()
		return
	# --- crafting
	if craft.visible:
		craft.handle_key(event)
		get_viewport().set_input_as_handled()
		return
	# --- status window
	if status.visible:
		if k == KEY_TAB or k == KEY_C or k == KEY_ESCAPE:
			status.close()
		get_viewport().set_input_as_handled()
		return
	# --- pause menu
	if _paused:
		if k == KEY_ESCAPE:
			if screens.panel_open():
				screens.close_panel()
			else:
				set_paused(false)
		elif k == KEY_W:
			_nav(-1)
		elif k == KEY_S:
			_nav(1)
		get_viewport().set_input_as_handled()
		return
	if not GameState.playing:
		return
	if k == KEY_ESCAPE:
		set_paused(true)
	elif k == KEY_TAB or k == KEY_C:
		status.open()
	get_viewport().set_input_as_handled()
