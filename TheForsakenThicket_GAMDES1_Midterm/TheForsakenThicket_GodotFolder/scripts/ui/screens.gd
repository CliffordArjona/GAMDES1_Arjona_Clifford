extends Control
class_name Screens
## Full-screen menus: MAIN MENU, Options, How to Play, Credits, PAUSE MENU, confirmation
## dialog, death screen and victory screen, plus the fade used for sleeping/respawning.
##
## Main menu = title logo over the live world (the camera slowly tours the zones),
## like the title screens of Terraria / Stardew Valley.

signal play_pressed          # "New Game"
signal resume_pressed        # pause menu: Resume
signal restart_pressed       # victory screen: Play again
signal title_pressed         # confirmed: go back to the main menu
signal quit_pressed          # confirmed: exit the game
signal slot_chosen(mode: String, slot: int)     # a save-slot card was chosen (mode: load / save / leave_title / leave_exit)
signal leave_without_saving(mode: String)       # "Don't save" in the leave dialogs

const LOGO := "res://assets/generated/ui/logo.png"
const VIGNETTE := "res://assets/generated/ui/vignette.png"
const FIREFLY := "res://assets/generated/ui/firefly.png"

const CONTROLS := [
	["Move", "W A S D  /  Arrow keys"],
	["Sword", "Space  /  Left click"],
	["Mana Bolt (aim with the mouse)", "Q  /  Right click"],
	["Dodge (free - no stamina)", "Shift"],
	["Interact: farm, chop, talk, craft, sleep", "E  (hold to keep chopping)"],
	["Health potion / Mana potion", "1  /  2"],
	["Status window (STR, AGI, INT)", "Tab  /  C"],
	["Pause menu  (Save Game is in here)", "Esc"],
	["Sleep in your bed = rest + autosave", "E at the bed"],
	["Mute  /  Fullscreen", "M  /  F11"],
]

const CREDITS := [
	["Game Design Document", "AG ARC Interactive - BSCS IAC2"],
	["Albino, Erin Camille", "Project Manager  /  Writer"],
	["Arjona, Clifford Xhyrus", "Game Programmer  /  Level Designer"],
	["Cauan, Nel Angelo", "Level Designer  /  Game Programmer"],
	["Galano, Laken Mai", "Game Designer  /  Composer"],
	["Ramos, Zachary Brent", "Animator  /  Level Designer"],
	["Course", "GAMDES1 - Game Design and Development"],
	["Instructor", "Erna-Kristi Martinez"],
	["Art", "Asset Pack Free + original sprites (see CREDITS.txt)"],
	["Engine", "Godot Engine 4.7"],
]

var fade_rect: ColorRect
var title: Control            # the main menu
var controls: Control
var options: Control
var credits: Control
var slots: Control
var pause: Control
var confirm: Control
var death: Control
var victory: Control

var _menu_buttons: VBoxContainer
var _logo: TextureRect
var _death_text: Label
var _victory_text: Label
var _pause_info: Label
var _confirm_text: Label
var _confirm_yes: Button
var _confirm_cb := Callable()
var _return_to: Control
var _mute_btn: Button
var _music_slider: HSlider
var _sfx_slider: HSlider
var _fs_btn: Button
var _logo_t := 0.0
var _continue_btn: Button
var _slot_mode := ""
var _slot_title: Label
var _slot_hint: Label
var _slot_rows: Array = []        # one dictionary per slot: card, del, l1, l2, l3
var _slot_footer: HBoxContainer
var _last_focus: Control
var _confirm_return: Control


func _init() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	process_mode = Node.PROCESS_MODE_ALWAYS
	# the fade is created FIRST so that every overlay (menus, death, victory ...) draws above it
	fade_rect = ColorRect.new()
	fade_rect.color = Color(0, 0, 0, 1)
	fade_rect.modulate.a = 0.0
	fade_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	fade_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(fade_rect)
	_build_main_menu()
	_build_controls()
	_build_options()
	_build_credits()
	_build_slots()
	_build_pause()
	_build_confirm()
	_build_death()
	_build_victory()


func _process(delta: float) -> void:
	if title.visible and _logo:
		_logo_t += delta
		_logo.position.y = 38.0 + sin(_logo_t * 1.6) * 3.0


# ------------------------------------------------------------------ small builders
func _overlay(alpha: float) -> Control:
	var c := Control.new()
	c.set_anchors_preset(Control.PRESET_FULL_RECT)
	var r := ColorRect.new()
	r.color = Color(0.03, 0.02, 0.05, alpha)
	r.set_anchors_preset(Control.PRESET_FULL_RECT)
	c.add_child(r)
	c.visible = false
	add_child(c)
	return c


func _centered_box(parent: Control, width: float = 460.0, sep: int = 10) -> VBoxContainer:
	var cc := CenterContainer.new()
	cc.set_anchors_preset(Control.PRESET_FULL_RECT)
	parent.add_child(cc)
	var v := VBoxContainer.new()
	v.custom_minimum_size = Vector2(width, 0)
	v.add_theme_constant_override("separation", sep)
	cc.add_child(v)
	return v


func _center_label(v: Control, text: String, size: int, color: Color, outline: bool = true) -> Label:
	var l := UIKit.label(text, size, color, outline)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(l)
	return l


func _btn(parent: Control, text: String, size: int, cb: Callable, min_h: float = 40.0) -> Button:
	var b := UIKit.button(text, size)
	b.custom_minimum_size = Vector2(0, min_h)
	b.pressed.connect(func():
		Sfx.play("ui_click", -4)
		cb.call())
	b.mouse_entered.connect(func(): if b.is_visible_in_tree(): Sfx.play("ui_click", -14))
	b.focus_entered.connect(func(): if b.is_visible_in_tree(): Sfx.play("ui_click", -14))
	parent.add_child(b)
	return b


func _panel_title(v: Control, text: String) -> void:
	_center_label(v, text, 34, UIKit.COL_GOLD)


# ------------------------------------------------------------------ MAIN MENU
func _build_main_menu() -> void:
	title = Control.new()
	title.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(title)
	# darkened edges so the live world behind stays readable but moody
	var vig := TextureRect.new()
	vig.texture = load(VIGNETTE)
	vig.set_anchors_preset(Control.PRESET_FULL_RECT)
	vig.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	vig.stretch_mode = TextureRect.STRETCH_SCALE
	vig.mouse_filter = Control.MOUSE_FILTER_IGNORE
	title.add_child(vig)
	var shade := ColorRect.new()
	shade.color = Color(0.02, 0.02, 0.05, 0.28)
	shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	title.add_child(shade)
	# drifting fireflies
	var fl := CPUParticles2D.new()
	fl.texture = load(FIREFLY)
	fl.amount = 46
	fl.lifetime = 9.0
	fl.preprocess = 9.0
	fl.position = Vector2(576, 660)
	fl.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	fl.emission_rect_extents = Vector2(620, 6)
	fl.direction = Vector2(0, -1)
	fl.spread = 28.0
	fl.gravity = Vector2.ZERO
	fl.initial_velocity_min = 14.0
	fl.initial_velocity_max = 44.0
	fl.scale_amount_min = 1.0
	fl.scale_amount_max = 2.2
	var g := Gradient.new()
	g.colors = PackedColorArray([Color(1, 1, 1, 0), Color(1, 1, 1, 1), Color(1, 1, 1, 1), Color(1, 1, 1, 0)])
	g.offsets = PackedFloat32Array([0.0, 0.2, 0.75, 1.0])
	fl.color_ramp = g
	title.add_child(fl)
	# logo
	_logo = TextureRect.new()
	_logo.texture = load(LOGO)
	_logo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_logo.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_logo.custom_minimum_size = Vector2(900, 150)
	_logo.size = Vector2(900, 150)
	_logo.position = Vector2(126, 38)
	_logo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	title.add_child(_logo)
	var sub := UIKit.label("Farm.  Gather.  Craft.  Escape the tyrant Benizaurus.", 20, Color(0.96, 0.92, 0.8), true)
	sub.set_anchors_preset(Control.PRESET_TOP_WIDE)
	sub.offset_top = 196
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub.mouse_filter = Control.MOUSE_FILTER_IGNORE
	title.add_child(sub)
	# buttons
	var cc := CenterContainer.new()
	cc.set_anchors_preset(Control.PRESET_FULL_RECT)
	cc.offset_top = 150
	cc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	title.add_child(cc)
	_menu_buttons = VBoxContainer.new()
	_menu_buttons.custom_minimum_size = Vector2(340, 0)
	_menu_buttons.add_theme_constant_override("separation", 7)
	cc.add_child(_menu_buttons)
	_continue_btn = _btn(_menu_buttons, "Continue", 24, func(): open_slots("load", title), 50)
	_btn(_menu_buttons, "New Game", 22, func(): play_pressed.emit(), 46)
	_btn(_menu_buttons, "How to Play", 19, func(): open_panel(controls, title), 38)
	_btn(_menu_buttons, "Options", 19, func(): open_panel(options, title), 38)
	_btn(_menu_buttons, "Credits", 19, func(): open_panel(credits, title), 38)
	_btn(_menu_buttons, "Exit Game", 19, func(): ask("Exit the game?", "Exit", func(): quit_pressed.emit()), 38)
	# footer
	var foot := UIKit.label("v0.1 prototype   -   AG ARC Interactive   -   GAMDES1", 13, Color(0.85, 0.82, 0.75), true)
	foot.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	foot.offset_left = 16
	foot.offset_top = -30
	foot.offset_bottom = -8
	foot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	title.add_child(foot)
	var hint := UIKit.label("W / S + Enter, or use the mouse     F11 = fullscreen", 13, Color(0.85, 0.82, 0.75), true)
	hint.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	hint.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	hint.offset_right = -16
	hint.offset_top = -30
	hint.offset_bottom = -8
	hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	title.add_child(hint)


func show_title() -> void:
	title.visible = true
	pause.visible = false
	death.visible = false
	victory.visible = false
	confirm.visible = false
	for p in [controls, options, credits, slots]:
		p.visible = false
	refresh_continue()
	focus_first_menu_button()


func refresh_continue() -> void:
	_continue_btn.disabled = not SaveGame.any_saves()


func focus_first_menu_button() -> void:
	## focus the first button that is enabled (Continue when there are saves, else New Game)
	for b in _menu_buttons.get_children():
		if b is Button and not (b as Button).disabled:
			(b as Button).grab_focus()
			return


# ------------------------------------------------------------------ sub-panels (shared by menu + pause)
func _panel_screen(width: float) -> Array:
	var root := _overlay(0.82)
	var v := _centered_box(root, width, 12)
	return [root, v]


func _build_controls() -> void:
	var a := _panel_screen(580)
	controls = a[0]
	var v: VBoxContainer = a[1]
	_panel_title(v, "How to Play")
	var p := UIKit.panel()
	v.add_child(p)
	var g := GridContainer.new()
	g.columns = 2
	g.add_theme_constant_override("h_separation", 34)
	g.add_theme_constant_override("v_separation", 8)
	p.add_child(g)
	for row in CONTROLS:
		g.add_child(UIKit.label(row[0], 15, UIKit.COL_TEXT))
		g.add_child(UIKit.label(row[1], 15, UIKit.COL_GOLD))
	_center_label(v, "Goal: farm, gather and craft to grow strong, then defeat the Warden and walk through the Escape Gate.", 13, UIKit.COL_DIM, false).autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_btn(v, "Back", 18, close_panel)


func _build_credits() -> void:
	var a := _panel_screen(600)
	credits = a[0]
	var v: VBoxContainer = a[1]
	_panel_title(v, "Credits")
	var p := UIKit.panel()
	v.add_child(p)
	var g := GridContainer.new()
	g.columns = 2
	g.add_theme_constant_override("h_separation", 30)
	g.add_theme_constant_override("v_separation", 7)
	p.add_child(g)
	for row in CREDITS:
		g.add_child(UIKit.label(row[0], 15, UIKit.COL_GOLD))
		g.add_child(UIKit.label(row[1], 15, UIKit.COL_TEXT))
	_btn(v, "Back", 18, close_panel)


func _build_options() -> void:
	var a := _panel_screen(520)
	options = a[0]
	var v: VBoxContainer = a[1]
	_panel_title(v, "Options")
	var p := UIKit.panel()
	v.add_child(p)
	var g := GridContainer.new()
	g.columns = 2
	g.add_theme_constant_override("h_separation", 24)
	g.add_theme_constant_override("v_separation", 16)
	p.add_child(g)
	g.add_child(UIKit.label("Music volume", 17, UIKit.COL_TEXT))
	_music_slider = _slider(Settings.music, func(val): Settings.set_music(val))
	g.add_child(_music_slider)
	g.add_child(UIKit.label("Sound effects", 17, UIKit.COL_TEXT))
	_sfx_slider = _slider(Settings.sfx, func(val): Settings.set_sfx(val))
	_sfx_slider.drag_ended.connect(func(_c): Sfx.play("pickup"))
	g.add_child(_sfx_slider)
	g.add_child(UIKit.label("Fullscreen  [F11]", 17, UIKit.COL_TEXT))
	_fs_btn = UIKit.button("Off", 16)
	_fs_btn.pressed.connect(func():
		Settings.set_fullscreen(not Settings.fullscreen)
		sync_options())
	g.add_child(_fs_btn)
	g.add_child(UIKit.label("Sound  [M]", 17, UIKit.COL_TEXT))
	_mute_btn = UIKit.button("On", 16)
	_mute_btn.pressed.connect(func():
		Sfx.toggle_mute()
		update_mute_label())
	g.add_child(_mute_btn)
	_btn(v, "Back", 18, close_panel)


func _slider(value: float, cb: Callable) -> HSlider:
	var s := HSlider.new()
	s.min_value = 0.0
	s.max_value = 1.0
	s.step = 0.05
	s.value = value
	s.custom_minimum_size = Vector2(250, 24)
	s.add_theme_stylebox_override("slider", UIKit.style(Color(0.16, 0.13, 0.13), Color(0.4, 0.32, 0.22), 3, 1))
	s.add_theme_stylebox_override("grabber_area", UIKit.style(Color(0.85, 0.62, 0.25), Color(0.4, 0.32, 0.22), 3, 1))
	s.add_theme_stylebox_override("grabber_area_highlight", UIKit.style(Color(1.0, 0.8, 0.4), Color(0.4, 0.32, 0.22), 3, 1))
	s.value_changed.connect(func(val): cb.call(val))
	return s


func update_mute_label() -> void:
	if _mute_btn:
		_mute_btn.text = "Off" if Sfx.muted else "On"


func sync_options() -> void:
	_music_slider.set_value_no_signal(Settings.music)
	_sfx_slider.set_value_no_signal(Settings.sfx)
	_fs_btn.text = "On" if Settings.fullscreen else "Off"
	update_mute_label()


func open_panel(panel: Control, from: Control) -> void:
	_last_focus = get_viewport().gui_get_focus_owner()     # so Back returns to the same button
	_return_to = from
	from.visible = false
	panel.visible = true
	if panel == options:
		sync_options()
	Sfx.play("ui_click", -6)
	var back := _find_back(panel)      # focus "Back" so the keyboard works
	if back:
		back.grab_focus()


func _find_back(node: Node) -> Button:
	if node is Button and (node as Button).text == "Back":
		return node
	for c in node.get_children():
		var r := _find_back(c)
		if r:
			return r
	return null


func panel_open() -> bool:
	return controls.visible or options.visible or credits.visible or slots.visible


func close_panel() -> void:
	for p in [controls, options, credits, slots]:
		if p.visible:
			p.visible = false
			if p == options:
				Settings.save_settings()
	if _return_to:
		_return_to.visible = true
		if _last_focus and is_instance_valid(_last_focus) and _last_focus.is_visible_in_tree():
			_last_focus.grab_focus()
		elif _return_to == title:
			focus_first_menu_button()
		elif _return_to == pause:
			_focus_resume()
	Sfx.play("ui_click", -6)


# kept for older callers
func show_controls(from: Control) -> void:
	open_panel(controls, from)

func hide_controls() -> void:
	close_panel()


# ------------------------------------------------------------------ SAVE SLOTS (Continue / Save Game / leave dialogs)
const SLOT_TEXT := {
	"load": ["Continue", "Choose a saved game to load."],
	"save": ["Save Game", "Choose a slot to save to."],
	"leave_title": ["Save before leaving?", "Save your game to a slot, or leave without saving. (Returns to the main menu.)"],
	"leave_exit": ["Save before exiting?", "Save your game to a slot, or exit without saving."],
}


func _build_slots() -> void:
	var a := _panel_screen(760)
	slots = a[0]
	var v: VBoxContainer = a[1]
	_slot_title = _center_label(v, "Continue", 34, UIKit.COL_GOLD)
	_slot_hint = _center_label(v, "", 15, UIKit.COL_DIM, false)
	_slot_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	for i in range(1, SaveGame.SLOTS + 1):
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		v.add_child(row)
		var card := UIKit.button("", 18)
		card.custom_minimum_size = Vector2(620, 90)
		card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		card.pressed.connect(func():
			Sfx.play("ui_click", -4)
			_slot_card_pressed(i))
		card.mouse_entered.connect(func(): if card.is_visible_in_tree() and not card.disabled: Sfx.play("ui_click", -14))
		card.focus_entered.connect(func(): if card.is_visible_in_tree(): Sfx.play("ui_click", -14))
		row.add_child(card)
		var box := VBoxContainer.new()
		box.set_anchors_preset(Control.PRESET_FULL_RECT)
		box.offset_left = 16
		box.offset_top = 8
		box.offset_right = -16
		box.offset_bottom = -6
		box.add_theme_constant_override("separation", 0)
		box.mouse_filter = Control.MOUSE_FILTER_IGNORE
		card.add_child(box)
		var l1 := UIKit.label("", 21, UIKit.COL_GOLD)
		var l2 := UIKit.label("", 17, UIKit.COL_TEXT)
		var l3 := UIKit.label("", 14, UIKit.COL_DIM)
		for l in [l1, l2, l3]:
			l.mouse_filter = Control.MOUSE_FILTER_IGNORE
			box.add_child(l)
		var del := UIKit.button("Delete", 15)
		del.custom_minimum_size = Vector2(96, 90)
		del.pressed.connect(func():
			Sfx.play("ui_click", -4)
			_slot_delete_pressed(i))
		row.add_child(del)
		_slot_rows.append({"card": card, "del": del, "l1": l1, "l2": l2, "l3": l3})
	_slot_footer = HBoxContainer.new()
	_slot_footer.add_theme_constant_override("separation", 12)
	v.add_child(_slot_footer)


func refresh_slots() -> void:
	for idx in _slot_rows.size():
		var i := idx + 1
		var r: Dictionary = _slot_rows[idx]
		var m := SaveGame.meta(i)
		var filled := not m.is_empty()
		var cur := "   (current game)" if i == SaveGame.current_slot else ""
		if filled:
			r["l1"].text = "SLOT %d   -   Day %d   -   %s%s" % [i, int(m.get("day", 1)), str(m.get("zone", "")), cur]
			r["l2"].text = str(m.get("quest", ""))
			r["l3"].text = "Played %s   -   Monsters defeated %d   -   Saved %s" % [str(m.get("played", "0:00")), int(m.get("kills", 0)), str(m.get("saved_at", "")).replace("T", "  ")]
		else:
			r["l1"].text = "SLOT %d   -   Empty%s" % [i, cur]
			r["l2"].text = "No saved game here yet."
			r["l3"].text = ""
		(r["card"] as Button).disabled = (_slot_mode == "load" and not filled)
		(r["del"] as Button).visible = (_slot_mode == "load")
		(r["del"] as Button).disabled = not filled


func open_slots(mode: String, from: Control) -> void:
	_slot_mode = mode
	_slot_title.text = SLOT_TEXT[mode][0]
	_slot_hint.text = SLOT_TEXT[mode][1]
	for c in _slot_footer.get_children():
		c.queue_free()
	if mode.begins_with("leave"):
		var dont := _btn(_slot_footer, "Don't save", 18, func(): leave_without_saving.emit(mode))
		dont.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var cancel := _btn(_slot_footer, "Back", 18, close_panel)      # named Back so the keyboard focus logic finds it
		cancel.text = "Cancel"
		cancel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	else:
		var back := _btn(_slot_footer, "Back", 18, close_panel)
		back.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	refresh_slots()
	open_panel(slots, from)
	# focus a card: the current slot, otherwise the first usable one
	var order: Array = []
	for idx in _slot_rows.size():
		order.append(idx)
	if SaveGame.current_slot > 0:
		order.push_front(SaveGame.current_slot - 1)
	for idx in order:
		var card: Button = _slot_rows[idx]["card"]
		if not card.disabled:
			card.grab_focus()
			break


func _slot_card_pressed(i: int) -> void:
	var filled := SaveGame.has_slot(i)
	if _slot_mode == "load":
		if filled:
			slot_chosen.emit("load", i)
		else:
			Sfx.play("ui_deny")
		return
	var mode := _slot_mode
	if filled and i != SaveGame.current_slot:
		var m := SaveGame.meta(i)
		ask("Overwrite Slot %d?\n(Day %d - %s)\nThe old save will be replaced." % [i, int(m.get("day", 1)), str(m.get("zone", ""))], "Overwrite",
			func(): slot_chosen.emit(mode, i))
	else:
		slot_chosen.emit(mode, i)


func _slot_delete_pressed(i: int) -> void:
	ask("Delete Slot %d?\nThis cannot be undone." % i, "Delete", func():
		SaveGame.delete(i)
		refresh_slots()
		refresh_continue()
		if not SaveGame.any_saves():
			close_panel())


# ------------------------------------------------------------------ PAUSE MENU
func _build_pause() -> void:
	pause = _overlay(0.72)
	var v := _centered_box(pause, 380, 8)
	_panel_title(v, "Paused")
	_pause_info = _center_label(v, "", 15, UIKit.COL_DIM, false)
	var gap := Control.new()
	gap.custom_minimum_size = Vector2(0, 6)
	v.add_child(gap)
	var resume := _btn(v, "Resume  [Esc]", 22, func(): resume_pressed.emit(), 46)
	resume.set_meta("resume", true)
	_btn(v, "Save Game", 18, func(): open_slots("save", pause))
	_btn(v, "Options", 18, func(): open_panel(options, pause))
	_btn(v, "How to Play", 18, func(): open_panel(controls, pause))
	_btn(v, "Main Menu", 18, func(): open_slots("leave_title", pause))
	_btn(v, "Exit Game", 18, func(): open_slots("leave_exit", pause))


func _focus_resume() -> void:
	for b in pause.find_children("*", "Button", true, false):
		if b.has_meta("resume"):
			b.grab_focus()
			return


func set_paused(on: bool, info: String = "") -> void:
	pause.visible = on
	if not on:
		for p in [controls, options, credits, slots]:
			p.visible = false
		confirm.visible = false
		Settings.save_settings()
	else:
		_pause_info.text = info
		_return_to = pause
		_focus_resume()
	update_mute_label()


# ------------------------------------------------------------------ confirmation dialog
func _build_confirm() -> void:
	confirm = _overlay(0.55)
	var v := _centered_box(confirm, 460, 14)
	var p := UIKit.panel(Color(0.09, 0.075, 0.1, 0.98))
	v.add_child(p)
	var inner := VBoxContainer.new()
	inner.add_theme_constant_override("separation", 14)
	p.add_child(inner)
	_confirm_text = _center_label(inner, "", 18, UIKit.COL_TEXT, false)
	_confirm_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	inner.add_child(row)
	_confirm_yes = _btn(row, "Yes", 18, func(): _confirm_answer(true))
	_confirm_yes.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var no := _btn(row, "Cancel", 18, func(): _confirm_answer(false))
	no.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	no.set_meta("cancel", true)


func ask(text: String, yes_label: String, on_yes: Callable) -> void:
	_confirm_return = get_viewport().gui_get_focus_owner()
	_confirm_text.text = text
	_confirm_yes.text = yes_label
	_confirm_cb = on_yes
	confirm.visible = true
	for b in confirm.find_children("*", "Button", true, false):
		if b.has_meta("cancel"):
			b.grab_focus()


func confirm_open() -> bool:
	return confirm.visible


func cancel_confirm() -> void:
	_confirm_answer(false)


func _confirm_answer(yes: bool) -> void:
	confirm.visible = false
	var cb := _confirm_cb
	_confirm_cb = Callable()
	if yes and cb.is_valid():
		cb.call()
	elif _confirm_return and is_instance_valid(_confirm_return) and _confirm_return.is_visible_in_tree():
		_confirm_return.grab_focus()
	elif title.visible:
		focus_first_menu_button()
	elif pause.visible:
		_focus_resume()


# ------------------------------------------------------------------ death
func _build_death() -> void:
	death = _overlay(0.0)
	var v := _centered_box(death, 640)
	_center_label(v, "YOU FELL", 60, Color(0.95, 0.3, 0.3))
	_death_text = _center_label(v, "", 18, UIKit.COL_TEXT)
	_death_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART


func show_death(lost: Dictionary, where: String) -> void:
	var msg := "You wake at: %s." % where
	if lost.is_empty():
		msg += "\nNothing was lost."
	else:
		var parts: Array[String] = []
		for id in lost:
			parts.append("%d %s" % [lost[id], GameState.ITEMS[id]["name"]])
		msg += "\nMaterials gathered since your last bed or shrine were lost:\n" + ", ".join(parts)
	_death_text.text = msg
	death.visible = true


func hide_death() -> void:
	death.visible = false


# ------------------------------------------------------------------ victory
func _build_victory() -> void:
	victory = _overlay(0.88)
	var v := _centered_box(victory, 620)
	_center_label(v, "YOU ESCAPED!", 60, UIKit.COL_GOLD)
	_center_label(v, "The Warden is defeated and the Escape Gate carries you out of the Thicket.", 17, UIKit.COL_TEXT, false).autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_victory_text = _center_label(v, "", 17, UIKit.COL_GOOD, false)
	_center_label(v, "(Prototype ending: the Warden stands in for Benizaurus, who is saved for the full game.)", 13, UIKit.COL_DIM, false).autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_btn(v, "Play again", 20, func(): restart_pressed.emit(), 46)
	_btn(v, "Main Menu", 18, func(): title_pressed.emit())
	_btn(v, "Exit Game", 18, func(): quit_pressed.emit())


func show_victory() -> void:
	_victory_text.text = "Time: %s    Days: %d    Monsters defeated: %d    Times fallen: %d" % [
		GameState.run_time_text(), GameState.day, GameState.kills, GameState.deaths]
	victory.visible = true
	for b in victory.find_children("*", "Button", true, false):
		b.grab_focus()
		break


# ------------------------------------------------------------------ fade
func fade_to(alpha: float, time: float) -> Signal:
	var tw := create_tween()
	tw.tween_property(fade_rect, "modulate:a", alpha, time)
	return tw.finished
